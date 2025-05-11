--[[----------------------------------------------------------------------------
Paketti XRNS Probe v1.2
Analyzes current song or XRNS file for track, instrument and device information
------------------------------------------------------------------------------]]
local bit = require("bit")
local vb = renoise.ViewBuilder()
local dialog = nil
local results_textfield = nil
local show_browse = true

--------------------------------------------------------------------------------
-- Helpers for JUCE "ioz" + LZF + plist parsing
--------------------------------------------------------------------------------

-- Convert signed to unsigned 32-bit
local function to_unsigned(n)
  return n < 0 and (n + 0x100000000) or n
end

-- Read a little-endian u32 from string at pos
local function read_u32_le(s,pos)
  local b1,b2,b3,b4 = s:byte(pos,pos+3)
  local n = bit.bor(
    b1,
    bit.lshift(b2, 8),
    bit.lshift(b3,16),
    bit.lshift(b4,24)
  )
  return to_unsigned(n)
end

-- JUCE's XOR‐LCG decryptor
local function juce_decrypt(cipher, key)
  local seed, out = key, {}
  for i = 1, #cipher do
    seed = (seed * 196314165 + 907633515) % 2^32
    local mask = bit.band(bit.rshift(seed,24),0xFF)
    out[i] = string.char(bit.bxor(cipher:byte(i), mask))
  end
  return table.concat(out)
end

-- Pure‐Lua LZF decompressor
local function lzf_decompress(input)
  local output, i, o = {}, 1, 1
  while i <= #input do
    local ctrl = input:byte(i); i = i + 1
    if ctrl < 32 then
      local run = ctrl + 1
      for _=1,run do
        output[o], o, i = string.char(input:byte(i)), o+1, i+1
      end
    else
      local hi = bit.rshift(ctrl,5)
      local lo = input:byte(i); i = i + 1
      local ref = bit.bor(bit.lshift(hi,8), lo)
      local length = bit.band(ctrl,31)
      if length == 0 then
        length = input:byte(i) + 9; i = i + 1
      else
        length = length + 2
      end
      local start = o - ref
      for _=1,length do
        output[o], o = output[start], o+1; start = start + 1
      end
    end
  end
  return table.concat(output)
end

-- Attempt to unwrap JUCE "ioz" wrapper
local function try_parse_juce(blob)
  if #blob < 12 or blob:sub(1,4) ~= string.char(0xC6,0x69,0x6F,0x7A) then
    return nil
  end
  print("DEBUG: JUCE magic detected—decrypting+decompressing")
  local key     = read_u32_le(blob,5)
  local compLen = read_u32_le(blob,9)
  print("DEBUG: JUCE key:", key, "compLen:", compLen, "blob size:", #blob)
  if compLen <= 0 or compLen > #blob-12 then
    print("DEBUG: Invalid compressed length, skipping JUCE unwrap")
    return nil
  end
  local cipher = blob:sub(13,12+compLen)
  local plain  = juce_decrypt(cipher, key)
  local raw    = lzf_decompress(plain)
  if not raw or raw:sub(1,6) ~= "bplist" then
    print("DEBUG: LZF decompress did not yield bplist")
    return nil
  end
  return raw
end

-- Minimal Base64 decoder
local function base64_decode(data)
  if not data then return nil end
  local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local t = {}
  data = data:gsub('[^'..b64..'=]', '')
  for i=1,#data,4 do
    local c1 = (b64:find(data:sub(i,i)) or 1)-1
    local c2 = (b64:find(data:sub(i+1,i+1)) or 1)-1
    local c3 = (b64:find(data:sub(i+2,i+2)) or 1)-1
    local c4 = (b64:find(data:sub(i+3,i+3)) or 1)-1
    local n = bit.bor(
      bit.lshift(c1,18),
      bit.lshift(c2,12),
      bit.lshift(c3,6),
      c4
    )
    t[#t+1] = string.char(bit.band(bit.rshift(n,16), 0xFF))
    if data:sub(i+2,i+2) ~= '=' then t[#t+1] = string.char(bit.band(bit.rshift(n,8), 0xFF)) end
    if data:sub(i+3,i+3) ~= '=' then t[#t+1] = string.char(bit.band(n, 0xFF)) end
  end
  return table.concat(t)
end

-- Extract preset name from Base64‐encoded blob
local function extract_preset_from_blob(b64)
  if not b64 then return nil end

  -- 1) Base64-decode
  local blob = base64_decode(b64)
  if not blob then return nil end

  -- 2) Try JUCE unwrap, else raw
  local raw = try_parse_juce(blob) or blob

  -- 3) Find binary plist
  local pos = raw:find("bplist")
  if not pos then
    print("DEBUG: no bplist marker found")
    return nil
  end
  local plist = raw:sub(pos)

  -- 4) Write to temp + plutil → XML
  local bin = os.tmpname()
  local xml = bin .. ".xml"
  do
    local f = assert(io.open(bin,"wb"))
    f:write(plist)
    f:close()
  end
  os.execute(("/usr/bin/plutil -convert xml1 -o %q %q"):format(xml,bin))
  os.remove(bin)

  -- 5) Read XML
  local f = io.open(xml,"r")
  if not f then
    print("DEBUG: plutil failed, no xml file")
    return nil
  end
  local txt = f:read("*a")
  f:close()
  os.remove(xml)

  -- 6) Debug-dump keys
  print("DEBUG: dumping all plist key/value pairs:")
  for k,v in txt:gmatch("<key>(.-)</key>%s*<string>(.-)</string>") do
    print(("DEBUG: plist key=%q val=%q"):format(k,v))
  end

  -- 7) Match known preset keys
  return txt:match('<key>lastPreset</key>%s*<string>(.-)</string>')
      or txt:match('<key>ProgramName</key>%s*<string>(.-)</string>')
      or txt:match('<key>PresetName</key>%s*<string>(.-)</string>')
      or txt:match('<key>name</key>%s*<string>(.-)</string>')
end

-- Retrieve a device's preset name
local function get_device_preset(device)
  if not device then return nil end
  print("DEBUG: get_device_preset processing device:", device.name)
  if not device.device_path
    or device.device_path:match("Audio/Effects/Native")
  then
    return nil
  end
  if device.active_preset_data then
    print("DEBUG: Found active_preset_data, length:", #device.active_preset_data)
    local name = extract_preset_from_blob(device.active_preset_data)
    if name then
      print("DEBUG: Found preset name:", name)
      return name
    end
  end
  -- fallbacks
  local from_name = device.name:match(":%s*(.+)$")
  if from_name then return from_name end
  local from_path = device.device_path:match("/([^/]+)%.%a+$")
  return from_path
end

--------------------------------------------------------------------------------
-- UI + Analysis
--------------------------------------------------------------------------------

function PakettiXRNSProbeAppendText(text)
  if dialog and results_textfield then
    results_textfield.text = results_textfield.text .. text
  end
end

function PakettiXRNSProbeClearText()
  if dialog and results_textfield then
    results_textfield.text = ""
  end
end

function PakettiXRNSProbeSetText(text)
  if dialog and results_textfield then
    results_textfield.text = text
  end
end

function PakettiXRNSProbeAnalyzeInstrument(instr, idx)
  if not instr then return end
  print("\nDEBUG: Analyzing instrument", idx, instr.name)
  
  PakettiXRNSProbeAppendText(string.format("Instrument %02X %s\n", idx, instr.name))
  
  if instr.plugin_properties and instr.plugin_properties.plugin_device then
    local plugin_device = instr.plugin_properties.plugin_device
    print("DEBUG: Found plugin device:", plugin_device.name)
    PakettiXRNSProbeAppendText(string.format("Instrument %02X Plugin: %s (%s)\n", 
      idx, plugin_device.name, plugin_device.device_path
    ))
    -- Show instrument plugin preset
    local preset_name = get_device_preset(plugin_device)
    if preset_name then
      print("DEBUG: Adding preset name to output:", preset_name)
      PakettiXRNSProbeAppendText(string.format("    Preset: %s\n", preset_name))
    end
  end
  
  -- Sample info
  if #instr.samples > 0 then
    for sample_idx, sample in ipairs(instr.samples) do
      if sample and sample.sample_buffer then
        PakettiXRNSProbeAppendText(string.format("Instrument %02X Sample: %03d: %s ", 
          idx, sample_idx, sample.name))
        PakettiXRNSProbeAppendText(string.format("[%s, ", 
          sample.sample_buffer.number_of_channels == 1 and "Mono" or "Stereo"))
        PakettiXRNSProbeAppendText(string.format("%d-Bit, ",
          sample.sample_buffer.bit_depth))
        PakettiXRNSProbeAppendText(string.format("Size: %s frames]\n", 
          tostring(sample.sample_buffer.number_of_frames):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")))
      end
    end
  end
  
  -- MIDI IN/OUT info
  local has_midi = false
  local midi_text = string.format("Instrument %02X MIDI:", idx)
  
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
            print("DEBUG: Processing FX chain for sample", sample_idx)
            PakettiXRNSProbeAppendText("\n      FX Chain:")
            for i = 2, #devices do
              local device = devices[i]
              print("DEBUG: Processing FX device:", device.name)
              local device_path = device.device_path or "Audio/Effects/Native"
              local device_type = device_path:match("Audio/Effects/([^/]+)")
              local display_name = device_type == "Native" 
                and string.format("Native %s", device.name)
                or device.name
              PakettiXRNSProbeAppendText(string.format("\n        %s (%s)",
                display_name,
                device_path
              ))
              
              -- Show current preset if available
              local preset_name = get_device_preset(device)
              if preset_name then
                print("DEBUG: Adding FX preset name to output:", preset_name)
                PakettiXRNSProbeAppendText(string.format("\n        Preset: %s", preset_name))
              end
            end
            PakettiXRNSProbeAppendText("\n")
          end
        end
      end
    end
  end
  
  PakettiXRNSProbeAppendText("\n")
end

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
      
      PakettiXRNSProbeAppendText(string.format("Track %02d: %s\n", track_idx, 
        track.type == renoise.Track.TRACK_TYPE_MASTER and "Master track" or
        track.type == renoise.Track.TRACK_TYPE_SEND and "Send track" or
        track.name))

      -- Analyze instruments if any
      for instr_idx in pairs(track_instruments) do
        PakettiXRNSProbeAnalyzeInstrument(song.instruments[instr_idx + 1], instr_idx)
      end
      
      -- Track devices display
      if #track.devices > 1 then
        PakettiXRNSProbeAppendText("Track Devices:\n")
        for i = 2, #track.devices do
          local device = track.devices[i]
          if device then
            local device_path = device.device_path or "Audio/Effects/Native"
            local device_type = device_path:match("Audio/Effects/([^/]+)")
            local display_name = device_type == "Native" 
              and string.format("Native %s", device.name)
              or device.name
            PakettiXRNSProbeAppendText(string.format("  %s, %s\n",
              display_name,
              device_path
            ))
            -- Show current preset if available
            local preset_name = get_device_preset(device)
            if preset_name then
              PakettiXRNSProbeAppendText(string.format("    Preset: %s\n", preset_name))
            end
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
      if (instr.plugin_properties and instr.plugin_properties.plugin_device) or
         (#instr.sample_mappings > 0 and instr.sample_mappings[1].sample) or
         (instr.midi_input_properties and instr.midi_input_properties.device_name ~= "") or
         (instr.midi_output_properties and instr.midi_output_properties.device_name ~= "") then
          table.insert(unused, {idx = i, instr = instr})
      end
    end
  end
  
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

function PakettiXRNSProbeBrowseAndAnalyzeXRNS()
  local filename = renoise.app():prompt_for_filename_to_read({"*.XRNS"}, "Paketti XRNS Probe")
  if not filename then return end
  
  local temp_path = os.tmpname()
  local cmd = string.format('unzip -p "%s" "Song.xml" > "%s"', filename, temp_path)
  
  if os.execute(cmd) ~= 0 then
    PakettiXRNSProbeSetText("Error: Failed to extract Song.xml")
    os.remove(temp_path)
    return
  end
  
  local file = io.open(temp_path, "r")
  if not file then
    PakettiXRNSProbeSetText("Error: Failed to read extracted Song.xml")
    os.remove(temp_path)
    return
  end
  
  local content = file:read("*all")
  file:close()
  os.remove(temp_path)
  
  -- Process tracks first
  local tracks_section = content:match("<Tracks>(.-)</Tracks>")
  if tracks_section then
    local seq_track_count = 0
    local send_track_count = 0
    
    -- First process sequencer tracks
    for track in tracks_section:gmatch("<SequencerTrack[^>]*>(.-)</SequencerTrack>") do
      seq_track_count = seq_track_count + 1
      local track_name = track:match("<Name>(.-)</Name>") or "Unnamed"
      
      PakettiXRNSProbeAppendText(string.format("Track %02d: %s\n", seq_track_count, track_name))
      
      -- Process devices
      local devices_section = track:match("<FilterDevices>.-<Devices>(.-)</Devices>")
      if devices_section then
        local has_devices = false
        
        -- Look for devices
        for device in devices_section:gmatch("<AudioPluginDevice[^>]*>(.-)</AudioPluginDevice>") do
          if not has_devices then
            PakettiXRNSProbeAppendText("Track Devices:\n")
            has_devices = true
          end
          
          local plugin_type = device:match("<PluginType>(.-)</PluginType>")
          local plugin_name = device:match("<PluginDisplayName>(.-)</PluginDisplayName>")
          local plugin_id = device:match("<PluginIdentifier>(.-)</PluginIdentifier>")
          
          if plugin_type and plugin_name then
            PakettiXRNSProbeAppendText(string.format("  %s, Audio/Effects/%s/%s\n",
              plugin_name,
              plugin_type,
              plugin_id or ""
            ))
            
            -- Extract preset from parameter chunk
            local chunk = device:match("<ParameterChunk><!%[CDATA%[(.-)%]%]></ParameterChunk>")
            if chunk then
              local preset = extract_preset_from_blob(chunk)
              if preset then
                PakettiXRNSProbeAppendText(string.format("    Preset: %s\n", preset))
              end
            end
          end
        end
      end
      PakettiXRNSProbeAppendText("-------------------\n")
    end
    
    -- Output track summary
    PakettiXRNSProbeAppendText("Track Summary:\n")
    PakettiXRNSProbeAppendText(string.format("Sequencer Track Count: %d\n", seq_track_count))
    PakettiXRNSProbeAppendText("Master Track\n")
    PakettiXRNSProbeAppendText(string.format("Send Track Count: %d\n", send_track_count))
    PakettiXRNSProbeAppendText(string.format("Total Tracks: %d\n", seq_track_count + send_track_count + 1))
    PakettiXRNSProbeAppendText("-------------------\n")
  end
end

function pakettiXRNSProbeShowDialog(mode)
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  local vb = renoise.ViewBuilder()
  local buttons = { vb:button{ text="Show Current Song", width=120,
        notifier=function() PakettiXRNSProbeClearText() PakettiXRNSProbeAnalyzeCurrentSong() end } }
  if show_browse then table.insert(buttons, vb:button{ text="Browse XRNS", width=120,
        notifier=function() PakettiXRNSProbeClearText() PakettiXRNSProbeBrowseAndAnalyzeXRNS() end }) end
  table.insert(buttons, vb:button{ text="Save as .TXT", width=120,
        notifier=function()
          local filename = renoise.app():prompt_for_filename_to_write("txt","Save Analysis as Text File")
          if filename then if not filename:match("%.txt$") then filename=filename..".txt" end
            local file=io.open(filename,"w") if file then file:write(results_textfield.text);file:close()
              renoise.app():show_status("Analysis saved to "..filename)
            else renoise.app():show_warning("Failed to save file") end
          end
        end })

  local dialog_content = vb:column{
    vb:horizontal_aligner{ spacing=4, unpack(buttons) },
    vb:multiline_textfield{ id="results", width=777, height=888, font="mono" }
  }
  dialog = renoise.app():show_custom_dialog("Paketti XRNS Probe", dialog_content)
  results_textfield = vb.views.results
  if mode=="Browse" and show_browse then PakettiXRNSProbeBrowseAndAnalyzeXRNS() else PakettiXRNSProbeAnalyzeCurrentSong() end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti XRNS Probe",invoke = pakettiXRNSProbeShowDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:Paketti XRNS Probe",invoke = pakettiXRNSProbeShowDialog}

-- Only add Browse menu entry if show_browse is true
if show_browse then
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:Paketti XRNS Probe (Browse)",invoke=function() pakettiXRNSProbeShowDialog("Browse") end}
end

function MissingDeviceParameters()
  print(renoise.song().selected_device.name)
  for i = 1, #renoise.song().selected_device.parameters do
    print ("renoise.song().selected_device.parameters[" .. i .. "].value=" ..renoise.song().selected_device.parameters[i].value)
  end
end
renoise.tool():add_menu_entry{name="--DSP Device:Paketti..:Query Missing Device for Parameters", invoke=function() MissingDeviceParameters() end}