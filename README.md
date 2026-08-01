# factorio-mods

In-game Factorio mods (Lua). Separate from [`factorio-bp`](../factorio-bp), which is a
browser/Node tool for editing blueprint *strings* outside the game — different language,
different runtime, no shared code.

| Mod | What it does |
|---|---|
| [`trains-via-interrupt/`](trains-via-interrupt/README.md) | From a train stop's GUI: which trains are wired up to it through a schedule interrupt, and which want it right now. Vanilla shows neither. |

Target: **Factorio 2.1** (installed build is 2.1.12 + Space Age, Steam).

Gotchas that cost real debugging — stale version fields, wildcard semantics, which API calls
crash — are in [CLAUDE.md](CLAUDE.md). Read it before changing matching behaviour.

## Running a mod in game

Factorio loads unzipped mods whose folder name matches the mod's `name` in `info.json`. A
directory junction keeps the source here and the game loading it live:

```bash
cmd /c mklink /J "%APPDATA%\Factorio\mods\trains-via-interrupt" "C:\Users\dirty\factorio-mods\trains-via-interrupt"
```

Junctions need no admin rights. After editing Lua, **restart Factorio**.

> Don't reach for `/c game.reload_mods()`. Any console command permanently disables
> achievements on that save, and it has to be confirmed twice. A restart is cheaper than it
> looks.

## Testing without launching the game

`--create` loads every mod, runs `control.lua`, and exits — about 30 seconds. Point it at a
throwaway config, or it collides with the running game's data-dir lock:

```bash
factorio.exe --create smoke.zip --mod-directory ./testmods --config ./config.ini
```

`config.ini` needs `write-data` set to a scratch folder. `Checksum for script
__<mod>__/control.lua` in the output means the mod loaded.

**That proves the file parses and nothing more.** Two runtime bugs shipped straight past it. So
each mod carries a `dev-selftest.lua`: enable `SELF_TEST` in `control.lua` and the same
`--create` run also exercises the mod's logic and builds a rail and a locomotive so the API is
called against a real train. Results land in `script-output/tvi-selftest.txt` under the
config's write-data path.

**Add a case whenever a new API call is introduced.** It is the only automated coverage of
runtime behaviour, and anything needing a GUI is still uncovered — `--create` never opens one,
so panel layout and event wiring need a human in game.

## Diagnostics from a real save

To see what the owner's game actually contains, write a file from the mod (`helpers.write_file`
lands in `script-output/`) and read it directly. Never ask them to paste a console command:
same data, and it costs them the save's achievements.
