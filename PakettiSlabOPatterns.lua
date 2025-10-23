-- PakettiSlabOPatterns.lua
-- Lua 5.1 implementation of "Paketti Slab'o'Patterns" dialog

-- Persistent config file path (same approach as PakettiAutocomplete caches)
PAKETTI_SLAB_CONFIG_PATH = renoise.tool().bundle_path .. "slab_o_patterns.txt"

-- Dialog/UI state
PakettiSlabOPatternsDialogRef = nil
PakettiSlabOPatternsVB = nil
PakettiSlabOPatternsRows = {}
PakettiSlabOPatternsSelectedIndex = 1
PakettiSlabOPatternsSectionName = ""
PakettiSlabOPatternsSectionTF = nil
PakettiSlabOPatternsAppendPresetToSectionName = false
PakettiSlabOPatternsAppendPresetCB = nil
PakettiSlabOPatternsActivePresetLabel = ""
PakettiSlabOPatternsSeedValues = {}
PakettiSlabOPatternsPresetAppend = false

-- Data model: list of entries stored as "beats" or "beats:lpb" strings
-- Format examples:
--   "4"     = 4 beats using current song LPB (e.g. at 4 LPB = 16 lines, at 8 LPB = 32 lines)
--   "4:8"   = 4 beats at 8 LPB = 32 lines (LPB will be written to pattern master track)
--   "7"     = 7 beats using current song LPB (e.g. at 4 LPB = 28 lines, at 5 LPB = 35 lines)
--   "3.5:4" = 3.5 beats at 4 LPB = 14 lines
-- This beats-based approach adapts to any LPB, so patterns maintain their rhythmic structure
PakettiSlabOPatternsValues = {}

-- Presets (labels used on buttons; values injected to rows)
-- Values are in format "beats" or "beats:lpb"
-- When LPB is specified, it will be written to the pattern's master track (ZL command)
PakettiSlabOPatternsPresets = {
  { label = "7/4 (7 beats)", values = { "7" } },
  { label = "5/4 (5 beats)", values = { "5" } },
  { label = "14/8", values = { "4", "3" } },
  { label = "15/8", values = { "4", "3.5" } },
  { label = "14/8 - 15/8", values = { "4", "3", "4", "3.5" } },
  { label = "14/8 - 15/8 - 15/8 - 14/8", values = { "4", "3", "4", "3.5", "4", "3.5", "4", "3" } },
  { label = "6/4 8/4", values = { "3", "3", "4", "4" } },
  { label = "8/4 6/4", values = { "4", "4", "3", "3" } }
}

function PakettiSlabOPatternsApplyPreset(preset_index)
  if not PakettiSlabOPatternsPresets[preset_index] then return end
  local pv = PakettiSlabOPatternsPresets[preset_index].values
  if PakettiSlabOPatternsPresetAppend then
    -- Append preset at end of current list
    for i = 1, #pv do
      table.insert(PakettiSlabOPatternsValues, pv[i])
    end
  else
    -- Overwrite list with preset
    PakettiSlabOPatternsValues = {}
    for i = 1, #pv do
      table.insert(PakettiSlabOPatternsValues, pv[i])
    end
  end
  -- Update seed from the newly applied preset so '+' duplicates it
  PakettiSlabOPatternsSeedValues = {}
  for i = 1, #PakettiSlabOPatternsValues do
    table.insert(PakettiSlabOPatternsSeedValues, PakettiSlabOPatternsValues[i])
  end
  PakettiSlabOPatternsActivePresetLabel = PakettiSlabOPatternsPresets[preset_index].label or ""
  if PakettiSlabOPatternsPresetAppend then
    PakettiSlabOPatternsSelectedIndex = #PakettiSlabOPatternsValues
  else
    PakettiSlabOPatternsSelectedIndex = 1
  end
  PakettiSlabOPatternsSave()
  PakettiSlabOPatternsRebuild()
end

-- Helpers: load/save config -------------------------------------------------

function PakettiSlabOPatternsLoad()
  PakettiSlabOPatternsValues = {}

  local f = io.open(PAKETTI_SLAB_CONFIG_PATH, "r")
  if f then
    for line in f:lines() do
      local v = tostring(line or "")
      if v ~= "" then
        table.insert(PakettiSlabOPatternsValues, v)
      end
    end
    f:close()
  end

  if #PakettiSlabOPatternsValues == 0 then
    -- default set: 4 beats
    table.insert(PakettiSlabOPatternsValues, "4")
  end

  -- Capture current configuration as seed for '+' duplication
  PakettiSlabOPatternsSeedValues = {}
  for i = 1, #PakettiSlabOPatternsValues do
    table.insert(PakettiSlabOPatternsSeedValues, PakettiSlabOPatternsValues[i])
  end

  if PakettiSlabOPatternsSelectedIndex < 1 then
    PakettiSlabOPatternsSelectedIndex = 1
  end
  if PakettiSlabOPatternsSelectedIndex > #PakettiSlabOPatternsValues then
    PakettiSlabOPatternsSelectedIndex = #PakettiSlabOPatternsValues
  end
end

function PakettiSlabOPatternsSave()
  local f = io.open(PAKETTI_SLAB_CONFIG_PATH, "w")
  if not f then return end
  for i = 1, #PakettiSlabOPatternsValues do
    f:write(tostring(PakettiSlabOPatternsValues[i]) .. "\n")
  end
  f:close()
end

-- Utility: parse value to beats and optional LPB
-- Format: "beats" or "beats:lpb" (e.g. "4" or "4:8")
-- Returns: beats, lpb (lpb is nil if not specified)
function PakettiSlabOPatternsParseEntry(v)
  if type(v) ~= "string" then
    return nil, nil
  end
  local trimmed = v:match("^%s*(.-)%s*$") or v
  
  -- Check for "beats:lpb" format
  local beats_str, lpb_str = trimmed:match("^([%d%.]+):([%d%.]+)$")
  if beats_str and lpb_str then
    local beats = tonumber(beats_str)
    local lpb = tonumber(lpb_str)
    if beats and lpb and beats > 0 and lpb > 0 then
      return beats, lpb
    end
  end
  
  -- Just "beats" format
  local beats = tonumber(trimmed)
  if beats and beats > 0 then
    return beats, nil
  end
  
  return nil, nil
end

-- Calculate lines from beats and LPB
function PakettiSlabOPatternsCalculateLines(beats, lpb)
  if not beats then return nil end
  if not lpb then
    -- Use current song LPB if not specified
    if renoise.song then
      local s = renoise.song()
      if s then
        lpb = s.transport.lpb
      else
        lpb = 4  -- fallback
      end
    else
      lpb = 4  -- fallback
    end
  end
  
  local lines = math.floor(beats * lpb + 0.5)  -- round to nearest
  if lines < 1 then lines = 1 end
  if lines > 512 then lines = 512 end
  return lines
end

-- Add/remove rows -----------------------------------------------------------

function PakettiSlabOPatternsAddRow()
  -- Add a fresh entry with default 4 beats
  table.insert(PakettiSlabOPatternsValues, "4")
  PakettiSlabOPatternsSelectedIndex = #PakettiSlabOPatternsValues
  PakettiSlabOPatternsSave()
  PakettiSlabOPatternsRebuild()
end

function PakettiSlabOPatternsRemoveRow()
  if #PakettiSlabOPatternsValues > 1 then
    table.remove(PakettiSlabOPatternsValues, #PakettiSlabOPatternsValues)
    if PakettiSlabOPatternsSelectedIndex > #PakettiSlabOPatternsValues then
      PakettiSlabOPatternsSelectedIndex = #PakettiSlabOPatternsValues
    end
    PakettiSlabOPatternsSave()
    PakettiSlabOPatternsRebuild()
  else
    -- Single slot: wipe to fresh default
    PakettiSlabOPatternsValues[1] = "4"
    PakettiSlabOPatternsSelectedIndex = 1
    PakettiSlabOPatternsSave()
    -- Update UI minimally
    if PakettiSlabOPatternsRows[1] then
      PakettiSlabOPatternsUpdateRowLabels(1)
      PakettiSlabOPatternsRefreshRowColors()
    else
      PakettiSlabOPatternsRebuild()
    end
    renoise.app():show_status("Cleared the only slot to '4' beats")
  end
end

-- Clear all to single fresh slot
function PakettiSlabOPatternsClear()
  PakettiSlabOPatternsValues = { "4" }
  PakettiSlabOPatternsSelectedIndex = 1
  PakettiSlabOPatternsActivePresetLabel = ""
  PakettiSlabOPatternsSeedValues = { "4" }
  PakettiSlabOPatternsSave()
  PakettiSlabOPatternsRebuild()
  renoise.app():show_status("Cleared: reset to single '4' beats slot")
end

-- Create patterns -----------------------------------------------------------

function PakettiSlabOPatternsCreate()
  if not renoise.song then return end
  local s = renoise.song()
  if not s then return end

  local insert_at = s.selected_sequence_index + 1
  local created = 0
  local first_created_seq_index = insert_at
  local created_lengths = {}
  local master_track = s:track(s.sequencer_track_count + 1)

  for i = 1, #PakettiSlabOPatternsValues do
    local v = PakettiSlabOPatternsValues[i]
    local beats, entry_lpb = PakettiSlabOPatternsParseEntry(v)
    
    if not beats then
      renoise.app():show_status("Invalid slab value: " .. tostring(v))
      return
    end

    local lines = PakettiSlabOPatternsCalculateLines(beats, entry_lpb)
    if not lines then
      renoise.app():show_status("Could not calculate lines for: " .. tostring(v))
      return
    end

    -- Insert unique new pattern after the current one
    s.sequencer:insert_new_pattern_at(insert_at)
    local pat_index = s.sequencer.pattern_sequence[insert_at]
    local pat = s.patterns[pat_index]
    if pat then
      pat.number_of_lines = lines
      
      -- Write LPB to master track at line 1 if LPB is specified
      if entry_lpb and master_track then
        local line = pat:track(master_track.index):line(1)
        if line and line.effect_columns[1] then
          line.effect_columns[1].number_string = "ZL"
          line.effect_columns[1].amount_value = math.floor(entry_lpb)
        end
      end
    end
    table.insert(created_lengths, lines)
    insert_at = insert_at + 1
    created = created + 1
  end

  -- Optional section creation
  local section_name = tostring(PakettiSlabOPatternsSectionName or "")
  if section_name ~= "" then
    s.sequencer:set_sequence_is_start_of_section(first_created_seq_index, true)
    s.sequencer:set_sequence_section_name(first_created_seq_index, section_name)
  end

  -- Go to first created pattern
  if created > 0 then
    s.selected_sequence_index = first_created_seq_index
  end

  local lengths_text = ""
  for i = 1, #created_lengths do
    lengths_text = lengths_text .. tostring(created_lengths[i])
    if i < #created_lengths then lengths_text = lengths_text .. ", " end
  end
  local preset_part = (PakettiSlabOPatternsActivePresetLabel ~= "" and (" (" .. PakettiSlabOPatternsActivePresetLabel .. ")") or "")
  local section_part = (section_name ~= "" and (" - Section Name: '" .. section_name .. "'") or "")

  renoise.app():show_status("Added " .. tostring(created) .. " pattern(s) with line counts: " .. lengths_text .. preset_part .. section_part)
end

-- Selection and typing ------------------------------------------------------

function PakettiSlabOPatternsMoveSelection(delta)
  if #PakettiSlabOPatternsValues == 0 then return end
  PakettiSlabOPatternsSelectedIndex = PakettiSlabOPatternsSelectedIndex + delta
  if PakettiSlabOPatternsSelectedIndex < 1 then
    PakettiSlabOPatternsSelectedIndex = #PakettiSlabOPatternsValues
  elseif PakettiSlabOPatternsSelectedIndex > #PakettiSlabOPatternsValues then
    PakettiSlabOPatternsSelectedIndex = 1
  end
  PakettiSlabOPatternsRefreshRowColors()
end

function PakettiSlabOPatternsAppendChar(ch)
  if #PakettiSlabOPatternsValues == 0 then return end
  local idx = PakettiSlabOPatternsSelectedIndex
  if idx < 1 then idx = 1 PakettiSlabOPatternsSelectedIndex = 1 end
  local cur = tostring(PakettiSlabOPatternsValues[idx] or "")
  
  -- Allow digits, decimal point, and colon for "beats:lpb" format
  if not ch:match("[0-9%.:]") then
    return nil
  end
  
  -- Don't allow multiple colons
  if ch == ":" and cur:find(":") then
    renoise.app():show_status("Only one colon allowed (format: beats:lpb)")
    return nil
  end
  
  -- Don't allow multiple decimal points in same section
  local before_colon, after_colon = cur:match("^([^:]*):?(.*)$")
  if ch == "." then
    if not cur:find(":") and before_colon:find("%.") then
      renoise.app():show_status("Only one decimal point per number")
      return nil
    elseif cur:find(":") and after_colon:find("%.") then
      renoise.app():show_status("Only one decimal point per number")
      return nil
    end
  end
  
  PakettiSlabOPatternsValues[idx] = cur .. ch
  PakettiSlabOPatternsUpdateRowLabels(idx)
end

function PakettiSlabOPatternsBackspace()
  if #PakettiSlabOPatternsValues == 0 then return end
  local idx = PakettiSlabOPatternsSelectedIndex
  if idx < 1 then idx = 1 PakettiSlabOPatternsSelectedIndex = 1 end
  local cur = tostring(PakettiSlabOPatternsValues[idx] or "")
  if #cur > 0 then
    cur = string.sub(cur, 1, #cur - 1)
  end
  PakettiSlabOPatternsValues[idx] = cur
  PakettiSlabOPatternsUpdateRowLabels(idx)
end

-- UI building ---------------------------------------------------------------

function PakettiSlabOPatternsRefreshRowColors()
  for i = 1, #PakettiSlabOPatternsRows do
    local row = PakettiSlabOPatternsRows[i]
    if row and row.sel then
      if i == PakettiSlabOPatternsSelectedIndex then
        row.sel.color = {0x80, 0x00, 0x80}
      else
        row.sel.color = {0x00, 0x00, 0x00}
      end
    end
  end
end

function PakettiSlabOPatternsUpdateRowLabels(idx)
  local row = PakettiSlabOPatternsRows[idx]
  if not row then return end
  local val = tostring(PakettiSlabOPatternsValues[idx] or "")
  local beats, lpb = PakettiSlabOPatternsParseEntry(val)
  local lines = PakettiSlabOPatternsCalculateLines(beats, lpb) or 0
  
  -- Get actual LPB that will be used (specified or current)
  local display_lpb = lpb
  if not display_lpb then
    if renoise.song then
      local s = renoise.song()
      if s then
        display_lpb = s.transport.lpb
      else
        display_lpb = 4
      end
    else
      display_lpb = 4
    end
  end
  
  if row.val then row.val.text = val end
  if row.lpb_label then row.lpb_label.text = tostring(display_lpb) end
  if row.dec then row.dec.text = tostring(lines) end
end

function PakettiSlabOPatternsBuildContent()
  PakettiSlabOPatternsRows = {}
  local vb = PakettiSlabOPatternsVB

  local rows = {}
  -- Header row with column labels
  table.insert(rows, vb:row{
    vb:text{ text = "", width = 22 },
    vb:text{ text = "Beats", width = 56, style = "strong", font = "bold" },
    vb:text{ text = "", width = 6 },
    vb:text{ text = "LPB", width = 40, style = "strong", font = "bold" },
    vb:text{ text = "", width = 6 },
    vb:text{ text = "Lines", width = 40, style = "strong", font = "bold" }
  })

  for i = 1, #PakettiSlabOPatternsValues do
    local idx = i
    local sel_btn = vb:button{
      text = "",
      width = 22,
      height = 20,
      color = {0x00, 0x00, 0x00},
      notifier = function()
        PakettiSlabOPatternsSelectedIndex = idx
        PakettiSlabOPatternsRefreshRowColors()
      end
    }
    local val_label = vb:text{
      text = tostring(PakettiSlabOPatternsValues[i] or ""),
      width = 56,
      style = "strong",
      font = "bold"
    }
    local beats, lpb = PakettiSlabOPatternsParseEntry(PakettiSlabOPatternsValues[i])
    local lines = PakettiSlabOPatternsCalculateLines(beats, lpb) or 0
    
    -- Get actual LPB that will be used (specified or current)
    local display_lpb = lpb
    if not display_lpb then
      if renoise.song then
        local s = renoise.song()
        if s then
          display_lpb = s.transport.lpb
        else
          display_lpb = 4
        end
      else
        display_lpb = 4
      end
    end
    
    local lpb_label = vb:text{
      text = tostring(display_lpb),
      width = 40,
      style = "strong",
      font = "bold"
    }
    
    local dec_label = vb:text{
      text = tostring(lines),
      width = 40,
      style = "strong",
      font = "bold"
    }
    PakettiSlabOPatternsRows[i] = { sel = sel_btn, val = val_label, lpb_label = lpb_label, dec = dec_label }
    table.insert(rows, vb:row{sel_btn, val_label, vb:text{ text = "→", width = 6, style = "disabled" }, lpb_label, vb:text{ text = "→", width = 6, style = "disabled" }, dec_label })
  end

  -- Presets live at file scope to follow Paketti global rules; use helper below

  local preset_buttons = vb:column{
    
    vb:text{ text = "Presets", style = "strong", font = "bold" },
    vb:switch{ width = 180, items = {"Overwrite","Append"}, value = PakettiSlabOPatternsPresetAppend and 2 or 1, notifier = function(v) PakettiSlabOPatternsPresetAppend = (v == 2) end },
    vb:button{ text = PakettiSlabOPatternsPresets[1].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(1) end },
    vb:button{ text = PakettiSlabOPatternsPresets[2].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(2) end },
    vb:button{ text = PakettiSlabOPatternsPresets[3].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(3) end },
    vb:button{ text = PakettiSlabOPatternsPresets[4].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(4) end },
    vb:button{ text = PakettiSlabOPatternsPresets[5].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(5) end },
    vb:button{ text = PakettiSlabOPatternsPresets[6].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(6) end },
    vb:button{ text = PakettiSlabOPatternsPresets[7].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(7) end },
    vb:button{ text = PakettiSlabOPatternsPresets[8].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(8) end }
  }

  -- Optional section name
  PakettiSlabOPatternsSectionTF = vb:textfield{
    text = tostring(PakettiSlabOPatternsSectionName or ""),
    width = 180,
    notifier = function(value)
      PakettiSlabOPatternsSectionName = value
    end
  }

  local add_btn = vb:button{
    text = "+",
    width = 24,
    notifier = PakettiSlabOPatternsAddRow
  }

  local remove_btn = vb:button{
    text = "-",
    width = 24,
    notifier = PakettiSlabOPatternsRemoveRow
  }

  local create_btn = vb:button{
    text = "Create Patterns (and Section)",
    width = 312,
    notifier = PakettiSlabOPatternsCreate
  }

  local clear_btn = vb:button{ text = "Clear", width = 60, notifier = PakettiSlabOPatternsClear }
  table.insert(rows, vb:row{ add_btn, remove_btn, vb:space{ width = 6 }, clear_btn })

  local section_row = vb:row{vb:text{ text = "Section Name (Optional)", width = 131 }, PakettiSlabOPatternsSectionTF }

  local content = vb:column{
    vb:row{ vb:column{ unpack(rows) }, preset_buttons },
    section_row,
    create_btn
  }

  return content
end

-- Keyhandler ----------------------------------------------------------------

function PakettiSlabOPatternsKeyHandler(dialog, key)
  -- Allow user's common handler to pre-process
  if type(_G["my_keyhandler_func"]) == "function" then
    local ret = _G["my_keyhandler_func"](dialog, key)
    -- If user's handler consumed the key (returned nil), stop here
    if ret == nil then return nil end
    -- Otherwise continue processing with our handler to ensure dialog hotkeys work
  end

  if key.name == "up" then
    PakettiSlabOPatternsMoveSelection(-1)
    return nil
  elseif key.name == "down" then
    PakettiSlabOPatternsMoveSelection(1)
    return nil
  elseif key.name == "+" or key.name == "=" then
    PakettiSlabOPatternsAddRow()
    return nil
  elseif key.name == "-" or key.name == "_" then
    PakettiSlabOPatternsRemoveRow()
    return nil
  elseif key.name == "return" then
    PakettiSlabOPatternsSave()
    PakettiSlabOPatternsCreate()
    return nil
  elseif key.name == "back" then
    PakettiSlabOPatternsBackspace()
    return nil
  elseif key.name == "esc" then
    dialog:close()
    return nil
  elseif string.len(key.name) == 1 then
    -- Accept digits, decimal point, and colon for "beats:lpb" format
    local ch = key.name
    if ch:match("[0-9%.:]") then
      PakettiSlabOPatternsAppendChar(ch)
      return nil
    end
  end

  return key
end

-- Rebuild/close/open --------------------------------------------------------

function PakettiSlabOPatternsRebuild()
  if PakettiSlabOPatternsDialogRef and PakettiSlabOPatternsDialogRef.visible then
    local was_open = true
    PakettiSlabOPatternsClose()
    if was_open then
      PakettiSlabOPatternsOpen()
    end
  end
end

function PakettiSlabOPatternsClose()
  if PakettiSlabOPatternsDialogRef and PakettiSlabOPatternsDialogRef.visible then
    PakettiSlabOPatternsDialogRef:close()
  end
  PakettiSlabOPatternsDialogRef = nil
  PakettiSlabOPatternsVB = nil
  PakettiSlabOPatternsRows = {}
end

function PakettiSlabOPatternsOpen()
  PakettiSlabOPatternsLoad()
  PakettiSlabOPatternsVB = renoise.ViewBuilder()

  local content = PakettiSlabOPatternsBuildContent()
  PakettiSlabOPatternsDialogRef = renoise.app():show_custom_dialog(
    "Paketti Slab'o'Patterns",
    content,
    PakettiSlabOPatternsKeyHandler
  )

  PakettiSlabOPatternsRefreshRowColors()
  -- Ensure Renoise captures keyboard for our keyhandler (required by user's rule)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiSlabOPatternsToggle()
  if PakettiSlabOPatternsDialogRef and PakettiSlabOPatternsDialogRef.visible then
    PakettiSlabOPatternsClose()
  else
    PakettiSlabOPatternsOpen()
  end
end

-- Menu entries / keybindings -----------------------------------------------

renoise.tool():add_menu_entry{ name = "Main Menu:Tools:Paketti Gadgets:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }
renoise.tool():add_menu_entry{ name = "Pattern Sequencer:Paketti Gadgets:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }
renoise.tool():add_menu_entry{ name = "Pattern Matrix:Paketti Gadgets:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }
renoise.tool():add_menu_entry{ name = "--Pattern Editor:Paketti Gadgets:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }
renoise.tool():add_keybinding{ name = "Pattern Editor:Paketti:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }
renoise.tool():add_keybinding{ name = "Global:Paketti:Paketti Slab'o'Patterns...", invoke = PakettiSlabOPatternsToggle }


