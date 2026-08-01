# Trains via Interrupt

**Your station says no trains are coming. Six of them are parked at a holding station, waiting
for it right now.**

Vanilla's "Trains with this stop" tab only knows about stations written into a train's
schedule. Interrupts don't count — an interrupt's target isn't in the schedule until the
temporary stop actually gets created. So the moment your network runs on interrupts, every
station window quietly stops telling you the truth.

This mod adds a panel beside the train stop window with the two numbers you actually wanted.

### Trains with this stop

Every train whose interrupts mention this station, however they mention it — sent here, waiting
on it, or triggered by it. This is your *what is wired up to this stop* number, and it barely
changes.

Train groups show as one row with a count, so a 6-train group is one line, not six.

### Trains waiting for this stop

Trains that want this stop **right now** — either an interrupt is sending them here, or they're
stuck somewhere else until this stop has room. Trains already parked at the station don't
count. They've arrived.

Six wired up and zero waiting? The stop is idle. Six and six? You've found your bottleneck.

## It handles parametrised networks

If you build with wildcard interrupts, your drop-offs are probably never named literally
anywhere — only as `[virtual-signal=signal-item-parameter][virtual-signal=down-arrow]`. Match
station names naively and every drop-off in your base reports zero trains.

Match wildcards *loosely* and it's worse: every train group carries the same generic interrupt,
so one drop-off claims your entire fleet.

This resolves the wildcard against the station you're actually looking at, then checks that the
group has any business hauling that item. Your brick drop-off lists brick trains. Not all 85
trains in the network.

## Details

- Click any row to open that train.
- **Read-only.** It never writes to a schedule, so it can't eat your interrupts.
- Everything happens when you open a stop. No per-tick cost, no save bloat.
- Factorio 2.1. No dependencies.
- It's a side panel rather than a third tab, because mods can't add tabs to vanilla windows.

One known gap: a train group that names no station literally *and* has no item icon in its
group name gives the mod nothing to go on, so its generic interrupts won't be matched. Naming
groups after what they haul is enough to avoid this.

Bug reports and ideas: <https://github.com/dirtyredz/trains-via-interrupt>
