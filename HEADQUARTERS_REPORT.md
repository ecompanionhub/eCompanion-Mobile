# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-11
Engineer: Iris / Mobile Interfaces implementation worker
Canonical source: `ecompanionhub/eCompanion-Mobile` -> `main`
Mode: WORK / SOURCE ONLY; owner explicitly forbids production deployment/install.
Baseline: `57c7a3a67c414d3d009cafa003a8ff7dfeb77d7b` (one bounded fast-forward from canonical main).
Candidate: this STABLE commit, `fix: preserve live Lola call continuity and truthful media lifecycle [skip render]`.

## PRODUCT RESULT
- Preserved the existing app, pairing, attachments, conversation history, multiline drafts, and browser voice functionality.
- Chat and Call are immediate primary controls. Chat docks the existing live call frame; reopening Call uses the same frame/session. Actual renderer video supplies Lola movement, body language and gaze throughout that switch.
- Routine call listening/processing/speaking labels are accessible status text rather than prominent overlays. Captions remain available under Conversation. Errors, connection waits and uncertain cleanup remain visible.
- Renderer speaking cues require actual matching speech events. Microphone cues require actual captured voiced samples; browser voice cues follow the browser speech callbacks. No idle animation, fabricated perception, local intelligence, new Lola identity or second runtime was introduced.
- A live call remains explicitly open until ended. Chat history and drafts remain accessible; sending a typed turn during an active call is held with an explanation, preserving the draft and avoiding a parallel owner turn while microphone input is active. No automatic send occurs later.

## MOBILE DEFECTS FIXED
- Baseline `web/app.js:349` contained a literal newline in a single-quoted string. Explicit ESM syntax checking reproduced `SyntaxError: Invalid or unexpected token`; the entrypoint now executes in the DOM contract test.
- Room join previously implied listening without live remote media. Both remote audio/video tracks must now be playable; missing media times out visibly and media loss releases capture.
- Audio upload previously called playback-complete immediately. Completion now requires matching renderer started/stopped events for the active inference; interrupted, stale, foreign, duplicate and missing output are not successful playback.
- Barge-in stops buffered renderer speech as well as interrupting the canonical Runtime generation.
- Failed joins, remote end, microphone loss, call transport errors, late microphone permission and late session/renderer allocations now clean up locally. Pending renderer allocation settles before canonical session deletion. Cleanup uncertainty stays visible.
- Request deadlines and bounded microphone buffering fail closed rather than accumulating stale speech indefinitely. Old asynchronous work cannot revive an ended call or mutate a replacement session.
- Call resume is restricted to canonical `chatId=body` sessions; Social/provider sessions are not resumed into this surface.
- Switching from dictation into Call discards pending dictation rather than accidentally submitting a concurrent chat turn.
- AudioContext is resumed in the Call gesture for iPhone audio activation. Physical iPhone behavior still needs proof.
- Service-worker shell cache advanced to v8 for any later authorized release.

## PROOF STATUS
IMPLEMENTED: YES for the source changes above.
TESTED: YES, local Windows / Node v24.19.0 / Python 3.12.10.
- `node --test test/*.test.mjs`: 25 passed, 0 failed.
- Includes explicit ESM syntax checks for app/call/voice/attachments/sw; actual app entrypoint with controlled DOM/service dependencies; Chat/Call frame and draft continuity; canonical audio, interruption, media loss, cleanup and cancellation regressions; existing attachments/voice behavior.
- `python tools/verify_workflow_policy.py`: PASS (manual workflow only; no automatic exceptions).
- `python tools/mobile_boundary_static_gate.py`: PASS.
- `git diff --check`: PASS.
- Manual remote qualification now includes call syntax and all web behavior tests. No remote workflow was dispatched.
DEPLOYED: NO deployment requested or performed in this work. Commit carries `[skip render]` to suppress the repository's Render auto-deploy.
TARGET VERIFIED: NO new real browser/iPhone/call target proof. Browser runtime returned no available browser; discovery returned an empty list. DOM fixtures are not visual browser proof.
END-TO-END PROVEN: NO authenticated microphone -> Runtime -> canonical Lola -> synthesized audio -> renderer playback call was available in this execution environment.
Native: untouched. Swift/Xcode/iOS Simulator unavailable on this Windows host; no new native build or physical install is claimed.

## CROSS-PROJECT CHANGES
### CHANGE: truthful Mobile media lifecycle and continuous call presentation
Changed by: Iris / Interfaces.
Proof status: IMPLEMENTED + TESTED, source only.
Canonical behavior now: Mobile consumes the existing Body voice API and echo-only scoped renderer; provider playback events control presentation and playback acknowledgment. Runtime remains conversation/session authority, Integrations remains renderer/provider authority, Lola remains intelligence authority.
Affected projects and expected action:
- Runtime / Maeve: OPTIONAL - during authorized call qualification, verify resumed Body generation and playback acknowledgments against canonical session history.
- Integrations / Cleo: OPTIONAL - during authorized qualification, verify actual echo renderer media, correlated `inference_id` speech events and interruption. No transport/account/gateway change requested.
- Private/shared Lola / Lola: NO ACTION - no intelligence/identity/provider selection change.
- Social Lola / Yara: NO ACTION - no Social source or implementation change; its sessions are excluded from Body call resume.
Compatibility: BACKWARD COMPATIBLE; no backend schema or credential scope changes. Mobile now requires the existing canonical `echo: true` renderer declaration and refuses unsupported/failing media.
Rollout dependency: owner authorization for a later production release; real paired phone and canonical voice/renderer availability for target proof.
Do not: restore upload-as-playback success, animate fake gaze/listening, replay uncertain audio writes, resume Social calls into Body, add browser-owned intelligence or move provider authority into Mobile.
Evidence: `test/mobile-app.test.mjs`, `test/mobile-call.test.mjs`, `test/mobile-voice.test.mjs`; canonical Runtime `3058dcb5b8efd2fe97379cf8b1b507786224676c`, `src/body-voice-api.ts`, `src/voice.ts`, `src/store/voice-postgres.ts`.

## CROSS-PROJECT BLOCKER
Blocked proof: real authenticated call, physical iPhone audio/media behavior and renderer speech-event correlation.
Owning dependencies: paired owner device/session; Runtime Body voice and Integrations scoped echo renderer. No bypass or owner-managed URL/credential flow introduced.
Implementation can continue independently: bounded requested source work is complete; remaining proof requires the actual target environment and later authorized release.
Always-on idle/perception/gaze intelligence is not exposed by this echo-media contract and has not been invented in Mobile.

## ECONOMIC / MANAGEMENT TRUTH
Provider/model choice and pricing: unchanged by Mobile. Measured cost impact: UNKNOWN. Docking deliberately keeps the same owner-started call alive until End; it does not start another renderer or call. No claim of reduced provider spend.
No Quinn product/cost decision was required for this owner-directed source-only work.

## HISTORICAL PRODUCTION EVIDENCE (NOT REVERIFIED THIS RUN)
Previous report recorded Mobile `246ba6f6866e665bb03cbb41965d903f3ee2ded2` / `dep-dag61erncjis738p4hf0` LIVE and attachment limits restored to 8 items, 20 MiB/item, 25 MiB/turn. That is historical evidence, not a claim about current production main.
Existing unresolved proof/dependencies: authenticated >650 KB attachment upload; durable owner-resolvable artifact binaries; device-safe Task progress/control feed; physical native iPhone installation.

## REFERENCES
- [Renderer speech events](https://docs.tavus.io/sections/event-schemas/conversation-started-stopped-speaking)
- [Renderer interruption](https://docs.tavus.io/sections/event-schemas/conversation-interrupt)
- [Echo-only media mode](https://docs.tavus.io/sections/conversational-video-interface/echo-mode)
- [Daily participant/media state](https://docs.daily.co/reference/daily-js/events/participant-events)
- [Render source-only push marker](https://render.com/docs/deploys#skipping-an-auto-deploy)
