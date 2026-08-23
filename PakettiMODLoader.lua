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
  return PakettiMODParser.sanitize_filename(base, "module")
end

-- True when a filename looks like a ProTracker module by name alone.
local function paketti_mod_is_mod_filename(filename)
  local lower = filename:lower()
  return lower:match("%.mod$") ~= nil or lower:match("^mod%.") ~= nil
end

-- Collects .mod files under a folder. Recurses into subfolders when asked,
-- skipping hidden ones. Returns a sorted array of absolute paths.
function PakettiMODCollectFiles(folder, recurse)
  local results = {}
  local sep = package.config:sub(1, 1)

  local ok_files, files = pcall(os.filenames, folder)
  if ok_files and files then
    for _, fn in ipairs(files) do
      if paketti_mod_is_mod_filename(fn) then
        table.insert(results, folder .. sep .. fn)
      end
    end
  end

  if recurse then
    local ok_dirs, dirs = pcall(os.dirnames, folder)
    if ok_dirs and dirs then
      for _, d in ipairs(dirs) do
        if not d:match("^%.") then
          local sub = PakettiMODCollectFiles(folder .. sep .. d, true)
          for _, p in ipairs(sub) do table.insert(results, p) end
        end
      end
    end
  end

  table.sort(results, function(a, b) return a:lower() < b:lower() end)
  return results
end

--------------------------------------------------------------------------------
-- Load Samples from .MOD (single module -> Renoise instruments)
--------------------------------------------------------------------------------

function load_samples_from_mod()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()

  local mod_file = renoise.app():prompt_for_filename_to_read(
    { "*.mod","mod.*" }, "Load .MOD file"
  )
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

  for _, info in ipairs(mod.samples) do
    local name = (#info.name > 0 and info.name) or ("Sample_" .. info.index)

    -- The in-Renoise loader has always stamped 44100 Hz on the temp WAV; the
    -- samples are pitched by keyzone anyway. The batch .WAV exporter is the
    -- one that cares about the real Amiga rate.
    local wav = PakettiMODParser.build_wav(PakettiMODParser.sign_flip(info.data), 44100)

    local tmp = pakettiGetTempFilePath(".wav")
    local wrote, write_err = PakettiMODParser.write_file(tmp, wav)
    if not wrote then
      renoise.app():show_status(tostring(write_err))
    else
      local next_ins = renoise.song().selected_instrument_index + 1
      if not safeInsertInstrumentAt(renoise.song(), next_ins) then
        os.remove(tmp)
        PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
        return
      end
      renoise.song().selected_instrument_index = next_ins
      pakettiPreferencesDefaultInstrumentLoader()
      local ins = renoise.song().selected_instrument

      ins.name = name
      ins.macros_visible = true
      ins.sample_modulation_sets[1].name = "Pitchbend"

      if #ins.samples == 0 then ins:insert_sample_at(1) end
      renoise.song().selected_sample_index = 1

      local samp = ins.samples[1]
      if samp.sample_buffer:load_from(tmp) then
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
          local calculated_loop_start = info.loop_start + 1
          local calculated_loop_end = info.loop_start + info.loop_length

          if calculated_loop_start > sample_length then
            samp.name = name .. " (invalid loopstart)"
            ins.name = name .. " (invalid loopstart)"
            samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
          else
            if calculated_loop_end > sample_length then
              calculated_loop_end = sample_length
            end
            samp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
            samp.loop_start = calculated_loop_start
            samp.loop_end = calculated_loop_end
          end
        else
          samp.loop_mode = renoise.Sample.LOOP_MODE_OFF
        end

        renoise.app():show_status(("Loaded “%s”"):format(name))
      else
        renoise.app():show_status(("Failed to load “%s”"):format(name))
      end

      os.remove(tmp)
    end
  end

  renoise.app():show_status(("All MOD samples loaded (%d from %s)."):format(#mod.samples, mod.format))
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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
    local sample_name = PakettiMODParser.sanitize_filename(info.name, "untitled")
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
PakettiAddMenuEntry{name="--Main Menu:File:Paketti Import:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Load:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Disk Browser Files:Paketti:Import/Export:Batch Convert .MOD to .WAV...",invoke=function() PakettiMODToWAVBatchDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Batch Convert .MOD to .WAV",invoke=function() PakettiMODToWAVBatchDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Convert .MOD to .WAV",invoke=function(message) if message:is_trigger() then PakettiMODToWAVBatchDialog() end end}
