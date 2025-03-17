--[[----------------------------------------------------------------------------
Paketti XRNS Probe v1.2
Analyzes current song or XRNS file for track, instrument and device information
------------------------------------------------------------------------------]]

local vb = renoise.ViewBuilder()
local dialog = nil
local results_textfield = nil
local show_browse = false

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

function PakettiXRNSProbeAppendText(text)
  if not dialog or not results_textfield then return end
  results_textfield.text = results_textfield.text .. text
end

function PakettiXRNSProbeClearText()
  if not dialog or not results_textfield then return end
  results_textfield.text = ""
end

function PakettiXRNSProbeSetText(text)
  if not dialog or not results_textfield then return end
  results_textfield.text = text
end

--------------------------------------------------------------------------------
-- Main Dialog Creation
--------------------------------------------------------------------------------

function PakettiXRNSProbeShowDialog(mode)
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  -- Create new ViewBuilder instance each time
  local vb = renoise.ViewBuilder()

  -- Create buttons array based on show_browse flag
  local buttons = {
    vb:button {
      text = "Show Current Song",
      width = 120,
      notifier = function() 
        PakettiXRNSProbeClearText()
        PakettiXRNSProbeAnalyzeCurrentSong() 
      end
    }
  }
  
  -- Only add Browse button if show_browse is true
  if show_browse then
    table.insert(buttons, vb:button {
      text = "Browse XRNS",
      width = 120,
      notifier = function() 
        PakettiXRNSProbeClearText()
        PakettiXRNSProbeBrowseAndAnalyzeXRNS() 
      end
    })
  end
  
  -- Always add Save button
  table.insert(buttons, vb:button {
    text = "Save as .TXT",
    width = 120,
    notifier = function()
      local filename = renoise.app():prompt_for_filename_to_write("txt", "Save Analysis as Text File")
      if filename then
        if not filename:match("%.txt$") then
          filename = filename .. ".txt"
        end
        local file = io.open(filename, "w")
        if file then
          file:write(results_textfield.text)
          file:close()
          renoise.app():show_status("Analysis saved to " .. filename)
        else
          renoise.app():show_warning("Failed to save file")
        end
      end
    end
  })

  local dialog_content = vb:column {
    vb:horizontal_aligner {
      spacing = 4,
      unpack(buttons)  -- Use the dynamically created buttons array
    },
    vb:multiline_textfield {
      id = "results",
      width = 777,
      height = 888,
      font = "mono"
    }
  }

  dialog = renoise.app():show_custom_dialog(
    "Paketti XRNS Probe", 
    dialog_content
  )
  
  results_textfield = vb.views.results

  -- Show current song by default or handle Browse mode
  if mode == "Browse" and show_browse then
    PakettiXRNSProbeBrowseAndAnalyzeXRNS()
  else
    PakettiXRNSProbeAnalyzeCurrentSong()
  end
end


--------------------------------------------------------------------------------
-- Current Song Analysis
--------------------------------------------------------------------------------
function PakettiXRNSProbeAnalyzeCurrentSong()
  local song = renoise.song()
  if not song then
    PakettiXRNSProbeSetText("Error: No song loaded")
    return
  end
  
  if #song.tracks == 0 then
    PakettiXRNSProbeSetText("Empty song - no tracks found")
    return
  end

  PakettiXRNSProbeSetText(string.format("Song filename: %s\n-------------------\n", 
    song.file_name ~= "" and song.file_name or "<This song has not yet been saved>"))

  local found_content = false
  local used_instruments = {}
  local total_tracks = #song.tracks
  local shown_tracks = 0
  
  for track_idx, track in ipairs(song.tracks) do
    local track_instruments = {}
    local has_notes = false
    
    for _, pattern in ipairs(song.patterns) do
      local pattern_track = pattern.tracks[track_idx]
      if pattern_track then
        for _, line in ipairs(pattern_track.lines) do
          for _, note_col in ipairs(line.note_columns) do
            if note_col.instrument_value < 255 then
              track_instruments[note_col.instrument_value] = true
              used_instruments[note_col.instrument_value] = true
              has_notes = true
            end
          end
          for _, fx_col in ipairs(line.effect_columns) do
            if fx_col.number_value > 0 then
              has_notes = true
            end
          end
        end
      end
    end

    -- Only show tracks with actual content
    if has_notes or #track.devices > 1 then
      found_content = true
      shown_tracks = shown_tracks + 1
      
-- In PakettiXRNSProbeAnalyzeCurrentSong, modify the track name display:
PakettiXRNSProbeAppendText(string.format("Track %02d: %s\n", track_idx, 
  track.type == renoise.Track.TRACK_TYPE_MASTER and "Master track" or
  track.type == renoise.Track.TRACK_TYPE_SEND and "Send track" or
  track.name))

      -- Analyze instruments if any
      for instr_idx in pairs(track_instruments) do
        PakettiXRNSProbeAnalyzeInstrument(song.instruments[instr_idx + 1], instr_idx)
      end
      
-- In track devices display, modify the format:
if #track.devices > 1 then
  PakettiXRNSProbeAppendText("Track Devices:\n")
  for i = 2, #track.devices do
    local device = track.devices[i]
    if device then
      local device_path = device.device_path or "Audio/Effects/Native"
      local device_type = device_path:match("Audio/Effects/([^/]+)")
      -- Only show "Native" prefix for native devices
      local display_name = device_type == "Native" 
        and string.format("Native %s", device.name)
        or device.name
      PakettiXRNSProbeAppendText(string.format("  %s, %s\n",
        display_name,
        device_path
      ))
    end
  end
end      
PakettiXRNSProbeAppendText("-------------------\n")
    end
  end

  -- Show detailed track counts at the end
  local seq_tracks = song.sequencer_track_count
  local send_tracks = song.send_track_count
  PakettiXRNSProbeAppendText("Track Summary:\n")
  PakettiXRNSProbeAppendText(string.format("Sequencer Track Count: %d\n", seq_tracks))
  PakettiXRNSProbeAppendText("Master Track\n")
  PakettiXRNSProbeAppendText(string.format("Send Track Count: %d\n", send_tracks))
  PakettiXRNSProbeAppendText(string.format("Total Tracks: %d", seq_tracks + send_tracks + 1))

  
  -- Check for unused instruments with actual content
  local unused = {}
  for i = 0, #song.instruments - 1 do
    if not used_instruments[i] and song.instruments[i + 1] then
      local instr = song.instruments[i + 1]
      -- Actually verify content exists before adding
      if (instr.plugin_properties and instr.plugin_properties.plugin_device) or
         (#instr.sample_mappings > 0 and instr.sample_mappings[1].sample) or
         (instr.midi_input_properties and instr.midi_input_properties.device_name ~= "") or
         (instr.midi_output_properties and instr.midi_output_properties.device_name ~= "") then
          table.insert(unused, {idx = i, instr = instr})
      end
    end
  end
  
  -- Only show unused instruments section if there are non-empty instruments
  if #unused > 0 then
    PakettiXRNSProbeAppendText("\n-------------------\nUnused instruments:\n")
    for _, entry in ipairs(unused) do
      PakettiXRNSProbeAnalyzeInstrument(entry.instr, entry.idx)
    end
    PakettiXRNSProbeAppendText("-------------------\n")
  end
  
  if not found_content then
    PakettiXRNSProbeAppendText("No regular tracks found (only Master/Send tracks)\n")
  end
end



function PakettiXRNSProbeAnalyzeTrackDevices(track)
  if not track or #track.devices <= 1 then return end
  
  PakettiXRNSProbeAppendText("\nTrack Devices:\n")
  for i = 2, #track.devices do
    local device = track.devices[i]
    if device then
      local device_path = device.device_path or "Audio/Effects/Native"
      local device_type = device_path:match("Audio/Effects/([^/]+)")
      -- Only show device name without format prefix unless it's Native
      local display_name = device_type == "Native" 
        and string.format("Native %s", device.name)
        or device.name
      PakettiXRNSProbeAppendText(string.format("  %s, %s\n",
        display_name,
        device_path
      ))
    end
  end
end

function PakettiXRNSProbeAnalyzeInstrument(instr, instr_idx)
  if not instr then return end
  
  -- Always show instrument name first (without colon)
  PakettiXRNSProbeAppendText(string.format("Instrument %02X %s\n", instr_idx, instr.name))
  
  -- Plugin info if exists
  if instr.plugin_properties and instr.plugin_properties.plugin_device then
    local plugin_device = instr.plugin_properties.plugin_device
    local plugin_path = plugin_device.device_path
    PakettiXRNSProbeAppendText(string.format("Instrument %02X Plugin: %s (%s)\n", 
      instr_idx, plugin_device.name, plugin_path))
  end
  
  -- Sample info - using samples[] directly
  if #instr.samples > 0 then
    for sample_idx, sample in ipairs(instr.samples) do
      if sample and sample.sample_buffer then
        PakettiXRNSProbeAppendText(string.format("Instrument %02X Sample: %s\n", 
          instr_idx, sample.name))
        PakettiXRNSProbeAppendText(string.format("    Channels: %s\n", 
          sample.sample_buffer.number_of_channels == 1 and "Mono" or "Stereo"))
        PakettiXRNSProbeAppendText(string.format("    Size: %s frames\n", 
          tostring(sample.sample_buffer.number_of_frames):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")))
      end
    end
  end

  -- MIDI IN/OUT info
  local has_midi = false
  local midi_text = string.format("Instrument %02X MIDI:", instr_idx)
  
  if instr.midi_input_properties and 
     instr.midi_input_properties.device_name and 
     instr.midi_input_properties.device_name ~= "" then
    has_midi = true
    midi_text = midi_text .. string.format(" [IN: %s", 
      instr.midi_input_properties.device_name)
    if instr.midi_input_properties.channel > 0 then
      midi_text = midi_text .. string.format(" ch:%d", 
        instr.midi_input_properties.channel)
    end
    midi_text = midi_text .. "]"
  end
  
  if instr.midi_output_properties and 
     instr.midi_output_properties.device_name and 
     instr.midi_output_properties.device_name ~= "" then
    has_midi = true
    midi_text = midi_text .. string.format(" [OUT: %s", 
      instr.midi_output_properties.device_name)
    if instr.midi_output_properties.channel > 0 then
      midi_text = midi_text .. string.format(" ch:%d", 
        instr.midi_output_properties.channel)
    end
    midi_text = midi_text .. "]"
  end
  
  if has_midi then
    PakettiXRNSProbeAppendText(midi_text .. "\n")
  end
  
  -- Now show FX chain if any
  if #instr.samples > 0 then
    for sample_idx, sample in ipairs(instr.samples) do
      if sample and sample.sample_buffer then
        if instr.sample_device_chains and 
           instr.sample_device_chains[sample_idx] and 
           instr.sample_device_chains[sample_idx].devices then
          local devices = instr.sample_device_chains[sample_idx].devices
          if #devices > 1 then  -- Skip first device (mixer)
            PakettiXRNSProbeAppendText("\n      FX Chain:")
            for i = 2, #devices do
              local device = devices[i]
              local device_path = device.device_path or "Audio/Effects/Native"
              local device_type = device_path:match("Audio/Effects/([^/]+)")
              local display_name = device_type == "Native" 
                and string.format("Native %s", device.name)
                or device.name
              PakettiXRNSProbeAppendText(string.format("\n        %s (%s)",
                display_name,
                device_path
              ))
            end
            PakettiXRNSProbeAppendText("\n")
          end
        end
      end
    end
  end

  PakettiXRNSProbeAppendText("\n")  -- Single newline after instrument
end


function PakettiXRNSProbeAnalyzeTrackDevices(track)
  if not track then return end
  
  if #track.devices > 1 then
    PakettiXRNSProbeAppendText("\nTrack Devices:\n")
    for i = 2, #track.devices do
      local device = track.devices[i]
      if device then
        local device_type = device.device_path and device.device_path:match("Audio/Effects/([^/]+)") or "Native"
        PakettiXRNSProbeAppendText(string.format("  %s: %s\n",
          device_type,
          device.name
        ))
      end
    end
  end
end
--------------------------------------------------------------------------------
-- XRNS File Analysis
--------------------------------------------------------------------------------

function PakettiXRNSProbeBrowseAndAnalyzeXRNS()
  local filename = renoise.app():prompt_for_filename_to_read({"*.XRNS"}, "Paketti XRNS Probe")
  if not filename then return end
  
  -- Create temp path for XML extraction
  local temp_path = os.tmpname()
  
  -- Extract Song.xml
  local success = os.execute(string.format('unzip -p "%s" "Song.xml" > "%s"', filename, temp_path))
  if not success then
    PakettiXRNSProbeSetText("Error: Failed to extract Song.xml from XRNS file")
    os.remove(temp_path)
    return
  end
  
  -- Read the XML content
  local file = io.open(temp_path, "r")
  if not file then
    PakettiXRNSProbeSetText("Error: Failed to read extracted Song.xml")
    os.remove(temp_path)
    return
  end
  
  local content = file:read("*all")
  file:close()
  os.remove(temp_path)
  
  PakettiXRNSProbeSetText(string.format("Song filename: %s\n\n", filename))
  
  -- Find all instruments first to track usage
  local all_instruments = {}
  local used_instruments = {}
  
  for instr in content:gmatch("<Instrument(.-)</Instrument>") do
    local instr_idx = tonumber(instr:match('index="(%d+)"'))
    if instr_idx then
      all_instruments[instr_idx] = {
        name = instr:match("<Name>(.-)</Name>") or "",
        plugin_type = instr:match("<PluginType>(.-)</PluginType>"),
        plugin_name = instr:match("<PluginName>(.-)</PluginName>"),
        plugin_path = instr:match("<PluginPath>(.-)</PluginPath>"),
        midi_in_device = instr:match("<MidiInputDevice>(.-)</MidiInputDevice>"),
        midi_out_device = instr:match("<MidiOutputDevice>(.-)</MidiOutputDevice>")
      }
    end
  end
  
  -- Process tracks
  local found_content = false
  for track in content:gmatch("<Track(.-)</Track>") do
    local track_type = track:match('type="(.-)"')
    if track_type ~= "Master" and track_type ~= "Send" then
      found_content = true
      local track_idx = track:match('index="(%d+)"') or "??"
      local track_name = track:match("<Name>(.-)</Name>") or "Unnamed"
      
      -- Check for notes and effects
      local has_notes = track:match("<Note>") or track:match("<Effect>")
      local devices = {}
      
      -- Collect devices
      for device in track:gmatch("<Device(.-)</Device>") do
        local device_name = device:match("<Name>(.-)</Name>")
        local device_path = device:match("<Path>(.-)</Path>") or "Audio/Effects/Native"
        if device_name then
          table.insert(devices, {name = device_name, path = device_path})
        end
      end
      
      -- Track instruments used
      local track_instruments = {}
      for note in track:gmatch("<Note(.-)</Note>") do
        local instr_value = tonumber(note:match('instrument_value="(%d+)"'))
        if instr_value and instr_value < 255 then
          track_instruments[instr_value] = true
          used_instruments[instr_value] = true
        end
      end
      
      -- Output track info
      if not has_notes and #devices <= 1 then
        PakettiXRNSProbeAppendText(string.format("Track %s: %s - No notes, effects or devices on track\n",
          track_idx, track_name))
      else
        PakettiXRNSProbeAppendText(string.format("Track %s: %s\n", track_idx, track_name))
        
        -- Show instruments used in track
        for instr_idx in pairs(track_instruments) do
          local instr = all_instruments[instr_idx]
          if instr then
            PakettiXRNSProbeAppendText(string.format("Instrument %02X: ", instr_idx))
            if instr.plugin_type and instr.plugin_path then
              PakettiXRNSProbeAppendText(string.format("%s: %s (%s)", 
                instr.plugin_type, instr.plugin_name, instr.plugin_path))
            end
            PakettiXRNSProbeAppendText(string.format("  %s", instr.name))
            if instr.midi_in_device and instr.midi_in_device ~= "" then
              PakettiXRNSProbeAppendText(string.format(" [MIDI IN: %s]", instr.midi_in_device))
            end
            if instr.midi_out_device and instr.midi_out_device ~= "" then
              PakettiXRNSProbeAppendText(string.format(" [MIDI OUT: %s]", instr.midi_out_device))
            end
            PakettiXRNSProbeAppendText("\n")
          end
        end
        
        -- Show track devices
        if #devices > 1 then
          PakettiXRNSProbeAppendText("\nTrack Devices:\n")
          for i = 2, #devices do
            local device = devices[i]
            local device_type = device.path:match("Audio/Effects/([^/]+)")
            PakettiXRNSProbeAppendText(string.format("  %s, %s, %s\n",
              device_type,
              device.name,
              device.path
            ))
          end
        end
        
        PakettiXRNSProbeAppendText("\n-------------------\n")
      end
    end
  end
  
  -- Check for unused instruments
  local unused = {}
  for i = 0, #song.instruments - 1 do
      if not used_instruments[i] and song.instruments[i + 1] then
          local instr = song.instruments[i + 1]
          -- Check for actual content
          local has_content = false
          
          -- Check plugin
          if instr.plugin_properties and instr.plugin_properties.plugin_device then
              has_content = true
          end
          
-- Sample info with length and FX chain
if #instr.sample_mappings > 0 then
  for mapping_idx, mapping in ipairs(instr.sample_mappings) do
      if mapping.sample then
          local sample = mapping.sample
          local buffer = sample.sample_buffer
          if buffer and buffer.has_sample_data then
              -- Show sample name, length, and channel info
              PakettiXRNSProbeAppendText(string.format("\n    Sample: %s (%d frames, %s)", 
                  sample.name,
                  buffer.number_of_frames,
                  buffer.number_of_channels == 1 and "mono" or "stereo"))
              
              -- Show sample FX chain using sample_device_chains
              if instr.sample_device_chains and 
                 instr.sample_device_chains[mapping_idx] and 
                 instr.sample_device_chains[mapping_idx].devices then
                  local devices = instr.sample_device_chains[mapping_idx].devices
                  if #devices > 1 then  -- Skip first device (mixer)
                      PakettiXRNSProbeAppendText("\n      FX Chain:")
                      for i = 2, #devices do
                          local device = devices[i]
                          local device_path = device.device_path or "Audio/Effects/Native"
                          local device_type = device_path:match("Audio/Effects/([^/]+)")
                          -- Only show "Native" prefix for native devices
                          local display_name = device_type == "Native" 
                              and string.format("Native %s", device.name)
                              or device.name
                          PakettiXRNSProbeAppendText(string.format("\n        %s (%s)",
                              display_name,
                              device_path
                          ))
                      end
                      PakettiXRNSProbeAppendText("\n")
                  end
              end
          end
      end
  end
end

          -- Check MIDI
          if (instr.midi_input_properties and 
              instr.midi_input_properties.device_name and 
              instr.midi_input_properties.device_name ~= "") or
             (instr.midi_output_properties and 
              instr.midi_output_properties.device_name and 
              instr.midi_output_properties.device_name ~= "") then
              has_content = true
          end
          
          if has_content then
              table.insert(unused, {idx = i, instr = instr})
          end
      end
  end
  
  if #unused > 0 then
    PakettiXRNSProbeAppendText("\n-------------------\nUnused instruments:\n")
    for _, entry in ipairs(unused) do
      PakettiXRNSProbeAppendText(string.format("Instrument %02X: ", entry.idx))
      if entry.instr.plugin_type and entry.instr.plugin_path then
        PakettiXRNSProbeAppendText(string.format("%s: %s (%s)", 
          entry.instr.plugin_type, entry.instr.plugin_name, entry.instr.plugin_path))
      end
      PakettiXRNSProbeAppendText(string.format("  %s", entry.instr.name))
      if entry.instr.midi_in_device and entry.instr.midi_in_device ~= "" then
        PakettiXRNSProbeAppendText(string.format(" [MIDI IN: %s]", entry.instr.midi_in_device))
      end
      if entry.instr.midi_out_device and entry.instr.midi_out_device ~= "" then
        PakettiXRNSProbeAppendText(string.format(" [MIDI OUT: %s]", entry.instr.midi_out_device))
      end
      PakettiXRNSProbeAppendText("\n")
    end
    PakettiXRNSProbeAppendText("-------------------\n")
  end
  
  if not found_content then
    PakettiXRNSProbeAppendText("No regular tracks found (only Master/Send tracks)\n")
  end
end

function PakettiXRNSProbeAnalyzeXRNSTrack(track_data)
  -- Get track name and index
  local track_name = track_data:match("<Name>(.-)</Name>") or "Unnamed"
  local track_idx = track_data:match('index="(%d+)"') or "??"
  
  -- Check for track content
  local has_notes = track_data:match("<Note>") or track_data:match("<Effect>")
  local devices = {}
  
  -- Collect devices first
  for device in track_data:gmatch("<Device.-</Device>") do
    local device_name = device:match("<Name>(.-)</Name>")
    local device_path = device:match("<Path>(.-)</Path>") or "Audio/Effects/Native"
    if device_name then
      table.insert(devices, {name = device_name, path = device_path})
    end
  end
  
  -- If track is empty, show concise output
  if not has_notes and #devices <= 1 then
    PakettiXRNSProbeAppendText(string.format("Track %s: %s - No notes, effects or devices on track\n",
      track_idx, track_name))
    return
  end
  
  -- Regular track with content
  PakettiXRNSProbeAppendText(string.format("Track %s: %s\n", track_idx, track_name))
  
  -- Process instruments
  for instr in track_data:gmatch("<Instrument.-</Instrument>") do
    local instr_name = instr:match("<Name>(.-)</Name>")
    local instr_idx = instr:match('index="(%d+)"')
    
    if instr_name then
      PakettiXRNSProbeAppendText(string.format("\nInstrument %02X: %s", 
        tonumber(instr_idx) or 0, instr_name))
      
      -- Plugin info
      local plugin_type = instr:match("<PluginType>(.-)</PluginType>")
      local plugin_name = instr:match("<PluginName>(.-)</PluginName>")
      local plugin_path = instr:match("<PluginPath>(.-)</PluginPath>")
      
      if plugin_type and plugin_path then
        PakettiXRNSProbeAppendText(string.format("\n  %s: %s (%s)",
          plugin_type,
          plugin_name or "Unknown",
          plugin_path
        ))
      end
      
      -- Sample info
      local has_samples = false
      for sample in instr:gmatch("<Sample.-</Sample>") do
        has_samples = true
        local sample_name = sample:match("<Name>(.-)</Name>")
        local sample_length = sample:match("<Length>(%d+)</Length>") or "0"
        
        PakettiXRNSProbeAppendText(string.format("\n  Sample: %s\n", sample_name))
        PakettiXRNSProbeAppendText(string.format("    Length: %s samples\n", sample_length))
        
        -- Sample effects chain
        local chain = sample:match("<DeviceChain.-</DeviceChain>")
        if chain then
          local has_effects = false
          for device in chain:gmatch("<Device.-</Device>") do
            if not has_effects then
              PakettiXRNSProbeAppendText("    Effects Chain:\n")
              has_effects = true
            end
            local device_name = device:match("<Name>(.-)</Name>")
            local device_path = device:match("<Path>(.-)</Path>") or "Audio/Effects/Native"
            local device_type = device_path:match("Audio/Effects/([^/]+)")
            PakettiXRNSProbeAppendText(string.format("      %s: %s (%s)\n",
              device_type,
              device_name,
              device_path
            ))
          end
        end
      end
      
      if not has_samples and not plugin_type then
        PakettiXRNSProbeAppendText("\n  Empty instrument (no samples or plugins)\n")
      end
    end
  end
  
  -- Output devices if any (skip first device which is mixer)
  if #devices > 1 then
    PakettiXRNSProbeAppendText("\nTrack Devices:\n")
    for i = 2, #devices do
      local device = devices[i]
      local device_type = device.path:match("Audio/Effects/([^/]+)")
      PakettiXRNSProbeAppendText(string.format("  %s: %s (%s)\n",
        device_type,
        device.name,
        device.path
      ))
    end
  end
  
  PakettiXRNSProbeAppendText("\n-------------------\n")
end

--------------------------------------------------------------------------------
-- Plugin Format Detection
--------------------------------------------------------------------------------

function PakettiXRNSProbeFindAlternativeFormat(device)
  if not device then return nil end
  
  local available_plugins = device.available_plugin_infos
  if not available_plugins then return nil end
  
  local alternatives = {}
  local current_format = device.path:match("Audio/Generators/([^/]+)")
  local device_name = device.display_name
  
  for _, plugin in ipairs(available_plugins) do
    local alt_format = plugin.path:match("Audio/Generators/([^/]+)")
    -- Check if it's same plugin but different format
    if plugin.display_name == device_name and 
       alt_format ~= current_format then
      table.insert(alternatives, string.format("%s (%s)", 
        plugin.display_name,
        alt_format
      ))
    end
  end
  
  return #alternatives > 0 and alternatives or nil
end
renoise.tool():add_keybinding {
  name = "Global:Tools:Paketti XRNS Probe",
  invoke = PakettiXRNSProbeShowDialog
}
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti XRNS Probe",
  invoke = PakettiXRNSProbeShowDialog
}

-- Only add Browse menu entry if show_browse is true
if show_browse then
  renoise.tool():add_menu_entry {
    name = "Main Menu:Tools:Paketti XRNS Probe (Browse)",
    invoke = function() PakettiXRNSProbeShowDialog("Browse") end
  }
end