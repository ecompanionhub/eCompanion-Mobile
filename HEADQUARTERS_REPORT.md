# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08
Engineer: ◐ Iris 👩🏽‍🎨
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current source head: `a150b8bd1a90a39f033f9c7c8709bd7a685ea061` (`AGENTS.md` standing WORK contract).
Current production / physical target: Render static site `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); no new physical iPhone install is claimed.
Current release/version where relevant: current Render deploy `dep-dag3vl15efls73fi9kig` LIVE on source head `a150b8bd1a90a39f033f9c7c8709bd7a685ea061`. Functional published `web/` product bytes are unchanged from tested product head `91996bc73eaaa8bf112d8a41e8a63830bd207714`.

GitHub compare `91996bc… → a150b8b…` changes only `HEADQUARTERS_REPORT.md` and `AGENTS.md`; no `web/` or native product bytes changed.

## PRODUCT RESULT
The owner-facing Mobile product is a daily companion client instead of a technical Body/Runtime control surface.

The owner can:
- open directly into the assigned companion conversation without configuring Runtime URLs;
- pair/reconnect only when a device credential is actually needed;
- keep visible conversation state through recoverable refresh/send failures;
- receive an explicit reconnect state when the scoped device credential expires or is revoked;
- avoid blind resend after an uncertain send result;
- rename a connected device through the canonical scoped Body device contract;
- forget the local credential without the UI pretending that local deletion equals server-side revocation;
- install the PWA under the owner-facing identity `eCompanion` / `Lola` rather than `eCompanion Body` / `eBody`.

The doctrine/`AGENTS.md` update in the current source head is standing work-environment metadata only; it adds no new owner-facing capability.

## COMPLETED
- Companion-first Mobile conversation home.
- Product-owned production Runtime routing; stale locally saved Runtime URL no longer controls production routing.
- Conditional pairing/reconnect surface using scoped device credentials.
- Recoverable conversation failure UX with duplicate-send caution on uncertain result.
- Owner-facing technical Runtime/presence/capability controls removed from normal UX.
- Connected-only `This phone` settings with real `Save changes` through `PUT /api/v1/body/device`.
- Honest local `Forget on this phone` semantics.
- Companion-first PWA install identity and refreshed service-worker shell cache.
- Regression gate for authority boundaries, recovery UX, installed identity and native BodyAgent invariants.

## PROOF STATUS
### IMPLEMENTED
- IMPLEMENTED — capabilities above exist in canonical source.

### TESTED
- TESTED — GitHub Actions `verify-mobile` run `34252191240` on product head `91996bc73eaaa8bf112d8a41e8a63830bd207714` completed successfully.
- TESTED — web JavaScript syntax PASS and Mobile boundary/static product gate PASS.
- TESTED — native BodyAgentCore build PASS, iOS Simulator BodyAgentCore build PASS, ECompanionBodyApp iOS Simulator build PASS, BodyAgentCore tests PASS.

### DEPLOYED
- DEPLOYED — current Render deploy `dep-dag3vl15efls73fi9kig` is LIVE on source head `a150b8bd1a90a39f033f9c7c8709bd7a685ea061`.
- DEPLOYED functional product bytes are the already-tested `91996bc…` `web/` tree; compare confirms later commits changed only report/standing instructions.

### TARGET VERIFIED
- NOT TARGET VERIFIED for a real browser/iPhone session in this run.
- NOT TARGET VERIFIED for a physical native iPhone install. Simulator proof is not physical-device proof.

### END-TO-END PROVEN
- NOT END-TO-END PROVEN for physical iPhone chat/voice/background/notification continuity.
- NOT END-TO-END PROVEN for owner-visible canonical action progress because Mobile lacks a device/owner-safe Runtime action-read contract.

## PRODUCTION / PHYSICAL STATE
Web production:
- Render service: `ecompanion-mobile`
- Service ID: `srv-daat0mu7bikc73c9fiv0`
- Source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`
- Publish path: `web`
- Auto deploy: yes
- Current deploy: `dep-dag3vl15efls73fi9kig` → LIVE
- Current source head deployed: `a150b8bd1a90a39f033f9c7c8709bd7a685ea061`
- Last tested functional product head: `91996bc73eaaa8bf112d8a41e8a63830bd207714`

Native source remains in the same repository. Native Simulator build/tests are green on `91996bc…`; no physical iPhone install is claimed.

## BLOCKERS
- Real browser/iPhone target verification is not currently available from this execution environment.
- Owner-friendly new-device pairing grant issuance remains Runtime authority; Mobile may claim a grant but must not mint authorization.
- Canonical action progress/result cannot yet be safely read by the Mobile device credential because the current Runtime action-read path is companion-service authenticated.
- Server-side credential revocation remains owner/Runtime authority.

## NEXT EXECUTABLE WORK
Continue owner-facing Mobile work over existing scoped Body contracts: conversation continuity, reconnect/offline/install resilience, accessibility, and truthful state already available to the device.

Integrate action progress, pairing issuance, provider delivery, persona state, or richer device execution as soon as the owning project exposes the required safe canonical contract. Do not build substitutes in Mobile.

## CROSS-PROJECT CHANGES
### CHANGE: Mobile consumes scoped Body contracts without exposing backend architecture
Changed by:
eCompanion Interfaces / Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
The normal Mobile product uses the existing Runtime Body APIs and device-scoped credential while hiding Runtime URLs, raw presence/capability controls and backend architecture from the owner.
Affected projects:
- eCompanion Runtime / Maeve
Canonical contract / behavior now:
Mobile remains a scoped client. Runtime owns pairing authority, conversation truth, neutral action truth and authorization.
Available capability / interface:
- `POST /api/v1/device-pairing/claim`
- `GET /api/v1/body/me`
- `PUT /api/v1/body/device`
- `PUT /api/v1/body/presence`
- `GET /api/v1/body/chat`
- `POST /api/v1/body/chat/turn`
Expected action by other projects:
### Runtime / Maeve
NO ACTION
Existing Body contracts are consumed unchanged by the current release.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not reintroduce browser-owned companion identity, browser-only policy/action truth, owner-entered Runtime infrastructure configuration, or raw technical controls into the normal Mobile flow.
Evidence:
- tested product head `91996bc73eaaa8bf112d8a41e8a63830bd207714`
- verify run `34252191240` PASS
- current Render deploy `dep-dag3vl15efls73fi9kig` LIVE

## CROSS-PROJECT BLOCKERS
### CROSS-PROJECT BLOCKER: canonical action progress in Mobile
Blocked capability:
Owner-visible real action progress/result/verification in Mobile.
Owning dependency:
eCompanion Runtime / Maeve
Required from dependency:
A device- or owner-safe read contract for canonical Runtime action state/result/verification without exposing a companion-service secret.
Why required:
Runtime owns action truth. Mobile holds a scoped device credential and must not create a second action authority or embed service credentials.
Current dependency status:
Runtime canonical action lifecycle: DEPLOYED. Mobile-safe action read: NOT YET PROVEN AVAILABLE.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Conversation, reconnect, device, install/offline and accessibility UX over current Body contracts.

### CROSS-PROJECT BLOCKER: owner pairing issuance
Blocked capability:
Fully owner-friendly new-device pairing initiation.
Owning dependency:
eCompanion Runtime / Maeve
Required from dependency:
Canonical owner-authorized pairing grant issuance/approval suitable for an owner surface.
Current dependency status:
Claim contract exists; owner-facing issuance path is NOT YET PROVEN AVAILABLE to Mobile.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
All already-authorized Mobile/client UX work.

## PROVENANCE
Canonical Mobile source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`.

Production: Render `srv-daat0mu7bikc73c9fiv0`, publish path `web`, auto deploy enabled.

Current source/deploy head `a150b8bd…` differs from tested product head `91996bc…` only by `HEADQUARTERS_REPORT.md` and root `AGENTS.md`; compare proves no product-byte drift.

Root `AGENTS.md` now contains standing Mobile WORK rules: authority boundaries, canonical deploy target, test commands, security/no-fallback rules, peer-report delta rules, proof semantics and reporting requirements.

## EVIDENCE
- tested functional product head: `91996bc73eaaa8bf112d8a41e8a63830bd207714`
- verify-mobile run `34252191240`: web SUCCESS + native-core SUCCESS
- current source head: `a150b8bd1a90a39f033f9c7c8709bd7a685ea061`
- compare `91996bc… → a150b8b…`: only `HEADQUARTERS_REPORT.md` + `AGENTS.md`
- Render deploy: `dep-dag3vl15efls73fi9kig` → LIVE
- root `AGENTS.md` standing contract added at `a150b8bd1a90a39f033f9c7c8709bd7a685ea061`
- no secrets recorded
