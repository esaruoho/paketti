-- PakettiRandomizeEffect.lua
-- Issue #375: tool - randomized values of an fx command on chosen steps.
-- Over the highlighted pattern block, roll a new amount (00..FF) for each
-- effect-column cell. By default it only touches cells that already carry a
-- command (so it randomizes an existing fx), but it can also stamp a chosen
-- command onto every selected cell first.

local vb = renoise.ViewBuilder()
local dialog = nil

-- 2-char hex effect-number string, or nil for "keep whatever is there".
local function normalize_command(text)
  text = tostring(text or ""):gsub("%s", ""):upper()
  if text == "" then return nil end
  if #text == 1 then text = "0" .. text end
  if #text > 2 then text = text:sub(1, 2) end
  return text
end

function PakettiRandomizeEffectRun(min_amount, max_amount, only_existing, set_command)
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end

  local sel = song.selection_in_pattern
  if not sel then
    renoise.app():show_status("Randomize FX: make a selection in the Pattern Editor first")
    return
  end

  if min_amount > max_amount then
    min_amount, max_amount = max_amount, min_amount
  end
  min_amount = math.max(0, math.min(255, math.floor(min_amount)))
  max_amount = math.max(0, math.min(255, math.floor(max_amount)))

  local command = normalize_command(set_command)
  local pattern = song.selected_pattern
  local changed = 0

  for track_index = sel.start_track, sel.end_track do
    local track = song.tracks[track_index]
    -- Effect columns only exist on sequencer/master/send tracks.
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER
      or track.type == renoise.Track.TRACK_TYPE_MASTER
      or track.type == renoise.Track.TRACK_TYPE_SEND then
      local visible_fx = track.visible_effect_columns
      if visible_fx > 0 then
        local pattern_track = pattern:track(track_index)
        for line_index = sel.start_line, sel.end_line do
          local line = pattern_track:line(line_index)
          for fx = 1, visible_fx do
            local col = line.effect_columns[fx]
            if col then
              local has_command = col.number_value ~= 0
              if command then
                -- Stamp the chosen command onto every selected cell, then roll.
                col.number_string = command
                col.amount_value = math.random(min_amount, max_amount)
                changed = changed + 1
              elseif has_command or (not only_existing) then
                -- No command chosen: roll the amount. "Only existing" gates
                -- whether cells without a command are touched.
                col.amount_value = math.random(min_amount, max_amount)
                changed = changed + 1
              end
            end
          end
        end
      end
    end
  end

  renoise.app():show_status(string.format(
    "Randomize FX: rolled %d effect value%s (%02X..%02X)",
    changed, changed == 1 and "" or "s", min_amount, max_amount))
end

function PakettiRandomizeEffectShowDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  vb = renoise.ViewBuilder()
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

  local content = vb:column{
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
    vb:text{ text = "Randomize the effect amount on the highlighted steps.", font = "bold" },
    vb:row{
      vb:text{ text = "Min amount (00-FF)", width = 150 },
      vb:valuebox{ id = "randfx_min", min = 0, max = 255, value = 0, width = 80 }
    },
    vb:row{
      vb:text{ text = "Max amount (00-FF)", width = 150 },
      vb:valuebox{ id = "randfx_max", min = 0, max = 255, value = 255, width = 80 }
    },
    vb:row{
      vb:checkbox{ id = "randfx_existing", value = true },
      vb:text{ text = "Only cells that already have a command" }
    },
    vb:row{
      vb:text{ text = "Set command first (opt, e.g. 0S)", width = 200 },
      vb:textfield{ id = "randfx_command", text = "", width = 60 }
    },
    vb:row{
      vb:button{
        text = "Randomize",
        width = 120,
        notifier = function()
          PakettiRandomizeEffectRun(
            vb.views.randfx_min.value,
            vb.views.randfx_max.value,
            vb.views.randfx_existing.value,
            vb.views.randfx_command.text)
        end
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

  dialog = renoise.app():show_custom_dialog("Paketti Randomize FX Values", content)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Registrations -------------------------------------------------------------
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Pattern Editor:Randomize FX Values on Selection...",
  invoke = PakettiRandomizeEffectShowDialog
}
PakettiAddMenuEntry{
  name = "--Pattern Editor:Paketti:Randomize FX Values on Selection...",
  invoke = PakettiRandomizeEffectShowDialog
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Randomize FX Values on Selection",
  invoke = PakettiRandomizeEffectShowDialog
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Randomize FX Values on Selection [Trigger]",
  invoke = function(message)
    if message:is_trigger() then PakettiRandomizeEffectShowDialog() end
  end
}
