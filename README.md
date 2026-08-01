# factorio-mods

In-game Factorio mods (Lua). Separate from [`factorio-bp`](../factorio-bp), which is a
browser/Node tool for editing blueprint *strings* outside the game — different language,
different runtime, no shared code.

| Mod | What it does |
|---|---|
| `trains-via-interrupt/` | Shows, from a train stop's GUI, which trains reach or wait on it via a schedule interrupt. |

## Testing a mod in game

Factorio loads unzipped mods whose folder name matches the mod's `name` in `info.json`.
A directory junction keeps the source here and the game loading it live:

```bash
cmd /c mklink /J "%APPDATA%\Factorio\mods\trains-via-interrupt" "C:\Users\dirty\factorio-mods\trains-via-interrupt"
```

Junctions need no admin rights. After editing Lua, restart Factorio (or `/c game.reload_mods()`
from the console in a save with cheats).

Target: **Factorio 2.1** (installed build is 2.1.12 + Space Age, Steam).

Note `player-data.json`'s `last-played-version` reported 2.0.77 and is stale — trust the
version banner in the game's own log output, not that field.

## Smoke-testing without launching the game

`--create` loads every mod and runs `control.lua`, then exits, so it catches syntax errors and
bad `defines` in about 30 seconds. Use a throwaway config, otherwise it collides with the
running game's data-dir lock:

```bash
factorio.exe --create smoke.zip --mod-directory ./testmods --config ./config.ini
```

where `config.ini` sets `write-data` to a scratch folder. A line reading
`Checksum for script __<mod>__/control.lua` means the mod loaded clean. This does **not**
exercise any GUI — that still needs a human in game.

