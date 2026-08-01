-- Trains via Interrupt
--
-- Vanilla's "Trains with this stop" tab lists only stations that sit in a train's schedule
-- proper. A station named inside an interrupt is invisible from the station side, which was
-- ruled "not a bug": interrupt targets aren't in the schedule until the temporary stop is
-- actually created. This mod fills that gap for *concrete* station references only.

local FRAME_NAME = "tvi-frame"
local CONTENT_NAME = "tvi-content"

-- Temporary diagnostic. Writes every interrupt's raw station references to
-- script-output/tvi-dump.txt each time a stop is opened, so the panel's classification can be
-- checked against what is actually stored. Done in the mod rather than via a /c command
-- because console commands permanently disable achievements on the save. Set false to silence.
local DEBUG_DUMP = true

-- The only wait-condition types that carry a station name. Per the WaitCondition docs,
-- `station` is populated for these four and nil everywhere else.
local STATION_CONDITION = {
  specific_destination_full = true,
  specific_destination_not_full = true,
  at_station = true,
  not_at_station = true,
}

--- True if any condition in the list names this exact station.
local function names_station(conditions, station)
  if not conditions then return false end
  for _, condition in pairs(conditions) do
    if STATION_CONDITION[condition.type] and condition.station == station then
      return true
    end
  end
  return false
end

--- Every train's interrupts, searched for literal references to `station`.
--
-- Exact string equality is the entire filter, and that is the whole trick: a parametrised
-- target like "[item=parameter-0] pickup" never equals a real station name, so generic
-- interrupts fall out on their own and never have to be resolved. Resolving them is the
-- reason the base game declined to build this.
local function scan(station, force)
  local seen, found = {}, {}

  for _, train in pairs(game.train_manager.get_trains { force = force }) do
    local schedule = train.get_schedule()
    local group = schedule and schedule.group
    local grouped = group ~= nil and group ~= ""
    -- Trains in a group share one schedule, so scan it once and count the members.
    local key = grouped and ("group:" .. group) or ("train:" .. train.id)

    if seen[key] then
      local entry = seen[key]
      entry.count = entry.count + 1
      -- Enough ids to make the tooltip useful without letting it run off screen.
      if #entry.train_ids < 20 then entry.train_ids[#entry.train_ids + 1] = train.id end
    elseif schedule then
      local entry = {
        count = 1,
        train_ids = { train.id },
        group = grouped and group or nil,
        train = train,
        arrives = {},
        waits = {},
        triggers = {},
      }

      for _, interrupt in pairs(schedule.get_interrupts()) do
        local name = interrupt.name ~= "" and interrupt.name or nil

        -- The stop's own state fires the interrupt.
        if names_station(interrupt.conditions, station) then
          entry.triggers[#entry.triggers + 1] = name
        end

        for _, target in pairs(interrupt.targets or {}) do
          -- The train is actually sent here.
          if target.station == station then
            entry.arrives[#entry.arrives + 1] = name
          end
          -- The train sits somewhere else until this stop frees up. Vanilla shows nothing
          -- for this, yet these are the trains queued on your station's train limit.
          if names_station(target.wait_conditions, station) then
            entry.waits[#entry.waits + 1] = name
          end
        end
      end

      seen[key] = entry
      if #entry.arrives > 0 or #entry.waits > 0 or #entry.triggers > 0 then
        found[#found + 1] = entry
      end
    end
  end

  return found
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
local function row_tooltip(entry, interrupt_names)
  local parts = { "" }
  for index, name in pairs(interrupt_names) do
    if index > 1 then parts[#parts + 1] = "\n" end
    parts[#parts + 1] = name and { "tvi.via", name } or { "tvi.via-unnamed" }
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

local function add_section(container, caption_key, entries, field)
  -- A group shares one schedule, so it is scanned once -- but it stands for every train in
  -- it, and the train count is what the player is actually asking about. Count trains here,
  -- not rows, or a six-train group reads as "(1)".
  local rows, trains = {}, 0
  for _, entry in pairs(entries) do
    if #entry[field] > 0 then
      rows[#rows + 1] = entry
      trains = trains + entry.count
    end
  end

  container.add {
    type = "label",
    caption = { caption_key, trains },
    style = "caption_label",
  }

  if #rows == 0 then
    container.add { type = "label", caption = { "tvi.none" } }
    return
  end

  for _, entry in pairs(rows) do
    local caption
    if entry.group then
      -- Group names are often pure rich-text icons, which render as a caption with no
      -- readable text at all. The count keeps every row legible.
      caption = { "tvi.row-group", entry.group, entry.count }
    else
      caption = { "tvi.row-train", entry.train.id }
    end

    local button = container.add {
      type = "button",
      style = "list_box_item",
      caption = caption,
      tooltip = row_tooltip(entry, entry[field]),
      tags = { tvi_train = entry.train.id },
    }
    button.style.horizontally_stretchable = true
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

  local entries = scan(stop.backer_name, player.force)
  add_section(content, "tvi.arrives", entries, "arrives")
  add_section(content, "tvi.waits", entries, "waits")
  add_section(content, "tvi.triggers", entries, "triggers")
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
