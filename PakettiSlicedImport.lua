--[[============================================================================
PakettiSlicedImport.lua — read back the sliced formats Paketti could only write

Paketti could export an Akai MPC program, an OP-XY preset, a Digitakt II preset
and an Apple Loop, but not read any of them: every one was a one-way street. So
was AIFF, whose MARK chunk is the AIFF counterpart of the WAV `cue ` chunk that
PakettiWavCueExtract already handles in both directions.

This file closes both gaps.

  .xpm            Akai MPC program. XML naming one WAV beside it, with a
                  SampleStart/SampleEnd window per pad.
  .preset.zip     OP-XY. ZIP holding patch.json plus one WAV per region.
  .dt2pst         Digitakt II. ZIP holding a WAV and a binary preset whose
                  8-byte entries carry the slice frames.
  .caf            Apple Loop. Big-endian CAF; slice positions live in the beat
                  marker uuid chunk, tempo in the loop metadata uuid chunk.
  .aif / .aiff    MARK chunk markers become slices; and the export writes them.

Each reader hands the same shape to one builder: an audio file plus a list of
frame positions. Every writer these invert lives beside it — PakettiSamplerExports,
PakettiOPXYExport, PakettiDT2Export, PakettiAppleLoopExport — and the formats are
documented where those files document them.
============================================================================]]--

--------------------------------------------------------------------------------
-- Shared: turn an audio file plus frame positions into a sliced instrument
--------------------------------------------------------------------------------

local function be32(s, p)
  local a, b, c, d = s:byte(p, p + 3)
  if not d then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

local function be16(s, p)
  local a, b = s:byte(p, p + 1)
  if not b then return nil end
  return a * 256 + b
end

local function le32(s, p)
  local a, b, c, d = s:byte(p, p + 3)
  if not d then return nil end
  return a + b * 256 + c * 65536 + d * 16777216
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. tostring(path) end
  local data = f:read("*a")
  f:close()
  if not data or #data == 0 then return nil, tostring(path) .. " is empty" end
  return data
end

local function write_temp(data, ext)
  local tmp = os.tmpname() .. (ext or ".wav")
  local f = io.open(tmp, "wb")
  if not f then return nil end
  f:write(data)
  f:close()
  return tmp
end

--- Build a new instrument holding one audio file, sliced at the given frames.
---
--- audio is either { path = "..." } for a file already on disk, or
--- { data = "...", ext = ".wav" } for bytes to drop in a temporary file.
--- frames is a list of 1-based frame positions; 0 or 1 is dropped, since
--- Renoise's first slice is the start of the sample and is not a marker.
---
--- Returns the instrument and the number of slices placed, or nil plus a reason.
function PakettiSlicedImportBuild(name, audio, frames, opts)
  opts = opts or {}
  local path, temp = audio.path, nil
  if not path then
    temp = write_temp(audio.data, audio.ext or ".wav")
    if not temp then return nil, "could not write a temporary audio file" end
    path = temp
  end

  local song = renoise.song()
  if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
    if temp then os.remove(temp) end
    return nil, "could not create an instrument"
  end
  song.selected_instrument_index = song.selected_instrument_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.selected_instrument
  instrument.name = name
  local sample = instrument.samples[1]

  -- load_from returns false rather than raising when Renoise has no decoder for
  -- the file, and the template's placeholder keeps has_sample_data true, so the
  -- return value is the only honest test of whether anything loaded.
  local ok, loaded = pcall(function() return sample.sample_buffer:load_from(path) end)
  if temp then os.remove(temp) end
  if not ok or loaded == false or not sample.sample_buffer.has_sample_data then
    return nil, "Renoise could not decode the audio"
  end
  sample.name = name

  local total = sample.sample_buffer.number_of_frames
  local placed, last = 0, -1
  for _, f in ipairs(frames or {}) do
    if placed >= 255 then break end
    local frame = math.floor(f)
    if frame > 1 and frame < total and frame ~= last then
      if pcall(function() sample:insert_slice_marker(frame) end) then
        placed = placed + 1
        last = frame
      end
    end
  end

  if opts.bpm and opts.bpm > 0 then
    sample.beat_sync_lines = sample.beat_sync_lines
  end

  return instrument, placed
end

--- The common ending: report, or clean up after a failed read.
local function finish(ok_name, instrument, placed, extra)
  local msg = string.format("%s: %d slice%s", ok_name, placed, placed == 1 and "" or "s")
  if extra then msg = msg .. ", " .. extra end
  renoise.app():show_status("Paketti: imported " .. msg)
  print("PakettiSlicedImport: " .. msg)
  return true, msg
end

--------------------------------------------------------------------------------
-- AIFF markers — the MARK chunk, both directions
--------------------------------------------------------------------------------

-- An AIFF MARK chunk is a uint16 count followed by, per marker, a uint16 id, a
-- uint32 frame position and a Pascal string (one length byte, then that many
-- bytes, padded to an even total). AIFF-C ("AIFC") carries the same chunk, so
-- both form types are read.

--- Returns a list of { position = <frame>, name = "..." }, or nil plus a reason.
function PakettiAIFFReadMarkers(data)
  if type(data) ~= "string" or #data < 12 then return nil, "not an AIFF file" end
  if data:sub(1, 4) ~= "FORM" then return nil, "not an AIFF file (no FORM header)" end
  local form = data:sub(9, 12)
  if form ~= "AIFF" and form ~= "AIFC" then
    return nil, "not an AIFF file (form type is '" .. form .. "')"
  end

  local markers = {}
  local p = 13
  while p + 8 <= #data do
    local id = data:sub(p, p + 3)
    local size = be32(data, p + 4)
    if not size then break end
    if id == "MARK" then
      local q = p + 8
      local count = be16(data, q) or 0
      q = q + 2
      for _ = 1, count do
        if q + 6 > #data then break end
        local mid = be16(data, q)
        local pos = be32(data, q + 2)
        local len = data:byte(q + 6) or 0
        local label = data:sub(q + 7, q + 6 + len)
        markers[#markers + 1] = { id = mid, position = pos, name = label }
        -- the Pascal string's length byte counts toward the even padding
        q = q + 7 + len
        if (len + 1) % 2 == 1 then q = q + 1 end
      end
    end
    p = p + 8 + size + (size % 2)
  end

  if #markers == 0 then return nil, "this AIFF carries no MARK chunk" end
  table.sort(markers, function(a, b) return a.position < b.position end)
  return markers
end

--- Import an AIFF, turning its MARK positions into slice markers.
function PakettiAIFFImportWithMarkers(path)
  local data, err = read_file(path)
  if not data then return false, err end
  local markers, merr = PakettiAIFFReadMarkers(data)
  if not markers then return false, merr end

  local frames = {}
  for _, m in ipairs(markers) do frames[#frames + 1] = m.position + 1 end

  local name = pakettiFSPath.basename(path):gsub("%.[^.]+$", "")
  local instrument, placed = PakettiSlicedImportBuild(name, { path = path }, frames)
  if not instrument then return false, placed end
  return finish("AIFF " .. name, instrument, placed,
    string.format("%d marker%s in the file", #markers, #markers == 1 and "" or "s"))
end

local function aiff_be32(v)
  v = math.floor(v)
  return string.char(math.floor(v / 16777216) % 256, math.floor(v / 65536) % 256,
                     math.floor(v / 256) % 256, v % 256)
end

local function aiff_be16(v)
  v = math.floor(v)
  return string.char(math.floor(v / 256) % 256, v % 256)
end

--- Build a MARK chunk from a list of 0-based frame positions.
function PakettiAIFFBuildMarkChunk(positions)
  local body = { aiff_be16(#positions) }
  for i, pos in ipairs(positions) do
    local label = string.format("Slice %02d", i + 1)
    local pascal = string.char(#label) .. label
    -- the length byte counts toward the chunk's even padding
    if #pascal % 2 == 1 then pascal = pascal .. "\0" end
    body[#body + 1] = aiff_be16(i) .. aiff_be32(pos) .. pascal
  end
  local mark_body = table.concat(body)
  return "MARK" .. aiff_be32(#mark_body) .. mark_body
       .. ((#mark_body % 2 == 1) and "\0" or "")
end

--- Export the selected sample as an AIFF whose MARK chunk holds its slices.
---
--- Renoise writes the AIFF itself, so nothing here transcodes audio: the file
--- is saved, then the MARK chunk is spliced in ahead of the sound data and the
--- FORM size corrected. That keeps the audio bit-identical to what Renoise
--- would have written on its own.
function PakettiAIFFExportWithMarkers(aif_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then return false, "the selected instrument has no samples" end
  local sample = instrument.samples[1]
  if not sample.sample_buffer.has_sample_data then
    return false, "the first sample of the selected instrument is empty"
  end

  local tmp = os.tmpname() .. ".aif"
  local ok = pcall(function() return sample.sample_buffer:save_as(tmp, "aiff") end)
  if not ok or not io.exists(tmp) then
    pcall(function() os.remove(tmp) end)
    return false, "Renoise could not write the AIFF"
  end
  local data, err = read_file(tmp)
  os.remove(tmp)
  if not data then return false, err end
  if data:sub(1, 4) ~= "FORM" then return false, "Renoise wrote something that is not an AIFF" end

  -- One marker per slice. Renoise's slice_markers are 1-based frames and the
  -- first slice is the start of the sample, which needs no marker of its own.
  local positions = {}
  for _, m in ipairs(sample.slice_markers) do
    positions[#positions + 1] = math.max(0, m - 1)
  end

  local mark = PakettiAIFFBuildMarkChunk(positions)

  -- Splice ahead of SSND: markers are metadata and readers expect them before
  -- the sound data, which is also where every AIFF Renoise reads puts them.
  local at = data:find("SSND", 13, true)
  if not at then return false, "the AIFF Renoise wrote has no SSND chunk" end
  local out = data:sub(1, at - 1) .. mark .. data:sub(at)
  -- FORM's size counts everything after the size field itself.
  out = out:sub(1, 4) .. aiff_be32(#out - 8) .. out:sub(9)

  if not aif_path:lower():match("%.aiff?$") then aif_path = aif_path .. ".aif" end
  local f = io.open(aif_path, "wb")
  if not f then return false, "could not write " .. aif_path end
  f:write(out)
  f:close()

  local msg = string.format("Wrote %s (%d marker%s)",
    pakettiFSPath.basename(aif_path), #positions, #positions == 1 and "" or "s")
  renoise.app():show_status("Paketti: " .. msg)
  return true, msg
end

--------------------------------------------------------------------------------
-- Apple Loop (.caf)
--------------------------------------------------------------------------------

-- CAF is big-endian: "caff", a version/flags pair, then chunks of a 4-byte type
-- and a 64-bit size. Slice positions live in a uuid chunk stamped with Apple's
-- beat marker UUID, tempo and beat count in the loop metadata one. Those two
-- UUIDs are the same constants PakettiAppleLoopExport writes.

local CAF_BEAT_MARKER_UUID = "\041\209\076\233\151\168\068\120\153\210\028\076\061\112\131\140"
local CAF_LOOP_META_UUID   = "\076\204\064\076\138\068\075\144\184\032\090\181\052\188\185\187"

local function caf_be64(s, p)
  local v = 0
  for i = 0, 7 do
    local b = s:byte(p + i)
    if not b then return nil end
    v = v * 256 + b
  end
  return v
end

--- Returns { rate, channels, bits, frames, markers = {frame,...}, tempo, beats }
function PakettiCAFReadInfo(data)
  if type(data) ~= "string" or #data < 8 then return nil, "not a CAF file" end
  if data:sub(1, 4) ~= "caff" then return nil, "not a CAF file (no 'caff' header)" end

  local info = { markers = {} }
  local p = 9
  while p + 12 <= #data do
    local id = data:sub(p, p + 3)
    local size = caf_be64(data, p + 4)
    if not size then break end
    local body_at = p + 12
    -- A 'data' chunk may carry -1 for "to end of file", which is legal.
    if size < 0 or size > #data then size = #data - body_at + 1 end

    if id == "desc" then
      -- 8-byte float rate, 4-byte format id, flags, bytes/packet,
      -- frames/packet, channels, bits
      local hi = be32(data, body_at)
      local lo = be32(data, body_at + 4)
      if hi then
        -- IEEE-754 double, big-endian, decoded without bit operations
        local sign = (hi >= 2147483648) and -1 or 1
        if sign < 0 then hi = hi - 2147483648 end
        local exp = math.floor(hi / 1048576)
        local mant = (hi % 1048576) * 4294967296 + lo
        if exp == 0 then
          info.rate = sign * mant * 2 ^ (-1074)
        else
          info.rate = sign * (1 + mant / 4503599627370496) * 2 ^ (exp - 1023)
        end
        info.rate = math.floor(info.rate + 0.5)
      end
      -- CAFAudioFormat: rate 0..7, format id 8..11, flags 12..15,
      -- bytes/packet 16..19, frames/packet 20..23, channels 24..27, bits 28..31
      info.block_align = be32(data, body_at + 16)
      info.channels = be32(data, body_at + 24)
      info.bits = be32(data, body_at + 28)
    elseif id == "data" then
      -- first 4 bytes are the edit count
      info.pcm_at = body_at + 4
      info.pcm_bytes = size - 4
    elseif id == "uuid" then
      local uuid = data:sub(body_at, body_at + 15)
      local q = body_at + 16
      if uuid == CAF_BEAT_MARKER_UUID then
        -- header is 5 fields, then a count, then 12 bytes per marker whose
        -- last 4 are the frame position
        local count = be32(data, q + 16) or 0
        local at = q + 20
        for _ = 1, count do
          local frame = be32(data, at + 8)
          if not frame then break end
          info.markers[#info.markers + 1] = frame
          at = at + 12
        end
      elseif uuid == CAF_LOOP_META_UUID then
        local count = be32(data, q) or 0
        local at = q + 4
        for _ = 1, count do
          local k = data:match("^([^%z]*)%z", at)
          if not k then break end
          at = at + #k + 1
          local v = data:match("^([^%z]*)%z", at)
          if not v then break end
          at = at + #v + 1
          if k == "tempo" then info.tempo = tonumber(v) end
          if k == "beat count" then info.beats = tonumber(v) end
        end
      end
    end

    p = body_at + size
  end

  if not info.pcm_at then return nil, "this CAF has no audio data" end
  if info.block_align and info.block_align > 0 then
    info.frames = math.floor(info.pcm_bytes / info.block_align)
  end
  table.sort(info.markers)
  return info
end

--- Import an Apple Loop, its beat markers becoming slices.
---
--- Renoise decodes CAF natively through CoreAudio on macOS, so the file is
--- handed over as it is and only the markers are parsed here. Where CoreAudio
--- is not available the load fails and says so, rather than pretending.
function PakettiAppleLoopImport(path)
  local data, err = read_file(path)
  if not data then return false, err end
  local info, ierr = PakettiCAFReadInfo(data)
  if not info then return false, ierr end

  local frames = {}
  for _, m in ipairs(info.markers) do frames[#frames + 1] = m + 1 end
  -- The exporter writes a final marker at the end of the file to close the last
  -- region; as a slice point it would sit past the audio, so it is dropped.
  if info.frames and #frames > 0 and frames[#frames] >= info.frames then
    table.remove(frames)
  end

  local name = pakettiFSPath.basename(path):gsub("%.[^.]+$", "")
  local instrument, placed = PakettiSlicedImportBuild(name, { path = path }, frames)
  if not instrument then return false, placed end

  if info.tempo and info.tempo > 0 then
    print(string.format("PakettiSlicedImport: %s carries %.3f BPM, %s beats",
      name, info.tempo, tostring(info.beats)))
  end
  return finish("Apple Loop " .. name, instrument, placed,
    info.tempo and string.format("%.1f BPM", info.tempo) or nil)
end

--------------------------------------------------------------------------------
-- OP-XY preset (.preset.zip)
--------------------------------------------------------------------------------

-- A ZIP holding patch.json and one WAV per region. The regions array names each
-- WAV, so the audio is reassembled by concatenating the region files in order
-- and slicing at the joins -- which is what makes an OP-XY kit round-trip into
-- the single sliced sample Renoise works with.

--- Pull the "sample" filenames out of patch.json, in order.
local function opxy_region_files(json)
  local files = {}
  for regions in json:gmatch('"regions"%s*:%s*%[(.*)%]') do
    for name in regions:gmatch('"sample"%s*:%s*"([^"]*)"') do
      files[#files + 1] = name
    end
  end
  return files
end

--- Concatenate a list of WAVs into one, keeping the first one's format.
--- Returns the WAV bytes and the frame position each source starts at.
local function join_wavs(list)
  local fmt, pcm_parts, starts = nil, {}, {}
  local total_frames, block_align = 0, nil
  for _, wav in ipairs(list) do
    if wav:sub(1, 4) ~= "RIFF" or wav:sub(9, 12) ~= "WAVE" then
      return nil, "one of the slices is not a WAV"
    end
    local p, this_fmt, pcm = 13, nil, nil
    while p + 8 <= #wav do
      local id = wav:sub(p, p + 3)
      local size = le32(wav, p + 4)
      if not size then break end
      if id == "fmt " then this_fmt = wav:sub(p + 8, p + 7 + size) end
      if id == "data" then pcm = wav:sub(p + 8, p + 7 + size) end
      p = p + 8 + size + (size % 2)
    end
    if not this_fmt or not pcm then return nil, "one of the slices has no audio" end
    if not fmt then
      fmt = this_fmt
      local ch = (this_fmt:byte(3) or 0) + (this_fmt:byte(4) or 0) * 256
      local bits = (this_fmt:byte(15) or 16) + (this_fmt:byte(16) or 0) * 256
      block_align = math.max(1, ch * math.floor(bits / 8))
    end
    starts[#starts + 1] = total_frames
    total_frames = total_frames + math.floor(#pcm / block_align)
    pcm_parts[#pcm_parts + 1] = pcm
  end
  if not fmt then return nil, "no audio in the preset" end

  local pcm = table.concat(pcm_parts)
  local function u32(v)
    return string.char(v % 256, math.floor(v / 256) % 256,
                       math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
  end
  local body = "WAVE" .. "fmt " .. u32(#fmt) .. fmt .. "data" .. u32(#pcm) .. pcm
  return "RIFF" .. u32(#body) .. body, starts
end

function PakettiOPXYImport(path)
  local entries, by_name = PakettiZipRead(path)
  if not entries then return false, by_name end

  local patch = by_name["patch.json"]
  if not patch then return false, "this preset has no patch.json" end
  local files = opxy_region_files(patch.data)
  if #files == 0 then return false, "patch.json names no regions" end

  local wavs = {}
  for _, name in ipairs(files) do
    local e = by_name[name]
    if not e then return false, "patch.json names '" .. name .. "', which is not in the preset" end
    wavs[#wavs + 1] = e.data
  end

  local joined, starts = join_wavs(wavs)
  if not joined then return false, starts end

  local frames = {}
  for i = 2, #starts do frames[#frames + 1] = starts[i] + 1 end

  local name = pakettiFSPath.basename(path):gsub("%.preset%.zip$", ""):gsub("%.[^.]+$", "")
  local instrument, placed = PakettiSlicedImportBuild(name, { data = joined, ext = ".wav" }, frames)
  if not instrument then return false, placed end
  return finish("OP-XY " .. name, instrument, placed,
    string.format("%d region%s", #files, #files == 1 and "" or "s"))
end

--------------------------------------------------------------------------------
-- Digitakt II preset (.dt2pst)
--------------------------------------------------------------------------------

-- A ZIP holding manifest.json, one WAV under Samples/, and a binary preset with
-- no extension. The slice table in that preset is a run of 8-byte entries
-- 00 22 <uint32 LE frame> 00 08, which is exactly what PakettiDT2Export writes.

function PakettiDT2Import(path)
  local entries, by_name = PakettiZipRead(path)
  if not entries then return false, by_name end

  local wav, preset = nil, nil
  for _, e in ipairs(entries) do
    local lower = e.name:lower()
    if lower:match("%.wav$") then
      wav = wav or e
    elseif not lower:match("%.json$") then
      -- the binary preset is the member with no extension
      if not e.name:match("%.[^./]+$") then preset = preset or e end
    end
  end
  if not wav then return false, "this preset holds no WAV" end

  local frames = {}
  if preset then
    local d = preset.data
    local p = 1
    while true do
      local at = d:find("\0\34", p, true)
      if not at then break end
      local frame = le32(d, at + 2)
      local tail = d:sub(at + 6, at + 7)
      if frame and tail == "\0\8" then
        frames[#frames + 1] = frame + 1
        p = at + 8
      else
        p = at + 1
      end
    end
  end
  table.sort(frames)

  local name = pakettiFSPath.basename(path):gsub("%.dt2pst$", "")
  local instrument, placed = PakettiSlicedImportBuild(name, { data = wav.data, ext = ".wav" }, frames)
  if not instrument then return false, placed end
  return finish("Digitakt II " .. name, instrument, placed,
    (not preset) and "no slice table in the preset" or nil)
end

--------------------------------------------------------------------------------
-- Akai MPC program (.xpm)
--------------------------------------------------------------------------------

-- XML. Each Instrument/Layer names a SampleName -- without its extension, which
-- is how an MPC stores it -- and a SampleStart/SampleEnd frame window into that
-- file. Every pad of a sliced program points into the same WAV, so the windows
-- are the slice boundaries.

function PakettiMPCImport(path)
  local data, err = read_file(path)
  if not data then return false, err end
  if not data:find("MPCVObject", 1, true) then
    return false, "this is not an MPC program (no MPCVObject)"
  end

  local layers = {}
  for block in data:gmatch("<Layer[^>]*>(.-)</Layer>") do
    local sname = block:match("<SampleName>(.-)</SampleName>")
    local sstart = tonumber(block:match("<SampleStart>(%-?%d+)</SampleStart>"))
    local send = tonumber(block:match("<SampleEnd>(%-?%d+)</SampleEnd>"))
    if sname and sname ~= "" then
      layers[#layers + 1] = { name = sname, start_frame = sstart or 0, end_frame = send }
    end
  end
  if #layers == 0 then return false, "this program names no samples" end

  -- MPC stores the name without an extension and resolves it against the
  -- program's own folder, so both common extensions are tried there first.
  local dir = pakettiFSPath.dirname(path)
  local wanted = layers[1].name
  local audio = nil
  for _, ext in ipairs({".wav", ".WAV", ".aif", ".aiff", ".AIF", ""}) do
    local candidate = pakettiFSPath.join(dir, wanted .. ext)
    if io.exists(candidate) then audio = candidate break end
  end
  if not audio then
    audio = pakettiFSPath.resolve(wanted .. ".wav", path)
  end
  if not audio or not io.exists(audio) then
    return false, string.format("cannot find '%s' beside the program", wanted)
  end

  -- Only the pads pointing at that one file describe slices of it; a program
  -- built from separate one-shots has nothing to slice.
  local frames, shared = {}, 0
  for _, l in ipairs(layers) do
    if l.name == wanted then
      shared = shared + 1
      if l.start_frame > 0 then frames[#frames + 1] = l.start_frame + 1 end
    end
  end
  table.sort(frames)

  local name = pakettiFSPath.basename(path):gsub("%.xpm$", "")
  local instrument, placed = PakettiSlicedImportBuild(name, { path = audio }, frames)
  if not instrument then return false, placed end
  return finish("MPC " .. name, instrument, placed,
    string.format("%d pad%s", #layers, #layers == 1 and "" or "s"))
end

--------------------------------------------------------------------------------
-- Dialogs
--------------------------------------------------------------------------------

local function ask_and_import(patterns, title, fn)
  local path = renoise.app():prompt_for_filename_to_read(patterns, title)
  if not path or path == "" then return end
  local ok, msg = fn(path)
  if not ok then
    renoise.app():show_status("Paketti: " .. tostring(msg))
    print("PakettiSlicedImport error: " .. tostring(msg))
  end
end

function PakettiMPCImportDialog()
  ask_and_import({"*.xpm", "*.XPM"}, "Import an Akai MPC program", PakettiMPCImport)
end

function PakettiOPXYImportDialog()
  ask_and_import({"*.zip", "*.ZIP"}, "Import an OP-XY preset", PakettiOPXYImport)
end

function PakettiDT2ImportDialog()
  ask_and_import({"*.dt2pst", "*.DT2PST"}, "Import a Digitakt II preset", PakettiDT2Import)
end

function PakettiAppleLoopImportDialog()
  ask_and_import({"*.caf", "*.CAF"}, "Import an Apple Loop", PakettiAppleLoopImport)
end

function PakettiAIFFImportDialog()
  ask_and_import({"*.aif", "*.aiff", "*.AIF", "*.AIFF"},
    "Import an AIFF and use its markers as slices", PakettiAIFFImportWithMarkers)
end

function PakettiAIFFExportDialog()
  local path = renoise.app():prompt_for_filename_to_write("aif",
    "Save as AIFF with slice markers")
  if not path or path == "" then return end
  local ok, msg = PakettiAIFFExportWithMarkers(path)
  if not ok then
    renoise.app():show_status("Paketti: " .. tostring(msg))
    print("PakettiSlicedImport error: " .. tostring(msg))
  end
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local IMPORTS = {
  { label = "Akai MPC Program (.xpm)...",      fn = function() PakettiMPCImportDialog() end,
    key = "Import Akai MPC Program" },
  { label = "OP-XY Preset (.preset.zip)...",   fn = function() PakettiOPXYImportDialog() end,
    key = "Import OP-XY Preset" },
  { label = "Digitakt II Preset (.dt2pst)...", fn = function() PakettiDT2ImportDialog() end,
    key = "Import Digitakt II Preset" },
  { label = "Apple Loop (.caf)...",            fn = function() PakettiAppleLoopImportDialog() end,
    key = "Import Apple Loop" },
  { label = "AIFF with Markers (.aif)...",     fn = function() PakettiAIFFImportDialog() end,
    key = "Import AIFF with Markers" },
}

for _, item in ipairs(IMPORTS) do
  PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:" .. item.label, invoke = item.fn}
  PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:" .. item.label,
                      invoke = item.fn}
  PakettiAddMenuEntry{name = "Instrument Box:Paketti:Load:" .. item.label, invoke = item.fn}
  renoise.tool():add_keybinding{name = "Global:Paketti:" .. item.key, invoke = item.fn}
  renoise.tool():add_midi_mapping{name = "Paketti:" .. item.key,
    invoke = function(message) if message:is_trigger() then item.fn() end end}
end

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:AIFF with Slice Markers (.aif)...",
  invoke = function() PakettiAIFFExportDialog() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export AIFF with Slice Markers (.aif)...",
  invoke = function() PakettiAIFFExportDialog() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Export AIFF with Slice Markers (.aif)...",
  invoke = function() PakettiAIFFExportDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Export AIFF with Slice Markers",
  invoke = function() PakettiAIFFExportDialog() end}
renoise.tool():add_midi_mapping{name = "Paketti:Export AIFF with Slice Markers",
  invoke = function(message) if message:is_trigger() then PakettiAIFFExportDialog() end end}
