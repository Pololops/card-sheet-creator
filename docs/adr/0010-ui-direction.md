# 10. UI direction: Apple HIG with Liquid Glass

- Status: accepted
- Date: 2026-10-20

## Context

The interface should feel like an Apple app, inspired by Pixelmator Pro's layers panel. The user
validated a set of mockups and asked the UI to match them exactly:
<https://claude.ai/artifact/MzCLyGjBXoKVYdbNooYM7g> (template editing, framing with clones, first launch,
sidebar, new sheet, resize draft, template offer, print).

## Decision

- One window: floating glass sidebar · neutral canvas · inspector (`NavigationSplitView` + `.inspector`).
- Liquid Glass only on the navigation layer: toolbar, sidebar, inspector, floating controls, dialogs.
  Never on content, never glass on glass.
- A single font family, SF Pro, through the system text styles. Hierarchy comes from weight and
  primary / secondary colour, like Apple's apps.
- Fixed accent `#0062CC`; values from the mockups live in `Shared/DesignTokens.swift`.
- Slot outlines, the hatched safety margin and centre guides are screen-only.

## Consequences

- Each UI change is compared side by side with its mockup; native control rendering is the only
  accepted difference.
- The app does not follow the system accent colour.
