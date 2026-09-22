# BACKLOG — trains-via-interrupt

Flat at the repo root, matching this project's flat doc convention (see STRUCTURE.md).

## From the 2026-09-22 baseline structural review

Baseline: 3 Claude lenses (componentization, abstraction, topology) + Codex cross-model sign-off.
Verdict: PASS, no P0. Topology SOUND. Full details: `STRUCTURE.md` → `## Structural debt`.

### Open

- **[P2] `matching.lua:8`** (surviving finding, from the Codex sign-off) — the module owns the
  Factorio WaitCondition schema and condition-record traversal (`STATION_CONDITION`,
  `conditions_match()`) despite being declared as the pure string-matching boundary, so
  schedule-shape knowledge is split between `matching.lua` and `control.lua`. Direction: move
  `STATION_CONDITION` and `conditions_match()` to the scan side of `control.lua`, or into a
  scanner module if the documented scan-vs-GUI split is later performed.

### Considered and rejected (do not re-raise at the next baseline)

- **Extracting `dump()` (`control.lua:156-190`) into a sibling `dev-dump.lua`** — REJECTED by the
  Codex sign-off: it would create a single-caller module for a 33-line, disabled diagnostic
  already slated for deletion. That is fragmentation and churn, not componentization.
- **Sharing one schedule-traversal iterator between `scan()` / `dump()` /
  `schedule_candidates()` / `schedule_references()`** — REJECTED: the duplication is intentional
  diagnostic independence. `dump()` exposes raw schedule structure while the production traversal
  filters and interprets it; sharing an iterator would let both paths inherit the same omissions,
  and the group keys have different output requirements.
