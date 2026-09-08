# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08T21:27+02:00
Engineer: ◐ Iris 👩🏽‍🎨 + ⌖ Vera 👩🏾‍🔧 Production
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK / PRODUCTION FIX
Canonical source: `ecompanionhub/eCompanion-Mobile` → `main`
Current production target: Render `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`); physical iPhone install not claimed.
Current functional release: `246ba6f6866e665bb03cbb41965d903f3ee2ded2`
Current verified deploy: `dep-dag61erncjis738p4hf0` → LIVE

✧ Yara 🙋🏽‍♀️ remains the Social Lola implementation worker for `ecompanionhub/eCompanion-Lola-Social`; this does not change Mobile authority.

## PRODUCT RESULT
The temporary 650 KB Mobile attachment ceiling is gone.

Runtime production now exposes enough Body JSON capacity for the existing canonical multimodal contract, and Mobile once again enforces the intended semantic limits only:
- maximum 8 attachments;
- maximum 20 MiB per attachment;
- maximum 25 MiB combined per turn.

Installed Mobile shells are advanced to `ecompanion-mobile-v5` so the updated attachment behavior replaces the cached v4 module.

This source is TESTED and DEPLOYED. A real authenticated browser/iPhone upload above 650 KB has not been exercised from this execution environment, so larger owner uploads are not claimed TARGET VERIFIED or END-TO-END PROVEN yet.

## VERA PRODUCTION FIX

### Incident — temporary 650 KB client mitigation remained after Runtime transport repair
Status: FIXED + TESTED + DEPLOYED

Owning dependency fixed first:
- ⌖ Vera repaired Runtime `/api/v1/body/chat/turn` to use a route-specific 36 MiB JSON ceiling while unrelated Runtime routes keep the generic 1 MB limit.
- Runtime replacement release `434484a49a42d8092e62c09529546c0e805323f9` / `dep-dag5ue67bikc73d84irg` is LIVE.

Mobile changes:
- Removed `MAX_WIRE_ATTACHMENT_BYTES = 650_000` and its temporary wire-level rejection from `web/attachments.js`.
- Preserved canonical semantic limits: 8 files, 20 MiB/item, 25 MiB/turn.
- Reworked attachment regressions to cover item/count/combined semantic boundaries, including exact accepted limits.
- Advanced installed shell cache `ecompanion-mobile-v4 → ecompanion-mobile-v5`.

First Mobile candidate exposed a stale CI assertion requiring the old v4 cache name. The product behavior tests themselves passed. Vera updated the static boundary gate to require v5, then allowed the full verification run to complete.

Exact current test proof:
- GitHub Actions `verify-mobile` run `34268693649`: SUCCESS on `246ba6f6866e665bb03cbb41965d903f3ee2ded2`.
- Web job: SUCCESS.
- JavaScript syntax: PASS.
- Multimodal + voice behavior: PASS.
- Mobile boundary/static gate: PASS.
- Native BodyAgentCore build: PASS.
- BodyAgentCore iOS Simulator build: PASS.
- ECompanionBodyApp iOS Simulator build: PASS.
- Native BodyAgentCore tests: PASS.

Deployment proof:
- Render exact deploy `dep-dag61erncjis738p4hf0` on `246ba6f6866e665bb03cbb41965d903f3ee2ded2`: LIVE.

## PROOF STATUS
### Canonical larger multimodal Mobile limits
IMPLEMENTED: YES.

TESTED: YES — `verify-mobile` run `34268693649` completed SUCCESS on exact current release.

DEPLOYED: YES — Render deploy `dep-dag61erncjis738p4hf0` is LIVE.

TARGET VERIFIED: PARTIAL — exact web release is live; no authenticated real browser/iPhone >650 KB turn was executed here.

END-TO-END PROVEN: NO for >650 KB owner upload until a real authenticated Body conversation turn carrying such an attachment completes and is visible in persisted conversation history.

### Existing multimodal/voice client behavior
IMPLEMENTED: YES.
TESTED: YES on current release.
DEPLOYED: YES.
TARGET VERIFIED: no new real authenticated owner-session proof in this run.
END-TO-END PROVEN: no for persistent autonomous Lola task journey.

## COMPLETED
- Restored Mobile to Runtime's canonical 8 / 20 MiB / 25 MiB attachment semantics.
- Removed the obsolete 650 KB transport workaround after Runtime fixed the owning wire contract.
- Updated multimodal regressions to the real current contract.
- Refreshed installed PWA shell to v5.
- Fixed the stale cache-version CI assertion exposed by the first release candidate.
- Completed the strongest available full Mobile verification across web and native simulator paths.
- Deployed the exact tested current release.

Existing deployed capabilities remain:
- text-only, file-only and text + files conversation turns;
- typed image/audio/video/document preparation with SHA-256 and canonical Base64;
- attachment selection/removal and persisted descriptor presentation;
- owner-interruptible browser voice playback;
- no unsafe concurrent owner turn when speech arrives during an in-flight turn.

## PRODUCTION / PHYSICAL STATE
- Mobile web: Render `srv-daat0mu7bikc73c9fiv0`, publish path `web`, auto-deploy enabled.
- Functional release: `246ba6f6866e665bb03cbb41965d903f3ee2ded2`.
- Deploy: `dep-dag61erncjis738p4hf0` → LIVE.
- GitHub Actions: `34268693649` → SUCCESS.
- Installed shell cache: `ecompanion-mobile-v5`.
- Physical iPhone: NOT TARGET VERIFIED in this run.
- Physical NODE-01: no new Mobile proof; Mobile does not infer device availability from stale evidence.

## BLOCKERS
- Real authenticated >650 KB browser/iPhone Body upload is not yet TARGET VERIFIED.
- Mobile still lacks a device/owner-safe canonical Runtime Task progress/control feed for working presence and pause/cancel/resume/supersede UI.
- Current conversation attachment path persists descriptors, not durable owner-resolvable task artifact binaries.
- Provider-grade low-latency duplex voice is not yet proven available to Mobile.
- Physical native iPhone install remains unverified.

The old Runtime Body 1 MB wire mismatch is RESOLVED and is no longer a cross-project blocker.

## NEXT EXECUTABLE WORK
- Target-verify one real authenticated Mobile attachment above 650 KB through `POST /api/v1/body/chat/turn` and confirm persisted attachment history. Do not fake this without a real paired owner/device session.
- Consume canonical Task progress/control only when Runtime exposes a browser/device-safe owner contract; do not use executor/private-service APIs as fake activity state.
- Integrate durable artifact references and realtime duplex voice when their owning contracts are production-ready.

For Social Lola UI dependencies, route Social implementation to ✧ Yara and provider transport to ↔ Cleo; Mobile remains presentation/client authority.

## CROSS-PROJECT CHANGES

### CHANGE: Mobile multimodal transport workaround retired
Changed by:
⌖ Vera Production across eCompanion Runtime + eCompanion Mobile

Status:
DEPLOYED

Change type:
CROSS-SERVICE PRODUCTION FIX + UI BEHAVIOR + TEST

What changed:
Runtime's Body route now carries the existing canonical multimodal attachment contract, and Mobile no longer imposes the temporary 650 KB wire workaround.

Affected projects:
- eCompanion Runtime / ◉ Maeve
- eCompanion Mobile / ◐ Iris

Canonical behavior:
- Runtime semantic attachment authority remains 8 attachments, 20 MiB/item, 25 MiB combined.
- Body chat has enough route-specific JSON capacity for canonical Base64 payloads.
- Mobile enforces the semantic limits instead of an obsolete lower transport workaround.

Compatibility:
BACKWARD COMPATIBLE for existing smaller uploads; larger uploads are newly unblocked at source/deployment level.

Do not:
- Do not globally raise unrelated Runtime JSON routes.
- Do not increase semantic attachment limits as part of this repair.
- Do not claim larger owner uploads E2E until a real authenticated upload is observed.

Evidence:
- Runtime current product-code commit `434484a49a42d8092e62c09529546c0e805323f9` / deploy `dep-dag5ue67bikc73d84irg` LIVE.
- Mobile changes `6cea85372cf708c2ff261f2858d08bf8a98d6a56`, `e6d98b49be7faaab158425eebcd0273a8c12e12f`, `76c0c5d3681201683e7bc8045e78a8416e011041`.
- CI gate repair/current release `246ba6f6866e665bb03cbb41965d903f3ee2ded2`.
- `verify-mobile` run `34268693649` SUCCESS.
- Render deploy `dep-dag61erncjis738p4hf0` LIVE.

## CROSS-PROJECT BLOCKERS

### CROSS-PROJECT BLOCKER: live task progress and owner interruption
Owning dependency: eCompanion Runtime / ◉ Maeve
Required: device/owner-safe task state + realtime event/control contract suitable for Mobile, not companion-service or executor authority.
Current status: Runtime Task v1 is deployed for Private companion consumption; Mobile-safe owner consumption remains not proven.

### CROSS-PROJECT BLOCKER: durable task artifacts
Owning dependency: eCompanion Runtime / ◉ Maeve plus producing authority.
Required: owner/device-safe artifact/media reference contract.
Current status: not yet proven on Body client contract.

### CROSS-PROJECT BLOCKER: realtime duplex voice
Owning dependency: eCompanion Runtime / ◉ Maeve + eCompanion Integrations / ↔ Cleo where provider transport is involved.
Required: canonical realtime streaming/session lifecycle with interruption/reconnect/failure semantics.
Current status: browser speech/TTS remains deployed; provider-grade client path not proven.

## PROVENANCE
Canonical source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`.
Canonical current product release: `246ba6f6866e665bb03cbb41965d903f3ee2ded2`.
Canonical web production: Render `srv-daat0mu7bikc73c9fiv0`, deploy `dep-dag61erncjis738p4hf0` LIVE.

Physical iPhone proof is separate from source/CI/Render proof.

## EVIDENCE
- Runtime Body transport dependency repaired and current Runtime release LIVE.
- `6cea85372cf708c2ff261f2858d08bf8a98d6a56` — remove obsolete 650 KB Mobile wire cap.
- `e6d98b49be7faaab158425eebcd0273a8c12e12f` — canonical semantic attachment regression coverage.
- `76c0c5d3681201683e7bc8045e78a8416e011041` — PWA cache v5.
- First current release run exposed only stale v4 static-gate expectation after product behavior tests passed.
- `246ba6f6866e665bb03cbb41965d903f3ee2ded2` — static-gate repair and exact current release.
- GitHub Actions `34268693649` — web SUCCESS + native-core SUCCESS.
- Render `dep-dag61erncjis738p4hf0` — LIVE.
- No secrets recorded.
