const INPUT_RATE = 16_000;
const ECHO_RATE = 24_000;
const INPUT_CHUNK_MS = 160;
const ECHO_CHUNK_MS = 40;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function resampleFloat32(input, fromRate, toRate) {
  if (!(input instanceof Float32Array)) input = Float32Array.from(input || []);
  if (!input.length || !Number.isFinite(fromRate) || !Number.isFinite(toRate) || fromRate <= 0 || toRate <= 0) return new Float32Array();
  if (fromRate === toRate) return input.slice();
  const length = Math.max(1, Math.floor(input.length * toRate / fromRate));
  const output = new Float32Array(length);
  const ratio = fromRate / toRate;
  for (let index = 0; index < length; index += 1) {
    const position = index * ratio;
    const left = Math.floor(position);
    const right = Math.min(input.length - 1, left + 1);
    const mix = position - left;
    output[index] = input[left] * (1 - mix) + input[right] * mix;
  }
  return output;
}
export function float32ToPcm16(input) {
  const source = input instanceof Float32Array ? input : Float32Array.from(input || []);
  const output = new Int16Array(source.length);
  for (let index = 0; index < source.length; index += 1) {
    const value = clamp(source[index], -1, 1);
    output[index] = value < 0 ? Math.round(value * 32768) : Math.round(value * 32767);
  }
  return output;
}

export function pcm16ToBase64(samples) {
  const input = samples instanceof Int16Array ? samples : Int16Array.from(samples || []);
  let binary = '';
  const bytes = new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  const step = 0x4000;
  for (let offset = 0; offset < bytes.length; offset += step) {
    binary += String.fromCharCode(...bytes.subarray(offset, Math.min(bytes.length, offset + step)));
  }
  return btoa(binary);
}

function base64ToArrayBuffer(value) {
  const binary = atob(String(value || ''));
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes.buffer;
}
export function pcmLooksVoiced(samples) {
  if (!samples?.length) return false;
  let sum = 0;
  let peak = 0;
  for (const raw of samples) {
    const value = Math.abs(raw / 32768);
    sum += value * value;
    if (value > peak) peak = value;
  }
  const rms = Math.sqrt(sum / samples.length);
  return rms >= 0.012 || peak >= 0.05;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function safeState(value) {
  const allowed = new Set(['idle', 'connecting', 'listening', 'processing', 'speaking', 'ending', 'ended', 'error']);
  return allowed.has(value) ? value : 'error';
}

function newestOpenCall(calls) {
  const now = Date.now();
  return (Array.isArray(calls) ? calls : []).find(call => call?.state !== 'ended' && (!call.expiresAt || Date.parse(call.expiresAt) > now)) || null;
}
export function createCallController({
  request,
  dailyFactory,
  videoHost,
  onState = () => {},
  onTurn = () => {},
  mediaDevices = globalThis.navigator?.mediaDevices,
  AudioContextCtor = globalThis.AudioContext || globalThis.webkitAudioContext
} = {}) {
  if (typeof request !== 'function') throw new TypeError('request is required');
  if (typeof dailyFactory !== 'function') throw new TypeError('dailyFactory is required');
  const call = {
    phase: 'idle', sessionId: null, callId: null, sequence: 1, eventCursor: 0,
    renderer: null, daily: null, stream: null, audioContext: null,
    mediaSource: null, processor: null, silentGain: null,
    pendingPcm: [], sendChain: Promise.resolve(), pollTimer: null,
    pollBusy: false, handledGenerations: new Set(), echoEpoch: 0,
    interruptPending: false, closed: false
  };

  function publish(phase, detail = '') {
    call.phase = safeState(phase);
    onState(Object.freeze({ phase: call.phase, detail, active: !['idle', 'ended'].includes(call.phase) }));
  }

  function ensureAudioContext() {
    if (!AudioContextCtor) throw new Error('Live audio is unavailable on this device.');
    if (!call.audioContext) call.audioContext = new AudioContextCtor();
    return call.audioContext;
  }
  async function recoverSequence() {
    if (!call.sessionId) return;
    const current = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}`);
    const next = Number(current?.session?.input?.nextSequence);
    if (Number.isInteger(next) && next > 0) call.sequence = next;
  }

  async function sendPcmChunk(samples) {
    if (!call.sessionId || call.closed) return;
    const sequence = call.sequence;
    try {
      const result = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/audio-chunks`, {
        method: 'POST',
        body: { sequence, audioBase64: pcm16ToBase64(samples), language: globalThis.navigator?.language || null }
      });
      const next = Number(result?.input?.nextSequence);
      call.sequence = Number.isInteger(next) && next > sequence ? next : sequence + 1;
    } catch (error) {
      if (Number(error?.status) === 409) {
        await recoverSequence();
        return;
      }
      throw error;
    }
  }

  function enqueuePcm(samples) {
    call.sendChain = call.sendChain.then(() => sendPcmChunk(samples)).catch(error => publish('error', error.message));
  }
  async function interruptForBargeIn() {
    if (call.interruptPending || !call.sessionId || call.closed) return;
    call.interruptPending = true;
    call.echoEpoch += 1;
    try {
      await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/interrupt`, { method: 'POST', body: {} });
      publish('listening', 'Interrupted · listening');
    } catch (error) {
      publish('error', error.message);
    } finally {
      call.interruptPending = false;
    }
  }

  function consumeMicrophoneBlock(floatSamples, sampleRate) {
    const mono16k = resampleFloat32(floatSamples, sampleRate, INPUT_RATE);
    const pcm = float32ToPcm16(mono16k);
    if (call.phase === 'speaking' && pcmLooksVoiced(pcm)) void interruptForBargeIn();
    for (const value of pcm) call.pendingPcm.push(value);
    const target = Math.round(INPUT_RATE * INPUT_CHUNK_MS / 1000);
    while (call.pendingPcm.length >= target) {
      const chunk = Int16Array.from(call.pendingPcm.splice(0, target));
      enqueuePcm(chunk);
    }
  }

  async function startMicrophone(stream) {
    const context = ensureAudioContext();
    if (context.state === 'suspended') await context.resume();
    const source = context.createMediaStreamSource(stream);
    const processor = context.createScriptProcessor(2048, 1, 1);
    const silent = context.createGain();
    silent.gain.value = 0;
    processor.onaudioprocess = event => consumeMicrophoneBlock(event.inputBuffer.getChannelData(0), context.sampleRate);
    source.connect(processor); processor.connect(silent); silent.connect(context.destination);
    call.mediaSource = source; call.processor = processor; call.silentGain = silent;
  }
  async function sendEchoPcm(samples, generation) {
    if (!call.daily || !call.renderer || !samples.length) return;
    const epoch = ++call.echoEpoch;
    const perChunk = Math.max(1, Math.floor(ECHO_RATE * ECHO_CHUNK_MS / 1000));
    const inferenceId = `${call.sessionId}:${generation}`;
    for (let offset = 0; offset < samples.length; offset += perChunk) {
      if (call.closed || epoch !== call.echoEpoch) return;
      const chunk = samples.subarray(offset, Math.min(samples.length, offset + perChunk));
      const done = offset + perChunk >= samples.length;
      call.daily.sendAppMessage({
        message_type: 'conversation',
        event_type: 'conversation.echo',
        conversation_id: call.renderer.sessionId,
        properties: {
          modality: 'audio', audio: pcm16ToBase64(chunk), sample_rate: ECHO_RATE,
          inference_id: inferenceId, done
        }
      }, '*');
      if (!done) await sleep(ECHO_CHUNK_MS);
    }
  }

  async function decodeSpeech(base64) {
    const context = ensureAudioContext();
    if (context.state === 'suspended') await context.resume();
    return context.decodeAudioData(base64ToArrayBuffer(base64).slice(0));
  }
  async function handleOutput(generation) {
    if (!Number.isInteger(generation) || generation < 1 || call.handledGenerations.has(generation) || call.closed) return;
    call.handledGenerations.add(generation);
    const payload = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/outputs/${generation}`);
    const voice = payload?.output?.voice;
    if (!voice) throw new Error('Runtime returned an invalid call output.');
    onTurn({ generation, transcript: String(voice.transcript || ''), replyText: String(voice.replyText || '') });
    if (voice.interrupted) {
      publish('listening', 'Listening');
      return;
    }
    const synthesized = voice.synthesizedAudio;
    if (synthesized?.status !== 'ready' || !synthesized.audioBase64) {
      await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/playback-complete`, { method: 'POST', body: { generation } });
      publish('error', 'Lola voice is unavailable · no fallback used');
      return;
    }
    publish('speaking', 'Lola is speaking');
    const decoded = await decodeSpeech(synthesized.audioBase64);
    const mono = decoded.getChannelData(0);
    const pcm24 = float32ToPcm16(resampleFloat32(mono, decoded.sampleRate, ECHO_RATE));
    await sendEchoPcm(pcm24, generation);
    if (call.closed || call.phase !== 'speaking') return;
    await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/playback-complete`, { method: 'POST', body: { generation } });
    publish('listening', 'Listening');
  }
  async function pollEvents() {
    if (call.pollBusy || call.closed || !call.sessionId) return;
    call.pollBusy = true;
    try {
      const payload = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/events?afterSequence=${call.eventCursor}&limit=100`);
      for (const event of payload?.events || []) {
        call.eventCursor = Math.max(call.eventCursor, Number(event.sequence || 0));
        const generation = Number(event?.payload?.generation || 0);
        if (event.type === 'turn.processing') publish('processing', 'Lola is thinking');
        else if (event.type === 'turn.speaking') publish('processing', 'Preparing Lola voice');
        else if (event.type === 'turn.output_ready') await handleOutput(generation);
        else if (event.type === 'turn.interrupted') { call.echoEpoch += 1; publish('listening', 'Listening'); }
        else if (event.type === 'turn.discarded') publish('error', String(event?.payload?.error || 'Call turn failed'));
        else if (event.type === 'session.ended') publish('ended', 'Call ended');
      }
    } catch (error) {
      if (!call.closed) publish('error', error.message);
    } finally {
      call.pollBusy = false;
      if (!call.closed && call.sessionId) call.pollTimer = setTimeout(pollEvents, 300);
    }
  }

  function stopPoll() {
    if (call.pollTimer) clearTimeout(call.pollTimer);
    call.pollTimer = null;
  }
  async function joinRenderer(renderer) {
    if (renderer?.protocol !== 'daily' || !renderer?.joinUrl || !renderer?.joinToken || !renderer?.sessionId) {
      throw new Error('Live Lola video is not configured correctly.');
    }
    call.renderer = renderer;
    const daily = dailyFactory(videoHost, renderer);
    if (!daily || typeof daily.join !== 'function' || typeof daily.sendAppMessage !== 'function') {
      throw new Error('Live video transport is unavailable.');
    }
    call.daily = daily;
    await daily.join({
      url: renderer.joinUrl,
      token: renderer.joinToken,
      startAudioOff: true,
      startVideoOff: true
    });
  }

  async function resolveSession() {
    const callsPayload = await request('/api/v1/body/calls');
    const existing = newestOpenCall(callsPayload?.calls);
    if (existing?.id) {
      const current = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(existing.id)}`);
      return current?.session || null;
    }
    const created = await request('/api/v1/body/voice/sessions', { method: 'POST', body: {} });
    return created?.session || null;
  }
  async function start() {
    if (!['idle', 'ended', 'error'].includes(call.phase)) return;
    call.closed = false;
    publish('connecting', 'Connecting Lola');
    let stream = null;
    try {
      const policy = await request('/api/v1/body/voice/policy');
      const input = policy?.voice?.input;
      if (!policy?.voice?.configured || input?.encoding !== 'pcm_s16le' || input?.sampleRate !== INPUT_RATE || input?.channels !== 1) {
        throw new Error('Runtime live voice contract is unavailable.');
      }
      if (!mediaDevices?.getUserMedia) throw new Error('Microphone access is unavailable on this device.');
      stream = await mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
      call.stream = stream;
      const session = await resolveSession();
      if (!session?.id) throw new Error('Runtime did not create or resume a call session.');
      call.sessionId = session.id; call.callId = session.callId || null;
      call.sequence = Number(session?.input?.nextSequence || 1); call.eventCursor = 0;
      const rendererPayload = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/renderer`, { method: 'POST', body: {} });
      await joinRenderer(rendererPayload?.renderer);
      await startMicrophone(stream);
      publish('listening', 'Listening');
      void pollEvents();
    } catch (error) {
      stream?.getTracks?.().forEach(track => track.stop());
      if (call.sessionId) await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}`, { method: 'DELETE' }).catch(() => null);
      publish('error', error.message);
      throw error;
    }
  }
  async function hangup() {
    if (call.closed || call.phase === 'idle') return;
    publish('ending', 'Ending call');
    call.closed = true; call.echoEpoch += 1; stopPoll();
    if (call.processor) call.processor.onaudioprocess = null;
    for (const node of [call.mediaSource, call.processor, call.silentGain]) {
      try { node?.disconnect?.(); } catch {}
    }
    call.stream?.getTracks?.().forEach(track => track.stop());
    try { await call.sendChain; } catch {}
    try { await call.daily?.leave?.(); } catch {}
    try { await call.daily?.destroy?.(); } catch {}
    let ended = null;
    if (call.sessionId) {
      ended = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}`, { method: 'DELETE' }).catch(error => ({ ok: false, error: error.message }));
    }
    try { await call.audioContext?.close?.(); } catch {}
    call.stream = null; call.audioContext = null; call.daily = null; call.renderer = null;
    call.mediaSource = null; call.processor = null; call.silentGain = null;
    call.pendingPcm = []; call.sessionId = null; call.callId = null; call.eventCursor = 0;
    publish('ended', ended?.ok === false ? `Call ended locally · ${ended.error}` : 'Call ended');
    return ended;
  }

  function snapshot() {
    return Object.freeze({ phase: call.phase, active: !['idle', 'ended'].includes(call.phase), sessionId: call.sessionId, callId: call.callId, nextSequence: call.sequence });
  }

  return Object.freeze({ start, hangup, snapshot, interrupt: interruptForBargeIn });
}
