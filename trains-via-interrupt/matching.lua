-- How a station name stored inside an interrupt relates to a station you are looking at.
--
-- Kept apart from control.lua so it can be exercised by dev-selftest.lua without a running
-- game: it is pure string work with no dependency on game state.

local matching = {}

-- The only wait-condition types that carry a station name. Per the WaitCondition docs,
-- `station` is populated for these four and nil everywhere else.
local STATION_CONDITION = {
  specific_destination_full = true,
  specific_destination_not_full = true,
  at_station = true,
  not_at_station = true,
}

-- The interrupt parameter wildcards, from base/prototypes/signal.lua. A station reference
-- containing one of these is a pattern rather than a name: at run time the wildcard binds to a
-- rich-text icon (usually whatever the train is carrying), so "[signal-item-parameter][down]"
-- stands for "[item=anything][down]". Note signal-fuel is an ordinary signal and not one of
-- these -- a station actually named after it matches literally.
local WILDCARD_SIGNALS = {
  ["signal-item-parameter"] = true,
  ["signal-fuel-parameter"] = true,
  ["signal-fluid-parameter"] = true,
  ["signal-signal-parameter"] = true,
}

local function escape(text)
  return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

--- A Lua pattern for a station reference containing wildcards, or nil if it has none.
-- Each wildcard becomes %b[], exactly one balanced rich-text tag, rather than "anything" --
-- the wildcard substitutes an icon, so a looser pattern would invent matches. Anchoring both
-- ends is what stops "[item=brick]" from claiming "[item=brick][down-arrow]".
local function wildcard_pattern(reference)
  local parts, cursor, position, found = {}, 1, 1, false

  while true do
    local start, stop, signal = reference:find("%[virtual%-signal=([%w%-]+)%]", position)
    if not start then break end

    if WILDCARD_SIGNALS[signal] then
      found = true
      parts[#parts + 1] = escape(reference:sub(cursor, start - 1))
      parts[#parts + 1] = "%b[]"
      cursor = stop + 1
    end
    position = stop + 1
  end

  if not found then return nil end
  parts[#parts + 1] = escape(reference:sub(cursor))
  return "^" .. table.concat(parts) .. "$"
end

--- How a stored station reference relates to this station: "exact", "wildcard", or nil.
--
-- Testing one known station name against a wildcard pattern is a single match. It is the
-- opposite direction -- asking which stations a wildcard could ever become -- that needs every
-- possible signal enumerated, and that is the expensive thing the base game declined to do.
-- Asked from the station side, the question is cheap.
function matching.reference_matches(reference, station)
  if reference == nil then return nil end
  if reference == station then return "exact" end

  local pattern = wildcard_pattern(reference)
  if pattern and station:match(pattern) then return "wildcard" end
  return nil
end

--- How any condition in the list refers to this station, preferring an exact match.
function matching.conditions_match(conditions, station)
  if not conditions then return nil end

  local result
  for _, condition in pairs(conditions) do
    if STATION_CONDITION[condition.type] then
      local kind = matching.reference_matches(condition.station, station)
      if kind == "exact" then return "exact" end
      result = result or kind
    end
  end
  return result
end

return matching
