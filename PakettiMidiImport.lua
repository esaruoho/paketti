-- PakettiMidiImport.lua
-- MIDI File Import → Renoise Phrase Presets
-- Converts Ableton/GM MIDI drum clips into Renoise instrument phrases
-- Supports Format 0 (single track) and Format 1 (multi-track)
-- Pure Lua MIDI parser, no external dependencies

local vb = renoise.ViewBuilder()
local dialog = nil

----------------------------------------------------------------------
-- GM DRUM MAP (for display purposes)
----------------------------------------------------------------------
local GM_DRUM_NAMES = {
  [35] = "Acoustic Bass Drum", [36] = "Bass Drum 1",
  [37] = "Side Stick", [38] = "Acoustic Snare",
  [39] = "Hand Clap", [40] = "Electric Snare",
  [41] = "Low Floor Tom", [42] = "Closed Hi-Hat",
  [43] = "High Floor Tom", [44] = "Pedal Hi-Hat",
  [45] = "Low Tom", [46] = "Open Hi-Hat",
  [47] = "Low-Mid Tom", [48] = "Hi-Mid Tom",
  [49] = "Crash Cymbal 1", [50] = "High Tom",
  [51] = "Ride Cymbal 1", [52] = "Chinese Cymbal",
  [53] = "Ride Bell", [54] = "Tambourine",
  [55] = "Splash Cymbal", [56] = "Cowbell",
  [57] = "Crash Cymbal 2", [58] = "Vibraslap",
  [59] = "Ride Cymbal 2", [60] = "Hi Bongo",
  [61] = "Low Bongo", [62] = "Mute Hi Conga",
  [63] = "Open Hi Conga", [64] = "Low Conga",
  [65] = "High Timbale", [66] = "Low Timbale",
  [67] = "High Agogo", [68] = "Low Agogo",
  [69] = "Cabasa", [70] = "Maracas",
  [71] = "Short Whistle", [72] = "Long Whistle",
  [73] = "Short Guiro", [74] = "Long Guiro",
  [75] = "Claves", [76] = "Hi Wood Block",
  [77] = "Low Wood Block", [78] = "Mute Cuica",
  [79] = "Open Cuica", [80] = "Mute Triangle",
  [81] = "Open Triangle",
}

----------------------------------------------------------------------
-- BINARY READING HELPERS
----------------------------------------------------------------------

-- Read big-endian unsigned integer from string at position pos
local function read_uint(data, pos, num_bytes)
  local value = 0
  for i = 0, num_bytes - 1 do
    value = value * 256 + string.byte(data, pos + i)
  end
  return value, pos + num_bytes
end

-- Read MIDI variable-length quantity
local function read_vlq(data, pos)
  local value = 0
  local byte
  repeat
    byte = string.byte(data, pos)
    pos = pos + 1
    value = value * 128 + (byte % 128)
  until byte < 128
  return value, pos
end

----------------------------------------------------------------------
-- MIDI FILE PARSER
----------------------------------------------------------------------

local function parse_midi_file(file_path)
  local file = io.open(file_path, "rb")
  if not file then
    return nil, "Could not open file: " .. tostring(file_path)
  end
  local data = file:read("*all")
  file:close()

  if not data or #data < 14 then
    return nil, "File too small to be a valid MIDI file"
  end

  -- Verify MThd header
  if data:sub(1, 4) ~= "MThd" then
    return nil, "Not a valid MIDI file (missing MThd header)"
  end

  local header_length = read_uint(data, 5, 4)
  local format_type = read_uint(data, 9, 2)
  local num_tracks = read_uint(data, 11, 2)
  local time_division = read_uint(data, 13, 2)

  -- Only support ticks-per-quarter-note
  if time_division >= 0x8000 then
    return nil, "SMPTE time division not supported"
  end

  local ppqn = time_division

  local result = {
    format = format_type,
    ppqn = ppqn,
    tracks = {},
    name = nil,
    tempo_bpm = nil,
    time_sig_num = 4,
    time_sig_den = 4,
  }

  -- Parse tracks
  local pos = 9 + header_length

  for _ = 1, num_tracks do
    if pos + 8 > #data then break end

    local chunk_id = data:sub(pos, pos + 3)
    if chunk_id ~= "MTrk" then
      break
    end

    local track_length = read_uint(data, pos + 4, 4)
    pos = pos + 8
    local track_end = pos + track_length - 1

    local events = {}
    local abs_tick = 0
    local running_status = 0

    while pos <= track_end do
      -- Read delta time
      local delta
      delta, pos = read_vlq(data, pos)
      abs_tick = abs_tick + delta

      if pos > track_end then break end

      -- Read status byte
      local first_byte = string.byte(data, pos)
      local status_byte

      if first_byte >= 0x80 then
        status_byte = first_byte
        pos = pos + 1
      else
        status_byte = running_status
      end

      if pos > #data then break end

      -- High nibble determines event type
      local event_type = status_byte - (status_byte % 16)

      if status_byte == 0xFF then
        -- Meta event
        if pos > #data then break end
        local meta_type = string.byte(data, pos)
        pos = pos + 1
        local meta_length
        meta_length, pos = read_vlq(data, pos)

        if pos + meta_length - 1 > #data then break end
        local meta_data = data:sub(pos, pos + meta_length - 1)
        pos = pos + meta_length

        if meta_type == 0x03 and not result.name then
          -- Track name
          result.name = meta_data
        elseif meta_type == 0x51 and meta_length == 3 then
          -- Tempo (microseconds per quarter note)
          local tempo_us = read_uint(meta_data, 1, 3)
          if tempo_us > 0 then
            result.tempo_bpm = math.floor(60000000 / tempo_us + 0.5)
          end
        elseif meta_type == 0x58 and meta_length >= 2 then
          -- Time signature
          result.time_sig_num = string.byte(meta_data, 1)
          result.time_sig_den = 2 ^ string.byte(meta_data, 2)
        end

      elseif event_type == 0x90 then
        -- Note On
        if pos + 1 > #data then break end
        local note = string.byte(data, pos)
        local velocity = string.byte(data, pos + 1)
        pos = pos + 2
        running_status = status_byte

        if velocity > 0 then
          table.insert(events, {
            tick = abs_tick,
            type = "note_on",
            note = note,
            velocity = velocity,
          })
        end

      elseif event_type == 0x80 then
        -- Note Off (ignored for phrase creation - drums are one-shot)
        pos = pos + 2
        running_status = status_byte

      elseif event_type == 0xA0 or event_type == 0xB0 or event_type == 0xE0 then
        -- Polyphonic aftertouch, CC, pitch bend (2 data bytes)
        pos = pos + 2
        running_status = status_byte

      elseif event_type == 0xC0 or event_type == 0xD0 then
        -- Program change, channel aftertouch (1 data byte)
        pos = pos + 1
        running_status = status_byte

      elseif status_byte == 0xF0 or status_byte == 0xF7 then
        -- SysEx
        local sysex_length
        sysex_length, pos = read_vlq(data, pos)
        pos = pos + sysex_length

      else
        -- Unknown status, skip
        pos = pos + 1
      end
    end

    -- Advance past track chunk
    pos = track_end + 1

    table.insert(result.tracks, {
      events = events,
      total_ticks = abs_tick,
    })
  end

  return result
end

----------------------------------------------------------------------
-- MIDI EVENTS TO PHRASE DATA CONVERTER
----------------------------------------------------------------------

local function midi_events_to_phrase_data(midi, target_lpb, use_delay)
  -- Merge note-on events from all tracks
  local all_events = {}
  local max_tick = 0

  for _, track in ipairs(midi.tracks) do
    for _, event in ipairs(track.events) do
      if event.type == "note_on" then
        table.insert(all_events, event)
        if event.tick > max_tick then
          max_tick = event.tick
        end
      end
    end
  end

  if #all_events == 0 then
    return nil, "No note events found"
  end

  -- Sort by tick, then by note for consistent column assignment
  table.sort(all_events, function(a, b)
    if a.tick == b.tick then return a.note < b.note end
    return a.tick < b.tick
  end)

  local ticks_per_line = midi.ppqn / target_lpb

  -- Calculate total lines, round up to bar boundary
  local beats_per_bar = midi.time_sig_num or 4
  local ticks_per_bar = midi.ppqn * beats_per_bar
  local total_bars = math.ceil((max_tick + 1) / ticks_per_bar)
  local total_lines = total_bars * beats_per_bar * target_lpb

  -- Clamp to 512 (Renoise phrase max)
  local was_truncated = false
  if total_lines > 512 then
    total_lines = 512
    was_truncated = true
  end
  if total_lines < 1 then total_lines = 1 end

  -- Build line data
  local lines = {}
  local max_polyphony = 0
  local has_delay = false
  local unique_notes = {}

  for _, event in ipairs(all_events) do
    local exact_line = event.tick / ticks_per_line
    local line_num = math.floor(exact_line) + 1 -- 1-indexed

    if line_num > total_lines then break end

    -- Calculate delay value for sub-line timing
    local delay = 0
    if use_delay then
      local remainder = event.tick - (line_num - 1) * ticks_per_line
      if remainder > 0.001 then
        delay = math.floor(remainder / ticks_per_line * 256 + 0.5)
        if delay > 255 then delay = 255 end
        if delay < 0 then delay = 0 end
        if delay > 0 then has_delay = true end
      end
    end

    if not lines[line_num] then
      lines[line_num] = {}
    end

    table.insert(lines[line_num], {
      note = event.note,
      velocity = event.velocity,
      delay = delay,
    })

    if #lines[line_num] > max_polyphony then
      max_polyphony = #lines[line_num]
    end

    unique_notes[event.note] = true
  end

  -- Cap note columns at 12 (Renoise max)
  local note_columns = math.min(max_polyphony, 12)
  if note_columns < 1 then note_columns = 1 end

  -- Count unique notes
  local unique_count = 0
  for _ in pairs(unique_notes) do unique_count = unique_count + 1 end

  return {
    lines = lines,
    total_lines = total_lines,
    lpb = target_lpb,
    note_columns = note_columns,
    has_delay = has_delay,
    name = midi.name,
    tempo_bpm = midi.tempo_bpm,
    total_events = #all_events,
    unique_notes = unique_count,
    was_truncated = was_truncated,
    total_bars = total_bars,
  }
end

----------------------------------------------------------------------
-- PHRASE CREATION
----------------------------------------------------------------------

local function create_phrase_from_data(instrument, phrase_index, phrase_data)
  instrument:insert_phrase_at(phrase_index)
  local phrase = instrument.phrases[phrase_index]

  -- Set phrase name (truncate if very long)
  local name = phrase_data.name or ("MIDI " .. phrase_index)
  if #name > 60 then
    name = name:sub(1, 57) .. "..."
  end
  phrase.name = name
  phrase.lpb = phrase_data.lpb
  phrase.number_of_lines = phrase_data.total_lines
  phrase.visible_note_columns = phrase_data.note_columns
  phrase.volume_column_visible = true
  phrase.delay_column_visible = phrase_data.has_delay
  phrase.panning_column_visible = false
  phrase.sample_effects_column_visible = false
  phrase.looping = true
  phrase.autoseek = true

  -- Write note data into phrase lines
  for line_num, notes in pairs(phrase_data.lines) do
    if line_num >= 1 and line_num <= phrase_data.total_lines then
      local line = phrase:line(line_num)
      for col_idx, note_data in ipairs(notes) do
        if col_idx <= 12 then
          local note_col = line:note_column(col_idx)
          -- Clamp MIDI note to Renoise range (0-119)
          local note_val = note_data.note
          if note_val > 119 then note_val = 119 end
          if note_val < 0 then note_val = 0 end
          note_col.note_value = note_val
          note_col.volume_value = note_data.velocity
          if note_data.delay > 0 then
            note_col.delay_value = note_data.delay
          end
        end
      end
    end
  end

  return phrase
end

----------------------------------------------------------------------
-- SINGLE FILE IMPORT (replaces dudeMidi stub in PakettiMidi.lua)
----------------------------------------------------------------------

function dudeMidi(file_path)
  local song = renoise.song()
  if not song then
    renoise.app():show_warning("No song loaded.")
    return false
  end

  local instrument = song.selected_instrument
  local target_lpb = preferences.pakettiMidiImportLPB.value
  local use_delay = preferences.pakettiMidiImportUseDelay.value

  -- Parse MIDI file
  local midi, err = parse_midi_file(file_path)
  if not midi then
    renoise.app():show_warning("MIDI Import Error:\n" .. tostring(err))
    return false
  end

  -- Convert to phrase data
  local phrase_data
  phrase_data, err = midi_events_to_phrase_data(midi, target_lpb, use_delay)
  if not phrase_data then
    renoise.app():show_warning("MIDI Conversion Error:\n" .. tostring(err))
    return false
  end

  -- Set name from filename if MIDI track name is missing
  if not phrase_data.name or phrase_data.name == "" then
    local filename = file_path:match("([^/\\]+)$") or "MIDI Import"
    phrase_data.name = filename:gsub("%.[mM][iI][dD]$", "")
  end

  -- Check phrase limit
  if #instrument.phrases >= 126 then
    renoise.app():show_warning("Instrument already has 126 phrases (maximum). Cannot add more.")
    return false
  end

  song:describe_undo("Import MIDI as Phrase")

  local new_index = #instrument.phrases + 1
  create_phrase_from_data(instrument, new_index, phrase_data)

  -- Select the new phrase and show phrase editor
  song.selected_phrase_index = new_index
  renoise.app().window.active_middle_frame = 3

  local bpm_str = ""
  if phrase_data.tempo_bpm then
    bpm_str = string.format(", %d BPM", phrase_data.tempo_bpm)
  end

  renoise.app():show_status(string.format(
    "Imported '%s' as Phrase %02d (%d lines, %d notes, %d cols, LPB %d%s)",
    phrase_data.name, new_index, phrase_data.total_lines,
    phrase_data.total_events, phrase_data.note_columns,
    phrase_data.lpb, bpm_str))

  return true
end

----------------------------------------------------------------------
-- SCAN FOLDER FOR MIDI FILES
----------------------------------------------------------------------

local function scan_midi_files(folder_path)
  local files = {}
  local ok, all_names = pcall(os.filenames, folder_path)
  if not ok or not all_names then
    return files
  end

  for _, name in ipairs(all_names) do
    if name:lower():match("%.midi?$") then
      table.insert(files, {
        path = folder_path .. "/" .. name,
        name = name,
      })
    end
  end

  -- Sort alphabetically
  table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
  return files
end

----------------------------------------------------------------------
-- BATCH IMPORT FROM FOLDER
----------------------------------------------------------------------

local function batch_import_midi_to_phrases(folder_path, target_lpb, use_delay)
  local song = renoise.song()
  if not song then return 0, "No song loaded" end

  local files = scan_midi_files(folder_path)
  if #files == 0 then
    return 0, "No .mid files found in folder"
  end

  song:describe_undo("Batch Import MIDI to Phrases")

  local instrument = song.selected_instrument
  local imported = 0
  local skipped = 0
  local errors_list = {}
  local instruments_created = 0

  for _, file_info in ipairs(files) do
    -- Check phrase limit, create new instrument if needed
    if #instrument.phrases >= 126 then
      local new_idx = song.selected_instrument_index + 1
      song:insert_instrument_at(new_idx)
      song.selected_instrument_index = new_idx
      instrument = song.selected_instrument
      instruments_created = instruments_created + 1
      instrument.name = string.format("MIDI Import (cont. %d)", instruments_created)
    end

    -- Parse MIDI
    local midi, err = parse_midi_file(file_info.path)
    if not midi then
      table.insert(errors_list, file_info.name .. ": " .. tostring(err))
      skipped = skipped + 1
    else
      -- Convert to phrase data
      local phrase_data
      phrase_data, err = midi_events_to_phrase_data(midi, target_lpb, use_delay)
      if not phrase_data then
        table.insert(errors_list, file_info.name .. ": " .. tostring(err))
        skipped = skipped + 1
      else
        -- Set name from MIDI track name or filename
        if not phrase_data.name or phrase_data.name == "" then
          phrase_data.name = file_info.name:gsub("%.[mM][iI][dD][iI]?$", "")
        end

        -- Create phrase
        local new_index = #instrument.phrases + 1
        create_phrase_from_data(instrument, new_index, phrase_data)
        imported = imported + 1

        renoise.app():show_status(string.format(
          "Importing MIDI... %d/%d: %s", imported, #files, phrase_data.name))
      end
    end
  end

  -- Select last imported phrase
  if imported > 0 then
    song.selected_phrase_index = #instrument.phrases
    renoise.app().window.active_middle_frame = 3
  end

  local summary = string.format("Imported %d of %d MIDI files as phrases (LPB %d)",
    imported, #files, target_lpb)
  if instruments_created > 0 then
    summary = summary .. string.format(", created %d extra instrument(s)", instruments_created)
  end
  if skipped > 0 then
    summary = summary .. string.format(", %d skipped", skipped)
  end

  return imported, summary, errors_list
end

----------------------------------------------------------------------
-- BATCH IMPORT DIALOG
----------------------------------------------------------------------

local function show_midi_import_dialog()
  if dialog and dialog.visible then
    dialog:close()
  end

  vb = renoise.ViewBuilder()

  local default_lpb = preferences.pakettiMidiImportLPB.value
  local default_delay = preferences.pakettiMidiImportUseDelay.value

  local folder_path = ""
  local midi_file_count = 0

  local lpb_items = {"4", "6", "8", "12", "16", "24"}
  local lpb_index = 3 -- default to "8"
  for i, v in ipairs(lpb_items) do
    if tonumber(v) == default_lpb then lpb_index = i end
  end

  local content = vb:column{
    margin = 10,
    spacing = 6,
    width = 520,

    vb:text{
      text = "MIDI Drum Pattern to Phrase Import",
      font = "bold",
    },

    vb:row{
      spacing = 4,
      vb:text{ text = "Folder:", width = 50 },
      vb:textfield{
        id = "folder_path",
        width = 360,
        value = "",
      },
      vb:button{
        text = "Browse",
        width = 80,
        pressed = function()
          local path = renoise.app():prompt_for_path("Select MIDI clips folder")
          if path and path ~= "" then
            path = path:gsub("[/\\]$", "")
            folder_path = path
            vb.views.folder_path.value = path

            local files = scan_midi_files(path)
            midi_file_count = #files
            vb.views.file_count.text = string.format("Found %d .mid file(s)", midi_file_count)
            vb.views.import_button.active = midi_file_count > 0
          end
        end,
      },
    },

    vb:text{
      id = "file_count",
      text = "No folder selected",
    },

    vb:space{ height = 4 },

    vb:row{
      spacing = 16,

      vb:row{
        spacing = 4,
        vb:text{ text = "LPB:" },
        vb:popup{
          id = "lpb_popup",
          items = lpb_items,
          value = lpb_index,
          width = 60,
          notifier = function(idx)
            preferences.pakettiMidiImportLPB.value = tonumber(lpb_items[idx])
            preferences:save_as("preferences.xml")
          end,
        },
      },

      vb:row{
        spacing = 4,
        vb:checkbox{
          id = "use_delay",
          value = default_delay,
          notifier = function(val)
            preferences.pakettiMidiImportUseDelay.value = val
            preferences:save_as("preferences.xml")
          end,
        },
        vb:text{ text = "Use delay column (sub-line timing)" },
      },
    },

    vb:space{ height = 4 },

    vb:text{
      text = "Phrases are added to the selected instrument.\n" ..
             "New instruments are created at the 126 phrase limit.",
      font = "italic",
    },

    vb:space{ height = 4 },

    vb:horizontal_aligner{
      mode = "center",
      spacing = 10,

      vb:button{
        id = "import_button",
        text = "Import All MIDI Files as Phrases",
        width = 240,
        height = 28,
        active = false,
        pressed = function()
          if folder_path == "" or midi_file_count == 0 then
            renoise.app():show_status("No MIDI files to import")
            return
          end

          local target_lpb = tonumber(lpb_items[vb.views.lpb_popup.value])
          local use_delay_val = vb.views.use_delay.value

          local _, summary, import_errors = batch_import_midi_to_phrases(
            folder_path, target_lpb, use_delay_val)

          if import_errors and #import_errors > 0 then
            local error_msg = summary .. "\n\nErrors:\n"
            for i = 1, math.min(#import_errors, 10) do
              error_msg = error_msg .. "- " .. import_errors[i] .. "\n"
            end
            if #import_errors > 10 then
              error_msg = error_msg .. string.format("... and %d more", #import_errors - 10)
            end
            renoise.app():show_warning(error_msg)
          else
            renoise.app():show_status(summary)
          end

          vb.views.file_count.text = summary
        end,
      },

      vb:button{
        text = "Import Single File...",
        width = 140,
        height = 28,
        pressed = function()
          local path = renoise.app():prompt_for_filename_to_read({"mid", "midi"}, "Select MIDI file")
          if path and path ~= "" then
            dudeMidi(path)
          end
        end,
      },
    },
  }

  dialog = renoise.app():show_custom_dialog("Paketti MIDI Import", content)
end

----------------------------------------------------------------------
-- FILENAME SANITIZATION HELPER
----------------------------------------------------------------------

local function sanitize_filename(name)
  -- Replace characters invalid on Windows/macOS/Linux: / \ : * ? " < > |
  return name:gsub('[/\\:*?"<>|]', "_")
end

----------------------------------------------------------------------
-- SAVE ALL PHRASES AS PRESETS (.xrnz)
----------------------------------------------------------------------

local function save_all_phrases_as_presets()
  local song = renoise.song()
  if not song then
    renoise.app():show_warning("No song loaded.")
    return
  end

  local instrument = song.selected_instrument
  local phrases = instrument.phrases

  if #phrases == 0 then
    renoise.app():show_warning("Selected instrument has no phrases to save.")
    return
  end

  local folder = renoise.app():prompt_for_path("Select destination folder for phrase presets")
  if not folder or folder == "" then return end

  -- Remove trailing slash
  folder = folder:gsub("[/\\]$", "")

  local saved = 0
  local errors_list = {}

  for i = 1, #phrases do
    song.selected_phrase_index = i

    -- Build filename: XX_PhraseName.xrnz
    local phrase_name = phrases[i].name
    if not phrase_name or phrase_name == "" then
      phrase_name = string.format("Phrase_%02d", i)
    end
    phrase_name = sanitize_filename(phrase_name)

    local filename = string.format("%02d_%s.xrnz", i, phrase_name)
    local full_path = folder .. "/" .. filename

    local ok, err = pcall(function()
      renoise.app():save_instrument_phrase(full_path)
    end)

    if ok then
      saved = saved + 1
      renoise.app():show_status(string.format(
        "Saving phrases... %d/%d: %s", saved, #phrases, filename))
    else
      table.insert(errors_list, string.format("%s: %s", filename, tostring(err)))
    end
  end

  if #errors_list > 0 then
    local error_msg = string.format("Saved %d of %d phrases to:\n%s\n\nErrors:\n", saved, #phrases, folder)
    for i = 1, math.min(#errors_list, 10) do
      error_msg = error_msg .. "- " .. errors_list[i] .. "\n"
    end
    if #errors_list > 10 then
      error_msg = error_msg .. string.format("... and %d more", #errors_list - 10)
    end
    renoise.app():show_warning(error_msg)
  else
    renoise.app():show_status(string.format(
      "Saved all %d phrases as presets to: %s", saved, folder))
  end
end

----------------------------------------------------------------------
-- LOAD ALL PHRASE PRESETS FROM FOLDER (.xrnz)
----------------------------------------------------------------------

local function load_all_phrase_presets_from_folder()
  local song = renoise.song()
  if not song then
    renoise.app():show_warning("No song loaded.")
    return
  end

  local folder = renoise.app():prompt_for_path("Select folder containing phrase presets (.xrnz)")
  if not folder or folder == "" then return end

  -- Remove trailing slash
  folder = folder:gsub("[/\\]$", "")

  -- Scan for .xrnz files
  local files = {}
  local ok, all_names = pcall(os.filenames, folder)
  if not ok or not all_names then
    renoise.app():show_warning("Could not read folder: " .. folder)
    return
  end

  for _, name in ipairs(all_names) do
    if name:lower():match("%.xrnz$") then
      table.insert(files, name)
    end
  end

  if #files == 0 then
    renoise.app():show_warning("No .xrnz phrase preset files found in:\n" .. folder)
    return
  end

  -- Sort alphabetically
  table.sort(files, function(a, b) return a:lower() < b:lower() end)

  -- Check capacity
  local instrument = song.selected_instrument
  local existing = #instrument.phrases
  local available = 126 - existing

  if available <= 0 then
    renoise.app():show_warning("Selected instrument already has 126 phrases (maximum). Cannot load more.")
    return
  end

  if #files > available then
    renoise.app():show_warning(string.format(
      "Found %d .xrnz files but only %d phrase slots available (126 max, %d existing).\nWill load first %d files.",
      #files, available, existing, available))
    -- Truncate to available slots
    local trimmed = {}
    for i = 1, available do
      trimmed[i] = files[i]
    end
    files = trimmed
  end

  song:describe_undo("Load Phrase Presets from Folder")

  local loaded = 0
  local errors_list = {}

  for _, name in ipairs(files) do
    local full_path = folder .. "/" .. name

    local load_ok, err = pcall(function()
      renoise.app():load_instrument_phrase(full_path)
    end)

    if load_ok then
      loaded = loaded + 1
      renoise.app():show_status(string.format(
        "Loading phrase presets... %d/%d: %s", loaded, #files, name))
    else
      table.insert(errors_list, string.format("%s: %s", name, tostring(err)))
    end
  end

  -- Select last loaded phrase and switch to phrase editor
  if loaded > 0 then
    instrument = song.selected_instrument
    song.selected_phrase_index = #instrument.phrases
    renoise.app().window.active_middle_frame = 3
  end

  if #errors_list > 0 then
    local error_msg = string.format("Loaded %d of %d phrase presets from:\n%s\n\nErrors:\n", loaded, #files, folder)
    for i = 1, math.min(#errors_list, 10) do
      error_msg = error_msg .. "- " .. errors_list[i] .. "\n"
    end
    if #errors_list > 10 then
      error_msg = error_msg .. string.format("... and %d more", #errors_list - 10)
    end
    renoise.app():show_warning(error_msg)
  else
    renoise.app():show_status(string.format(
      "Loaded %d phrase presets from: %s", loaded, folder))
  end
end

----------------------------------------------------------------------
-- REGISTRATION
----------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Instruments:MIDI Drum Pattern to Phrase (Import)...",
  invoke = function()
    local path = renoise.app():prompt_for_filename_to_read({"mid", "midi"}, "Select MIDI file to import as phrase")
    if path and path ~= "" then
      dudeMidi(path)
    end
  end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Instruments:MIDI Folder Batch Import to Phrases...",
  invoke = function()
    show_midi_import_dialog()
  end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:MIDI Drum Pattern to Phrase (Import)...",
  invoke = function()
    local path = renoise.app():prompt_for_filename_to_read({"mid", "midi"}, "Select MIDI file to import as phrase")
    if path and path ~= "" then
      dudeMidi(path)
    end
  end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:MIDI Folder Batch Import to Phrases...",
  invoke = function()
    show_midi_import_dialog()
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MIDI Drum Pattern to Phrase (Import)... x[Button]",
  invoke = function(message)
    if message:is_trigger() then
      local path = renoise.app():prompt_for_filename_to_read({"mid", "midi"}, "Select MIDI file to import as phrase")
      if path and path ~= "" then
        dudeMidi(path)
      end
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MIDI Folder Batch Import to Phrases... x[Button]",
  invoke = function(message)
    if message:is_trigger() then
      show_midi_import_dialog()
    end
  end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Instruments:Save All Phrases as Presets (.xrnz)...",
  invoke = function() save_all_phrases_as_presets() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Instruments:Load All Phrase Presets from Folder (.xrnz)...",
  invoke = function() load_all_phrase_presets_from_folder() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Save All Phrases as Presets (.xrnz)...",
  invoke = function() save_all_phrases_as_presets() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Load All Phrase Presets from Folder (.xrnz)...",
  invoke = function() load_all_phrase_presets_from_folder() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Save All Phrases as Presets (.xrnz)... x[Button]",
  invoke = function(message)
    if message:is_trigger() then
      save_all_phrases_as_presets()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Load All Phrase Presets from Folder (.xrnz)... x[Button]",
  invoke = function(message)
    if message:is_trigger() then
      load_all_phrase_presets_from_folder()
    end
  end
}
