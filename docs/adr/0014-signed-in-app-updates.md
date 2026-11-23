# 14. Signed in-app updates on GitHub Releases

- Status: accepted
- Date: 2026-11-21

## Context

[ADR 0009](0009-ad-hoc-distribution.md) ships ad-hoc signed builds and asks each user to repeat "Open
Anyway" for every new version. The repository is now public, and users should get new versions from
inside the app. An ad-hoc signature proves no origin, so an updater that trusts what GitHub serves
would install whatever is published under the repository's name.

## Decision

- **Distribution is unchanged.** `scripts/release.sh <version>` archives a universal (arm64 + x86_64)
  Release build, signed ad hoc, zips it with `ditto` and publishes `CardSheetCreator.zip` as a GitHub
  Release. The README links to `releases/latest/download/CardSheetCreator.zip`.
- **The zip is signed with Ed25519.** The private key lives in the publisher's login Keychain, the public
  key is embedded in the app. `release.sh` publishes `CardSheetCreator.zip.sig` next to the zip and
  aborts when the Keychain key does not match the embedded public key.
- **A hand-rolled updater, no Sparkle.** The app reads the GitHub `releases/latest` API (public repository,
  no token), from the menu and at launch. It verifies the signature on the downloaded archive before
  unzipping it, then the bundle id and version. A detached helper swaps the bundle after a normal quit
  and relaunches the new version.
- Sparkle would add a dependency for a flow of a few hundred lines, and it uses EdDSA signatures too.

## Consequences

- Gatekeeper's "Open Anyway" is needed only for the first install: an update downloaded by the app
  carries no quarantine flag (see [0015](0015-no-app-sandbox.md)).
- Losing the private key means shipping a new public key in a release that users install manually once.
- Moving to Developer ID later only changes the signing step of the script.
- Users on 0.6.0 or earlier have no updater: they install the first version with updates manually once.
- This ADR supersedes 0009; its decision stays in force.
