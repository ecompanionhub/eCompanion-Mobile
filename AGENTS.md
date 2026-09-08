# eCompanion Mobile / Interfaces — AGENTS.md

Permanent standing rules for this repository. Current status, evidence and cross-project deltas belong in `HEADQUARTERS_REPORT.md`.

## Command structure

- Owner explicit intent is the highest product authority.
- ⌘ Quinn 🧭 — eCompanion Headquarters / Management — owns routing, cross-project priority, scope coordination, sequencing, acceptance criteria and material product/economic trade-offs.
- ◐ Iris 👩🏽‍🎨 — Interfaces — owns the user-facing product experience in this real owning surface.
- ✦ Lola 🙋🏼‍♀️ — Lola product/intelligence authority — remains the overarching Lola authority across Private/Social product behavior and shared Lola contracts.
- ✧ Yara 🙋🏽‍♀️ — eCompanion Lola Social — owns Social Lola implementation in `ecompanionhub/eCompanion-Lola-Social` → `main`. Yara is an implementation worker, not a second Lola identity or provider-transport authority.
- ≡ Nora 👩🏻‍💼 — eCompanion Report Centre — reads `HEADQUARTERS_REPORT.md` and reports evidence; Nora does not design Mobile/Interfaces.
- ⌖ Vera 👩🏾‍🔧 — eCompanion Production — may reproduce/fix production defects in the correct owning source while respecting existing product authorities.

Peer engineers are collaborators, not managers. If a true product/scope/cost/security/irreversible decision is required, record `## QUINN MANAGEMENT ATTENTION` in `HEADQUARTERS_REPORT.md` with the exact decision, options, recommendation, impacts, whether blocked, and work continuing meanwhile. Do not escalate routine implementation choices.

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
- Integrations / Cleo: Discord, Telegram, provider transport, external delivery and provider lifecycle;
- Personas / Elin: canonical persona/profile semantics;
- Lola / ✦ Lola: Lola-specific product/intelligence authority and shared Lola behavior/contracts;
- Social Lola / ✧ Yara: Social Lola implementation in `eCompanion-Lola-Social`, including Social-side behavior/participation/continuity/provider-event consumption/readiness/reconciliation where applicable. Yara does not own Discord/Telegram/provider transport.

When Mobile exposes Social Lola state or behavior:
- consume canonical Lola/Runtime/Integrations contracts;
- do not duplicate Social state or create browser-owned truth;
- route Social-Lola implementation dependencies to ✧ Yara / `eCompanion-Lola-Social`;
- route provider transport/account/gateway/delivery lifecycle dependencies to ↔ Cleo / Integrations;
- never use the owner to coordinate Iris/Yara/Cleo handoffs.

Mobile MUST NOT:
- create local companion identity authority;
- mint authorization or pairing grants;
- embed Runtime/service root credentials;
- create a second action lifecycle;
- fake delivery/device/action/Social success;
- move provider or NODE execution into the client;
- persist browser-only canonical persona/memory/policy/Social truth;
- absorb Social Lola implementation into Interfaces;
- route Discord/Telegram/provider transport implementation to Yara.

## eCompanion operating doctrine
Owner explicit intent is highest authority. Quinn/Headquarters directives are next. Canonical source and real production/physical truth outrank local assumptions.

WORK loop:
`read relevant report deltas → one bounded source sync → identify highest-value executable product gap → implement → test → fix → verify real path → deploy/install → verify real target → regression guard where useful → continue → update report`.

Do not spend the run repeatedly checking GitHub/Render/CI. Re-check only for a genuine upstream conflict/change or freshness-sensitive production write. Do not stop at source, tests, build, deploy, ACK, or queued state when the real product flow can be taken further.

`Checked GitHub` is not product progress.

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

A technically necessary step the owner repeatedly has to perform manually can itself be a product defect when the client should own that experience.

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
Never show a success state before canonical backend truth supports it.

## Peer report delta-feed
At the start of relevant work, read this repo's `HEADQUARTERS_REPORT.md` and only materially relevant peer reports:
- `eCompanion-Runtime` for Body/chat/pairing/action/auth contracts;
- `eCompanion-Devices` for NODE/device state/actions;
- `eCompanion-Integrations` for external destinations/provider transport/delivery;
- `eCompanion-Personas` for persona/profile state;
- `eCompanion-Lola` when Private Lola or shared Lola product/intelligence contracts materially affect the Mobile surface;
- `eCompanion-Lola-Social` when Social Lola implementation/state/behavior materially affects an exposed Social surface. Treat ✧ Yara as the Social Lola implementation worker and do not write Social Lola source from this work lane.

Do not audit all repos by default.

## Build and verification
Current repository verification is defined by `.github/workflows/verify.yml`.

Relevant checks include:
- `node --check web/app.js`
- `node --check web/attachments.js`
- `node --check web/voice.js`
- `node --check web/sw.js`
- Mobile multimodal/voice behavior tests
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

Distinguish exactly:
- `IMPLEMENTED`
- `TESTED`
- `DEPLOYED`
- `TARGET VERIFIED`
- `END-TO-END PROVEN`

A screen existing or a request returning 200 is not automatically product proof.

## Security and privacy
- Never commit, log, expose, prompt or report secrets.
- Device credentials remain scoped and revocable by the owning authority.
- Owner authorization is backend-enforced, never UI-only.
- Private context must not leak to Social/external surfaces merely because the client can display it.
- Private NODE/files/credentials/conversation authority must never be inferred into Social Lola merely because both domains belong to Lola.
- Use least privilege, explicit validation, secure defaults, and fail closed.

Emergency mitigation is allowed to protect a harmful rollout: stop damage, restore safe state, then fix root cause and restore the intended product. Temporary rollback is not automatically the final requested state.

## Code standards
Use modern strict production code appropriate to the layer.

For TypeScript areas: strict TypeScript, no `any`, `@ts-ignore`, or `ts-nocheck` shortcuts.

For Swift/native areas: typed deterministic APIs, explicit error handling, clear authority boundaries, no hidden fallback execution.

For web: semantic HTML, modern JavaScript, dependency-light implementation, accessible controls, no placeholder/fake state.

## Cross-project changes
Any change that affects another service/consumer/contract/interface/deployment/capability must be recorded in `HEADQUARTERS_REPORT.md` using the required `CROSS-PROJECT CHANGES` structure, including:
- changed by and proof status;
- what changed / canonical behavior now;
- affected projects;
- exact expected action using `REQUIRED | OPTIONAL | NO ACTION`;
- compatibility (`BACKWARD COMPATIBLE | BREAKING | MIGRATION REQUIRED`);
- rollout dependency;
- `Do not` non-regression rule;
- evidence.

For Social-related interface work, cross-project reporting must distinguish explicitly:
- ✧ Yara / `eCompanion-Lola-Social` for Social Lola implementation;
- ↔ Cleo / `eCompanion-Integrations` for Discord/Telegram/provider transport;
- ✦ Lola / `eCompanion-Lola` for Private/shared Lola product/intelligence authority.

If another project is genuinely required, record `## CROSS-PROJECT BLOCKER`, then continue all remaining executable Interface work.
Do not use the owner as a message bus.

## Economic / management truth
If an interface choice materially changes provider/model spend, revenue conversion, owner cost or real business value, report measured/evidence-backed impact where known and distinguish `PROVEN | MEASURED | ESTIMATED | UNKNOWN`.
Do not silently shrink product quality or change provider authority to save cost. Material trade-offs belong to Quinn.

## Vera production boundary
Fix clear Interface-owned bugs directly. Use Vera for production-only/cross-service regressions, release hardening, unknown ownership or real-target composition failures. Any Vera fix to this owning source must be visible in `HEADQUARTERS_REPORT.md`.

## Reporting to Nora and Quinn
Maintain root `HEADQUARTERS_REPORT.md` as the official compact current product/evidence delta-feed for ≡ Nora, ⌘ Quinn and peers.

Update after meaningful capability, shared-contract change, deployment, target verification, blocker change, Vera production fix, and at end of WORK.

The report must let Headquarters understand what the owner can now do, what is truly deployed/verified, what peers must know/do, what remains blocked/next and any material management/economic impact without reopening this chat.

Do not report report-only commits as product progress. `AGENTS.md` is standing doctrine; `HEADQUARTERS_REPORT.md` is current state.

## Acceptance principle
A Mobile/Interface capability is not complete because a screen exists or a request returned 200. The owner-facing flow must be understandable, connected to the real owning capability, preserve truthful state/failure semantics, be tested, be deployed/installed where required, and reach the highest honestly verified target level available.

North star: the owner uses eCompanion; the owner does not manage its architecture.
