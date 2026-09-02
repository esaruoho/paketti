--[[============================================================================
PakettiAbleton.lua — Ableton Live preset import/export

Live stores its presets as XML in a gzip wrapper: .adv is a single device, .adg a
device group (a Drum Rack is a group of Simplers), .als a whole Live Set. Live 12
occasionally writes the XML uncompressed, so both shapes are accepted on read.

The element paths below were taken from real presets, not from a spec:

  .adv   Ableton/OriginalSimpler
  .adg   Ableton/GroupDevicePreset/BranchPresets/DrumBranchPreset
           ZoneSettings/ReceivingNote                     <- the pad's MIDI note
           DevicePresets/AbletonDevicePreset/Device/OriginalSimpler
  .als   Ableton/LiveSet/Tracks/MidiTrack/.../DrumBranch

and inside either sampler device (OriginalSimpler, or MultiSampler when the pad
holds a full Sampler):

  Player/MultiSampleMap/SampleParts/MultiSamplePart
    SampleRef/FileRef/Path            absolute path as last written by Live
    SampleRef/FileRef/RelativePath    path relative to preset or Live Pack
    SampleStart, SampleEnd            frame offsets into the file
    SlicePoints/SlicePoint            TimeInSeconds, from Live's onset analysis
    ManualSlicePoints/SlicePoint      TimeInSeconds, placed by hand
  Globals/PlaybackMode                0 Classic, 1 One-Shot, 2 Slicing

Scoping sample discovery to MultiSamplePart matters: a Drum Rack also carries
SampleRefs for reverb impulse responses under Hybrid/ImpulseResponseHandler, and
those are not instrument content.

Reading needs PakettiDeflate for the gzip layer. Audio never passes through Lua —
the resolved path is handed to Renoise's own sample_buffer:load_from.
============================================================================]]--



--------------------------------------------------------------------------------
-- Minimal XML reader
--
-- Live's XML is attribute-only and deeply nested but never mixed-content, so a
-- flat scanner over "<...>" spans is enough and stays fast on the ~1 MB documents
-- a 128-pad Drum Rack produces.
--------------------------------------------------------------------------------

--- on_progress, when given, is called every few thousand elements. Under a
--- ProcessSlicer pass a function that yields.
function PakettiAbletonParseXML(xml, on_progress)
  local root = { name = "#root", children = {} }
  local stack = { root }
  local depth = 1
  local pos = 1
  local seen = 0
  local len = #xml
  local find, sub, gsub, gmatch = string.find, string.sub, string.gsub, string.gmatch

  while pos <= len do
    local lt = find(xml, "<", pos, true)
    if not lt then break end
    local gt = find(xml, ">", lt + 1, true)
    if not gt then break end

    -- an attribute value may legally contain ">", so keep extending until the
    -- span holds an even number of quotes
    local tag = sub(xml, lt + 1, gt - 1)
    local _, quotes = gsub(tag, '"', '"')
    while quotes % 2 == 1 do
      local nxt = find(xml, ">", gt + 1, true)
      if not nxt then break end
      gt = nxt
      tag = sub(xml, lt + 1, gt - 1)
      _, quotes = gsub(tag, '"', '"')
    end

    local first = sub(tag, 1, 1)
    if first == "?" or first == "!" then
      -- declaration, comment or doctype

    elseif first == "/" then
      if depth > 1 then
        stack[depth] = nil
        depth = depth - 1
      end

    else
      local self_closing = (sub(tag, -1) == "/")
      if self_closing then tag = sub(tag, 1, -2) end

      local name = string.match(tag, "^([%w_:%-%.]+)")
      if name then
        local node = { name = name }
        local rest = sub(tag, #name + 1)
        if find(rest, "=", 1, true) then
          local attrs = nil
          for k, v in gmatch(rest, '([%w_:%-%.]+)%s*=%s*"([^"]*)"') do
            attrs = attrs or {}
            attrs[k] = v
          end
          node.attrs = attrs
        end

        local parent = stack[depth]
        local kids = parent.children
        if not kids then kids = {}; parent.children = kids end
        kids[#kids + 1] = node

        if not self_closing then
          depth = depth + 1
          stack[depth] = node
        end
      end
    end

    pos = gt + 1

    seen = seen + 1
    if on_progress and seen % 4000 == 0 then on_progress(pos, len) end
  end

  return root
end

--- Drum Rack pad notes are stored INVERTED in Live's XML: ZoneSettings holds
--- 128 minus the MIDI note, so the standard C1 base pad (36) is written as 92.
--- Verified across every Drum Rack in a real library -- an 8-pad kit reads 92..85
--- (notes 36..43), a 12-pad kit 92..81 (36..47), a 24-pad slice rack 92..69
--- (36..59). Taking the stored value as a MIDI note lands the pads two octaves
--- high AND reverses their order, because descending stored values are ascending
--- pitches.
local ABLETON_PAD_NOTE_BASE = 128

function PakettiAbletonPadNoteFromXML(stored)
  if not stored or stored < 0 then return -1 end
  local n = ABLETON_PAD_NOTE_BASE - stored
  if n < 0 or n > 127 then return -1 end
  return n
end

function PakettiAbletonPadNoteToXML(note)
  return ABLETON_PAD_NOTE_BASE - note
end

-- first direct child by name
function PakettiAbletonChild(node, name)
  if not node or not node.children then return nil end
  for i = 1, #node.children do
    if node.children[i].name == name then return node.children[i] end
  end
  return nil
end

-- follow a chain of direct children, e.g. ("Player","MultiSampleMap","SampleParts")
function PakettiAbletonPath(node, ...)
  local cur = node
  local names = { ... }
  for i = 1, #names do
    cur = PakettiAbletonChild(cur, names[i])
    if not cur then return nil end
  end
  return cur
end

-- the Value="" attribute of a named direct child
function PakettiAbletonValue(node, name)
  local c = PakettiAbletonChild(node, name)
  if c and c.attrs then return c.attrs.Value end
  return nil
end

-- every descendant with the given name, in document order
function PakettiAbletonFindAll(node, name, acc)
  acc = acc or {}
  if not node or not node.children then return acc end
  for i = 1, #node.children do
    local c = node.children[i]
    if c.name == name then acc[#acc + 1] = c end
    PakettiAbletonFindAll(c, name, acc)
  end
  return acc
end

--------------------------------------------------------------------------------
-- Container: gzip or plain XML
--------------------------------------------------------------------------------

function PakettiAbletonReadPresetFile(path, on_progress)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. tostring(path) end
  local data = f:read("*a")
  f:close()
  if not data or #data < 8 then return nil, "empty or truncated file" end

  if data:byte(1) == 0x1F and data:byte(2) == 0x8B then
    local xml, err = PakettiGunzip(data, on_progress)
    if not xml then return nil, "gzip: " .. tostring(err) end
    return xml
  end

  -- Live 12 writes some presets as plain XML
  if data:find("<Ableton", 1, true) then return data end
  return nil, "not an Ableton preset (no gzip magic, no <Ableton> root)"
end

--------------------------------------------------------------------------------
-- Sample resolution
--
-- Live writes both an absolute Path and a RelativePath, and neither is reliable
-- on another machine. The search order mirrors how Live itself hunts for missing
-- media, widened with the folder the preset was found in.
--------------------------------------------------------------------------------

local function file_exists(p)
  if not p or p == "" then return false end
  return io.exists(p) == true
end

local basename = pakettiFSPath.basename
local dirname = pakettiFSPath.dirname
local join = pakettiFSPath.join

--- Find the audio file a MultiSamplePart points at.
---
--- Live writes both an absolute Path and a RelativePath and neither survives a
--- move between machines, so the Ableton-specific attempts (RelativePath read
--- against the preset folder and its parents, which is how Live Packs are laid
--- out, plus the Samples/Imported convention) run first, then the shared
--- pakettiFSPath.resolve takes over with the user's configured library roots.
function PakettiAbletonResolveSample(abs_path, rel_path, preset_path)
  local preset_dir = dirname(preset_path)
  local roots = pakettiFSPath.library_roots()

  if abs_path and abs_path ~= "" and file_exists(abs_path) then return abs_path end

  if rel_path and rel_path ~= "" then
    local bases = { preset_dir, dirname(preset_dir), dirname(dirname(preset_dir)) }
    for i = 1, #roots do bases[#bases + 1] = roots[i] end
    for i = 1, #bases do
      local p = join(bases[i], rel_path)
      if file_exists(p) then return p end
    end
  end

  local reference = (abs_path ~= "" and abs_path) or rel_path or ""
  if reference ~= "" then
    local base = basename(reference)
    for i = 1, #roots do
      local a = join(join(join(roots[i], "Samples"), "Imported"), base)
      if file_exists(a) then return a end
      local b = join(join(roots[i], "Samples"), base)
      if file_exists(b) then return b end
    end
    local hit = pakettiFSPath.resolve(reference, preset_path, roots)
    if hit then return hit end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Audio decodability pre-screen
--
-- Live Packs ship their audio as AIFF-C with compressionType "able", Ableton's
-- proprietary lossless codec. Nothing outside Live decodes it — macOS CoreAudio
-- fails on these files too. Handing one to sample_buffer:load_from raises a
-- modal "no decoder is installed" dialog, so a 24-pad Live Pack rack would throw
-- 24 dialogs at the user before reporting anything. Screening the AIFF header
-- first turns that into one clear sentence.
--------------------------------------------------------------------------------

-- AIFF-C compression types that are really just PCM under a label
local AIFC_PCM = {
  NONE = true, sowt = true, twos = true, raw  = true,
  in24 = true, in32 = true, fl32 = true, FL32 = true,
  fl64 = true, FL64 = true, ["23ni"] = true, ["42ni"] = true,
}

--- Returns true when Renoise stands a chance of decoding the file, or false plus
--- a short reason. Only AIFF-C is inspected; everything else is left to Renoise.
function PakettiAbletonAudioIsDecodable(path)
  local f = io.open(path, "rb")
  if not f then return false, "unreadable" end
  local head = f:read(4096)
  f:close()
  if not head or #head < 16 then return false, "empty file" end

  if head:sub(1, 4) ~= "FORM" or head:sub(9, 12) ~= "AIFC" then
    return true
  end

  -- walk the IFF chunk list to COMM; its compression type is at body offset 19
  local pos = 13
  while pos + 8 <= #head do
    local id = head:sub(pos, pos + 3)
    local b1, b2, b3, b4 = head:byte(pos + 4, pos + 7)
    if not b4 then break end
    local size = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    if id == "COMM" then
      local comp = head:sub(pos + 8 + 18, pos + 8 + 21)
      if comp == "able" then
        return false, "Ableton Live Pack encrypted audio (AIFF-C 'able')"
      end
      if not AIFC_PCM[comp] then
        return false, "compressed AIFF-C ('" .. comp .. "')"
      end
      return true
    end
    pos = pos + 8 + size + (size % 2)
  end
  return true
end

--------------------------------------------------------------------------------
-- Extraction: XML tree -> a flat list of pads
--------------------------------------------------------------------------------

local function read_sample_part(part)
  local ref = PakettiAbletonPath(part, "SampleRef", "FileRef")
  if not ref then return nil end

  local entry = {
    abs_path = PakettiAbletonValue(ref, "Path") or "",
    rel_path = PakettiAbletonValue(ref, "RelativePath") or "",
    name = PakettiAbletonValue(part, "Name") or "",
    sample_start = tonumber(PakettiAbletonValue(part, "SampleStart") or "") or 0,
    sample_end = tonumber(PakettiAbletonValue(part, "SampleEnd") or "") or 0,
    default_rate = tonumber(PakettiAbletonValue(ref, "DefaultSampleRate") or "") or 0,
    slices = {},
  }
  if entry.abs_path == "" and entry.rel_path == "" then return nil end

  -- hand-placed slices win over Live's onset analysis
  local manual = PakettiAbletonChild(part, "ManualSlicePoints")
  local auto = PakettiAbletonChild(part, "SlicePoints")
  local src = nil
  if manual and manual.children and #manual.children > 0 then
    src = manual
  elseif auto and auto.children and #auto.children > 0 then
    src = auto
  end
  if src then
    for i = 1, #src.children do
      local sp = src.children[i]
      if sp.name == "SlicePoint" and sp.attrs and sp.attrs.TimeInSeconds then
        local t = tonumber(sp.attrs.TimeInSeconds)
        if t then entry.slices[#entry.slices + 1] = t end
      end
    end
    table.sort(entry.slices)
  end

  return entry
end

local function read_sampler_device(dev)
  local parts_node = PakettiAbletonPath(dev, "Player", "MultiSampleMap", "SampleParts")
  if not parts_node or not parts_node.children then return {} end

  local mode = tonumber(PakettiAbletonValue(PakettiAbletonChild(dev, "Globals") or {}, "PlaybackMode") or "") or 0

  -- Simpler keeps its loop on the device, so it applies to every part of it
  local loop_on, loop_length = false, 1
  local mods = PakettiAbletonPath(dev, "Player", "LoopModulators")
  if mods then
    local on = PakettiAbletonChild(mods, "LoopOn")
    if on and PakettiAbletonValue(on, "Manual") == "true" then loop_on = true end
    local len = PakettiAbletonChild(mods, "LoopLength")
    local lv = len and tonumber(PakettiAbletonValue(len, "Manual") or "")
    if lv and lv > 0 and lv <= 1 then loop_length = lv end
  end
  local out = {}
  for i = 1, #parts_node.children do
    local part = parts_node.children[i]
    if part.name == "MultiSamplePart" then
      local e = read_sample_part(part)
      if e then
        e.playback_mode = mode
        e.loop_on = loop_on
        e.loop_length = loop_length
        out[#out + 1] = e
      end
    end
  end
  return out
end

local function first_sampler_device(container)
  local d = PakettiAbletonFindAll(container, "OriginalSimpler")
  if #d > 0 then return d[1] end
  d = PakettiAbletonFindAll(container, "MultiSampler")
  if #d > 0 then return d[1] end
  return nil
end

--- Turn a parsed Ableton document into { kind, name, pads = { {note, entries} } }.
function PakettiAbletonExtract(root, preset_name)
  local ableton = PakettiAbletonChild(root, "Ableton")
  if not ableton then return nil, "no <Ableton> root element" end

  local result = { name = preset_name, pads = {} }

  -- Drum Rack: presets use DrumBranchPreset, a Live Set uses DrumBranch
  local branches = PakettiAbletonFindAll(ableton, "DrumBranchPreset")
  if #branches == 0 then
    branches = PakettiAbletonFindAll(ableton, "DrumBranch")
  end

  if #branches > 0 then
    result.kind = "drumrack"
    for i = 1, #branches do
      local br = branches[i]
      local stored = tonumber(
        PakettiAbletonValue(PakettiAbletonChild(br, "ZoneSettings") or {}, "ReceivingNote")
        or PakettiAbletonValue(br, "ReceivingNote") or "")
      local note = stored and PakettiAbletonPadNoteFromXML(stored) or -1
      local dev = first_sampler_device(br)
      if dev then
        local entries = read_sampler_device(dev)
        if #entries > 0 then
          result.pads[#result.pads + 1] = {
            note = note,
            name = PakettiAbletonValue(br, "Name") or entries[1].name,
            entries = entries,
          }
        end
      end
    end
    if #result.pads > 0 then
      -- Sorting by the DECODED note puts Renoise sample 1 on the lowest pad, which
      -- is also the document order Live writes -- the stored values only look
      -- descending because they are inverted.
      local all_noted = true
      for i = 1, #result.pads do
        if result.pads[i].note < 0 then all_noted = false break end
      end
      if all_noted then
        table.sort(result.pads, function(a, b) return a.note < b.note end)
      end
      return result
    end
    -- an empty rack falls through to the flat scan below
  end

  -- Single device, or a Live Set full of them
  local devices = PakettiAbletonFindAll(ableton, "OriginalSimpler")
  local samplers = PakettiAbletonFindAll(ableton, "MultiSampler")
  for i = 1, #samplers do devices[#devices + 1] = samplers[i] end

  if #devices == 0 then
    return nil, "no Simpler or Sampler device found in this file"
  end

  result.kind = (#devices == 1) and "simpler" or "multi"
  for i = 1, #devices do
    local entries = read_sampler_device(devices[i])
    if #entries > 0 then
      result.pads[#result.pads + 1] = { note = -1, name = entries[1].name, entries = entries }
    end
  end

  if #result.pads == 0 then
    return nil, "device found but it holds no sample"
  end
  return result
end

--------------------------------------------------------------------------------
-- Import into Renoise
--------------------------------------------------------------------------------

--- Apply a Live pad's loop to a Renoise sample. Simpler only loops forward, so
--- that is the mode; LoopLength is the fraction of the region the loop covers and
--- Live loops up to the region end, so the loop starts that fraction back from it.
local function apply_loop(sample, loop_on, loop_length, region_frames)
  if not loop_on then return false end
  local ok = pcall(function()
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    local frames = region_frames
    if not frames or frames <= 0 then
      frames = sample.sample_buffer.has_sample_data
        and sample.sample_buffer.number_of_frames or 0
    end
    if frames > 1 then
      local len = math.floor(frames * (loop_length or 1))
      if len < 1 then len = 1 end
      if len > frames then len = frames end
      sample.loop_start = math.max(1, frames - len + 1)
      sample.loop_end = frames
    end
  end)
  return ok
end

local function apply_slices(sample, seconds)
  if #seconds == 0 then return 0 end
  local buf = sample.sample_buffer
  if not buf.has_sample_data then return 0 end
  local rate = buf.sample_rate
  local frames = buf.number_of_frames

  local placed = 0
  for i = 1, #seconds do
    -- Renoise tops out at 255 slice markers
    if placed >= 255 then break end
    local frame = math.floor(seconds[i] * rate + 0.5) + 1
    if frame >= 1 and frame < frames then
      local ok = pcall(function() sample:insert_slice_marker(frame) end)
      if ok then placed = placed + 1 end
    end
  end
  return placed
end

--- Load one Ableton preset file as a new Renoise instrument.
--- Returns true plus a status string, or false plus an error.
--- opts.yield is called at every safe point so the caller can hand time back to
--- Renoise; opts.status receives a line of progress text. Both are optional, so
--- this stays usable synchronously (batch conversion, tests) and sliced.
function PakettiAbletonImportFile(path, opts)
  opts = opts or {}
  local yield_fn = opts.yield
  local status_fn = opts.status or function() end

  local preset_name = basename(path):gsub("%.%w+$", "")

  status_fn("Reading " .. preset_name .. "...")
  local xml, err = PakettiAbletonReadPresetFile(path, yield_fn and function(done)
    status_fn(string.format("Decompressing %s... %d KB", preset_name, math.floor(done / 1024)))
    yield_fn()
  end or nil)
  if not xml then return false, err end

  status_fn("Reading the preset structure...")
  local root = PakettiAbletonParseXML(xml, yield_fn and function(at, total)
    status_fn(string.format("Reading the preset structure... %d%%",
      math.floor(at / total * 100)))
    yield_fn()
  end or nil)
  local model, err2 = PakettiAbletonExtract(root, preset_name)
  if not model then return false, err2 end
  if yield_fn then yield_fn() end

  local song = renoise.song()

  -- resolve every path up front so a fully unresolvable preset does not leave a
  -- half-built instrument behind
  local resolved, missing = {}, {}
  local undecodable, undecodable_reason = {}, nil
  for p = 1, #model.pads do
    local pad = model.pads[p]
    for e = 1, #pad.entries do
      local entry = pad.entries[e]
      if yield_fn then yield_fn() end
      local found = PakettiAbletonResolveSample(entry.abs_path, entry.rel_path, path)
      if found then
        local playable, why = PakettiAbletonAudioIsDecodable(found)
        if playable then
          entry.resolved = found
          resolved[#resolved + 1] = entry
        else
          undecodable[#undecodable + 1] = basename(found)
          undecodable_reason = undecodable_reason or why
        end
      else
        missing[#missing + 1] = basename(entry.abs_path ~= "" and entry.abs_path or entry.rel_path)
      end
    end
  end

  if #resolved == 0 and #undecodable > 0 then
    return false, string.format(
      "%s: all %d samples are %s. Renoise cannot decode them — in Live, drag the samples to a track and use File > Export Audio, or replace them with the original WAVs.",
      preset_name, #undecodable, undecodable_reason or "in an unsupported format")
  end

  if #resolved == 0 then
    return false, string.format(
      "%s: none of the %d referenced samples could be found on this machine. Add the folder holding them with Instruments > File Formats > Ableton > Add Sample Library Root.",
      preset_name, #missing)
  end

  -- Live's "Slice to New MIDI Track" makes a Drum Rack whose pads all point at the
  -- SAME file, each pad playing one SampleStart..SampleEnd region. Renoise says that
  -- with one sample and a slice marker per region, so collapse it rather than loading
  -- two dozen identical full-length copies.
  local shared_path = nil
  local is_sliced_rack = false
  if #resolved > 1 then
    shared_path = resolved[1].resolved
    is_sliced_rack = true
    for i = 2, #resolved do
      if resolved[i].resolved ~= shared_path then
        is_sliced_rack = false
        break
      end
    end
    -- one file used twice with identical regions is a duplicate, not a slice set
    if is_sliced_rack then
      local distinct = {}
      for i = 1, #resolved do distinct[resolved[i].sample_start] = true end
      local n = 0
      for _ in pairs(distinct) do n = n + 1 end
      if n < 2 then is_sliced_rack = false end
    end
  end

  if is_sliced_rack then
    if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
      return false, "could not create an instrument"
    end
    song.selected_instrument_index = song.selected_instrument_index + 1
    pakettiPreferencesDefaultInstrumentLoader()

    local instrument = song.selected_instrument
    instrument.name = model.name
    local sample = instrument.samples[1]

    status_fn("Loading " .. basename(shared_path) .. "...")
    if yield_fn then yield_fn() end
    local ok, loaded_ok = pcall(function()
      return sample.sample_buffer:load_from(shared_path)
    end)
    if not (ok and loaded_ok and sample.sample_buffer.has_sample_data) then
      return false, model.name .. ": Renoise could not decode " .. basename(shared_path)
    end
    sample.name = basename(shared_path):gsub("%.%w+$", "")
    sample.sample_mapping.note_range = { 0, 119 }

    local starts = {}
    for i = 1, #resolved do starts[#starts + 1] = resolved[i].sample_start end
    table.sort(starts)

    -- Renoise's own slicer puts its first marker AT frame 1, so a region starting
    -- at frame 0 in Live must get one too; skipping it turned 128 slices into 127.
    local frames = sample.sample_buffer.number_of_frames
    local placed, last = 0, -1
    for i = 1, #starts do
      local frame = starts[i] + 1
      if frame >= 1 and frame < frames and frame ~= last and placed < 255 then
        if pcall(function() sample:insert_slice_marker(frame) end) then
          placed = placed + 1
          last = frame
        end
      end
    end

    -- each pad carried its own loop; slice i of the collapsed sample is samples[i+1]
    local looped = 0
    for i = 1, #resolved do
      local slice = instrument.samples[i + 1]
      if slice and resolved[i].loop_on then
        if apply_loop(slice, true, resolved[i].loop_length,
             slice.sample_buffer.has_sample_data
               and slice.sample_buffer.number_of_frames or nil) then
          looped = looped + 1
        end
      end
    end

    local msg = string.format("Ableton sliced Drum Rack '%s': %s, %d slices",
      model.name, sample.name, #sample.slice_markers)
    if looped > 0 then msg = msg .. string.format(", %d looping", looped) end
    if #undecodable > 0 then
      msg = msg .. string.format(", %d skipped (%s)", #undecodable,
        undecodable_reason or "undecodable")
    end
    return true, msg
  end

  if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
    return false, "could not create an instrument"
  end
  song.selected_instrument_index = song.selected_instrument_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.selected_instrument
  instrument.name = model.name

  local slot = 0
  local total_slices = 0
  local loaded = 0

  for p = 1, #model.pads do
    local pad = model.pads[p]
    for e = 1, #pad.entries do
      local entry = pad.entries[e]
      if entry.resolved then
        slot = slot + 1
        local sample
        if slot == 1 then
          sample = instrument.samples[1]
        else
          instrument:insert_sample_at(slot)
          sample = instrument.samples[slot]
        end

        status_fn(string.format("Loading sample %d of %d...", slot, #resolved))
        if yield_fn then yield_fn() end
        local ok, loaded_ok = pcall(function()
          return sample.sample_buffer:load_from(entry.resolved)
        end)
        if ok and loaded_ok and sample.sample_buffer.has_sample_data then
          loaded = loaded + 1
          local nm = entry.name
          if nm == "" then nm = basename(entry.resolved):gsub("%.%w+$", "") end
          sample.name = nm

          if pad.note >= 0 then
            local n = pad.note
            if n > 119 then n = 119 end
            if n < 0 then n = 0 end
            sample.sample_mapping.base_note = n
            sample.sample_mapping.note_range = { n, n }
            sample.sample_mapping.velocity_range = { 0, 127 }
          else
            sample.sample_mapping.note_range = { 0, 119 }
            sample.sample_mapping.velocity_range = { 0, 127 }
          end

          if entry.loop_on then
            apply_loop(sample, true, entry.loop_length,
              sample.sample_buffer.number_of_frames)
          end

          -- Live's Slicing mode is the only one where the slice list is playable
          if entry.playback_mode == 2 and #entry.slices > 0 then
            total_slices = total_slices + apply_slices(sample, entry.slices)
          end
        else
          undecodable[#undecodable + 1] = basename(entry.resolved)
          -- drop the slot again so a failed decode does not leave an empty sample
          if slot > 1 then
            instrument:delete_sample_at(slot)
            slot = slot - 1
          end
        end
      end
    end
  end

  if loaded == 0 then
    return false, model.name .. ": samples were found on disk but Renoise could not decode any of them"
  end

  local msg = string.format("Ableton %s '%s': %d sample%s",
    model.kind, model.name, loaded, loaded == 1 and "" or "s")
  if total_slices > 0 then msg = msg .. string.format(", %d slices", total_slices) end
  if #missing > 0 then msg = msg .. string.format(", %d not found", #missing) end
  if #undecodable > 0 then
    msg = msg .. string.format(", %d skipped (%s)", #undecodable,
      undecodable_reason or "undecodable")
  end
  return true, msg
end

--------------------------------------------------------------------------------
-- User-facing entry points
--------------------------------------------------------------------------------

--- Run an import on a ProcessSlicer so Renoise keeps repainting. A megabyte of
--- Drum Rack XML takes about a second to decompress and the audio loads after
--- that; without slicing, Renoise reports the tool as unresponsive.
---
--- Nothing is allowed to escape the worker: an error raised inside an app_idle
--- notifier makes Renoise disable this tool's notifiers, which silently kills
--- every other ProcessSlicer feature in Paketti until Renoise is restarted.
function PakettiAbletonImportSliced(path)
  local dialog, vb

  local slicer = ProcessSlicer(function()
    local ran, ok, msg = pcall(function()
      return PakettiAbletonImportFile(path, {
        yield = function() coroutine.yield() end,
        status = function(text)
          if vb and vb.views and vb.views.progress_text then
            vb.views.progress_text.text = text
          end
        end,
      })
    end)

    if dialog and dialog.visible then dialog:close() end

    if not ran then
      local why = tostring(ok)
      print("-- PakettiAbleton: import crashed: " .. why)
      renoise.app():show_error("Ableton import failed.\n\n" .. why)
      return
    end
    if ok then
      renoise.app():show_status(msg)
      print("-- PakettiAbleton: " .. tostring(msg))
    else
      print("-- PakettiAbleton: FAILED " .. tostring(msg))
      renoise.app():show_error("Ableton import failed.\n\n" .. tostring(msg))
    end
  end)

  dialog, vb = slicer:create_dialog("Importing Ableton Live preset...")
  slicer:start()
end

function PakettiAbletonImportDialog()
  local path = renoise.app():prompt_for_filename_to_read(
    { "*.adv", "*.adg", "*.als", "*.alc" }, "Import Ableton Live preset")
  if not path or path == "" then return end
  PakettiAbletonImportSliced(path)
end

--- File import hook target. Renoise hands us one path.
function PakettiAbletonImportHook(path)
  PakettiAbletonImportSliced(path)
  return true
end

--- Append a folder to the shared pakettiSampleLibraryRoots preference, which
--- every Paketti importer consults when a referenced sample has moved.
function PakettiAbletonAddSampleLibraryRoot()
  local path = renoise.app():prompt_for_path(
    "Select a sample library root (e.g. your Ableton User Library)")
  if not path or path == "" then return end

  local current = preferences.pakettiSampleLibraryRoots.value or ""
  for line in string.gmatch(current, "[^\r\n]+") do
    if line:match("^%s*(.-)%s*$") == path then
      renoise.app():show_status("Already a sample library root: " .. path)
      return
    end
  end

  if current ~= "" and not current:match("\n$") then current = current .. "\n" end
  preferences.pakettiSampleLibraryRoots.value = current .. path
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Added sample library root: " .. path)
end

--------------------------------------------------------------------------------
-- Menu entries and keybindings
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Ableton:Import Live Preset (.adv/.adg/.als)...",
  invoke=function() PakettiAbletonImportDialog() end}
PakettiAddMenuEntry{name="Main Menu:File:Paketti Import:Ableton Live Preset (.adv/.adg/.als)...",
  invoke=function() PakettiAbletonImportDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Ableton:Add Sample Library Root (for missing samples)...",
  invoke=function() PakettiAbletonAddSampleLibraryRoot() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Import Ableton Live Preset",
  invoke = function() PakettiAbletonImportDialog() end }

--------------------------------------------------------------------------------
-- Export: Renoise instrument -> Ableton Live preset
--
-- Live's own presets carry every parameter of every sub-device (Pitch, Filter,
-- Shaper, VolumeAndPan, AuxEnv, Lfo, ...), which is how a 24-pad rack reaches a
-- megabyte of XML. Emitting all of that would mean transcribing Ableton's whole
-- default parameter set, so what is written here is the structural skeleton plus
-- the parts that carry meaning: the sample reference, the region, the slice
-- points and the pad's note. Live fills the rest from its own defaults, the same
-- way it opens presets saved by older versions that predate half those elements.
--
-- The audio is written by Renoise (sample_buffer:save_as), so no encoder is
-- needed here; only the container and the XML.
--
-- FileRef is the part that decides whether Live finds the audio at all, and it
-- is not free-form. Surveying real presets shows RelativePathType names which
-- root the RelativePath is measured from:
--
--   1  the preset file's own folder      5  a Live Pack root
--   6  the User Library root             7  Live's built-in resources
--
-- and every audio reference carries Type="2". Getting either wrong makes Live
-- open the preset with its structure intact but every sample listed as Missing —
-- Live resolves through the relative root and does not fall back to the absolute
-- Path. Paketti writes the WAVs into Samples/Imported/ beside the preset, which
-- is the layout Live itself uses for imported media, so RelativePathType is 1.
--------------------------------------------------------------------------------

-- Every Drum Rack pad translates its incoming note to this one before handing it
-- to the sampler in its chain; it is written as ZoneSettings/SendingNote and is
-- what the pad's MultiSamplePart must be keyed and rooted to.
--- Live names middle C (MIDI 60) as C3, so MIDI 36 reads as C1 on its pads.
local ABLETON_NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

function PakettiAbletonNoteName(note)
  return ABLETON_NOTE_NAMES[(note % 12) + 1] .. tostring(math.floor(note / 12) - 2)
end

local DRUM_PAD_SENDING_NOTE = 60

-- C1: where Live lays out the first pad of a Drum Rack, including the racks its
-- own "Slice to New MIDI Track" produces
local DRUM_PAD_FIRST_NOTE = 36

local function xml_escape(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
  return s
end

-- Live wants a plain decimal, never Lua's "1e-05" or a trailing ".0"
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return (string.format("%.10f", v):gsub("0+$", ""):gsub("%.$", ""))
end

--- Live's Id attributes are POSITIONAL, not globally unique. In a real Drum Rack
--- every OriginalSimpler, MultiSamplePart, AutomationTarget, ModulationTarget and
--- Pointee carries Id="0", AbletonDevicePreset counts within its own DevicePresets
--- list, and only DrumBranchPreset runs 0..N-1 as an index into its collection.
--- Handing out globally increasing numbers instead makes Live mis-resolve the
--- device and fall back to the "Multisample Mode" panel.
local function id_allocator()
  return function() return 0 end
end

local function build_sample_part(o, next_id)
  local slice_xml = {}
  for i = 1, #o.slices do
    slice_xml[#slice_xml + 1] = string.format(
      '<SlicePoint TimeInSeconds="%s" Rank="0" NormalizedEnergy="0.5" />', num(o.slices[i]))
  end
  local has_slices = (#o.slices > 0) and "true" or "false"

  return string.format([[
<MultiSamplePart Id="%d" HasImportedSlicePoints="%s" NeedsAnalysisData="false">
<LomId Value="0" />
<Name Value="%s" />
<Selection Value="true" />
<IsActive Value="true" />
<Solo Value="false" />
<KeyRange><Min Value="%d" /><Max Value="%d" /><CrossfadeMin Value="%d" /><CrossfadeMax Value="%d" /></KeyRange>
<VelocityRange><Min Value="1" /><Max Value="127" /><CrossfadeMin Value="1" /><CrossfadeMax Value="127" /></VelocityRange>
<SelectorRange><Min Value="0" /><Max Value="127" /><CrossfadeMin Value="0" /><CrossfadeMax Value="127" /></SelectorRange>
<RootKey Value="%d" />
<Detune Value="0" />
<TuneScale Value="100" />
<Panorama Value="0" />
<Volume Value="1" />
<Link Value="false" />
<SampleStart Value="%d" />
<SampleEnd Value="%d" />
<SustainLoop><Start Value="%d" /><End Value="%d" /><Mode Value="0" /><Crossfade Value="0" /><Detune Value="0" /></SustainLoop>
<ReleaseLoop><Start Value="%d" /><End Value="%d" /><Mode Value="3" /><Crossfade Value="0" /><Detune Value="0" /></ReleaseLoop>
<SampleRef>
<FileRef>
<RelativePathType Value="1" />
<RelativePath Value="%s" />
<Path Value="%s" />
<Type Value="2" />
<LivePackName Value="" />
<LivePackId Value="" />
<OriginalFileSize Value="%d" />
<OriginalCrc Value="0" />
</FileRef>
<LastModDate Value="0" />
<SourceContext />
<SampleUsageHint Value="0" />
<DefaultDuration Value="%d" />
<DefaultSampleRate Value="%d" />
</SampleRef>
<SlicingThreshold Value="100" />
<SlicingBeatGrid Value="4" />
<SlicingRegions Value="8" />
<SlicingStyle Value="0" />
<SlicePoints />
<ManualSlicePoints>%s</ManualSlicePoints>
<BeatSlicePoints />
<RegionSlicePoints />
<UseDynamicBeatSlices Value="true" />
<UseDynamicRegionSlices Value="true" />
</MultiSamplePart>]],
    next_id(), has_slices, xml_escape(o.name),
    o.key_min, o.key_max, o.key_min, o.key_max,
    o.root_key,
    o.sample_start, o.sample_end,
    o.sample_start, o.sample_end,
    o.sample_start, o.sample_end,
    xml_escape(o.rel_path), xml_escape(o.abs_path),
    o.file_size, o.frames, o.sample_rate,
    table.concat(slice_xml))
end

--- Globals/IsSimpler is what decides which UI Live draws. Every OriginalSimpler in
--- a real rack carries IsSimpler true and every MultiSampler carries false; leave it
--- out and Live defaults to false, showing the pad as "Multisample Mode" with no
--- waveform and no Start/Loop/Length controls no matter what else is correct.
---
--- Simpler's loop lives in the device, not in the sample part: Player/LoopModulators
--- carries LoopOn (the toggle) and LoopLength (how much of the region the loop
--- covers, as a fraction). Real presets bear this out — 79 pads across the library
--- have LoopOn true, and MultiSamplePart/SustainLoop stays Mode 0 on all of them,
--- because SustainLoop is what the full Sampler uses instead.
--- Loop export is OFF.
---
--- Writing a Player/LoopModulators block -- in any shape tried, stub or complete --
--- made Live show every pad as "Multisample Mode": no waveform, no Start / Loop /
--- Length controls. Removing it restores the normal Simpler view. Live evidently
--- reconstructs the loop parameters itself and objects to being handed them, so
--- Paketti leaves the block out and lets Live supply it.
---
--- The consequence is that Renoise slice loops do not reach Live on export. Import
--- still reads Live's loops, since reading is unaffected. Reinstating export means
--- finding the exact shape Live accepts, not another guess at it.
local function build_loop_modulators(loop, next_id)
  return ""
end

-- Live writes these as full parameters; Reverse and Snap are on/off, SampleSelector
-- is a ranged value. They sit after LoopModulators inside Player.
local SIMPLER_PLAYER_TAIL = table.concat({
  '<Reverse><LomId Value="0" /><Manual Value="false" />',
  '<AutomationTarget Id="0"><LockEnvelope Value="0" /></AutomationTarget>',
  '<MidiCCOnOffThresholds><Min Value="64" /><Max Value="127" /></MidiCCOnOffThresholds></Reverse>',
  '<Snap><LomId Value="0" /><Manual Value="false" />',
  '<AutomationTarget Id="0"><LockEnvelope Value="0" /></AutomationTarget>',
  '<MidiCCOnOffThresholds><Min Value="64" /><Max Value="127" /></MidiCCOnOffThresholds></Snap>',
  '<SampleSelector><LomId Value="0" /><Manual Value="0" />',
  '<MidiControllerRange><Min Value="0" /><Max Value="127" /></MidiControllerRange>',
  '<AutomationTarget Id="0"><LockEnvelope Value="0" /></AutomationTarget>',
  '<ModulationTarget Id="0"><LockEnvelope Value="0" /></ModulationTarget></SampleSelector>',
})

-- The view state Live keeps per device. ZoneEditorVisible and SelectedPage are the
-- two that decide which panel a Simpler shows.
local SIMPLER_VIEW_SETTINGS =
  '<ViewSettings><SelectedPage Value="0" /><ZoneEditorVisible Value="false" />' ..
  '<Seconds Value="false" /><SelectedSampleChannel Value="0" />' ..
  '<VerticalSampleZoom Value="1" /><IsAutoSelectEnabled Value="false" />' ..
  '<SimplerBreakoutVisible Value="false" /></ViewSettings>'

local function build_simpler(parts_xml, playback_mode, next_id, loop)
  return string.format([[
<OriginalSimpler Id="%d">
<LomId Value="0" />
<LomIdView Value="0" />
<IsExpanded Value="true" />
<On><LomId Value="0" /><Manual Value="true" /><AutomationTarget Id="%d"><LockEnvelope Value="0" /></AutomationTarget><MidiCCOnOffThresholds><Min Value="64" /><Max Value="127" /></MidiCCOnOffThresholds></On>
<ModulationSourceCount Value="0" />
<ParametersListWrapper LomId="0" />
<Pointee Id="%d" />
<LastSelectedTimeableIndex Value="0" />
<LastSelectedClipEnvelopeIndex Value="0" />
<IsFolded Value="false" />
<ShouldShowPresetName Value="true" />
<UserName Value="" />
<Annotation Value="" />
<SourceContext />
<Player>
<MultiSampleMap>
<SampleParts>%s</SampleParts>
<LoadInRam Value="false" />
<LayerCrossfade Value="0" />
<SourceContext />
</MultiSampleMap>
%s
]] .. SIMPLER_PLAYER_TAIL .. [[
</Player>
<Globals><IsSimpler Value="true" /><PlaybackMode Value="%d" /></Globals>
]] .. SIMPLER_VIEW_SETTINGS .. [[
<SimplerSlicing><PlaybackMode Value="%d" /></SimplerSlicing>
</OriginalSimpler>]],
    next_id(), next_id(), next_id(), parts_xml, build_loop_modulators(loop, next_id),
    playback_mode, playback_mode)
end

local ABLETON_HEADER =
  '<?xml version="1.0" encoding="UTF-8"?>\n' ..
  '<Ableton MajorVersion="5" MinorVersion="12.0_12049" SchemaChangeCount="7" ' ..
  'Creator="Paketti" Revision="">\n'

--- Gather what one Renoise sample contributes to a preset.
--- Turn one Renoise sample's loop into Simpler terms. Renoise offers off, forward,
--- reverse and ping-pong; Simpler in Classic mode has a plain forward loop and
--- nothing else, so the three looping modes all arrive as "looping" and only the
--- extent survives. Returns nil when the sample does not loop.
local function loop_from_sample(sample, region_frames)
  if not sample then return nil end
  local ok, mode = pcall(function() return sample.loop_mode end)
  if not ok or mode == nil or mode == renoise.Sample.LOOP_MODE_OFF then return nil end

  local length = 1.0
  local ok2 = pcall(function()
    local a, b = sample.loop_start, sample.loop_end
    if region_frames and region_frames > 0 and b > a then
      length = (b - a) / region_frames
    end
  end)
  if not ok2 then length = 1.0 end
  if length > 1 then length = 1 end
  if length <= 0 then length = 1 end

  return { on = true, length = length }
end

local function describe_sample(sample, wav_path, rel_path, key_min, key_max, root)
  local buf = sample.sample_buffer
  local size = 0
  local f = io.open(wav_path, "rb")
  if f then
    size = f:seek("end") or 0
    f:close()
  end
  return {
    name = sample.name,
    abs_path = wav_path,
    rel_path = rel_path,
    frames = buf.number_of_frames,
    sample_rate = buf.sample_rate,
    file_size = size,
    sample_start = 0,
    sample_end = buf.number_of_frames - 1,
    key_min = key_min, key_max = key_max, root_key = root,
    slices = {},
  }
end

local function ensure_dir(dir)
  -- Renoise has no mkdir; save_as into a missing folder fails, so create it via
  -- the one portable trick available: ask the OS.
  if io.exists(dir) then return true end
  local cmd
  if os.platform() == "WINDOWS" then
    cmd = 'mkdir "' .. dir .. '"'
  else
    cmd = 'mkdir -p ' .. pakettiFSPath.shell_quote(dir)
  end
  os.execute(cmd)
  return io.exists(dir) == true
end

--- Write the selected instrument as a Simpler preset (.adv) plus its WAV.
--- A Renoise sliced sample becomes a Simpler in Slicing mode with the markers
--- carried across as ManualSlicePoints.
function PakettiAbletonExportSimpler(adv_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end
  local sample = instrument.samples[1]
  if not sample.sample_buffer.has_sample_data then
    return false, "the first sample of the selected instrument is empty"
  end

  local dir = pakettiFSPath.dirname(adv_path)
  local base = pakettiFSPath.basename(adv_path):gsub("%.adv$", "")
  local samples_dir = pakettiFSPath.join(pakettiFSPath.join(dir, "Samples"), "Imported")
  if not ensure_dir(samples_dir) then
    return false, "could not create " .. samples_dir
  end

  local wav_name = pakettiFSPath.sanitize_filename(base, "sample") .. ".wav"
  local wav_path = pakettiFSPath.join(samples_dir, wav_name)
  local ok = pcall(function() return sample.sample_buffer:save_as(wav_path, "wav") end)
  if not ok or not io.exists(wav_path) then
    return false, "could not write " .. wav_path
  end

  local o = describe_sample(sample, wav_path, "Samples/Imported/" .. wav_name, 0, 127, 60)
  o.name = base

  local rate = sample.sample_buffer.sample_rate
  local markers = sample.slice_markers
  for i = 1, #markers do
    o.slices[#o.slices + 1] = (markers[i] - 1) / rate
  end
  local playback_mode = (#o.slices > 0) and 2 or 0

  local next_id = id_allocator()
  local xml = ABLETON_HEADER ..
    build_simpler(build_sample_part(o, next_id), playback_mode, next_id,
      loop_from_sample(sample, sample.sample_buffer.number_of_frames)) ..
    "\n</Ableton>\n"

  local written, werr = PakettiGzipToFile(adv_path, xml, base .. ".adv")
  if not written then return false, werr end

  return true, string.format("Wrote %s (%s, %d slice%s)",
    pakettiFSPath.basename(adv_path), wav_name, #o.slices, #o.slices == 1 and "" or "s")
end

--- Write the selected instrument as a Drum Rack (.adg).
--- A sliced instrument becomes one WAV with a pad per slice region, which is the
--- exact inverse of what Live's "Slice to New MIDI Track" produces. A multi-sample
--- instrument becomes one WAV and one pad per sample.
function PakettiAbletonExportDrumRack(adg_path, opts)
  opts = opts or {}
  local yield_fn = opts.yield
  local status_fn = opts.status or function() end
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end

  local dir = pakettiFSPath.dirname(adg_path)
  local base = pakettiFSPath.basename(adg_path):gsub("%.adg$", "")
  local samples_dir = pakettiFSPath.join(pakettiFSPath.join(dir, "Samples"), "Imported")
  if not ensure_dir(samples_dir) then
    return false, "could not create " .. samples_dir
  end

  local pads = {}
  local first = instrument.samples[1]
  local markers = first.slice_markers

  if #markers > 0 and first.sample_buffer.has_sample_data then
    -- sliced instrument: one file, one pad per region
    local wav_name = pakettiFSPath.sanitize_filename(base, "sample") .. ".wav"
    local wav_path = pakettiFSPath.join(samples_dir, wav_name)
    local ok = pcall(function() return first.sample_buffer:save_as(wav_path, "wav") end)
    if not ok or not io.exists(wav_path) then
      return false, "could not write " .. wav_path
    end

    -- In Renoise a slice STARTS at its marker, so N markers make N slices and any
    -- audio before the first marker belongs to none of them. Seeding the bounds
    -- with frame 1 would invent a 25th pad out of that lead-in.
    local frames = first.sample_buffer.number_of_frames
    local bounds = {}
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] end
    bounds[#bounds + 1] = frames + 1

    for i = 1, #bounds - 1 do
      if yield_fn then yield_fn() end
      do
        -- A Drum Rack pad receives its own note but SENDS note 60 into its chain,
        -- so the Simpler inside is always played at C3 no matter which pad it is.
        -- Keying the sampler to the pad's note therefore puts the incoming note
        -- outside its range and the pad is silent. Real racks use 0..127 / root 60
        -- and let ZoneSettings/ReceivingNote carry the pad's identity.
        local o = describe_sample(first, wav_path, "Samples/Imported/" .. wav_name,
          0, 127, DRUM_PAD_SENDING_NOTE)
        o.name = string.format("%s %02d", base, i)
        o.sample_start = bounds[i] - 1
        o.sample_end = bounds[i + 1] - 2
        -- slice i lives at samples[i + 1]; samples[1] is the parent buffer
        local slice_sample = instrument.samples[i + 1]
        pads[#pads + 1] = {
          part = o,
          loop = loop_from_sample(slice_sample, bounds[i + 1] - bounds[i]),
        }
      end
    end
  else
    -- multi-sample instrument: one file per sample
    for i = 1, #instrument.samples do
      status_fn(string.format("Writing sample %d of %d...", i, #instrument.samples))
      if yield_fn then yield_fn() end
      local s = instrument.samples[i]
      if s.sample_buffer.has_sample_data then
        local nm = pakettiFSPath.sanitize_filename(
          (s.name ~= "" and s.name) or (base .. "_" .. i), base .. "_" .. i)
        local wav_name = string.format("%s_%02d_%s.wav", base, i, nm)
        wav_name = pakettiFSPath.sanitize_filename(wav_name:gsub("%.wav$", ""), "sample") .. ".wav"
        local wav_path = pakettiFSPath.join(samples_dir, wav_name)
        local ok = pcall(function() return s.sample_buffer:save_as(wav_path, "wav") end)
        if ok and io.exists(wav_path) then
          local o = describe_sample(s, wav_path, "Samples/Imported/" .. wav_name,
            0, 127, DRUM_PAD_SENDING_NOTE)
          if o.name == "" then o.name = nm end
          pads[#pads + 1] = {
            part = o,
            loop = loop_from_sample(s, s.sample_buffer.number_of_frames),
          }
        end
      end
    end
  end

  if #pads == 0 then
    return false, "nothing to export: no sample in the instrument holds audio"
  end

  -- A Drum Rack has 128 pads, one per MIDI note, so a rack starting at C1 only has
  -- room for 92 of them. Rather than dropping the rest, drop the starting note far
  -- enough to fit the set, and split anything past 128 across further files -- the
  -- same thing Live does when you slice more than one rack's worth.
  local MAX_PADS = 128
  local groups = {}
  for i = 1, #pads, MAX_PADS do
    local g = {}
    for j = i, math.min(i + MAX_PADS - 1, #pads) do g[#g + 1] = pads[j] end
    groups[#groups + 1] = g
  end

  local report = {}

  for gi = 1, #groups do
    local group = groups[gi]

    local first_note = DRUM_PAD_FIRST_NOTE
    if first_note + #group - 1 > 127 then first_note = 128 - #group end
    if first_note < 0 then first_note = 0 end

    local rack_name = base
    local out_path = adg_path
    if #groups > 1 then
      rack_name = string.format("%s %d", base, gi)
      if gi > 1 then
        out_path = adg_path:gsub("%.adg$", "") .. string.format(" %d.adg", gi)
      end
    end

    local next_id = id_allocator()
    local branches = {}
    for i = 1, #group do
      status_fn(string.format("Building pad %d of %d...", i, #group))
      if yield_fn then yield_fn() end
      local pad = group[i]
      local note = first_note + i - 1
      branches[#branches + 1] = string.format([[
<DrumBranchPreset Id="%d">
<Name Value="%s" />
<IsSoloed Value="false" />
<DevicePresets>
<AbletonDevicePreset Id="%d">
<OverwriteProtectionNumber Value="2817" />
<Device>%s</Device>
</AbletonDevicePreset>
</DevicePresets>
<MixerPreset />
<BranchSelectorRange><Min Value="0" /><Max Value="127" /><CrossfadeMin Value="0" /><CrossfadeMax Value="127" /></BranchSelectorRange>
<SessionViewBranchWidth Value="55" />
<DocumentColorIndex Value="26" />
<AutoColored Value="true" />
<AutoColorScheme Value="0" />
<SourceContext />
<ZoneSettings><ReceivingNote Value="%d" /><SendingNote Value="60" /><ChokeGroup Value="0" /></ZoneSettings>
</DrumBranchPreset>]],
        i - 1, xml_escape(pad.part.name), 0,
        build_simpler(build_sample_part(pad.part, next_id), 0, next_id, pad.loop),
        PakettiAbletonPadNoteToXML(note))
    end

    local xml = ABLETON_HEADER .. string.format([[
<GroupDevicePreset>
<OverwriteProtectionNumber Value="2817" />
<Device>
<DrumGroupDevice Id="0">
<LomId Value="0" />
<LomIdView Value="0" />
<IsExpanded Value="true" />
<On><LomId Value="0" /><Manual Value="true" /><AutomationTarget Id="%d"><LockEnvelope Value="0" /></AutomationTarget><MidiCCOnOffThresholds><Min Value="64" /><Max Value="127" /></MidiCCOnOffThresholds></On>
<ModulationSourceCount Value="0" />
<ParametersListWrapper LomId="0" />
<Pointee Id="%d" />
<LastSelectedTimeableIndex Value="0" />
<LastSelectedClipEnvelopeIndex Value="0" />
<IsFolded Value="false" />
<ShouldShowPresetName Value="true" />
<UserName Value="%s" />
<Annotation Value="" />
<SourceContext />
<OverwriteProtectionNumber Value="2817" />
<IsBranchesListVisible Value="false" />
<IsReturnBranchesListVisible Value="false" />
<IsRangesEditorVisible Value="false" />
<AreDevicesVisible Value="true" />
<NumVisibleMacroControls Value="8" />
<AreMacroControlsVisible Value="true" />
<IsAutoSelectEnabled Value="true" />
<ArePadsVisible Value="true" />
<PadScrollPosition Value="0" />
<DrumPadsListWrapper LomId="0" />
<VisibleDrumPadsListWrapper LomId="0" />
</DrumGroupDevice>
</Device>
<BranchPresets>%s</BranchPresets>
</GroupDevicePreset>
</Ableton>
]], next_id(), next_id(), xml_escape(rack_name), table.concat(branches))

    local wrote, werr = PakettiGzipToFile(out_path, xml,
      pakettiFSPath.basename(out_path))
    if not wrote then return false, werr end

    report[#report + 1] = string.format("%s (%d pads from %s)",
      pakettiFSPath.basename(out_path), #group,
      PakettiAbletonNoteName(first_note))
  end

  return true, "Wrote " .. table.concat(report, " + ")
end

--- Drum Rack export writes one WAV per pad, so a large instrument is slow enough
--- to need slicing for the same reason import does. Errors stay inside the worker.
function PakettiAbletonExportDrumRackSliced(adg_path)
  local dialog, vb

  local slicer = ProcessSlicer(function()
    local ran, ok, msg = pcall(function()
      return PakettiAbletonExportDrumRack(adg_path, {
        yield = function() coroutine.yield() end,
        status = function(text)
          if vb and vb.views and vb.views.progress_text then
            vb.views.progress_text.text = text
          end
        end,
      })
    end)

    if dialog and dialog.visible then dialog:close() end

    if not ran then
      print("-- PakettiAbleton export crashed: " .. tostring(ok))
      renoise.app():show_error("Ableton export failed.\n\n" .. tostring(ok))
      return
    end
    if ok then
      renoise.app():show_status(msg)
      print("-- PakettiAbleton export: " .. tostring(msg))
    else
      print("-- PakettiAbleton export: FAILED " .. tostring(msg))
      renoise.app():show_error("Ableton export failed.\n\n" .. tostring(msg))
    end
  end)

  dialog, vb = slicer:create_dialog("Exporting Ableton Drum Rack...")
  slicer:start()
end

function PakettiAbletonExportSimplerDialog()
  local name = renoise.song().selected_instrument.name
  if name == "" then name = "Paketti" end
  local path = renoise.app():prompt_for_filename_to_write(
    "adv", "Export Ableton Simpler preset")
  if not path or path == "" then return end
  if not path:lower():match("%.adv$") then path = path .. ".adv" end
  local ok, msg = PakettiAbletonExportSimpler(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("Ableton export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiAbleton export: " .. tostring(msg))
end

function PakettiAbletonExportDrumRackDialog()
  local path = renoise.app():prompt_for_filename_to_write(
    "adg", "Export Ableton Drum Rack")
  if not path or path == "" then return end
  if not path:lower():match("%.adg$") then path = path .. ".adg" end
  PakettiAbletonExportDrumRackSliced(path)
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Ableton:Export Instrument as Simpler (.adv)...",
  invoke=function() PakettiAbletonExportSimplerDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Ableton:Export Instrument as Drum Rack (.adg)...",
  invoke=function() PakettiAbletonExportDrumRackDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Ableton:Export Instrument as Simpler (.adv)...",
  invoke=function() PakettiAbletonExportSimplerDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Ableton:Export Instrument as Drum Rack (.adg)...",
  invoke=function() PakettiAbletonExportDrumRackDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export Instrument as Ableton Simpler",
  invoke = function() PakettiAbletonExportSimplerDialog() end }
renoise.tool():add_keybinding{
  name = "Global:Paketti:Export Instrument as Ableton Drum Rack",
  invoke = function() PakettiAbletonExportDrumRackDialog() end }
