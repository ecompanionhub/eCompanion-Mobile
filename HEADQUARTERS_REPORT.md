# HEADQUARTERS REPORT

## CURRENT
Updated: 2026-09-08T16:07:00Z
Engineer: Iris
Project: eCompanion Interfaces — Mobile / Body
Mode: WORK

Current source: `ecompanionhub/eCompanion-Mobile` → `main`.
Current functional web product release source: `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`.
Current production / physical release: Render static site `ecompanion-mobile` (`srv-daat0mu7bikc73c9fiv0`), functional web deploy `dep-dag2kn95efls73fgblag`, release commit `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`, status LIVE.

`HEADQUARTERS_REPORT.md` is outside the `web/` publish tree. Reporting-only commits may cause Render auto-deploys, but they do not change the functional web product bytes unless `web/` changes.

## PRODUCT RESULT
The owner-facing Mobile / Body web client no longer presents Runtime configuration, capability flags, sync controls or raw state as the primary experience. The normal path is now a companion-first daily client: open the product, pair only when the device is not connected, continue the Runtime-assigned companion conversation, and use the existing scoped Body/voice paths without managing backend architecture.

## COMPLETED
- Reworked the Mobile web home into a daily companion conversation experience instead of a developer/debug surface.
- Removed owner-facing Runtime base-URL setup from the normal production flow; production Runtime routing is product configuration.
- Kept pairing conditional: device connection appears when needed rather than remaining permanent setup chrome.
- Preserved scoped device credentials and Runtime-assigned companion authority instead of creating local identity/state authority.
- Preserved persisted Body chat/presence integration and the existing voice path.
- Updated the Mobile static product gate so tests enforce the companion-first UX instead of requiring obsolete developer copy.
- Preserved mobile viewport/safe-area behavior for the daily web client.

## PROVEN
- IMPLEMENTED — companion-first Mobile web source exists in canonical GitHub `main`.
- TESTED — JavaScript syntax and the Mobile product/boundary static gate passed on functional release source `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`.
- DEPLOYED — Render deploy `dep-dag2kn95efls73fgblag` reached LIVE on exact functional release commit `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`.
- PHYSICAL / EXTERNAL TARGET VERIFIED — not claimed for a physical iPhone/native app in this Interfaces wave. A LIVE Render static deployment is deployment proof, not physical-device proof.
- END-TO-END PROVEN — not claimed for physical iPhone voice, notifications or native background continuity in this Interfaces wave.

## PRODUCTION / PHYSICAL STATE
Web production target:
- service: `ecompanion-mobile`
- service ID: `srv-daat0mu7bikc73c9fiv0`
- source repo: `https://github.com/ecompanionhub/eCompanion-Mobile`
- branch: `main`
- publish path: `web`
- auto deploy: yes
- functional deploy: `dep-dag2kn95efls73fgblag`
- functional release commit: `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`

Native iOS foundations exist in the same repository from earlier work, but this Interfaces report does not claim a new physical-device install/canary for those native capabilities.

## BLOCKERS
No concrete blocker remains for the current Mobile web deployment.

Owner-friendly issuance/approval of a new device pairing grant remains dependent on the canonical Runtime pairing authority. Mobile can consume the pairing path; it must not mint or simulate authorization itself.

Rich realtime action progress, owner authorization controls and notification semantics must only be surfaced when the owning backend contracts provide truthful state. No UI-only success/permission model is authorized.

## NEXT EXECUTABLE WORK
Continue the next complete Mobile vertical slice over existing real contracts: improve conversation continuity and real action-result presentation where current Body/Runtime endpoints already expose it. Pairing UX should become simpler as soon as Runtime provides the owner-facing issuance contract; do not build a parallel pairing authority in Mobile.

## CROSS-PROJECT DEPENDENCIES
- Runtime / Maeve — needed result: owner-facing pairing issuance/approval and truthful action/event state suitable for Mobile presentation. Iris can continue improving existing conversation/body flows while those contracts evolve.
- Devices / Sanne — needed result for richer device UI: canonical NODE presence/capability/update/action state. Iris can present it once available; Mobile must not invent device capabilities.
- Integrations / Cleo — needed result for external-action UI: human-resolvable destinations plus verified delivery result through canonical transport contracts. Iris can continue conversation UX independently.

## PROVENANCE
Mobile development source: GitHub `ecompanionhub/eCompanion-Mobile` → `main`.
Mobile web production: Render static site `ecompanion-mobile` → same GitHub repo/branch, `web/` publish path, auto-deploy on commit.
Native iOS source lives in the same repository but physical installation/external device verification is separate from Render web deployment proof.

Mobile is a client/presentation surface. Runtime/device/provider authority remains external and canonical.

## EVIDENCE
- functional web release source: `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`
- product UX commits: `feb116815760eae5d1e3ecab99fddd23f847b322`, `4798647db484f1c3447da1d33199457c026c940b`, `2e75d24b324f539ebe2ef68b0efc6b2b0beff50f`
- Render service: `srv-daat0mu7bikc73c9fiv0`
- Render functional deploy: `dep-dag2kn95efls73fgblag`
- Render functional deploy status: LIVE
- Mobile JavaScript syntax: PASS
- Mobile product/boundary gate: PASS
