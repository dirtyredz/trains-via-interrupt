-- Checks matching.lua against station names taken from a real save. There is no standalone
-- Lua on the dev machine, so Factorio is the interpreter: set SELF_TEST in control.lua, then
--
--   factorio.exe --create smoke.zip --mod-directory ./testmods --config ./config.ini
--
-- and read script-output/tvi-selftest.txt under the config's write-data path.

local matching = require("matching")

local BRICK = "[item=stone-brick]"
local IRON = "[item=iron-plate]"
local OIL = "[fluid=crude-oil]"
local DOWN = "[virtual-signal=down-arrow]"
local ITEM_PARAM = "[virtual-signal=signal-item-parameter]"
local FLUID_PARAM = "[virtual-signal=signal-fluid-parameter]"

-- reference stored in the interrupt | station being viewed | icons the schedule deals in |
-- expected kind
local CASES = {
  -- The drop-off is only ever named through the parametrised reference, so it has to match...
  { ITEM_PARAM .. DOWN, BRICK .. DOWN, { BRICK }, "wildcard" },
  -- ...but every group carries that same generic interrupt. Without checking what the group
  -- actually hauls, the brick drop-off claims all 85 trains in the network.
  { ITEM_PARAM .. DOWN, BRICK .. DOWN, { IRON }, nil },
  { ITEM_PARAM .. DOWN, BRICK .. DOWN, {}, nil },
  -- Evidence can come from anywhere in the schedule, not just the group name.
  { ITEM_PARAM .. DOWN, BRICK .. DOWN, { IRON, BRICK }, "wildcard" },
  -- The drop-off reference must not also claim the pickup.
  { ITEM_PARAM .. DOWN, BRICK, { BRICK }, nil },
  -- The pickup is named literally, and an exact match needs no evidence.
  { BRICK, BRICK, {}, "exact" },
  -- A name must not match a station that merely starts with it.
  { BRICK, BRICK .. DOWN, { BRICK }, nil },
  -- signal-fuel is an ordinary signal, not a wildcard.
  { "[virtual-signal=signal-fuel]", "[virtual-signal=signal-fuel]", {}, "exact" },
  { ITEM_PARAM, BRICK, { BRICK }, "wildcard" },
  { FLUID_PARAM .. DOWN, OIL .. DOWN, { OIL }, "wildcard" },
  { FLUID_PARAM .. DOWN, OIL .. DOWN, { BRICK }, nil },
  -- Wildcards can sit alongside plain text.
  { ITEM_PARAM .. " Has Cargo", BRICK .. " Has Cargo", { BRICK }, "wildcard" },
  { "Holding Station", "Holding Station", {}, "exact" },
  { "Holding Station", BRICK, { BRICK }, nil },
}

local function run(case)
  local candidates = {}
  for _, icon in pairs(case[3]) do candidates[icon] = true end

  local result = matching.match(case[1], case[2])
  if result and not matching.plausible(result, candidates) then return nil end
  return result and result.kind or nil
end

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

    local records = schedule.get_records()
    lines[#lines + 1] = "PASS  get_records -> " .. #records .. " record(s)"

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
    local got = run(case)
    local ok = got == case[4]
    if not ok then failures = failures + 1 end
    lines[#lines + 1] = (ok and "PASS" or "FAIL")
      .. "  ref=" .. case[1]
      .. "  station=" .. case[2]
      .. "  deals-in=" .. (#case[3] > 0 and table.concat(case[3], ",") or "nothing")
      .. "  expected=" .. tostring(case[4])
      .. "  got=" .. tostring(got)
  end

  lines[#lines + 1] = failures .. " matcher failure(s) of " .. #CASES
  lines[#lines + 1] = ""

  for _, line in pairs(api_checks()) do
    lines[#lines + 1] = line
  end

  helpers.write_file("tvi-selftest.txt", table.concat(lines, "\n") .. "\n", false)
end
