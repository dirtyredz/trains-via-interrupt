# Trains via Interrupt

Open a train stop and you get two tabs: **Trains on the way** and **Trains with this stop**.
Neither one knows about interrupts. A station named inside an interrupt isn't in any train's
schedule until the temporary stop is actually created, so from the station's own GUI the trains
that serve it through an interrupt simply don't exist. That's
[deliberate upstream](https://forums.factorio.com/viewtopic.php?p=628111&t=118449) — the
objection was that a station would have to evaluate every wildcard in every train group to
know whether it might be a target.

This mod adds a panel beside the stop GUI answering two questions vanilla can't.

## Trains with this stop

Every schedule whose interrupts name this station **at all** — as somewhere to send the train,
as something to wait on, or as the trigger. This is the "how is this stop wired up" question,
so the three relationships aren't separated.

One row per train **group**, since a group shares a single schedule, with the number of trains
in it. Hover for which interrupts matched; click to open a train.

## Trains waiting for this stop

Trains that want the stop **right now** — one row per train, because each sits at its own point
in its schedule even when six of them share one. A train counts if the record it is currently
executing either sends it here, or holds it somewhere else until this stop has room.

Trains already parked at the stop are **excluded**: they've arrived, they aren't queuing.

The difference matters. The first number is configuration and barely changes; the second is
live demand. A stop with 6 wired up and 0 waiting is idle; 6 and 6 is a bottleneck.

## Parametrised stations

Wildcards are handled, and they have to be — in a parametrised network a drop-off named
`[item=iron-plate][virtual-signal=down-arrow]` is often *never* referenced literally, only as
`[virtual-signal=signal-item-parameter][virtual-signal=down-arrow]`. Ignore wildcards and every
drop-off reports zero.

Matching them blindly is just as wrong: every group carries the same generic interrupt, so one
drop-off would claim every train in the network. Instead the wildcard captures what it would
have to bind to, and the match counts only where that schedule shows evidence of hauling that
item — from its group name and from every station it names concretely. Such rows are marked
*(generic)* in the tooltip.

**Limitation:** a group that names nothing concretely and has no icon in its group name gives
no evidence, so its generic interrupts match nothing and it won't be listed. Under-reporting
was chosen over listing everything.

Note this isn't the expensive thing the base game declined to do. Resolving a wildcard forwards
means enumerating every item it might become; asked from the station side, you only ever test
one known station name against one pattern.

## Compatibility

Factorio **2.1**, no dependencies, read-only on schedules — it can't corrupt interrupts. All
work happens when you open a stop, so there's no per-tick cost.

It cannot add a real third *tab*: mods can't extend a vanilla tabbed pane, so the panel docks
to the side of the window instead.
