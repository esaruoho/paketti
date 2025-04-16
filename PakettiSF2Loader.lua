--------------------------------------------------------------------------------
-- SF2 Importer with Detailed Debugging of Panning, Transpose, Fine-Tune, and Key Ranges
--------------------------------------------------------------------------------

local _DEBUG = true
local function dprint(...)
  if _DEBUG then
    print("SF2 Tool:", ...)
  end
end

--------------------------------------------------------------------------------
-- Utility: trim_string, read_u16_le, read_u32_le, read_s16_le
--------------------------------------------------------------------------------
local function trim_string(s)
  return s:gsub("\0", ""):match("^%s*(.-)%s*$")
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

  dprint("Total sample headers (excluding EOS):", #headers)
  return headers
end

--------------------------------------------------------------------------------
-- Step 2: Parse Instrument Zones (INST, IBAG, IGEN)
--------------------------------------------------------------------------------
local function read_instruments(data)
  local pdta_pos = data:find("pdta", 1, true)
  if not pdta_pos then
    dprint("No pdta chunk found for instrument analysis.")
    return {}
  end

  local inst_pos = data:find("inst", pdta_pos + 8, true)
  if not inst_pos then
    dprint("No inst chunk found.")
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
    dprint("No ibag chunk found.")
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
    dprint("No igen chunk found.")
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
        end
      end
      local zone = { params = zone_params }
      -- Key range
      if zone_params[43] then
        local kr = zone_params[43]
        zone.key_range = {
          low = kr % 256,
          high = math.floor(kr / 256) % 256
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

  dprint("Parsed", #instruments, "instruments with zones.")
  return instruments_zones
end

--------------------------------------------------------------------------------
-- Step 3: Parse Presets (PHDR, PBAG, PGEN)
--------------------------------------------------------------------------------
local function read_presets(data)
  local phdr_pos = data:find("phdr", 1, true)
  if not phdr_pos then
    dprint("No phdr chunk found.")
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
    dprint("No pdta chunk available for preset analysis.")
    return presets
  end

  local function read_pbag(data, start_pos)
    local pbag_pos = data:find("pbag", start_pos, true)
    if not pbag_pos then
      dprint("No pbag chunk found.")
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
      dprint("No pgen chunk found.")
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
    dprint("No PBAG/PGEN data; returning basic presets only.")
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
        key_range = { low = kr % 256, high = math.floor(kr / 256) % 256 }
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
    
    dprint("Importing SF2 file:", file_path)

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
    dprint("RIFF header found.")

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
      
      dprint("Preset", preset.name)
      local combined_samples = {}
      for _, zone in ipairs(preset.zones) do
        local assigned_samples = {}
        local zone_params = zone.params or {}

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
                  dprint(string.format("  Instrument %s => Sample %s (SampleID %d)", inst_info.name, hdr.name, izone.sample_id))
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
              dprint(string.format("  KeyRange fallback => Sample %s (pitch %d in range %d-%d)", hdr.name, hdr.orig_pitch, zone.key_range.low, zone.key_range.high))
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
              dprint("  Substring fallback => Sample", hdr.name)
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
        dprint("Preset", preset.name, "has no assigned samples.")
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
      dprint("Created instrument for preset:", r_inst.name)

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
        local frames = hdr.s_end - hdr.s_start
        if frames <= 0 then
          dprint("Skipping sample", hdr.name, "(non-positive frame count).")
        else
          -- Determine if sample is stereo
          local is_stereo = false
          if hdr.sample_link ~= 0 then
            if hdr.sample_type == 0 or hdr.sample_type == 1 then
              is_stereo = true
            else
              dprint("Skipping right stereo channel for", hdr.name)
            
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
          dprint(string.format("Extracted %d frames from sample %s", #sample_data, hdr.name))
          if #sample_data == 0 then
            dprint("Skipping sample", hdr.name, "(zero frames).")
            
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
            dprint("Error creating sample data for", hdr.name, err)
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

            -- Key range - check instrument zone params first, then preset zone params
            local zone_key_range = nil
            local inst_zone_params = smp_entry.inst_zone_params or {}
            
            -- First try instrument zone key range
            if inst_zone_params[43] then
                local kr = inst_zone_params[43]
                local orig_low = kr % 256
                local orig_high = math.floor(kr / 256) % 256
                zone_key_range = {
                    low = clamp(orig_low, 0, 119),
                    high = clamp(orig_high, 0, 119)
                }
                dprint(string.format("KEYRANGE DEBUG for %s:", hdr.name))
                dprint(string.format("  - Found in instrument zone: %d-%d", orig_low, orig_high))
                dprint(string.format("  - Clamped to Renoise range: %d-%d", zone_key_range.low, zone_key_range.high))
            -- Then try preset zone key range
            elseif zone_params[43] then
                local kr = zone_params[43]
                local orig_low = kr % 256
                local orig_high = math.floor(kr / 256) % 256
                zone_key_range = {
                    low = clamp(orig_low, 0, 119),
                    high = clamp(orig_high, 0, 119)
                }
                dprint(string.format("KEYRANGE DEBUG for %s:", hdr.name))
                dprint(string.format("  - Found in preset zone: %d-%d", orig_low, orig_high))
                dprint(string.format("  - Clamped to Renoise range: %d-%d", zone_key_range.low, zone_key_range.high))
            -- Finally fall back to map key range
            else
                if map.key_range then
                    local orig_low = map.key_range.low
                    local orig_high = map.key_range.high
                    zone_key_range = {
                        low = clamp(orig_low, 0, 119),
                        high = clamp(orig_high, 0, 119)
                    }
                    dprint(string.format("KEYRANGE DEBUG for %s:", hdr.name))
                    dprint(string.format("  - Found in map: %d-%d", orig_low, orig_high))
                    dprint(string.format("  - Clamped to Renoise range: %d-%d", zone_key_range.low, zone_key_range.high))
                end
            end

            -- Tuning
            local coarse_tune = 0
            local fine_tune = 0
            
            -- Check instrument zone params first for tuning
            -- Coarse tune (semitones) - Generator ID 51
            if inst_zone_params[51] then
                -- SF2 stores this as a signed 16-bit value directly representing semitones
                local raw_val = inst_zone_params[51]
                if raw_val >= 32768 then
                    coarse_tune = raw_val - 65536  -- Convert to signed
                else
                    coarse_tune = raw_val
                end
                dprint(string.format("TUNING DEBUG for %s:", hdr.name))
                dprint(string.format("  - Coarse tune (semitones) from instrument zone: %d (raw: %d)", coarse_tune, raw_val))
            elseif zone_params[51] then
                local raw_val = zone_params[51]
                if raw_val >= 32768 then
                    coarse_tune = raw_val - 65536  -- Convert to signed
                else
                    coarse_tune = raw_val
                end
                dprint(string.format("TUNING DEBUG for %s:", hdr.name))
                dprint(string.format("  - Coarse tune (semitones) from preset zone: %d (raw: %d)", coarse_tune, raw_val))
            end

            -- Fine tune (cents) - Generator ID 52
            if inst_zone_params[52] then
                -- SF2 stores this as a signed 16-bit value representing cents (-100 to +100)
                local raw_val = inst_zone_params[52]
                if raw_val >= 32768 then
                    fine_tune = raw_val - 65536  -- Convert to signed
                else
                    fine_tune = raw_val
                end
                -- Convert from cents (-100 to +100) to Renoise's fine tune range
                fine_tune = (fine_tune * 100) / 100  -- Scale appropriately
                dprint(string.format("  - Fine tune (cents) from instrument zone: %d (raw: %d)", fine_tune, raw_val))
            elseif zone_params[52] then
                local raw_val = zone_params[52]
                if raw_val >= 32768 then
                    fine_tune = raw_val - 65536  -- Convert to signed
                else
                    fine_tune = raw_val
                end
                -- Convert from cents (-100 to +100) to Renoise's fine tune range
                fine_tune = (fine_tune * 100) / 100  -- Scale appropriately
                dprint(string.format("  - Fine tune (cents) from preset zone: %d (raw: %d)", fine_tune, raw_val))
            end

            -- Add original pitch correction if available
            if hdr.pitch_corr and hdr.pitch_corr ~= 0 then
                fine_tune = fine_tune + hdr.pitch_corr
                dprint(string.format("  - Added pitch correction: %d", hdr.pitch_corr))
            end

            -- Clamp the values to Renoise's valid ranges (-120 to 120 for transpose)
            coarse_tune = clamp(coarse_tune, -120, 120)
            fine_tune = clamp(fine_tune, -100, 100)

            -- Assign the values
            reno_smp.transpose = coarse_tune
            reno_smp.fine_tune = fine_tune
            dprint(string.format("  - Final values: transpose=%d, fine_tune=%d", coarse_tune, fine_tune))

            -- Base note and mapping
            local base_note = hdr.orig_pitch or 60
            reno_smp.sample_mapping.base_note = base_note
            dprint(string.format("  - Base note: %d", base_note))

            -- Pan (SF2 range -120..120 maps proportionally to Renoise 0..1)
            local raw_pan = zone_params[17] or map.fallback_params[17]
            if raw_pan ~= nil then
                -- Get signed value already scaled to -120..120
                local pan_val = to_signed(raw_pan)
                -- Convert to 0..1 range proportionally
                local pan_norm = 0.5 + (pan_val / 120) * 0.5
                reno_smp.panning = pan_norm
            else
                reno_smp.panning = 0.5
            end

            -- Assign mapping
            if zone_key_range then
                reno_smp.sample_mapping.note_range = { zone_key_range.low, zone_key_range.high }
                dprint(string.format("  - Applied note range to sample: %d-%d", zone_key_range.low, zone_key_range.high))
            else
                if is_drumkit then
                    -- We'll map them after removing placeholder
                    reno_smp.sample_mapping.note_range = { base_note, base_note }
                    dprint(string.format("  - Drumkit: mapped to single note %d", base_note))
                else
                    -- full range for melodic
                    reno_smp.sample_mapping.note_range = {0, 119}
                    dprint("  - No key range found, using full range 0-119")
                end
            end

            -- Loop handling
            if not is_drumkit then
              if frames < 512 and (hdr.loop_end > hdr.loop_start) then
                local l_start = hdr.loop_start - hdr.s_start
                local l_end   = hdr.loop_end - hdr.s_start
                if l_start <= 0 then l_start=1 end
                if l_end > #sample_data then l_end=#sample_data end
                reno_smp.loop_mode  = renoise.Sample.LOOP_MODE_FORWARD
                reno_smp.loop_start = l_start
                reno_smp.loop_end   = l_end
                dprint("Short sample => forced loop", hdr.name, l_start, l_end)
              elseif hdr.loop_start == hdr.s_start and hdr.loop_end == hdr.s_end then
                reno_smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
                dprint("No valid loop => disabled for", hdr.name)
              else
                local l_start = hdr.loop_start - hdr.s_start
                local l_end   = hdr.loop_end - hdr.s_start
                if l_start <= 0 then l_start=1 end
                if l_end > #sample_data then l_end=#sample_data end
                if l_end > l_start then
                  reno_smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
                  reno_smp.loop_start = l_start
                  reno_smp.loop_end   = l_end
                  dprint("Set loop for", hdr.name, l_start, l_end)
                else
                  reno_smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
                  dprint("Invalid loop => disabled for", hdr.name)
                end
              end
            end
          end
        end
        
        coroutine.yield()
      end

      -- If drumkit => remove placeholder and map each sample to one discrete note
      if is_drumkit then
        if #r_inst.samples > 1 then
          dprint("Drum preset: removing placeholder sample #1 ("..r_inst.samples[1].name..")")
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
  dprint("Removed old SF2 Import Hook")
end

local hook = {
  category = "sample",
  extensions = {"sf2"},
  invoke = import_sf2
}

if not renoise.tool():has_file_import_hook("sample", {"sf2"}) then
  renoise.tool():add_file_import_hook(hook)
  dprint("Added SF2 Import Hook")
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
