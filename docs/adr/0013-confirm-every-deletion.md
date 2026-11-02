# 13. Confirm every deletion

- Status: accepted
- Date: 2026-11-02

## Context

A two-finger swipe on a sidebar row, like in Mail, makes deletion one gesture away. The same gesture is easy
to trigger by accident on a trackpad, and ⌘Z, which brings deleted items back, is hard to discover for
people who never use the Edit menu.

## Decision

Every deletion asks for confirmation, even when ⌘Z can undo it.

- One dialog serves every path: the swipe action, the context menu and the Delete key.
- The dialog names the item, or gives the count when several are selected.
- *Annuler* is the default action: Return never deletes.

## Consequences

- One extra click per deletion.
- ⌘Z still brings the deleted items back.
- Any future deletion path reuses this dialog instead of deleting directly.
