-- PakettiAutomationStack.lua
-- Visualize all automation envelopes on the selected track within the selected pattern
-- Requirements honored:
-- - Lua 5.1 only
-- - All functions are GLOBAL and defined before first use
-- - Uses my_keyhandler_func from main.lua
-- - After dialog opens, reactivate middle frame to pass keys back to Renoise
-- - Stable ViewBuilder layout (rebuild content instead of toggling visibility)
-- - Uses shared PakettiCanvasFontDrawText when available

-- Global state
PakettiAutomationStack_dialog = nil
PakettiAutomationStack_vb = nil
PakettiAutomationStack_header_canvas = nil
PakettiAutomationStack_container = nil
PakettiAutomationStack_track_canvases = {}
PakettiAutomationStack_canvas_width = 1400
PakettiAutomationStack_lane_height = 80
PakettiAutomationStack_gutter_height = 18
PakettiAutomationStack_gutter_width = 0
PakettiAutomationStack_zoom_levels = {1.0, 0.5, 0.25, 0.125}
PakettiAutomationStack_zoom_index = 1
PakettiAutomationStack_view_start_line = 1
PakettiAutomationStack_scrollbar_view = nil
PakettiAutomationStack_timer_running = false
PakettiAutomationStack_timer_interval_ms = 120
PakettiAutomationStack_last_hash = ""
PakettiAutomationStack_automations = {}
PakettiAutomationStack_vertical_page_index = 1
PakettiAutomationStack_vertical_page_size = 8
PakettiAutomationStack_vscrollbar_view = nil
PakettiAutomationStack_min_redraw_ms = 60
PakettiAutomationStack_last_redraw_ms = 0
PakettiAutomationStack_is_drawing = false
PakettiAutomationStack_last_draw_line = -1
PakettiAutomationStack_last_draw_idx = -1
PakettiAutomationStack_last_draw_value = -1
PakettiAutomationStack_draw_playmode_index = 2 -- 1=Points,2=Lines,3=Curves
PakettiAutomationStack_selection_active = false
PakettiAutomationStack_selection_start_line = nil
PakettiAutomationStack_selection_end_line = nil
PakettiAutomationStack_selection_lane_index = nil
PakettiAutomationStack_show_all_vertically = false
PakettiAutomationStack_count_text_view = nil
PakettiAutomationStack_view_mode = 1 -- 1=Stack (multi lanes), 2=Single (overlay)
PakettiAutomationStack_env_popup_view = nil
PakettiAutomationStack_single_selected_index = 1
PakettiAutomationStack_single_canvas_height = 320
PakettiAutomationStack_copy_buffer = nil
PakettiAutomationStack_automation_hashes = {} -- Individual automation hashes for change detection

-- Observable management for auto-updating
PakettiAutomationStack_track_observables = {} -- Track mute state observables
PakettiAutomationStack_tracks_observable = nil -- Track list observable

-- Arbitrary Parameters Selection System
PakettiAutomationStack_arbitrary_mode = false -- false=current track, true=arbitrary selection
PakettiAutomationStack_selected_parameters = {} -- Array of {track_index, device_index, param_index}
PakettiAutomationStack_arbitrary_dialog = nil
PakettiAutomationStack_arbitrary_vb = nil
PakettiAutomationStack_parameter_checkboxes = {}

-- Show Same Parameters System
PakettiAutomationStack_show_same_mode = false -- false=normal modes, true=show same parameter name
PakettiAutomationStack_selected_param_name = "" -- The parameter name to filter by
PakettiAutomationStack_show_same_popup_view = nil

-- Preferences key for persistent storage
PakettiAutomationStack_prefs_key = "AutomationStack_SelectedParams"

-- Utility draw text helper
function PakettiAutomationStack_DrawText(ctx, text, x, y, size)
  if type(PakettiCanvasFontDrawText) == "function" then
    PakettiCanvasFontDrawText(ctx, text, x, y, size)
  else
    -- Minimal fallback: small tick + no real text (keeps code safe if font not present)
    ctx.stroke_color = {200,200,200,255}
    ctx:begin_path(); ctx:move_to(x, y); ctx:line_to(x+6, y); ctx:stroke()
  end
end

-- Get track color utility function
function PakettiAutomationStack_GetTrackColor(track_index)
  local song = renoise.song()
  if not song or track_index < 1 or track_index > #song.tracks then 
    return {255, 255, 255} -- Default white
  end
  
  local track = song.tracks[track_index]
  local color = track.color
  if not color or #color < 3 then
    return {255, 255, 255} -- Default white if no color
  end
  
  return {color[1], color[2], color[3]}
end

-- Check if track is muted
function PakettiAutomationStack_IsTrackMuted(track_index)
  local song = renoise.song()
  if not song or track_index < 1 or track_index > #song.tracks then 
    return false
  end
  
  local track = song.tracks[track_index]
  -- Master track doesn't have mute state
  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    return false
  end
  
  return track.mute_state == renoise.Track.MUTE_STATE_MUTED
end

-- Convert track color to canvas colors with alpha and brightness variations
function PakettiAutomationStack_TrackColorToCanvas(track_index, alpha, brightness_mult)
  local rgb = PakettiAutomationStack_GetTrackColor(track_index)
  alpha = alpha or 255
  brightness_mult = brightness_mult or 1.0
  
  -- Apply mute state - if muted, desaturate and darken significantly
  local is_muted = PakettiAutomationStack_IsTrackMuted(track_index)
  if is_muted then
    brightness_mult = brightness_mult * 0.3 -- Much darker when muted
    alpha = math.max(60, alpha * 0.4) -- Much more transparent when muted
    -- Desaturate by averaging with grey
    local grey = (rgb[1] + rgb[2] + rgb[3]) / 3
    rgb[1] = rgb[1] * 0.2 + grey * 0.8
    rgb[2] = rgb[2] * 0.2 + grey * 0.8
    rgb[3] = rgb[3] * 0.2 + grey * 0.8
  end
  
  -- Apply brightness multiplier and clamp
  local r = math.max(0, math.min(255, math.floor(rgb[1] * brightness_mult)))
  local g = math.max(0, math.min(255, math.floor(rgb[2] * brightness_mult)))
  local b = math.max(0, math.min(255, math.floor(rgb[3] * brightness_mult)))
  
  return {r, g, b, alpha}
end

-- Get contrasting track colors for automation drawing
function PakettiAutomationStack_GetTrackAutomationColors(track_index)
  local base_color = PakettiAutomationStack_TrackColorToCanvas(track_index, 235, 1.0)
  local bright_color = PakettiAutomationStack_TrackColorToCanvas(track_index, 255, 1.3)
  local dim_color = PakettiAutomationStack_TrackColorToCanvas(track_index, 180, 0.8)
  
  return base_color, bright_color, dim_color
end

-- Generate proper track name based on track type and position
function PakettiAutomationStack_GetTrackName(track_index)
  local song = renoise.song()
  if not song or track_index < 1 or track_index > #song.tracks then return "Unknown" end
  
  local track = song.tracks[track_index]
  
  if track.type == renoise.Track.TRACK_TYPE_MASTER then
    return track.name or "Master"
  elseif track.type == renoise.Track.TRACK_TYPE_SEND then
    return track.name or ("Send " .. string.format("%02d", track_index))
  elseif track.type == renoise.Track.TRACK_TYPE_GROUP then
    return track.name or ("Group " .. string.format("%02d", track_index))
  else -- TRACK_TYPE_SEQUENCER (regular tracks)
    -- Count sequencer tracks up to this point for proper numbering
    local sequencer_count = 0
    for i = 1, track_index do
      if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
        sequencer_count = sequencer_count + 1
      end
    end
    return track.name or ("Track " .. string.format("%02d", sequencer_count))
  end
end

-- Toggle track mute state
function PakettiAutomationStack_ToggleTrackMute(track_index)
  local song = renoise.song()
  if not song or track_index < 1 or track_index > #song.tracks then return end
  
  local track = song.tracks[track_index]
  -- Master track doesn't have mute state
  if track.type == renoise.Track.TRACK_TYPE_MASTER then return end
  
  if track.mute_state == renoise.Track.MUTE_STATE_MUTED then
    track:unmute()
    renoise.app():show_status("Automation Stack: Unmuted " .. PakettiAutomationStack_GetTrackName(track_index))
  else
    track:mute()
    renoise.app():show_status("Automation Stack: Muted " .. PakettiAutomationStack_GetTrackName(track_index))
  end
end

-- Key handler wrapper to support flood fill with Enter while delegating to my_keyhandler_func
function PakettiAutomationStack_KeyHandler(dialog, key)
  if key and key.modifiers == "" and (key.name == "return" or key.name == "enter") then
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    if song and patt and PakettiAutomationStack_selection_active and PakettiAutomationStack_selection_lane_index then
      local start_l = PakettiAutomationStack_selection_start_line or 1
      local end_l = PakettiAutomationStack_selection_end_line or patt.number_of_lines
      if start_l > end_l then local tmp = start_l; start_l = end_l; end_l = tmp end
      local v = PakettiAutomationStack_last_draw_value
      if not v then v = 0.0 end
      for L = start_l, end_l do
        PakettiAutomationStack_WritePoint(PakettiAutomationStack_selection_lane_index, L, v, false)
      end
      PakettiAutomationStack_selection_active = false
      PakettiAutomationStack_selection_lane_index = nil
      PakettiAutomationStack_selection_start_line = nil
      PakettiAutomationStack_selection_end_line = nil
      PakettiAutomationStack_RequestUpdate()
      renoise.app():show_status("Automation Stack: Flood filled lines " .. tostring(start_l) .. "-" .. tostring(end_l))
      return nil
    end
  end
  if type(my_keyhandler_func) == "function" then
    return my_keyhandler_func(dialog, key)
  end
  return key
end

-- Safe access helpers
function PakettiAutomationStack_GetSongPatternTrack()
  local song = renoise.song()
  if not song then return nil, nil, nil end
  local patt_idx = song.selected_pattern_index
  if patt_idx < 1 or patt_idx > #song.patterns then return song, nil, nil end
  local patt = song:pattern(patt_idx)
  local track_idx = song.selected_track_index
  if track_idx < 1 or track_idx > #song.tracks then return song, patt, nil end
  local ptrack = patt:track(track_idx)
  return song, patt, ptrack
end

-- Zoom and mapping
function PakettiAutomationStack_GetWindowLines(total_lines)
  local z = PakettiAutomationStack_zoom_levels[PakettiAutomationStack_zoom_index] or 1.0
  local win = math.max(1, math.floor(total_lines * z + 0.5))
  if win > total_lines then win = total_lines end
  return win
end

function PakettiAutomationStack_ClampView(total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local max_start = math.max(1, total_lines - win + 1)
  if PakettiAutomationStack_view_start_line < 1 then PakettiAutomationStack_view_start_line = 1 end
  if PakettiAutomationStack_view_start_line > max_start then PakettiAutomationStack_view_start_line = max_start end
end

function PakettiAutomationStack_MapTimeToX(t, total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local view_start_t = (PakettiAutomationStack_view_start_line - 1)
  -- Account for gutters - use effective width, not full canvas width
  local eff_w = math.max(1, PakettiAutomationStack_canvas_width - (2*PakettiAutomationStack_gutter_width))
  if win <= 1 then
    return PakettiAutomationStack_gutter_width + eff_w / 2
  end
  -- Map the full pattern length to the full canvas width for proper end-to-end drawing
  local divisor = total_lines  -- Use total pattern length so we can draw to the very end
  local x = PakettiAutomationStack_gutter_width + ((t - view_start_t) / divisor) * eff_w
  return x
end

function PakettiAutomationStack_LineToX(line_index, total_lines)
  return PakettiAutomationStack_MapTimeToX((line_index - 1), total_lines)
end

-- Inverse mapping: canvas x to pattern line
function PakettiAutomationStack_XToLine(x, total_lines)
  local win = PakettiAutomationStack_GetWindowLines(total_lines)
  local eff_w = math.max(1, PakettiAutomationStack_canvas_width - (2*PakettiAutomationStack_gutter_width))
  -- Remove gutter offset first (inverse of forward mapping)
  local x_eff = x - PakettiAutomationStack_gutter_width
  -- Map effective canvas width to 0-based time (inverse of forward mapping)
  local t_0based = (x_eff / eff_w) * total_lines
  -- Convert from 0-based time back to 1-based line number
  -- Allow drawing slightly beyond for canvas, but clamp for automation writing
  local line = math.max(1, math.floor(t_0based + 0.5))
  return line
end

function PakettiAutomationStack_UpdateScrollbars()
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then return end
  local num_lines = patt.number_of_lines
  PakettiAutomationStack_ClampView(num_lines)
  if PakettiAutomationStack_scrollbar_view then
    local win = PakettiAutomationStack_GetWindowLines(num_lines)
    PakettiAutomationStack_scrollbar_view.min = 1
    PakettiAutomationStack_scrollbar_view.max = num_lines + 1
    PakettiAutomationStack_scrollbar_view.pagestep = win
    PakettiAutomationStack_scrollbar_view.value = PakettiAutomationStack_view_start_line
  end
end

function PakettiAutomationStack_SetZoomIndex(idx)
  PakettiAutomationStack_zoom_index = math.max(1, math.min(#PakettiAutomationStack_zoom_levels, idx))
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RequestUpdate()
end

-- Hash builder for quick change detection
function PakettiAutomationStack_BuildAutomationHash()
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt or not ptrack then return "" end
  local acc = {tostring(patt.number_of_lines), tostring(song.selected_track_index), tostring(#song.tracks)}
  
  -- Include track count and mute states for change detection
  for track_idx = 1, #song.tracks do
    local track = song.tracks[track_idx]
    if track then
      local mute_state = "active"
      if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
        if track.mute_state == renoise.Track.MUTE_STATE_MUTED then
          mute_state = "muted"
        elseif track.mute_state == renoise.Track.MUTE_STATE_OFF then
          mute_state = "off"
        end
      end
      acc[#acc+1] = "t" .. tostring(track_idx) .. ":" .. mute_state .. ":" .. (track.name or "")
    end
  end
  
  local track = song.tracks[song.selected_track_index]
  if not track then return table.concat(acc, ":") end
  for d = 1, #track.devices do
    local dev = track.devices[d]
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = ptrack:find_automation(param)
        if a then
          local ok1, pm = pcall(function() return a.playmode end)
          acc[#acc+1] = tostring(pm or "?")
          acc[#acc+1] = tostring(param.name or "?")
          local points = a.points
          if points then
            acc[#acc+1] = tostring(#points)
            local sumt = 0; local sumv = 0
            for j = 1, #points do
              local p = points[j]
              sumt = sumt + (p.time or 0)
              sumv = sumv + math.floor(((p.value or 0)*1000)+0.5)
            end
            acc[#acc+1] = tostring(sumt)
            acc[#acc+1] = tostring(sumv)
          end
        end
      end
    end
  end
  return table.concat(acc, ":")
end

-- Build individual automation hashes for change detection
function PakettiAutomationStack_BuildIndividualHashes()
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt or not ptrack then return {} end
  local hashes = {}
  local track = song.tracks[song.selected_track_index]
  if not track then return hashes end
  local auto_index = 1
  for d = 1, #track.devices do
    local dev = track.devices[d]
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = ptrack:find_automation(param)
        if a then
          local acc = {}
          local ok1, pm = pcall(function() return a.playmode end)
          acc[#acc+1] = tostring(pm or "?")
          acc[#acc+1] = tostring(param.name or "?")
          local points = a.points
          if points then
            acc[#acc+1] = tostring(#points)
            local sumt = 0; local sumv = 0
            for j = 1, #points do
              local p = points[j]
              sumt = sumt + (p.time or 0)
              sumv = sumv + math.floor(((p.value or 0)*1000)+0.5)
            end
            acc[#acc+1] = tostring(sumt)
            acc[#acc+1] = tostring(sumv)
          end
          hashes[auto_index] = table.concat(acc, ":")
          auto_index = auto_index + 1
        end
      end
    end
  end
  return hashes
end

-- Detect which automation changed and auto-select it
function PakettiAutomationStack_DetectChangedAutomation()
  local new_hashes = PakettiAutomationStack_BuildIndividualHashes()
  for i = 1, #new_hashes do
    local old_hash = PakettiAutomationStack_automation_hashes[i]
    local new_hash = new_hashes[i]
    if old_hash and old_hash ~= new_hash then
      -- This automation changed, auto-select it
      if PakettiAutomationStack_view_mode == 2 then
        -- Single view mode
        PakettiAutomationStack_single_selected_index = i
        PakettiAutomationStack_UpdateEnvPopup()
        local entry = PakettiAutomationStack_automations[i]
        if entry then
          renoise.app():show_status("Auto-selected: " .. (entry.device_name or "Device") .. ": " .. (entry.name or "Parameter"))
        end
      end
      break -- Only select the first changed automation
    end
  end
  PakettiAutomationStack_automation_hashes = new_hashes
end

-- Enumerate all automatable parameters from all tracks
function PakettiAutomationStack_GetAllParameters()
  local song = renoise.song()
  if not song then return {} end
  local all_params = {}
  
  for track_idx = 1, #song.tracks do
    local track = song.tracks[track_idx]
    local track_name = PakettiAutomationStack_GetTrackName(track_idx)
    
    for dev_idx = 1, #track.devices do
      local dev = track.devices[dev_idx]
      local device_name = dev.display_name or "Device"
      
      for param_idx = 1, #dev.parameters do
        local param = dev.parameters[param_idx]
        if param.is_automatable then
          local param_key = track_idx .. "_" .. dev_idx .. "_" .. param_idx
          local display_name = string.format("Track%02d: %s: %s", 
            track_idx, device_name, param.name or "Parameter")
          
          all_params[#all_params+1] = {
            key = param_key,
            track_index = track_idx,
            device_index = dev_idx,
            param_index = param_idx,
            track_name = track_name,
            device_name = device_name,
            param_name = param.name or "Parameter",
            display_name = display_name,
            parameter = param
          }
        end
      end
    end
  end
  
  return all_params
end

-- Get all unique parameter names that currently have automation data
function PakettiAutomationStack_GetUniqueAutomatedParameterNames()
  local song, patt = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then return {} end
  
  local unique_names = {}
  local name_counts = {} -- Track how many times each name appears
  
  for track_idx = 1, #song.tracks do
    local track = song.tracks[track_idx]
    local pattern_track = patt:track(track_idx)
    if pattern_track then
      for dev_idx = 1, #track.devices do
        local dev = track.devices[dev_idx]
        for param_idx = 1, #dev.parameters do
          local param = dev.parameters[param_idx]
          if param.is_automatable then
            local automation = pattern_track:find_automation(param)
            if automation and automation.points and #automation.points > 0 then
              local param_name = param.name or "Parameter"
              if not name_counts[param_name] then
                name_counts[param_name] = 0
                unique_names[#unique_names+1] = param_name
              end
              name_counts[param_name] = name_counts[param_name] + 1
            end
          end
        end
      end
    end
  end
  
  -- Sort by name and add count information
  table.sort(unique_names)
  local result = {}
  for i = 1, #unique_names do
    local name = unique_names[i]
    local count = name_counts[name]
    local display_name = string.format("%s (%d)", name, count)
    result[#result+1] = {
      name = name,
      count = count,
      display_name = display_name
    }
  end
  
  return result
end

-- Check if a parameter is selected for arbitrary display
function PakettiAutomationStack_IsParameterSelected(track_idx, dev_idx, param_idx)
  for i = 1, #PakettiAutomationStack_selected_parameters do
    local sel = PakettiAutomationStack_selected_parameters[i]
    if sel.track_index == track_idx and sel.device_index == dev_idx and sel.param_index == param_idx then
      return true
    end
  end
  return false
end

-- Add parameter to selection
function PakettiAutomationStack_AddParameter(track_idx, dev_idx, param_idx)
  if not PakettiAutomationStack_IsParameterSelected(track_idx, dev_idx, param_idx) then
    PakettiAutomationStack_selected_parameters[#PakettiAutomationStack_selected_parameters+1] = {
      track_index = track_idx,
      device_index = dev_idx,
      param_index = param_idx
    }
  end
end

-- Remove parameter from selection
function PakettiAutomationStack_RemoveParameter(track_idx, dev_idx, param_idx)
  for i = #PakettiAutomationStack_selected_parameters, 1, -1 do
    local sel = PakettiAutomationStack_selected_parameters[i]
    if sel.track_index == track_idx and sel.device_index == dev_idx and sel.param_index == param_idx then
      table.remove(PakettiAutomationStack_selected_parameters, i)
      break
    end
  end
end

-- Save selected parameters to preferences
function PakettiAutomationStack_SaveSelectedParameters()
  local params_table = {}
  for i = 1, #PakettiAutomationStack_selected_parameters do
    local sel = PakettiAutomationStack_selected_parameters[i]
    local param_string = sel.track_index .. "_" .. sel.device_index .. "_" .. sel.param_index
    params_table[#params_table+1] = param_string
  end
  renoise.tool().preferences[PakettiAutomationStack_prefs_key] = table.concat(params_table, ",")
end

-- Load selected parameters from preferences
function PakettiAutomationStack_LoadSelectedParameters()
  local params_string = renoise.tool().preferences[PakettiAutomationStack_prefs_key]
  PakettiAutomationStack_selected_parameters = {}
  
  if params_string and params_string.value and params_string.value ~= "" then
    local param_strings = {}
    for param_str in params_string.value:gmatch("[^,]+") do
      param_strings[#param_strings+1] = param_str
    end
    
    for i = 1, #param_strings do
      local parts = {}
      for part in param_strings[i]:gmatch("[^_]+") do
        parts[#parts+1] = tonumber(part)
      end
      
      if #parts == 3 then
        PakettiAutomationStack_selected_parameters[#PakettiAutomationStack_selected_parameters+1] = {
          track_index = parts[1],
          device_index = parts[2],
          param_index = parts[3]
        }
      end
    end
  end
end

-- Rebuild automation list (modified to support arbitrary parameters and show same)
function PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_automations = {}
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then return end
  
  if PakettiAutomationStack_show_same_mode then
    -- Show Same mode: find all automations with the selected parameter name
    if PakettiAutomationStack_selected_param_name and PakettiAutomationStack_selected_param_name ~= "" then
      for track_idx = 1, #song.tracks do
        local track = song.tracks[track_idx]
        local pattern_track = patt:track(track_idx)
        if pattern_track then
          for dev_idx = 1, #track.devices do
            local dev = track.devices[dev_idx]
            for param_idx = 1, #dev.parameters do
              local param = dev.parameters[param_idx]
              if param.is_automatable and (param.name or "Parameter") == PakettiAutomationStack_selected_param_name then
                local a = pattern_track:find_automation(param)
                -- Show parameter even if no automation exists yet (allows creating new automation)
                local entry = {
                  automation = a, -- May be nil for new automation
                  parameter = param,
                  pattern_track = pattern_track, -- Store for creating automation later
                  name = param.name or "Parameter",
                  device_name = dev.display_name or "Device",
                  track_name = PakettiAutomationStack_GetTrackName(track_idx),
                  track_index = track_idx,
                  playmode = a and a.playmode or renoise.PatternTrackAutomation.PLAYMODE_LINES
                }
                PakettiAutomationStack_automations[#PakettiAutomationStack_automations+1] = entry
              end
            end
          end
        end
      end
    end
  elseif PakettiAutomationStack_arbitrary_mode then
    -- Arbitrary mode: show selected parameters from any track
    for i = 1, #PakettiAutomationStack_selected_parameters do
      local sel = PakettiAutomationStack_selected_parameters[i]
      local track = song.tracks[sel.track_index]
      if track then
        local pattern_track = patt:track(sel.track_index)
        if pattern_track then
          local dev = track.devices[sel.device_index]
          if dev then
            local param = dev.parameters[sel.param_index]
            if param and param.is_automatable then
              local a = pattern_track:find_automation(param)
              -- Show parameter even if no automation exists yet (allows creating new automation)
              local entry = {
                automation = a, -- May be nil for new automation
                parameter = param,
                pattern_track = pattern_track, -- Store for creating automation later
                name = param.name or "Parameter",
                device_name = dev.display_name or "Device",
                track_name = PakettiAutomationStack_GetTrackName(sel.track_index),
                track_index = sel.track_index,
                playmode = a and a.playmode or renoise.PatternTrackAutomation.PLAYMODE_LINES
              }
              PakettiAutomationStack_automations[#PakettiAutomationStack_automations+1] = entry
            end
          end
        end
      end
    end
  else
    -- Current track mode: original behavior
    if not ptrack then return end
    local track = song.tracks[song.selected_track_index]
    if not track then return end
    for d = 1, #track.devices do
      local dev = track.devices[d]
      for pi = 1, #dev.parameters do
        local param = dev.parameters[pi]
        if param.is_automatable then
          local a = ptrack:find_automation(param)
          -- Include parameter even if no automation exists yet (allows creating new automation)
          local entry = {
            automation = a, -- May be nil for new automation
            parameter = param,
            pattern_track = ptrack, -- Store for creating automation later
            name = param.name or "Parameter",
            device_name = dev.display_name or "Device",
            track_name = PakettiAutomationStack_GetTrackName(song.selected_track_index),
            track_index = song.selected_track_index,
            playmode = a and a.playmode or renoise.PatternTrackAutomation.PLAYMODE_LINES
          }
          PakettiAutomationStack_automations[#PakettiAutomationStack_automations+1] = entry
        end
      end
    end
  end
  PakettiAutomationStack_UpdateEnvPopup()
end

-- Redraw throttling
function PakettiAutomationStack_RequestUpdate()
  local now_ms = os.clock() * 1000
  if (now_ms - PakettiAutomationStack_last_redraw_ms) >= PakettiAutomationStack_min_redraw_ms then
    if PakettiAutomationStack_header_canvas and PakettiAutomationStack_header_canvas.visible then PakettiAutomationStack_header_canvas:update() end
    if PakettiAutomationStack_track_canvases and #PakettiAutomationStack_track_canvases > 0 then
      for i = 1, #PakettiAutomationStack_track_canvases do
        local c = PakettiAutomationStack_track_canvases[i]
        if c and c.visible then c:update() end
      end
    end
    PakettiAutomationStack_last_redraw_ms = now_ms
  end
end

-- Rendering helpers
function PakettiAutomationStack_DrawGrid(ctx, W, H, num_lines, lpb)
  local win = PakettiAutomationStack_GetWindowLines(num_lines)
  local pixels_per_line = W / win
  -- background
  ctx:set_fill_linear_gradient(0, 0, 0, H)
  ctx:add_fill_color_stop(0, {25,25,35,255})
  ctx:add_fill_color_stop(1, {15,15,25,255})
  ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
  -- gutters (only if gutter_width > 0)
  local gutter = PakettiAutomationStack_gutter_width
  if gutter > 0 then
    ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
    ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
  end
  -- grid
  if pixels_per_line >= 6 then
    for line = PakettiAutomationStack_view_start_line, math.min(num_lines, PakettiAutomationStack_view_start_line + win - 1) do
      local x = PakettiAutomationStack_LineToX(line, num_lines)
      if ((line-1) % (lpb*4)) == 0 then
        ctx.stroke_color = {110,110,160,255}; ctx.line_width = 3
      elseif ((line-1) % lpb) == 0 then
        ctx.stroke_color = {80,80,120,220}; ctx.line_width = 2
      else
        ctx.stroke_color = {40,40,60,130}; ctx.line_width = 1
      end
      ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
    end
  else
    ctx.line_width = 1
    for line = PakettiAutomationStack_view_start_line, math.min(num_lines, PakettiAutomationStack_view_start_line + win - 1) do
      if ((line-1) % lpb) == 0 then
        local x = PakettiAutomationStack_LineToX(line, num_lines)
        ctx.stroke_color = {70,70,100,220}
        ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
      end
    end
  end
end

-- Draw a single automation into an existing canvas with track-based colors or custom colors
function PakettiAutomationStack_DrawAutomation(entry, ctx, W, H, num_lines, color_main, color_point, line_width, use_track_colors)
  if not entry or not entry.automation then return end
  local a = entry.automation
  local points = a.points or {}
  local mode = a.playmode or renoise.PatternTrackAutomation.PLAYMODE_POINTS
  local gutter = PakettiAutomationStack_gutter_width
  if #points == 0 then return end
  
  -- Use track colors if enabled and we have a track index, otherwise use provided colors
  local main_color = color_main
  local point_color = color_point
  
  if use_track_colors and entry.track_index then
    local base_color, bright_color, dim_color = PakettiAutomationStack_GetTrackAutomationColors(entry.track_index)
    main_color = base_color
    point_color = bright_color
  end
  
  if mode == renoise.PatternTrackAutomation.PLAYMODE_POINTS then
    ctx.stroke_color = main_color
    ctx.line_width = line_width
    for i = 1, #points do
      local p = points[i]
      local x = PakettiAutomationStack_MapTimeToX((p.time or 1) - 1, num_lines)
      local y = PakettiAutomationStack_ValueToY(p.value, H)
      -- Remove gutter constraints since gutter_width = 0
      if gutter > 0 then
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
      end
      ctx:begin_path(); ctx:move_to(x, H-1); ctx:line_to(x, y); ctx:stroke()
      ctx.stroke_color = point_color
      ctx.line_width = math.max(1, line_width - 1)
      ctx:begin_path(); ctx:move_to(x-1, y); ctx:line_to(x+1, y); ctx:stroke()
      ctx.stroke_color = main_color
      ctx.line_width = line_width
    end
  elseif mode == renoise.PatternTrackAutomation.PLAYMODE_LINES then
    ctx.stroke_color = main_color
    ctx.line_width = line_width
    ctx:begin_path()
    local p1 = points[1]
    local x1 = PakettiAutomationStack_MapTimeToX((p1.time or 1) - 1, num_lines)
    local y1 = PakettiAutomationStack_ValueToY(p1.value, H)
    if x1 < gutter then x1 = gutter end
    if x1 > W - gutter then x1 = W - gutter end
    ctx:move_to(x1, y1)
    for i = 2, #points do
      local p = points[i]
      local x = PakettiAutomationStack_MapTimeToX((p.time or 1) - 1, num_lines)
      local y = PakettiAutomationStack_ValueToY(p.value, H)
      -- Remove gutter constraints since gutter_width = 0
      if gutter > 0 then
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
      end
      ctx:line_to(x, y)
    end
    ctx:stroke()
  else
    ctx.stroke_color = main_color
    ctx.line_width = line_width
    for seg = 1, (#points - 1) do
      local p0 = points[math.max(1, seg-1)]
      local p1c = points[seg]
      local p2 = points[seg+1]
      local p3 = points[math.min(#points, seg+2)]
      local x1 = PakettiAutomationStack_MapTimeToX((p1c.time or 1) - 1, num_lines)
      local y1 = PakettiAutomationStack_ValueToY(p1c.value, H)
      local x2 = PakettiAutomationStack_MapTimeToX((p2.time or 1) - 1, num_lines)
      local y2 = PakettiAutomationStack_ValueToY(p2.value, H)
      if x2 <= x1 then x2 = x1 + 1 end
      local steps = math.max(8, math.floor((x2 - x1) / 6))
      local function hermite(t, y_0, y_1, y_2, y_3)
        local m1 = 0.5 * (y_2 - y_0)
        local m2 = 0.5 * (y_3 - y_1)
        local t2 = t * t
        local t3 = t2 * t
        local h00 = 2*t3 - 3*t2 + 1
        local h10 = t3 - 2*t2 + t
        local h01 = -2*t3 + 3*t2
        local h11 = t3 - t2
        return h00*y_1 + h10*m1 + h01*y_2 + h11*m2
      end
      ctx:begin_path()
      for s = 0, steps do
        local t = s / steps
        local x = x1 + (x2 - x1) * t
        local y = hermite(t, PakettiAutomationStack_ValueToY(p0.value, H), y1, y2, PakettiAutomationStack_ValueToY(p3.value, H))
        if s == 0 then ctx:move_to(x, y) else ctx:line_to(x, y) end
      end
      ctx:stroke()
    end
  end
end

-- Single view renderer (overlay all automations, highlight selected)
function PakettiAutomationStack_RenderSingleCanvas(canvas_w, canvas_h)
  return function(ctx)
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    local W = canvas_w or PakettiAutomationStack_canvas_width
    local H = canvas_h or PakettiAutomationStack_single_canvas_height
    ctx:clear_rect(0, 0, W, H)
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local lpb = song.transport.lpb
    PakettiAutomationStack_DrawGrid(ctx, W, H, num_lines, lpb)

    if #PakettiAutomationStack_automations == 0 then return end
    local sel = PakettiAutomationStack_single_selected_index
    if sel < 1 then sel = 1 end
    if sel > #PakettiAutomationStack_automations then sel = #PakettiAutomationStack_automations end

    -- Draw background automations dimmed (using track colors with reduced alpha)
    for i = 1, #PakettiAutomationStack_automations do
      if i ~= sel then
        local entry = PakettiAutomationStack_automations[i]
        if entry.track_index then
          local dim_main = PakettiAutomationStack_TrackColorToCanvas(entry.track_index, 90, 0.7)
          local dim_point = PakettiAutomationStack_TrackColorToCanvas(entry.track_index, 80, 1.0)
          PakettiAutomationStack_DrawAutomation(entry, ctx, W, H, num_lines, dim_main, dim_point, 2, false)
        else
          PakettiAutomationStack_DrawAutomation(entry, ctx, W, H, num_lines, {90,190,170,90}, {200,255,255,80}, 2, false)
        end
      end
    end
    -- Draw selected on top (using track colors with full opacity)
    local sel_entry = PakettiAutomationStack_automations[sel]
    if sel_entry then
      PakettiAutomationStack_DrawAutomation(sel_entry, ctx, W, H, num_lines, nil, nil, 3, true)
    end
    -- Title for selected automation only
    if sel_entry then
      local label
      if PakettiAutomationStack_arbitrary_mode and sel_entry.track_index then
        label = string.format("Track%02d: %s: %s", 
          sel_entry.track_index, (sel_entry.device_name or "DEVICE"), (sel_entry.name or "PARAM"))
      else
        label = string.format("%s: %s", (sel_entry.device_name or "DEVICE"), (sel_entry.name or "PARAM"))
      end
      
      -- Get track color for title background
      local track_idx = sel_entry.track_index or renoise.song().selected_track_index
      local track_color = PakettiAutomationStack_TrackColorToCanvas(track_idx, 180, 0.4)
      local track_border = PakettiAutomationStack_TrackColorToCanvas(track_idx, 255, 0.9)
      
      -- Draw colored background with track color
      ctx.fill_color = track_color
      ctx:begin_path(); ctx:rect(2, 2, W - 4, 12); ctx:fill()
      
      -- Draw colored border
      ctx.stroke_color = track_border
      ctx.line_width = 1
      ctx:begin_path(); ctx:rect(2, 2, W - 4, 12); ctx:stroke()
      
      -- Add mute indicator if track is muted
      local is_muted = PakettiAutomationStack_IsTrackMuted(track_idx)
      local mute_suffix = is_muted and " (MUTED - CLICK TO UNMUTE)" or ""
      
      -- Draw text with high contrast color or dimmed if muted
      if is_muted then
        ctx.stroke_color = {200, 200, 200, 255} -- Slightly dimmed for muted tracks
      else
        ctx.stroke_color = {255, 255, 255, 255}
      end
      PakettiAutomationStack_DrawText(ctx, string.upper(label .. mute_suffix), 6, 4, 8)
    end
  end
end

-- Mouse handler for Single view (operates on selected automation)
function PakettiAutomationStack_SingleMouse(ev, lane_h)
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
  if #PakettiAutomationStack_automations == 0 then return end
  local num_lines = patt.number_of_lines
  local x = ev.position.x
  local y = ev.position.y
  local line = PakettiAutomationStack_XToLine(x, num_lines)
  local value = PakettiAutomationStack_YToValue(y, lane_h)
  local mods = tostring(ev.modifiers or "")
  local is_alt = (string.find(mods:lower(), "alt", 1, true) ~= nil) or (string.find(mods:lower(), "option", 1, true) ~= nil)
  local idx = PakettiAutomationStack_single_selected_index
  if idx < 1 then idx = 1 end
  if idx > #PakettiAutomationStack_automations then idx = #PakettiAutomationStack_automations end
  if ev.type == "down" and ev.button == "left" then
    -- Check if click is on the label area (top 14 pixels)
    if y <= 14 then
      local entry = PakettiAutomationStack_automations[idx]
      if entry and entry.track_index then
        PakettiAutomationStack_ToggleTrackMute(entry.track_index)
        -- Also show the automation envelope for this parameter
        PakettiAutomationStack_ShowAutomationEnvelope(entry)
        PakettiAutomationStack_RequestUpdate()
        return
      end
    end
    PakettiAutomationStack_is_drawing = true
    PakettiAutomationStack_last_draw_line = line
    PakettiAutomationStack_last_draw_idx = idx
    PakettiAutomationStack_last_draw_value = value
    
    -- Show automation envelope in lower frame for visual feedback
    local entry = PakettiAutomationStack_automations[idx]
    if entry then
      PakettiAutomationStack_ShowAutomationEnvelope(entry)
    end
    
    PakettiAutomationStack_WritePoint(idx, line, value, is_alt)
    PakettiAutomationStack_RequestUpdate()
  elseif ev.type == "down" and ev.button == "right" then
    local entry = PakettiAutomationStack_automations[idx]
    if entry and entry.automation then
      local a = entry.automation
      if a.points and #a.points > 0 then
        for i = #a.points, 1, -1 do
          local pt = a.points[i]
          if pt and pt.time then
            local L = math.floor(pt.time)
            if L < 1 then L = 1 end
            a:remove_point_at(L)
          end
        end
        PakettiAutomationStack_RequestUpdate()
      end
    end
  elseif ev.type == "move" then
    if PakettiAutomationStack_is_drawing and PakettiAutomationStack_last_draw_idx == idx then
      if line ~= PakettiAutomationStack_last_draw_line or math.abs(value - PakettiAutomationStack_last_draw_value) >= 0.001 then
        local start_l = PakettiAutomationStack_last_draw_line
        local end_l = line
        if start_l and end_l then
          local step = (end_l >= start_l) and 1 or -1
          local count = math.abs(end_l - start_l)
          if count <= 1 then
            PakettiAutomationStack_WritePoint(idx, line, value, is_alt)
          else
            for L = start_l, end_l, step do
              local t = (count > 0) and (math.abs(L - start_l) / count) or 1.0
              local v = PakettiAutomationStack_last_draw_value + (value - PakettiAutomationStack_last_draw_value) * t
              PakettiAutomationStack_WritePoint(idx, L, v, is_alt)
            end
          end
        end
        PakettiAutomationStack_last_draw_line = line
        PakettiAutomationStack_last_draw_value = value
        PakettiAutomationStack_RequestUpdate()
      end
    end
  elseif ev.type == "up" and ev.button == "left" then
    PakettiAutomationStack_is_drawing = false
    PakettiAutomationStack_last_draw_idx = -1
    PakettiAutomationStack_RequestUpdate()
  end
end

-- Update popup items from current automations
function PakettiAutomationStack_UpdateEnvPopup()
  if not PakettiAutomationStack_env_popup_view then return end
  local items_with_content = {}
  local items_without_content = {}
  
  for i = 1, #PakettiAutomationStack_automations do
    local e = PakettiAutomationStack_automations[i]
    local label
    if PakettiAutomationStack_arbitrary_mode and e.track_index then
      label = string.format("Track%02d: %s: %s", e.track_index, (e.device_name or "Device"), (e.name or "Param"))
    else
      label = string.format("%s: %s", (e.device_name or "Device"), (e.name or "Param"))
    end
    
    -- Check if this automation has content (points)
    local has_content = false
    if e.automation and e.automation.points and #e.automation.points > 0 then
      has_content = true
    end
    
    if has_content then
      items_with_content[#items_with_content+1] = label
    else
      items_without_content[#items_without_content+1] = label
    end
  end
  
  -- Combine: content first, then empty ones
  local items = {}
  for i = 1, #items_with_content do
    items[#items+1] = items_with_content[i]
  end
  for i = 1, #items_without_content do
    items[#items+1] = items_without_content[i]
  end
  
  if #items == 0 then items = {"(none)"} end
  PakettiAutomationStack_env_popup_view.items = items
  if PakettiAutomationStack_single_selected_index < 1 then PakettiAutomationStack_single_selected_index = 1 end
  if PakettiAutomationStack_single_selected_index > #items then PakettiAutomationStack_single_selected_index = #items end
  PakettiAutomationStack_env_popup_view.value = PakettiAutomationStack_single_selected_index
end

-- Copy / Paste
function PakettiAutomationStack_CopySelectedEnvelope()
  local idx = PakettiAutomationStack_single_selected_index
  if idx < 1 or idx > #PakettiAutomationStack_automations then renoise.app():show_status("Automation Stack: Nothing to copy") return end
  local entry = PakettiAutomationStack_automations[idx]
  if not entry or not entry.automation then renoise.app():show_status("Automation Stack: No automation to copy") return end
  local a = entry.automation
  local buf = { playmode = a.playmode, points = {} }
  local pts = a.points or {}
  for i = 1, #pts do
    local p = pts[i]
    buf.points[#buf.points+1] = { time = p.time, value = p.value }
  end
  PakettiAutomationStack_copy_buffer = buf
  renoise.app():show_status("Automation Stack: Copied " .. tostring(#buf.points) .. " points")
end

function PakettiAutomationStack_PasteIntoSelectedEnvelope()
  if not PakettiAutomationStack_copy_buffer or not PakettiAutomationStack_copy_buffer.points then
    renoise.app():show_status("Automation Stack: Copy buffer is empty")
    return
  end
  local idx = PakettiAutomationStack_single_selected_index
  if idx < 1 or idx > #PakettiAutomationStack_automations then renoise.app():show_status("Automation Stack: No destination envelope") return end
  local entry = PakettiAutomationStack_automations[idx]
  if not entry or not entry.automation then renoise.app():show_status("Automation Stack: No destination envelope") return end
  local a = entry.automation
  -- Clear existing points
  local pts = a.points or {}
  for i = #pts, 1, -1 do
    local pt = pts[i]
    if pt and pt.time then a:remove_point_at(math.floor(pt.time)) end
  end
  -- Paste
  a.playmode = PakettiAutomationStack_copy_buffer.playmode or a.playmode
  for i = 1, #PakettiAutomationStack_copy_buffer.points do
    local p = PakettiAutomationStack_copy_buffer.points[i]
    a:add_point_at(math.floor(p.time), p.value)
  end
  PakettiAutomationStack_RequestUpdate()
  renoise.app():show_status("Automation Stack: Pasted " .. tostring(#PakettiAutomationStack_copy_buffer.points) .. " points")
end

function PakettiAutomationStack_ValueToY(v, H)
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return (H - (v * H))
end

function PakettiAutomationStack_YToValue(y, H)
  local v = 1.0 - (y / H)
  if v < 0 then v = 0 end
  if v > 1 then v = 1 end
  return v
end

function PakettiAutomationStack_PlaymodeForIndex(idx)
  if idx == 1 then return renoise.PatternTrackAutomation.PLAYMODE_POINTS end
  if idx == 3 then return renoise.PatternTrackAutomation.PLAYMODE_CURVES end
  return renoise.PatternTrackAutomation.PLAYMODE_LINES
end

-- Show automation envelope in lower frame for visual feedback
function PakettiAutomationStack_ShowAutomationEnvelope(entry)
  if not entry or not entry.parameter then return end
  
  local success, error_msg = pcall(function()
    local song = renoise.song()
    
    -- Show automation frame and make it active
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Make sure we're looking at the right track
    if entry.track_index then
      song.selected_track_index = entry.track_index
    end
    
    -- Select this parameter's automation envelope
    song.selected_automation_parameter = entry.parameter
    
    -- Force a refresh of the automation data to ensure consistency
    PakettiAutomationStack_RequestUpdate()
  end)
  
  if not success then
    print("AUTOMATION_ERROR: Failed to select parameter '" .. (entry.parameter.name or "Unknown") .. "': " .. tostring(error_msg))
  end
end

-- Write or remove point for a lane
function PakettiAutomationStack_WritePoint(automation_index, line, value, remove)
  local song, patt, ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt or not ptrack then return end
  local entry = PakettiAutomationStack_automations[automation_index]; if not entry then return end
  
  -- Clamp line to valid pattern range for automation writing
  local num_lines = patt.number_of_lines
  line = math.max(1, math.min(num_lines, line))
  
  local a = entry.automation
  
  -- If no automation exists yet, create it by adding the first point
  if not a and not remove then
    -- Use the stored pattern_track if available, otherwise use current ptrack
    local target_ptrack = entry.pattern_track or ptrack
    -- Adding a point automatically creates the automation envelope in Renoise
    -- We need to get the automation after creating the first point
    local param = entry.parameter
    if param and param.is_automatable then
      -- Create automation by adding first point - this automatically creates the envelope
      local desired = PakettiAutomationStack_PlaymodeForIndex(PakettiAutomationStack_draw_playmode_index)
      
      -- The tricky part: we need to create automation first
      -- In Renoise, automation is created when you add the first point
      -- But we need the automation object to set playmode
      
      -- Create automation envelope if it doesn't exist
      if not target_ptrack:find_automation(param) then
        -- Create the automation envelope for this parameter
        a = target_ptrack:create_automation(param)
        if a then
          entry.automation = a -- Store it back in the entry for next time
          a.playmode = desired
        end
      else
        -- Get existing automation
        a = target_ptrack:find_automation(param)
        if a then
          entry.automation = a -- Store it back in the entry for next time
          a.playmode = desired
        end
      end
    end
    
    if not a then return end -- Still couldn't create automation
  elseif not a then
    return -- Can't remove from non-existent automation
  end
  
  -- Only set playmode for new automation, don't change existing automation's mode
  -- This preserves the original automation mode (curves stay curves, lines stay lines)
  if not entry.automation then
    local desired = PakettiAutomationStack_PlaymodeForIndex(PakettiAutomationStack_draw_playmode_index)
    a.playmode = desired
  end
  
  if remove then
    if a:has_point_at(line) then a:remove_point_at(line) end
  else
    -- Normalize already 0..1
    if a:has_point_at(line) then a:remove_point_at(line) end
    a:add_point_at(line, value)
  end
end

-- Mouse handler per lane
function PakettiAutomationStack_LaneMouse(automation_index, ev, lane_h)
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
  local num_lines = patt.number_of_lines
  local x = ev.position.x
  local y = ev.position.y
  local line = PakettiAutomationStack_XToLine(x, num_lines)
  local value = PakettiAutomationStack_YToValue(y, lane_h)
  local mods = tostring(ev.modifiers or "")
  local is_alt = (string.find(mods:lower(), "alt", 1, true) ~= nil) or (string.find(mods:lower(), "option", 1, true) ~= nil)

  if ev.type == "down" and ev.button == "left" then
    -- Check if click is on the label area (top 14 pixels)
    if y <= 14 then
      local entry = PakettiAutomationStack_automations[automation_index]
      if entry and entry.track_index then
        PakettiAutomationStack_ToggleTrackMute(entry.track_index)
        -- Also show the automation envelope for this parameter
        PakettiAutomationStack_ShowAutomationEnvelope(entry)
        PakettiAutomationStack_RequestUpdate()
        return
      end
    end
    local is_shift = (string.find(mods:lower(), "shift", 1, true) ~= nil)
    if is_shift then
      PakettiAutomationStack_selection_active = true
      PakettiAutomationStack_selection_start_line = line
      PakettiAutomationStack_selection_end_line = line
      PakettiAutomationStack_selection_lane_index = automation_index
      PakettiAutomationStack_last_draw_value = value
      PakettiAutomationStack_RequestUpdate()
      return
    end
    PakettiAutomationStack_is_drawing = true
    PakettiAutomationStack_last_draw_line = line
    PakettiAutomationStack_last_draw_idx = automation_index
    PakettiAutomationStack_last_draw_value = value
    
    -- Show automation envelope in lower frame for visual feedback
    local entry = PakettiAutomationStack_automations[automation_index]
    if entry then
      PakettiAutomationStack_ShowAutomationEnvelope(entry)
    end
    
    PakettiAutomationStack_WritePoint(automation_index, line, value, is_alt)
    PakettiAutomationStack_RequestUpdate()
  elseif ev.type == "down" and ev.button == "right" then
    -- Right-click: clear all points in this automation lane
    local entry = PakettiAutomationStack_automations[automation_index]
    if entry and entry.automation then
      local a = entry.automation
      if a.points and #a.points > 0 then
        -- Remove from end to start to avoid index shifts
        for i = #a.points, 1, -1 do
          local pt = a.points[i]
          if pt and pt.time then
            local L = math.floor(pt.time)
            if L < 1 then L = 1 end
            a:remove_point_at(L)
          end
        end
        PakettiAutomationStack_RequestUpdate()
      end
    end
  elseif ev.type == "move" then
    local is_shift = (string.find(mods:lower(), "shift", 1, true) ~= nil)
    if PakettiAutomationStack_selection_active and PakettiAutomationStack_selection_lane_index == automation_index and is_shift then
      PakettiAutomationStack_selection_end_line = line
      PakettiAutomationStack_RequestUpdate()
      return
    end
    if PakettiAutomationStack_is_drawing and PakettiAutomationStack_last_draw_idx == automation_index then
      if line ~= PakettiAutomationStack_last_draw_line or math.abs(value - PakettiAutomationStack_last_draw_value) >= 0.001 then
        -- Continuous draw: write point on the current line and interpolate if we skipped lines
        local start_l = PakettiAutomationStack_last_draw_line
        local end_l = line
        if start_l and end_l then
          local step = (end_l >= start_l) and 1 or -1
          local count = math.abs(end_l - start_l)
          if count <= 1 then
            PakettiAutomationStack_WritePoint(automation_index, line, value, is_alt)
          else
            -- interpolate values across lines
            for L = start_l, end_l, step do
              local t = (count > 0) and (math.abs(L - start_l) / count) or 1.0
              local v = PakettiAutomationStack_last_draw_value + (value - PakettiAutomationStack_last_draw_value) * t
              PakettiAutomationStack_WritePoint(automation_index, L, v, is_alt)
            end
          end
        end
        PakettiAutomationStack_last_draw_line = line
        PakettiAutomationStack_last_draw_value = value
        PakettiAutomationStack_RequestUpdate()
      end
    end
  elseif ev.type == "up" and ev.button == "left" then
    PakettiAutomationStack_is_drawing = false
    PakettiAutomationStack_last_draw_idx = -1
    PakettiAutomationStack_RequestUpdate()
  end
end

-- Render a single automation lane
function PakettiAutomationStack_RenderLaneCanvas(automation_index, canvas_w, canvas_h)
  return function(ctx)
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    local W = canvas_w or PakettiAutomationStack_canvas_width
    local H = canvas_h or PakettiAutomationStack_lane_height
    ctx:clear_rect(0, 0, W, H)
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local lpb = song.transport.lpb

    PakettiAutomationStack_DrawGrid(ctx, W, H, num_lines, lpb)

    local entry = PakettiAutomationStack_automations[automation_index]
    if not entry then return end
    
    -- Handle case where automation doesn't exist yet (empty lane ready for drawing)

    -- Label block with track, device and parameter formatted as "TRACKXX: DEVICE: PARAMETER"
    local label
    if PakettiAutomationStack_arbitrary_mode and entry.track_index then
      label = string.format("Track%02d: %s: %s", 
        entry.track_index, (entry.device_name or "DEVICE"), (entry.name or "PARAM"))
    else
      label = string.format("%s: %s", (entry.device_name or "DEVICE"), (entry.name or "PARAM"))
    end
    
    -- Get track color for label background
    local track_idx = entry.track_index or song.selected_track_index
    local track_color = PakettiAutomationStack_TrackColorToCanvas(track_idx, 150, 0.3)
    local track_border = PakettiAutomationStack_TrackColorToCanvas(track_idx, 255, 0.8)
    
    -- Draw colored background with track color
    ctx.fill_color = track_color
    ctx:begin_path(); ctx:rect(2, 2, W - 4, 12); ctx:fill()
    
    -- Draw colored border
    ctx.stroke_color = track_border
    ctx.line_width = 1
    ctx:begin_path(); ctx:rect(2, 2, W - 4, 12); ctx:stroke()
    
    -- Add mute indicator if track is muted
    local is_muted = PakettiAutomationStack_IsTrackMuted(track_idx)
    local mute_suffix = is_muted and " (MUTED - CLICK TO UNMUTE)" or ""
    
    -- Draw text with high contrast color or dimmed if muted
    if is_muted then
      ctx.stroke_color = {150, 150, 150, 255} -- Dimmed text for muted tracks
    else
      ctx.stroke_color = {255, 255, 255, 255}
    end
    PakettiAutomationStack_DrawText(ctx, string.upper(label .. mute_suffix), 6, 4, 8)

    local a = entry.automation
    local points = (a and a.points) or {}
    local mode = (a and a.playmode) or renoise.PatternTrackAutomation.PLAYMODE_LINES
    local gutter = PakettiAutomationStack_gutter_width

    -- Draw zero-line reference
    ctx.stroke_color = {80,80,100,200}
    ctx.line_width = 1
    local start_x = (gutter > 0) and gutter or 0
    local end_x = (gutter > 0) and (W - gutter) or W
    ctx:begin_path(); ctx:move_to(start_x, PakettiAutomationStack_ValueToY(0.5, H)); ctx:line_to(end_x, PakettiAutomationStack_ValueToY(0.5, H)); ctx:stroke()

    if #points == 0 then
      -- Empty lane - show as ready for drawing with a subtle indicator
      local track_idx = entry.track_index or song.selected_track_index
      local dim_color = PakettiAutomationStack_TrackColorToCanvas(track_idx, 60, 0.5)
      ctx.stroke_color = dim_color
      ctx.line_width = 1
      -- Draw dotted line to indicate this is a drawable empty lane
      local step = 20
      local start_x = (gutter > 0) and gutter or 0
      local end_x = (gutter > 0) and (W - gutter) or W
      for x = start_x, end_x, step do
        ctx:begin_path()
        ctx:move_to(x, PakettiAutomationStack_ValueToY(0.5, H))
        ctx:line_to(math.min(x + 10, end_x), PakettiAutomationStack_ValueToY(0.5, H))
        ctx:stroke()
      end
      return
    end

    -- Get track-based colors
    local track_idx = entry.track_index or song.selected_track_index
    local base_color, bright_color, dim_color = PakettiAutomationStack_GetTrackAutomationColors(track_idx)

    if mode == renoise.PatternTrackAutomation.PLAYMODE_POINTS then
      -- Vertical bars with dots at values
      ctx.stroke_color = base_color
      ctx.line_width = 2
      for i = 1, #points do
        local p = points[i]
        local x = PakettiAutomationStack_MapTimeToX((p.time or 1) - 1, num_lines)
        local y = PakettiAutomationStack_ValueToY(p.value, H)
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
        ctx:begin_path(); ctx:move_to(x, H-1); ctx:line_to(x, y); ctx:stroke()
        -- round marker
        ctx.stroke_color = bright_color
        ctx.line_width = 2
        ctx:begin_path(); ctx:move_to(x-1, y); ctx:line_to(x+1, y); ctx:stroke()
        ctx.stroke_color = base_color; ctx.line_width = 2
      end
    elseif mode == renoise.PatternTrackAutomation.PLAYMODE_LINES then
      -- Linear segments between points
      ctx.stroke_color = base_color
      ctx.line_width = 3
      ctx:begin_path()
      local p1 = points[1]
      local x1 = PakettiAutomationStack_MapTimeToX((p1.time or 1) - 1, num_lines)
      local y1 = PakettiAutomationStack_ValueToY(p1.value, H)
      if x1 < gutter then x1 = gutter end
      if x1 > W - gutter then x1 = W - gutter end
      ctx:move_to(x1, y1)
      for i = 2, #points do
        local p = points[i]
        local x = PakettiAutomationStack_MapTimeToX((p.time or 1) - 1, num_lines)
        local y = PakettiAutomationStack_ValueToY(p.value, H)
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
        ctx:line_to(x, y)
      end
      ctx:stroke()
      -- small point markers
      ctx.stroke_color = bright_color
      ctx.line_width = 2
      for i = 1, #points do
        local p = points[i]
        local x = PakettiAutomationStack_MapTimeToX((p.time or 1) - 1, num_lines)
        local y = PakettiAutomationStack_ValueToY(p.value, H)
        if x < gutter then x = gutter end
        if x > W - gutter then x = W - gutter end
        ctx:begin_path(); ctx:move_to(x-1, y); ctx:line_to(x+1, y); ctx:stroke()
      end
    else
      -- Curves: smooth by Catmull-Rom / Hermite sampling between points
      ctx.stroke_color = base_color
      ctx.line_width = 3
      for seg = 1, (#points - 1) do
        local p0 = points[math.max(1, seg-1)]
        local p1c = points[seg]
        local p2 = points[seg+1]
        local p3 = points[math.min(#points, seg+2)]
        local x1 = PakettiAutomationStack_MapTimeToX((p1c.time or 1) - 1, num_lines)
        local y1 = PakettiAutomationStack_ValueToY(p1c.value, H)
        local x2 = PakettiAutomationStack_MapTimeToX((p2.time or 1) - 1, num_lines)
        local y2 = PakettiAutomationStack_ValueToY(p2.value, H)
        if x2 <= x1 then x2 = x1 + 1 end
        local steps = math.max(8, math.floor((x2 - x1) / 6))
        local function hermite(t, y_0, y_1, y_2, y_3)
          local m1 = 0.5 * (y_2 - y_0)
          local m2 = 0.5 * (y_3 - y_1)
          local t2 = t * t
          local t3 = t2 * t
          local h00 = 2*t3 - 3*t2 + 1
          local h10 = t3 - 2*t2 + t
          local h01 = -2*t3 + 3*t2
          local h11 = t3 - t2
          return h00*y_1 + h10*m1 + h01*y_2 + h11*m2
        end
        ctx:begin_path()
        for s = 0, steps do
          local t = s / steps
          local x = x1 + (x2 - x1) * t
          local y = hermite(t, PakettiAutomationStack_ValueToY(p0.value, H), y1, y2, PakettiAutomationStack_ValueToY(p3.value, H))
          if s == 0 then ctx:move_to(x, y) else ctx:line_to(x, y) end
        end
        ctx:stroke()
      end
    end
  end
end

-- Header canvas renderer (timeline + playhead) and click-to-jump
function PakettiAutomationStack_RenderHeaderCanvas(canvas_w, canvas_h)
  local function on_mouse(ev)
    if not ev or ev.type ~= "down" then return end
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
    local x = ev.position.x
    local num_lines = patt.number_of_lines
    local target_line = PakettiAutomationStack_XToLine(x, num_lines)
    if target_line < 1 then target_line = 1 end
    if target_line > num_lines then target_line = num_lines end
    song.selected_line_index = target_line
    song.transport:start_at{sequence = renoise.song().selected_sequence_index, line = target_line}
  end
  return function(ctx)
    local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
    local W = canvas_w or PakettiAutomationStack_canvas_width
    local H = canvas_h or (PakettiAutomationStack_gutter_height + 4)
    ctx:clear_rect(0, 0, W, H)
    if not song or not patt then return end
    local num_lines = patt.number_of_lines
    local win = PakettiAutomationStack_GetWindowLines(num_lines)
    local view_start = PakettiAutomationStack_view_start_line
    local view_end = math.min(num_lines, view_start + win - 1)
    local lpb = song.transport.lpb
    local gutter = PakettiAutomationStack_gutter_width
    -- background and gutters
    ctx:set_fill_linear_gradient(0, 0, 0, H)
    ctx:add_fill_color_stop(0, {22,22,30,255})
    ctx:add_fill_color_stop(1, {12,12,20,255})
    ctx:begin_path(); ctx:rect(0,0,W,H); ctx:fill()
    -- gutters (only if gutter_width > 0)
    if gutter > 0 then
      ctx.fill_color = {18,18,24,255}; ctx:fill_rect(0, 0, gutter, H)
      ctx.fill_color = {14,14,20,255}; ctx:fill_rect(W - gutter, 0, gutter, H)
    end
    -- Grid ticks and row labels along the header timeline
    local row_label_size = 7
    local eff_w = math.max(1, W - (2*PakettiAutomationStack_gutter_width))
    local pixels_per_line = eff_w / win
    -- Use smaller step size when zoomed in enough to show individual lines
    local step = (pixels_per_line >= 12) and 1 or ((lpb >= 2) and lpb or 1)
    
    for line = view_start, view_end, step do
      local x = PakettiAutomationStack_LineToX(line, num_lines)
      -- tick
      ctx.stroke_color = {90,90,120,255}
      ctx:begin_path(); ctx:move_to(x, 0); ctx:line_to(x, H); ctx:stroke()
      
      -- Smart row labeling: every 4th line when > 32 lines, otherwise every line
      local should_show_label = true
      if num_lines > 32 then
        -- Only show labels on "Grey Lines" (every 4th line: 1, 5, 9, 13, etc.)
        should_show_label = ((line - 1) % 4 == 0)
      end
      
      if should_show_label then
        -- label above the tick - show full range without artificial 100-limit
        local label = string.format("%03d", (line - 1))  -- Convert 1-based internal to 0-based visual display
        -- Set bright white color for better visibility
        ctx.stroke_color = {255,255,255,255}
        PakettiAutomationStack_DrawText(ctx, label, x + 2, 2, row_label_size)
        -- Restore original color for tick marks
        ctx.stroke_color = {90,90,120,255}
      end
    end
    -- playhead
    local x_play = nil
    local play_line = nil
    if song.transport.playing then
      local pos = song.transport.playback_pos
      if pos and pos.sequence and pos.line and pos.sequence == renoise.song().selected_sequence_index then
        play_line = pos.line
      end
    else
      play_line = song.selected_line_index
    end
    if play_line then x_play = PakettiAutomationStack_LineToX(play_line, num_lines) end
    if x_play then
      ctx.stroke_color = {255,200,120,255}; ctx.line_width = 3
      -- FAT PINK LINE at the absolute leftmost drawable position
      local start_x = (gutter > 0) and gutter or 0
      ctx:begin_path(); ctx:move_to(start_x, 0); ctx:line_to(start_x, H); ctx:stroke()
      -- Also draw the timeline position indicator
      ctx.line_width = 2
      ctx:begin_path(); ctx:move_to(x_play, 0); ctx:line_to(x_play, H); ctx:stroke()
    end
  end, on_mouse
end

-- Build canvases for current page of automations
function PakettiAutomationStack_RebuildCanvases()
  if not PakettiAutomationStack_container then return end
  -- Remove existing children
  if PakettiAutomationStack_container.views then
    while #PakettiAutomationStack_container.views > 0 do
      PakettiAutomationStack_container:remove_child(PakettiAutomationStack_container.views[1])
    end
  end
  PakettiAutomationStack_track_canvases = {}

  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack(); if not song or not patt then return end
  local total = #PakettiAutomationStack_automations

  if PakettiAutomationStack_view_mode == 2 then
    -- Single view: one tall canvas + selection popup and buttons row
    local cw = PakettiAutomationStack_canvas_width
    local ch = PakettiAutomationStack_single_canvas_height
    local single_canvas = PakettiAutomationStack_vb:canvas{
      width = cw,
      height = ch,
      mode = "plain",
      render = PakettiAutomationStack_RenderSingleCanvas(cw, ch),
      mouse_events = {"down","up","move"},
      mouse_handler = function(ev) PakettiAutomationStack_SingleMouse(ev, ch) end
    }
    PakettiAutomationStack_container:add_child(single_canvas)
    PakettiAutomationStack_track_canvases[#PakettiAutomationStack_track_canvases+1] = single_canvas

    -- Check if popup already exists, if so reuse it, otherwise create new one
    local popup_view
    if PakettiAutomationStack_vb.views.pas_env_popup then
      popup_view = PakettiAutomationStack_vb.views.pas_env_popup
      popup_view.items = {"(none)"}
      popup_view.value = PakettiAutomationStack_single_selected_index
      -- Note: Cannot reassign notifier to existing popup, it's already set during creation
    else
      popup_view = PakettiAutomationStack_vb:popup{ 
        id = "pas_env_popup", 
        items = {"(none)"}, 
        width = 400, 
        value = PakettiAutomationStack_single_selected_index, 
        notifier = function(val)
          PakettiAutomationStack_single_selected_index = val
          -- Show automation envelope for the selected parameter
          local entry = PakettiAutomationStack_automations[val]
          if entry then
            PakettiAutomationStack_ShowAutomationEnvelope(entry)
          end
          PakettiAutomationStack_RequestUpdate()
        end 
      }
    end
    
    local select_row = PakettiAutomationStack_vb:row{
      PakettiAutomationStack_vb:text{ text = "Envelope:" },
      popup_view,
      PakettiAutomationStack_vb:button{ text = "Copy", notifier = function() PakettiAutomationStack_CopySelectedEnvelope() end },
      PakettiAutomationStack_vb:button{ text = "Paste", notifier = function() PakettiAutomationStack_PasteIntoSelectedEnvelope() end }
    }
    PakettiAutomationStack_container:add_child(select_row)
    PakettiAutomationStack_env_popup_view = PakettiAutomationStack_vb.views.pas_env_popup
    PakettiAutomationStack_UpdateEnvPopup()
  else
    -- Stack view: paged lanes
    local start_idx = ((PakettiAutomationStack_vertical_page_index - 1) * PakettiAutomationStack_vertical_page_size) + 1
    if start_idx < 1 then start_idx = 1 end
    if start_idx > total then start_idx = math.max(1, total - PakettiAutomationStack_vertical_page_size + 1) end
    local end_idx = math.min(total, start_idx + PakettiAutomationStack_vertical_page_size - 1)

    for i = start_idx, end_idx do
      local cw = PakettiAutomationStack_canvas_width
      local ch = PakettiAutomationStack_lane_height
      local idx_for_canvas = i
      local c = PakettiAutomationStack_vb:canvas{
        width = cw,
        height = ch,
        mode = "plain",
        render = PakettiAutomationStack_RenderLaneCanvas(idx_for_canvas, cw, ch),
        mouse_events = {"down","up","move"},
        mouse_handler = function(ev) PakettiAutomationStack_LaneMouse(idx_for_canvas, ev, ch) end
      }
      PakettiAutomationStack_container:add_child(c)
      PakettiAutomationStack_track_canvases[#PakettiAutomationStack_track_canvases+1] = c
    end
  end

  -- Update vertical scrollbar bounds
  if PakettiAutomationStack_vscrollbar_view then
    local pages = math.max(1, math.ceil(total / PakettiAutomationStack_vertical_page_size))
    PakettiAutomationStack_vscrollbar_view.min = 1
    PakettiAutomationStack_vscrollbar_view.max = math.max(2, pages)
    if PakettiAutomationStack_vertical_page_index > pages then PakettiAutomationStack_vertical_page_index = pages end
    PakettiAutomationStack_vscrollbar_view.value = PakettiAutomationStack_vertical_page_index
  end
  if PakettiAutomationStack_count_text_view then
    PakettiAutomationStack_count_text_view.text = "(" .. tostring(total) .. ")"
  end
end

-- Create Arbitrary Parameters Selection Dialog
function PakettiAutomationStack_ShowParameterSelectionDialog()
  if PakettiAutomationStack_arbitrary_dialog and PakettiAutomationStack_arbitrary_dialog.visible then
    PakettiAutomationStack_arbitrary_dialog:close()
    return
  end
  
  PakettiAutomationStack_arbitrary_vb = renoise.ViewBuilder()
  PakettiAutomationStack_parameter_checkboxes = {}
  
  local all_params = PakettiAutomationStack_GetAllParameters()
  if #all_params == 0 then
    renoise.app():show_status("Automation Stack: No automatable parameters found")
    return
  end
  
  local rows = {}
  local current_track = -1
  local track_column = nil
  
  -- Add header row
  local header_row = PakettiAutomationStack_arbitrary_vb:row{
    PakettiAutomationStack_arbitrary_vb:text{ text = "Check parameters you want to display, then click APPLY:", font = "bold", style = "strong" },
  }
  
  local quick_buttons_row = PakettiAutomationStack_arbitrary_vb:row{
    PakettiAutomationStack_arbitrary_vb:button{ text = "Select All", width = 80, notifier = function()
      -- Select all
      for key, checkbox in pairs(PakettiAutomationStack_parameter_checkboxes) do
        checkbox.value = true
      end
      PakettiAutomationStack_UpdateParameterSelection()
    end },
    PakettiAutomationStack_arbitrary_vb:button{ text = "Select None", width = 80, notifier = function()
      -- Deselect all
      for key, checkbox in pairs(PakettiAutomationStack_parameter_checkboxes) do
        checkbox.value = false
      end
      PakettiAutomationStack_UpdateParameterSelection()
    end },
    PakettiAutomationStack_arbitrary_vb:space{ width = 20 },
    PakettiAutomationStack_arbitrary_vb:button{ 
      text = "APPLY - Show Selected Parameters", 
      width = 280, 
      height = 24,
      notifier = function()
        PakettiAutomationStack_UpdateParameterSelection()
        PakettiAutomationStack_SaveSelectedParameters()
        PakettiAutomationStack_arbitrary_mode = true
        PakettiAutomationStack_show_same_mode = false -- Clear show same mode
        
        -- Close the parameter selection dialog first
        PakettiAutomationStack_arbitrary_dialog:close()
        
        -- Ensure main automation stack dialog is open and updated
        if not PakettiAutomationStack_dialog or not PakettiAutomationStack_dialog.visible then
          -- Main dialog not visible, reopen it
          PakettiAutomationStack_ReopenDialog()
        else
          -- Main dialog is open, just update it
          PakettiAutomationStack_RebuildAutomations()
          PakettiAutomationStack_RebuildCanvases()
          PakettiAutomationStack_RequestUpdate()
        end
        
        renoise.app():show_status("Automation Stack: Showing " .. tostring(#PakettiAutomationStack_selected_parameters) .. " selected parameters from multiple tracks")
      end 
    }
  }
  rows[#rows+1] = header_row
  rows[#rows+1] = quick_buttons_row
  
  -- Group parameters by track and device
  local current_device_key = ""
  local device_params = {}
  local device_label_added = false
  
  -- Helper function to flush device parameters with their label
  local function flush_device_params()
    if #device_params > 0 then
      -- Add device label first
      if not device_label_added and device_params[1] then
        local device_label_row = PakettiAutomationStack_arbitrary_vb:row{
          PakettiAutomationStack_arbitrary_vb:space{ width = 30 },
          PakettiAutomationStack_arbitrary_vb:text{ 
            text = device_params[1].device_name .. ":", 
            font = "bold",
            width = 120
          }
        }
        rows[#rows+1] = device_label_row
      end
      
      -- Split parameters into rows of max 10 each
      local params_per_row = 10
      
      for start_idx = 1, #device_params, params_per_row do
        local end_idx = math.min(start_idx + params_per_row - 1, #device_params)
        local device_row_views = {
          PakettiAutomationStack_arbitrary_vb:space{ width = 20 }
        }
        
        -- Add checkboxes and labels for this chunk of parameters
        for j = start_idx, end_idx do
          local dp = device_params[j]
          device_row_views[#device_row_views+1] = dp.checkbox
          device_row_views[#device_row_views+1] = PakettiAutomationStack_arbitrary_vb:text{ 
            text = dp.param_name, width = 80
          }
          if j < end_idx then
            device_row_views[#device_row_views+1] = PakettiAutomationStack_arbitrary_vb:space{ width = 10 }
          end
        end
        
        local device_row = PakettiAutomationStack_arbitrary_vb:row{ views = device_row_views }
        rows[#rows+1] = device_row
      end
      
      device_params = {}
      device_label_added = false
    end
  end
  
  for i = 1, #all_params do
    local param = all_params[i]
    local device_key = param.track_index .. "_" .. param.device_index
    
    -- Add track separator if this is a new track
    if param.track_index ~= current_track then
      -- Flush any pending device params from previous track
      flush_device_params()
      
      current_track = param.track_index
      local track_sep = PakettiAutomationStack_arbitrary_vb:row{
        PakettiAutomationStack_arbitrary_vb:space{ width = 10 },
        PakettiAutomationStack_arbitrary_vb:text{ text = param.track_name, font = "bold", style = "strong" }
      }
      rows[#rows+1] = track_sep
      current_device_key = "" -- Reset device key for new track
    end
    
    -- If we're starting a new device, flush the previous device's parameters
    if device_key ~= current_device_key then
      flush_device_params()
      current_device_key = device_key
    end
    
    -- Create checkbox for this parameter
    local is_selected = PakettiAutomationStack_IsParameterSelected(
      param.track_index, param.device_index, param.param_index)
    
    local checkbox = PakettiAutomationStack_arbitrary_vb:checkbox{
      value = is_selected,
      notifier = function() PakettiAutomationStack_UpdateParameterSelection() end
    }
    
    PakettiAutomationStack_parameter_checkboxes[param.key] = checkbox
    
    -- Add to current device group
    device_params[#device_params+1] = {
      checkbox = checkbox,
      param_name = param.param_name,
      device_name = param.device_name
    }
  end
  
  -- Flush final device params
  flush_device_params()
  
  -- Add just a cancel button at the bottom for convenience
  local bottom_button_row = PakettiAutomationStack_arbitrary_vb:row{
    PakettiAutomationStack_arbitrary_vb:space{ width = 100 },
    PakettiAutomationStack_arbitrary_vb:button{ 
      text = "Cancel", 
      width = 100, 
      notifier = function()
        PakettiAutomationStack_arbitrary_dialog:close()
      end 
    }
  }
  rows[#rows+1] = bottom_button_row
  
  -- Create scrollable content
  local content_column = PakettiAutomationStack_arbitrary_vb:column{
    --spacing = 2,
    views = rows
  }
  
  local scrollable_content = content_column
  
  PakettiAutomationStack_arbitrary_dialog = renoise.app():show_custom_dialog(
    "Select Arbitrary Parameters", scrollable_content)
end

-- Update parameter selection from checkboxes
function PakettiAutomationStack_UpdateParameterSelection()
  -- Clear current selection
  PakettiAutomationStack_selected_parameters = {}
  
  -- Build new selection from checkboxes
  local all_params = PakettiAutomationStack_GetAllParameters()
  for i = 1, #all_params do
    local param = all_params[i]
    local checkbox = PakettiAutomationStack_parameter_checkboxes[param.key]
    if checkbox and checkbox.value then
      PakettiAutomationStack_AddParameter(
        param.track_index, param.device_index, param.param_index)
    end
  end
end

-- Update Show Same dropdown with available parameter names
function PakettiAutomationStack_UpdateShowSamePopup()
  if not PakettiAutomationStack_show_same_popup_view then return end
  
  local param_names = PakettiAutomationStack_GetUniqueAutomatedParameterNames()
  local items = {"(none)"}
  local selected_index = 1
  
  for i = 1, #param_names do
    items[#items+1] = param_names[i].display_name
    -- Check if this was the previously selected parameter
    if param_names[i].name == PakettiAutomationStack_selected_param_name then
      selected_index = #items
    end
  end
  
  PakettiAutomationStack_show_same_popup_view.items = items
  PakettiAutomationStack_show_same_popup_view.value = selected_index
end

-- Build the ViewBuilder content
function PakettiAutomationStack_BuildContent()
  local controls_row = PakettiAutomationStack_vb:row{
    PakettiAutomationStack_vb:switch{
      id = "pas_zoom_switch",
      items = {"Full","1/2","1/4","1/8"},
      width = 100,
      value = PakettiAutomationStack_zoom_index,
      notifier = function(val) PakettiAutomationStack_SetZoomIndex(val) end
    },
    PakettiAutomationStack_vb:text{ text = "Mode:" },
    PakettiAutomationStack_vb:switch{
      id = "pas_mode_switch",
      items = {"Points","Lines","Curves"},
      width = 150,
      value = PakettiAutomationStack_draw_playmode_index,
      notifier = function(val)
        PakettiAutomationStack_draw_playmode_index = val
        -- Apply immediately to visible envelopes
        for i = 1, #PakettiAutomationStack_automations do
          local e = PakettiAutomationStack_automations[i]
          if e and e.automation then e.automation.playmode = PakettiAutomationStack_PlaymodeForIndex(val) end
        end
        PakettiAutomationStack_RequestUpdate()
      end
    },
    PakettiAutomationStack_vb:text{ text = "View:" },
    PakettiAutomationStack_vb:switch{
      id = "pas_view_switch",
      items = {"Stack","Single"},
      width = 80,
      value = (PakettiAutomationStack_view_mode == 2) and 2 or 1,
      notifier = function(val)
        PakettiAutomationStack_view_mode = (val == 2) and 2 or 1
        PakettiAutomationStack_RebuildCanvases()
        PakettiAutomationStack_RequestUpdate()
      end
    },
    PakettiAutomationStack_vb:text{ text = "Show:" },
    PakettiAutomationStack_vb:switch{
      id = "pas_show_switch",
      items = {"8","16"},
      width = 70,
      value = PakettiAutomationStack_show_all_vertically and 2 or 1,
      notifier = function(val)
        PakettiAutomationStack_show_all_vertically = (val == 2)
        if val == 1 then
          PakettiAutomationStack_vertical_page_size = 8
        else
          PakettiAutomationStack_vertical_page_size = 16
        end
        PakettiAutomationStack_vertical_page_index = 1
        PakettiAutomationStack_RebuildCanvases()
        PakettiAutomationStack_RequestUpdate()
      end
    },
    PakettiAutomationStack_vb:text{ text = "Page:" },
    PakettiAutomationStack_vb:scrollbar{ id = "pas_vscroll", min = 1, max = 2, value = PakettiAutomationStack_vertical_page_index, step = 1, pagestep = 1, autohide = false, notifier = function(val)
      PakettiAutomationStack_vertical_page_index = val
      PakettiAutomationStack_RebuildCanvases()
      PakettiAutomationStack_RequestUpdate()
    end },
    PakettiAutomationStack_vb:text{ id = "pas_count_text", text = "(0)" },
    PakettiAutomationStack_vb:button{ 
      text = "Arbitrary Parameters", 
      width = 100, 
      notifier = function() PakettiAutomationStack_ShowParameterSelectionDialog() end 
    },
    PakettiAutomationStack_vb:button{ 
      text = "Current Track", 
      width = 80, 
      notifier = function() 
        PakettiAutomationStack_arbitrary_mode = false
        PakettiAutomationStack_show_same_mode = false
        PakettiAutomationStack_RebuildAutomations()
        PakettiAutomationStack_RebuildCanvases()
        PakettiAutomationStack_RequestUpdate()
        renoise.app():show_status("Automation Stack: Showing current track")
      end 
    },
    PakettiAutomationStack_vb:button{ text = "Refresh", width = 50, notifier = function() PakettiAutomationStack_ForceRefresh() end }
  }

  local show_same_row = PakettiAutomationStack_vb:row{
    PakettiAutomationStack_vb:text{ text = "Show Same:" },
    PakettiAutomationStack_vb:popup{ 
      id = "pas_show_same_popup", 
      items = {"(none)"}, 
      width = 300, 
      value = 1, 
      notifier = function(val)
        local param_names = PakettiAutomationStack_GetUniqueAutomatedParameterNames()
        if val == 1 then
          -- "(none)" selected
          PakettiAutomationStack_selected_param_name = ""
          PakettiAutomationStack_show_same_mode = false
        elseif val > 1 and val <= (#param_names + 1) then
          -- Parameter name selected
          local param_index = val - 1
          PakettiAutomationStack_selected_param_name = param_names[param_index].name
          PakettiAutomationStack_show_same_mode = true
          PakettiAutomationStack_arbitrary_mode = false
        end
        PakettiAutomationStack_RebuildAutomations()
        PakettiAutomationStack_RebuildCanvases()
        PakettiAutomationStack_RequestUpdate()
        if PakettiAutomationStack_show_same_mode then
          renoise.app():show_status("Automation Stack: Showing all '" .. PakettiAutomationStack_selected_param_name .. "' parameters")
        end
      end 
    },
    PakettiAutomationStack_vb:button{ 
      text = "Refresh List", 
      width = 100, 
      notifier = function() 
        PakettiAutomationStack_UpdateShowSamePopup()
        renoise.app():show_status("Automation Stack: Updated Show Same list")
      end 
    }
  }

  local header_row = PakettiAutomationStack_vb:row{ spacing = 0, PakettiAutomationStack_vb:canvas{ id = "pas_header_canvas", width = PakettiAutomationStack_canvas_width, height = PakettiAutomationStack_gutter_height + 6, mode = "plain", mouse_events = {"down"}, mouse_handler = function(ev)
      local _render, on_mouse = PakettiAutomationStack_RenderHeaderCanvas(PakettiAutomationStack_canvas_width, PakettiAutomationStack_gutter_height + 6)
      if on_mouse then on_mouse(ev) end
    end, render = (function()
      local render_func = PakettiAutomationStack_RenderHeaderCanvas(PakettiAutomationStack_canvas_width, PakettiAutomationStack_gutter_height + 6)
      return render_func
    end)() } }

  local tracks_col = PakettiAutomationStack_vb:column{ id = "pas_tracks_container", spacing = 0 }
  local bottom_row = PakettiAutomationStack_vb:row{
    PakettiAutomationStack_vb:text{ text = "Scroll:" }, PakettiAutomationStack_vb:space{ width = 10 },
    PakettiAutomationStack_vb:scrollbar{ id = "pas_hscroll", min = 1, max = 2, value = 1, step = 1, pagestep = 1, autohide = false, notifier = function(val)
      PakettiAutomationStack_view_start_line = val
      PakettiAutomationStack_UpdateScrollbars()
      PakettiAutomationStack_RequestUpdate()
    end }
  }

  local main_content = PakettiAutomationStack_vb:column{ controls_row, show_same_row, header_row, tracks_col, bottom_row }
  
  -- Wrap in a container with exact canvas width to match dialog to canvas
  return PakettiAutomationStack_vb:column{
    PakettiAutomationStack_vb:space{ width = PakettiAutomationStack_canvas_width, height = 1 },
    main_content
  }
end

-- Reopen / build dialog
function PakettiAutomationStack_ReopenDialog()
  if PakettiAutomationStack_dialog and PakettiAutomationStack_dialog.visible then PakettiAutomationStack_dialog:close() end
  PakettiAutomationStack_vb = renoise.ViewBuilder()
  local content = PakettiAutomationStack_BuildContent()
  PakettiAutomationStack_dialog = renoise.app():show_custom_dialog("Paketti Automation Stack", content, PakettiAutomationStack_KeyHandler)
  PakettiAutomationStack_header_canvas = PakettiAutomationStack_vb.views.pas_header_canvas
  PakettiAutomationStack_scrollbar_view = PakettiAutomationStack_vb.views.pas_hscroll
  PakettiAutomationStack_vscrollbar_view = PakettiAutomationStack_vb.views.pas_vscroll
  PakettiAutomationStack_container = PakettiAutomationStack_vb.views.pas_tracks_container
  PakettiAutomationStack_count_text_view = PakettiAutomationStack_vb.views.pas_count_text
  PakettiAutomationStack_show_same_popup_view = PakettiAutomationStack_vb.views.pas_show_same_popup
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Setup observables for auto-updating
  PakettiAutomationStack_SetupObservables()
  
  PakettiAutomationStack_RebuildAutomations()
  -- Initialize automation hashes for change detection
  PakettiAutomationStack_automation_hashes = PakettiAutomationStack_BuildIndividualHashes()
  -- Update Show Same dropdown with available parameters
  PakettiAutomationStack_UpdateShowSamePopup()
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RebuildCanvases()
  PakettiAutomationStack_RequestUpdate()
  if not PakettiAutomationStack_timer_running then renoise.tool():add_timer(PakettiAutomationStack_TimerTick, PakettiAutomationStack_timer_interval_ms); PakettiAutomationStack_timer_running = true end
end

-- Public entry
function PakettiAutomationStackShowDialog()
  if PakettiAutomationStack_dialog and PakettiAutomationStack_dialog.visible then
    PakettiAutomationStack_dialog:close()
    PakettiAutomationStack_Cleanup()
    return
  end
  local song, patt, _ptrack = PakettiAutomationStack_GetSongPatternTrack()
  if not song or not patt then
    renoise.app():show_status("Automation Stack: No song/pattern available")
    return
  end
  -- Load saved parameter selections
  PakettiAutomationStack_LoadSelectedParameters()
  PakettiAutomationStack_ReopenDialog()
end

-- Force refresh from UI button
function PakettiAutomationStack_ForceRefresh()
  PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_UpdateScrollbars()
  PakettiAutomationStack_RebuildCanvases()
  PakettiAutomationStack_RequestUpdate()
  renoise.app():show_status("Automation Stack: Refreshed")
end

-- Timer: detect changes and update
function PakettiAutomationStack_TimerTick()
  if not PakettiAutomationStack_dialog or not PakettiAutomationStack_dialog.visible then return end
  local hash = PakettiAutomationStack_BuildAutomationHash()
  if hash ~= PakettiAutomationStack_last_hash then
    PakettiAutomationStack_last_hash = hash
    -- Detect which specific automation changed for auto-selection
    PakettiAutomationStack_DetectChangedAutomation()
    PakettiAutomationStack_RebuildAutomations()
    PakettiAutomationStack_RebuildCanvases()
    PakettiAutomationStack_RequestUpdate()
  else
    -- Even if overall hash didn't change, check for individual automation changes
    PakettiAutomationStack_DetectChangedAutomation()
    PakettiAutomationStack_RequestUpdate()
  end
end

-- Setup observables for auto-updating
function PakettiAutomationStack_SetupObservables()
  PakettiAutomationStack_CleanupObservables() -- Clean up existing first
  
  local song = renoise.song()
  if not song then return end
  
  -- Track list observable (for when tracks are added/removed)
  if song.tracks_observable and not song.tracks_observable:has_notifier(PakettiAutomationStack_OnTracksChanged) then
    song.tracks_observable:add_notifier(PakettiAutomationStack_OnTracksChanged)
    PakettiAutomationStack_tracks_observable = song.tracks_observable
  end
  
  -- Individual track mute state observables
  for track_idx = 1, #song.tracks do
    local track = song.tracks[track_idx]
    if track and track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.mute_state_observable then
      if not track.mute_state_observable:has_notifier(PakettiAutomationStack_OnTrackMuteChanged) then
        track.mute_state_observable:add_notifier(PakettiAutomationStack_OnTrackMuteChanged)
        PakettiAutomationStack_track_observables[track_idx] = track.mute_state_observable
      end
    end
  end
end

-- Cleanup observables
function PakettiAutomationStack_CleanupObservables()
  -- Clean up tracks observable
  if PakettiAutomationStack_tracks_observable then
    if PakettiAutomationStack_tracks_observable:has_notifier(PakettiAutomationStack_OnTracksChanged) then
      PakettiAutomationStack_tracks_observable:remove_notifier(PakettiAutomationStack_OnTracksChanged)
    end
    PakettiAutomationStack_tracks_observable = nil
  end
  
  -- Clean up track mute observables
  for track_idx, observable in pairs(PakettiAutomationStack_track_observables) do
    if observable and observable:has_notifier(PakettiAutomationStack_OnTrackMuteChanged) then
      observable:remove_notifier(PakettiAutomationStack_OnTrackMuteChanged)
    end
  end
  PakettiAutomationStack_track_observables = {}
end

-- Observable callbacks
function PakettiAutomationStack_OnTracksChanged()
  if not PakettiAutomationStack_dialog or not PakettiAutomationStack_dialog.visible then return end
  
  -- Refresh track observables since tracks changed
  PakettiAutomationStack_SetupObservables()
  
  -- Force refresh the display
  PakettiAutomationStack_RebuildAutomations()
  PakettiAutomationStack_RebuildCanvases()
  PakettiAutomationStack_RequestUpdate()
  
  renoise.app():show_status("Automation Stack: Track list changed - updated display")
end

function PakettiAutomationStack_OnTrackMuteChanged()
  if not PakettiAutomationStack_dialog or not PakettiAutomationStack_dialog.visible then return end
  
  -- Just request a visual update since mute state changed
  PakettiAutomationStack_RequestUpdate()
end

-- Cleanup
function PakettiAutomationStack_Cleanup()
  if PakettiAutomationStack_timer_running then
    renoise.tool():remove_timer(PakettiAutomationStack_TimerTick)
    PakettiAutomationStack_timer_running = false
  end
  
  -- Cleanup observables
  PakettiAutomationStack_CleanupObservables()
  
  PakettiAutomationStack_dialog = nil
  PakettiAutomationStack_vb = nil
  PakettiAutomationStack_header_canvas = nil
  PakettiAutomationStack_container = nil
  PakettiAutomationStack_track_canvases = {}
  PakettiAutomationStack_scrollbar_view = nil
  PakettiAutomationStack_vscrollbar_view = nil
  PakettiAutomationStack_automation_hashes = {} -- Clear automation hashes
  -- Close arbitrary parameter dialog if open
  if PakettiAutomationStack_arbitrary_dialog and PakettiAutomationStack_arbitrary_dialog.visible then
    PakettiAutomationStack_arbitrary_dialog:close()
  end
  PakettiAutomationStack_arbitrary_dialog = nil
  PakettiAutomationStack_arbitrary_vb = nil
  PakettiAutomationStack_parameter_checkboxes = {}
  -- Reset Show Same state
  PakettiAutomationStack_show_same_popup_view = nil
end

-- Menu + Keybinding entries
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Automation Stack", invoke = function() PakettiAutomationStackShowDialog() end }
renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Automation Stack - Select Arbitrary Parameters", invoke = function() PakettiAutomationStack_ShowParameterSelectionDialog() end }
renoise.tool():add_menu_entry{ name = "Pattern Editor:Paketti:Automation:Automation Stack", invoke = function() PakettiAutomationStackShowDialog() end }
renoise.tool():add_menu_entry{ name = "Pattern Editor:Paketti:Automation:Automation Stack - Select Arbitrary Parameters", invoke = function() PakettiAutomationStack_ShowParameterSelectionDialog() end }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:Automation Stack...", invoke = function() PakettiAutomationStackShowDialog() end }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:Automation Stack - Select Arbitrary Parameters...", invoke = function() PakettiAutomationStack_ShowParameterSelectionDialog() end }



