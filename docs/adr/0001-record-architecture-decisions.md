# 1. Record architecture decisions

- Status: accepted
- Date: 2026-10-20

## Context

The app is meant to grow (colour management, print profiles, maybe iOS) and its author is new to Swift.
Decisions need to stay understandable months later, with their reasons.

## Decision

Every structuring decision is recorded as a short ADR in `docs/adr/`, MADR style, numbered in order.
An ADR is never rewritten once accepted: a new ADR supersedes it.

Only decisions that shape the code or the product get an ADR — not every small choice.

## Consequences

- New contributors (human or agent) read `docs/adr/` before changing structure.
- Reversing a decision means writing a new ADR that says why.
