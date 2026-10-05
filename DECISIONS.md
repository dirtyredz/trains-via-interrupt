# DECISIONS — trains-via-interrupt

Why things are the way they are. Flat at the repo root, matching this project's flat doc convention (see STRUCTURE.md).

## Rejected ideas (do not re-raise)

Considered and rejected (do not re-raise at the next baseline). From the 2026-09-22 baseline structural review.

- **Extracting `dump()` (`control.lua:156-190`) into a sibling `dev-dump.lua`** — REJECTED by the
  Codex sign-off: it would create a single-caller module for a 33-line, disabled diagnostic
  already slated for deletion. That is fragmentation and churn, not componentization.
- **Sharing one schedule-traversal iterator between `scan()` / `dump()` /
  `schedule_candidates()` / `schedule_references()`** — REJECTED: the duplication is intentional
  diagnostic independence. `dump()` exposes raw schedule structure while the production traversal
  filters and interprets it; sharing an iterator would let both paths inherit the same omissions,
  and the group keys have different output requirements.
