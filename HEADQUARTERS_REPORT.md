# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08
Engineer: ◐ Iris 👩🏽‍🎨
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current production / physical target: Render `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); physical iPhone install not claimed.
Current functional release: `d6a5917a5e42d0fab96b92709c0271ba53292f6e`
Current verified deploy: `dep-dag4qq3ncjis738ng57g` → LIVE

Standing crew/authority update only: ✧ Yara 🙋🏽‍♀️ is now recognized as the Social Lola implementation worker for `ecompanionhub/eCompanion-Lola-Social` → `main`. This report/doctrine update changes no Mobile product bytes and does not upgrade product proof.

## PRODUCT RESULT
Mobile remains a materially richer live-companion conversation surface.

The owner can send Lola text plus real image/audio/video/document attachments through the canonical Runtime Body conversation, see selected files before sending, see persisted attachment descriptors after history reload, interrupt Lola's browser voice playback by speaking/typing, and continue speaking while a turn is in flight without causing an unsafe concurrent turn.

The current Runtime Body HTTP route limits JSON requests to 1,000,000 bytes. Mobile therefore fails closed at 650 KB total selected binary data so allowed uploads fit the real current transport rather than advertising Runtime's larger semantic attachment limits as if they were transport proof.

## CREW / AUTHORITY ROUTING
- ◐ Iris 👩🏽‍🎨 owns Mobile/Interfaces user-facing experience.
- ✦ Lola 🙋🏼‍♀️ remains the Lola product/intelligence authority.
- ✧ Yara 🙋🏽‍♀️ owns Social Lola implementation in `eCompanion-Lola-Social`.
- ↔ Cleo 🙋🏽‍♀️ owns Discord/Telegram/provider transport and delivery lifecycle.

When Mobile exposes Social Lola state/behavior, it must consume canonical Lola/Runtime/Integrations truth. It must not duplicate Social state or create browser-owned Social truth.

Social-Lola implementation dependencies route to Yara. Provider transport/account/gateway/delivery dependencies route to Cleo. Interfaces does not absorb Social Lola implementation and the owner is not used as the Iris/Yara/Cleo message bus.

## COMPLETED
- Multimodal composer: text-only, file-only or text + files.
- Typed image/audio/video/document preparation with SHA-256, canonical Base64 and Runtime-compatible metadata.
- Selected-file removal and persisted attachment-descriptor presentation.
- Voice barge-in: owner speech/typing stops current browser TTS.
- Voice remains available during an in-flight turn; recognized correction is preserved as the next draft instead of concurrent dispatch.
- Installed shell updated to cache the multimodal module.
- Fail-closed 650 KB current wire limit added after verifying Runtime's 1 MB Body JSON ceiling.
- Regression protection for attachment digest/type/count/wire limit, voice barge-in and authority boundaries.
- Permanent Interfaces doctrine now distinguishes ✧ Yara / Social Lola implementation from ↔ Cleo / provider transport.

## PROOF STATUS
### IMPLEMENTED
IMPLEMENTED — current Mobile capabilities exist in canonical source. Crew/authority routing is standing doctrine/report metadata only.

### TESTED
TESTED — `verify-mobile` run `34260544342` succeeded on exact functional release `d6a5917a5e42d0fab96b92709c0271ba53292f6e`:
- web JavaScript syntax PASS;
- multimodal/wire-limit tests PASS;
- voice barge-in test PASS;
- Mobile boundary/static gate PASS;
- BodyAgentCore build PASS;
- BodyAgentCore iOS Simulator build PASS;
- ECompanionBodyApp iOS Simulator build PASS;
- BodyAgentCore tests PASS.

No new product test is claimed for the doctrine/report-only Yara routing update because no product bytes changed.

### DEPLOYED
DEPLOYED — functional Mobile release `d6a5917…` remains LIVE via Render deploy `dep-dag4qq3ncjis738ng57g`.

### TARGET VERIFIED
NOT TARGET VERIFIED for an authenticated real browser/iPhone conversation. External page probing from this execution environment remains DNS-unresolved. Render LIVE is deployment proof only.

NOT TARGET VERIFIED for a physical native iPhone install.

### END-TO-END PROVEN
NOT END-TO-END PROVEN for the requested persistent autonomous Lola task journey. Mobile still lacks canonical task progress/control/artifact contracts and real NODE/provider task proof.

## PRODUCTION / PHYSICAL STATE
- Mobile web: Render `srv-daat0mu7bikc73c9fiv0`, publish path `web`, auto-deploy enabled.
- Exact functional release: `d6a5917a5e42d0fab96b92709c0271ba53292f6e`.
- Exact verified functional deploy: `dep-dag4qq3ncjis738ng57g` → LIVE.
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

For any Social Lola UI dependency, read `eCompanion-Lola-Social/HEADQUARTERS_REPORT.md` when materially relevant and route Social implementation work to ✧ Yara. Do not route provider transport to Yara.

Do not use executor-claim endpoints, browser service credentials or local fake task state to get there.

## CROSS-PROJECT CHANGES
### CHANGE: Interfaces routing recognizes Social Lola worker
Changed by:
eCompanion Interfaces / ◐ Iris
Status:
IMPLEMENTED — doctrine/report routing
Change type:
AUTHORITY + REPORTING
What changed:
Interfaces cross-project routing now recognizes ✧ Yara 🙋🏽‍♀️ as the Social Lola implementation worker for `ecompanionhub/eCompanion-Lola-Social` → `main`.
Affected projects:
- eCompanion Lola Social / ✧ Yara
- eCompanion Integrations / ↔ Cleo
- eCompanion Lola / ✦ Lola
Canonical contract / behavior now:
- Social Lola implementation/state/behavior dependencies → ✧ Yara / `eCompanion-Lola-Social`.
- Discord/Telegram/provider transport/account/gateway/delivery lifecycle → ↔ Cleo / Integrations.
- Lola product/intelligence authority remains ✦ Lola.
- Interfaces remains presentation/client authority only.
Expected action by other projects:
### eCompanion Lola Social / ✧ Yara
NO ACTION
Interfaces will consume canonical Social Lola contracts when a user-facing Social surface needs them; Yara remains the implementation owner.
### eCompanion Integrations / ↔ Cleo
NO ACTION
Provider transport authority is unchanged and is not routed to Yara.
### eCompanion Lola / ✦ Lola
NO ACTION
Lola product/intelligence authority is unchanged.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
REPORTING/DOCTRINE ONLY; no Mobile product deployment required.
Do not:
- Do not absorb Social Lola implementation into Interfaces.
- Do not route provider transport to Yara.
- Do not duplicate Social state in the browser.
- Do not ask the owner to coordinate Iris/Yara/Cleo dependencies.
Evidence:
- Mobile `AGENTS.md` updated with explicit Social Lola/Yara/Cleo boundaries.
- This `HEADQUARTERS_REPORT.md` now carries the same routing.

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
Functional product release/deploy remain `d6a5917…` / `dep-dag4qq3ncjis738ng57g` LIVE.
Standing doctrine commit recognizing Yara: `fa36ba07f979a03ab32501d326b46205da45fa07`.

## EVIDENCE
- `verify-mobile` run `34260544342`: web SUCCESS + native-core SUCCESS.
- Render deploy `dep-dag4qq3ncjis738ng57g`: LIVE on exact tested functional release.
- Runtime `src/http-body.ts`: default JSON limit 1,000,000 bytes.
- Mobile multimodal/wire-limit + voice tests: PASS.
- Mobile `AGENTS.md`: explicit Yara/Social Lola vs Cleo/provider transport authority split.
- No secrets recorded.
