# trains-via-interrupt — notes for whoever works on this next

An in-game Factorio mod (Lua), published at
[mods.factorio.com](https://mods.factorio.com/mod/trains-via-interrupt) as `Dirtyredz`.
This folder is both the git repo and the mod folder — `info.json` sits at the root, so the
game loads it directly through the junction. `build.ps1` zips it for the portal.

General environment, testing and publishing practice lives in the parent folder's
[`../CLAUDE.md`](../CLAUDE.md). Read that first; this file only covers what is specific to
this mod.

Keep the split below between **verified** (checked against the game's own output or a
screenshot from the owner) and **inferred**. Almost every wasted round here came from confident
reasoning about semantics that real data then contradicted.

## What it does

Adds a side panel to the train stop GUI showing which trains are wired up to that stop via
**interrupts**, and which want it right now. Vanilla's "Trains with this stop" tab only knows
about stations written literally into a schedule, so interrupt-driven networks get told
nothing.

## Self-test

`dev-selftest.lua` runs during `on_init` when `SELF_TEST` is enabled in `control.lua`. It
builds a rail and a locomotive so the API is exercised against a real train, and writes
results to `script-output/tvi-selftest.txt`. **Add a case whenever a new API call is
introduced.**

The panel itself is still uncovered — `--create` never opens a GUI, so layout and event
wiring need a human in game.

## Runtime API facts (verified)

- `LuaTrain.get_schedule()`, **not** `.schedule` — the latter is documented as a simplified
  schedule *without* groups or interrupts.
- `LuaSchedule.current` is a bare `uint32`, but `get_record` takes a `ScheduleRecordPosition`
  **table**: `get_record{ schedule_index = schedule.current }`. Passing the number crashes.
- `WaitCondition.station` is populated only for `specific_destination_full`,
  `specific_destination_not_full`, `at_station`, `not_at_station`.
- A station name can therefore hide in three places: an interrupt target's `station`, a target's
  `wait_conditions[].station`, and the interrupt's own `conditions[].station`.
- Relative GUI anchoring to `defines.relative_gui_type.train_stop_gui` **works** (confirmed by
  screenshot). There is an open report that `train_gui` anchoring broke in 2.0 — that one is
  fullscreen; the stop GUI is an ordinary entity GUI and is unaffected.

## Interrupt wildcards — read before touching matching

The four parameter wildcards, from `base/prototypes/signal.lua`: `signal-item-parameter`,
`signal-fuel-parameter`, `signal-fluid-parameter`, `signal-signal-parameter`. **`signal-fuel` is
not one of them** — a station named after it matches literally.

The owner's network is **almost entirely parametrised**. Their drop-offs are named
`[item=x][virtual-signal=down-arrow]` and are *never* referenced literally — only as
`[signal-item-parameter][down-arrow]`. Any design that ignores wildcards reports zero for every
drop-off. This was assumed away twice before their dump proved it.

But every group carries the *same* generic interrupt, so matching a wildcard as "anything"
made one drop-off claim all 85 trains in the network. A wildcard binds to **cargo**, so:

1. Capture what the wildcard would have to become, from the viewed station's name.
2. Only count it if that schedule shows evidence of dealing in that icon — its group name plus
   every station it names concretely.

Known gap: a group naming nothing concretely, with no icon in its group name, has no evidence
and will be **missing** from the list. Under-reporting was chosen over listing everything.

Note this is *not* the enumeration the base game
[declined to do](https://forums.factorio.com/viewtopic.php?p=628111&t=118449). They objected to
resolving a wildcard forwards — every item it might become. Asked from the station side you only
ever test one known name against one pattern.
