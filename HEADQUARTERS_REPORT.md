# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08T20:04+02:00
Engineer: ◐ Iris 👩🏽‍🎨
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current production / physical target: Render `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); physical iPhone install not claimed.
Current functional release: `d6a5917a5e42d0fab96b92709c0271ba53292f6e`
Current verified deploy: `dep-dag4qq3ncjis738ng57g` → LIVE

## PRODUCT RESULT
Mobile is now a materially richer live-companion conversation surface.

The owner can send Lola text plus real image/audio/video/document attachments through the canonical Runtime Body conversation, see selected files before sending, see persisted attachment descriptors after history reload, interrupt Lola's browser voice playback by speaking/typing, and continue speaking while a turn is in flight without causing an unsafe concurrent turn.

The current Runtime Body HTTP route limits JSON requests to 1,000,000 bytes. Mobile therefore fails closed at 650 KB total selected binary data so allowed uploads fit the real current transport rather than advertising Runtime's larger semantic attachment limits as if they were transport proof.

## COMPLETED
- Multimodal composer: text-only, file-only or text + files.
- Typed image/audio/video/document preparation with SHA-256, canonical Base64 and Runtime-compatible metadata.
- Selected-file removal and persisted attachment-descriptor presentation.
- Voice barge-in: owner speech/typing stops current browser TTS.
- Voice remains available during an in-flight turn; recognized correction is preserved as the next draft instead of concurrent dispatch.
- Installed shell updated to cache the multimodal module.
- Fail-closed 650 KB current wire limit added after verifying Runtime's 1 MB Body JSON ceiling.
- Regression protection for attachment digest/type/count/wire limit, voice barge-in and authority boundaries.

## PROOF STATUS
### IMPLEMENTED
IMPLEMENTED — all capabilities above exist in canonical Mobile source.

### TESTED
TESTED — `verify-mobile` run `34260544342` succeeded on exact release `d6a5917a5e42d0fab96b92709c0271ba53292f6e`:
- web JavaScript syntax PASS;
- multimodal/wire-limit tests PASS;
- voice barge-in test PASS;
- Mobile boundary/static gate PASS;
- BodyAgentCore build PASS;
- BodyAgentCore iOS Simulator build PASS;
- ECompanionBodyApp iOS Simulator build PASS;
- BodyAgentCore tests PASS.

### DEPLOYED
DEPLOYED — Render deploy `dep-dag4qq3ncjis738ng57g` is LIVE on exact tested release `d6a5917a5e42d0fab96b92709c0271ba53292f6e`.

### TARGET VERIFIED
NOT TARGET VERIFIED for an authenticated real browser/iPhone conversation. External page probing from this execution environment remains DNS-unresolved. Render LIVE is deployment proof only.

NOT TARGET VERIFIED for a physical native iPhone install.

### END-TO-END PROVEN
NOT END-TO-END PROVEN for the requested persistent autonomous Lola task journey. Mobile still lacks canonical task progress/control/artifact contracts and real NODE/provider task proof.

## PRODUCTION / PHYSICAL STATE
- Mobile web: Render `srv-daat0mu7bikc73c9fiv0`, publish path `web`, auto-deploy enabled.
- Exact functional release: `d6a5917a5e42d0fab96b92709c0271ba53292f6e`.
- Exact verified deploy: `dep-dag4qq3ncjis738ng57g` → LIVE.
- Native simulator build/tests: green on same release.
- Physical iPhone: not verified in this run.
- Physical NODE-01: no new Mobile proof; Iris does not infer online/current state from stale historical device data.

## BLOCKERS
- Runtime Body multimodal semantic limits and HTTP transport limit are inconsistent: attachment validation allows 20 MiB each / 25 MiB total, while Body `readJsonBody()` currently defaults to 1,000,000 bytes.
- No device/owner-safe canonical task/action read + realtime event/control contract for Mobile working presence, pause, cancel, resume or superseded intent.
- Current conversation attachment path persists descriptors, not a durable owner-resolvable binary task-artifact reference.
- Provider-grade low-latency duplex voice is not yet available to Mobile through a proven canonical realtime transport.
- Authenticated real-browser/physical-iPhone target verification remains unavailable from this execution environment.

## NEXT EXECUTABLE WORK
Continue truthful Mobile conversation UX over existing Body contracts. As soon as the owning contracts land, integrate:
1. canonical task/activity state + pause/cancel/resume;
2. durable artifact cards/downloads;
3. coherent larger multimodal Body transport;
4. realtime duplex voice.

Do not use executor-claim endpoints, browser service credentials or local fake task state to get there.

## CROSS-PROJECT CHANGES
### CHANGE: Mobile multimodal companion turns
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
Mobile sends typed multimodal content through existing `POST /api/v1/body/chat/turn` and renders persisted attachment descriptors from `GET /api/v1/body/chat`.
Affected projects:
- eCompanion Runtime / ◉ Maeve
Canonical contract / behavior now:
Runtime remains conversation and attachment truth; Mobile creates no media/persistence authority.
Available capability / interface:
- `POST /api/v1/body/chat/turn`
- `GET /api/v1/body/chat`
Expected action by other projects:
### Runtime / ◉ Maeve
NO ACTION for the existing multimodal content schema.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not treat persisted attachment descriptors as durable downloadable artifact storage.
Evidence:
`d6a5917…`; run `34260544342` PASS; deploy `dep-dag4qq3ncjis738ng57g` LIVE.

### CHANGE: Mobile fails closed on actual Body HTTP wire ceiling
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
DEPLOYED
Change type:
BEHAVIOR + CONTRACT CONSUMPTION
What changed:
Mobile now permits at most 650 KB total binary attachment data per turn so Base64 + text/JSON stays safely inside the current 1,000,000-byte Body request ceiling.
Why:
The Runtime multimodal validator's 20/25 MiB semantic limits cannot currently traverse the default Body HTTP reader.
Affected projects:
- eCompanion Runtime / ◉ Maeve
Canonical contract / behavior now:
Until Runtime reconciles the Body transport, Mobile uses the smaller real transport-safe ceiling and fails closed before upload.
Expected action by other projects:
### Runtime / ◉ Maeve
REQUIRED
Make the Body multimodal turn HTTP/request-body limit coherent with the intended typed attachment contract, with explicit tested limits and failure semantics. Do not require Mobile to use companion-service media credentials or an alternate authority.
Compatibility:
MIGRATION REQUIRED to unlock intended large attachment sizes; current small-file behavior remains backward compatible.
Rollout dependency:
Runtime fix DEPLOYED/TESTED → Iris raises/removes temporary Mobile wire ceiling → Mobile TESTED/DEPLOYED.
Production state:
Current Mobile mitigation DEPLOYED; Runtime contract fix NOT YET PROVEN.
Do not:
Do not advertise 20/25 MiB in owner UX while the real Body request transport rejects those payloads.
Evidence:
Runtime `src/http-body.ts` defines `MAX_JSON_BODY_BYTES = 1_000_000`; Mobile regression verifies the 650 KB fail-closed bound.

### CHANGE: Browser voice playback is owner-interruptible
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
Speaking or typing interrupts local Lola TTS. Speech heard during an in-flight Runtime turn becomes a draft rather than a second concurrent turn.
Affected projects:
- eCompanion Runtime / ◉ Maeve
- eCompanion Integrations / ↔ Cleo
Expected action by other projects:
### Runtime / ◉ Maeve
NO ACTION for this local playback behavior.
### Integrations / ↔ Cleo
NO ACTION for this local playback behavior.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not describe local TTS interruption as canonical task cancellation or provider-grade duplex voice.
Evidence:
Voice regression PASS in run `34260544342`.

## CROSS-PROJECT BLOCKERS
### CROSS-PROJECT BLOCKER: live task progress and owner interruption
Blocked capability:
Working presence plus truthful pause/cancel/resume/supersede while Lola performs long-running work.
Owning dependency:
eCompanion Runtime / ◉ Maeve
Required from dependency:
Device/owner-safe task/action state + realtime event/control contract, including non-terminal `claimed`, current action/step, observations/results and authorized interruption semantics.
Why required:
Private action reads use companion-service auth; `/api/v1/body/actions/claim` is executor authority, not an owner activity feed.
Current dependency status:
Runtime canonical Action lifecycle/reconciliation: DEPLOYED. Mobile-safe task consumer/control contract: NOT YET PROVEN AVAILABLE.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Conversation/multimodal/voice/accessibility UX using current scoped Body contracts.

### CROSS-PROJECT BLOCKER: durable task artifacts
Blocked capability:
Generated/downloaded artifacts remain reopenable and usable after reload/reconnect.
Owning dependency:
eCompanion Runtime / ◉ Maeve plus the producing authority.
Required from dependency:
Canonical owner/device-safe artifact/media references attachable to task/conversation state.
Current dependency status:
NOT YET PROVEN AVAILABLE on the Body client contract.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Incoming multimodal turns and persisted descriptors are already implemented.

### CROSS-PROJECT BLOCKER: realtime duplex voice
Blocked capability:
Low-latency bidirectional voice with true task interruption while work continues.
Owning dependency:
eCompanion Runtime / ◉ Maeve and eCompanion Integrations / ↔ Cleo where provider transport is used.
Required from dependency:
Canonical realtime streaming/session lifecycle with interruption, reconnect and machine-readable failure.
Current dependency status:
NOT YET PROVEN AVAILABLE to Mobile.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Browser voice input/output and playback barge-in are deployed.

## PROVENANCE
Canonical source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`.

Functional release chain:
- `88eca1d…` attachment preparation
- `355bfca…` voice interruption
- `b5f21d4…` multimodal composer
- `875f638…` canonical multimodal turn + in-flight draft behavior
- `1ae49f0…` installed shell update
- `d23f734…` first full multimodal release gate
- `08a24f4…` actual transport fail-closed mitigation
- `3896cf3…` wire-limit regression
- `d6a5917…` semantic-vs-wire distinction, current functional release

Production: Render `srv-daat0mu7bikc73c9fiv0` → `dep-dag4qq3ncjis738ng57g` LIVE on `d6a5917…`.

## EVIDENCE
- `verify-mobile` run `34260544342`: web SUCCESS + native-core SUCCESS.
- Render deploy `dep-dag4qq3ncjis738ng57g`: LIVE on exact tested release.
- Runtime `src/http-body.ts`: default JSON limit 1,000,000 bytes.
- Mobile multimodal/wire-limit + voice tests: PASS.
- External public hostname probe: DNS-unresolved in execution environment; not counted as target proof or product failure.
- No secrets recorded.
