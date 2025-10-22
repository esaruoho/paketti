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

-- Data model: list of string values like "0x40"
PakettiSlabOPatternsValues = {}

-- Presets (labels used on buttons; values injected to rows)
-- NOTE: Preset values are defined for 4 LPB reference. They will be scaled by (LPB/4) when creating patterns.
PakettiSlabOPatternsPresets = {
  { label = "14/8", values = { "0x40", "0x30" } },
  { label = "15/8", values = { "0x40", "0x38" } },
  { label = "14/8 - 15/8", values = { "0x40", "0x30", "0x40", "0x38" } },
  { label = "14/8 - 15/8 - 15/8 - 14/8", values = { "0x40", "0x30", "0x40", "0x38", "0x40", "0x38", "0x40", "0x30" } },
  { label = "6/4 8/4", values = { "0x30", "0x30", "0x40", "0x40" } },
  { label = "8/4 6/4", values = { "0x40", "0x40", "0x30", "0x30" } }
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
    -- default set
    table.insert(PakettiSlabOPatternsValues, "0x40")
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

-- Utility: parse value to number of lines (supports 0x.. or decimal)
function PakettiSlabOPatternsParseToLines(v)
  if type(v) ~= "string" then
    return nil
  end
  local trimmed = v:match("^%s*(.-)%s*$") or v
  local num = nil
  if trimmed:match("^0[xX]%x+$") then
    num = tonumber(trimmed:sub(3), 16)
  else
    num = tonumber(trimmed)
  end
  if not num then return nil end
  if num < 1 then num = 1 end
  if num > 512 then num = 512 end
  return math.floor(num)
end

-- Add/remove rows -----------------------------------------------------------

function PakettiSlabOPatternsAddRow()
  -- Always add a fresh entry prompting for hex input
  table.insert(PakettiSlabOPatternsValues, "0x")
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
    -- Single slot: wipe to fresh hex starter
    PakettiSlabOPatternsValues[1] = "0x"
    PakettiSlabOPatternsSelectedIndex = 1
    PakettiSlabOPatternsSave()
    -- Update UI minimally
    if PakettiSlabOPatternsRows[1] then
      PakettiSlabOPatternsUpdateRowLabels(1)
      PakettiSlabOPatternsRefreshRowColors()
    else
      PakettiSlabOPatternsRebuild()
    end
    renoise.app():show_status("Cleared the only slot to '0x'")
  end
end

-- Clear all to single fresh slot
function PakettiSlabOPatternsClear()
  PakettiSlabOPatternsValues = { "0x" }
  PakettiSlabOPatternsSelectedIndex = 1
  PakettiSlabOPatternsActivePresetLabel = ""
  PakettiSlabOPatternsSeedValues = { "0x" }
  PakettiSlabOPatternsSave()
  PakettiSlabOPatternsRebuild()
  renoise.app():show_status("Cleared: reset to single '0x' slot")
end

-- Create patterns -----------------------------------------------------------

function PakettiSlabOPatternsCreate()
  if not renoise.song then return end
  local s = renoise.song()
  if not s then return end

  -- Get current LPB and calculate multiplier (reference is 4 LPB)
  local lpb = s.transport.lpb
  local lpb_multiplier = lpb / 4

  local insert_at = s.selected_sequence_index + 1
  local created = 0
  local first_created_seq_index = insert_at
  local created_lengths = {}

  for i = 1, #PakettiSlabOPatternsValues do
    local v = PakettiSlabOPatternsValues[i]
    local lines = PakettiSlabOPatternsParseToLines(v)
    if not lines then
      renoise.app():show_status("Invalid slab value: " .. tostring(v))
      return
    end

    -- Apply LPB multiplier to get actual line count
    lines = math.floor(lines * lpb_multiplier)
    if lines < 1 then lines = 1 end
    if lines > 512 then lines = 512 end

    -- Insert unique new pattern after the current one
    s.sequencer:insert_new_pattern_at(insert_at)
    local pat_index = s.sequencer.pattern_sequence[insert_at]
    local pat = s.patterns[pat_index]
    if pat then
      pat.number_of_lines = lines
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
  local lpb_part = " [LPB: " .. tostring(lpb) .. "]"

  renoise.app():show_status("Added " .. tostring(created) .. " pattern(s) at lengths: " .. lengths_text .. preset_part .. lpb_part .. section_part)
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
  -- If value starts with 0x, allow only hex digits and max 3 digits after 0x
  if cur:match("^0[xX]") then
    if ch == "x" or ch == "X" then
      -- Do not allow adding another x/X into an already 0x-prefixed value
      return nil
    end
    local digits = cur:sub(3)
    if #digits >= 3 then
      renoise.app():show_status("Max 3 hex digits after 0x")
      return nil
    end
    if not ch:match("[0-9a-fA-F]") then
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
  local dec = PakettiSlabOPatternsParseToLines(val) or 0
  
  -- Apply LPB multiplier to show actual line count (reference is 4 LPB)
  if renoise.song then
    local s = renoise.song()
    if s then
      local lpb = s.transport.lpb
      local lpb_multiplier = lpb / 4
      dec = math.floor(dec * lpb_multiplier)
      if dec < 1 then dec = 1 end
      if dec > 512 then dec = 512 end
    end
  end
  
  if row.val then row.val.text = val end
  if row.dec then row.dec.text = tostring(dec) end
end

function PakettiSlabOPatternsBuildContent()
  PakettiSlabOPatternsRows = {}
  local vb = PakettiSlabOPatternsVB

  local rows = {}
  table.insert(rows, vb:text{ text = "Length", style = "strong",font="bold" })

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
    local dec_val = PakettiSlabOPatternsParseToLines(PakettiSlabOPatternsValues[i]) or 0
    
    -- Apply LPB multiplier to show actual line count (reference is 4 LPB)
    if renoise.song then
      local s = renoise.song()
      if s then
        local lpb = s.transport.lpb
        local lpb_multiplier = lpb / 4
        dec_val = math.floor(dec_val * lpb_multiplier)
        if dec_val < 1 then dec_val = 1 end
        if dec_val > 512 then dec_val = 512 end
      end
    end
    
    local dec_label = vb:text{
      text = tostring(dec_val),
      width = 40,
      style = "strong",
      font = "bold"
    }
    PakettiSlabOPatternsRows[i] = { sel = sel_btn, val = val_label, dec = dec_label }
    table.insert(rows, vb:row{sel_btn, val_label, vb:text{ text = "→", width = 6, style = "disabled" }, dec_label })
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
    vb:button{ text = PakettiSlabOPatternsPresets[6].label, width = 180, notifier = function() PakettiSlabOPatternsApplyPreset(6) end }
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
  elseif key.name == "space" then
    PakettiSlabOPatternsAppendChar(" ")
    return nil
  elseif string.len(key.name) == 1 then
    -- Accept typical hex/decimal characters
    local ch = key.name
    if ch:match("[0-9a-fA-FxX]") then
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


