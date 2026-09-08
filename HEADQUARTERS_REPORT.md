# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08T19:58+02:00
Engineer: ◐ Iris 👩🏽‍🎨
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current production / physical target: Render static site `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); no physical iPhone install is claimed.
Current functional release: `d23f734ae49ea874ff92680f34488239ed9536c4`
Current verified Render deploy for that release: `dep-dag4nkh5efls73fjaeig` → LIVE

This report commit is outside `web/`; functional product proof remains tied to the exact tested/deployed release above.

## PRODUCT RESULT
Mobile now behaves materially more like a live companion client.

The owner can:
- talk to Lola through the same persisted conversation;
- attach real photos, audio, video and documents to a conversation turn instead of being limited to text;
- see selected files before sending and remove mistakes;
- send text-only, file-only or text + files through the existing canonical Runtime Body conversation path;
- reopen conversation history and see persisted attachment descriptors on the original message;
- interrupt Lola's spoken browser reply by talking or typing; playback stops before owner speech is captured;
- continue speaking while a Runtime turn is still in flight: the correction/new instruction is kept as a draft rather than firing an unsafe concurrent turn;
- keep existing reconnect, uncertain-send and scoped-device safety behavior.

This does NOT claim canonical task pause/cancel, concurrent autonomous work, durable downloadable artifact storage, or low-latency provider duplex voice. Those require owning backend/provider contracts rather than UI simulation.

## COMPLETED
- Added a mobile multimodal composer with multi-file selection and removal.
- Added Runtime-compatible attachment preparation: image/audio/video/document classification, byte limits, SHA-256 digest, canonical Base64 payload and stable per-turn attachment identity.
- Enforced current Runtime limits in the client: maximum 8 attachments, 20 MiB each, 25 MiB combined.
- Routed multimodal content through existing `POST /api/v1/body/chat/turn`; no new backend authority was created.
- Rendered persisted attachment metadata from canonical conversation history.
- Added voice-playback interruption: owner speech stops Lola TTS before recognition begins.
- Kept microphone available during an in-flight turn while preventing a second concurrent send; captured speech becomes the next draft.
- Typing while Lola is speaking also stops playback.
- Advanced service-worker shell cache to `ecompanion-mobile-v4` and included `attachments.js` so installed Mobile receives the new composer offline shell.
- Added behavioral regression tests for attachment hashing/limits and voice barge-in.
- Added a boundary guard explicitly preventing owner web UI from consuming executor claim or private companion action APIs as fake activity truth.

## PROOF STATUS
### IMPLEMENTED
IMPLEMENTED — the multimodal conversation and voice-interruption slice exists in canonical Mobile source.

### TESTED
TESTED — GitHub Actions `verify-mobile` run `34259883142` completed successfully on exact product head `d23f734ae49ea874ff92680f34488239ed9536c4`.

Successful evidence on that head:
- JavaScript syntax: PASS (`app.js`, `attachments.js`, `voice.js`, `sw.js`).
- Multimodal attachment behavior tests: PASS.
- Voice barge-in behavior test: PASS.
- Mobile boundary/static product gate: PASS.
- Native BodyAgentCore build: PASS.
- BodyAgentCore iOS Simulator build: PASS.
- ECompanionBodyApp iOS Simulator build: PASS.
- BodyAgentCore tests: PASS.

### DEPLOYED
DEPLOYED — Render deploy `dep-dag4nkh5efls73fjaeig` reached LIVE on exact tested product head `d23f734ae49ea874ff92680f34488239ed9536c4`.

### TARGET VERIFIED
NOT TARGET VERIFIED for an authenticated real browser/iPhone conversation. The external probe environment could not resolve the public Render hostname; Render LIVE is deployment proof, not owner-session proof.

NOT TARGET VERIFIED for a physical native iPhone install. Simulator proof is not physical-device proof.

### END-TO-END PROVEN
NOT END-TO-END PROVEN for the requested live autonomous task journey.

The current Mobile slice proves client behavior and canonical conversation wiring, but not:
- persisted Lola task execution;
- live Runtime task/action stream in Mobile;
- pause/cancel/resume/supersede;
- physical NODE execution;
- durable task artifact retrieval;
- provider-grade duplex voice.

## PRODUCTION / PHYSICAL STATE
Web production:
- Render service: `ecompanion-mobile`
- Service ID: `srv-daat0mu7bikc73c9fiv0`
- Source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`
- Publish path: `web`
- Auto deploy: yes
- Functional release: `d23f734ae49ea874ff92680f34488239ed9536c4`
- Verified deploy: `dep-dag4nkh5efls73fjaeig`
- Status: LIVE

Native source remains in the same repository. Native core/app simulator builds and tests are green on the same product head. No physical iPhone installation is claimed.

Physical NODE-01 is NOT presented as online/current by Mobile in this slice. Devices' current report still has repaired NODE release activation unproven on the physical machine.

## BLOCKERS
- Real authenticated browser/iPhone TARGET VERIFICATION is not available from the current execution environment.
- Mobile has no device/owner-safe canonical Runtime task/action read/event contract for live companion work progress.
- Mobile has no canonical task interruption control contract for pause/cancel/resume/superseded owner intent.
- Current Body turn persistence keeps attachment descriptors in message metadata, but this path does not provide a durable owner-accessible binary artifact reference after reload. Durable task artifacts need canonical media/artifact references from the owning Runtime/media contract.
- Provider-grade low-latency duplex voice/barge-in is not yet exposed to Mobile through a proven canonical realtime transport contract.
- Owner-friendly new-device pairing grant issuance remains Runtime authority; Mobile may claim a grant but may not mint authorization.

## NEXT EXECUTABLE WORK
Continue improving the currently real conversation surface without inventing backend state: stable scroll/new-turn behavior, attachment accessibility and failure recovery where useful.

Immediately integrate a human working-presence/activity surface, pause/cancel/resume controls and durable artifact cards when Runtime exposes the corresponding device/owner-safe task/event/artifact contracts.

Integrate realtime duplex voice when the canonical Runtime/Integrations session transport is available; do not disguise browser SpeechRecognition/TTS as that final capability.

## CROSS-PROJECT CHANGES
### CHANGE: Mobile consumes canonical Runtime multimodal conversation turns
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
Mobile can now prepare and send images, audio, video and documents through the existing Body conversation turn, and renders the persisted attachment descriptors returned in conversation history.
Why:
The owner can collaborate with Lola around real media/files from the daily Mobile conversation instead of text only.
Affected projects:
- eCompanion Runtime / ◉ Maeve
Canonical contract / behavior now:
Runtime remains conversation/multimodal truth. Mobile conforms to the existing Runtime attachment contract: up to 8 attachments, 20 MiB each, 25 MiB combined, typed kind/MIME, byte size, SHA-256 and canonical Base64 content.
Available capability / interface:
- `POST /api/v1/body/chat/turn`
- `GET /api/v1/body/chat`
Expected action by other projects:
### Runtime / ◉ Maeve
NO ACTION
Existing multimodal conversation contract is consumed unchanged.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not move binary persistence/media authority into Mobile or treat persisted attachment descriptors as durable downloadable artifact storage.
Evidence:
- Mobile product head `d23f734ae49ea874ff92680f34488239ed9536c4`
- verify run `34259883142` PASS
- Render deploy `dep-dag4nkh5efls73fjaeig` LIVE

### CHANGE: Owner can interrupt browser voice playback without concurrent turn dispatch
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
Starting owner speech or typing stops current browser TTS playback. If a Runtime turn is already in flight, recognized owner speech becomes a draft for the next turn rather than dispatching a concurrent request.
Affected projects:
- eCompanion Runtime / ◉ Maeve
- eCompanion Integrations / ↔ Cleo
Canonical contract / behavior now:
This is presentation-layer conversational barge-in only. It does not mutate Runtime task/action state and is not task cancellation.
Expected action by other projects:
### Runtime / ◉ Maeve
NO ACTION for this browser-voice behavior.
### Integrations / ↔ Cleo
NO ACTION for this browser-voice behavior.
A future canonical realtime voice transport can replace this local transport without changing the owner interaction principle.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not label local TTS cancellation as canonical task cancellation or provider duplex voice.
Evidence:
- voice barge-in regression PASS in run `34259883142`
- exact product release/deploy above

## CROSS-PROJECT BLOCKERS
### CROSS-PROJECT BLOCKER: live canonical task/action state and owner interruption
Blocked capability:
Human-readable working presence plus truthful pause/cancel/resume/supersede while Lola performs long-running work.
Owning dependency:
eCompanion Runtime / ◉ Maeve
Required from dependency:
A device- or owner-safe canonical task/action read + realtime event/control contract exposing task identity, current step/action, non-terminal states including `claimed`, observations/results, and authorized pause/cancel/resume/supersede semantics without service credentials in Mobile.
Why required:
Runtime owns neutral task/action truth. Current private action reads are companion-service authenticated, while `/api/v1/body/actions/claim` is executor authority and must not be consumed as an owner activity feed.
Current dependency status:
Canonical Runtime Action lifecycle including `claimed` and reconciliation is DEPLOYED. Mobile-safe task/action owner consumption is NOT YET PROVEN AVAILABLE.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Conversation, multimodal, voice UX, reconnect/install/accessibility work using existing Body contracts.

### CROSS-PROJECT BLOCKER: durable owner-usable task artifacts
Blocked capability:
A generated/downloaded task artifact remains reopenable and usable in conversation/activity after reload/reconnect.
Owning dependency:
eCompanion Runtime / ◉ Maeve, with the producing authority supplying the real artifact.
Required from dependency:
A canonical owner/device-safe artifact/media reference contract that can be attached to task/conversation state and resolved without embedding privileged service credentials in Mobile.
Why required:
Current conversation turns persist attachment descriptors, not a durable downloadable binary reference for the owner.
Current dependency status:
NOT YET PROVEN AVAILABLE on the Mobile Body contract.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Incoming multimodal collaboration and descriptor presentation are already implemented.

### CROSS-PROJECT BLOCKER: realtime duplex voice/task coordination
Blocked capability:
Low-latency bidirectional voice with true task interruption while Lola continues background work.
Owning dependency:
eCompanion Runtime / ◉ Maeve and eCompanion Integrations / ↔ Cleo where an external voice provider is used.
Required from dependency:
Canonical realtime session lifecycle with streaming input/output, interruption semantics, reconnect and machine-readable failure, while task control remains Runtime-owned.
Current dependency status:
Browser voice is deployed in Mobile; provider-grade realtime path is NOT YET PROVEN AVAILABLE to this client.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Current voice playback barge-in and queued conversational correction are deployed.

## PROVENANCE
Canonical Mobile development source:
- GitHub `ecompanionhub/eCompanion-Mobile` → `main`.

Functional Mobile release:
- `d23f734ae49ea874ff92680f34488239ed9536c4`

Production:
- Render `srv-daat0mu7bikc73c9fiv0`
- publish path `web`
- auto deploy enabled
- deploy `dep-dag4nkh5efls73fjaeig` → LIVE on exact tested functional release

Relevant implementation chain:
- `88eca1d62e3390e95ec79368230b23a5a2ed41d9` — multimodal attachment preparation
- `355bfca3ce9a025733a26dbc3ca58696c452603f` — interruptible browser voice playback
- `b5f21d43ba92b900f15ea6577b23aceb2adcb952` — multimodal composer UI
- `875f638d1b7bf1535e47ce76fbe976b47ea2a1a2` — canonical multimodal turn + in-flight voice draft behavior
- `1ae49f0d9e03928643ae9aaa693cf6aace9bcfbe` — installed shell cache update
- `e1bea82b60d9991b675bd206ca32448a06a30237` — attachment regression tests
- `ca7af04ef78df2f8aebd371c19f88fb7089a3c24` — voice barge-in regression
- `d23f734ae49ea874ff92680f34488239ed9536c4` — full release gate

## EVIDENCE
- GitHub Actions `verify-mobile` run `34259883142`: web SUCCESS + native-core SUCCESS.
- Web JavaScript syntax: PASS.
- Multimodal/hash/limit behavior tests: PASS.
- Voice barge-in behavior: PASS.
- Mobile boundary/static gate: PASS.
- Native BodyAgentCore + iOS Simulator builds/tests: PASS.
- Render deploy `dep-dag4nkh5efls73fjaeig`: LIVE on `d23f734ae49ea874ff92680f34488239ed9536c4`.
- Public external target probe: unresolved because execution environment DNS could not resolve the Render hostname; not counted as product failure or target proof.
- No secrets recorded.
