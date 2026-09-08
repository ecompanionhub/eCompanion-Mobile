# AGENTS.md

## Mission
Build eCompanion Mobile / Body into a daily owner client for Lola, conversation, voice/media, activity, device presence/actions, notifications, authorization, and other real eCompanion capabilities as their canonical backend contracts become available.

The owner should use eCompanion, not manage Runtime URLs, scopes, provider IDs, raw device state, or infrastructure.

## Owning authority
Engineer: ◐ Iris 👩🏽‍🎨 — Interfaces.

Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`.

Web production target:
- Render static site: `ecompanion-mobile`
- Service ID: `srv-daat0mu7bikc73c9fiv0`
- Publish path: `web`
- Auto deploy: yes

Native iOS source lives in this repository, but GitHub/Simulator proof is not physical iPhone proof.

## Product authority boundaries
Mobile is a client and device-facing product surface. It does not own neutral backend truth.

Canonical external authorities include:
- Runtime / Maeve: conversations, neutral action lifecycle, auth/policy, shared state, pairing authority;
- Devices / Sanne: physical/local device execution and NODE truth;
- Integrations / Cleo: Discord, Telegram, providers, external delivery;
- Personas / Elin: canonical persona/profile semantics;
- Lola: Lola-specific companion behavior and product logic.

Mobile MUST NOT:
- create local companion identity authority;
- mint authorization or pairing grants;
- embed Runtime/service root credentials;
- create a second action lifecycle;
- fake delivery/device/action success;
- move provider or NODE execution into the client;
- persist browser-only canonical persona/memory/policy truth.

## eCompanion operating doctrine
Owner explicit intent is highest authority. Quinn/Headquarters directives are next. Canonical source and real production/physical truth outrank local assumptions.

WORK loop:
`read relevant report deltas → one bounded source sync → identify highest-value executable product gap → implement → test → fix → verify real path → deploy/install → verify real target → regression guard where useful → continue → update report`.

Do not spend the run repeatedly checking GitHub/Render/CI. Do not stop at source, tests, build, deploy, ACK, or queued state when the real productflow can be taken further.

No product shrink. No unrequested scope expansion. No silent fallback. No duplicate authority. Canonical-path failure fails closed.

## Daily product rules
Mobile-first is a real product form, not desktop shrink.

Prioritize:
- one-handed use and safe areas;
- correct iPhone viewport/keyboard behavior;
- multiline conversation composer;
- stable scroll and conversation continuity;
- real voice/media flows only where supported;
- understandable reconnect/offline/failure states;
- owner-facing device controls backed by canonical device-scoped APIs;
- human-readable action/result state from canonical backend truth;
- accessibility, focus, contrast, semantic controls, reduced motion;
- install/PWA/native identity that uses owner-facing product language.

Reject:
- Runtime URL fields in the normal owner path;
- raw JSON/debug panels as the finished UX;
- manual presence/capability controls that exist only for engineering;
- fake realtime animation;
- optimistic success for real side effects;
- fake notifications or placeholder menus.

## Current scoped web contract
The web client may consume the current device-scoped Runtime Body APIs, including where applicable:
- `POST /api/v1/device-pairing/claim`
- `GET /api/v1/body/me`
- `PUT /api/v1/body/device`
- `PUT /api/v1/body/presence`
- `GET /api/v1/body/chat`
- `POST /api/v1/body/chat/turn`

Use the scoped device credential only for the authority granted to that device. Do not upgrade it into owner/service authority.

## Side effects and failure semantics
For any message/action/device side effect:
- use canonical execution identity where provided;
- avoid blind retry after an uncertain result;
- preserve useful visible state during transient failure;
- distinguish unauthorized, offline, provider rejection, timeout, stale/invalid state, and unavailable capability where the contract exposes them;
- verify the desired post-condition where the owning contract supports it.

Never turn a failed technical operation into fake Lola/system prose that implies success.

## Peer report delta-feed
At the start of relevant work, read this repo's `HEADQUARTERS_REPORT.md` and only materially relevant peer reports:
- `eCompanion-Runtime` for Body/chat/pairing/action/auth contracts;
- `eCompanion-Devices` for NODE/device state/actions;
- `eCompanion-Integrations` for external destinations/delivery;
- `eCompanion-Personas` for persona/profile state;
- `eCompanion-Lola` only when companion behavior/contracts materially affect the Mobile surface. Do not write Lola source from this work lane.

Do not audit all repos by default.

## Build and verification
Current repository verification is defined by `.github/workflows/verify.yml`.

Relevant checks include:
- `node --check web/app.js`
- `node --check web/voice.js`
- `node --check web/sw.js`
- Mobile boundary/static product gate
- Swift `BodyAgentCore` build
- iOS Simulator `BodyAgentCore` build
- iOS Simulator `ECompanionBodyApp` build
- `swift test --package-path native/BodyAgentCore`

Do not weaken authority/security assertions merely to make a build green.

A pre-runner CI failure with no executed steps is not test evidence. Do not blindly rerun unchanged failures.

## Deployment and physical proof
Web: `main` auto-deploys to Render. After product-byte changes, verify the exact commit/deploy reaches LIVE.

Native: source/Simulator build is not a physical install. Physical iPhone claims require the actual intended device/install/session evidence.

Distinguish:
- IMPLEMENTED
- TESTED
- DEPLOYED
- TARGET VERIFIED
- END-TO-END PROVEN

## Security and privacy
- Never commit, log, expose, or report secrets.
- Device credentials remain scoped and revocable by the owning authority.
- Owner authorization is backend-enforced, never UI-only.
- Private context must not leak to Social/external surfaces merely because the client can display it.
- Use least privilege, explicit validation, secure defaults, and fail closed.

## Code standards
Use modern strict production code appropriate to the layer.

For TypeScript areas: strict TypeScript, no `any`, `@ts-ignore`, or `ts-nocheck` shortcuts.

For Swift/native areas: typed deterministic APIs, explicit error handling, clear authority boundaries, no hidden fallback execution.

For web: semantic HTML, modern JavaScript, dependency-light implementation, accessible controls, no placeholder/fake state.

## Cross-project changes
Any change that affects another service/consumer/contract/interface/deployment/capability must be recorded in `HEADQUARTERS_REPORT.md` using the required `CROSS-PROJECT CHANGES` structure, including REQUIRED / OPTIONAL / NO ACTION, compatibility, rollout dependency, do-not rule, and evidence.

Do not use the owner as a message bus.

## Reporting
Maintain root `HEADQUARTERS_REPORT.md` as a compact current product/evidence delta-feed.

Update after meaningful capability, shared-contract change, deployment, target verification, blocker change, Vera production fix, and at end of WORK.

Do not report report-only commits as product progress.

## Acceptance principle
A Mobile capability is not complete because a screen exists or a request returned 200. The owner-facing flow must be understandable, connected to the real owning capability, preserve truthful state/failure semantics, be tested, be deployed/installed where required, and reach the highest honestly verified target level available.