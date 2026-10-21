# Agent instructions

## Changelog

`CHANGELOG.md` is the release history and the roadmap. Keep it current in the same commit as the change:

- **Feature or bug fix** — add a user-facing line under `[Unreleased]` (`Added`, `Changed`, `Fixed`,
  `Removed`). Describe what the user sees, not the code. Skip changes users never notice (refactors,
  tests, tooling).
- **Release** — before running `scripts/release.sh`, rename `[Unreleased]` to `[x.y.z] — YYYY-MM-DD`,
  open a new empty `[Unreleased]`, and update the compare links at the bottom.
- **Roadmap** — move an item out of `Roadmap` once it ships; add new planned work there.
