--------------------------------------------------------------------------------
-- PakettiKorg.lua
--
-- Korg Trinity / Triton import for Paketti. Ported and modernised from Martin
-- Bealby's 2011 com.mxb.FileFormats tool.
--
--   .ksf  - single KSF sample                       -> sample
--   .kmp  - KMP multisample (many .ksf + keymap)    -> instrument
--   .ksc  - KSC performance script (list of .kmp)   -> instrument(s)
--
-- Uses the shared readers in PakettiForeignFormatSupport.lua. Sample audio in
-- KSF is big-endian 16-bit PCM; it is byte-swapped to little-endian and written
-- as a standard WAV before load_from(), so any sample rate imports correctly.
--
-- Keyzone mapping uses the modern per-sample `sample_mapping` API. The 2011
-- original called instrument:insert_sample_mapping(), which no longer exists in
-- the Renoise API.
--------------------------------------------------------------------------------

local function clamp_note(n)
  if not n then return 0 end
  if n < 0 then return 0 end
  if n > 119 then return 119 end
  return n
end

--------------------------------------------------------------------------------
-- KSF sample loader
--------------------------------------------------------------------------------
-- Loads a KSF file into `target_sample` (a renoise.Sample), or into the current
-- selected_sample when target_sample is nil (disk-browser hook path).
-- Returns true on success, false otherwise.
function PakettiKorgKSFLoadSample(filename, target_sample)
  local smp = target_sample or renoise.song().selected_sample
  if not smp then
    renoise.app():show_status("KSF import: no target sample slot.")
    return false
  end

  local d = PakettiFFLoadFile(filename)
  if not d then
    renoise.app():show_status("Couldn't open Korg KSF sample: " .. tostring(filename))
    return false
  end

  if PakettiFFReadStr(d, 1, 4) ~= "SMP1" then
    return false
  end

  local smd_offset = d:find("SMD1")
  if not smd_offset then
    return false
  end

  local flags = PakettiFFReadU8(d, smd_offset + 12) or 0
  if bit.band(0x10, flags) == 0x10 then
    renoise.app():show_status("Cannot import compressed Korg KSF samples. Aborting.")
    return false
  end

  local bit_depth   = PakettiFFReadU8(d, smd_offset + 15) or 16
  local sample_rate = PakettiFFReadU32BE(d, smd_offset + 8) or 44100
  local channels    = PakettiFFReadU8(d, smd_offset + 14) or 1
  local frames      = PakettiFFReadU32BE(d, smd_offset + 16) or 0
  local loop_start  = PakettiFFReadU32BE(d, 33) or 0
  local loop_end    = (PakettiFFReadU32BE(d, 37) or 1) - 1
  local loop_enabled = bit.band(0x80, flags) ~= 0x80

  if channels < 1 then channels = 1 end
  if bit_depth < 1 then bit_depth = 16 end

  local bytes_per_frame = channels * (bit_depth / 8)
  if d:len() < (frames * bytes_per_frame) + smd_offset + 19 then
    renoise.app():show_status("Corrupt Korg KSF sample: " .. tostring(filename))
    return false
  end

  local pcm = d:sub(smd_offset + 20)
  if bit_depth == 16 then
    pcm = PakettiFFSwap16(pcm) -- big-endian -> little-endian
  end

  local wav = PakettiFFWriteWAV(channels, sample_rate, bit_depth, pcm)
  d = nil
  pcm = nil
  if not wav then return false end

  if smp.sample_buffer.has_sample_data and smp.sample_buffer.read_only then
    return false
  end

  smp:clear()
  if smp.sample_buffer:load_from(wav) == false then
    os.remove(wav)
    return false
  end
  os.remove(wav)

  local _, name = PakettiFFSplitFilename(filename)
  smp.name = name

  if loop_enabled and loop_end > loop_start then
    smp.loop_start = math.max(1, loop_start)
    smp.loop_end = loop_end
    smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  end

  return true
end

--------------------------------------------------------------------------------
-- KMP multisample loader
--------------------------------------------------------------------------------
local function kmp_load_samples(instrument, sample_path, samples)
  local missing = 0
  local last_high_note = 12

  for i = 1, #samples do
    local entry = samples[i]
    local sample_name = entry[1]
    if sample_name == "SKIPPEDSAMPL" then
      -- intentional skip marker in the KMP
    elseif string.sub(sample_name, 1, 8) == "INTERNAL" then
      missing = missing + 1 -- ROM sample, not on disk
    elseif not io.exists(sample_path .. sample_name) then
      missing = missing + 1
    else
      local s = instrument:insert_sample_at(#instrument.samples + 1)
      if PakettiKorgKSFLoadSample(sample_path .. sample_name, s) then
        s.fine_tune = entry[4] or 0
        local base_note = clamp_note(entry[2])
        local high_note = clamp_note(entry[3])
        local map = s.sample_mapping
        map.base_note = base_note
        map.note_range = { clamp_note(last_high_note), high_note }
        map.velocity_range = { 0, 127 }
        last_high_note = high_note + 1
      else
        -- KSF load failed; drop the empty slot we just made
        instrument:delete_sample_at(#instrument.samples)
        missing = missing + 1
      end
    end
    renoise.app():show_status(string.format(
      "Importing Korg Triton multisample (%d%%)...", math.floor((i / #samples) * 100)))
    coroutine.yield()
  end

  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end

  if missing == 0 then
    renoise.app():show_status("Korg Triton multisample import complete.")
  else
    renoise.app():show_status(string.format(
      "Korg Triton multisample import partial (%d missing samples).", missing))
    renoise.app():show_warning(string.format(
      "%d sample(s) could not be found while importing this KMP.\nThese have been skipped.", missing))
  end
end

function PakettiKorgKMPImport(filename)
  local inst_path, inst_name = PakettiFFSplitFilename(filename)
  if inst_path == "" or inst_name == "" then return false end

  local d = PakettiFFLoadFile(filename)
  if not d then
    renoise.app():show_status("Couldn't open Korg Triton multisample (KMP) file.")
    return false
  end

  if PakettiFFReadStr(d, 1, 4) ~= "MSP1" then
    renoise.app():show_error(tostring(filename) .. " is not a valid Korg Triton multisample (KMP).")
    return false
  end

  local chunk_start = d:find("RLP1")
  if not chunk_start then
    renoise.app():show_error(tostring(filename) .. " has no RLP1 keymap chunk.")
    return false
  end
  local chunk_len = PakettiFFReadU32BE(d, chunk_start + 4) or 0
  local chunk_count = math.floor(chunk_len / 18)

  local samples = {}
  for i = 1, chunk_count do
    local base = chunk_start + (i - 1) * 18
    local name = PakettiFFReadStr(d, base + 14, 12)
    local start_note = bit.band((PakettiFFReadU8(d, base + 8) or 12) - 12, 0x7F)
    local end_note = (PakettiFFReadU8(d, base + 9) or 12) - 12
    local fine = PakettiFFByteToSigned(PakettiFFReadU8(d, base + 10))
    samples[#samples + 1] = { name, start_note, end_note, fine }
  end
  d = nil

  if #samples == 0 then
    renoise.app():show_status("Korg KMP contains no samples.")
    return false
  end
  if #samples > 254 then
    renoise.app():show_error("Renoise is limited to 255 samples per instrument; this KMP has more.")
    return false
  end

  -- find the first real (non-ROM/non-skip) sample so we can locate the folder
  local first = nil
  for i = 1, #samples do
    local nm = samples[i][1]
    if nm ~= "SKIPPEDSAMPL" and string.sub(nm, 1, 8) ~= "INTERNAL" then
      first = nm
      break
    end
  end
  if not first then
    renoise.app():show_warning("This KMP references only internal ROM samples, which are not on disk.")
    return false
  end

  local sample_path = PakettiFFGetSamplesPath(inst_name, inst_path, first)
  if not sample_path then
    renoise.app():show_status("Korg KMP import aborted (no sample folder).")
    return false
  end

  local instrument = renoise.song().selected_instrument
  instrument:clear()
  instrument.name = inst_name

  renoise.app():show_status("Importing Korg Triton multisample...")
  local slicer = ProcessSlicer(function()
    kmp_load_samples(instrument, sample_path, samples)
  end)
  slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- KSC performance script loader (a text list of KMP files)
--------------------------------------------------------------------------------
function PakettiKorgKSCImport(filename)
  local patch_path, patch_name = PakettiFFSplitFilename(filename)
  if patch_path == "" or patch_name == "" then return false end

  local line_number = 0
  local loaded = 0
  for line in io.lines(filename) do
    line = line:gsub(string.char(13), "") -- strip CR on unix
    line_number = line_number + 1
    if line_number == 1 then
      if line ~= "#KORG Script Version 1.0" then
        renoise.app():show_status(tostring(filename) .. " is not a valid Korg KSC script.")
        return false
      end
    elseif line ~= "" then
      if io.exists(patch_path .. patch_name .. "/" .. line) then
        PakettiKorgKMPImport(patch_path .. patch_name .. "/" .. line)
        loaded = loaded + 1
      elseif io.exists(patch_path .. line) then
        PakettiKorgKMPImport(patch_path .. line)
        loaded = loaded + 1
      end
    end
  end

  if loaded == 0 then
    renoise.app():show_status("Korg KSC script referenced no reachable KMP files.")
    return false
  end
  return true
end

--------------------------------------------------------------------------------
-- Menu entries (manual file-prompt loading; disk-browser hooks live in
-- PakettiImport.lua)
--------------------------------------------------------------------------------
local function prompt_and_load(exts, title, loader)
  local file = renoise.app():prompt_for_filename_to_read(exts, title)
  if file and file ~= "" then loader(file) end
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Instruments:Import:Load Korg Triton KMP Multisample...",
  invoke = function() prompt_and_load({ "*.kmp" }, "Load Korg Triton KMP", PakettiKorgKMPImport) end }
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Instruments:Import:Load Korg Triton KSC Script...",
  invoke = function() prompt_and_load({ "*.ksc" }, "Load Korg Triton KSC", PakettiKorgKSCImport) end }
