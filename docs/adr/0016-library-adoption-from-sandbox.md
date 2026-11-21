# 16. Library adoption from the sandbox container

- Status: accepted
- Date: 2026-11-21

## Context

Leaving the App Sandbox ([0015](0015-no-app-sandbox.md)) moves the library from the container to
`~/Library/Application Support/CardSheetCreator/Library`. Users keep their templates and sheets only if
the first launch brings them over, and a failed copy must not lose anything.

## Decision

A one-time copy out of the container, run at each launch until it succeeds.

- A marker file, `.adopted`, records success; without it the copy is retried at the next launch.
- The container is only read, never modified, so 0.6.0 keeps working with its own copy.
- An interim library created after a failed attempt is renamed `Library-<date>` and never deleted.
- Only a provably absent manifest counts as "no library"; an unreadable one is a failure.
- On failure the app still starts and shows an alert.

## Consequences

- After the copy, 0.6.0 and the new version each have their own library; changes do not travel between them.
- The container's copy stays on disk, and the user can delete it.
- A failed attempt can leave a `Library-<date>` folder beside the adopted library.
