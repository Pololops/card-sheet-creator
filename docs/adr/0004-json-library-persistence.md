# 4. Library persistence in JSON files

- Status: accepted
- Date: 2026-10-20

## Context

Templates and sheets live in a library managed by the app (not documents in the Finder), saved after
every change. Images picked by the user must survive the original file being moved or deleted.

Options considered: SwiftData; a document-based app; plain Codable JSON files.

## Decision

`FileLibraryStore` (an actor) writes to `Application Support/CardSheetCreator/Library/`:

- `manifest.json` — schema version.
- `templates/<uuid>.json`, `sheets/<uuid>.json` — `{ schemaVersion, payload }`.
- `images/<sha256>.<ext>` — imported images, copied and deduplicated by content.
- `settings.json` — last print settings.

Writes are atomic, coalesced with a 400 ms debounce and flushed when the app quits. A `Migrator`
upgrades older files step by step and refuses files written by a newer version. Images no sheet uses
are purged at launch, so an undone deletion still finds its images during the session.

## Consequences

- No hidden framework behaviour: the files are readable, testable on a temporary folder, easy to migrate.
- Queries are in-memory; fine for hundreds of sheets, to revisit if the library grows much larger.
- Copying images costs disk space but removes broken links and sandbox bookmarks.
