# STRUCTURE — trains-via-interrupt

## Overview

A Factorio 2.1 mod that adds a side panel to the train stop GUI, answering the two questions
vanilla's "Trains with this stop" tab cannot: which trains are **wired up** to this stop via
interrupts, and which of them **want it right now**. Vanilla only sees stations written literally
into a schedule, so an interrupt-driven network reports nothing.

Runtime only — no data or settings stage. The panel is built on `on_gui_opened` and anchored to
`defines.relative_gui_type.train_stop_gui`; everything happens when a stop is opened, so there is
no per-tick cost and nothing is written to storage. The mod is strictly read-only with respect to
schedules.

The hard part is **wildcard matching**: parametrised drop-offs are never named literally, only as
`[signal-item-parameter][down-arrow]`, and every train group carries the same generic interrupt.
Matching resolves the wildcard against the station being viewed and then requires evidence that
the schedule deals in that icon. `CLAUDE.md` has the rules — read it before touching matching.

## Layout

```
trains-via-interrupt/
├── info.json           # mod manifest — Factorio requires it at the mod root
├── control.lua         # runtime entry point: stop scan, panel build, event wiring
├── matching.lua        # module: station-name / interrupt-reference matching, incl. wildcards
├── dev-selftest.lua    # module: matcher cases + API probes, required only when SELF_TEST is on
├── build.ps1           # packages dist/<name>_<version>.zip for the mod portal
└── locale/en/*.cfg     # translation strings
```

**Enforced homes:**

- `control.lua` — runtime entry point; Factorio loads it from the mod root
- `matching.lua` — module `require`d by control and the self-test: pure string matching of station
  names against interrupt references, wildcards included
- `dev-selftest.lua` — module `require`d by control at load time when `SELF_TEST` is on
- `build.ps1` — portal packaging script; run from the repo root
- `locale/` — translation `.cfg` files

**Why the root is flat, and why it stays that way.** A Factorio mod folder *is* the mod: the game
loads `info.json` and `control.lua` from the mod root and nowhere else. That is a platform
requirement, not a style choice. The other `.lua` files are the mod's own modules, reached by
`require("matching")` with paths resolved relative to the mod root, so moving them into a
subdirectory means rewriting every `require`. Flat-at-the-root is also the universal convention
for published mods — this one ships from this folder, and anyone unzipping the package expects
that shape.

The deciding point is verification. There is no standalone Lua on this machine: `dev-selftest.lua`
runs only inside a real Factorio `--create`, and the panel itself is not covered even then, since
`--create` never opens a GUI. A `require`-path refactor could only be confirmed by launching the
game and opening a train stop by hand — unverifiable risk, on three files, for no structural gain.
**Do not "fix" the flat root.**

## Structural debt

- **`control.lua` (~369 lines) carries three concerns**: the scan (walking every train's schedule
  and classifying it as configured / waiting), the GUI build (frame, headers, rows, tooltips), and
  a `DEBUG_DUMP` diagnostic writer. `matching.lua` already took the pure logic out; the remaining
  seam is scan-vs-GUI, which would give the scan the same testability matching has. Under the
  ~800-line cap and not urgent — deferred because the GUI half is exactly what `dev-selftest.lua`
  cannot verify, so a split would need a human in game to confirm.
- Known behavioural gap (not structural, recorded in `CLAUDE.md` and `README.md`): a train group
  that names no station literally and has no item icon in its group name gives the matcher no
  evidence, so it is under-reported rather than over-reported.
