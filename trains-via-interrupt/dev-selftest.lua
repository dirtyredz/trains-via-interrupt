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

  lines[#lines + 1] = failures .. " failure(s) of " .. #CASES
  helpers.write_file("tvi-selftest.txt", table.concat(lines, "\n") .. "\n", false)
end
