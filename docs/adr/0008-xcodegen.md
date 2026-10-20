# 8. Generate the Xcode project with XcodeGen

- Status: accepted
- Date: 2026-10-20

## Context

`project.pbxproj` is hard to review and merge, and the project is mostly built from the command line by
coding agents.

## Decision

The project is described in `project.yml` and generated with XcodeGen (`scripts/bootstrap.sh`). The
`.xcodeproj` is not committed. App sources are synchronized folders, so new files need no regeneration;
most code lives in the Swift package, which picks up files on its own.

## Consequences

- Run `xcodegen generate` after a fresh clone or a change to `project.yml`.
- Project settings are reviewed as readable YAML.
