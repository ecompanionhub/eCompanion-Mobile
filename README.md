# eCompanion Mobile

Platform-independent body client for eCompanion.

## Core rule

The companion identity, memory and authority do not live in an iOS app or depend on a paid platform membership. Mobile clients are capability surfaces for the neutral eCompanion Runtime.

## Targets

- Web/PWA baseline
- Native iOS sidecar when additional device capabilities are available
- Dynamic capability negotiation
- Self-hostable transport
- No secrets committed to this repository

## Runtime

The client integrates with the neutral `eCompanion-Runtime` API. Device, presence, calling and conversation state remain Runtime-owned.
