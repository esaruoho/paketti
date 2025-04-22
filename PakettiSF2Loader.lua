--------------------------------------------------------------------------------
-- SF2 Importer with Detailed Debugging of Panning, Transpose, Fine-Tune, and Key Ranges
--------------------------------------------------------------------------------

local _DEBUG = true
local function dprint(...)
  if _DEBUG then
    print("SF2 Tool:", ...)
  end
end

-- Convert a 16-bit unsigned generator value to a signed integer
local function to_signed(val)
  -- First ensure val is in 0-65535 range
  val = val % 65536
  -- Then convert to signed, but scale it to -120..120 range
  if val >= 32768 then
    -- Scale negative range from -120 to 0
    local neg = val - 65536  -- This gives us -32768 to -1
    return (neg * 120) / 32768
  else
    -- Scale positive range from 0 to 120
    return (val * 120) / 32768
  end
end

-- SF2 Parameter name mapping
local SF2_PARAM_NAMES = {
    [0] = "StartAddrsOffset",
    [1] = "EndAddrsOffset",
    [2] = "StartloopAddrsOffset",
    [3] = "EndloopAddrsOffset",
    [4] = "StartAddrsCoarseOffset",
    [5] = "ModLFO_to_Pitch",
    [6] = "VibLFO_to_Pitch",
    [7] = "ModEnv_to_Pitch",
    [8] = "InitialFilterFC",
    [9] = "InitialFilterQ",
    [10] = "ModLFO_to_FilterFC",
    [11] = "ModEnv_to_FilterFC",
    [12] = "EndAddrsCoarseOffset",
    [13] = "ModLFO_to_Volume",
    [15] = "ChorusEffectsSend",
    [16] = "ReverbEffectsSend",
    [17] = "Pan",
    [21] = "ModLFO_Delay",
    [22] = "ModLFO_Freq",
    [23] = "VibLFO_Delay",
    [24] = "VibLFO_Freq",
    [25] = "ModEnv_Delay",
    [26] = "ModEnv_Attack",
    [27] = "ModEnv_Hold",
    [28] = "ModEnv_Decay",
    [29] = "ModEnv_Sustain",
    [30] = "ModEnv_Release",
    [31] = "Key_to_ModEnvHold",
    [32] = "Key_to_ModEnvDecay",
    [33] = "VolEnv_Delay",
    [34] = "VolEnv_Attack",
    [35] = "VolEnv_Hold",
    [36] = "VolEnv_Decay",
    [37] = "VolEnv_Sustain",
    [38] = "VolEnv_Release",
    [39] = "Key_to_VolEnvHold",
    [40] = "Key_to_VolEnvDecay",
    [41] = "Instrument",
    [43] = "KeyRange",
    [44] = "VelRange",
    [45] = "StartloopAddrsCoarse",
    [46] = "Keynum",
    [47] = "Velocity",
    [48] = "InitialAttenuation",
    [50] = "EndloopAddrsCoarse",
    [51] = "CoarseTune",
    [52] = "FineTune",
    [53] = "SampleID",
    [54] = "SampleModes",
    [56] = "ScaleTuning",
    [57] = "ExclusiveClass",
    [58] = "OverridingRootKey"
}

-- Helper function to format parameter value based on its type
local function format_param_value(param_id, value)
    if param_id == 43 then -- KeyRange
        local low = value % 256
        local high = math.floor(value / 256) % 256
        return string.format("%d-%d", low, high)
    elseif param_id == 54 then -- SampleModes
        local modes = {"None", "Loop", "LoopBidi"}
        return modes[value + 1] or "Unknown"
    elseif param_id == 17 then -- Pan
        local pan_val = to_signed(value)
        return string.format("%d", pan_val)
    elseif param_id == 51 or param_id == 52 then -- Tuning
        if value >= 32768 then
            return tostring(value - 65536)
        end
        return tostring(value)
    else
        return tostring(value)
    end
end

--------------------------------------------------------------------------------
-- Utility: trim_string, read_u16_le, read_u32_le, read_s16_le
--------------------------------------------------------------------------------
local function trim_string(s)
  return s:gsub("\0", ""):match("^%s*(.-)%s*$")
end

-- Helper function to get MIDI note name
local function get_note_name(midi_note)
    local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local octave = math.floor(midi_note / 12) - 1
    local note_index = (midi_note % 12) + 1
    return string.format("%s%d", notes[note_index], octave)
end

local function read_u16_le(data, pos)
  local b1 = data:byte(pos)
  local b2 = data:byte(pos+1)
  return b1 + b2*256
end

local function read_u32_le(data, pos)
  local b1 = data:byte(pos)
  local b2 = data:byte(pos+1)
  local b3 = data:byte(pos+2)
  local b4 = data:byte(pos+3)
  return b1 + b2*256 + b3*65536 + b4*16777216
end

local function read_s16_le(data, pos)
  local val = read_u16_le(data, pos)
  if val >= 32768 then
    return val - 65536
  else
    return val
  end
end

-- Clamp a value between min and max
local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--------------------------------------------------------------------------------
-- Step 1: Read Sample Headers (SHDR)
--------------------------------------------------------------------------------
local function read_sample_headers(data)
  local shdr_pos = data:find("shdr", 1, true)
  if not shdr_pos then
    renoise.app():show_error("SF2 file missing 'shdr' chunk.")
    return nil
  end

  local shdr_size = read_u32_le(data, shdr_pos + 4)
  local shdr_data_start = shdr_pos + 8
  local record_size = 46
  local headers = {}

  local pos = shdr_data_start
  while (pos + record_size - 1) <= (shdr_data_start + shdr_size - 1) do
    local sample_name = data:sub(pos, pos + 19)
    pos = pos + 20
    local s_start = read_u32_le(data, pos) ; pos = pos + 4
    local s_end   = read_u32_le(data, pos) ; pos = pos + 4
    local loop_start = read_u32_le(data, pos) ; pos = pos + 4
    local loop_end   = read_u32_le(data, pos) ; pos = pos + 4
    local sample_rate = read_u32_le(data, pos) ; pos = pos + 4
    local orig_pitch  = data:byte(pos) ; pos = pos + 1
    local pitch_corr  = data:byte(pos) ; pos = pos + 1
    if pitch_corr >= 128 then pitch_corr = pitch_corr - 256 end
    local sample_link = read_u16_le(data, pos) ; pos = pos + 2
    local sample_type = read_u16_le(data, pos) ; pos = pos + 2

    local name = trim_string(sample_name)
    if name:find("EOS") then break end

    headers[#headers + 1] = {
      name        = name,
      s_start     = s_start,
      s_end       = s_end,
      loop_start  = loop_start,
      loop_end    = loop_end,
      sample_rate = sample_rate,
      orig_pitch  = orig_pitch,
      pitch_corr  = pitch_corr,
      sample_link = sample_link,
      sample_type = sample_type,
    }
  end

  print("Total sample headers (excluding EOS): " .. #headers)
  return headers
end

--------------------------------------------------------------------------------
-- Step 2: Parse Instrument Zones (INST, IBAG, IGEN)
--------------------------------------------------------------------------------
local function read_instruments(data)
  local pdta_pos = data:find("pdta", 1, true)
  if not pdta_pos then
    print("No pdta chunk found for instrument analysis.")
    return {}
  end

  local inst_pos = data:find("inst", pdta_pos + 8, true)
  if not inst_pos then
    print("No inst chunk found.")
    return {}
  end

  local inst_size = read_u32_le(data, inst_pos + 4)
  local inst_data_start = inst_pos + 8
  local inst_record_size = 22
  local instruments = {}

  local pos = inst_data_start
  while (pos + inst_record_size - 1) <= (inst_data_start + inst_size - 1) do
    local inst_name = trim_string(data:sub(pos, pos + 19))
    local bag_index = read_u16_le(data, pos + 20)
    instruments[#instruments + 1] = { name = inst_name, bag_index = bag_index }
    pos = pos + inst_record_size
  end

  local ibag_pos = data:find("ibag", pdta_pos + 8, true)
  if not ibag_pos then
    print("No ibag chunk found.")
    return instruments
  end

  local ibag_size = read_u32_le(data, ibag_pos + 4)
  local ibag_data_start = ibag_pos + 8
  local ibag_record_size = 4
  local ibags = {}

  pos = ibag_data_start
  while (pos + ibag_record_size - 1) <= (ibag_data_start + ibag_size - 1) do
    local gen_index = read_u16_le(data, pos)
    local mod_index = read_u16_le(data, pos + 2)
    ibags[#ibags + 1] = { gen_index = gen_index, mod_index = mod_index }
    pos = pos + ibag_record_size
  end

  local igen_pos = data:find("igen", pdta_pos + 8, true)
  if not igen_pos then
    print("No igen chunk found.")
    return instruments
  end

  local igen_size = read_u32_le(data, igen_pos + 4)
  local igen_data_start = igen_pos + 8
  local igen_record_size = 4
  local igens = {}

  pos = igen_data_start
  while (pos + igen_record_size - 1) <= (igen_data_start + igen_size - 1) do
    local op = read_u16_le(data, pos)
    local amount = read_u16_le(data, pos + 2)
    igens[#igens + 1] = { op = op, amount = amount }
    pos = pos + igen_record_size
  end

  local instruments_zones = {}
  for i, inst in ipairs(instruments) do
    local zones = {}
    local bag_start = inst.bag_index + 1
    local bag_end = #ibags
    if i < #instruments then
      bag_end = instruments[i + 1].bag_index
    end
    for b = bag_start, bag_end do
      local bag = ibags[b]
      local zone_params = {}
      local gen_start = bag.gen_index + 1
      local gen_end = #igens
      if b < #ibags then
        gen_end = ibags[b + 1].gen_index
      end
      for g = gen_start, gen_end do
        local gen = igens[g]
        if gen then
          zone_params[gen.op] = gen.amount
          print("Found instrument param: op=" .. gen.op .. ", amount=" .. gen.amount)
        end
      end
      local zone = { params = zone_params }
      -- Key range
      if zone_params[43] then
        local kr = zone_params[43]
        local orig_low = kr % 256
        local orig_high = math.floor(kr / 256) % 256
        -- Clamp values to 0-119 range
        zone.key_range = {
          low = math.min(119, math.max(0, orig_low)),
          high = math.min(119, math.max(0, orig_high))
        }
      end
      -- Velocity range
      if zone_params[42] then
        local vr = zone_params[42]
        zone.vel_range = {
          low = vr % 256,
          high = math.floor(vr / 256) % 256
        }
      end
      -- Sample ID
      if zone_params[53] then
        zone.sample_id = zone_params[53]  -- 0-based index
      end
      zones[#zones + 1] = zone
    end
    instruments_zones[i] = { name = inst.name, zones = zones }
  end

  print("Parsed " .. #instruments .. " instruments with zones.")
  return instruments_zones
end

--------------------------------------------------------------------------------
-- Step 3: Parse Presets (PHDR, PBAG, PGEN)
--------------------------------------------------------------------------------
local function read_presets(data)
  local phdr_pos = data:find("phdr", 1, true)
  if not phdr_pos then
    print("No phdr chunk found.")
    return {}
  end

  local phdr_size = read_u32_le(data, phdr_pos + 4)
  local phdr_data_start = phdr_pos + 8
  local phdr_record_size = 38
  local presets = {}

  local pos = phdr_data_start
  while (pos + phdr_record_size - 1) <= (phdr_data_start + phdr_size - 1) do
    local preset_name = trim_string(data:sub(pos, pos+19))
    local preset = read_u16_le(data, pos+20)
    local bank = read_u16_le(data, pos+22)
    local pbag_idx = read_u16_le(data, pos+24)
    if preset_name:find("EOP") then break end
    presets[#presets + 1] = {
      name = preset_name,
      preset = preset,
      bank = bank,
      pbag_index = pbag_idx,
      zones = {}
    }
    pos = pos + phdr_record_size
  end

  local pdta_pos = data:find("pdta", 1, true)
  if not pdta_pos then
    print("No pdta chunk available for preset analysis.")
    return presets
  end

  local function read_pbag(data, start_pos)
    local pbag_pos = data:find("pbag", start_pos, true)
    if not pbag_pos then
      print("No pbag chunk found.")
      return {}
    end
    local pbag_size = read_u32_le(data, pbag_pos + 4)
    local pbag_data_start = pbag_pos + 8
    local record_size = 4
    local pbag_list = {}
    local pos = pbag_data_start
    while (pos + record_size -1) <= (pbag_data_start + pbag_size -1) do
      local pgen_idx = read_u16_le(data, pos)
      local pmod_idx = read_u16_le(data, pos+2)
      pbag_list[#pbag_list + 1] = { pgen_index = pgen_idx, pmod_index = pmod_idx }
      pos = pos + record_size
    end
    return pbag_list
  end

  local function read_pgen(data, start_pos)
    local pgen_pos = data:find("pgen", start_pos, true)
    if not pgen_pos then
      print("No pgen chunk found.")
      return {}
    end
    local pgen_size = read_u32_le(data, pgen_pos + 4)
    local pgen_data_start = pgen_pos + 8
    local record_size = 4
    local pgen_list = {}
    local pos = pgen_data_start
    while (pos + record_size -1) <= (pgen_data_start + pgen_size -1) do
      local op = read_u16_le(data, pos)
      local amount = read_u16_le(data, pos+2)
      pgen_list[#pgen_list + 1] = { op = op, amount = amount }
      pos = pos + record_size
    end
    return pgen_list
  end

  local pbag = read_pbag(data, pdta_pos + 8)
  local pgen = read_pgen(data, pdta_pos + 8)
  if (#pbag == 0) or (#pgen == 0) then
    print("No PBAG/PGEN data; returning basic presets only.")
    return presets
  end

  for i, preset in ipairs(presets) do
    local zone_start = preset.pbag_index + 1
    local zone_end   = #pbag
    if i < #presets then
      zone_end = presets[i+1].pbag_index
    end
    for z = zone_start, zone_end do
      local bag = pbag[z]
      local zone_params = {}
      local pgen_start = bag.pgen_index + 1
      local pgen_end   = #pgen
      if z < #pbag then
        pgen_end = pbag[z+1].pgen_index
      end
      for pg = pgen_start, pgen_end do
        local gen = pgen[pg]
        if gen then
          zone_params[gen.op] = gen.amount
        end
      end
      local key_range = nil
      if zone_params[43] then
        local kr = zone_params[43]
        local low = kr % 256
        local high = math.floor(kr / 256) % 256
        -- Clamp values to 0-119 range
        low = math.min(119, math.max(0, low))
        high = math.min(119, math.max(0, high))
        key_range = { low = low, high = high }
      end
      preset.zones[#preset.zones + 1] = {
        params = zone_params,
        key_range = key_range
      }
    end
  end

  return presets
end

--------------------------------------------------------------------------------
-- Step 4: Import SF2
--------------------------------------------------------------------------------
local function import_sf2(file_path)
  -- Create a ProcessSlicer to handle the import
  local slicer = nil
  
  local function process_import()
    local dialog, vb = nil, nil
    dialog, vb = slicer:create_dialog("Importing SF2...")
    
    print("Importing SF2 file: " .. file_path)

    local f = io.open(file_path, "rb")
    if not f then
      renoise.app():show_error("Could not open SF2 file: " .. file_path)
      return false
    end
    local data = f:read("*all")
    f:close()

    if data:sub(1,4) ~= "RIFF" then
      renoise.app():show_error("Invalid SF2 file (missing RIFF header).")
      return false
    end
    print("RIFF header found.")

    local smpl_pos = data:find("smpl", 1, true)
    if not smpl_pos then
      renoise.app():show_error("SF2 file missing 'smpl' chunk.")
      return false
    end
    local smpl_data_start = smpl_pos + 8

    -- Read SF2 components:
    if vb then vb.views.progress_text.text = "Reading sample headers..." end
    coroutine.yield()
    
    local headers = read_sample_headers(data)
    if not headers or #headers == 0 then
      renoise.app():show_error("No sample headers found in SF2.")
      return false
    end

    if vb then vb.views.progress_text.text = "Reading instruments..." end
    coroutine.yield()
    
    local instruments_zones = read_instruments(data)
    
    if vb then vb.views.progress_text.text = "Reading presets..." end
    coroutine.yield()
    
    local presets = read_presets(data)
    if #presets == 0 then
      renoise.app():show_error("No presets found in SF2.")
      return false
    end

    -- Build a mapping: one XRNI instrument per preset
    local mappings = {}

    if vb then vb.views.progress_text.text = "Processing presets..." end
    coroutine.yield()

    for _, preset in ipairs(presets) do
      if slicer:was_cancelled() then
        return false
      end
      
      print("Preset " .. preset.name)
      local combined_samples = {}
      for _, zone in ipairs(preset.zones) do
        local assigned_samples = {}
        local zone_params = zone.params or {}

        print("Processing preset zone params:")
        for k,v in pairs(zone_params) do
            print("  [" .. k .. "] = " .. v)
        end

        -- If there's an assigned instrument
        if zone_params[41] then
          local inst_idx = zone_params[41] + 1
          local inst_info = instruments_zones[inst_idx]
          if inst_info and inst_info.zones then
            for _, izone in ipairs(inst_info.zones) do
              if izone.sample_id then
                local hdr_idx = izone.sample_id + 1
                local hdr = headers[hdr_idx]
                if hdr then
                  print("  Instrument " .. inst_info.name .. " => Sample " .. hdr.name .. " (SampleID " .. izone.sample_id .. ")")
                  print("  Instrument zone params:")
                  for k,v in pairs(izone.params or {}) do
                      print("    [" .. k .. "] = " .. v)
                  end
                  assigned_samples[#assigned_samples+1] = {
                    header = hdr,
                    zone_params = zone_params,
                    inst_zone_params = izone.params
                  }
                end
              end
            end
          end
        end

        -- Fallback: key_range from the preset zone
        if #assigned_samples == 0 and zone.key_range then
          for _, hdr in ipairs(headers) do
            if hdr.orig_pitch >= zone.key_range.low and hdr.orig_pitch <= zone.key_range.high then
              print("  KeyRange fallback => Sample " .. hdr.name .. " (pitch " .. hdr.orig_pitch .. " in range " .. zone.key_range.low .. "-" .. zone.key_range.high .. ")")
              assigned_samples[#assigned_samples+1] = {
                header = hdr,
                zone_params = zone_params
              }
            end
          end
        end

        -- Substring fallback if we still have no assigned samples
        if #assigned_samples == 0 then
          for _, hdr in ipairs(headers) do
            if hdr.name:lower():find(preset.name:lower()) then
              print("  Substring fallback => Sample " .. hdr.name)
              assigned_samples[#assigned_samples+1] = {
                header = hdr,
                zone_params = zone_params
              }
            end
          end
        end

        for _, smp_entry in ipairs(assigned_samples) do
          combined_samples[#combined_samples+1] = smp_entry
        end
      end

      if #combined_samples > 0 then
        mappings[#mappings+1] = {
          preset_name = preset.name,
          bank = preset.bank,
          preset_num = preset.preset,
          samples = combined_samples,
          fallback_params = (preset.zones[#preset.zones] and preset.zones[#preset.zones].params) or {},
          key_range = (preset.zones[#preset.zones] and preset.zones[#preset.zones].key_range)
        }
      else
        print("Preset " .. preset.name .. " has no assigned samples.")
      end
      
      coroutine.yield()
    end

    if #mappings == 0 then
      renoise.app():show_error("No preset with assigned samples.")
      return false
    end

    local song = renoise.song()

    -- Process each mapping
    for map_idx, map in ipairs(mappings) do
      if slicer:was_cancelled() then
        return false
      end
      
      if vb then 
        vb.views.progress_text.text = string.format(
          "Creating instrument %d/%d: %s", 
          map_idx, #mappings, map.preset_name)
      end
      
      local is_drumkit = (map.bank == 128)
      local preset_file = is_drumkit and
        (renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni") or
        "Presets/12st_Pitchbend.xrni"

      song:insert_instrument_at(song.selected_instrument_index + 1)
      song.selected_instrument_index = song.selected_instrument_index + 1
      renoise.app():load_instrument(preset_file)

      local r_inst = song.selected_instrument
      if not r_inst then
        renoise.app():show_error("Failed to load XRNI preset for " .. map.preset_name)
        return false
      end

      r_inst.name = string.format("%s (Bank %d, Preset %d)", map.preset_name, map.bank, map.preset_num)
      print("Created instrument for preset: " .. r_inst.name)

      local is_first_overwritten = false

      -- Process samples for this mapping
      for smp_idx, smp_entry in ipairs(map.samples) do
        if slicer:was_cancelled() then
          return false
        end
        
        if vb then 
          vb.views.progress_text.text = string.format(
            "Processing sample %d/%d in %s", 
            smp_idx, #map.samples, map.preset_name)
        end
        
        local hdr = smp_entry.header
        local zone_params = smp_entry.zone_params or {}
        local inst_zone_params = smp_entry.inst_zone_params or {}
        local frames = hdr.s_end - hdr.s_start
        if frames <= 0 then
          print("Skipping sample " .. hdr.name .. " (non-positive frame count).")
        else
          -- Determine if sample is stereo
          local is_stereo = false
          if hdr.sample_link ~= 0 then
            if hdr.sample_type == 0 or hdr.sample_type == 1 then
              is_stereo = true
            else
              print("Skipping right stereo channel for " .. hdr.name)
            
            end
          end

          -- Load sample data
          local sample_data = {}
          if is_stereo then
            for f_i = hdr.s_start + 1, hdr.s_end do
              local offset = smpl_data_start + (f_i - 1) * 4
              if offset + 3 <= #data then
                local left_val  = read_s16_le(data, offset)
                local right_val = read_s16_le(data, offset + 2)
                sample_data[#sample_data+1] = { left = left_val/32768.0, right = right_val/32768.0 }
              end
              -- Yield every 100,000 frames
              if f_i % 100000 == 0 then coroutine.yield() end
            end
          else
            for f_i = hdr.s_start + 1, hdr.s_end do
              local offset = smpl_data_start + (f_i - 1) * 2
              if offset + 1 <= #data then
                local raw_val = read_s16_le(data, offset)
                sample_data[#sample_data+1] = raw_val / 32768.0
              end
              -- Yield every 100,000 frames
              if f_i % 100000 == 0 then coroutine.yield() end
            end
          end
          print("Extracted " .. #sample_data .. " frames from sample " .. hdr.name)
          if #sample_data == 0 then
            print("Skipping sample " .. hdr.name .. " (zero frames).")
            
          end

          local sample_slot = nil
          if not is_drumkit then
            if not is_first_overwritten and #r_inst.samples > 0 then
              sample_slot = 1
              is_first_overwritten = true
            else
              sample_slot = #r_inst.samples + 1
              r_inst:insert_sample_at(sample_slot)
            end
          else
            sample_slot = #r_inst.samples + 1
            r_inst:insert_sample_at(sample_slot)
          end

          local reno_smp = r_inst.samples[sample_slot]
          local success, err = pcall(function()
            if is_stereo then
              reno_smp.sample_buffer:create_sample_data(hdr.sample_rate, 16, 2, #sample_data)
            else
              reno_smp.sample_buffer:create_sample_data(hdr.sample_rate, 16, 1, #sample_data)
            end
          end)
          if not success then
            print("Error creating sample data for " .. hdr.name .. ": " .. err)
          else
            -- Fill sample buffer
            local buf = reno_smp.sample_buffer
            if is_stereo then
              for f_i=1, #sample_data do
                buf:set_sample_data(1, f_i, sample_data[f_i].left)
                buf:set_sample_data(2, f_i, sample_data[f_i].right)
                -- Yield every 100,000 frames
                if f_i % 100000 == 0 then coroutine.yield() end
              end
            else
              for f_i=1, #sample_data do
                buf:set_sample_data(1, f_i, sample_data[f_i])
                -- Yield every 100,000 frames
                if f_i % 100000 == 0 then coroutine.yield() end
              end
            end
            reno_smp.name = hdr.name

            -- Get parameters from both instrument and preset zones
            local inst_zone_params = smp_entry.inst_zone_params or {}
            local zone_params = smp_entry.zone_params or {}

            -- Debug the actual parameters we got
            print("DEBUG RAW PARAMS for " .. hdr.name .. ":")
            print("  Instrument zone params:")
            for k,v in pairs(inst_zone_params) do
                local param_name = SF2_PARAM_NAMES[k] or "Unknown"
                local formatted_value = format_param_value(k, v)
                print(string.format("    [%d:%s] = %s", k, param_name, formatted_value))
            end
            print("  Preset zone params:")
            for k,v in pairs(zone_params) do
                local param_name = SF2_PARAM_NAMES[k] or "Unknown"
                local formatted_value = format_param_value(k, v)
                print(string.format("    [%d:%s] = %s", k, param_name, formatted_value))
            end

            -- Initialize debug strings
            local tuning_info = {}
            local loop_info = {}
            local envelope_info = {}

            -- Tuning parameters
            local coarse_tune = 0
            local fine_tune = 0
            local tuning_source = "none"
            local raw_coarse = 0
            local raw_fine = 0
            
            -- Get tuning values
            if inst_zone_params[51] then
                tuning_source = "instrument"
                raw_coarse = inst_zone_params[51]
                coarse_tune = (raw_coarse >= 32768) and (raw_coarse - 65536) or raw_coarse
            elseif zone_params[51] then
                tuning_source = "preset"
                raw_coarse = zone_params[51]
                coarse_tune = (raw_coarse >= 32768) and (raw_coarse - 65536) or raw_coarse
            end

            if inst_zone_params[52] then
                raw_fine = inst_zone_params[52]
                fine_tune = (raw_fine >= 32768) and (raw_fine - 65536) or raw_fine
                fine_tune = (fine_tune * 100) / 100
            elseif zone_params[52] then
                raw_fine = zone_params[52]
                fine_tune = (raw_fine >= 32768) and (raw_fine - 65536) or raw_fine
                fine_tune = (fine_tune * 100) / 100
            end

            -- Apply pitch correction if available
            if hdr.pitch_corr and hdr.pitch_corr ~= 0 then
                fine_tune = fine_tune + hdr.pitch_corr
            end

            -- Clamp tuning values to valid ranges
            coarse_tune = clamp(coarse_tune, -120, 120)
            fine_tune = clamp(fine_tune, -100, 100)

            -- Pan (SF2 range -120..120 maps proportionally to Renoise 0..1)
            local raw_pan = inst_zone_params[17] or zone_params[17] or map.fallback_params[17]
            if raw_pan ~= nil then
                -- Get signed value already scaled to -120..120
                local pan_val = to_signed(raw_pan)
                -- Convert to 0..1 range proportionally
                local pan_norm = 0.5 + (pan_val / 120) * 0.5
                reno_smp.panning = pan_norm
            else
                reno_smp.panning = 0.5
            end

            -- Loop handling
            local loop_mode = "none"
            local loop_start_rel = hdr.loop_start - hdr.s_start
            local loop_end_rel = hdr.loop_end - hdr.s_start
            local loop_length = 0

            if not is_drumkit then
                if loop_start_rel <= 0 then loop_start_rel = 1 end
                if loop_end_rel > #sample_data then loop_end_rel = #sample_data end

                if loop_end_rel > loop_start_rel then
                    reno_smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
                    reno_smp.loop_start = loop_start_rel
                    reno_smp.loop_end = loop_end_rel
                    loop_mode = frames < 512 and "forced" or "normal"
                    loop_length = loop_end_rel - loop_start_rel
                else
                    reno_smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
                end
            end

            -- Key range handling
            local key_range_source = "none"
            local key_range_low = 0
            local key_range_high = 119
            local zone_key_range = nil

            if inst_zone_params[43] then
                key_range_source = "instrument"
                local kr = inst_zone_params[43]
                local orig_low = kr % 256
                local orig_high = math.floor(kr / 256) % 256
                key_range_low = math.min(119, math.max(0, orig_low))
                key_range_high = math.min(119, math.max(0, orig_high))
                zone_key_range = { low = key_range_low, high = key_range_high }
            elseif zone_params[43] then
                key_range_source = "preset"
                local kr = zone_params[43]
                local orig_low = kr % 256
                local orig_high = math.floor(kr / 256) % 256
                key_range_low = math.min(119, math.max(0, orig_low))
                key_range_high = math.min(119, math.max(0, orig_high))
                zone_key_range = { low = key_range_low, high = key_range_high }
            elseif map.key_range then
                key_range_source = "map"
                local orig_low = map.key_range.low
                local orig_high = map.key_range.high
                key_range_low = math.min(119, math.max(0, orig_low))
                key_range_high = math.min(119, math.max(0, orig_high))
                zone_key_range = { low = key_range_low, high = key_range_high }
            end

            -- Apply the key range to the sample mapping
            local base_note = hdr.orig_pitch or 60
            -- Clamp base_note to valid range (0-108, where 108 is C-9)
            base_note = math.min(108, math.max(0, base_note))
            reno_smp.sample_mapping.base_note = base_note

            if zone_key_range then
                -- Clamp key range to valid range (0-119)
                local low = math.min(119, math.max(0, zone_key_range.low))
                local high = math.min(119, math.max(0, zone_key_range.high))
                reno_smp.sample_mapping.note_range = { low, high }
            else
                if is_drumkit then
                    reno_smp.sample_mapping.note_range = { base_note, base_note }
                else
                    reno_smp.sample_mapping.note_range = { 0, 119 }
                end
            end

            -- Print comprehensive debug info
            print("TUNING DEBUG for " .. hdr.name .. ": source=" .. tuning_source .. 
                  ", coarse=" .. raw_coarse .. "->" .. coarse_tune .. 
                  ", fine=" .. raw_fine .. "->" .. fine_tune .. 
                  ", pitch_corr=" .. (hdr.pitch_corr or 0))

            print("KEYRANGE DEBUG for " .. hdr.name .. ": source=" .. key_range_source .. 
                  ", range=" .. key_range_low .. "-" .. key_range_high)

            print("LOOP DEBUG for " .. hdr.name .. ": mode=" .. loop_mode .. 
                  ", orig_start=" .. hdr.loop_start .. ", orig_end=" .. hdr.loop_end .. 
                  ", rel_start=" .. loop_start_rel .. ", rel_end=" .. loop_end_rel .. 
                  ", length=" .. loop_length)

            print("PANNING DEBUG for " .. hdr.name .. ": source=" .. (raw_pan and "instrument" or "preset") .. 
                  ", value=" .. (raw_pan and to_signed(raw_pan) or 0))

            -- Apply all values to the sample
            reno_smp.transpose = coarse_tune
            reno_smp.fine_tune = fine_tune
          end
        end
        
        coroutine.yield()
      end

      -- If drumkit => remove placeholder and map each sample to one discrete note
      if is_drumkit then
        if #r_inst.samples > 1 then
          print("Drum preset: removing placeholder sample #1 (" .. r_inst.samples[1].name .. ")")
          r_inst:delete_sample_at(1)
        end
        for i_smp=1, #r_inst.samples do
          local s = r_inst.samples[i_smp]
          local note = i_smp - 1
          s.sample_mapping.note_range = { note, note }
          s.sample_mapping.base_note  = note
        end
      end
      
      coroutine.yield()
    end

    if dialog and dialog.visible then
      dialog:close()
    end
    
    renoise.app():show_status("SF2 import complete. See console for debug details.")
    return true
  end
  
  -- Create and start the ProcessSlicer
  slicer = ProcessSlicer(process_import)
  slicer:start()
end

--------------------------------------------------------------------------------
-- Dummy multitimbral
--------------------------------------------------------------------------------
local function import_sf2_multitimbral(filepath)
  renoise.app():show_error("Multitimbral import not implemented.")
  return false
end

--------------------------------------------------------------------------------
-- Register
--------------------------------------------------------------------------------
if renoise.tool():has_file_import_hook("sample", {"sf2"}) then
  renoise.tool():remove_file_import_hook("sample", {"sf2"})
  print("Removed old SF2 Import Hook")
end

local hook = {
  category = "sample",
  extensions = {"sf2"},
  invoke = import_sf2
}

if not renoise.tool():has_file_import_hook("sample", {"sf2"}) then
  renoise.tool():add_file_import_hook(hook)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Import SF2 (Single XRNI per Preset)",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import")
    if f and f ~= "" then import_sf2(f) end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Import SF2 (Multitimbral)",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import (multitimbral)")
    if f and f ~= "" then import_sf2_multitimbral(f) end
  end
}

-- Helper function to find or create Volume AHDSR device
local function setup_volume_ahdsr_device(instrument, sample_index)
    -- Ensure we have a modulation set
    if #instrument.sample_modulation_sets == 0 then
        instrument:insert_sample_modulation_set_at(1)
    end
    
    -- Get the modulation set for this sample
    local mod_set_index = instrument.samples[sample_index].modulation_set_index
    local mod_set = instrument.sample_modulation_sets[mod_set_index]
    
    -- Find existing Volume AHDSR device or create new one
    local ahdsr_device = nil
    for _, device in ipairs(mod_set.devices) do
        if device.name == "Volume AHDSR" then
            ahdsr_device = device
            break
        end
    end
    
    if not ahdsr_device then
        -- Create new Volume AHDSR device
        local device_index = #mod_set.devices + 1
        mod_set:insert_device_at("Volume AHDSR", device_index)
        ahdsr_device = mod_set.devices[device_index]
    end
    
    return ahdsr_device
end

-- Helper function to convert timecents to seconds
local function timecents_to_seconds(timecents)
    if timecents then
        -- Convert unsigned to signed if needed
        if timecents >= 32768 then 
            timecents = timecents - 65536
        end
        -- Convert timecents to seconds: seconds = 2^(timecents/1200)
        return 2^(timecents/1200)
    end
    return nil
end

-- Helper function to convert sustain centibels to 0-1 range
local function sustain_cb_to_level(centibels)
    if centibels then
        -- Convert centibels to decibels (divide by 10)
        local db = centibels / 10
        -- Convert dB to linear (0-1) scale
        return math.min(1, math.max(0, math.db2lin(db)))
    end
    return nil
end

-- Helper function to map envelope time to Renoise parameter range (0-1)
local function map_envelope_time(seconds)
    if not seconds then return nil end
    -- Renoise's envelope time parameters are mapped 0-1 to 0-20 seconds
    return math.min(1, math.max(0, seconds / 20))
end
