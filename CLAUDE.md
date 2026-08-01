# factorio-mods — notes for whoever works on this next

In-game Factorio mods (Lua). **`factorio-bp` is a separate project** — a browser/Node tool for
blueprint strings. Don't reach across; they share nothing but a game.

Keep the split below between **verified** (checked against the game's own output or a
screenshot from the owner) and **inferred**. Almost every wasted round here came from confident
reasoning about semantics that real data then contradicted.

## Environment

- **Factorio 2.1.12 + Space Age**, Steam, at
  `C:\Program Files (x86)\Steam\steamapps\common\Factorio`. Verified from the game's log banner.
- **`player-data.json`'s `last-played-version` lies** — it read 2.0.77 while the installed build
  was 2.1.12, and `info.json` targeting `"2.0"` was rejected outright. Trust the log, not that
  field.
- Each mod folder is junctioned into `%APPDATA%\Factorio\mods\`, so the game loads this source
  live. `mklink /J` needs no admin.

## Testing

```bash
factorio.exe --create smoke.zip --mod-directory ./testmods --config ./config.ini
```

`config.ini` must set `write-data` to a scratch folder, or this collides with the running
game's data-dir lock. `Checksum for script __<mod>__/control.lua` in the output means it loaded.

**Loading clean proves only that the file parses.** Two bugs reached the owner's game past it:
a GUI counting the wrong thing, and `get_record` called with a bare number. So each mod carries
a `dev-selftest.lua` (enable `SELF_TEST`) that runs during `on_init` and builds a rail and a
locomotive so the API is exercised against a real train. **Add a case whenever a new API call is
introduced.** Anything needing a GUI is still uncovered — `--create` never opens one.

## Working with the owner

**Never ask them to run a `/c` console command.** It permanently disables achievements on the
save, and they have to run it twice to confirm. Write diagnostics from the mod to
`script-output/` instead and read the file directly — same data, no cost to them.

Their screenshots are ground truth. A dump of their real schedules settled in one round what
three rounds of reasoning had got backwards.

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
- A mod cannot add a tab to a vanilla tabbed pane. A side panel is the only option.

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
