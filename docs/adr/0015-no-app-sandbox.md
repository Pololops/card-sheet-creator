# 15. No App Sandbox, hardened runtime kept

- Status: accepted
- Date: 2026-11-21

## Context

The in-app updater ([0014](0014-signed-in-app-updates.md)) replaces the app's own bundle. A sandboxed,
ad-hoc signed app cannot do that, and what it downloads is quarantined, so every update would hit
Gatekeeper again.

## Decision

The App Sandbox entitlement is removed, and with it the entitlements file. The hardened runtime stays
on.

## Consequences

- A compromised app could reach more files than the sandbox allowed.
- Downloads made by the app carry no quarantine flag: no Gatekeeper prompt after an update.
- The library moves out of the sandbox container ([0016](0016-library-adoption-from-sandbox.md)).
