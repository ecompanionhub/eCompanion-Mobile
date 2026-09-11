import assert from 'node:assert/strict';
import test from 'node:test';

import { createCallController, float32ToPcm16, resampleFloat32 } from '../web/call.js';

function fakeAudioContext() {
  return class FakeAudioContext {
    constructor() { this.state = 'running'; this.sampleRate = 16_000; this.destination = {}; }
    createMediaStreamSource() { return { connect() {}, disconnect() {} }; }
    createScriptProcessor() { return { onaudioprocess: null, connect() {}, disconnect() {} }; }
    createGain() { return { gain: { value: 1 }, connect() {}, disconnect() {} }; }
    async resume() { this.state = 'running'; }
    async close() { this.state = 'closed'; }
  };
}

function fakeStream() {
  const track = { stopped: false, stop() { this.stopped = true; } };
  return { track, stream: { getTracks: () => [track] } };
}

test('PCM conversion is deterministic for the Runtime 16 kHz contract', () => {
  const input = new Float32Array([0, 0.5, -0.5, 1, -1]);
  const resampled = resampleFloat32(input, 16_000, 16_000);
  assert.deepEqual([...resampled], [...input]);
  assert.deepEqual([...float32ToPcm16(input)], [0, 16384, -16384, 32767, -32768]);
});
function controllerFixture({ calls = [], requestOverride, mediaOverride, ready = true, joinError, audioOverride } = {}) {
  const requests = [];
  const states = [];
  const signals = [];
  const { track, stream } = fakeStream();
  const daily = {
    joined: null, left: 0, destroyed: 0, messages: [], handlers: new Map(),
    remote: ready ? { replica: { local: false, tracks: { video: { state: 'playable' }, audio: { state: 'playable' } } } } : {},
    on(name, handler) { this.handlers.set(name, handler); },
    emit(name, event) { this.handlers.get(name)?.(event); },
    participants() { return this.remote; },
    async join(options) { this.joined = options; if (joinError) throw new Error(joinError); },
    sendAppMessage(message) { this.messages.push(message); },
    async leave() { this.left += 1; },
    async destroy() { this.destroyed += 1; }
  };
  const request = async (path, options = {}) => {
    requests.push({ path, options });
    const override = await requestOverride?.(path, options);
    if (override !== undefined) return override;
    if (path === '/api/v1/body/voice/policy') return { voice: { configured: true, input: { encoding: 'pcm_s16le', sampleRate: 16_000, channels: 1 } } };
    if (path === '/api/v1/body/calls') return { calls };
    if (path === '/api/v1/body/voice/sessions' && options.method === 'POST') return { session: { id: 'voice-new', callId: 'call-new', input: { nextSequence: 1 } } };
    if (path === '/api/v1/body/voice/sessions/voice-existing') return { session: { id: 'voice-existing', callId: 'call-existing', input: { nextSequence: 7 } } };
    if (path.endsWith('/renderer')) return { renderer: { echo: true, protocol: 'daily', sessionId: 'renderer-1', joinUrl: 'https://room.example.test', joinToken: 'scoped-token' } };
    if (path.includes('/events?')) return { events: [] };
    if (options.method === 'DELETE') return { ok: true };
    return { ok: true };
  };
  const controller = createCallController({
    request, dailyFactory: () => daily, videoHost: {},
    onState: state => states.push(state), onSignal: signal => signals.push(signal),
    mediaDevices: { getUserMedia: mediaOverride || (async () => stream) },
    AudioContextCtor: audioOverride || fakeAudioContext()
  });
  return { controller, requests, daily, track, states, signals };
}
test('call start joins the scoped renderer and hangup closes both client and Runtime session', async () => {
  const { controller, requests, daily, track } = controllerFixture();
  await controller.start();
  assert.equal(controller.snapshot().sessionId, 'voice-new');
  assert.equal(daily.joined.url, 'https://room.example.test');
  assert.equal(daily.joined.token, 'scoped-token');
  assert.equal(daily.joined.startAudioOff, true);
  await controller.hangup();
  assert.equal(track.stopped, true);
  assert.equal(daily.left, 1);
  assert.equal(daily.destroyed, 1);
  assert.ok(requests.some(entry => entry.path === '/api/v1/body/voice/sessions/voice-new' && entry.options.method === 'DELETE'));
  assert.equal(controller.snapshot().active, false);
});

test('reconnect resumes a non-expired canonical session without creating a second call', async () => {
  const { controller, requests } = controllerFixture({ calls: [{ id: 'voice-existing', chatId: 'body', state: 'listening', expiresAt: new Date(Date.now() + 60_000).toISOString() }] });
  await controller.start();
  assert.equal(controller.snapshot().sessionId, 'voice-existing');
  assert.equal(controller.snapshot().nextSequence, 7);
  assert.equal(requests.filter(entry => entry.path === '/api/v1/body/voice/sessions' && entry.options.method === 'POST').length, 0);
  assert.equal(requests.filter(entry => entry.path.endsWith('/renderer') && entry.options.method === 'POST').length, 1);
  await controller.hangup();
});

const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}

test('room join alone never claims live Lola media', async () => {
  const { controller, daily, states } = controllerFixture({ ready: false });
  try {
    await controller.start();
    assert.equal(controller.snapshot().phase, 'connecting');
    assert.equal(controller.snapshot().rendererReady, false);
    daily.remote = { replica: { local: false, tracks: { video: { state: 'playable' }, audio: { state: 'playable' } } } };
    daily.emit('participant-updated');
    assert.equal(controller.snapshot().phase, 'listening');
    assert.equal(states.at(-1).rendererReady, true);
  } finally { await controller.hangup(); }
});

test('failed renderer join releases microphone, Daily and Runtime before retry', async () => {
  const { controller, daily, track, requests } = controllerFixture({ joinError: 'Join rejected' });
  await assert.rejects(controller.start(), /Join rejected/);
  assert.equal(track.stopped, true);
  assert.equal(daily.destroyed, 1);
  assert.equal(controller.snapshot().active, false);
  assert.equal(controller.snapshot().phase, 'error');
  assert.equal(requests.filter(entry => entry.options.method === 'DELETE').length, 1);
});

test('ending during microphone permission cannot create or join a late call', async () => {
  const permission = deferred();
  const late = fakeStream();
  const { controller, requests, daily } = controllerFixture({ mediaOverride: () => permission.promise });
  const starting = controller.start();
  await tick();
  await controller.hangup();
  permission.resolve(late.stream);
  await starting;
  assert.equal(late.track.stopped, true);
  assert.equal(daily.joined, null);
  assert.equal(requests.some(entry => entry.path.endsWith('/sessions')), false);
  assert.equal(controller.snapshot().phase, 'ended');
});

test('ending during session creation cleans the late canonical session without joining', async () => {
  const creation = deferred();
  const { controller, requests, daily } = controllerFixture({ requestOverride: (path, options) =>
    path.endsWith('/sessions') && options.method === 'POST' ? creation.promise : undefined });
  const starting = controller.start();
  await tick();
  const ending = controller.hangup();
  creation.resolve({ session: { id: 'late-session' } });
  await ending;
  await starting;
  assert.equal(daily.joined, null);
  assert.equal(requests.filter(entry => entry.path.endsWith('/late-session') && entry.options.method === 'DELETE').length, 1);
});

test('canonical session-ended event stops local microphone and renderer', async () => {
  const { controller, track, daily, states } = controllerFixture({ requestOverride: path => path.includes('/events?')
    ? { events: [{ sequence: 1, type: 'session.ended', payload: {} }] } : undefined });
  await controller.start();
  await tick();
  assert.equal(track.stopped, true);
  assert.equal(daily.destroyed, 1);
  assert.equal(states.at(-1).phase, 'ended');
});

test('renderer media loss stops capture and exposes a failure', async () => {
  const { controller, daily, track } = controllerFixture();
  await controller.start();
  daily.remote = {};
  daily.emit('participant-left');
  await tick();
  assert.equal(track.stopped, true);
  assert.equal(controller.snapshot().phase, 'error');
  assert.equal(controller.snapshot().rendererReady, false);
});

test('remote cleanup failure is never reported as a successfully ended call', async () => {
  const { controller, states } = controllerFixture({ requestOverride: (path, options) => options.method === 'DELETE'
    ? { ok: true, renderer: { ended: false, cleanupRequired: true } } : undefined });
  await controller.start();
  await controller.hangup();
  assert.equal(states.at(-1).phase, 'error');
  assert.match(states.at(-1).detail, /could not be confirmed/);
  assert.equal(states.at(-1).active, false);
});

function outputFixture({ audioReady = true } = {}) {
  const Audio = fakeAudioContext();
  class DecodingAudio extends Audio {
    async decodeAudioData() { return { sampleRate: 24_000, getChannelData: () => new Float32Array([0, .1, -.1]) }; }
  }
  return controllerFixture({ audioOverride: DecodingAudio, requestOverride: path => {
    if (path.includes('/events?')) return { events: [{ sequence: 1, type: 'turn.output_ready', payload: { generation: 1 } }] };
    if (path.endsWith('/outputs/1')) return { output: { voice: { transcript: 'Hello', replyText: 'Hello there', synthesizedAudio: audioReady ? { status: 'ready', audioBase64: 'AA==' } : { status: 'unavailable' } } } };
    return undefined;
  } });
}
function speechEvent(fixture, type, inferenceId = 'voice-new:1', properties = {}) {
  fixture.daily.emit('app-message', { fromId: 'replica', data: { message_type: 'conversation', event_type: type,
    conversation_id: 'renderer-1', inference_id: inferenceId, properties: { role: 'replica', ...properties } } });
}

test('only matching actual renderer playback events can acknowledge output', async () => {
  const fixture = outputFixture();
  const { controller, daily, requests } = fixture;
  const completions = () => requests.filter(entry => entry.path.endsWith('/playback-complete')).length;
  try {
    await controller.start();
    await tick();
    assert.equal(daily.messages.filter(message => message.event_type === 'conversation.echo').length, 1);
    assert.equal(completions(), 0, 'sending all audio must not acknowledge playback');
    assert.notEqual(controller.snapshot().phase, 'speaking');
    speechEvent(fixture, 'conversation.stopped_speaking');
    speechEvent(fixture, 'conversation.started_speaking', 'wrong-generation');
    await tick();
    assert.equal(completions(), 0);
    speechEvent(fixture, 'conversation.started_speaking');
    assert.equal(controller.snapshot().phase, 'speaking');
    speechEvent(fixture, 'conversation.stopped_speaking');
    speechEvent(fixture, 'conversation.replica.stopped_speaking');
    await tick();
    assert.equal(completions(), 1);
    assert.equal(controller.snapshot().phase, 'listening');
  } finally { await controller.hangup(); }
});

test('barge-in interrupts both buffered renderer media and canonical Runtime generation', async () => {
  const fixture = outputFixture();
  try {
    await fixture.controller.start();
    await tick();
    speechEvent(fixture, 'conversation.started_speaking');
    await fixture.controller.interrupt();
    speechEvent(fixture, 'conversation.stopped_speaking');
    await tick();
    assert.ok(fixture.daily.messages.some(message => message.event_type === 'conversation.interrupt'));
    assert.ok(fixture.requests.some(entry => entry.path.endsWith('/interrupt')));
    assert.equal(fixture.requests.some(entry => entry.path.endsWith('/playback-complete')), false);
  } finally { await fixture.controller.hangup(); }
});

test('unavailable canonical voice closes resources without fake playback completion', async () => {
  const { controller, requests, track } = outputFixture({ audioReady: false });
  await controller.start();
  await tick();
  assert.equal(controller.snapshot().phase, 'error');
  assert.equal(track.stopped, true);
  assert.equal(requests.some(entry => entry.path.endsWith('/playback-complete')), false);
});

test('a Social call is never resumed into the private Body surface', async () => {
  const { controller, requests } = controllerFixture({ calls: [{ id: 'social-session', chatId: 'telegram', state: 'listening' }] });
  try {
    await controller.start();
    assert.equal(controller.snapshot().sessionId, 'voice-new');
    assert.equal(requests.some(entry => entry.path.includes('social-session')), false);
  } finally { await controller.hangup(); }
});

test('hangup waits for a pending renderer allocation before canonical cleanup', async () => {
  const renderer = deferred();
  const { controller, requests, daily, track } = controllerFixture({ requestOverride: path => path.endsWith('/renderer') ? renderer.promise : undefined });
  const starting = controller.start();
  await tick();
  const ending = controller.hangup();
  await tick();
  assert.equal(track.stopped, true);
  assert.equal(requests.some(entry => entry.options.method === 'DELETE'), false);
  renderer.resolve({ renderer: { echo: true, protocol: 'daily', sessionId: 'late-renderer' } });
  await Promise.all([starting, ending]);
  assert.equal(daily.joined, null);
  assert.equal(requests.filter(entry => entry.options.method === 'DELETE').length, 1);
});

test('late renderer events after hangup cannot revive speech or acknowledge output', async () => {
  const fixture = outputFixture();
  await fixture.controller.start();
  await tick();
  await fixture.controller.hangup();
  speechEvent(fixture, 'conversation.started_speaking');
  speechEvent(fixture, 'conversation.stopped_speaking');
  await tick();
  assert.equal(fixture.controller.snapshot().phase, 'ended');
  assert.equal(fixture.requests.some(entry => entry.path.endsWith('/playback-complete')), false);
});

test('a repeated Call gesture allocates exactly one canonical session', async () => {
  const { controller, requests } = controllerFixture();
  try {
    await Promise.all([controller.start(), controller.start()]);
    assert.equal(requests.filter(entry => entry.path.endsWith('/sessions') && entry.options.method === 'POST').length, 1);
  } finally { await controller.hangup(); }
});

test('unconfigured voice fails before microphone permission or session allocation', async () => {
  let microphoneRequests = 0;
  const { controller, requests } = controllerFixture({ requestOverride: path => path.endsWith('/policy') ? { voice: { configured: false } } : undefined,
    mediaOverride: async () => { microphoneRequests += 1; return fakeStream().stream; } });
  await assert.rejects(controller.start(), /unavailable/);
  assert.equal(microphoneRequests, 0);
  assert.equal(requests.some(entry => entry.options.method === 'POST'), false);
});
