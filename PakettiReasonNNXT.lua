--------------------------------------------------------------------------------
-- PakettiReasonNNXT.lua
--
-- Reason NN-XT patch import (.sxt) for Paketti. Ported and modernised from
-- Martin Bealby's 2011 com.mxb.FileFormats tool. Partial: imports the sample
-- references and their keyzone/velocity mapping. Synth/modulation parameters in
-- the patch are not translated.
--
-- Keyzone mapping uses the modern per-sample `sample_mapping` API (the 2011
-- original used instrument:insert_sample_mapping(), which no longer exists).
--------------------------------------------------------------------------------

local function clamp(v, lo, hi)
  if not v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Parse one REFE (sample reference) chunk; appends {filename} to samples.
local function parse_refe(d, start_pos, samples)
  local len = PakettiFFReadU8(d, start_pos + 30)
  if not len or len == 0 then return end
  local name = PakettiFFReadStr(d, start_pos + 31, len)
  if not name or name == "" then return end
  samples[#samples + 1] = { name }
end

-- Parse one sample-metadata block; attaches low/high/base/minvel/maxvel to the
-- sample entry at metadata_index+1. Returns the advanced metadata_index.
local function parse_metadata(d, start_pos, metadata_index, samples)
  local low  = PakettiFFReadU8(d, start_pos)
  local base = PakettiFFReadU8(d, start_pos + 1)
  local minv = PakettiFFReadU8(d, start_pos + 2)
  local maxv = PakettiFFReadU8(d, start_pos + 3)
  local high = PakettiFFReadU8(d, start_pos + 4)
  if not (low and base and minv and maxv and high) then
    return metadata_index
  end
  if minv == 1 then minv = 0 end -- historical NN-XT quirk

  metadata_index = metadata_index + 1
  local entry = samples[metadata_index]
  if not entry then return metadata_index end
  entry[2] = low
  entry[3] = high
  entry[4] = base
  entry[5] = minv
  entry[6] = maxv
  return metadata_index
end

local function nnxt_load_samples(instrument, sample_path, samples)
  local missing = 0
  for i = 1, #samples do
    local entry = samples[i]
    local name = entry[1]
    if not io.exists(sample_path .. name) then
      missing = missing + 1
    else
      local s = instrument:insert_sample_at(#instrument.samples + 1)
      if s.sample_buffer:load_from(sample_path .. name) then
        s.name = name
        s.volume = math.db2lin(0)
        local map = s.sample_mapping
        map.base_note = clamp(entry[4], 0, 119)
        map.note_range = { clamp(entry[2], 0, 119), clamp(entry[3], 0, 119) }
        map.velocity_range = { clamp(entry[5], 0, 127), clamp(entry[6] or 127, 0, 127) }
      else
        instrument:delete_sample_at(#instrument.samples)
        missing = missing + 1
      end
    end
    renoise.app():show_status(string.format(
      "Importing Reason NN-XT patch (%d%%)...", math.floor((i / #samples) * 100)))
    coroutine.yield()
  end

  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end

  if missing == 0 then
    renoise.app():show_status("Reason NN-XT patch import complete.")
  else
    renoise.app():show_status(string.format(
      "Reason NN-XT patch import partial (%d missing samples).", missing))
    renoise.app():show_warning(string.format(
      "%d sample(s) could not be found while importing this NN-XT patch.\nThese have been skipped.", missing))
  end
end

function PakettiReasonNNXTImport(filename)
  if not filename or filename == "" then return false end
  local inst_path, inst_name = PakettiFFSplitFilename(filename)
  if inst_path == "" or inst_name == "" then return false end

  local d = PakettiFFLoadFile(filename)
  if not d then
    renoise.app():show_status("Couldn't open Reason NN-XT patch file.")
    return false
  end

  if PakettiFFReadStr(d, 9, 4) ~= "PTCH" then
    renoise.app():show_error(tostring(filename) .. " is not a valid Reason NN-XT patch.")
    return false
  end

  -- Parse REFE (sample reference) chunks
  local samples = {}
  local start_pos = 1
  while true do
    local chunk_start = d:find("REFE", start_pos, true)
    if not chunk_start then break end
    parse_refe(d, chunk_start, samples)
    start_pos = chunk_start + 4
  end

  if #samples == 0 then
    renoise.app():show_status("Reason NN-XT patch contains no sample references.")
    return false
  end
  if #samples > 254 then
    renoise.app():show_error("Renoise is limited to 255 samples per instrument; this NN-XT patch has more.")
    return false
  end

  -- Locate the sample-metadata region: after PARM, inside the BODY chunk
  local parm = d:find("PARM", 1, true)
  local body = parm and d:find("BODY", parm, true) or d:find("BODY", 1, true)
  if not body then
    renoise.app():show_error(tostring(filename) .. " is missing its BODY chunk.")
    return false
  end
  local skip = PakettiFFReadU8(d, body + 14) or 0
  local chunk_start = body + 40 + skip

  local metadata_index = 0
  while chunk_start < d:len() do
    metadata_index = parse_metadata(d, chunk_start, metadata_index, samples)
    if metadata_index >= #samples then break end
    chunk_start = chunk_start + 241
  end
  d = nil

  local sample_path = PakettiFFGetSamplesPath(inst_name, inst_path, samples[1][1])
  if not sample_path then
    renoise.app():show_status("Reason NN-XT patch import aborted (no sample folder).")
    return false
  end

  local instrument = renoise.song().selected_instrument
  instrument:clear()
  instrument.name = inst_name

  renoise.app():show_status("Importing Reason NN-XT patch...")
  local slicer = ProcessSlicer(function()
    nnxt_load_samples(instrument, sample_path, samples)
  end)
  slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- Menu entry (disk-browser hook lives in PakettiImport.lua)
--------------------------------------------------------------------------------
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Instruments:Import:Load Reason NN-XT Patch...",
  invoke = function()
    local file = renoise.app():prompt_for_filename_to_read({ "*.sxt" }, "Load Reason NN-XT Patch")
    if file and file ~= "" then PakettiReasonNNXTImport(file) end
  end }
