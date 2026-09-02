--[[============================================================================
PakettiSamplerExports.lua — Akai MPC, Decent Sampler and Elektron multi-sample

Three exports that share a shape: a sidecar file describing regions, plus audio
Renoise writes itself. Nothing here transcodes anything.

  .xpm        Akai MPC program (MPC Live / One / X / Force). XML, one Instrument
              per pad, each pad a SampleStart..SampleEnd window into one WAV.
              128 pads.
  .dspreset   Decent Sampler. XML, one <sample> per region with start/end
              attributes, again into one WAV.
  _slices.txt Elektron multi-sample mapping. A TOML-ish config listing key zones,
              one per slice, each naming its own slice_NN.wav. 64 zones.

MPC and Decent Sampler point into a single file; Elektron wants one file per
slice, like OP-XY. Renoise covers both cases directly, since a sliced
instrument's slices are real samples whose buffers view only their own frames.

Layouts transcribed from chirashi (github.com/g-lok/chirashi).
============================================================================]]--

local MPC_MAX_PADS = 128
local EL_MAX_ZONES = 64
local DS_FIRST_NOTE = 24
local EL_FIRST_PITCH = 24

local function xml_attr(s)
  s = tostring(s or "")
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

--- The regions of the selected instrument, as start/end frames into one file.
--- Returns the list, the sample that owns the audio, or nil plus a reason.
local function instrument_regions(instrument)
  local first = instrument.samples[1]
  if not first or not first.sample_buffer.has_sample_data then
    return nil, nil, "the first sample of the selected instrument is empty"
  end

  local regions = {}
  local markers = first.slice_markers
  if #markers > 0 then
    local frames = first.sample_buffer.number_of_frames
    local bounds = {}
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] end
    bounds[#bounds + 1] = frames + 1
    for i = 1, #bounds - 1 do
      regions[#regions + 1] = {
        start_frame = bounds[i] - 1,
        end_frame = bounds[i + 1] - 2,
        sample = instrument.samples[i + 1],
        name = string.format("Slice %02d", i),
      }
    end
  else
    regions[1] = {
      start_frame = 0,
      end_frame = first.sample_buffer.number_of_frames - 1,
      sample = first,
      name = (first.name ~= "" and first.name) or "Sample",
    }
  end

  return regions, first, nil
end

--- Write the parent audio beside `path`, returning the WAV's filename.
local function write_shared_wav(sample, path, base)
  local wav_name = pakettiFSPath.sanitize_filename(base, "sample") .. ".wav"
  local wav_path = pakettiFSPath.join(pakettiFSPath.dirname(path), wav_name)
  local ok = pcall(function() return sample.sample_buffer:save_as(wav_path, "wav") end)
  if not ok or not io.exists(wav_path) then return nil end
  return wav_name
end

--------------------------------------------------------------------------------
-- Akai MPC program (.xpm)
--------------------------------------------------------------------------------

function PakettiMPCExport(xpm_path)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end

  local regions, parent, err = instrument_regions(instrument)
  if not regions then return false, err end

  local base = pakettiFSPath.basename(xpm_path):gsub("%.xpm$", "")
  local wav_name = write_shared_wav(parent, xpm_path, base)
  if not wav_name then return false, "could not write the WAV beside the program" end

  -- MPC resolves SampleName against the samples sitting next to the program,
  -- and wants the name without its extension
  local sample_name = wav_name:gsub("%.wav$", "")

  local dropped = math.max(0, #regions - MPC_MAX_PADS)
  local out = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<MPCVObject>',
    '  <Version><File_Version>2.0</File_Version></Version>',
    string.format('  <Program type="DRUM">'),
    string.format('    <ProgramName>%s</ProgramName>', xml_attr(base)),
    '    <Instruments>',
  }

  for i = 1, math.min(#regions, MPC_MAX_PADS) do
    local r = regions[i]
    local loop_mode, loop_start, loop_end = 0, 0, 0
    if r.sample and r.sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
      loop_mode = 1
      loop_start = math.max(0, r.sample.loop_start - 1)
      loop_end = math.max(loop_start, r.sample.loop_end - 1)
    end
    out[#out + 1] = string.format([[      <Instrument number="%d">
        <Layers>
          <Layer number="1">
            <Active>true</Active>
            <Volume>1.0</Volume>
            <Pan>0.5</Pan>
            <Pitch>0.0</Pitch>
            <SampleName>%s</SampleName>
            <SampleStart>%d</SampleStart>
            <SampleEnd>%d</SampleEnd>
            <LoopStart>%d</LoopStart>
            <LoopEnd>%d</LoopEnd>
            <LoopMode>%d</LoopMode>
          </Layer>
        </Layers>
      </Instrument>]], i, xml_attr(sample_name), r.start_frame, r.end_frame,
      loop_start, loop_end, loop_mode)
  end

  out[#out + 1] = '    </Instruments>'
  out[#out + 1] = '  </Program>'
  out[#out + 1] = '</MPCVObject>'

  local f = io.open(xpm_path, "wb")
  if not f then return false, "could not write " .. xpm_path end
  f:write(table.concat(out, "\n"))
  f:close()

  local msg = string.format("Wrote %s (%d pad%s, %s)",
    pakettiFSPath.basename(xpm_path), math.min(#regions, MPC_MAX_PADS),
    #regions == 1 and "" or "s", wav_name)
  if dropped > 0 then
    msg = msg .. string.format("; %d more dropped, an MPC program takes %d", dropped, MPC_MAX_PADS)
  end
  return true, msg
end

--------------------------------------------------------------------------------
-- Decent Sampler (.dspreset)
--------------------------------------------------------------------------------

function PakettiDecentSamplerExport(ds_path)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end

  local regions, parent, err = instrument_regions(instrument)
  if not regions then return false, err end

  local base = pakettiFSPath.basename(ds_path):gsub("%.dspreset$", "")
  local wav_name = write_shared_wav(parent, ds_path, base)
  if not wav_name then return false, "could not write the WAV beside the preset" end

  -- start low enough that the whole set fits inside 128 notes
  local first_note = DS_FIRST_NOTE
  if first_note + #regions - 1 > 127 then first_note = 128 - #regions end
  if first_note < 0 then first_note = 0 end

  local out = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<DecentSampler>',
    '  <groups>',
    '    <group>',
  }
  local written = 0
  for i = 1, #regions do
    local note = first_note + i - 1
    if note > 127 then break end
    local r = regions[i]
    out[#out + 1] = string.format(
      '      <sample path="%s" rootNote="%d" loNote="%d" hiNote="%d" start="%d" end="%d" />',
      xml_attr(wav_name), note, note, note, r.start_frame, r.end_frame)
    written = written + 1
  end
  out[#out + 1] = '    </group>'
  out[#out + 1] = '  </groups>'
  out[#out + 1] = '</DecentSampler>'

  local f = io.open(ds_path, "wb")
  if not f then return false, "could not write " .. ds_path end
  f:write(table.concat(out, "\n"))
  f:close()

  return true, string.format("Wrote %s (%d region%s from note %d, %s)",
    pakettiFSPath.basename(ds_path), written, written == 1 and "" or "s",
    first_note, wav_name)
end

--------------------------------------------------------------------------------
-- Elektron multi-sample mapping (_slices.txt + one WAV per slice)
--------------------------------------------------------------------------------

function PakettiElektronMultiSampleExport(txt_path)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end

  local regions, _, err = instrument_regions(instrument)
  if not regions then return false, err end

  local dir = pakettiFSPath.dirname(txt_path)
  local base = pakettiFSPath.basename(txt_path):gsub("_slices%.txt$", ""):gsub("%.txt$", "")

  local dropped = math.max(0, #regions - EL_MAX_ZONES)
  local count = math.min(#regions, EL_MAX_ZONES)

  local out = {
    "# ELEKTRON MULTI-SAMPLE MAPPING FORMAT",
    "version = 0",
    string.format("name = '%s'", tostring(base):gsub("'", "\\'")),
    "",
  }

  local written = 0
  for i = 1, count do
    local r = regions[i]
    local wav_name = string.format("slice_%02d.wav", i)
    local wav_path = pakettiFSPath.join(dir, wav_name)
    local ok = pcall(function() return r.sample.sample_buffer:save_as(wav_path, "wav") end)
    if ok and io.exists(wav_path) then
      local pitch = EL_FIRST_PITCH + written
      if pitch > 127 then break end
      out[#out + 1] = "[[key-zones]]"
      out[#out + 1] = string.format("pitch = %d", pitch)
      out[#out + 1] = string.format("key-center = %d.0", pitch)
      out[#out + 1] = ""
      out[#out + 1] = "[[key-zones.velocity-layers]]"
      out[#out + 1] = "velocity = 0.49411765"
      out[#out + 1] = "strategy = 'Forward'"
      out[#out + 1] = ""
      out[#out + 1] = "[[key-zones.velocity-layers.sample-slots]]"
      out[#out + 1] = string.format("sample = '%s'", wav_name)
      out[#out + 1] = ""
      written = written + 1
    end
  end

  if written == 0 then return false, "none of the slices could be written as WAV" end

  local f = io.open(txt_path, "wb")
  if not f then return false, "could not write " .. txt_path end
  f:write(table.concat(out, "\n"))
  f:close()

  local msg = string.format("Wrote %s (%d zone%s, %d WAV%s)",
    pakettiFSPath.basename(txt_path), written, written == 1 and "" or "s",
    written, written == 1 and "" or "s")
  if dropped > 0 then
    msg = msg .. string.format("; %d more dropped, the format takes %d", dropped, EL_MAX_ZONES)
  end
  return true, msg
end

--------------------------------------------------------------------------------
-- Dialogs and registration
--------------------------------------------------------------------------------

local function export_dialog(extension, title, fn, suffix)
  return function()
    local path = renoise.app():prompt_for_filename_to_write(extension, title)
    if not path or path == "" then return end
    if not path:lower():match(suffix:gsub("%.", "%%.") .. "$") then
      path = path:gsub("%.[^.]+$", "") .. suffix
    end
    local ok, msg = fn(path)
    if ok then renoise.app():show_status(msg)
    else renoise.app():show_error(title .. " failed.\n\n" .. tostring(msg)) end
    print("-- " .. title .. ": " .. tostring(msg))
  end
end

PakettiMPCExportDialog = export_dialog("xpm", "Export Akai MPC program", PakettiMPCExport, ".xpm")
PakettiDecentSamplerExportDialog = export_dialog("dspreset", "Export Decent Sampler preset", PakettiDecentSamplerExport, ".dspreset")
PakettiElektronMultiSampleExportDialog = export_dialog("txt", "Export Elektron multi-sample mapping", PakettiElektronMultiSampleExport, "_slices.txt")

local sampler_exports = {
  { label = "Akai MPC Program (.xpm)", fn = function() PakettiMPCExportDialog() end,
    key = "Export Akai MPC Program" },
  { label = "Decent Sampler Preset (.dspreset)", fn = function() PakettiDecentSamplerExportDialog() end,
    key = "Export Decent Sampler Preset" },
  { label = "Elektron Multi-Sample Mapping (_slices.txt)", fn = function() PakettiElektronMultiSampleExportDialog() end,
    key = "Export Elektron Multi-Sample Mapping" },
}

for _, e in ipairs(sampler_exports) do
  PakettiAddMenuEntry{ name = "Main Menu:File:Paketti Export:" .. e.label .. "...", invoke = e.fn }
  PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export " .. e.label .. "...", invoke = e.fn }
  PakettiAddMenuEntry{ name = "Sample Editor:Paketti:Export:Export " .. e.label .. "...", invoke = e.fn }
  renoise.tool():add_keybinding{ name = "Global:Paketti:" .. e.key, invoke = e.fn }
end
