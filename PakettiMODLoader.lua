renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Samples..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}


renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti..:Load .MOD as Sample",invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod", "mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}


renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Load .MOD as Sample",
  invoke=function() 
    local file_path = renoise.app():prompt_for_filename_to_read({"*.mod","mod.*"}, "Select Any File to Load as Sample")
    if file_path ~= "" then
      pakettiLoadExeAsSample(file_path)
      paketti_toggle_signed_unsigned() end end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Samples..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Load Samples from .MOD",invoke=function() load_samples_from_mod() end}

-- helper to read a big-endian 16-bit word from a string at pos (1-based)
local function read_be_u16(str, pos)
  local b1, b2 = str:byte(pos, pos+1)
  return b1*256 + b2
end

-- helpers to build little-endian words/dwords for WAV header
local function le_u16(n)
  return string.char(n % 256, math.floor(n/256) % 256)
end
local function le_u32(n)
  local b1 = n % 256
  local b2 = math.floor(n/256) % 256
  local b3 = math.floor(n/65536) % 256
  local b4 = math.floor(n/16777216) % 256
  return string.char(b1, b2, b3, b4)
end

function load_samples_from_mod()
  -- pick a .mod
  local mod_file = renoise.app():prompt_for_filename_to_read(
    { "*.mod","mod.*" }, "Load .MOD file"
  )
  if not mod_file then 
    renoise.app():show_status("No MOD selected.") 
    return 
  end

  -- read full file
  local f = io.open(mod_file, "rb")
  if not f then 
    renoise.app():show_status("Cannot open .MOD") 
    return 
  end
  local data = f:read("*all")
  f:close()

  -- parse 31 sample headers
  local sample_infos = {}
  local off = 21
  for i = 1,31 do
    local raw_name = data:sub(off, off+21)
    local name = raw_name:gsub("%z+$","")
    local length     = read_be_u16(data, off+22) * 2
    local loop_start = read_be_u16(data, off+26) * 2
    local loop_len   = read_be_u16(data, off+28) * 2
    sample_infos[i] = {
      name        = (#name>0 and name) or ("Sample_"..i),
      length      = (length>0 and length) or nil,
      loop_start  = loop_start,
      loop_length = loop_len,
    }
    off = off + 30
  end

  -- compute patterns to skip
  local song_len    = data:byte(951)
  local patt_bytes  = { data:byte(953, 953+127) }
  local maxp = 0
  for i = 1, song_len do
    if patt_bytes[i] and patt_bytes[i] > maxp then
      maxp = patt_bytes[i]
    end
  end
  local num_patterns = maxp + 1

  -- channels from ID
  local id = data:sub(1081,1084)
  local channel_map = { M_K=4, ["4CHN"]=4, ["6CHN"]=6, ["8CHN"]=8, ["FLT4"]=4, ["FLT8"]=8 }
  local channels = channel_map[id] or 4

  -- skip to sample data
  local patt_size = num_patterns * 64 * channels * 4
  local sample_data_off = 1085 + patt_size

  -- loop through each sample
  for idx,info in ipairs(sample_infos) do
    if info.length then
      -- extract raw sample
      local s0 = sample_data_off
      local s1 = s0 + info.length - 1
      local raw = data:sub(s0, s1)
      sample_data_off = s1 + 1

      -- signed→unsigned
      local unsigned = raw:gsub(".", function(c)
        return string.char((c:byte() + 128) % 256)
      end)

      -- make minimal 8-bit/44.1k WAV header
      local sr, nch, bits = 44100, 1, 8
      local byte_rate   = sr * nch * (bits/8)
      local block_align = nch * (bits/8)
      local data_sz     = #unsigned
      local fmt_sz      = 16
      local riff_sz     = 4 + (8 + fmt_sz) + (8 + data_sz)

      local hdr = {
        "RIFF", le_u32(riff_sz), "WAVE",
        "fmt ", le_u32(fmt_sz),
        le_u16(1),       -- PCM
        le_u16(nch),
        le_u32(sr),
        le_u32(byte_rate),
        le_u16(block_align),
        le_u16(bits),
        "data", le_u32(data_sz),
      }
      local header = table.concat(hdr)

      -- write to temp .wav
      local tmp = os.tmpname()..".wav"
      local wf  = io.open(tmp,"wb")
      wf:write(header)
      wf:write(unsigned)
      wf:close()

      -- apply Paketti defaults + insert instrument
      
      local next_ins = renoise.song().selected_instrument_index + 1
      renoise.song():insert_instrument_at(next_ins)
      renoise.song().selected_instrument_index = next_ins
      pakettiPreferencesDefaultInstrumentLoader()
      local ins = renoise.song().selected_instrument
      
      -- name instrument from .mod
      ins.name = info.name
      ins.macros_visible = true
      ins.sample_modulation_sets[1].name = "Pitchbend"

      -- ensure sample slot 1 exists
      if #ins.samples == 0 then ins:insert_sample_at(1) end
      renoise.song().selected_sample_index = 1

      -- load the sample
      local samp = ins.samples[1]
      if samp.sample_buffer:load_from(tmp) then
        -- name the sample too
        samp.name = info.name

        -- prefs
        samp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        samp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        samp.autofade           = preferences.pakettiLoaderAutofade.value
        samp.autoseek           = preferences.pakettiLoaderAutoseek.value
        samp.oneshot            = preferences.pakettiLoaderOneshot.value
        samp.new_note_action    = preferences.pakettiLoaderNNA.value
        samp.loop_release       = preferences.pakettiLoaderLoopExit.value

        -- set looping only if loop_length > 1
        if info.loop_length and info.loop_length > 5 then
          local sample_length = samp.sample_buffer.number_of_frames
          local calculated_loop_start = info.loop_start + 1
          local calculated_loop_end = info.loop_start + info.loop_length
          
          -- check if loop_start is completely invalid (beyond sample length)
          if calculated_loop_start > sample_length then
            -- mark as invalid and don't set looping
            samp.name = info.name .. " (invalid loopstart)"
            ins.name = info.name .. " (invalid loopstart)"
            samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
          else
            -- loop_start is valid, now check loop_end
            if calculated_loop_end > sample_length then
              -- clamp loop_end to sample length
              calculated_loop_end = sample_length
            end
            
            samp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
            samp.loop_start = calculated_loop_start
            samp.loop_end = calculated_loop_end
          end
        else
          samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
        end

        renoise.app():show_status(("Loaded “%s”"):format(info.name))
      else
        renoise.app():show_status(("Failed to load “%s”"):format(info.name))
      end

      -- clean up
      os.remove(tmp)
    end
  end

  renoise.app():show_status("All MOD samples loaded.")
end

---
