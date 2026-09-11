import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';

const appSource = readFileSync(new URL('../web/app.js', import.meta.url), 'utf8');
const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');

test('all browser entry modules parse with explicit ESM semantics', () => {
  for (const name of ['app', 'call', 'voice', 'attachments', 'sw']) {
    execFileSync(process.execPath, ['--input-type=module', '--check'], {
      input: readFileSync(new URL(`../web/${name}.js`, import.meta.url)), stdio: ['pipe', 'pipe', 'pipe']
    });
  }
});

// DOM contract fixture, not a browser or visual-layout proof. Execute the actual
// app entrypoint; only its browser/device/service dependencies are controlled.
function appFixture() {
  let focused = null;
  function element() {
    const classes = new Set();
    const node = {
      children: [], dataset: {}, style: {}, attributes: {}, handlers: new Map(),
      value: '', textContent: '', hidden: false, disabled: false, scrollHeight: 44,
      classList: {
        add: (...values) => values.forEach(value => classes.add(value)),
        remove: (...values) => values.forEach(value => classes.delete(value)),
        contains: value => classes.has(value),
        toggle(value, enabled) { if (enabled ?? !classes.has(value)) classes.add(value); else classes.delete(value); }
      },
      setAttribute(key, value) { this.attributes[key] = value; },
      removeAttribute(key) { delete this.attributes[key]; },
      addEventListener(name, callback) { this.handlers.set(name, callback); },
      append(...items) { this.children.push(...items); },
      replaceChildren(...items) { this.children = items; },
      querySelector() { return null; },
      focus() { focused = this; }, scrollIntoView() {},
      async click() { await this.handlers.get('click')?.({ preventDefault() {} }); }
    };
    return node;
  }
  const elements = new Map([...html.matchAll(/id="([^"]+)"/g)].map(match => [match[1], element()]));
  elements.get('callSurface').hidden = true;
  const body = element();
  const storage = new Map();
  let callOptions;
  let current = { active: false, phase: 'idle', rendererReady: false };
  let starts = 0;
  const voiceStops = [];
  const mediaFrame = element();
  const context = {
    console, URL, URLSearchParams, AbortSignal, crypto: webcrypto,
    location: { search: '', hash: '', pathname: '/' }, history: { replaceState() {} },
    document: { body, visibilityState: 'visible', getElementById: id => elements.get(id), createElement: element, addEventListener() {} },
    window: { matchMedia: () => ({ matches: false }) },
    navigator: { language: 'en-US', mediaDevices: { getUserMedia() {} } },
    RTCPeerConnection: class {},
    localStorage: { getItem: key => storage.get(key) || null, setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    createVoiceAdapter: options => ({
      capabilities: () => ({ speech_recognition: true, speech_synthesis: true }),
      setSpeakReplies: speakReplies => options.onState({ text: 'Voice ready', speakReplies, listening: false, speaking: false }),
      stopListening: value => voiceStops.push(value), stopSpeaking() {}, isSpeaking: () => false
    }),
    createCallController: options => {
      callOptions = options;
      return {
        snapshot: () => current,
        async start() {
          starts += 1;
          options.videoHost.append(mediaFrame);
          current = { active: true, phase: 'listening', rendererReady: true, detail: 'Call connected' };
          options.onState(current);
        },
        async hangup() {
          current = { active: false, phase: 'ended', rendererReady: false, detail: 'Call ended' };
          options.onState(current);
        }
      };
    },
    Daily: {}, prepareAttachments() {}, validateAttachmentFiles: value => value
  };
  vm.runInNewContext(appSource.replace(/^import .*;\r?\n/gm, ''), context, { filename: 'web/app.js' });
  return { elements, body, storage, context, voiceStops, mediaFrame, callOptions, starts: () => starts, focused: () => focused };
}

test('entrypoint boots unpaired and Chat/Call retain the same media instance and draft', async () => {
  const f = appFixture();
  const el = id => f.elements.get(id);
  assert.equal(el('statusText').textContent, 'Not connected');
  assert.equal(el('callBtn').disabled, true);
  await el('chatBtn').click();
  assert.equal(f.focused(), el('chatInput'));
  f.storage.set('ecompanion.device_token', 'fixture-device-scope');
  f.context.renderPairingSurface();
  assert.equal(el('callBtn').disabled, false);
  await el('callBtn').click();
  assert.equal(f.voiceStops.at(-1).discard, true);
  assert.equal(el('callSurface').hidden, false);
  assert.equal(el('callState').classList.contains('sr-only'), true);
  assert.equal(el('voiceBtn').disabled, true);
  el('chatInput').value = 'Keep this multiline\ndraft';
  await el('callChatBtn').click();
  assert.equal(f.body.classList.contains('call-docked'), true);
  assert.equal(f.body.classList.contains('call-open'), false);
  await el('callBtn').click();
  assert.equal(f.starts(), 1, 'returning to Call must not create another session');
  assert.equal(el('callVideo').children[0], f.mediaFrame);
  assert.equal(el('chatInput').value, 'Keep this multiline\ndraft');
  f.callOptions.onTurn({ transcript: 'Hello', replyText: 'Hi' });
  assert.equal(el('callTranscript').textContent, 'You: Hello\nLola: Hi');
  f.callOptions.onState({ active: false, phase: 'error', rendererReady: false, detail: 'Microphone denied' });
  assert.equal(el('callSurface').hidden, false);
  assert.equal(el('callState').classList.contains('sr-only'), false);
  assert.equal(el('callState').textContent, 'Microphone denied');
});
