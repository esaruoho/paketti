-- PakettiDeviceCopyDialog.lua
-- Issue #322: Track DSP Device copying dialog.
-- Lists every track and its DSP devices with a checkbox each. Tick the source
-- devices you want, then use a target track's "-> Beginning" or "-> End"
-- button to copy the ticked devices into that track (with their full preset
-- state). Index 1 (the TrackVolPan mixer) is never listed or touched.

local vb = renoise.ViewBuilder()
local dialog = nil

local function is_dsp_track(track)
  return track.type == renoise.Track.TRACK_TYPE_SEQUENCER
    or track.type == renoise.Track.TRACK_TYPE_MASTER
    or track.type == renoise.Track.TRACK_TYPE_SEND
end

local function checkbox_id(track_index, device_index)
  return "devcopy_" .. track_index .. "_" .. device_index
end

-- Snapshot every ticked device (path + preset XML + state) BEFORE any insert,
-- so shifting indices during copying can't corrupt the source list.
local function collect_checked()
  local song = renoise.song()
  local snapshots = {}
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if is_dsp_track(track) then
      for device_index = 2, #track.devices do
        local id = checkbox_id(track_index, device_index)
        local view = vb.views[id]
        if view and view.value then
          local device = track.devices[device_index]
          table.insert(snapshots, {
            path = device.device_path,
            xml = device.active_preset_data,
            is_active = device.is_active,
            is_maximized = device.is_maximized,
            name = device.display_name
          })
        end
      end
    end
  end
  return snapshots
end

local function copy_snapshots_into(track_index, at_beginning)
  local song = renoise.song()
  local track = song.tracks[track_index]
  if not is_dsp_track(track) then
    renoise.app():show_status("Device Copy: target track has no DSP chain")
    return
  end

  local snapshots = collect_checked()
  if #snapshots == 0 then
    renoise.app():show_status("Device Copy: tick at least one device to copy")
    return
  end

  song:describe_undo("Paketti: Copy DSP Devices")

  local copied = 0
  for i = 1, #snapshots do
    local snap = snapshots[i]
    local insert_index
    if at_beginning then
      -- Keep the ticked order: first snapshot lands at slot 2, next at 3, ...
      insert_index = 2 + (i - 1)
    else
      insert_index = #track.devices + 1
    end

    local ok, new_device = pcall(function()
      return track:insert_device_at(snap.path, insert_index)
    end)
    if ok and new_device then
      if snap.xml and snap.xml ~= "" then
        pcall(function() new_device.active_preset_data = snap.xml end)
      end
      pcall(function() new_device.is_active = snap.is_active end)
      pcall(function() new_device.is_maximized = snap.is_maximized end)
      copied = copied + 1
    else
      print("Device Copy: failed to insert " .. tostring(snap.path)
        .. " into track " .. track_index)
    end
  end

  renoise.app():show_status(string.format(
    "Device Copy: copied %d device%s to %s of '%s'",
    copied, copied == 1 and "" or "s",
    at_beginning and "beginning" or "end", track.name))

  -- Rebuild so the newly-copied devices show up in the target's list.
  PakettiDeviceCopyShowDialog(true)
end

function PakettiDeviceCopyShowDialog(force_rebuild)
  if dialog and dialog.visible then
    if not force_rebuild then
      dialog:close()
      dialog = nil
      return
    end
    dialog:close()
    dialog = nil
  end

  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end

  vb = renoise.ViewBuilder()
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

  local track_columns = vb:column{ spacing = 6 }

  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if is_dsp_track(track) then
      local device_rows = vb:column{ spacing = 1 }
      local dsp_count = 0
      for device_index = 2, #track.devices do
        dsp_count = dsp_count + 1
        local device = track.devices[device_index]
        device_rows:add_child(vb:row{
          vb:checkbox{ id = checkbox_id(track_index, device_index), value = false },
          vb:text{ text = device.display_name }
        })
      end
      if dsp_count == 0 then
        device_rows:add_child(vb:text{ text = "  (no DSP devices)" })
      end

      local ti = track_index
      track_columns:add_child(vb:column{
        style = "group",
        margin = 4,
        vb:row{
          vb:text{ text = track.name, font = "bold", width = 220 },
          vb:button{
            text = "-> Beginning",
            width = 110,
            notifier = function() copy_snapshots_into(ti, true) end
          },
          vb:button{
            text = "-> End",
            width = 90,
            notifier = function() copy_snapshots_into(ti, false) end
          }
        },
        device_rows
      })
    end
  end

  local content = vb:column{
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
    vb:text{
      text = "Tick source devices, then use a track's Beginning/End button to copy them in.",
      font = "bold"
    },
    track_columns,
    vb:row{
      vb:button{
        text = "Refresh",
        width = 100,
        notifier = function() PakettiDeviceCopyShowDialog(true) end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if dialog and dialog.visible then dialog:close() end
          dialog = nil
        end
      }
    }
  }

  dialog = renoise.app():show_custom_dialog("Paketti Track DSP Device Copy", content)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Registrations -------------------------------------------------------------
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Mixer:Track DSP Device Copy Dialog...",
  invoke = function() PakettiDeviceCopyShowDialog() end
}
PakettiAddMenuEntry{
  name = "--Mixer:Paketti:Track DSP Device Copy Dialog...",
  invoke = function() PakettiDeviceCopyShowDialog() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Track DSP Device Copy Dialog",
  invoke = function() PakettiDeviceCopyShowDialog() end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Track DSP Device Copy Dialog [Trigger]",
  invoke = function(message)
    if message:is_trigger() then PakettiDeviceCopyShowDialog() end
  end
}
