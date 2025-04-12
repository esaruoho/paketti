--------------------------------------------------------------------------------
-- Advanced SF2 Importer for Renoise
-- Single XRNI per preset, merges multiple SF2 instruments if needed.
-- Drum presets (bank == 128) get one-sample-per-key mapping (C-0, C#0, D-0, etc.)
--------------------------------------------------------------------------------

local _DEBUG = true
local function dprint(...)
  if _DEBUG then print("SF2 Tool:", ...) end
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
  if val >= 32768 then return val - 65536 else return val end
end

--------------------------------------------------------------------------------
-- Step 1: Read SHDR (Sample Headers)
--------------------------------------------------------------------------------
local function read_sample_headers(data)
  local shdr_pos = data:find("shdr", 1, true)
  if not shdr_pos then
    renoise.app():show_error("SF2 file missing 'shdr' chunk")
    return nil
  end
  local shdr_size = read_u32_le(data, shdr_pos + 4)
  local shdr_data_start = shdr_pos + 8
  local record_size = 46
  local headers = {}
  local pos = shdr_data_start
  while pos + record_size - 1 <= shdr_data_start + shdr_size - 1 do
    local sample_name = data:sub(pos, pos+19)
    pos = pos + 20
    local s_start = read_u32_le(data, pos); pos=pos+4
    local s_end   = read_u32_le(data, pos); pos=pos+4
    local loop_start = read_u32_le(data, pos); pos=pos+4
    local loop_end   = read_u32_le(data, pos); pos=pos+4
    local sample_rate = read_u32_le(data, pos); pos=pos+4
    local orig_pitch  = data:byte(pos); pos=pos+1
    local pitch_corr  = data:byte(pos); pos=pos+1
    if pitch_corr >= 128 then pitch_corr = pitch_corr - 256 end
    local sample_link = read_u16_le(data, pos); pos=pos+2
    local sample_type = read_u16_le(data, pos); pos=pos+2
    local name = trim_string(sample_name)
    if name:find("EOS") then
      break
    end
    table.insert(headers, {
      name = name,
      s_start = s_start,
      s_end   = s_end,
      loop_start = loop_start,
      loop_end   = loop_end,
      sample_rate = sample_rate,
      orig_pitch  = orig_pitch,
      pitch_corr  = pitch_corr,
      sample_link = sample_link,
      sample_type = sample_type
    })
  end
  dprint("Total sample headers (excluding EOS):", #headers)
  return headers
end

--------------------------------------------------------------------------------
-- Step 2: Read Instrument Zones (INST, IBAG, IGEN)
-- For each instrument, store .zones = { {params={}, sample_id?=...}, ... }
--------------------------------------------------------------------------------
local function read_instruments(data)
  local pdta_pos = data:find("pdta", 1, true)
  if not pdta_pos then
    dprint("No pdta chunk found (read_instruments).")
    return {}
  end
  local pdta_data_start = pdta_pos + 8

  local inst_pos = data:find("inst", pdta_data_start, true)
  if not inst_pos then
    dprint("No inst chunk found.")
    return {}
  end
  local inst_size = read_u32_le(data, inst_pos + 4)
  local inst_data_start = inst_pos + 8
  local inst_record_size = 22
  local instruments = {}
  local pos = inst_data_start
  while pos + inst_record_size - 1 <= inst_data_start + inst_size - 1 do
    local inst_name = trim_string(data:sub(pos, pos+19))
    local bag_index = read_u16_le(data, pos+20)
    table.insert(instruments, { name=inst_name, bag_index=bag_index })
    pos = pos + inst_record_size
  end

  local ibag_pos = data:find("ibag", pdta_data_start, true)
  if not ibag_pos then
    dprint("No ibag chunk found.")
    return instruments
  end
  local ibag_size = read_u32_le(data, ibag_pos + 4)
  local ibag_data_start = ibag_pos + 8
  local ibag_record_size = 4
  local ibags = {}
  pos = ibag_data_start
  while pos + ibag_record_size - 1 <= ibag_data_start + ibag_size - 1 do
    local gen_index = read_u16_le(data, pos)
    local mod_index = read_u16_le(data, pos+2)
    table.insert(ibags, { gen_index=gen_index, mod_index=mod_index })
    pos = pos + ibag_record_size
  end

  local igen_pos = data:find("igen", pdta_data_start, true)
  if not igen_pos then
    dprint("No igen chunk found.")
    return instruments
  end
  local igen_size = read_u32_le(data, igen_pos + 4)
  local igen_data_start = igen_pos + 8
  local igen_record_size = 4
  local igens = {}
  pos = igen_data_start
  while pos + igen_record_size - 1 <= igen_data_start + igen_size - 1 do
    local op = read_u16_le(data, pos)
    local amount = read_u16_le(data, pos+2)
    table.insert(igens, { op=op, amount=amount })
    pos = pos + igen_record_size
  end

  -- Construct zones for each instrument
  local instruments_zones = {}
  for i, inst in ipairs(instruments) do
    local zones = {}
    local bag_start = inst.bag_index + 1
    local bag_end   = #ibags
    if i < #instruments then
      bag_end = instruments[i+1].bag_index
    end
    for b = bag_start, bag_end do
      local bag = ibags[b]
      local zone_params = {}
      local gen_start = bag.gen_index + 1
      local gen_end = (#igens)+1
      if b < #ibags then
        gen_end = ibags[b+1].gen_index + 1
      end
      for g=gen_start, gen_end-1 do
        local gen = igens[g]
        if gen then
          zone_params[ gen.op ] = gen.amount
        end
      end
      local zone = { params=zone_params }
      -- If operator 53 => sample_id
      if zone_params[53] then
        zone.sample_id = zone_params[53]
      end
      table.insert(zones, zone)
    end
    instruments_zones[i] = {
      name = inst.name,
      zones = zones
    }
  end

  dprint("Parsed", #instruments, "instruments with zones.")
  return instruments_zones
end

--------------------------------------------------------------------------------
-- Step 3: Read Presets (PHDR, PBAG, PGEN)
-- For each preset, store .zones = { { params={} }, ... }
--------------------------------------------------------------------------------
local function read_presets(data)
  local phdr_pos = data:find("phdr", 1, true)
  if not phdr_pos then
    dprint("No phdr chunk found. No presets.")
    return {}
  end
  local phdr_size = read_u32_le(data, phdr_pos + 4)
  local phdr_data_start = phdr_pos + 8
  local phdr_record_size = 38
  local presets = {}
  local pos = phdr_data_start
  while (pos + phdr_record_size -1) <= (phdr_data_start + phdr_size -1) do
    local preset_name = trim_string(data:sub(pos, pos+19))
    local preset_num  = read_u16_le(data, pos+20)
    local bank_num    = read_u16_le(data, pos+22)
    local pbag_idx    = read_u16_le(data, pos+24)
    if preset_name:find("EOP") then break end
    table.insert(presets, {
      name = preset_name,
      preset = preset_num,
      bank   = bank_num,
      pbag_index = pbag_idx,
      zones = {}
    })
    pos = pos + phdr_record_size
  end

  local pdta_pos = data:find("pdta", 1, true)
  if not pdta_pos then
    dprint("No pdta chunk found, cannot parse PBAG/PGEN.")
    return presets
  end
  local pdta_data_start = pdta_pos + 8

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
      table.insert(pbag_list, { pgen_index=pgen_idx, pmod_index=pmod_idx })
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
      table.insert(pgen_list, { op=op, amount=amount })
      pos = pos + record_size
    end
    return pgen_list
  end

  local pbag_list = read_pbag(data, pdta_data_start)
  local pgen_list = read_pgen(data, pdta_data_start)
  if (#pbag_list == 0) or (#pgen_list == 0) then
    dprint("No PBAG/PGEN data; returning basic presets only.")
    return presets
  end

  -- For each preset, read zones from pbag/pgen
  for i, p in ipairs(presets) do
    local zone_start = p.pbag_index + 1
    local zone_end   = #pbag_list
    if i < #presets then
      zone_end = presets[i+1].pbag_index
    end
    for z = zone_start, zone_end do
      local bag = pbag_list[z]
      local zone_params = {}
      local pgen_start = bag.pgen_index + 1
      local pgen_end   = #pgen_list
      if z < #pbag_list then
        pgen_end = pbag_list[z+1].pgen_index
      end
      for g = pgen_start, pgen_end do
        local gen = pgen_list[g]
        if gen then
          zone_params[ gen.op ] = gen.amount
        end
      end
      table.insert(p.zones, { params=zone_params })
    end
  end

  return presets
end

--------------------------------------------------------------------------------
-- Import SF2: Single XRNI per preset. If bank=128 => drum mapping
--------------------------------------------------------------------------------
local function import_sf2(file_path)
  dprint("Importing SF2 file:", file_path)
  local f = io.open(file_path, "rb")
  if not f then
    renoise.app():show_error("Could not open SF2: " .. file_path)
    return false
  end
  local data = f:read("*all")
  f:close()
  if data:sub(1,4) ~= "RIFF" then
    renoise.app():show_error("Not a valid SF2 (missing RIFF).")
    return false
  end

  local smpl_pos = data:find("smpl", 1, true)
  if not smpl_pos then
    renoise.app():show_error("SF2 missing 'smpl' chunk.")
    return false
  end
  local smpl_data_start = smpl_pos + 8

  -- 1) sample headers
  local headers = read_sample_headers(data)
  if not headers or #headers == 0 then
    renoise.app():show_error("No sample headers found.")
    return false
  end

  -- 2) read instruments => each instrument has multiple zones => each zone may reference one sample
  local instruments_zones = read_instruments(data)

  -- 3) read presets => each preset has multiple zones => each zone may reference an instrument via op41
  local presets = read_presets(data)
  if (#presets == 0) then
    renoise.app():show_error("No presets found in SF2.")
    return false
  end

  -- Build a "mapping" per preset. Instead of one XRNI per instrument, we do
  -- one XRNI per PRESET. So all instruments that the preset references get
  -- merged into that one XRNI.
  local mappings_per_preset = {}

  for _, preset in ipairs(presets) do
    -- This table is all the samples for this preset
    local these_samples = {}
    local zone_count = #preset.zones
    if zone_count < 1 then
      dprint("Preset "..preset.name.." has no zones.")
    end
    for z_i, z_data in ipairs(preset.zones) do
      local zone_params = z_data.params or {}
      local inst_index  = zone_params[41]  -- op41 => instrument ID
      local assigned_samples = {}

      if (inst_index ~= nil) then
        -- 0-based
        local real_inst_idx = inst_index + 1
        local inst_info = instruments_zones[ real_inst_idx ]
        if inst_info and inst_info.zones then
          -- For each zone in the instrument, if sample_id is present => fetch that sample
          for _, izone in ipairs(inst_info.zones) do
            if izone.sample_id then
              local sample_idx = izone.sample_id + 1
              local hdr = headers[ sample_idx ]
              if hdr then
                table.insert(assigned_samples, hdr)
                dprint("Preset '"..preset.name.."': referencing instrument '"..inst_info.name.."' => sample '"..hdr.name.."'")
              end
            end
          end
        else
          dprint("Instrument idx "..real_inst_idx.." not found, fallback logic.")
        end
      end
      -- If no assigned samples found from instrument => fallback by key range or substring
      if (#assigned_samples == 0) then
        -- keyRange => op43
        if zone_params[43] then
          local kr = { low = zone_params[43] % 256, high = math.floor(zone_params[43]/256) % 256 }
          for _, hdr in ipairs(headers) do
            if hdr.orig_pitch >= kr.low and hdr.orig_pitch <= kr.high then
              table.insert(assigned_samples, hdr)
              dprint("Preset '"..preset.name.."': fallback keyRange => sample '"..hdr.name.."'")
            end
          end
        end
      end
      if (#assigned_samples == 0) then
        -- substring fallback
        for _, hdr in ipairs(headers) do
          if hdr.name:lower():find( preset.name:lower() ) then
            table.insert(assigned_samples, hdr)
            dprint("Preset '"..preset.name.."': substring fallback => sample '"..hdr.name.."'")
          end
        end
      end

      for _, s in ipairs(assigned_samples) do
        table.insert(these_samples, s)
      end
    end

    if #these_samples == 0 then
      dprint("Preset "..preset.name.." => no assigned samples => skipping.")
    else
      table.insert(mappings_per_preset, {
        preset_name = preset.name,
        bank = preset.bank,
        preset_num = preset.preset,
        samples = these_samples
      })
    end
  end

  if #mappings_per_preset == 0 then
    renoise.app():show_error("No preset found that has assigned samples.")
    return false
  end

  local song = renoise.song()

  for _, mapping_entry in ipairs(mappings_per_preset) do
    local is_drumkit = (mapping_entry.bank == 128)
    local preset_file = is_drumkit
      and (renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
      or  "Presets/12st_Pitchbend.xrni"

    -- Insert new instrument for this preset
    song:insert_instrument_at(song.selected_instrument_index+1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    renoise.app():load_instrument(preset_file)
    local r_inst = song.selected_instrument
    if not r_inst then
      renoise.app():show_error("Failed to load XRNI preset for "..mapping_entry.preset_name)
      return false
    end
    r_inst.name = string.format("%s (Bank %d, Preset %d)", mapping_entry.preset_name, mapping_entry.bank, mapping_entry.preset_num)
    dprint("Created instrument for preset: "..r_inst.name)

    -- We insert new sample slots at index 2, 3, 4... THEN remove slot 1 at the end if drumkit
    -- If melodic => we do the old approach (overwrite slot1 for first sample).
    local is_first_overwritten = false
    local new_slots = {}

    for i, hdr in ipairs(mapping_entry.samples) do
      local frames = hdr.s_end - hdr.s_start
      if frames <= 0 then
        dprint("Skipping sample "..hdr.name.." because frames <= 0.")
      else
        local is_stereo = false
        if hdr.sample_link ~= 0 then
          if hdr.sample_type == 0 or hdr.sample_type == 1 then
            is_stereo = true
          else
            dprint("Skipping sample_link for right channel in stereo pair: "..hdr.name)
            goto continue_samples
          end
        end
        local sample_data = {}
        if is_stereo then
          for f_i = hdr.s_start+1, hdr.s_end do
            local offs = smpl_data_start + (f_i -1)*4
            if (offs+3) <= #data then
              local left_val  = read_s16_le(data, offs)
              local right_val = read_s16_le(data, offs+2)
              table.insert(sample_data, {
                left  = left_val / 32768.0,
                right = right_val/ 32768.0
              })
            end
          end
        else
          for f_i = hdr.s_start+1, hdr.s_end do
            local offs = smpl_data_start + (f_i -1)*2
            if (offs+1) <= #data then
              local raw_val = read_s16_le(data, offs)
              table.insert(sample_data, raw_val / 32768.0)
            end
          end
        end
        dprint(("Extracted %d frames from '%s'"):format(#sample_data, hdr.name))
        if #sample_data == 0 then
          dprint("Skipping sample "..hdr.name.." due to zero frames.")
          goto continue_samples
        end

        local slot_idx = nil

        if not is_drumkit then
          -- For melodic presets, overwrite slot 1 with the first sample; append subsequent.
          if not is_first_overwritten and #r_inst.samples > 0 then
            slot_idx = 1
            is_first_overwritten = true
          else
            slot_idx = #r_inst.samples + 1
            r_inst:insert_sample_at(slot_idx)
          end
        else
          -- For drum presets => always append at the end, we will remove slot1 later.
          slot_idx = #r_inst.samples + 1
          r_inst:insert_sample_at(slot_idx)
        end

        local new_samp = r_inst.samples[ slot_idx ]

        local success, err = pcall(function()
          if is_stereo then
            new_samp.sample_buffer:create_sample_data(hdr.sample_rate, 16, 2, #sample_data)
          else
            new_samp.sample_buffer:create_sample_data(hdr.sample_rate, 16, 1, #sample_data)
          end
        end)
        if not success then
          dprint("Error creating buffer for "..hdr.name..": "..tostring(err))
        else
          local buf = new_samp.sample_buffer
          if is_stereo then
            for f_i=1, #sample_data do
              buf:set_sample_data(1, f_i, sample_data[f_i].left)
              buf:set_sample_data(2, f_i, sample_data[f_i].right)
            end
          else
            for f_i=1, #sample_data do
              buf:set_sample_data(1, f_i, sample_data[f_i])
            end
          end
          new_samp.name = hdr.name
          -- Loop settings
          if is_drumkit then
            new_samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
          else
            -- If loop is valid
            if hdr.loop_start == hdr.s_start and hdr.loop_end == hdr.s_end then
              new_samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
            else
              local l_start = hdr.loop_start - hdr.s_start
              local l_end   = hdr.loop_end   - hdr.s_start
              if l_start <= 0 then l_start=1 end
              if l_end > #sample_data then l_end=#sample_data end
              if l_end > l_start then
                new_samp.loop_mode  = renoise.Sample.LOOP_MODE_FORWARD
                new_samp.loop_start = l_start
                new_samp.loop_end   = l_end
              else
                new_samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
              end
            end
          end

          new_samp.sample_mapping.base_note = hdr.orig_pitch or 60
          new_samp.sample_mapping.velocity_range = {0,127}
          table.insert(new_slots, slot_idx)
        end

        ::continue_samples::
      end
    end

    -- If this is a drum preset, remove the original placeholder sample at slot 1.
    -- Then re-map each final sample to consecutive notes: C-0, C#0, D-0, etc.
    if is_drumkit then
      if #r_inst.samples > 1 then
        local first_samp_name = r_inst.samples[1].name
        dprint("Removing placeholder sample #1 => '"..first_samp_name.."' for drum preset.")
        r_inst:delete_sample_at(1)
      end
      -- Now re-map the final sample slots (which are currently 1..N) to notes 0..(N-1).
      for i_samp=1, #r_inst.samples do
        local s = r_inst.samples[i_samp]
        local note_idx = (i_samp -1)
        s.sample_mapping.note_range = { note_idx, note_idx }
        s.sample_mapping.base_note  = note_idx
      end
    end
  end

  renoise.app():show_status("SF2 import done. See script console for details.")
  return true
end


--------------------------------------------------------------------------------
-- (Optional) Dummy Multitimbral Handler
--------------------------------------------------------------------------------
local function import_sf2_multitimbral(filepath)
  renoise.app():show_error("Multitimbral import not implemented.")
  return false
end

--------------------------------------------------------------------------------
-- Register
--------------------------------------------------------------------------------
if renoise.tool():has_file_import_hook("sample", {"sf2_import"}) then
  renoise.tool():remove_file_import_hook("sample", {"sf2_import"})
  dprint("Removed old SF2 Import Hook.")
end

local sf2_hook = {
  category   = "sample",
  extensions = {"sf2"},
  invoke     = import_sf2
}

if not renoise.tool():has_file_import_hook("sample", {"sf2_import"}) then
  renoise.tool():add_file_import_hook(sf2_hook)
  dprint("Added SF2 Import Hook.")
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Import SF2 (Single XRNI per Preset)",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import.")
    if f and f~="" then
      import_sf2(f)
    end
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Import SF2 (Multitimbral Placeholder)",
  invoke = function()
    local f = renoise.app():prompt_for_filename_to_read({"*.sf2"}, "Select SF2 to import (multitimbral).")
    if f and f~="" then
      import_sf2_multitimbral(f)
    end
  end
}
