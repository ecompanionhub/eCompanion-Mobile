# eCompanion Multi-Chat Coordination

This repository participates in the canonical eCompanion multi-chat development control plane.

Canonical coordination anchor: `ecompanionhub/eCompanion-Runtime#33`.

## Mandatory before any write
1. Read the canonical control-plane issue.
2. Read relevant open pull requests in every affected repository.
3. Check the latest target/base branch state and recent changes that can affect the requested production authority, contracts, callers, callees, persistence, configuration, deployment, or error semantics.
4. Identify the canonical authority, execution path, forbidden alternate paths, production callers/callees, persistence authority, and error semantics.
5. Confirm that the intended scope does not overlap an active lane.

Chat memory is context, not repository authority.

## Isolation
- Never implement directly on `main`.
- One workstream uses one isolated branch and pull request lane.
- Record a lane manifest in the PR body or a top-level PR comment containing: `WORKSTREAM`, `AUTHORITY`, `BASE_SHA`, `OWNED_PATHS`, `FORBIDDEN_PATHS`, `DEPENDENCIES`, `CONTRACTS_CHANGED`, and `STATUS`.
- Do not silently edit production paths, authorities, or contracts owned by another active lane.
- If ownership or overlap is unclear, fail closed. Do not create a fallback, compatibility path, second authority, temporary implementation, or legacy bridge to avoid the conflict.

## Before merge or handoff
- Re-check latest base/main movement.
- Re-audit affected production paths when base movement touches the lane's assumptions.
- Treat CI as evidence, not proof of architectural correctness.
- Update the PR lane manifest/status and record actual changed contracts/paths and remaining blockers.
- Leave GitHub sufficient for another chat to resume without relying on the previous chat transcript.

Parallel work is expected and allowed only when scope and authority are proven non-overlapping or explicitly handed off.