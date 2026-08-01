-- Checks matching.lua against station names taken from a real save. There is no standalone
-- Lua on the dev machine, so Factorio is the interpreter: set SELF_TEST in control.lua, then
--
--   factorio.exe --create smoke.zip --mod-directory ./testmods --config ./config.ini
--
-- and read script-output/tvi-selftest.txt under the config's write-data path.

local matching = require("matching")

-- reference stored in the interrupt, station being viewed, expected result
local CASES = {
  -- The drop-off is only ever named through the parametrised reference.
  { "[virtual-signal=signal-item-parameter][virtual-signal=down-arrow]",
    "[item=stone-brick][virtual-signal=down-arrow]", "wildcard" },
  -- ...and must not also claim the pickup.
  { "[virtual-signal=signal-item-parameter][virtual-signal=down-arrow]",
    "[item=stone-brick]", nil },
  -- The pickup is named literally.
  { "[item=stone-brick]", "[item=stone-brick]", "exact" },
  -- A name must not match a station that merely starts with it.
  { "[item=stone-brick]", "[item=stone-brick][virtual-signal=down-arrow]", nil },
  -- signal-fuel is an ordinary signal, not a wildcard.
  { "[virtual-signal=signal-fuel]", "[virtual-signal=signal-fuel]", "exact" },
  { "[virtual-signal=signal-item-parameter]", "[item=stone-brick]", "wildcard" },
  { "[virtual-signal=signal-fluid-parameter][virtual-signal=down-arrow]",
    "[fluid=crude-oil][virtual-signal=down-arrow]", "wildcard" },
  -- Wildcards can sit alongside plain text.
  { "[virtual-signal=signal-item-parameter] Has Cargo", "[item=stone-brick] Has Cargo",
    "wildcard" },
  { "Holding Station", "Holding Station", "exact" },
  { "Holding Station", "[item=stone-brick]", nil },
}

--- Exercise the schedule API against a real train.
--
-- Loading the file only proves it parses. Both runtime bugs found so far were calls with the
-- wrong shape -- passing `current` as a bare number to get_record, which wants a
-- ScheduleRecordPosition table -- and neither could surface without a train to call them on.
local function api_checks()
  local lines = {}

  local ok, err = pcall(function()
    local surface = game.surfaces[1]
    for y = -10, 10, 2 do
      surface.create_entity {
        name = "straight-rail", position = { 0, y },
        direction = defines.direction.north, force = "player",
      }
    end

    local loco = surface.create_entity {
      name = "locomotive", position = { 0, 0 },
      direction = defines.direction.north, force = "player",
    }
    if not loco then error("could not place a locomotive") end

    local schedule = loco.train.get_schedule()
    schedule.set_records { { station = "A" }, { station = "B" } }
    schedule.add_interrupt {
      name = "test",
      conditions = { { type = "empty", compare_type = "and" } },
      targets = { {
        station = "Holding",
        wait_conditions = {
          { type = "specific_destination_not_full", compare_type = "and", station = "A" },
        },
      } },
    }

    lines[#lines + 1] = "PASS  get_schedule -> current=" .. tostring(schedule.current)

    local record = schedule.get_record { schedule_index = schedule.current }
    lines[#lines + 1] = "PASS  get_record{schedule_index=current} -> station="
      .. tostring(record and record.station)

    local interrupts = schedule.get_interrupts()
    lines[#lines + 1] = "PASS  get_interrupts -> " .. #interrupts .. " interrupt(s)"

    local target = interrupts[1].targets[1]
    lines[#lines + 1] = "PASS  target.wait_conditions[1].station="
      .. tostring(target.wait_conditions[1].station)
  end)

  if not ok then lines[#lines + 1] = "FAIL  api: " .. tostring(err) end
  return lines
end

return function()
  local lines, failures = {}, 0

  for _, case in pairs(CASES) do
    local got = matching.reference_matches(case[1], case[2])
    local ok = got == case[3]
    if not ok then failures = failures + 1 end
    lines[#lines + 1] = (ok and "PASS" or "FAIL")
      .. "  ref=" .. case[1]
      .. "  station=" .. case[2]
      .. "  expected=" .. tostring(case[3])
      .. "  got=" .. tostring(got)
  end

  lines[#lines + 1] = failures .. " matcher failure(s) of " .. #CASES
  lines[#lines + 1] = ""

  for _, line in pairs(api_checks()) do
    lines[#lines + 1] = line
  end

  helpers.write_file("tvi-selftest.txt", table.concat(lines, "\n") .. "\n", false)
end
