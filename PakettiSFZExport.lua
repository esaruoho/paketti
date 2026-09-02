--[[============================================================================
PakettiSFZExport.lua — SFZ mapping export

SFZ is an open, plain-text instrument format read by sfizz, Sforzando, Bitwig,
Falcon and most free samplers. Paketti could already convert SFZ *into* XRNI
(PakettiForeignSnippets); this is the other direction.

Two shapes come out of it, both writing one WAV and one .sfz beside it:

  a sliced instrument   one region per slice, all pointing into the same WAV with
                        `offset` and `end` marking the slice, laid out from C1 up
  everything else       one region per sample, using each sample's own key range,
                        root note and velocity range

Nothing is transcoded: `sample_buffer:save_as` writes the audio and the .sfz is a
text sidecar, so the export is lossless with respect to what Renoise holds.
============================================================================]]--

local SFZ_FIRST_NOTE = 36   -- C1, matching the drum-kit convention elsewhere

local function sfz_escape(name)
  return (tostring(name or ""):gsub("[\r\n]", " "))
end

--- Write the selected instrument as a .sfz plus its WAV(s).
---
--- opts.existing_wav names an audio file that already holds this instrument's
--- single sample, so the .sfz can point straight at it instead of writing a
--- second copy beside it. Converting a folder of WAVs would otherwise leave a
--- duplicate of every source file next to the original.
function PakettiSFZExport(sfz_path, opts)
  opts = opts or {}
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end

  local dir = pakettiFSPath.dirname(sfz_path)
  local base = pakettiFSPath.basename(sfz_path):gsub("%.sfz$", "")
  local first = instrument.samples[1]
  local markers = first.slice_markers

  local lines = {
    "// Exported from Renoise by Paketti",
    string.format("// instrument: %s", sfz_escape(instrument.name)),
    "",
    "<control>",
    "default_path=",
    "",
    "<global>",
    "ampeg_release=0.1",
    "",
  }
  local written_wavs = 0
  local regions = 0

  if #markers > 0 and first.sample_buffer.has_sample_data then
    -- one WAV, one region per slice, delimited by offset/end
    local wav_name, wav_path
    if opts.existing_wav then
      wav_path = opts.existing_wav
      wav_name = pakettiFSPath.basename(wav_path)
    else
      wav_name = pakettiFSPath.sanitize_filename(base, "sample") .. ".wav"
      wav_path = pakettiFSPath.join(dir, wav_name)
      local ok = pcall(function() return first.sample_buffer:save_as(wav_path, "wav") end)
      if not ok or not io.exists(wav_path) then
        return false, "could not write " .. wav_path
      end
      written_wavs = 1
    end

    local frames = first.sample_buffer.number_of_frames
    local bounds = {}
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] end
    bounds[#bounds + 1] = frames + 1

    -- 128 notes exist, so a set that will not fit from C1 starts lower rather than
    -- losing its tail; laying out from C1 and breaking at 127 silently dropped
    -- every slice past the 92nd.
    local count = #bounds - 1
    local first_note = SFZ_FIRST_NOTE
    if first_note + count - 1 > 127 then first_note = 128 - count end
    if first_note < 0 then first_note = 0 end

    for i = 1, count do
      local note = first_note + i - 1
      if note > 127 then break end
      local slice = instrument.samples[i + 1]
      lines[#lines + 1] = "<region>"
      lines[#lines + 1] = "sample=" .. wav_name
      lines[#lines + 1] = string.format("lokey=%d hikey=%d pitch_keycenter=%d", note, note, note)
      -- SFZ offset/end are frame indices into the sample, zero based
      lines[#lines + 1] = string.format("offset=%d end=%d", bounds[i] - 1, bounds[i + 1] - 2)
      if slice and slice.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
        local mode = (slice.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG)
          and "loop_alternate" or "loop_continuous"
        lines[#lines + 1] = "loop_mode=" .. mode
        lines[#lines + 1] = string.format("loop_start=%d loop_end=%d",
          math.max(0, slice.loop_start - 1), math.max(0, slice.loop_end - 1))
      end
      if slice and slice.name ~= "" then
        lines[#lines + 1] = "// " .. sfz_escape(slice.name)
      end
      lines[#lines + 1] = ""
      regions = regions + 1
    end
  else
    -- one WAV and one region per sample, keeping each sample's own mapping
    for i = 1, #instrument.samples do
      local smp = instrument.samples[i]
      if smp.sample_buffer.has_sample_data then
        local wav_name, wav_path, ok
        if opts.existing_wav and #instrument.samples == 1 then
          wav_path = opts.existing_wav
          wav_name = pakettiFSPath.basename(wav_path)
          ok = true
        else
          -- only tack the index and sample name on when there is more than one,
          -- so a single sample does not become "break_01_break.wav"
          local stem = base
          if #instrument.samples > 1 then
            local nm = (smp.name ~= "" and smp.name) or tostring(i)
            stem = string.format("%s_%02d_%s", base, i, nm)
          end
          wav_name = pakettiFSPath.sanitize_filename(stem, "sample") .. ".wav"
          wav_path = pakettiFSPath.join(dir, wav_name)
          ok = pcall(function() return smp.sample_buffer:save_as(wav_path, "wav") end)
        end
        if ok and io.exists(wav_path) then
          if not opts.existing_wav then written_wavs = written_wavs + 1 end
          local map = smp.sample_mapping
          lines[#lines + 1] = "<region>"
          lines[#lines + 1] = "sample=" .. wav_name
          lines[#lines + 1] = string.format("lokey=%d hikey=%d pitch_keycenter=%d",
            map.note_range[1], map.note_range[2], map.base_note)
          lines[#lines + 1] = string.format("lovel=%d hivel=%d",
            math.max(1, map.velocity_range[1]), map.velocity_range[2])
          if smp.transpose ~= 0 then
            lines[#lines + 1] = string.format("transpose=%d", smp.transpose)
          end
          if smp.fine_tune ~= 0 then
            lines[#lines + 1] = string.format("tune=%d",
              math.floor(smp.fine_tune / 127 * 100 + 0.5))
          end
          if smp.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
            local mode = (smp.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG)
              and "loop_alternate" or "loop_continuous"
            lines[#lines + 1] = "loop_mode=" .. mode
            lines[#lines + 1] = string.format("loop_start=%d loop_end=%d",
              math.max(0, smp.loop_start - 1), math.max(0, smp.loop_end - 1))
          end
          lines[#lines + 1] = ""
          regions = regions + 1
        end
      end
    end
  end

  if regions == 0 then
    return false, "nothing to export: no sample in the instrument holds audio"
  end

  local f = io.open(sfz_path, "wb")
  if not f then return false, "could not write " .. sfz_path end
  f:write(table.concat(lines, "\n"))
  f:close()

  return true, string.format("Wrote %s (%d region%s, %s)",
    pakettiFSPath.basename(sfz_path), regions, regions == 1 and "" or "s",
    written_wavs == 0
      and ("reusing " .. pakettiFSPath.basename(opts.existing_wav or ""))
      or string.format("%d WAV%s", written_wavs, written_wavs == 1 and "" or "s"))
end

function PakettiSFZExportDialog()
  local path = renoise.app():prompt_for_filename_to_write("sfz", "Export SFZ mapping")
  if not path or path == "" then return end
  if not path:lower():match("%.sfz$") then path = path .. ".sfz" end
  local ok, msg = PakettiSFZExport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("SFZ export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiSFZExport: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export SFZ Mapping (.sfz)...",
  invoke=function() PakettiSFZExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export SFZ Mapping (.sfz)...",
  invoke=function() PakettiSFZExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export SFZ Mapping",
  invoke = function() PakettiSFZExportDialog() end }

--------------------------------------------------------------------------------
-- Batch exports
--
-- Two shapes, matching what already exists elsewhere in Paketti:
--   * every instrument in the song, written into one chosen folder
--   * a folder of source files converted in place, beside each source
--
-- The folder walk accepts audio as well as .xrni, because Renoise reads a WAV's
-- CUE points as slice markers on load — so a folder of cue-marked breaks converts
-- straight to sliced SFZ without a detour through .xrni.
--------------------------------------------------------------------------------

local SFZ_SOURCE_EXTENSIONS = { "*.xrni", "*.wav", "*.mp3", "*.flac", "*.aif", "*.aiff", "*.ogg" }

--- Every file Paketti can turn into an instrument, under `folder` and below it.
function PakettiSFZCollectSourceFiles(folder)
  local results = {}
  local sep = package.config:sub(1, 1)

  for _, pattern in ipairs(SFZ_SOURCE_EXTENSIONS) do
    local ok, files = pcall(os.filenames, folder, pattern)
    if ok and files then
      for _, fn in ipairs(files) do results[#results + 1] = folder .. sep .. fn end
    end
  end

  local ok_dirs, dirs = pcall(os.dirnames, folder)
  if ok_dirs and dirs then
    for _, d in ipairs(dirs) do
      if not d:match("^%.") then
        for _, p in ipairs(PakettiSFZCollectSourceFiles(folder .. sep .. d)) do
          results[#results + 1] = p
        end
      end
    end
  end

  table.sort(results)
  return results
end

--- Export every instrument in the song into one folder, one .sfz each.
--- The prompting wrapper is separate from the work so the whole pipeline can be
--- driven headlessly with an explicit path.
function PakettiSFZExportAllInstruments()
  local folder = nil
  local song = renoise.song()
  local any = false
  for i = 1, #song.instruments do
    for s = 1, #song.instruments[i].samples do
      if song.instruments[i].samples[s].sample_buffer.has_sample_data then any = true break end
    end
    if any then break end
  end
  if not any then
    renoise.app():show_status("Batch SFZ: no instrument in this song holds audio")
    return
  end
  folder = renoise.app():prompt_for_path("Select a folder for the SFZ instruments")
  if not folder or folder == "" then
    renoise.app():show_status("Batch SFZ: no folder selected")
    return
  end
  PakettiSFZExportAllInstrumentsToFolder(folder)
end

function PakettiSFZExportAllInstrumentsToFolder(folder)
  local song = renoise.song()

  local usable = {}
  for i = 1, #song.instruments do
    local inst = song.instruments[i]
    local has_audio = false
    for s = 1, #inst.samples do
      if inst.samples[s].sample_buffer.has_sample_data then has_audio = true break end
    end
    if has_audio then usable[#usable + 1] = i end
  end

  if #usable == 0 then
    renoise.app():show_status("Batch SFZ: no instrument in this song holds audio")
    return
  end

  local dialog, vb
  local original_index = song.selected_instrument_index

  local slicer = ProcessSlicer(function()
    local done, failed, regions = 0, 0, 0
    for n, idx in ipairs(usable) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format("Instrument %d of %d...", n, #usable)
      end

      song.selected_instrument_index = idx
      local name = song.instruments[idx].name
      if name == "" then name = string.format("Instrument %02d", idx) end
      local file = pakettiFSPath.join(folder,
        pakettiFSPath.sanitize_filename(string.format("%02d %s", idx, name), "instrument") .. ".sfz")

      local ran, ok, msg = pcall(function() return PakettiSFZExport(file) end)
      if ran and ok then
        done = done + 1
        local count = tostring(msg):match("(%d+) region")
        regions = regions + (tonumber(count) or 0)
      else
        failed = failed + 1
        print("-- Batch SFZ: FAILED " .. name .. ": " .. tostring(ran and msg or ok))
      end
      coroutine.yield()
    end

    song.selected_instrument_index = original_index
    if dialog and dialog.visible then dialog:close() end

    local msg = string.format("Batch SFZ: %d instrument%s, %d regions written to %s",
      done, done == 1 and "" or "s", regions, folder)
    if failed > 0 then msg = msg .. string.format(" (%d failed)", failed) end
    renoise.app():show_status(msg)
    print("-- " .. msg)
  end)

  dialog, vb = slicer:create_dialog("Exporting every instrument as SFZ...")
  slicer:start()
end

--- Convert a folder of instruments and audio files to SFZ, in place.
function PakettiSFZBatchConvertFolder()
  local folder = renoise.app():prompt_for_path(
    "Select folder to convert to SFZ (.xrni, .wav, .mp3, .flac, .aif, .ogg — recurses)")
  if not folder or folder == "" then
    renoise.app():show_status("Batch SFZ: no folder selected")
    return
  end
  PakettiSFZBatchConvertFolderPath(folder)
end

function PakettiSFZBatchConvertFolderPath(folder)
  local song = renoise.song()

  local sources = PakettiSFZCollectSourceFiles(folder)
  if #sources == 0 then
    renoise.app():show_status("Batch SFZ: no .xrni or audio files found in that folder")
    return
  end

  local dialog, vb
  local original_index = song.selected_instrument_index

  local slicer = ProcessSlicer(function()
    local done, failed = 0, 0
    local failures = {}

    for i, path in ipairs(sources) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format("%d/%d  %s", i, #sources,
          pakettiFSPath.basename(path))
      end

      local is_xrni = path:lower():match("%.xrni$") ~= nil
      local base = path:gsub("%.[^.]+$", "")

      local load_ok, load_err = pcall(function()
        if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
          error("maximum of 255 instruments reached")
        end
        song.selected_instrument_index = song.selected_instrument_index + 1
        if is_xrni then
          renoise.app():load_instrument(path)
        else
          -- audio file: Renoise turns any embedded CUE points into slice markers on
          -- load, so a cue-marked break arrives already sliced and its regions come
          -- out per slice; a plain WAV gives a single region
          pakettiPreferencesDefaultInstrumentLoader()
          local inst = song.selected_instrument
          inst.name = pakettiFSPath.basename(base)
          if not inst.samples[1].sample_buffer:load_from(path) then
            error("Renoise could not decode this file")
          end
          inst.samples[1].name = pakettiFSPath.basename(base)
        end
      end)

      if load_ok then
        -- an audio source already IS the WAV the .sfz needs, so reference it
        local reuse = (not is_xrni) and path or nil
        local exp_ok, ok, msg = pcall(function()
          return PakettiSFZExport(base .. ".sfz", { existing_wav = reuse })
        end)
        pcall(function()
          if #song.instruments > 1 then
            song:delete_instrument_at(song.selected_instrument_index)
          end
        end)
        if exp_ok and ok then
          done = done + 1
        else
          failed = failed + 1
          failures[#failures + 1] = path .. " (" .. tostring(exp_ok and msg or ok) .. ")"
        end
      else
        failed = failed + 1
        failures[#failures + 1] = path .. " (" .. tostring(load_err) .. ")"
        if tostring(load_err):match("maximum of 255") then
          renoise.app():show_status("Batch SFZ: hit the 255-instrument cap, stopping")
          break
        end
      end

      coroutine.yield()
    end

    song.selected_instrument_index = math.min(original_index, #song.instruments)
    if dialog and dialog.visible then dialog:close() end

    local msg = string.format("Batch SFZ: converted %d of %d file%s", done, #sources,
      #sources == 1 and "" or "s")
    if failed > 0 then msg = msg .. string.format(" (%d failed)", failed) end
    renoise.app():show_status(msg)
    print("-- " .. msg)
    for _, f in ipairs(failures) do print("   - " .. f) end
  end)

  dialog, vb = slicer:create_dialog("Converting folder to SFZ...")
  slicer:start()
end

PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:SFZ Export Current Instrument...",
  invoke=function() PakettiSFZExportDialog() end}
PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:SFZ Export All Instruments in Song...",
  invoke=function() PakettiSFZExportAllInstruments() end}
PakettiAddMenuEntry{name="Main Menu:File:Paketti Export:SFZ Batch Convert Folder (.xrni/.wav/.mp3/.flac)...",
  invoke=function() PakettiSFZBatchConvertFolder() end}
PakettiAddMenuEntry{name="Disk Browser:Paketti:Import/Export:SFZ Batch Convert Folder...",
  invoke=function() PakettiSFZBatchConvertFolder() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export All Instruments as SFZ...",
  invoke=function() PakettiSFZExportAllInstruments() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:SFZ Batch Convert Folder...",
  invoke=function() PakettiSFZBatchConvertFolder() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export All Instruments as SFZ",
  invoke = function() PakettiSFZExportAllInstruments() end }
renoise.tool():add_keybinding{
  name = "Global:Paketti:SFZ Batch Convert Folder",
  invoke = function() PakettiSFZBatchConvertFolder() end }
renoise.tool():add_midi_mapping{
  name = "Paketti:Export All Instruments as SFZ",
  invoke = function(message) if message:is_trigger() then PakettiSFZExportAllInstruments() end end }
