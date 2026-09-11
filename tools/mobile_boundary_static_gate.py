import json
import plistlib
from pathlib import Path

boundaries = json.loads(Path('ECOMPANION_MOBILE_BOUNDARIES.json').read_text(encoding='utf-8'))
capabilities = json.loads(Path('BODY_AGENT_CAPABILITIES.json').read_text(encoding='utf-8'))
manifest = json.loads(Path('web/manifest.webmanifest').read_text(encoding='utf-8'))
html = Path('web/index.html').read_text(encoding='utf-8')
js = Path('web/app.js').read_text(encoding='utf-8')
attachments = Path('web/attachments.js').read_text(encoding='utf-8')
voice = Path('web/voice.js').read_text(encoding='utf-8')
call = Path('web/call.js').read_text(encoding='utf-8')
sw = Path('web/sw.js').read_text(encoding='utf-8')
runtime_client = Path('native/BodyAgentCore/Sources/BodyAgentCore/RuntimeActionClient.swift').read_text(encoding='utf-8')
json_value = Path('native/BodyAgentCore/Sources/BodyAgentCore/JSONValue.swift').read_text(encoding='utf-8')

required_ids = [
    'pairBtn', 'connectBtn', 'syncDeviceBtn', 'availableBtn',
    'offlineBtn', 'forgetBtn', 'pairingCode', 'runtimeBase',
    'deviceLabel', 'output', 'statusDot', 'statusText',
    'capabilities', 'bodyInfo', 'messages', 'chatForm',
    'chatInput', 'sendBtn', 'refreshChatBtn', 'chatTitle', 'chatMeta',
    'chatNotice', 'voiceBtn', 'speakToggle', 'voiceState',
    'attachBtn', 'attachmentInput', 'attachmentTray',
    'callBtn', 'callSurface', 'callVideo', 'callState', 'callTranscript', 'hangupBtn'
]
missing = [value for value in required_ids if f'id="{value}"' not in html]
assert not missing, f'missing UI ids: {missing}'

forbidden = [
    'Runtime bearer token',
    "$('token')",
    '/api/v1/devices',
    '/api/v1/presence',
    'actorId',
    'companionId',
    'conversationId'
]
combined = html + '\n' + js + '\n' + voice
found = [value for value in forbidden if value in combined]
assert not found, f'forbidden body-client authority found: {found}'

# Owner conversation UI may not consume executor/private action APIs as fake activity truth.
assert '/api/v1/body/actions/claim' not in js
assert '/api/v1/body-actions' not in js
assert '/api/companion/operations/actions' not in js

assert '<summary>Device & system controls</summary>' in html
assert 'id="runtimeBase" type="hidden"' in html
assert 'id="syncDeviceBtn" class="secondary" type="button">Save changes</button>' in html
assert 'body:has(#setupSection:not([hidden])) .advanced{display:none}' in html
assert 'Forget on this phone' in html
assert 'Server-side revocation remains owner-controlled' in html
owner_visible_forbidden = [
    '>Runtime connection<',
    '>Refresh capabilities<',
    '>Available<',
    '>Offline<'
]
visible_found = [value for value in owner_visible_forbidden if value in html]
assert not visible_found, f'developer controls leaked into owner UX: {visible_found}'

assert manifest['name'] == 'Lola · eCompanion'
assert manifest['short_name'] == 'Lola'
assert manifest['description'] == 'Lola, your private eCompanion.'
assert 'body surface' not in manifest['description'].lower()
assert "const CACHE = 'ecompanion-mobile-v8';" in sw
assert "'./attachments.js'" in sw
assert 'ecompanion-body-v2' not in sw

assert '/api/v1/device-pairing/claim' in js
assert '/api/v1/body/me' in js
assert '/api/v1/body/device' in js
assert '/api/v1/body/presence' in js
assert '/api/v1/body/chat?limit=100' in js
assert '/api/v1/body/chat/turn' in js
assert "import { prepareAttachments, validateAttachmentFiles } from './attachments.js'" in js
assert 'const turnContent = attachments.length ? { text, attachments } : text' in js
assert 'metadata?.attachments' in js
assert 'cryptoImpl.subtle.digest' in attachments
assert 'MAX_ATTACHMENT_COUNT = 8' in attachments
assert 'MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024' in attachments
assert 'MAX_TURN_ATTACHMENT_BYTES = 25 * 1024 * 1024' in attachments
assert 'ecompanion.device_token' in js
assert 'new URLSearchParams(location.search)' in js
assert "new URLSearchParams(location.hash.replace(/^#/, ''))" in js
assert "hashParams.get('relink')" in js
assert "history.replaceState(null, '', `${location.pathname}${location.search}`)" in js
assert "deviceId = result.device.id" in js
assert "localStorage.setItem(STORAGE.deviceId, deviceId)" in js
assert "result.relinked ? 'Reconnected' : 'Connected'" in js
assert "|| location.origin" not in js
assert "DEFAULT_RUNTIME = 'https://ecompanion-ene7.onrender.com'" in js
assert 'localStorage.removeItem(STORAGE.runtimeBase)' in js
assert 'savedRuntime' not in js
assert 'unexpected response' in js
assert 'runtimeErrorMessage' in js
assert "message !== 'Runtime operation failed'" in js
assert 'error.status = response.status' in js
assert 'clearLocalCredential()' in js
assert 'preserveMessages' in js
assert 'Your saved messages are still here' in js
assert 'Refresh the conversation before sending again to avoid a duplicate message' in js
assert "$('syncDeviceBtn').addEventListener('click'" in js
assert "'/api/v1/body/device'" in js

assert "import { createCallController } from './call.js'" in js
assert "import Daily from './vendor/daily-esm.js'" in js
assert '/api/v1/body/voice/policy' in call
assert '/api/v1/body/voice/sessions' in call
assert '/renderer' in call
assert '/audio-chunks' in call
assert '/events?afterSequence=' in call
assert '/outputs/' in call
assert '/interrupt' in call
assert '/playback-complete' in call
assert 'conversation.echo' in call
assert "modality: 'audio'" in call
assert 'sample_rate: ECHO_RATE' in call
assert 'getUserMedia' in call
assert 'speechSynthesis' not in call
assert 'SpeechRecognition' not in call
assert "import { createVoiceAdapter } from './voice.js'" in js
assert 'speech_recognition' in js
assert 'speech_synthesis' in js
assert 'sendChatContent(transcript' in js
assert 'voiceAdapter.speak(assistantText)' in js
assert 'Interrupt and talk' in js
assert 'voiceAdapter.isSpeaking()' in js
assert 'if (speaking) stopSpeaking({ emitState: false })' in voice
assert 'SpeechRecognition' in voice
assert 'webkitSpeechRecognition' in voice
assert 'SpeechSynthesisUtterance' in voice
assert 'fetch(' not in voice
assert "'./voice.js'" in sw
assert "'./call.js'" in sw
assert "'./vendor/daily-esm.js'" in sw

# Native BodyAgent keeps executor authority; owner web UI does not claim it.
assert '/api/v1/body/actions/claim' in runtime_client
assert '/complete' in runtime_client
assert '/api/v1/body/device' in runtime_client
assert 'Bearer ' in runtime_client
assert 'JSONValue' in runtime_client
assert 'enum JSONValue' in json_value
assert 'process' not in runtime_client

assert boundaries['pairing']['relink_client_device_id_authority'] is False
assert boundaries['authority']['relink_device_identity'] == 'runtime_returned_existing_device_only'
assert boundaries['voice']['paid_provider_required'] is False
assert boundaries['voice']['runtime_chat_authority'] == 'unchanged'
assert boundaries['voice']['client_companion_selection'] is False
assert boundaries['platform_independence']['native_body_agent_required'] is True
assert boundaries['body_agent']['native_core'] == 'native/BodyAgentCore'
assert boundaries['body_agent']['execution_tiers'] == ['stock', 'integration', 'elevated']
assert boundaries['body_agent']['runtime_command_cycle'] == 'claim_execute_complete'
assert boundaries['body_agent']['runtime_command_arguments'] == 'structured_json'
assert boundaries['body_agent']['busy_polling'] == 'forbidden'
assert capabilities['rules']['unsupported_capability_must_fail_closed'] is True
assert capabilities['rules']['elevated_capabilities_default'] == 'unavailable'
assert 'transport.telegram' in capabilities['capabilities']['transports']
assert 'transport.discord' in capabilities['capabilities']['transports']
assert 'voice_bypass_runtime_conversation' in boundaries['forbidden']
assert 'cross_device_action_claim' in boundaries['forbidden']
assert 'busy_polling_action_loop' in boundaries['forbidden']

native_info = plistlib.loads(Path('native/ECompanionBodyApp/ECompanionBodyApp/Info.plist').read_bytes())
background_modes = set(native_info.get('UIBackgroundModes', []))
assert {'audio', 'voip'} <= background_modes, f'native call background modes missing: {background_modes}'
assert native_info.get('NSMicrophoneUsageDescription'), 'native microphone usage description missing'
print('mobile boundary/static gate: PASS')
