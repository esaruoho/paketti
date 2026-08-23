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
-- exists. Nothing can be harvested the moment the call returns, so these only
-- work through PakettiExpandLoadableFilesAsync, which runs inside a coroutine
-- and waits for the instrument to actually appear. The plain synchronous
-- PakettiExpandLoadableFiles reports them instead of silently dropping them.
local PAKETTI_ASYNC_LOADER_FOR = {
  pti = "pti_loadsample",
  sf2 = "import_sf2",
  exs = "exs24_loadinstrument",
}

local PAKETTI_ASYNC_LABEL = {
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
  for ext in pairs(PAKETTI_ASYNC_LOADER_FOR) do out[#out + 1] = "*." .. ext end
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

--- Harvests every sample of the instruments occupying `first..last` into temp
--- wavs, then removes those scratch instruments. Returns how many wavs.
---
--- THE ONLY PLACE IN THIS FILE THAT REMOVES ANYTHING, and it is deliberately
--- hemmed in:
---
---   * It is only ever reached from the SYNCHRONOUS loader path, where the
---     loader call and this cleanup happen inside one uninterrupted Lua call.
---     Renoise cannot run its idle handler in the middle, so nothing you do and
---     no other Paketti feature can insert an instrument into the range between
---     the loader creating it and this removing it. There is no window.
---   * `first` is always `before + 1`, computed from the instrument count taken
---     immediately before the loader ran, so index `before` and everything under
---     it - the whole song as it was - is unreachable from here.
---   * The guards below refuse the job outright if those invariants do not hold.
---
--- The asynchronous path does NOT use this. It waits, which means a window
--- exists, so it never removes anything at all - see
--- paketti_expand_via_async_loader.
local function paketti_harvest_range(first, last, short, out, temps, floor)
  local song = renoise.song()
  local harvested = 0

  -- refuse to touch anything at or below the pre-existing instruments
  if floor and first <= floor then
    print("PakettiExpandLoadable: refusing to clean up - range would reach "
      .. "pre-existing instruments (first=" .. tostring(first)
      .. ", floor=" .. tostring(floor) .. ")")
    return 0
  end
  if first < 2 or last < first or last > #song.instruments then
    print("PakettiExpandLoadable: refusing to clean up - implausible range "
      .. tostring(first) .. ".." .. tostring(last)
      .. " of " .. #song.instruments)
    return 0
  end

  for index = first, last do
    local instrument = song.instruments[index]
    if instrument then
      for sample_index = 1, #instrument.samples do
        local sample = instrument.samples[sample_index]
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

  for index = last, first, -1 do
    if song.instruments[index] then song:delete_instrument_at(index) end
  end

  return harvested
end

--- Runs a SYNCHRONOUS Paketti loader and harvests what it built.
---
--- The selected instrument is moved to the end of the list first, so that
--- loaders which insert after the selection and loaders which append at the end
--- both land in the same place - everything from `before + 1` onwards is new.
local function paketti_expand_via_loader(path, loader_name, out, temps, failures)
  local loader = rawget(_G, loader_name)
  local short = path:match("[^/\\]+$") or path
  if type(loader) ~= "function" then
    failures[#failures + 1] = short .. " (no loader for this format in this build)"
    return
  end

  local song = renoise.song()
  song.selected_instrument_index = #song.instruments
  local before = #song.instruments

  local ok, err = pcall(loader, path)
  if not ok then
    failures[#failures + 1] = short .. " (" .. tostring(err) .. ")"
  end

  if #song.instruments <= before then
    if ok then failures[#failures + 1] = short .. " (loader produced nothing)" end
    song.selected_instrument_index = math.min(before, #song.instruments)
    return
  end

  local harvested = paketti_harvest_range(before + 1, #song.instruments, short, out, temps, before)
  song.selected_instrument_index = math.min(before, #song.instruments)
  if harvested == 0 then
    failures[#failures + 1] = short .. " (no audio found in it)"
  end
end

--- Runs an ASYNCHRONOUS Paketti loader and LEAVES what it built in the song.
---
--- MUST be called from inside a coroutine.
---
--- These loaders spin up their own ProcessSlicer and return before the
--- instrument exists, so the only way to harvest their audio would be to wait,
--- then delete the instruments afterwards. That is not safe and this does not
--- do it: during a wait that can run for many seconds, anything YOU add to the
--- song - or anything another Paketti feature adds - would sit inside the
--- delete range and be destroyed. So this path never deletes anything.
---
--- Instead the file simply loads as its own instrument, which is what its
--- importer was written to produce, and the caller is told about it rather than
--- being handed a wav. The wait is only there so the instruments land in a
--- predictable order relative to whatever loads next; nothing depends on it.
local PAKETTI_ASYNC_SETTLE = 12      -- idle passes with no change = finished
local PAKETTI_ASYNC_GIVE_UP = 1200   -- idle passes total, a sane upper bound

local function paketti_expand_via_async_loader(path, loader_name, label, loaded_directly, failures)
  local loader = rawget(_G, loader_name)
  local short = path:match("[^/\\]+$") or path
  if type(loader) ~= "function" then
    failures[#failures + 1] = short .. " (no " .. label .. " loader in this build)"
    return
  end

  local song = renoise.song()
  song.selected_instrument_index = #song.instruments
  local before = #song.instruments

  local ok, err = pcall(loader, path)
  if not ok then
    failures[#failures + 1] = short .. " (" .. tostring(err) .. ")"
    return
  end

  local last_count, steady, waited = #song.instruments, 0, 0
  while waited < PAKETTI_ASYNC_GIVE_UP do
    coroutine.yield()
    waited = waited + 1
    local now = #song.instruments
    if now ~= last_count then
      last_count = now
      steady = 0
    elseif now > before then
      steady = steady + 1
      if steady >= PAKETTI_ASYNC_SETTLE then break end
    end
  end

  local added = #song.instruments - before
  if added <= 0 then
    failures[#failures + 1] = short .. " (" .. label .. " loader produced nothing)"
    return
  end
  loaded_directly[#loaded_directly + 1] = string.format("%s (%d instrument%s)",
    short, added, added == 1 and "" or "s")
end

--------------------------------------------------------------------------------
-- the entry points
--------------------------------------------------------------------------------

--- Expands ONE selected path. `allow_async` may only be true inside a coroutine.
local function paketti_expand_one(path, out, temps, failures, allow_async, loaded_directly)
  local ext = paketti_extension_of(path)
  local short = path:match("[^/\\]+$") or path

  if PAKETTI_NATIVE_AUDIO[ext] then
    out[#out + 1] = path
  elseif ext == "mod" or short:lower():match("^mod%.") then
    paketti_expand_mod(path, out, temps, failures)
  elseif PAKETTI_ASYNC_LOADER_FOR[ext] then
    if allow_async then
      paketti_expand_via_async_loader(path, PAKETTI_ASYNC_LOADER_FOR[ext],
        PAKETTI_ASYNC_LABEL[ext], loaded_directly, failures)
    else
      failures[#failures + 1] = short .. " (" .. PAKETTI_ASYNC_LABEL[ext] ..
        " files load on their own - use File > Paketti Import for this one)"
    end
  elseif PAKETTI_LOADER_FOR[ext] then
    paketti_expand_via_loader(path, PAKETTI_LOADER_FOR[ext], out, temps, failures)
  else
    -- unknown extension: let Renoise try it anyway rather than refusing.
    -- This is what makes the wide-open Linux dialog safe.
    out[#out + 1] = path
  end
end

--- Synchronous expansion. Handles everything except the formats whose loaders
--- run on their own ProcessSlicer (.pti, .sf2, .exs) - those are reported.
--- Returns paths, temp_paths, failures.
function PakettiExpandLoadableFiles(paths)
  local out, temps, failures = {}, {}, {}
  for _, path in ipairs(paths or {}) do
    paketti_expand_one(path, out, temps, failures, false, nil)
  end
  return out, temps, failures
end

--- Asynchronous expansion, which additionally handles .pti, .sf2 and .exs.
--- Runs on its own ProcessSlicer and calls on_done(paths, temps, failures).
--- Skips the slicer entirely when nothing needs converting, so a plain pile of
--- wavs behaves exactly as it always did.
function PakettiExpandLoadableFilesAsync(paths, on_done)
  paths = paths or {}

  local needs_work = false
  for _, path in ipairs(paths) do
    local ext = paketti_extension_of(path)
    local short = path:match("[^/\\]+$") or path
    if not PAKETTI_NATIVE_AUDIO[ext] then
      if ext == "mod" or short:lower():match("^mod%.")
        or PAKETTI_LOADER_FOR[ext] or PAKETTI_ASYNC_LOADER_FOR[ext] then
        needs_work = true
        break
      end
    end
  end

  if not needs_work then
    on_done(paths, {}, {})
    return
  end

  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    local out, temps, failures, loaded_directly = {}, {}, {}, {}
    for index, path in ipairs(paths) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format("Converting %d/%d\n%s",
          index, #paths, path:match("[^/\\]+$") or path)
      end
      paketti_expand_one(path, out, temps, failures, true, loaded_directly)
      coroutine.yield()
    end
    if dialog and dialog.visible then dialog:close() end

    -- .pti / .sf2 / .exs became instruments of their own rather than wavs, and
    -- were left exactly where their importer put them
    if #loaded_directly > 0 then
      local message = "Loaded straight into their own instruments: "
        .. table.concat(loaded_directly, ", ")
      renoise.app():show_status(message)
      print("PakettiExpandLoadable: " .. message)
    end

    on_done(out, temps, failures)
  end)
  dialog, vb = slicer:create_dialog("Converting to audio...")
  slicer:start()
end

--- Deletes the temp files the expanders created.
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
