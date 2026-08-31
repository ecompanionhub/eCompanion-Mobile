const $ = (id) => document.getElementById(id);

const output = $('output');
const statusDot = $('statusDot');
const statusText = $('statusText');
const capabilitiesEl = $('capabilities');
const messagesEl = $('messages');
const chatTitle = $('chatTitle');
const chatMeta = $('chatMeta');
const chatInput = $('chatInput');
const sendBtn = $('sendBtn');

const STORAGE = Object.freeze({
  deviceId: 'ecompanion.device_id',
  runtimeBase: 'ecompanion.runtime_base',
  deviceLabel: 'ecompanion.device_label',
  deviceToken: 'ecompanion.device_token',
  credentialId: 'ecompanion.credential_id'
});

const savedDeviceId = localStorage.getItem(STORAGE.deviceId);
const deviceId = savedDeviceId || `ebody:${crypto.randomUUID()}`;
if (!savedDeviceId) localStorage.setItem(STORAGE.deviceId, deviceId);

function normalizedHttpUrl(value) {
  const raw = String(value ?? '').trim().replace(/\/$/, '');
  if (!raw) return '';
  let parsed;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error('Runtime base URL must be a valid http:// or https:// URL');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('Runtime base URL must start with http:// or https://');
  }
  return parsed.href.replace(/\/$/, '');
}

const runtimeFromQuery = new URLSearchParams(location.search).get('runtime');
const savedRuntime = localStorage.getItem(STORAGE.runtimeBase) || '';
let initialRuntime = '';
try {
  initialRuntime = normalizedHttpUrl(runtimeFromQuery || savedRuntime);
  if (runtimeFromQuery && initialRuntime) localStorage.setItem(STORAGE.runtimeBase, initialRuntime);
} catch {
  initialRuntime = '';
}

$('runtimeBase').value = initialRuntime;
$('deviceLabel').value = localStorage.getItem(STORAGE.deviceLabel) || 'eCompanion Body';

function detectCapabilities() {
  return Object.freeze({
    display: true,
    audio_output: typeof Audio !== 'undefined',
    microphone: Boolean(navigator.mediaDevices?.getUserMedia),
    camera: Boolean(navigator.mediaDevices?.getUserMedia),
    webrtc: typeof RTCPeerConnection !== 'undefined',
    notifications: 'Notification' in window,
    web_push: 'PushManager' in window && 'serviceWorker' in navigator,
    service_worker: 'serviceWorker' in navigator,
    standalone: window.matchMedia?.('(display-mode: standalone)').matches || Boolean(navigator.standalone)
  });
}

const capabilities = detectCapabilities();

function renderCapabilities() {
  capabilitiesEl.replaceChildren();
  for (const [name, enabled] of Object.entries(capabilities)) {
    const el = document.createElement('span');
    el.className = `cap${enabled ? ' on' : ''}`;
    el.textContent = `${name}: ${enabled ? 'yes' : 'no'}`;
    capabilitiesEl.append(el);
  }
}

function currentToken() {
  return localStorage.getItem(STORAGE.deviceToken) || '';
}

function currentCredentialId() {
  return localStorage.getItem(STORAGE.credentialId) || '';
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
  const value = normalizedHttpUrl($('runtimeBase').value);
  if (!value) throw new Error('Runtime base URL is required');
  localStorage.setItem(STORAGE.runtimeBase, value);
  return value;
}

function deviceDescriptor() {
  const label = $('deviceLabel').value.trim();
  if (!label) throw new Error('Device label is required');
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
  if (code && message && message !== 'Runtime operation failed') return `${code}: ${message}`;
  if (code) return code;
  if (message) return message;
  return `HTTP ${status}`;
}

async function parseResponse(response) {
  const contentType = String(response.headers.get('content-type') || '').toLowerCase();
  if (!contentType.includes('application/json')) {
    const error = new Error('Runtime endpoint returned a non-JSON response. Check that Runtime base URL points to eCompanion Runtime, not the body website.');
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
  if (!token) throw new Error('This body is not paired yet');
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
    setStatus(false, 'Connection/action failed');
    show({ ok: false, error: error.message, details: error.payload || null });
    throw error;
  }
}

function renderMessages(items) {
  messagesEl.replaceChildren();
  if (!items.length) {
    const empty = document.createElement('div');
    empty.className = 'empty-chat';
    empty.textContent = 'No messages yet. Say something.';
    messagesEl.append(empty);
    return;
  }
  for (const item of items) {
    if (item.role !== 'user' && item.role !== 'assistant' && item.role !== 'system') continue;
    const bubble = document.createElement('div');
    bubble.className = `bubble ${item.role}`;
    bubble.textContent = String(item.content || '');
    messagesEl.append(bubble);
  }
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function renderChat(chat) {
  chatTitle.textContent = String(chat?.companion?.name || 'Companion');
  chatMeta.textContent = chat?.conversation ? 'Connected · conversation active' : 'Connected · start a conversation';
  renderMessages(Array.isArray(chat?.messages) ? chat.messages : []);
}

function renderChatError(error) {
  messagesEl.replaceChildren();
  const empty = document.createElement('div');
  empty.className = 'empty-chat';
  if (error?.payload?.error === 'BODY_COMPANION_NOT_CONFIGURED') {
    empty.textContent = 'This paired body still needs a companion assignment in eHub Body setup.';
    chatMeta.textContent = 'Body paired · companion setup required';
  } else if (!currentToken()) {
    empty.textContent = 'Pair this body first.';
    chatMeta.textContent = 'Not paired';
  } else {
    empty.textContent = error?.message || 'Chat unavailable.';
    chatMeta.textContent = 'Chat unavailable';
  }
  messagesEl.append(empty);
}

async function loadChat() {
  try {
    const result = await bodyRequest('/api/v1/body/chat?limit=100');
    renderChat(result.chat);
    return result;
  } catch (error) {
    renderChatError(error);
    throw error;
  }
}

async function refreshSelf() {
  const result = await bodyRequest('/api/v1/body/me');
  const device = result.body?.device;
  renderBodyIdentity({
    assigned_actor_id: device?.assigned_actor_id ?? null,
    runtime_device: device ?? null
  });
  setStatus(true, device?.assigned_actor_id ? 'Paired · actor assigned' : 'Paired · no actor assigned');
  return result;
}

$('pairBtn').addEventListener('click', () => run(async () => {
  const code = $('pairingCode').value.trim();
  if (!code) throw new Error('Pairing code is required');
  const result = await pairingRequest(code);
  const token = result.credential?.token;
  if (!token) {
    const error = new Error('Runtime pairing response did not include a device credential');
    error.payload = result;
    throw error;
  }
  localStorage.setItem(STORAGE.deviceToken, token);
  if (result.credential?.id) localStorage.setItem(STORAGE.credentialId, result.credential.id);
  $('pairingCode').value = '';
  setStatus(true, 'Body paired');
  renderBodyIdentity({ assigned_actor_id: result.device?.assigned_actor_id ?? null });
  await loadChat().catch(() => null);
  return result;
}).catch(() => {}));

$('connectBtn').addEventListener('click', () => run(async () => {
  const result = await refreshSelf();
  await loadChat().catch(() => null);
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
  setStatus(true, 'Body capabilities synced');
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
  setStatus(state !== 'offline', `Presence: ${state}`);
  return result;
}

$('availableBtn').addEventListener('click', () => run(() => setPresence('available')).catch(() => {}));
$('offlineBtn').addEventListener('click', () => run(() => setPresence('offline')).catch(() => {}));
$('refreshChatBtn').addEventListener('click', () => run(() => loadChat()).catch(() => {}));

$('chatForm').addEventListener('submit', (event) => {
  event.preventDefault();
  run(async () => {
    const content = chatInput.value.trim();
    if (!content) throw new Error('Message is empty');
    sendBtn.disabled = true;
    chatInput.disabled = true;
    try {
      const result = await bodyRequest('/api/v1/body/chat/turn', {
        method: 'POST',
        body: { content }
      });
      chatInput.value = '';
      setStatus(true, 'Chat connected');
      await loadChat();
      setPresence('available').catch(() => null);
      return result;
    } finally {
      sendBtn.disabled = false;
      chatInput.disabled = false;
      chatInput.focus();
    }
  }).catch((error) => renderChatError(error));
});

$('forgetBtn').addEventListener('click', () => {
  localStorage.removeItem(STORAGE.deviceToken);
  localStorage.removeItem(STORAGE.credentialId);
  setStatus(false, 'Pairing removed from this browser');
  renderBodyIdentity();
  renderChatError(new Error('Pair this body first.'));
  show({ ok: true, local_pairing_removed: true, note: 'Server-side revocation remains owner-controlled.' });
});

document.addEventListener('visibilitychange', () => {
  if (!currentToken()) return;
  const state = document.visibilityState === 'visible' ? 'available' : 'away';
  setPresence(state).catch(() => null);
});

renderCapabilities();
renderBodyIdentity();
if (currentToken()) {
  refreshSelf()
    .then(() => Promise.allSettled([loadChat(), setPresence(document.visibilityState === 'visible' ? 'available' : 'away')]))
    .catch(() => setStatus(false, 'Stored pairing needs attention'));
} else {
  renderChatError(new Error('Pair this body first.'));
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch((error) => {
    show({ ok: false, warning: 'service_worker_registration_failed', error: error.message });
  });
}
