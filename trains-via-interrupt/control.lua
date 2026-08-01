-- Trains via Interrupt
--
-- Vanilla's "Trains with this stop" tab lists only stations that sit in a train's schedule
-- proper. A station named inside an interrupt is invisible from the station side, which was
-- ruled "not a bug": interrupt targets aren't in the schedule until the temporary stop is
-- actually created. This mod fills that gap, and answers two separate questions about it --
-- which trains are wired up to this stop, and which of them want it right now.

local FRAME_NAME = "tvi-frame"
local CONTENT_NAME = "tvi-content"

-- Temporary diagnostic. Writes every interrupt's raw station references to
-- script-output/tvi-dump.txt each time a stop is opened, so the panel's classification can be
-- checked against what is actually stored. Done in the mod rather than via a /c command
-- because console commands permanently disable achievements on the save. Set false to silence.
local DEBUG_DUMP = false

-- Runs the matcher's cases during --create and writes script-output/tvi-selftest.txt.
local SELF_TEST = false

local matching = require("matching")

--- The item and fluid icons a schedule demonstrably deals in: its group name, plus every
--- station it names concretely. A wildcard on this schedule can only bind to one of these.
--
-- Every group carries the same generic interrupt, so without this a drop-off named
-- "[item=brick][down-arrow]" matches the iron group's interrupt exactly as well as the brick
-- group's, and the panel lists the entire network.
local function schedule_candidates(schedule, group)
  local candidates = matching.icons(group)

  local function consider(reference)
    if reference and not matching.has_wildcard(reference) then
      matching.icons(reference, candidates)
    end
  end

  for _, record in pairs(schedule.get_records() or {}) do
    consider(record.station)
  end

  for _, interrupt in pairs(schedule.get_interrupts()) do
    for _, condition in pairs(interrupt.conditions or {}) do
      consider(condition.station)
    end
    for _, target in pairs(interrupt.targets or {}) do
      consider(target.station)
      for _, wait in pairs(target.wait_conditions or {}) do
        consider(wait.station)
      end
    end
  end

  return candidates
end

--- Does this reference point at `station`, for a schedule dealing in `candidates`?
local function refers_to(reference, station, candidates)
  local result = matching.match(reference, station)
  if result and matching.plausible(result, candidates) then return result end
  return nil
end

--- Does any of this schedule's interrupts mention `station`, and how?
-- Returns a list of { name = interrupt name, kind = "exact"|"wildcard" }, one per interrupt
-- that refers to the station in any way at all -- as a place to send the train, as something
-- to wait on, or as the trigger. This is the "is it wired up to this stop" question, so the
-- three relationships are deliberately not distinguished.
local function schedule_references(schedule, station, candidates)
  local references = {}

  for _, interrupt in pairs(schedule.get_interrupts()) do
    local name = interrupt.name ~= "" and interrupt.name or nil
    local result = matching.conditions_match(interrupt.conditions, station, candidates)

    for _, target in pairs(interrupt.targets or {}) do
      result = result
        or refers_to(target.station, station, candidates)
        or matching.conditions_match(target.wait_conditions, station, candidates)
    end

    if result then references[#references + 1] = { name = name, kind = result.kind } end
  end

  return references
end

--- Is this train, right now, trying to get to `station`?
-- Its current schedule record is the one it is actually executing, so either that record
-- sends it here, or the record's wait conditions hold it somewhere else until this station
-- frees up. Both mean the train wants this stop and does not have it yet.
local function waiting_for(train, schedule, station, candidates)
  -- A train standing at the stop has arrived -- it is loading, not queuing. Its current
  -- record still points here, so without this it counts as on its way to a stop it is
  -- already occupying. Compare by name because a station is a name, not one entity.
  local stopped_at = train.station
  if stopped_at and stopped_at.valid and stopped_at.backer_name == station then
    return nil
  end

  -- `current` is a bare uint32 but get_record takes a ScheduleRecordPosition table.
  local record = schedule.get_record { schedule_index = schedule.current }
  if not record then return nil end

  if refers_to(record.station, station, candidates) then return "heading" end
  if matching.conditions_match(record.wait_conditions, station, candidates) then
    return "blocked"
  end
  return nil
end

--- Both questions in one pass over the trains.
--
-- Configured membership is a property of the schedule, so grouped trains share an answer and
-- it is computed once per group. Live demand is a property of the individual train -- each one
-- sits at its own point in the schedule -- so that is evaluated for every train.
local function scan(station, force)
  local schedules, configured, waiting = {}, {}, {}

  for _, train in pairs(game.train_manager.get_trains { force = force }) do
    local schedule = train.get_schedule()

    if schedule then
      local group = schedule.group
      local grouped = group ~= nil and group ~= ""
      local key = grouped and ("group:" .. group) or ("train:" .. train.id)
      local entry = schedules[key]

      if entry then
        entry.count = entry.count + 1
        -- Enough ids to make the tooltip useful without letting it run off screen.
        if #entry.train_ids < 20 then entry.train_ids[#entry.train_ids + 1] = train.id end
      else
        entry = {
          count = 1,
          train_ids = { train.id },
          group = grouped and group or nil,
          train = train,
          candidates = schedule_candidates(schedule, group),
        }
        entry.references = schedule_references(schedule, station, entry.candidates)
        schedules[key] = entry
        if #entry.references > 0 then configured[#configured + 1] = entry end
      end

      local state = waiting_for(train, schedule, station, entry.candidates)
      if state then
        waiting[#waiting + 1] = { train = train, group = entry.group, state = state }
      end
    end
  end

  return configured, waiting
end

--- Dump every station reference the scan can see. Names are bracketed so trailing spaces and
--- rich-text icons are visible rather than invisible.
local function dump(stop, player)
  local lines = { "", "=== opened stop: [" .. stop.backer_name .. "] ===" }
  local seen = {}

  for _, train in pairs(game.train_manager.get_trains { force = player.force }) do
    local schedule = train.get_schedule()
    if schedule then
      local group = schedule.group
      local key = (group ~= nil and group ~= "") and group or ("train " .. train.id)

      if not seen[key] then
        seen[key] = true
        lines[#lines + 1] = "-- " .. key
        for _, interrupt in pairs(schedule.get_interrupts()) do
          lines[#lines + 1] = "  interrupt [" .. tostring(interrupt.name) .. "]"
          for _, condition in pairs(interrupt.conditions or {}) do
            lines[#lines + 1] = "    cond " .. condition.type
              .. " station=[" .. tostring(condition.station) .. "]"
          end
          for _, target in pairs(interrupt.targets or {}) do
            lines[#lines + 1] = "    target station=[" .. tostring(target.station) .. "]"
            for _, wait in pairs(target.wait_conditions or {}) do
              lines[#lines + 1] = "      wait " .. wait.type
                .. " station=[" .. tostring(wait.station) .. "]"
            end
          end
        end
      end
    end
  end

  helpers.write_file("tvi-dump.txt", table.concat(lines, "\n") .. "\n", true)
end

--- Which interrupts matched, and which trains are behind a group row.
local function configured_tooltip(entry)
  local parts = { "" }
  for index, match in pairs(entry.references) do
    if index > 1 then parts[#parts + 1] = "\n" end
    local label = match.name or { "tvi.unnamed-interrupt" }
    -- A generic interrupt only routes here when its wildcard happens to bind to this
    -- station's icon, so say so rather than implying it always does.
    parts[#parts + 1] = match.kind == "wildcard"
      and { "tvi.via-generic", label }
      or { "tvi.via", label }
  end

  if entry.count > 1 then
    parts[#parts + 1] = "\n"
    local ids = {}
    for index, id in pairs(entry.train_ids) do
      ids[index] = tostring(id)
    end
    if entry.count > #entry.train_ids then
      ids[#ids + 1] = "..."
    end
    parts[#parts + 1] = { "tvi.tooltip-trains", table.concat(ids, ", ") }
  end

  return parts
end

local function add_row(container, caption, tooltip, train_id)
  local button = container.add {
    type = "button",
    style = "list_box_item",
    caption = caption,
    tooltip = tooltip,
    tags = { tvi_train = train_id },
  }
  button.style.horizontally_stretchable = true
end

-- The two counts answer different questions and were read as the same one, so each header
-- carries an explanation rather than relying on the wording of the caption alone.
local function add_header(container, caption_key, count)
  container.add {
    type = "label",
    caption = { caption_key, count },
    tooltip = { caption_key .. "-tooltip" },
    style = "caption_label",
  }
end

--- Schedules wired up to this stop, one row per group.
local function add_configured(container, configured)
  -- A group shares one schedule, so it is scanned once -- but it stands for every train in
  -- it, and the train count is what is actually being asked about. Count trains here, not
  -- rows, or a six-train group reads as "(1)".
  local trains = 0
  for _, entry in pairs(configured) do
    trains = trains + entry.count
  end

  add_header(container, "tvi.configured", trains)
  if #configured == 0 then
    container.add { type = "label", caption = { "tvi.none" } }
    return
  end

  for _, entry in pairs(configured) do
    -- Group names are often pure rich-text icons, which render as a caption with no readable
    -- text at all. The count keeps every row legible.
    local caption = entry.group
      and { "tvi.row-group", entry.group, entry.count }
      or { "tvi.row-train", entry.train.id }

    add_row(container, caption, configured_tooltip(entry), entry.train.id)
  end
end

--- Trains that want this stop right now, one row per train.
local function add_waiting(container, waiting)
  add_header(container, "tvi.waiting", #waiting)
  if #waiting == 0 then
    container.add { type = "label", caption = { "tvi.none" } }
    return
  end

  for _, item in pairs(waiting) do
    local caption = item.group
      and { "tvi.row-train-grouped", item.train.id, item.group }
      or { "tvi.row-train", item.train.id }

    add_row(container, caption, { "tvi." .. item.state }, item.train.id)
  end
end

local function refresh(player, stop)
  local frame = player.gui.relative[FRAME_NAME]
  if not frame then
    frame = player.gui.relative.add {
      type = "frame",
      name = FRAME_NAME,
      direction = "vertical",
      caption = { "tvi.title" },
      anchor = {
        gui = defines.relative_gui_type.train_stop_gui,
        position = defines.relative_gui_position.right,
      },
    }
    frame.style.minimal_width = 260
    frame.add {
      type = "frame",
      name = CONTENT_NAME,
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
    }
  end

  -- Remember which station these results describe, so a panel left over from a previously
  -- opened stop can be spotted and rebuilt rather than silently believed.
  frame.tags = { tvi_station = stop.backer_name }

  local content = frame[CONTENT_NAME]
  content.clear()

  if DEBUG_DUMP then dump(stop, player) end

  local configured, waiting = scan(stop.backer_name, player.force)
  add_configured(content, configured)
  add_waiting(content, waiting)
end

if SELF_TEST then
  script.on_init(require("dev-selftest"))
end

script.on_event(defines.events.on_gui_opened, function(event)
  local stop = event.entity
  if not (stop and stop.valid and stop.type == "train-stop") then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  refresh(player, stop)
end)

-- The relative frame outlives any single opening, and on_gui_opened is not the only way the
-- opened stop can change -- the stop GUI's own back/forward buttons walk between stops. A
-- panel describing the station you were looking at a moment ago is worse than no panel, so
-- confirm what is actually open rather than trusting the last event we saw.
script.on_nth_tick(20, function()
  for _, player in pairs(game.connected_players) do
    local frame = player.gui.relative[FRAME_NAME]
    if frame then
      local stop = player.opened
      local viewing_stop = player.opened_gui_type == defines.gui_type.entity
        and stop and stop.valid and stop.type == "train-stop"

      if not viewing_stop then
        frame.destroy()
      elseif frame.tags.tvi_station ~= stop.backer_name then
        refresh(player, stop)
      end
    end
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then return end

  local train_id = element.tags and element.tags.tvi_train
  if not train_id then return end

  local train = game.train_manager.get_train_by_id(train_id)
  if not (train and train.valid) then return end

  local player = game.get_player(event.player_index)
  if player then player.opened = train.front_stock end
end)
