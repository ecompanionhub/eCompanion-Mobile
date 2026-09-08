import { prepareAttachments, validateAttachmentFiles } from './attachments.js';
import { createVoiceAdapter } from './voice.js';

const $ = (id) => document.getElementById(id);

const output = $('output');
const statusDot = $('statusDot');
const statusText = $('statusText');
const capabilitiesEl = $('capabilities');
const messagesEl = $('messages');
const chatNotice = $('chatNotice');
const chatTitle = $('chatTitle');
const chatMeta = $('chatMeta');
const chatInput = $('chatInput');
const sendBtn = $('sendBtn');
const attachBtn = $('attachBtn');
const attachmentInput = $('attachmentInput');
const attachmentTray = $('attachmentTray');
const voiceBtn = $('voiceBtn');
const speakToggle = $('speakToggle');
const voiceState = $('voiceState');
const setupSection = $('setupSection');
const mobileHero = $('mobileHero');
const mobileIntro = $('mobileIntro');

const DEFAULT_RUNTIME = 'https://ecompanion-ene7.onrender.com';

const STORAGE = Object.freeze({
  deviceId: 'ecompanion.device_id',
  runtimeBase: 'ecompanion.runtime_base',
  deviceLabel: 'ecompanion.device_label',
  deviceToken: 'ecompanion.device_token',
  credentialId: 'ecompanion.credential_id',
  speakReplies: 'ecompanion.voice.speak_replies'
});

const savedDeviceId = localStorage.getItem(STORAGE.deviceId);
let deviceId = savedDeviceId || `ebody:${crypto.randomUUID()}`;
if (!savedDeviceId) localStorage.setItem(STORAGE.deviceId, deviceId);

let selectedFiles = [];
let turnInFlight = false;

function normalizedHttpUrl(value) {
  const raw = String(value ?? '').trim().replace(/\/$/, '');
  if (!raw) return '';
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error('The eCompanion connection address is invalid');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('The eCompanion connection must use http:// or https://');
  }
  return parsed.href.replace(/\/$/, '');
}

const runtimeFromQuery = new URLSearchParams(location.search).get('runtime');
localStorage.removeItem(STORAGE.runtimeBase);
let initialRuntime = DEFAULT_RUNTIME;
try {
  initialRuntime = normalizedHttpUrl(runtimeFromQuery || DEFAULT_RUNTIME);
} catch {
  initialRuntime = DEFAULT_RUNTIME;
}

const hashParams = new URLSearchParams(location.hash.replace(/^#/, ''));
let pendingRelinkCode = String(hashParams.get('relink') || '').trim();
if (pendingRelinkCode) {
  history.replaceState(null, '', `${location.pathname}${location.search}`);
}

$('runtimeBase').value = initialRuntime;
$('deviceLabel').value = localStorage.getItem(STORAGE.deviceLabel) || 'My iPhone';
if (pendingRelinkCode) {
  $('pairingCode').value = pendingRelinkCode;
  $('pairBtn').textContent = 'Reconnect';
}

function resizeComposer() {
  chatInput.style.height = 'auto';
  chatInput.style.height = `${Math.min(150, chatInput.scrollHeight)}px`;
}

function appendVoiceDraft(transcript) {
  const current = chatInput.value.trim();
  chatInput.value = current ? `${current}\n${transcript}` : transcript;
  resizeComposer();
  chatInput.focus();
}

const voiceAdapter = createVoiceAdapter({
  language: navigator.language || 'en-US',
  onTranscript: async (transcript) => {
    if (turnInFlight) {
      appendVoiceDraft(transcript);
      showChatNotice('I heard you. Your next message is ready to send when this turn finishes.');
      return;
    }
    chatInput.value = transcript;
    resizeComposer();
    await run(() => sendChatContent(transcript, { clearInput: true }))
      .catch((error) => renderChatError(error, { preserveMessages: true }));
  },
  onState: ({ listening, speaking, speakReplies, text }) => {
    voiceBtn.textContent = listening ? '■' : '◉';
    voiceBtn.classList.toggle('voice-listening', listening);
    voiceBtn.setAttribute('aria-pressed', listening ? 'true' : 'false');
    voiceBtn.setAttribute('aria-label', listening ? 'Stop listening' : speaking ? 'Interrupt and talk' : 'Talk to Lola');
    speakToggle.textContent = speakReplies ? 'Replies on' : 'Replies off';
    speakToggle.setAttribute('aria-pressed', speakReplies ? 'true' : 'false');
    voiceState.textContent = text;
  }
});

const savedSpeakReplies = localStorage.getItem(STORAGE.speakReplies);
voiceAdapter.setSpeakReplies(savedSpeakReplies !== 'false');

function detectCapabilities() {
  const voiceCapabilities = voiceAdapter.capabilities();
  return Object.freeze({
    display: true,
    audio_output: typeof Audio !== 'undefined' || voiceCapabilities.speech_synthesis,
    microphone: Boolean(navigator.mediaDevices?.getUserMedia),
    camera: Boolean(navigator.mediaDevices?.getUserMedia),
    webrtc: typeof RTCPeerConnection !== 'undefined',
    notifications: 'Notification' in window,
    web_push: 'PushManager' in window && 'serviceWorker' in navigator,
    service_worker: 'serviceWorker' in navigator,
    standalone: window.matchMedia?.('(display-mode: standalone)').matches || Boolean(navigator.standalone),
    ...voiceCapabilities
  });
}

const capabilities = detectCapabilities();
speakToggle.disabled = !capabilities.speech_synthesis;
if (!capabilities.speech_recognition && capabilities.speech_synthesis) {
  voiceState.textContent = 'Voice input is unavailable here · spoken replies are available';
} else if (!capabilities.speech_recognition && !capabilities.speech_synthesis) {
  voiceState.textContent = 'Voice is unavailable in this browser';
} else {
  voiceState.textContent = 'Voice ready';
}

function capabilityLabel(name) {
  const labels = {
    display: 'Display',
    audio_output: 'Audio',
    microphone: 'Microphone',
    camera: 'Camera',
    webrtc: 'Live calls',
    notifications: 'Notifications',
    web_push: 'Push',
    service_worker: 'Background support',
    standalone: 'Installed app',
    speech_recognition: 'Voice input',
    speech_synthesis: 'Spoken replies'
  };
  return labels[name] || name.replaceAll('_', ' ');
}

function renderCapabilities() {
  capabilitiesEl.replaceChildren();
  for (const [name, enabled] of Object.entries(capabilities)) {
    const item = document.createElement('span');
    item.className = `cap${enabled ? ' on' : ''}`;
    item.textContent = enabled ? capabilityLabel(name) : `${capabilityLabel(name)} unavailable`;
    capabilitiesEl.append(item);
  }
}

function currentToken() {
  return localStorage.getItem(STORAGE.deviceToken) || '';
}

function currentCredentialId() {
  return localStorage.getItem(STORAGE.credentialId) || '';
}

function clearLocalCredential() {
  localStorage.removeItem(STORAGE.deviceToken);
  localStorage.removeItem(STORAGE.credentialId);
}

function showChatNotice(text = '') {
  const value = String(text || '').trim();
  chatNotice.textContent = value;
  chatNotice.hidden = !value;
}

function renderPairingSurface() {
  const paired = Boolean(currentToken());
  setupSection.hidden = paired && !pendingRelinkCode;
  sendBtn.disabled = !paired || turnInFlight;
  attachBtn.disabled = !paired || turnInFlight;
  voiceBtn.disabled = !paired || !capabilities.speech_recognition;
  if (paired) {
    mobileHero.textContent = `${chatTitle.textContent || 'Lola'}, with you.`;
    mobileIntro.textContent = 'Continue the conversation from your phone. Device access stays scoped to this device.';
  } else if (pendingRelinkCode) {
    mobileHero.textContent = 'Reconnect this phone.';
    mobileIntro.textContent = 'Your one-time reconnect link is ready. No system settings are required.';
  } else {
    mobileHero.textContent = 'Bring Lola with you.';
    mobileIntro.textContent = 'Connect this phone once, then eCompanion opens directly into your companion.';
  }
}

function bodyIdentity(extra = {}) {
  return {
    protocol: 'ecompanion-body-web-v1',
    device_id: deviceId,
    platform: 'web-pwa',
    paired: Boolean(currentToken()),
    credential_id: currentCredentialId() || null,
    capabilities,
    ...extra
  };
}

function renderBodyIdentity(extra = {}) {
  $('bodyInfo').textContent = JSON.stringify(bodyIdentity(extra), null, 2);
}

function show(payload) {
  output.textContent = typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2);
}

function setStatus(ok, text) {
  statusDot.classList.toggle('ok', Boolean(ok));
  statusText.textContent = text;
}

function runtimeBase() {
  const value = normalizedHttpUrl($('runtimeBase').value || DEFAULT_RUNTIME);
  if (!value) throw new Error('eCompanion is not connected to Runtime');
  return value;
}

function deviceDescriptor() {
  const label = $('deviceLabel').value.trim();
  if (!label) throw new Error('Give this device a name');
  localStorage.setItem(STORAGE.deviceLabel, label);
  return {
    id: deviceId,
    label,
    platform: 'web-pwa',
    capabilities,
    metadata: {
      body_protocol: 'ecompanion-body-web-v1',
      install_mode: capabilities.standalone ? 'standalone' : 'browser'
    }
  };
}

function runtimeErrorMessage(payload, status) {
  const code = String(payload?.error || '').trim();
  const message = String(payload?.message || '').trim();
  if (code === 'BODY_COMPANION_NOT_CONFIGURED') return 'This phone is connected, but no companion is assigned to it yet.';
  if (status === 401 || status === 403) return 'This device connection is no longer authorized. Reconnect this phone.';
  if (message && message !== 'Runtime operation failed') return message;
  if (status >= 500) return 'eCompanion is temporarily unavailable.';
  if (code) return code;
  return 'That action could not be completed.';
}

async function parseResponse(response) {
  const contentType = String(response.headers.get('content-type') || '').toLowerCase();
  if (!contentType.includes('application/json')) {
    const error = new Error('eCompanion returned an unexpected response.');
    error.status = response.status;
    error.payload = {
      status: response.status,
      content_type: contentType || null,
      runtime_base: $('runtimeBase').value.trim() || null
    };
    throw error;
  }

  const payload = await response.json().catch(() => ({ ok: false, error: 'invalid_json_response' }));
  if (!response.ok) {
    const error = new Error(runtimeErrorMessage(payload, response.status));
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

async function pairingRequest(code) {
  const response = await fetch(`${runtimeBase()}/api/v1/device-pairing/claim`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code, device: deviceDescriptor() }),
    cache: 'no-store'
  });
  return parseResponse(response);
}

async function bodyRequest(path, { method = 'GET', body } = {}) {
  const token = currentToken();
  if (!token) throw new Error('Connect this phone to eCompanion first.');
  const response = await fetch(`${runtimeBase()}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined,
    cache: 'no-store'
  });
  return parseResponse(response);
}

async function run(action) {
  try {
    const result = await action();
    show(result);
    return result;
  } catch (error) {
    setStatus(false, 'Needs attention');
    show({ ok: false, error: error.message, details: error.payload || null });
    throw error;
  }
}

function formatBytes(value) {
  const bytes = Number(value || 0);
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function fileTypeLabel(value) {
  const kind = String(value || 'document');
  return kind === 'image' ? 'Image' : kind === 'audio' ? 'Audio' : kind === 'video' ? 'Video' : 'File';
}

function renderSelectedAttachments() {
  attachmentTray.replaceChildren();
  attachmentTray.hidden = selectedFiles.length === 0;
  for (const [index, file] of selectedFiles.entries()) {
    const chip = document.createElement('div');
    chip.className = 'attachment-chip';
    const label = document.createElement('span');
    label.textContent = `${file.name || 'Attachment'} · ${formatBytes(file.size)}`;
    const remove = document.createElement('button');
    remove.className = 'attachment-remove';
    remove.type = 'button';
    remove.setAttribute('aria-label', `Remove ${file.name || 'attachment'}`);
    remove.textContent = '×';
    remove.addEventListener('click', () => {
      selectedFiles = selectedFiles.filter((_, candidateIndex) => candidateIndex !== index);
      renderSelectedAttachments();
    });
    chip.append(label, remove);
    attachmentTray.append(chip);
  }
}

function persistedAttachments(item) {
  const value = item?.metadata?.attachments;
  if (!Array.isArray(value)) return [];
  return value.filter(entry => entry && typeof entry === 'object' && !Array.isArray(entry));
}

function appendAttachmentBadges(container, items) {
  if (!items.length) return;
  const wrap = document.createElement('div');
  wrap.className = 'message-attachments';
  for (const item of items) {
    const badge = document.createElement('span');
    badge.className = 'message-attachment';
    const kind = fileTypeLabel(item.kind);
    const filename = String(item.filename || kind);
    const size = Number(item.byte_size ?? item.byteSize ?? 0);
    badge.textContent = size ? `${kind} · ${filename} · ${formatBytes(size)}` : `${kind} · ${filename}`;
    wrap.append(badge);
  }
  container.append(wrap);
}

function renderMessages(items) {
  messagesEl.replaceChildren();
  if (!items.length) {
    const empty = document.createElement('div');
    empty.className = 'empty-chat';
    empty.textContent = 'No messages yet. Say something to Lola.';
    messagesEl.append(empty);
    return;
  }
  for (const item of items) {
    if (item.role !== 'user' && item.role !== 'assistant' && item.role !== 'system') continue;
    const bubble = document.createElement('div');
    bubble.className = `bubble ${item.role}`;
    const text = String(item.content || '');
    if (text) {
      const content = document.createElement('span');
      content.textContent = text;
      bubble.append(content);
    }
    appendAttachmentBadges(bubble, persistedAttachments(item));
    messagesEl.append(bubble);
  }
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function renderPendingTurn(content, attachments = []) {
  showChatNotice('');
  const empty = messagesEl.querySelector('.empty-chat');
  if (empty) empty.remove();
  const user = document.createElement('div');
  user.className = 'bubble user';
  if (content) {
    const text = document.createElement('span');
    text.textContent = content;
    user.append(text);
  }
  appendAttachmentBadges(user, attachments);
  const pending = document.createElement('div');
  pending.className = 'bubble system';
  pending.dataset.pending = 'true';
  pending.textContent = attachments.length ? 'Lola is looking at what you sent…' : 'Lola is responding…';
  messagesEl.append(user, pending);
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function renderChat(chat) {
  showChatNotice('');
  chatTitle.textContent = String(chat?.companion?.name || 'Lola');
  chatMeta.textContent = chat?.conversation ? 'Conversation connected' : 'Ready when you are';
  renderMessages(Array.isArray(chat?.messages) ? chat.messages : []);
  renderPairingSurface();
}

function renderChatError(error, { preserveMessages = false } = {}) {
  const unauthorized = error?.status === 401 || error?.status === 403;
  if (unauthorized) {
    clearLocalCredential();
    setStatus(false, 'Reconnect needed');
  }

  const hasConversation = preserveMessages && messagesEl.children.length > 0 && !messagesEl.querySelector('.empty-chat');
  if (hasConversation && currentToken()) {
    messagesEl.querySelector('[data-pending="true"]')?.remove();
    showChatNotice(error?.message || 'The conversation could not refresh. Your saved messages are still here.');
    chatMeta.textContent = 'Needs attention';
    renderPairingSurface();
    return;
  }

  messagesEl.replaceChildren();
  const empty = document.createElement('div');
  empty.className = 'empty-chat';
  if (unauthorized) {
    empty.textContent = 'This device connection expired or was revoked. Reconnect this phone to continue.';
    chatMeta.textContent = 'Reconnect needed';
  } else if (error?.payload?.error === 'BODY_COMPANION_NOT_CONFIGURED') {
    empty.textContent = 'This phone is connected, but a companion still needs to be assigned in eCompanion.';
    chatMeta.textContent = 'Companion assignment needed';
  } else if (!currentToken() && pendingRelinkCode) {
    empty.textContent = 'Your reconnect link is ready. Tap Reconnect below.';
    chatMeta.textContent = 'Reconnect ready';
  } else if (!currentToken()) {
    empty.textContent = 'Connect this phone once to start talking to Lola.';
    chatMeta.textContent = 'Device not connected';
  } else {
    empty.textContent = error?.message || 'Conversation unavailable.';
    chatMeta.textContent = 'Conversation unavailable';
  }
  showChatNotice('');
  messagesEl.append(empty);
  renderPairingSurface();
}

async function loadChat({ preserveOnError = true } = {}) {
  try {
    const result = await bodyRequest('/api/v1/body/chat?limit=100');
    renderChat(result.chat);
    return result;
  } catch (error) {
    renderChatError(error, { preserveMessages: preserveOnError });
    throw error;
  }
}

async function refreshSelf() {
  const result = await bodyRequest('/api/v1/body/me');
  const device = result.body?.device;
  if (device?.id && device.id !== deviceId) {
    deviceId = device.id;
    localStorage.setItem(STORAGE.deviceId, deviceId);
  }
  renderBodyIdentity({
    assigned_actor_id: device?.assigned_actor_id ?? null,
    runtime_device: device ?? null
  });
  setStatus(true, device?.assigned_actor_id ? 'Connected' : 'Connected · setup needed');
  renderPairingSurface();
  return result;
}

async function sendChatContent(value, { clearInput = false } = {}) {
  if (turnInFlight) throw new Error('Lola is still answering this turn. Your next message can stay in the composer.');
  const text = String(value || '').trim();
  const files = [...selectedFiles];
  if (!text && files.length === 0) throw new Error('Write a message or attach a file first.');

  turnInFlight = true;
  renderPairingSurface();
  const originalComposerValue = chatInput.value;

  try {
    if (files.length) showChatNotice(files.length === 1 ? 'Preparing your file…' : 'Preparing your files…');
    const attachments = files.length ? await prepareAttachments(files) : [];
    const turnContent = attachments.length ? { text, attachments } : text;
    renderPendingTurn(text, attachments);

    const result = await bodyRequest('/api/v1/body/chat/turn', {
      method: 'POST',
      body: { content: turnContent }
    });

    if (clearInput && chatInput.value === originalComposerValue) {
      chatInput.value = '';
      resizeComposer();
    }
    selectedFiles = [];
    attachmentInput.value = '';
    renderSelectedAttachments();
    setStatus(true, 'Connected');
    await loadChat({ preserveOnError: true });
    setPresence('available').catch(() => null);
    const assistantText = result.chat?.turn?.assistantMessage?.content;
    if (assistantText) voiceAdapter.speak(assistantText);
    return result;
  } catch (error) {
    await loadChat({ preserveOnError: true }).catch(() => {
      renderChatError(error, { preserveMessages: true });
      if (currentToken()) {
        showChatNotice('Connection interrupted while sending. Refresh the conversation before sending again to avoid a duplicate message.');
      }
    });
    throw error;
  } finally {
    turnInFlight = false;
    renderPairingSurface();
    chatInput.focus();
  }
}

$('pairBtn').addEventListener('click', () => run(async () => {
  const code = $('pairingCode').value.trim();
  if (!code) throw new Error('Enter the one-time pairing code.');
  $('pairBtn').disabled = true;
  $('pairBtn').textContent = pendingRelinkCode ? 'Reconnecting…' : 'Connecting…';
  try {
    const result = await pairingRequest(code);
    const token = result.credential?.token;
    if (!token) {
      const error = new Error('eCompanion did not return a device credential.');
      error.payload = result;
      throw error;
    }

    if (result.device?.id) {
      deviceId = result.device.id;
      localStorage.setItem(STORAGE.deviceId, deviceId);
    }
    if (result.device?.label) {
      $('deviceLabel').value = result.device.label;
      localStorage.setItem(STORAGE.deviceLabel, result.device.label);
    }

    localStorage.setItem(STORAGE.deviceToken, token);
    if (result.credential?.id) localStorage.setItem(STORAGE.credentialId, result.credential.id);
    $('pairingCode').value = '';
    pendingRelinkCode = '';
    setStatus(true, result.relinked ? 'Reconnected' : 'Connected');
    renderBodyIdentity({ assigned_actor_id: result.device?.assigned_actor_id ?? null });
    renderPairingSurface();
    await loadChat({ preserveOnError: false }).catch(() => null);
    setPresence('available').catch(() => null);
    return result;
  } finally {
    $('pairBtn').disabled = false;
    $('pairBtn').textContent = 'Connect';
  }
}).catch(() => {}));

$('connectBtn').addEventListener('click', () => run(async () => {
  const result = await refreshSelf();
  await loadChat({ preserveOnError: true }).catch(() => null);
  return result;
}).catch(() => {}));

$('syncDeviceBtn').addEventListener('click', () => run(async () => {
  const descriptor = deviceDescriptor();
  const result = await bodyRequest('/api/v1/body/device', {
    method: 'PUT',
    body: {
      label: descriptor.label,
      platform: descriptor.platform,
      capabilities: descriptor.capabilities,
      metadata: descriptor.metadata
    }
  });
  setStatus(true, 'Device refreshed');
  return result;
}).catch(() => {}));

async function setPresence(state) {
  const result = await bodyRequest('/api/v1/body/presence', {
    method: 'PUT',
    body: {
      state,
      details: {
        body_protocol: 'ecompanion-body-web-v1',
        capabilities,
        surface: document.visibilityState
      }
    }
  });
  setStatus(state !== 'offline', state === 'available' ? 'Connected' : state === 'away' ? 'Connected · away' : 'Offline');
  return result;
}

$('availableBtn').addEventListener('click', () => run(() => setPresence('available')).catch(() => {}));
$('offlineBtn').addEventListener('click', () => run(() => setPresence('offline')).catch(() => {}));
$('refreshChatBtn').addEventListener('click', () => run(() => loadChat({ preserveOnError: true })).catch(() => {}));

attachBtn.addEventListener('click', () => {
  if (!currentToken()) {
    renderChatError(new Error('Connect this phone before sharing files.'));
    return;
  }
  attachmentInput.click();
});

attachmentInput.addEventListener('change', () => {
  try {
    selectedFiles = validateAttachmentFiles([...selectedFiles, ...Array.from(attachmentInput.files || [])]);
    renderSelectedAttachments();
    showChatNotice('');
  } catch (error) {
    showChatNotice(error.message);
  } finally {
    attachmentInput.value = '';
  }
});

$('chatForm').addEventListener('submit', (event) => {
  event.preventDefault();
  if (turnInFlight) {
    showChatNotice('Lola is still answering. Your next message can stay here and will not be sent until you press Send after this turn finishes.');
    return;
  }
  run(() => sendChatContent(chatInput.value, { clearInput: true }))
    .catch((error) => renderChatError(error, { preserveMessages: true }));
});

chatInput.addEventListener('input', () => {
  if (voiceAdapter.isSpeaking()) voiceAdapter.stopSpeaking();
  resizeComposer();
});

chatInput.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing && window.matchMedia('(pointer:fine)').matches) {
    event.preventDefault();
    $('chatForm').requestSubmit();
  }
});

voiceBtn.addEventListener('click', () => {
  if (!currentToken()) {
    const error = new Error('Connect this phone before using voice.');
    renderChatError(error);
    show({ ok: false, error: error.message });
    return;
  }
  try {
    voiceAdapter.toggleListening();
  } catch (error) {
    voiceState.textContent = error.message;
    show({ ok: false, error: error.message });
  }
});

speakToggle.addEventListener('click', () => {
  const enabled = !voiceAdapter.speakRepliesEnabled();
  localStorage.setItem(STORAGE.speakReplies, enabled ? 'true' : 'false');
  voiceAdapter.setSpeakReplies(enabled);
});

$('forgetBtn').addEventListener('click', () => {
  voiceAdapter.stopListening();
  voiceAdapter.stopSpeaking();
  clearLocalCredential();
  selectedFiles = [];
  attachmentInput.value = '';
  renderSelectedAttachments();
  setStatus(false, 'Forgotten on this phone');
  renderBodyIdentity();
  renderPairingSurface();
  renderChatError(new Error('Connect this phone to eCompanion.'));
  show({ ok: true, local_pairing_removed: true, note: 'Server-side revocation remains owner-controlled.' });
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'visible') voiceAdapter.stopListening();
  if (!currentToken()) return;
  const state = document.visibilityState === 'visible' ? 'available' : 'away';
  setPresence(state).catch(() => null);
});

renderCapabilities();
renderSelectedAttachments();
renderBodyIdentity();
renderPairingSurface();
if (currentToken()) {
  refreshSelf()
    .then(() => Promise.allSettled([loadChat({ preserveOnError: false }), setPresence(document.visibilityState === 'visible' ? 'available' : 'away')]))
    .catch((error) => {
      renderChatError(error, { preserveMessages: false });
      if (currentToken()) setStatus(false, 'Connection unavailable');
    });
} else if (pendingRelinkCode) {
  setStatus(false, 'Reconnect ready');
  renderChatError(new Error('Reconnect this phone.'));
} else {
  setStatus(false, 'Not connected');
  renderChatError(new Error('Connect this phone.'));
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch((error) => {
    show({ ok: false, warning: 'service_worker_registration_failed', error: error.message });
  });
}
