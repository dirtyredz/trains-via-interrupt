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

Target: **Factorio 2.0** (owner is on 2.0.77, Steam).
