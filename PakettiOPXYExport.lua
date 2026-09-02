--[[============================================================================
PakettiOPXYExport.lua — Teenage Engineering OP-XY preset export (.preset.zip)

An OP-XY drum preset is a ZIP holding:

  patch.json          engine, envelope and a "regions" array
  slice_01.wav .. slice_NN.wav   one WAV per region, up to 24

Unlike the Ableton Drum Rack, where every pad points into one shared file with a
start and end, OP-XY wants each region as its own audio file. Renoise makes that
easy: a sliced instrument's slices are real samples whose buffers already view
only their own frames, so `sample_buffer:save_as` on samples[2..] writes exactly
one slice each.

Regions are laid out from key 53 upward, which is where the device's pads start.

Uses Paketti's stored-entry ZIP writer (PakettiDeflate.lua). The JSON layout is
transcribed from chirashi (github.com/g-lok/chirashi).
============================================================================]]--

local OPXY_MAX_REGIONS = 24
local OPXY_FIRST_KEY = 53

--- Render one Renoise sample to a WAV and hand back the bytes.
local function sample_to_wav_bytes(sample)
  local tmp = os.tmpname() .. ".wav"
  local ok = pcall(function() return sample.sample_buffer:save_as(tmp, "wav") end)
  if not ok or not io.exists(tmp) then
    pcall(function() os.remove(tmp) end)
    return nil
  end
  local f = io.open(tmp, "rb")
  local data = f and f:read("*a") or nil
  if f then f:close() end
  os.remove(tmp)
  return data
end

local function opxy_patch_json(regions)
  local out = {
    '{"engine":{"bendrange":8191,"highpass":0,',
    '"modulation":{"aftertouch":{"amount":16384,"target":0}},',
    '"params":[16384,16384,16384,16384,16384,16384,16384,16384],',
    '"playmode":"poly","transpose":0,"tuning":{"root":0,"scale":0},',
    '"velocity":{"sensitivity":19660},"volume":28505,"width":0},',
    '"envelope":{"amp":{"attack":0,"decay":0,"release":32767,"sustain":32604},',
    '"filter":{"attack":0,"decay":0,"release":32767,"sustain":32604}},',
    '"fx":{"active":false},"lfo":{"active":false},',
    '"octave":0,"platform":"OP-XY","type":"drum","version":4,',
    '"regions":[',
  }

  for i = 1, #regions do
    local r = regions[i]
    if i > 1 then out[#out + 1] = "," end
    out[#out + 1] = string.format(
      '{"fade.in":0,"fade.out":0,"framecount":%d,"gain":0,"hikey":%d,"lokey":%d,' ..
      '"pan":0,"pitch.keycenter":60,"playmode":"%s","reverse":false,' ..
      '"sample":"%s","sample.end":%d,"sample.start":0,"transpose":%d,"tune":0}',
      r.frames, r.key, r.key, r.playmode, r.file, r.frames, r.transpose)
  end

  out[#out + 1] = "]}"
  return table.concat(out)
end

--- Write the selected instrument as an OP-XY preset.
function PakettiOPXYExport(zip_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end

  -- a sliced instrument contributes its slices; anything else its samples
  local sources = {}
  local first = instrument.samples[1]
  if #first.slice_markers > 0 then
    for i = 2, #instrument.samples do sources[#sources + 1] = instrument.samples[i] end
  else
    for i = 1, #instrument.samples do
      if instrument.samples[i].sample_buffer.has_sample_data then
        sources[#sources + 1] = instrument.samples[i]
      end
    end
  end

  if #sources == 0 then
    return false, "nothing to export: no sample in the instrument holds audio"
  end

  local dropped = 0
  if #sources > OPXY_MAX_REGIONS then
    dropped = #sources - OPXY_MAX_REGIONS
    for i = #sources, OPXY_MAX_REGIONS + 1, -1 do sources[i] = nil end
  end

  local entries, regions = {}, {}
  for i = 1, #sources do
    local smp = sources[i]
    local data = sample_to_wav_bytes(smp)
    if data then
      local file = string.format("slice_%02d.wav", #regions + 1)
      entries[#entries + 1] = { name = file, data = data }
      regions[#regions + 1] = {
        file = file,
        frames = smp.sample_buffer.number_of_frames,
        key = OPXY_FIRST_KEY + #regions,
        transpose = tonumber(smp.transpose) or 0,
        playmode = (smp.loop_mode ~= renoise.Sample.LOOP_MODE_OFF) and "loop" or "oneshot",
      }
    end
  end

  if #regions == 0 then
    return false, "none of the samples could be rendered to WAV"
  end

  -- patch.json first, the way the device's own presets are laid out
  table.insert(entries, 1, { name = "patch.json", data = opxy_patch_json(regions) })

  local ok, err = PakettiZipWrite(zip_path, entries)
  if not ok then return false, err end

  local msg = string.format("Wrote %s (%d region%s)",
    pakettiFSPath.basename(zip_path), #regions, #regions == 1 and "" or "s")
  if dropped > 0 then
    msg = msg .. string.format("; %d more dropped, the device takes %d",
      dropped, OPXY_MAX_REGIONS)
  end
  return true, msg
end

function PakettiOPXYExportDialog()
  local path = renoise.app():prompt_for_filename_to_write(
    "zip", "Export OP-XY preset (.preset.zip)")
  if not path or path == "" then return end
  if not path:lower():match("%.preset%.zip$") then
    path = path:gsub("%.zip$", "") .. ".preset.zip"
  end
  local ok, msg = PakettiOPXYExport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("OP-XY export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiOPXYExport: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:OP-XY Preset (.preset.zip)...",
  invoke=function() PakettiOPXYExportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export OP-XY Preset (.preset.zip)...",
  invoke=function() PakettiOPXYExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export OP-XY Preset (.preset.zip)...",
  invoke=function() PakettiOPXYExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export OP-XY Preset",
  invoke = function() PakettiOPXYExportDialog() end }
