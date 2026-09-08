# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08
Engineer: ◐ Iris 👩🏽‍🎨
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current production / physical target: Render static site `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); no new physical iPhone install is claimed.
Current release/version where relevant: tested/deployed product head `91996bc73eaaa8bf112d8a41e8a63830bd207714`; latest web-byte changes include `679ac0a40257ec515cb92375b1646a5119b4e8f8`, `83791025f90570b37006f810b1106d140df3fc53`, and `26733fc16f5b2eba980f18f35840e0f20d22dff7`.

`HEADQUARTERS_REPORT.md` is outside the `web/` publish tree. A report-only commit can trigger Render auto-deploy without changing functional web bytes; functional product claims are therefore tied to the tested `web/` tree, not merely the newest metadata commit.

## PRODUCT RESULT
The owner-facing Mobile product is now a daily companion client instead of a technical Body/Runtime control surface.

The owner can:
- open the Mobile web/PWA into the assigned companion conversation without configuring Runtime URLs;
- pair only when the phone actually needs a device credential;
- keep the visible conversation when a transient refresh/send failure occurs instead of losing the chat surface;
- get an explicit reconnect state when a device credential expires or is revoked;
- avoid blind resend behavior after an uncertain send result, reducing duplicate-message risk;
- open `This phone` only after the device is connected, rename the connected device through the canonical scoped `/api/v1/body/device` contract, and forget the local credential without the UI pretending that local deletion equals server-side revocation;
- install the PWA under the owner-facing identity `eCompanion` / `Lola` rather than `eCompanion Body` / `eBody`.

The installed shell cache was advanced after the companion-first redesign so an existing installed PWA can replace the older cached shell when the new service worker activates.

## COMPLETED
- Companion-first Mobile conversation home.
- Product-owned production Runtime routing; stale locally saved Runtime URL no longer silently overrides production configuration.
- Conditional pairing/reconnect surface.
- Scoped device credential remains the only Mobile authorization authority.
- Recoverable conversation failures preserve already-visible messages where safe.
- 401/403 device-auth failure clears the invalid local credential and returns the owner to a real reconnect path.
- Uncertain send failure warns the owner to refresh before sending again instead of automatically duplicating the turn.
- Owner-facing technical controls (`Runtime connection`, manual availability/offline controls, raw capability refresh) removed from normal UI.
- Connected-only device settings now expose a real `Save changes` action backed by the existing Body device update contract.
- Local credential removal is labeled honestly as `Forget on this phone`; server-side revocation is not faked.
- Installed PWA identity changed to `eCompanion` / `Lola` with owner-facing copy.
- Service-worker shell cache advanced to `ecompanion-mobile-v3`.
- Product gate now protects companion-first install identity, connected-only settings, product-owned Runtime routing, reconnect behavior and duplicate-risk messaging.

## PROOF STATUS
### IMPLEMENTED
- IMPLEMENTED — all capabilities above exist in canonical `eCompanion-Mobile/main`.

### TESTED
- TESTED — GitHub Actions `verify-mobile` run `34252191240` on head `91996bc73eaaa8bf112d8a41e8a63830bd207714` completed successfully.
- TESTED — web job: JavaScript syntax PASS and Mobile boundary/static product gate PASS.
- TESTED — native-core job: Swift build PASS, BodyAgentCore iOS Simulator build PASS, ECompanionBodyApp iOS Simulator build PASS, BodyAgentCore tests PASS.
- An earlier new assertion failed only because test copy used lowercase `server-side` while the product copy used `Server-side`; the assertion was corrected before the successful run. No unchanged failing CI was repeatedly rerun.

### DEPLOYED
- DEPLOYED — Render `ecompanion-mobile` deploy `dep-dag3jhgae00c738d3sq0` reached LIVE on exact tested head `91996bc73eaaa8bf112d8a41e8a63830bd207714`.

### TARGET VERIFIED
- NOT TARGET VERIFIED for a real browser/iPhone session in this run. Render LIVE is deployment proof, not external client proof.
- NOT TARGET VERIFIED for a physical native iPhone install. iOS Simulator build/test proof is not physical-device proof.

### END-TO-END PROVEN
- NOT END-TO-END PROVEN for physical iPhone chat/voice/background/notification continuity in this run.
- NOT END-TO-END PROVEN for owner action progress because Mobile does not yet have a device/owner-safe canonical Runtime action-read contract.

## PRODUCTION / PHYSICAL STATE
Web production:
- Render service: `ecompanion-mobile`
- Service ID: `srv-daat0mu7bikc73c9fiv0`
- Source: `https://github.com/ecompanionhub/eCompanion-Mobile`
- Branch: `main`
- Publish path: `web`
- Auto deploy: yes
- Tested product head: `91996bc73eaaa8bf112d8a41e8a63830bd207714`
- Verified LIVE deploy for that head: `dep-dag3jhgae00c738d3sq0`

Native source remains in the same repository. Native BodyAgentCore and iOS Simulator app build are TESTED on the same head, but there is no new physical iPhone installation/target verification claim.

## BLOCKERS
- Real browser/iPhone target verification is still absent from the current execution environment.
- Owner-friendly issuance/approval of new device pairing grants remains Runtime authority; Mobile consumes the grant but does not mint authorization.
- Truthful canonical action progress/result cannot yet be shown directly in Mobile from a device credential because Runtime's current action-read API is companion-service authenticated, not a device/owner-safe Mobile read contract.
- Server-side credential revocation remains owner/Runtime authority; the Mobile device credential cannot silently promote itself into revocation authority.

## NEXT EXECUTABLE WORK
Within Interfaces authority, continue improving the daily Mobile experience over existing real Body contracts: conversation continuity, pairing/reconnect clarity, install/offline behavior, accessibility and truthful presentation of state already exposed to the device.

Do not invent action progress, pairing authority, provider delivery state or server-side credential revocation in the client. Integrate those immediately when the owning contracts become available.

## CROSS-PROJECT CHANGES
### CHANGE: Mobile uses product-owned Runtime routing and scoped Body contracts
Changed by:
eCompanion Interfaces / Iris
Status:
DEPLOYED
Change type:
UI + BEHAVIOR
What changed:
The normal Mobile experience no longer exposes Runtime URL configuration or technical device-state controls. Production Runtime routing is product configuration. Device pairing, self state, device update, presence and chat continue through the existing canonical Runtime Body APIs with the device-scoped credential.
Why:
The owner should use the companion product, not configure backend architecture.
Affected projects:
- eCompanion Runtime
Canonical contract / behavior now:
Mobile consumes the existing Runtime Body contract and does not create local identity, policy, companion or action truth.
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
Existing Body contracts are consumed unchanged by this release.
Compatibility:
BACKWARD COMPATIBLE
Rollout dependency:
NONE
Production state:
DEPLOYED
Do not:
Do not reintroduce browser-owned companion identity, browser-only policy truth, owner-entered Runtime infrastructure configuration, or raw technical controls into the normal Mobile flow.
Evidence:
- product recovery/routing gate head `91996bc73eaaa8bf112d8a41e8a63830bd207714`
- Render deploy `dep-dag3jhgae00c738d3sq0` LIVE
- verify-mobile run `34252191240` PASS

## CROSS-PROJECT BLOCKERS
### CROSS-PROJECT BLOCKER: canonical action progress in Mobile
Blocked capability:
Owner-visible real action progress/result/verification in the Mobile companion UI.
Owning dependency:
eCompanion Runtime / Maeve
Required from dependency:
A device- or owner-safe read contract that exposes the canonical Runtime action state/result/verification needed by Mobile without embedding a companion-service secret or creating a second action authority.
Why required:
The deployed canonical Runtime action lifecycle exists, but `/api/companion/operations/actions` is protected by companion-service authentication. Mobile holds a scoped device credential and must not receive service credentials.
Current dependency status:
DEPLOYED for Runtime canonical action lifecycle; Mobile-safe action read contract is not currently available/proven.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
Conversation, pairing/reconnect, device, install/offline and accessibility UX over current scoped Body contracts.

### CROSS-PROJECT BLOCKER: owner pairing issuance
Blocked capability:
A fully owner-friendly new-device pairing flow originating from the Mobile product without manual backend-level handling.
Owning dependency:
eCompanion Runtime / Maeve
Required from dependency:
Canonical owner-authorized pairing grant issuance/approval suitable for the intended owner surface.
Why required:
Mobile may claim a one-time grant but may not mint authorization itself.
Current dependency status:
Claim contract exists; owner-facing issuance path is not proven available to this Mobile surface.
Can continue meanwhile:
YES
Executable work remaining meanwhile:
All already-authorized device/client UX work.

## PROVENANCE
Canonical Mobile development source:
- GitHub `ecompanionhub/eCompanion-Mobile` → `main`.

Web production:
- Render service `srv-daat0mu7bikc73c9fiv0`.
- Render source is the same GitHub repository/branch.
- Publish path is `web`.
- Auto-deploy is enabled.
- Tested/deployed product head: `91996bc73eaaa8bf112d8a41e8a63830bd207714`.
- Verified LIVE deploy for that head: `dep-dag3jhgae00c738d3sq0`.

Relevant product commits in this wave:
- `aa2fb9137d7772887cc9dcca7d37ba245265bc2b` — recoverable conversation failures.
- `0c00637c754aec21399113ee01824e630695f9db` — product-safe reconnect/send uncertainty and canonical Runtime routing.
- `679ac0a40257ec515cb92375b1646a5119b4e8f8` — connected-only actionable device settings.
- `83791025f90570b37006f810b1106d140df3fc53` — companion-first installed PWA identity.
- `26733fc16f5b2eba980f18f35840e0f20d22dff7` — refreshed installed shell cache.
- `91996bc73eaaa8bf112d8a41e8a63830bd207714` — regression gate covering the resulting product state.

Native iOS source is in the same repository, but GitHub source/Simulator proof does not equal physical iPhone installation.

## EVIDENCE
- verify-mobile run `34252191240`: web SUCCESS + native-core SUCCESS.
- JavaScript syntax: PASS.
- Mobile boundary/static product gate: PASS.
- Swift BodyAgentCore build: PASS.
- BodyAgentCore iOS Simulator build: PASS.
- ECompanionBodyApp iOS Simulator build: PASS.
- BodyAgentCore tests: PASS.
- Render service: `srv-daat0mu7bikc73c9fiv0`.
- Render tested-head deploy: `dep-dag3jhgae00c738d3sq0` → LIVE.
- No secrets are recorded in this report.
