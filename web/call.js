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
  return (Array.isArray(calls) ? calls : []).find(call => call?.chatId === 'body' && call.state !== 'ended' && (!call.expiresAt || Date.parse(call.expiresAt) > now)) || null;
}
export function createCallController({
  request,
  dailyFactory,
  videoHost,
  onState = () => {},
  onTurn = () => {},
  onSignal = () => {},
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
    interruptPending: false, closed: true, epoch: 0, starting: null, stopping: null,
    playback: null, playbackTimer: null, rendererReady: false, generationFloor: 0,
    outputChain: Promise.resolve(), queuedChunks: 0, allocating: null, mediaTimer: null
  };

  function publish(phase, detail = '') {
    call.phase = safeState(phase);
    if (!call.rendererReady && ['listening', 'processing', 'speaking'].includes(call.phase)) detail = 'Waiting for Lola live media';
    onState(Object.freeze({ phase: call.phase, detail, active: !call.closed, rendererReady: call.rendererReady }));
  }

  function isCurrent(epoch) { return !call.closed && epoch === call.epoch; }

  function cancelPlayback() {
    call.echoEpoch += 1;
    clearTimeout(call.playbackTimer);
    call.playbackTimer = null;
    call.playback = null;
    onSignal({ source: 'renderer', speaking: false });
  }

  async function fail(error) {
    if (call.closed) return;
    await hangup({ phase: 'error', detail: error?.message || 'Call connection failed.' });
  }

  function ensureAudioContext() {
    if (!AudioContextCtor) throw new Error('Live audio is unavailable on this device.');
    if (!call.audioContext) call.audioContext = new AudioContextCtor();
    return call.audioContext;
  }
  async function recoverSequence() {
    if (!call.sessionId) return;
    const epoch = call.epoch;
    const current = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}`);
    if (!isCurrent(epoch)) return;
    const next = Number(current?.session?.input?.nextSequence);
    if (Number.isInteger(next) && next > 0) call.sequence = next;
  }

  async function sendPcmChunk(samples) {
    if (!call.sessionId || call.closed) return;
    const epoch = call.epoch;
    const sequence = call.sequence;
    try {
      const result = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/audio-chunks`, {
        method: 'POST',
        body: { sequence, audioBase64: pcm16ToBase64(samples), language: globalThis.navigator?.language || null }
      });
      const next = Number(result?.input?.nextSequence);
      if (!isCurrent(epoch)) return;
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
    // Stop capture on backpressure instead of accumulating stale speech indefinitely.
    if (call.queuedChunks >= 20) { void fail(new Error('Call connection is too slow. Please reconnect.')); return; }
    call.queuedChunks += 1;
    const epoch = call.epoch;
    call.sendChain = call.sendChain.then(() => isCurrent(epoch) ? sendPcmChunk(samples) : undefined)
      .catch(error => { if (isCurrent(epoch)) void fail(error); }).finally(() => { if (isCurrent(epoch)) call.queuedChunks -= 1; });
  }
  async function interruptForBargeIn() {
    if (call.interruptPending || !call.sessionId || call.closed) return;
    call.interruptPending = true;
    const epoch = call.epoch;
    cancelPlayback();
    try {
      call.daily?.sendAppMessage({ message_type: 'conversation', event_type: 'conversation.interrupt', conversation_id: call.renderer.sessionId }, '*');
      await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/interrupt`, { method: 'POST', body: {} });
      if (isCurrent(epoch)) publish('listening', 'Call connected');
    } catch (error) {
      if (!isCurrent(epoch)) return;
      void fail(error);
    } finally {
      call.interruptPending = false;
    }
  }

  function consumeMicrophoneBlock(floatSamples, sampleRate) {
    if (call.closed || !call.rendererReady) return;
    const mono16k = resampleFloat32(floatSamples, sampleRate, INPUT_RATE);
    const pcm = float32ToPcm16(mono16k);
    const voiced = pcmLooksVoiced(pcm);
    onSignal({ source: 'microphone', voiced });
    if (call.playback && voiced) void interruptForBargeIn();
    for (const value of pcm) call.pendingPcm.push(value);
    const target = Math.round(INPUT_RATE * INPUT_CHUNK_MS / 1000);
    while (call.pendingPcm.length >= target) {
      const chunk = Int16Array.from(call.pendingPcm.splice(0, target));
      enqueuePcm(chunk);
    }
  }

  async function startMicrophone(stream, epoch) {
    const context = ensureAudioContext();
    if (context.state === 'suspended') await context.resume();
    if (!isCurrent(epoch)) return;
    const source = context.createMediaStreamSource(stream);
    const processor = context.createScriptProcessor(2048, 1, 1);
    const silent = context.createGain();
    silent.gain.value = 0;
    processor.onaudioprocess = event => consumeMicrophoneBlock(event.inputBuffer.getChannelData(0), context.sampleRate);
    source.connect(processor); processor.connect(silent); silent.connect(context.destination);
    call.mediaSource = source; call.processor = processor; call.silentGain = silent;
  }
  async function sendEchoPcm(samples, generation, epoch) {
    if (!call.daily || !call.renderer || !samples.length) return;
    const perChunk = Math.max(1, Math.floor(ECHO_RATE * ECHO_CHUNK_MS / 1000));
    const inferenceId = `${call.sessionId}:${generation}`;
    for (let offset = 0; offset < samples.length; offset += perChunk) {
      if (call.closed || epoch !== call.echoEpoch) return;
      const chunk = samples.subarray(offset, Math.min(samples.length, offset + perChunk));
      const done = offset + perChunk >= samples.length;
      await call.daily.sendAppMessage({
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
    if (!Number.isInteger(generation) || generation <= call.generationFloor || call.handledGenerations.has(generation) || call.closed) return;
    call.handledGenerations.add(generation);
    const epoch = call.epoch;
    const echoEpoch = call.echoEpoch;
    const payload = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/outputs/${generation}`);
    if (!isCurrent(epoch) || echoEpoch !== call.echoEpoch) return;
    const voice = payload?.output?.voice;
    if (!voice) throw new Error('Runtime returned an invalid call output.');
    onTurn({ generation, transcript: String(voice.transcript || ''), replyText: String(voice.replyText || '') });
    if (voice.interrupted) {
      publish('listening', 'Call connected');
      return;
    }
    const synthesized = voice.synthesizedAudio;
    if (synthesized?.status !== 'ready' || !synthesized.audioBase64) {
      throw new Error('Lola voice is unavailable. Please reconnect.');
    }
    const decoded = await decodeSpeech(synthesized.audioBase64);
    if (!isCurrent(epoch) || echoEpoch !== call.echoEpoch) return;
    if (!call.rendererReady) throw new Error('Lola live media is unavailable. Please reconnect.');
    const mono = decoded.getChannelData(0);
    const pcm24 = float32ToPcm16(resampleFloat32(mono, decoded.sampleRate, ECHO_RATE));
    if (!pcm24.length) throw new Error('Lola returned empty call audio.');
    cancelPlayback();
    call.playback = { generation, inferenceId: `${call.sessionId}:${generation}`, started: false, completing: false };
    // Upload completion is not playback proof. Only the matching renderer event acknowledges it.
    call.playbackTimer = setTimeout(() => { void fail(new Error('Lola playback could not be confirmed. Please reconnect.')); }, pcm24.length / ECHO_RATE * 1000 + 20_000);
    await sendEchoPcm(pcm24, generation, call.echoEpoch);
  }
  async function pollEvents() {
    if (call.pollBusy || call.closed || !call.sessionId) return;
    call.pollBusy = true;
    const epoch = call.epoch;
    try {
      const payload = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/events?afterSequence=${call.eventCursor}&limit=100`);
      if (!isCurrent(epoch)) return;
      for (const event of payload?.events || []) {
        if (!isCurrent(epoch)) break;
        call.eventCursor = Math.max(call.eventCursor, Number(event.sequence || 0));
        const generation = Number(event?.payload?.generation || 0);
        if (generation && generation <= call.generationFloor) continue;
        if (event.type === 'turn.processing' || event.type === 'turn.speaking') publish('processing', 'Call connected');
        else if (event.type === 'turn.output_ready') {
          call.outputChain = call.outputChain.then(() => isCurrent(epoch) ? handleOutput(generation) : undefined).catch(error => { if (isCurrent(epoch)) void fail(error); });
        }
        else if (event.type === 'turn.interrupted') {
          call.generationFloor = Math.max(call.generationFloor, generation);
          cancelPlayback();
          call.daily?.sendAppMessage({ message_type: 'conversation', event_type: 'conversation.interrupt', conversation_id: call.renderer.sessionId }, '*');
          publish('listening', 'Call connected');
        }
        else if (event.type === 'turn.discarded') { void fail(new Error('This call turn could not be completed. Please reconnect.')); break; }
        else if (event.type === 'session.ended') { void hangup({ remoteEnded: true }); break; }
      }
    } catch (error) {
      if (isCurrent(epoch)) void fail(error);
    } finally {
      if (isCurrent(epoch)) {
        call.pollBusy = false;
        if (call.sessionId) call.pollTimer = setTimeout(pollEvents, 300);
      }
    }
  }

  function stopPoll() {
    if (call.pollTimer) clearTimeout(call.pollTimer);
    call.pollTimer = null;
  }
  async function joinRenderer(renderer) {
    if (renderer?.protocol !== 'daily' || renderer?.echo !== true || !renderer?.joinUrl || !renderer?.joinToken || !renderer?.sessionId) {
      throw new Error('Live Lola video is not configured correctly.');
    }
    call.renderer = renderer;
    const daily = dailyFactory(videoHost, renderer);
    if (!daily || typeof daily.join !== 'function' || typeof daily.sendAppMessage !== 'function' || typeof daily.on !== 'function') {
      throw new Error('Live video transport is unavailable.');
    }
    call.daily = daily;
    const epoch = call.epoch;
    const updateMedia = () => {
      if (!isCurrent(epoch)) return;
      const remote = Object.values(daily.participants()).filter(participant => !participant.local);
      const ready = remote.some(participant => participant.tracks?.video?.state === 'playable' && participant.tracks?.audio?.state === 'playable');
      const wasReady = call.rendererReady;
      call.rendererReady = ready;
      if (ready) { clearTimeout(call.mediaTimer); call.mediaTimer = null; }
      onSignal({ source: 'renderer', available: ready });
      if (!ready && wasReady) { void fail(new Error('Lola live media disconnected. Please reconnect.')); return; }
      if (ready && call.phase === 'connecting') publish('listening', 'Call connected');
    };
    daily.on('participant-joined', updateMedia);
    daily.on('participant-updated', updateMedia);
    daily.on('participant-left', updateMedia);
    daily.on('app-message', event => { if (isCurrent(epoch)) void rendererMessage(event).catch(error => { void fail(error); }); });
    daily.on('error', () => { if (isCurrent(epoch)) void fail(new Error('Live call connection failed. Please reconnect.')); });
    daily.on('left-meeting', () => { if (isCurrent(epoch)) void fail(new Error('Live call disconnected. Please reconnect.')); });
    await daily.join({
      url: renderer.joinUrl,
      token: renderer.joinToken,
      startAudioOff: true,
      startVideoOff: true
    });
    updateMedia();
  }

  async function rendererMessage(event) {
    const data = event?.data;
    const playback = call.playback;
    const sender = call.daily?.participants?.()[event?.fromId];
    if (!sender || sender.local || !playback || !call.rendererReady || data?.message_type !== 'conversation'
      || (data.conversation_id && data.conversation_id !== call.renderer.sessionId)
      || data.inference_id !== playback.inferenceId) return;
    const replica = data.properties?.role === 'replica';
    const started = data.event_type === 'conversation.replica.started_speaking' || (replica && data.event_type === 'conversation.started_speaking');
    const stopped = data.event_type === 'conversation.replica.stopped_speaking' || (replica && data.event_type === 'conversation.stopped_speaking');
    if (started && !playback.completing) {
      playback.started = true;
      onSignal({ source: 'renderer', speaking: true });
      publish('speaking', 'Call connected');
    }
    if (!stopped || !playback.started || playback.completing) return;
    playback.completing = true;
    if (data.properties?.interrupted) { await interruptForBargeIn(); return; }
    clearTimeout(call.playbackTimer);
    const epoch = call.epoch;
    await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/playback-complete`, { method: 'POST', body: { generation: playback.generation } });
    if (!isCurrent(epoch) || call.playback !== playback) return;
    cancelPlayback();
    publish('listening', 'Call connected');
  }

  async function resolveSession(epoch) {
    const callsPayload = await request('/api/v1/body/calls');
    if (!isCurrent(epoch)) return null;
    const existing = newestOpenCall(callsPayload?.calls);
    if (existing?.id) {
      const current = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(existing.id)}`);
      return current?.session || null;
    }
    const created = await request('/api/v1/body/voice/sessions', { method: 'POST', body: {} });
    return created?.session || null;
  }
  function start() {
    if (call.starting) return call.starting;
    if (call.stopping || !call.closed) return Promise.resolve();
    call.starting = startSession().finally(() => { call.starting = null; });
    return call.starting;
  }
  async function startSession() {
    call.closed = false;
    const epoch = ++call.epoch;
    call.handledGenerations.clear();
    call.generationFloor = 0;
    call.pollBusy = false;
    call.sendChain = Promise.resolve();
    call.outputChain = Promise.resolve();
    call.queuedChunks = 0;
    call.interruptPending = false;
    publish('connecting', 'Connecting Lola');
    let stream = null;
    const cancelled = () => !isCurrent(epoch);
    try {
      // Unlock iPhone audio while still in the owner's Call gesture.
      const context = ensureAudioContext();
      if (context.state === 'suspended') await context.resume();
      if (cancelled()) return;
      const policy = await request('/api/v1/body/voice/policy');
      if (cancelled()) return;
      const input = policy?.voice?.input;
      if (!policy?.voice?.configured || input?.encoding !== 'pcm_s16le' || input?.sampleRate !== INPUT_RATE || input?.channels !== 1) {
        throw new Error('Runtime live voice contract is unavailable.');
      }
      if (!mediaDevices?.getUserMedia) throw new Error('Microphone access is unavailable on this device.');
      stream = await mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }, video: false });
      if (cancelled()) { stream.getTracks().forEach(track => track.stop()); return; }
      call.stream = stream;
      for (const track of stream.getTracks()) track.addEventListener?.('ended', () => {
        if (isCurrent(epoch)) void fail(new Error('Microphone disconnected. Please reconnect.'));
      }, { once: true });
      call.allocating = { kind: 'session', promise: resolveSession(epoch) };
      const session = await call.allocating.promise;
      call.allocating = null;
      if (cancelled()) return;
      if (!session?.id) throw new Error('Runtime did not create or resume a call session.');
      call.sessionId = session.id; call.callId = session.callId || null;
      call.sequence = Number(session?.input?.nextSequence || 1); call.eventCursor = 0;
      call.generationFloor = Math.max(0, Number(session.generation || 0) - (['processing', 'speaking'].includes(session.state) ? 1 : 0));
      call.allocating = { kind: 'renderer', promise: request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}/renderer`, { method: 'POST', body: {} }) };
      const rendererPayload = await call.allocating.promise;
      call.allocating = null;
      if (cancelled()) return;
      await joinRenderer(rendererPayload?.renderer);
      if (cancelled()) return;
      await startMicrophone(stream, epoch);
      if (cancelled()) return;
      if (!call.rendererReady) call.mediaTimer = setTimeout(() => { void fail(new Error('Lola live media did not arrive. Please reconnect.')); }, 20_000);
      publish(call.rendererReady ? 'listening' : 'connecting', call.rendererReady ? 'Call connected' : 'Waiting for Lola live media');
      void pollEvents();
    } catch (error) {
      stream?.getTracks?.().forEach(track => track.stop());
      if (cancelled()) return;
      await fail(error);
      throw error;
    }
  }
  function hangup(options = {}) {
    if (call.stopping) return call.stopping;
    call.stopping = closeSession(options).finally(() => { call.stopping = null; });
    return call.stopping;
  }
  async function closeSession({ phase = 'ended', detail = '', remoteEnded = false } = {}) {
    if (call.closed || call.phase === 'idle') return;
    publish('ending', 'Ending call');
    call.closed = true; call.epoch += 1; cancelPlayback(); stopPoll();
    clearTimeout(call.mediaTimer); call.mediaTimer = null;
    const allocating = call.allocating;
    call.rendererReady = false;
    onSignal({ source: 'renderer', available: false });
    onSignal({ source: 'microphone', voiced: false });
    if (call.processor) call.processor.onaudioprocess = null;
    for (const node of [call.mediaSource, call.processor, call.silentGain]) {
      try { node?.disconnect?.(); } catch {}
    }
    call.stream?.getTracks?.().forEach(track => track.stop());
    try { await call.daily?.leave?.(); } catch {}
    try { await call.daily?.destroy?.(); } catch {}
    // Let an in-flight allocation resolve before deleting its canonical session.
    // Local capture is already stopped; a late renderer must not outlive its cleanup.
    let allocationFailed = false;
    if (allocating) {
      try {
        const allocated = await allocating.promise;
        if (allocating.kind === 'session' && allocated?.id) call.sessionId = allocated.id;
      } catch { allocationFailed = true; }
      call.allocating = null;
    }
    let ended = null;
    if (call.sessionId && !remoteEnded) {
      ended = await request(`/api/v1/body/voice/sessions/${encodeURIComponent(call.sessionId)}`, { method: 'DELETE' }).catch(error => ({ ok: false, error: error.message }));
    }
    try { await call.audioContext?.close?.(); } catch {}
    call.stream = null; call.audioContext = null; call.daily = null; call.renderer = null;
    call.mediaSource = null; call.processor = null; call.silentGain = null;
    call.pendingPcm = []; call.sessionId = null; call.callId = null; call.eventCursor = 0;
    const uncertain = allocationFailed || ended?.ok === false || ended?.renderer?.cleanupRequired === true;
    publish(uncertain ? 'error' : phase, uncertain ? 'Call stopped on this phone. Remote cleanup could not be confirmed.' : detail || 'Call ended');
    return ended;
  }

  function snapshot() {
    return Object.freeze({ phase: call.phase, active: !call.closed, rendererReady: call.rendererReady, sessionId: call.sessionId, callId: call.callId, nextSequence: call.sequence });
  }

  return Object.freeze({ start, hangup, snapshot, interrupt: interruptForBargeIn });
}
