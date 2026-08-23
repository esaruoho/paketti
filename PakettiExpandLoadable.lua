--[[============================================================================
PakettiExpandLoadable.lua — turn anything Paketti can load into plain .wav paths

WHY THIS EXISTS
--------------------------------------------------------------------------------
The PitchBend Multiple Sample Loader and the PitchBend Drumkit Loader both ask
for files with

    prompt_for_multiple_filenames_to_read({"*.wav","*.aif","*.flac","*.mp3","*.aiff"}, ...)

On macOS that filter is advisory - you can usually still pick whatever you
like. On Linux the GTK file dialog enforces it, so Linux users physically
cannot select a .mod, .rex, .rx2, .iff and so on. Even if they could, the
loaders call sample_buffer:load_from(), which only understands the plain audio
formats, so a .mod would fail anyway.

This file fixes both halves:

  PakettiLoadableExtensions()      the dialog filter, covering every format
                                   Paketti knows how to turn into audio.

  PakettiExpandLoadableFiles(paths)  takes the selected list and returns a flat
                                   list of .wav paths that load_from() will
                                   accept, plus the temp files to delete after.

HOW THE CONVERSION WORKS
--------------------------------------------------------------------------------
Plain audio files pass straight through untouched - no re-encoding, no quality
loss, no temp file.

A .mod is decoded by PakettiMODParser directly into one .wav per sample. That
is the natural reading of "multiple sample loader": a 31-sample module becomes
31 entries in the list.

Everything else (.rex, .rx2, .iff, .8svx, .16sv, .pti, .iti, .ot, .sf2, .exs,
.wt, .mti) is handled by the Paketti loader that already owns that format.
Those loaders all build a Renoise instrument rather than handing back audio, so
this bridges the gap: it lets the loader build its instrument, writes every
sample in it out with sample_buffer:save_as(), then deletes the instrument
again. One code path covers every present and future format hook.

Formats that genuinely cannot work on the running platform are reported rather
than silently skipped - .rx2 on Linux, for instance, needs a decoder that only
ships as a Windows executable.
============================================================================]]--

--------------------------------------------------------------------------------
-- what counts as what
--------------------------------------------------------------------------------

-- Formats Renoise's own sample_buffer:load_from() reads. These pass through.
local PAKETTI_NATIVE_AUDIO = {
  wav = true, aif = true, aiff = true, flac = true, mp3 = true,
  ogg = true, wv = true, caf = true, snd = true, au = true, voc = true,
}

-- Everything else Paketti can turn into audio, mapped to the global loader
-- that owns it. Each of these builds an instrument from the file SYNCHRONOUSLY,
-- which is what lets the audio be harvested the moment the call returns.
local PAKETTI_LOADER_FOR = {
  rex  = "rex_loadsample",
  rx2  = "rx2_loadsample",
  iff  = "loadIFFSample",
  ["8svx"] = "loadIFFSample",
  ["16sv"] = "loadIFFSample",
  iti  = "iti_loadinstrument",
  ot   = "ot_import_filehook",
  wt   = "wt_loadsample",
  mti  = "mti_loadsample",
}

-- Loaders that start their OWN ProcessSlicer and return before the instrument
-- exists. There is nothing to harvest when the call returns, so these cannot be
-- bridged this way - pretending otherwise would silently drop the file. They
-- are named here so the user gets told which importer to use instead of a
-- useless "loader produced nothing".
local PAKETTI_ASYNC_LOADER = {
  pti = "Polyend PTI",
  sf2 = "SoundFont SF2",
  exs = "Logic EXS24",
}

local function paketti_extension_of(path)
  return (path:match("%.([^%.\\/]+)$") or ""):lower()
end

--- Builds a temp .wav path that carries a MEANINGFUL name.
---
--- This matters more than it looks. Both pitchbend loaders name the instrument
--- and the sample after the file they loaded, so handing them
--- "paketti_temp_1787509778_482014.wav" would turn a 31-sample module into 31
--- instruments called "paketti_temp_<numbers>". Naming the temp file after the
--- sample instead means the loaders produce "ST-12_newwhist" with no changes
--- needed on their side.
local paketti_expand_temp_dir = nil
local paketti_expand_used = {}

local function paketti_named_temp_wav(basename)
  if not paketti_expand_temp_dir then
    local probe = pakettiGetTempFilePath(".wav")
    paketti_expand_temp_dir = probe:match("^(.*[/\\])") or ""
    os.remove(probe)
  end

  local safe = basename
  if rawget(_G, "pakettiFSPath") and pakettiFSPath.sanitize_filename then
    safe = pakettiFSPath.sanitize_filename(basename, "sample")
  else
    safe = (basename or "sample"):gsub("[^%w%-%_%. ]", "_")
  end
  if safe == "" then safe = "sample" end

  local candidate = paketti_expand_temp_dir .. safe .. ".wav"
  local attempt = 1
  while paketti_expand_used[candidate] or io.exists(candidate) do
    attempt = attempt + 1
    candidate = paketti_expand_temp_dir .. safe .. "-" .. attempt .. ".wav"
  end
  paketti_expand_used[candidate] = true
  return candidate
end

--- The filter list for prompt_for_multiple_filenames_to_read, covering plain
--- audio plus every format PakettiExpandLoadableFiles can convert.
---
--- On Linux this returns a wide-open "*" instead. The GTK file dialog enforces
--- its filter strictly, and an extension list can never be complete - an Amiga
--- module named "mod.SongName" carries no extension at all, and files copied
--- off old media routinely have the wrong case or none. Rather than police
--- what can be picked, Linux users pick anything and
--- PakettiExpandLoadableFiles decides what to do with it, reporting whatever
--- it cannot convert. macOS and Windows treat the filter as a hint, so they
--- keep the readable list.
function PakettiLoadableExtensions()
  if os.platform() == "LINUX" then return {"*"} end

  local out = {}
  for ext in pairs(PAKETTI_NATIVE_AUDIO) do out[#out + 1] = "*." .. ext end
  for ext in pairs(PAKETTI_LOADER_FOR) do out[#out + 1] = "*." .. ext end
  for ext in pairs(PAKETTI_ASYNC_LOADER) do out[#out + 1] = "*." .. ext end
  out[#out + 1] = "*.mod"
  table.sort(out)
  -- Amiga modules are often named "mod.SongName" with the tag in front
  out[#out + 1] = "mod.*"
  return out
end

--------------------------------------------------------------------------------
-- .MOD -> one wav per sample, straight from the parser
--------------------------------------------------------------------------------

local function paketti_expand_mod(path, out, temps, failures)
  local data, read_err = PakettiMODParser.read_file(path)
  if not data then
    failures[#failures + 1] = path:match("[^/\\]+$") .. " (" .. tostring(read_err) .. ")"
    return
  end
  local mod, parse_err = PakettiMODParser.parse(data)
  if not mod then
    failures[#failures + 1] = path:match("[^/\\]+$") .. " (" .. tostring(parse_err) .. ")"
    return
  end

  for _, info in ipairs(mod.samples) do
    local wav = PakettiMODParser.build_wav(PakettiMODParser.sign_flip(info.data), 44100)
    local name = (#info.name > 0 and info.name) or ("Sample_" .. info.index)
    local tmp = paketti_named_temp_wav(name)
    local wrote = PakettiMODParser.write_file(tmp, wav)
    if wrote then
      out[#out + 1] = tmp
      temps[#temps + 1] = tmp
    end
  end
end

--------------------------------------------------------------------------------
-- anything with a Paketti loader -> let it build an instrument, harvest the audio
--------------------------------------------------------------------------------

local function paketti_expand_via_loader(path, loader_name, out, temps, failures)
  local loader = rawget(_G, loader_name)
  local short = path:match("[^/\\]+$")
  if type(loader) ~= "function" then
    failures[#failures + 1] = short .. " (no loader for this format in this build)"
    return
  end

  local song = renoise.song()
  local before = #song.instruments
  local at = song.selected_instrument_index

  -- The loaders insert their own instrument after the selected one and leave it
  -- selected, so remember where we were and work out what appeared.
  local ok, err = pcall(loader, path)
  if not ok then
    failures[#failures + 1] = short .. " (" .. tostring(err) .. ")"
  end

  local added = #song.instruments - before
  if added <= 0 then
    if ok then failures[#failures + 1] = short .. " (loader produced nothing)" end
    return
  end

  -- harvest every sample of every instrument the loader created
  local harvested = 0
  for index = at + added, at + 1, -1 do
    local instrument = song.instruments[index]
    if instrument then
      for s = 1, #instrument.samples do
        local sample = instrument.samples[s]
        local buffer = sample.sample_buffer
        -- slice aliases share the parent's audio, so skip them
        if buffer and buffer.has_sample_data and not sample.is_slice_alias then
          -- the IFF loader names its sample "fkoo.iff", which would become
          -- "fkoo.iff.wav" - strip any trailing format extension first
          local base = sample.name
          if not base or base == "" then base = short end
          if rawget(_G, "pakettiFSPath") and pakettiFSPath.strip_audio_extension then
            base = pakettiFSPath.strip_audio_extension(base)
          end
          local tmp = paketti_named_temp_wav(base)
          local saved = pcall(function() return buffer:save_as(tmp, "wav") end)
          if saved then
            out[#out + 1] = tmp
            temps[#temps + 1] = tmp
            harvested = harvested + 1
          end
        end
      end
    end
  end

  -- put the song back the way we found it
  for index = at + added, at + 1, -1 do
    if song.instruments[index] then song:delete_instrument_at(index) end
  end
  song.selected_instrument_index = math.min(at, #song.instruments)

  if harvested == 0 then
    failures[#failures + 1] = short .. " (no audio found in it)"
  end
end

--------------------------------------------------------------------------------
-- the entry point
--------------------------------------------------------------------------------

--- Expands a list of selected files into a flat list of .wav paths that
--- sample_buffer:load_from() accepts.
--- Returns paths, temp_paths, failures.
---   paths      what to load, in order
---   temp_paths what to delete afterwards (a subset of paths)
---   failures   human-readable "name (why)" strings for anything skipped
function PakettiExpandLoadableFiles(paths)
  local out, temps, failures = {}, {}, {}

  for _, path in ipairs(paths or {}) do
    local ext = paketti_extension_of(path)
    local short = path:match("[^/\\]+$") or path

    if PAKETTI_NATIVE_AUDIO[ext] then
      out[#out + 1] = path
    elseif ext == "mod" or short:lower():match("^mod%.") then
      paketti_expand_mod(path, out, temps, failures)
    elseif PAKETTI_ASYNC_LOADER[ext] then
      failures[#failures + 1] = short .. " (" .. PAKETTI_ASYNC_LOADER[ext] ..
        " files load on their own - use File > Paketti Import for this one)"
    elseif PAKETTI_LOADER_FOR[ext] then
      paketti_expand_via_loader(path, PAKETTI_LOADER_FOR[ext], out, temps, failures)
    else
      -- unknown extension: let Renoise try it anyway rather than refusing
      out[#out + 1] = path
    end
  end

  return out, temps, failures
end

--- Deletes the temp files PakettiExpandLoadableFiles created.
function PakettiExpandLoadableCleanup(temps)
  for _, path in ipairs(temps or {}) do os.remove(path) end
end

--- Shared reporting so both loaders say the same thing about skipped files.
function PakettiExpandLoadableReport(label, original_count, expanded_count, failures)
  if #failures == 0 then return end
  local message = string.format("%s: %d of %d selected files could not be converted - %s",
    label, #failures, original_count, table.concat(failures, ", "))
  renoise.app():show_status(message)
  print("PakettiExpandLoadable: " .. message)
end
