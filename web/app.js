const $ = (id) => document.getElementById(id);

const output = $('output');
const statusDot = $('statusDot');
const statusText = $('statusText');
const capabilitiesEl = $('capabilities');

const savedDeviceId = localStorage.getItem('ecompanion.device_id');
const deviceId = savedDeviceId || `ebody:${crypto.randomUUID()}`;
if (!savedDeviceId) localStorage.setItem('ecompanion.device_id', deviceId);

$('runtimeBase').value = localStorage.getItem('ecompanion.runtime_base') || location.origin;
$('deviceLabel').value = localStorage.getItem('ecompanion.device_label') || 'eCompanion Body';
$('actorId').value = localStorage.getItem('ecompanion.actor_id') || '';

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

function bodyIdentity() {
  return {
    protocol: 'ecompanion-body-web-v1',
    device_id: deviceId,
    platform: 'web',
    capabilities
  };
}

function show(payload) {
  output.textContent = typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2);
}

function setStatus(ok, text) {
  statusDot.classList.toggle('ok', Boolean(ok));
  statusText.textContent = text;
}

function runtimeBase() {
  const value = $('runtimeBase').value.trim().replace(/\/$/, '');
  if (!/^https?:\/\//i.test(value)) throw new Error('Runtime base URL must start with http:// or https://');
  localStorage.setItem('ecompanion.runtime_base', value);
  return value;
}

function token() {
  const value = $('token').value.trim();
  if (!value) throw new Error('Runtime bearer token is required');
  return value;
}

async function runtimeRequest(path, { method = 'GET', body } = {}) {
  const response = await fetch(`${runtimeBase()}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token()}`,
      ...(body ? { 'content-type': 'application/json' } : {})
    },
    body: body ? JSON.stringify(body) : undefined,
    cache: 'no-store'
  });

  const payload = await response.json().catch(() => ({ ok: false, error: 'invalid_json_response' }));
  if (!response.ok) {
    const error = new Error(payload?.message || payload?.error || `HTTP ${response.status}`);
    error.payload = payload;
    throw error;
  }
  return payload;
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

$('connectBtn').addEventListener('click', () => run(async () => {
  const result = await runtimeRequest('/api/v1/runtime');
  setStatus(true, `Connected · Runtime ${result.runtime?.version || ''}`.trim());
  return result;
}).catch(() => {}));

$('registerBtn').addEventListener('click', () => run(async () => {
  const label = $('deviceLabel').value.trim();
  if (!label) throw new Error('Device label is required');
  const actorId = $('actorId').value.trim();
  localStorage.setItem('ecompanion.device_label', label);
  if (actorId) localStorage.setItem('ecompanion.actor_id', actorId);
  else localStorage.removeItem('ecompanion.actor_id');

  const result = await runtimeRequest('/api/v1/devices', {
    method: 'POST',
    body: {
      id: deviceId,
      label,
      platform: 'web-pwa',
      assignedActorId: actorId || undefined,
      capabilities,
      metadata: {
        body_protocol: 'ecompanion-body-web-v1',
        install_mode: capabilities.standalone ? 'standalone' : 'browser'
      }
    }
  });
  setStatus(true, 'Body registered');
  return result;
}).catch(() => {}));

async function setPresence(state) {
  const actorId = $('actorId').value.trim();
  if (!actorId) throw new Error('Assigned actor ID is required for presence');
  localStorage.setItem('ecompanion.actor_id', actorId);
  const result = await runtimeRequest('/api/v1/presence', {
    method: 'PUT',
    body: {
      actorId,
      deviceId,
      state,
      details: {
        body_protocol: 'ecompanion-body-web-v1',
        capabilities
      }
    }
  });
  setStatus(state !== 'offline', `Presence: ${state}`);
  return result;
}

$('availableBtn').addEventListener('click', () => run(() => setPresence('available')).catch(() => {}));
$('offlineBtn').addEventListener('click', () => run(() => setPresence('offline')).catch(() => {}));

renderCapabilities();
$('bodyInfo').textContent = JSON.stringify(bodyIdentity(), null, 2);

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch((error) => {
    show({ ok: false, warning: 'service_worker_registration_failed', error: error.message });
  });
}
