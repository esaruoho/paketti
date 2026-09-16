--------------------------------------------------------------------------------
-- PakettiRolandMV8000.lua
--
-- Roland MV-8000 / MV-8800 patch import (.mv0) for Paketti. Ported and
-- modernised from Martin Bealby's 2011 com.mxb.FileFormats tool. Samples only:
-- the embedded WAVE audio is extracted into instrument sample slots. Keymap /
-- partial parameters are not translated (the source format does not expose them
-- in a documented way).
--------------------------------------------------------------------------------

function PakettiRolandMV8000Import(filename)
  local d = PakettiFFLoadFile(filename)
  if not d then
    renoise.app():show_status("Couldn't open Roland MV-8000 patch file.")
    return false
  end

  if PakettiFFReadStr(d, 1, 4) ~= "MVFF" then
    renoise.app():show_error(tostring(filename) .. " is not a valid Roland MV-8000 patch.")
    return false
  end

  local start_pos = d:find("SMPL", 1, true)
  if not start_pos then
    renoise.app():show_status("Roland MV-8000 patch contains no SMPL section.")
    return false
  end

  -- Each sample = a PRM chunk (name) followed by a WAVE chunk (LE 16-bit PCM).
  local samples = {}
  while true do
    local prm = d:find("PRM ", start_pos, true)
    if not prm then break end
    local wave_start = d:find("WAVE", start_pos, true)
    if not wave_start then break end
    local wave_len = PakettiFFReadU32BE(d, wave_start + 4) or 0
    local name = PakettiFFReadStr(d, prm + 16, 12):gsub("%z+$", ""):gsub("%s+$", "")
    local pcm = d:sub(wave_start + 9, wave_start + wave_len)
    samples[#samples + 1] = { name, pcm }
    start_pos = wave_start + 4
  end
  d = nil

  if #samples == 0 then
    renoise.app():show_status("Roland MV-8000 patch contains no samples.")
    return false
  end
  if #samples > 254 then
    renoise.app():show_error("Renoise is limited to 255 samples per instrument; this MV-8000 patch has more.")
    return false
  end

  local instrument = renoise.song().selected_instrument
  instrument:clear()
  local _, inst_name = PakettiFFSplitFilename(filename)
  instrument.name = inst_name

  renoise.app():show_status("Importing Roland MV-8000 patch (samples)...")
  local loaded = 0
  for i = 1, #samples do
    -- MV-8000 WAVE payload is little-endian 44.1kHz/16-bit/stereo PCM.
    local wav = PakettiFFWriteWAV(2, 44100, 16, samples[i][2])
    if wav then
      local s = instrument:insert_sample_at(#instrument.samples + 1)
      if s.sample_buffer:load_from(wav) then
        local nm = samples[i][1]
        if nm and nm ~= "" then s.name = nm end
        loaded = loaded + 1
      else
        instrument:delete_sample_at(#instrument.samples)
      end
      os.remove(wav)
    end
  end

  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end

  renoise.app():show_status(string.format(
    "Roland MV-8000 import complete (%d of %d samples).", loaded, #samples))
  return true
end

--------------------------------------------------------------------------------
-- Menu entry (disk-browser hook lives in PakettiImport.lua)
--------------------------------------------------------------------------------
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Instruments:Import:Load Roland MV-8000 Patch...",
  invoke = function()
    local file = renoise.app():prompt_for_filename_to_read({ "*.mv0" }, "Load Roland MV-8000 Patch")
    if file and file ~= "" then PakettiRolandMV8000Import(file) end
  end }
