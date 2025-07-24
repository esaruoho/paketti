function globalToggleVisibleColumnState(columnName)
  -- Get the current state of the specified column from the selected track
  local currentState = false
  local selected_track = renoise.song().selected_track

  if columnName == "delay" then
    currentState = selected_track.delay_column_visible
  elseif columnName == "volume" then
    currentState = selected_track.volume_column_visible
  elseif columnName == "panning" then
    currentState = selected_track.panning_column_visible
  elseif columnName == "sample_effects" then
    currentState = selected_track.sample_effects_column_visible
  else
    renoise.app():show_status("Invalid column name: " .. columnName)
    return
  end

  -- Toggle the state for all tracks of type 1
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 then
      if columnName == "delay" then
        renoise.song().tracks[i].delay_column_visible = not currentState
      elseif columnName == "volume" then
        renoise.song().tracks[i].volume_column_visible = not currentState
      elseif columnName == "panning" then
        renoise.song().tracks[i].panning_column_visible = not currentState
      elseif columnName == "sample_effects" then
        renoise.song().tracks[i].sample_effects_column_visible = not currentState
      end
    end
  end
end

function globalChangeVisibleColumnState(columnName,toggle)
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 and columnName == "delay" then
      renoise.song().tracks[i].delay_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "volume" then
      renoise.song().tracks[i].volume_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "panning" then
      renoise.song().tracks[i].panning_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "sample_effects" then
      renoise.song().tracks[i].sample_effects_column_visible = toggle
    else
      renoise.app():show_status("Invalid column name: " .. columnName)
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Volume)",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Panning)",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Delay)",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Sample Effects)",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
