--[[============================================================================
PakettiMODLoader.lua — ProTracker / Soundtracker .MOD sample tools

Two features, both built on the pure-Lua parser in PakettiMODParser.lua:

  load_samples_from_mod()          — pick one .mod, load every sample in it as
                                     its own Renoise instrument (Paketti
                                     defaults + loop points applied).
  PakettiMODToWAVBatchDialog()     — point at a folder of .mod files and write
                                     every sample in every module out as
                                     <modulename>-<NN>-<samplename>.wav.

Helpers are declared above their callers, and every registration sits at the
bottom of the file, after the functions it names (skill rules 18 and 28).
============================================================================]]--

--------------------------------------------------------------------------------
-- shared helpers
--------------------------------------------------------------------------------

local RATE_MODE_LABELS = {
  "Amiga 8363 Hz (apply finetune)",
  "Amiga 8363 Hz (ignore finetune)",
  "16726 Hz",
  "22050 Hz",
  "44100 Hz",
}

local RATE_MODE_VALUES = { 8363, 8363, 16726, 22050, 44100 }

-- Returns the WAV sample rate to stamp for one .MOD sample under a rate mode.
local function paketti_mod_rate_for(rate_mode, finetune)
  rate_mode = rate_mode or 1
  local base = RATE_MODE_VALUES[rate_mode] or 8363
  if rate_mode == 1 then
    return PakettiMODParser.finetune_rate(base, finetune)
  end
  return base
end

-- Strips the .mod extension (or a leading "mod." Amiga prefix) from a filename
-- and returns a filesystem-safe module name for use in output filenames.
local function paketti_mod_module_basename(filename)
  local base = filename:gsub("%.[mM][oO][dD]$", "")
  base = base:gsub("^[mM][oO][dD]%.", "")
  return pakettiFSPath.sanitize_filename(base, "module")
end

-- True when a filename looks like a ProTracker module by name alone.
local function paketti_mod_is_mod_filename(filename)
  local lower = filename:lower()
  return lower:match("%.mod$") ~= nil or lower:match("^mod%.") ~= nil
end

-- Collects .mod files under a folder. Recurses into subfolders when asked,
-- skipping hidden ones. Returns a sorted array of absolute paths.
function PakettiMODCollectFiles(folder, recurse)
  return pakettiFSPath.collect_files(folder, recurse, paketti_mod_is_mod_filename)
end

--------------------------------------------------------------------------------
-- shared: one parsed .MOD sample -> one Renoise sample slot
--------------------------------------------------------------------------------

--- Loads one parsed .MOD sample into `sample_index` of `ins`, applying Paketti's
--- loader preferences and the module's loop points. Creates the slot when it is
--- missing. Used by both "Load Samples from .MOD" and the batch .MOD -> .XRNI
--- converter, so the two cannot drift apart.
--- Returns true plus the display name, or false plus an error message.
function PakettiMODApplySampleToSlot(ins, sample_index, info)
  local name = (#info.name > 0 and info.name) or ("Sample_" .. info.index)

  -- The in-Renoise path has always stamped 44100 Hz on the temp WAV; the samples
  -- are pitched by keyzone anyway. The batch .WAV exporter is the one that cares
  -- about the real Amiga rate.
  local wav = PakettiMODParser.build_wav(PakettiMODParser.sign_flip(info.data), 44100)

  local tmp = pakettiGetTempFilePath(".wav")
  local wrote, write_err = PakettiMODParser.write_file(tmp, wav)
  if not wrote then return false, tostring(write_err) end

  while #ins.samples < sample_index do
    ins:insert_sample_at(#ins.samples + 1)
  end

  local samp = ins.samples[sample_index]
  if not samp.sample_buffer:load_from(tmp) then
    os.remove(tmp)
    return false, "Renoise could not load the converted audio"
  end
  os.remove(tmp)

  samp.name = name
  samp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  samp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  samp.autofade           = preferences.pakettiLoaderAutofade.value
  samp.autoseek           = preferences.pakettiLoaderAutoseek.value
  samp.oneshot            = preferences.pakettiLoaderOneshot.value
  samp.new_note_action    = preferences.pakettiLoaderNNA.value
  samp.loop_release       = preferences.pakettiLoaderLoopExit.value

  if info.loop_length and info.loop_length > 5 then
    local sample_length = samp.sample_buffer.number_of_frames
    local loop_start = info.loop_start + 1
    local loop_end = info.loop_start + info.loop_length

    if loop_start > sample_length then
      -- the module points its loop past the end of its own sample data
      name = name .. " (invalid loopstart)"
      samp.name = name
      samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
    else
      if loop_end > sample_length then loop_end = sample_length end
      samp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      samp.loop_start = loop_start
      samp.loop_end = loop_end
    end
  else
    samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
  end

  return true, name
end

--------------------------------------------------------------------------------
-- Load Samples from .MOD (single module -> Renoise instruments)
--------------------------------------------------------------------------------

--- Loads every sample of one .mod as its own Renoise instrument.
--- `mod_file` is optional: pass a path to run without the file dialog (which is
--- what makes this testable headlessly), omit it to prompt.
function load_samples_from_mod(mod_file)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()

  if not mod_file then
    mod_file = renoise.app():prompt_for_filename_to_read(
      { "*.mod","mod.*" }, "Load .MOD file"
    )
  end
  if not mod_file then
    renoise.app():show_status("No MOD selected.")
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

  local data, read_err = PakettiMODParser.read_file(mod_file)
  if not data then
    renoise.app():show_status("Cannot open .MOD: " .. tostring(read_err))
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

  local mod, parse_err = PakettiMODParser.parse(data)
  if not mod then
    renoise.app():show_status("Not a valid .MOD: " .. tostring(parse_err))
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

  -- A 31-sample module means 31 instrument inserts, each one pulling in the
  -- Paketti default instrument template, so this runs on a ProcessSlicer with a
  -- progress dialog rather than freezing Renoise for the duration.
  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    local loaded, failed = 0, 0

    for position, info in ipairs(mod.samples) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = ("Sample %d/%d: %s"):format(
          position, #mod.samples, info.name)
      end

      local next_ins = renoise.song().selected_instrument_index + 1
      if not safeInsertInstrumentAt(renoise.song(), next_ins) then
        renoise.app():show_status("Load Samples from .MOD: could not insert an instrument.")
        break
      end
      renoise.song().selected_instrument_index = next_ins
      pakettiPreferencesDefaultInstrumentLoader()
      local ins = renoise.song().selected_instrument
      ins.macros_visible = true
      ins.sample_modulation_sets[1].name = "Pitchbend"

      local ok, name_or_err = PakettiMODApplySampleToSlot(ins, 1, info)
      if ok then
        ins.name = name_or_err
        loaded = loaded + 1
      else
        failed = failed + 1
        print(("PakettiMODLoader: sample %d failed - %s"):format(info.index, tostring(name_or_err)))
      end
      coroutine.yield()
    end

    local message = ("All MOD samples loaded (%d of %d from %s)."):format(
      loaded, #mod.samples, mod.format)
    if failed > 0 then
      message = message .. (" %d failed - see the console."):format(failed)
    end
    renoise.app():show_status(message)
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    if dialog and dialog.visible then dialog:close() end
  end)

  dialog, vb = slicer:create_dialog("Loading .MOD samples...")
  slicer:start()
end

--------------------------------------------------------------------------------
-- .MOD Loader dialog
--------------------------------------------------------------------------------

local mod_loader_dialog = nil

local function paketti_mod_dialog_choose_file(vb)
  local path = renoise.app():prompt_for_filename_to_read(
    { "*.mod", "mod.*" }, "Select .MOD file"
  )
  if path and path ~= "" and vb and vb.views and vb.views.mod_loader_file then
    vb.views.mod_loader_file.text = path
  end
end

local function paketti_mod_dialog_path(vb)
  if not vb or not vb.views or not vb.views.mod_loader_file then return nil end
  local path = vb.views.mod_loader_file.text
  if path and path ~= "" then return path end
  return nil
end

local function paketti_mod_loader_open(label, mod_file)
  if not mod_file or mod_file == "" then
    mod_file = renoise.app():prompt_for_filename_to_read(
      { "*.mod", "mod.*" }, "Load .MOD file"
    )
  end
  if not mod_file or mod_file == "" then
    renoise.app():show_status(label .. ": no .MOD selected.")
    return nil
  end

  local data, read_err = PakettiMODParser.read_file(mod_file)
  if not data then
    renoise.app():show_status(label .. ": cannot open .MOD - " .. tostring(read_err))
    return nil
  end

  local mod, parse_err = PakettiMODParser.parse(data)
  if not mod then
    renoise.app():show_status(label .. ": not a valid .MOD - " .. tostring(parse_err))
    return nil
  end
  if #mod.samples == 0 then
    renoise.app():show_status(label .. ": this .MOD holds no sample data.")
    return nil
  end
  return mod
end

local function paketti_mod_loader_insert_sample_after(song, after_index, info)
  local index = after_index + 1
  if not safeInsertInstrumentAt(song, index) then
    return nil, "could not insert an instrument"
  end
  song.selected_instrument_index = index
  pakettiPreferencesDefaultInstrumentLoader()

  local ins = song.instruments[index]
  ins.macros_visible = true
  ins.sample_modulation_sets[1].name = "Pitchbend"

  local ok, name_or_err = PakettiMODApplySampleToSlot(ins, 1, info)
  if not ok then
    song:delete_instrument_at(index)
    return nil, tostring(name_or_err)
  end
  ins.name = name_or_err
  song.selected_sample_index = 1
  return index, name_or_err
end

local function paketti_mod_dialog_run(vb, label, invoke)
  local path = paketti_mod_dialog_path(vb)
  if not path then
    paketti_mod_dialog_choose_file(vb)
    path = paketti_mod_dialog_path(vb)
  end
  if not path then
    renoise.app():show_status(label .. ": no .MOD selected.")
    return
  end
  invoke(path)
end

function PakettiMODLoadAllRenoise(mod_file)
  local label = "All Renoise .MOD Load"
  local mod = paketti_mod_loader_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    local song = renoise.song()
    local loaded, failed = 0, 0

    for position, info in ipairs(mod.samples) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "Renoise sample %d/%d: %s", position, #mod.samples, info.name)
      end
      local index, err = paketti_mod_loader_insert_sample_after(
        song, song.selected_instrument_index, info)
      if index then
        loaded = loaded + 1
      else
        failed = failed + 1
        print(("PakettiMODLoader: sample %d failed - %s"):format(info.index, tostring(err)))
      end
      coroutine.yield()
    end

    PakettiRestoreNewSampleMonitoring(monitoring)
    if dialog and dialog.visible then dialog:close() end

    local message = string.format("%s: %d of %d samples loaded",
      label, loaded, #mod.samples)
    if failed > 0 then message = message .. string.format(", %d failed", failed) end
    renoise.app():show_status(message .. "; loading wavetable...")
    if PakettiLoadMODAsWavetable then
      PakettiLoadMODAsWavetable(mod_file)
    else
      pakettiLoadExeAsSample(mod_file)
    end
  end)

  dialog, vb = slicer:create_dialog("Loading all .MOD Renoise targets...")
  slicer:start()
end

function PakettiMODLoadAllAmigo(mod_file)
  local label = "All Amigo .MOD Load"
  local mod = paketti_mod_loader_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    local song = renoise.song()
    local made, failed = 0, {}

    for position, info in ipairs(mod.samples) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "Amigo sample %d/%d: %s", position, #mod.samples, info.name)
      end

      local scratch, name_or_err = paketti_mod_loader_insert_sample_after(
        song, song.selected_instrument_index, info)
      if not scratch then
        failed[#failed + 1] = string.format("%02d (%s)", info.index, tostring(name_or_err))
      else
        local ok, send_err, count, dropped, amigo_index =
          PakettiAmigoSendInstrumentToAmigo(scratch)
        song:delete_instrument_at(scratch)
        if ok then
          song.selected_instrument_index = amigo_index - 1
          made = made + 1
        else
          failed[#failed + 1] = string.format("%02d %s (%s)",
            info.index, tostring(name_or_err), tostring(send_err))
        end
      end
      coroutine.yield()
    end

    PakettiRestoreNewSampleMonitoring(monitoring)
    if dialog and dialog.visible then dialog:close() end

    local message = string.format("%s: %d of %d samples loaded to Amigo",
      label, made, #mod.samples)
    if #failed > 0 then message = message .. " - skipped " .. table.concat(failed, ", ") end
    renoise.app():show_status(message .. "; loading wavetable to Amigo...")
    PakettiMODWavetableToAmigo(mod_file)
  end)

  dialog, vb = slicer:create_dialog("Loading all .MOD Amigo targets...")
  slicer:start()
end

function PakettiMODLoadOneWithEverything(mod_file)
  local label = "Make Me One With Everything"
  local mod = paketti_mod_loader_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    local song = renoise.song()
    local paired, failed = 0, {}

    for position, info in ipairs(mod.samples) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "Renoise + Amigo pair %d/%d: %s", position, #mod.samples, info.name)
      end

      local renoise_index, name_or_err = paketti_mod_loader_insert_sample_after(
        song, song.selected_instrument_index, info)
      if not renoise_index then
        failed[#failed + 1] = string.format("%02d (%s)", info.index, tostring(name_or_err))
      else
        local ok, send_err, count, dropped, amigo_index =
          PakettiAmigoSendInstrumentToAmigo(renoise_index)
        if ok then
          song.selected_instrument_index = amigo_index
          paired = paired + 1
        else
          song.selected_instrument_index = renoise_index
          failed[#failed + 1] = string.format("%02d %s (%s)",
            info.index, tostring(name_or_err), tostring(send_err))
        end
      end
      coroutine.yield()
    end

    PakettiRestoreNewSampleMonitoring(monitoring)
    if dialog and dialog.visible then dialog:close() end

    local message = string.format("%s: %d Renoise/Amigo sample pairs loaded",
      label, paired)
    if #failed > 0 then message = message .. " - skipped " .. table.concat(failed, ", ") end
    renoise.app():show_status(message .. "; loading both wavetables...")
    if PakettiLoadMODAsWavetable then
      PakettiLoadMODAsWavetable(mod_file)
    else
      pakettiLoadExeAsSample(mod_file)
    end
    PakettiMODCreateSlicedWavetable(mod_file, {
      label = "Make Me One With Everything Sliced .MOD Wavetable",
      send_to_amigo = true,
      keep_chain = true,
      select = "chain"
    })
  end)

  dialog, vb = slicer:create_dialog("Making one .MOD with everything...")
  slicer:start()
end

function PakettiMODLoaderDialog()
  if mod_loader_dialog and mod_loader_dialog.visible then
    mod_loader_dialog:close()
    mod_loader_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

  local content = vb:column{
    margin = DEFAULT_MARGIN,
    spacing = 6,

    vb:row{
      vb:text{ text = ".MOD File", width = 70 },
      vb:textfield{
        id = "mod_loader_file",
        width = 430,
        text = ""
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function() paketti_mod_dialog_choose_file(vb) end
      }
    },

    vb:row{
      vb:button{
        text = "Load Samples from .MOD",
        width = 210,
        notifier = function()
          paketti_mod_dialog_run(vb, "Load Samples from .MOD", load_samples_from_mod)
        end
      },
      vb:button{
        text = "Load .MOD as Wavetable",
        width = 210,
        notifier = function()
          paketti_mod_dialog_run(vb, "Load .MOD as Wavetable", function(path)
            if PakettiLoadMODAsWavetable then
              PakettiLoadMODAsWavetable(path)
            else
              pakettiLoadExeAsSample(path)
            end
          end)
        end
      }
    },

    vb:row{
      vb:button{
        text = "Load Samples from .MOD as Amigo",
        width = 210,
        notifier = function()
          paketti_mod_dialog_run(vb, "Load Samples from .MOD as Amigo", PakettiMODSamplesToAmigo)
        end
      },
      vb:button{
        text = "Load .MOD as Wavetable to Amigo",
        width = 210,
        notifier = function()
          paketti_mod_dialog_run(vb, "Load .MOD as Wavetable to Amigo", PakettiMODWavetableToAmigo)
        end
      }
    },

    vb:row{
      vb:button{
        text = "All Renoise",
        width = 136,
        notifier = function()
          paketti_mod_dialog_run(vb, "All Renoise", PakettiMODLoadAllRenoise)
        end
      },
      vb:button{
        text = "All Amigo",
        width = 136,
        notifier = function()
          paketti_mod_dialog_run(vb, "All Amigo", PakettiMODLoadAllAmigo)
        end
      },
      vb:button{
        text = "Make Me One With Everything",
        width = 280,
        notifier = function()
          paketti_mod_dialog_run(vb, "Make Me One With Everything", PakettiMODLoadOneWithEverything)
        end
      }
    },

    vb:row{
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if mod_loader_dialog and mod_loader_dialog.visible then
            mod_loader_dialog:close()
          end
          mod_loader_dialog = nil
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return mod_loader_dialog end,
    function(value) mod_loader_dialog = value end
  )
  mod_loader_dialog = renoise.app():show_custom_dialog(
    ".MOD Loader", content, keyhandler)
end

--------------------------------------------------------------------------------
-- Batch .MOD -> .WAV
--------------------------------------------------------------------------------

--- Converts every sample of one .mod into .wav files.
--- `seen` is a shared table of output paths already written during this batch
--- run; pass it so two modules that share a basename (different subfolders,
--- one output folder) get suffixed apart instead of overwriting each other.
--- Re-running the converter over the same folder still overwrites its own
--- previous output rather than piling up copies.
--- Returns written_count, error_string_or_nil.
function PakettiMODConvertFileToWAVs(mod_path, output_folder, rate_mode, skip_existing, seen)
  local sep = package.config:sub(1, 1)
  local filename = mod_path:match("[^/\\]+$") or mod_path
  seen = seen or {}

  local data, read_err = PakettiMODParser.read_file(mod_path)
  if not data then return 0, read_err end

  local mod, parse_err = PakettiMODParser.parse(data)
  if not mod then return 0, parse_err end

  local module_name = paketti_mod_module_basename(filename)
  local written = 0

  for _, info in ipairs(mod.samples) do
    local sample_name = pakettiFSPath.sanitize_filename(
      pakettiFSPath.strip_audio_extension(info.name), "untitled")
    local out_path = string.format("%s%s%s-%02d-%s.wav",
      output_folder, sep, module_name, info.index, sample_name)

    local n = 2
    while seen[out_path:lower()] and n < 1000 do
      out_path = string.format("%s%s%s-%02d-%s (%d).wav",
        output_folder, sep, module_name, info.index, sample_name, n)
      n = n + 1
    end
    seen[out_path:lower()] = true

    if skip_existing and io.exists(out_path) then
      -- leave it alone
    else
      local rate = paketti_mod_rate_for(rate_mode, info.finetune)
      local wav = PakettiMODParser.build_wav(PakettiMODParser.sign_flip(info.data), rate)
      local ok_write, write_err = PakettiMODParser.write_file(out_path, wav)
      if ok_write then
        written = written + 1
      else
        return written, write_err
      end
    end
  end

  if mod.truncated then
    print(string.format("-- MOD->WAV: %s has sample data running past end of file; wrote what was there", filename))
  end

  return written, nil
end

--- Batch driver. Runs on a ProcessSlicer so Renoise stays responsive across
--- hundreds of modules, and so the run can be cancelled.
function PakettiMODBatchConvertToWAV(source_folder, output_folder, recurse, rate_mode, skip_existing)
  if not source_folder or source_folder == "" then
    renoise.app():show_status("MOD->WAV: no source folder selected")
    return
  end

  local mod_files = PakettiMODCollectFiles(source_folder, recurse)
  if #mod_files == 0 then
    renoise.app():show_status("MOD->WAV: no .mod files found in " .. source_folder)
    return
  end

  local sep = package.config:sub(1, 1)
  print("------------")
  print(string.format("-- MOD->WAV: found %d .mod files under %s", #mod_files, source_folder))

  local slicer
  local function worker()
    local dialog, vb = slicer:create_dialog("Converting .MOD to .WAV")

    local total_wavs, converted, failed = 0, 0, 0
    local failed_files = {}
    -- output paths claimed during this run, so same-named modules in different
    -- subfolders do not overwrite one another
    local seen = {}

    for i, mod_path in ipairs(mod_files) do
      if slicer:was_cancelled() then break end

      local filename = mod_path:match("[^/\\]+$") or mod_path
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "%d/%d  %s\n%d .wav written so far", i, #mod_files, filename, total_wavs)
      end

      -- "same folder as the .mod" means beside each module, so a recursive run
      -- keeps the source folder structure instead of flattening it.
      local dest = output_folder
      if not dest or dest == "" then
        dest = mod_path:sub(1, #mod_path - #filename - 1)
        if dest == "" then dest = source_folder end
      end

      local ok, count_or_err, err = pcall(PakettiMODConvertFileToWAVs,
        mod_path, dest, rate_mode, skip_existing, seen)

      if not ok then
        failed = failed + 1
        table.insert(failed_files, filename .. ": " .. tostring(count_or_err))
        print(string.format("-- MOD->WAV: FAILED %s (%s)", filename, tostring(count_or_err)))
      else
        local count = count_or_err or 0
        total_wavs = total_wavs + count
        if err then
          failed = failed + 1
          table.insert(failed_files, filename .. ": " .. tostring(err))
          print(string.format("-- MOD->WAV: FAILED %s (%s)", filename, tostring(err)))
        else
          converted = converted + 1
          print(string.format("-- MOD->WAV: %s -> %d .wav", filename, count))
        end
      end

      coroutine.yield()
    end

    if dialog and dialog.visible then dialog:close() end

    local summary
    if slicer:was_cancelled() then
      summary = string.format("MOD->WAV cancelled: %d modules done, %d .wav written", converted, total_wavs)
    else
      summary = string.format("MOD->WAV complete: %d modules, %d .wav written%s",
        converted, total_wavs, failed > 0 and string.format(", %d failed", failed) or "")
    end
    print("-- " .. summary)
    for _, f in ipairs(failed_files) do print("--   failed: " .. f) end
    renoise.app():show_status(summary)
  end

  slicer = ProcessSlicer(worker)
  slicer:start()
end

--------------------------------------------------------------------------------
-- Batch .MOD -> .WAV dialog
--------------------------------------------------------------------------------

local mod_to_wav_dialog = nil

function PakettiMODToWAVBatchDialog()
  if mod_to_wav_dialog and mod_to_wav_dialog.visible then
    mod_to_wav_dialog:close()
    mod_to_wav_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

  local function refresh_count()
    local folder = preferences.pakettiMODToWAVSourceFolder.value
    if not folder or folder == "" then
      vb.views.mod_count_text.text = "No source folder selected."
      return
    end
    local files = PakettiMODCollectFiles(folder, preferences.pakettiMODToWAVRecurse.value)
    vb.views.mod_count_text.text = string.format("%d .mod file%s found.", #files, #files == 1 and "" or "s")
  end

  local content = vb:column{
    margin = DEFAULT_MARGIN,
    spacing = 4,

    vb:row{
      vb:text{ text = "Source Folder", width = 90 },
      vb:textfield{
        id = "mod_source_field",
        width = 420,
        text = preferences.pakettiMODToWAVSourceFolder.value,
        notifier = function(value)
          preferences.pakettiMODToWAVSourceFolder.value = value
          preferences:save_as("preferences.xml")
          refresh_count()
        end
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function()
          local path = renoise.app():prompt_for_path("Select folder of .MOD files")
          if path and path ~= "" then
            preferences.pakettiMODToWAVSourceFolder.value = path
            preferences:save_as("preferences.xml")
            vb.views.mod_source_field.text = path
            refresh_count()
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:checkbox{
        value = preferences.pakettiMODToWAVRecurse.value,
        notifier = function(value)
          preferences.pakettiMODToWAVRecurse.value = value
          preferences:save_as("preferences.xml")
          refresh_count()
        end
      },
      vb:text{ text = "Include subfolders" },
      vb:checkbox{
        value = preferences.pakettiMODToWAVSkipExisting.value,
        notifier = function(value)
          preferences.pakettiMODToWAVSkipExisting.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:text{ text = "Skip .wav files that already exist" }
    },

    vb:row{
      vb:text{ text = "Write .WAV to", width = 90 },
      vb:switch{
        id = "mod_output_switch",
        width = 260,
        items = { "Same folder as .MOD", "Separate folder" },
        value = preferences.pakettiMODToWAVSeparateOutput.value and 2 or 1,
        notifier = function(value)
          preferences.pakettiMODToWAVSeparateOutput.value = (value == 2)
          preferences:save_as("preferences.xml")
        end
      }
    },

    vb:row{
      vb:text{ text = "Output Folder", width = 90 },
      vb:textfield{
        id = "mod_output_field",
        width = 420,
        text = preferences.pakettiMODToWAVOutputFolder.value,
        notifier = function(value)
          preferences.pakettiMODToWAVOutputFolder.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function()
          local path = renoise.app():prompt_for_path("Select folder to write .WAV files into")
          if path and path ~= "" then
            preferences.pakettiMODToWAVOutputFolder.value = path
            preferences.pakettiMODToWAVSeparateOutput.value = true
            preferences:save_as("preferences.xml")
            vb.views.mod_output_field.text = path
            vb.views.mod_output_switch.value = 2
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "Sample Rate", width = 90 },
      vb:popup{
        width = 260,
        items = RATE_MODE_LABELS,
        value = preferences.pakettiMODToWAVRateMode.value,
        notifier = function(value)
          preferences.pakettiMODToWAVRateMode.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:text{ text = "8363 Hz is the Amiga C-3 playback rate" }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ id = "mod_count_text", text = "No source folder selected.", width = 420 }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ text = "Output filenames: modulename-NN-samplename.wav", width = 420 }
    },

    vb:row{
      vb:button{
        text = "Convert",
        width = 120,
        notifier = function()
          local source = preferences.pakettiMODToWAVSourceFolder.value
          if not source or source == "" then
            renoise.app():show_status("MOD->WAV: select a source folder first")
            return
          end
          local output = nil
          if preferences.pakettiMODToWAVSeparateOutput.value then
            output = preferences.pakettiMODToWAVOutputFolder.value
            if not output or output == "" then
              renoise.app():show_status("MOD->WAV: select an output folder, or switch to \"Same folder as .MOD\"")
              return
            end
          end
          if mod_to_wav_dialog and mod_to_wav_dialog.visible then
            mod_to_wav_dialog:close()
            mod_to_wav_dialog = nil
          end
          PakettiMODBatchConvertToWAV(
            source, output,
            preferences.pakettiMODToWAVRecurse.value,
            preferences.pakettiMODToWAVRateMode.value,
            preferences.pakettiMODToWAVSkipExisting.value)
        end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if mod_to_wav_dialog and mod_to_wav_dialog.visible then
            mod_to_wav_dialog:close()
          end
          mod_to_wav_dialog = nil
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return mod_to_wav_dialog end,
    function(value) mod_to_wav_dialog = value end
  )
  mod_to_wav_dialog = renoise.app():show_custom_dialog(
    "Batch Convert .MOD to .WAV", content, keyhandler)

  refresh_count()
end

--------------------------------------------------------------------------------
-- registrations (always last — every function above is already defined)
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}
PakettiAddMenuEntry{name="--Main Menu:File:Paketti Import:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="--Main Menu:File:Paketti Import:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}
PakettiAddMenuEntry{name="--Main Menu:Tools:Paketti Gadgets:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Load:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Load:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Load:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}
PakettiAddMenuEntry{name="Disk Browser Files:Paketti:Import/Export:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Disk Browser Files:Paketti:Import/Export:.MOD Loader...",invoke=function() PakettiMODLoaderDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Batch Convert .MOD to .WAV",invoke=function() PakettiMODToWAVBatchDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:.MOD Loader",invoke=function() PakettiMODLoaderDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Convert .MOD to .WAV",invoke=function(message) if message:is_trigger() then PakettiMODToWAVBatchDialog() end end}
renoise.tool():add_midi_mapping{name="Paketti:.MOD Loader",invoke=function(message) if message:is_trigger() then PakettiMODLoaderDialog() end end}
