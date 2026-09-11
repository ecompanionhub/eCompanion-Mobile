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
function controllerFixture({ calls = [] } = {}) {
  const requests = [];
  const { track, stream } = fakeStream();
  const daily = {
    joined: null, left: 0, destroyed: 0,
    async join(options) { this.joined = options; },
    sendAppMessage() {},
    async leave() { this.left += 1; },
    async destroy() { this.destroyed += 1; }
  };
  const request = async (path, options = {}) => {
    requests.push({ path, options });
    if (path === '/api/v1/body/voice/policy') return { voice: { configured: true, input: { encoding: 'pcm_s16le', sampleRate: 16_000, channels: 1 } } };
    if (path === '/api/v1/body/calls') return { calls };
    if (path === '/api/v1/body/voice/sessions' && options.method === 'POST') return { session: { id: 'voice-new', callId: 'call-new', input: { nextSequence: 1 } } };
    if (path === '/api/v1/body/voice/sessions/voice-existing') return { session: { id: 'voice-existing', callId: 'call-existing', input: { nextSequence: 7 } } };
    if (path.endsWith('/renderer')) return { renderer: { protocol: 'daily', sessionId: 'renderer-1', joinUrl: 'https://room.example.test', joinToken: 'scoped-token' } };
    if (path.includes('/events?')) return { events: [] };
    if (options.method === 'DELETE') return { ok: true };
    return { ok: true };
  };
  const controller = createCallController({
    request, dailyFactory: () => daily, videoHost: {},
    mediaDevices: { async getUserMedia() { return stream; } },
    AudioContextCtor: fakeAudioContext()
  });
  return { controller, requests, daily, track };
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
  const { controller, requests } = controllerFixture({ calls: [{ id: 'voice-existing', state: 'listening', expiresAt: new Date(Date.now() + 60_000).toISOString() }] });
  await controller.start();
  assert.equal(controller.snapshot().sessionId, 'voice-existing');
  assert.equal(controller.snapshot().nextSequence, 7);
  assert.equal(requests.filter(entry => entry.path === '/api/v1/body/voice/sessions' && entry.options.method === 'POST').length, 0);
  assert.equal(requests.filter(entry => entry.path.endsWith('/renderer') && entry.options.method === 'POST').length, 1);
  await controller.hangup();
});