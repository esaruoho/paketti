--[[============================================================================
PakettiMODToXRNI.lua — Batch convert a folder of .MOD files to .xrni instruments

Companion to the batch .MOD -> .WAV converter in PakettiMODLoader.lua. Same
folder-in / files-out shape, but the output is Renoise instruments instead of
bare audio, so the Paketti default instrument (pitchbend modulation set, loader
preferences) and the module's own loop points come along for the ride.

Two grouping modes:

  One .XRNI per sample   <modulename>-<NN>-<samplename>.xrni   (default)
  One .XRNI per module   <modulename>.xrni                     — all of the
                         module's samples in a single instrument, in the
                         module's own sample order

Writing a .xrni needs Renoise, so each instrument is built in a temporary
instrument slot, saved with renoise.app():save_instrument(), and the slot is
deleted again. The user's own instruments are left alone and the selected
instrument is restored when the run finishes.

Helpers are declared above their callers and all registrations sit at the bottom
of the file, after the functions they name (skill rules 18 and 28).
============================================================================]]--

--------------------------------------------------------------------------------
-- conversion
--------------------------------------------------------------------------------

--- Builds one .xrni per sample of an already-parsed module.
--- `seen` is the shared set of output paths claimed during this run, so two
--- modules sharing a basename (different subfolders, one output folder) get
--- suffixed apart while a re-run overwrites its own previous output.
--- Yields between samples, so this must run inside a ProcessSlicer.
--- Returns written_count, skipped_count, error_string_or_nil.
function PakettiMODWriteSampleXRNIs(mod, module_name, output_folder, scratch_index, skip_existing, seen)
  seen = seen or {}
  local song = renoise.song()
  local sep = package.config:sub(1, 1)
  local written, skipped = 0, 0

  for _, info in ipairs(mod.samples) do
    local sample_name = pakettiFSPath.sanitize_filename(
      pakettiFSPath.strip_audio_extension(info.name), "untitled")
    local out_path = string.format("%s%s%s-%02d-%s.xrni",
      output_folder, sep, module_name, info.index, sample_name)

    local n = 2
    while seen[out_path:lower()] and n < 1000 do
      out_path = string.format("%s%s%s-%02d-%s (%d).xrni",
        output_folder, sep, module_name, info.index, sample_name, n)
      n = n + 1
    end
    seen[out_path:lower()] = true

    if skip_existing and io.exists(out_path) then
      skipped = skipped + 1
    else
      if not safeInsertInstrumentAt(song, scratch_index) then
        return written, skipped, "maximum of 255 instruments reached"
      end
      song.selected_instrument_index = scratch_index
      pakettiPreferencesDefaultInstrumentLoader()

      local ins = song.instruments[scratch_index]
      ins.macros_visible = true
      ins.sample_modulation_sets[1].name = "Pitchbend"

      local ok, name_or_err = PakettiMODApplySampleToSlot(ins, 1, info)
      if ok then
        ins.name = name_or_err
        local saved = pcall(function() renoise.app():save_instrument(out_path) end)
        if saved then written = written + 1 end
      end

      -- always drop the scratch slot, saved or not, so a long run never walks
      -- into the 255-instrument ceiling
      if song.instruments[scratch_index] then
        pcall(function() song:delete_instrument_at(scratch_index) end)
      end

      if not ok then
        return written, skipped, tostring(name_or_err)
      end
    end

    coroutine.yield()
  end

  return written, skipped, nil
end

--- Builds a single .xrni holding every sample of an already-parsed module.
--- Same `seen` contract as above. Yields between samples.
--- Returns written_count (0 or 1), skipped_count, error_string_or_nil.
function PakettiMODWriteModuleXRNI(mod, module_name, output_folder, scratch_index, skip_existing, seen)
  seen = seen or {}
  local song = renoise.song()
  local sep = package.config:sub(1, 1)

  local out_path = string.format("%s%s%s.xrni", output_folder, sep, module_name)
  local n = 2
  while seen[out_path:lower()] and n < 1000 do
    out_path = string.format("%s%s%s (%d).xrni", output_folder, sep, module_name, n)
    n = n + 1
  end
  seen[out_path:lower()] = true

  if skip_existing and io.exists(out_path) then
    return 0, 1, nil
  end

  if not safeInsertInstrumentAt(song, scratch_index) then
    return 0, 0, "maximum of 255 instruments reached"
  end
  song.selected_instrument_index = scratch_index
  pakettiPreferencesDefaultInstrumentLoader()

  local ins = song.instruments[scratch_index]
  ins.name = module_name
  ins.macros_visible = true
  ins.sample_modulation_sets[1].name = "Pitchbend"

  local failure = nil
  for slot, info in ipairs(mod.samples) do
    local ok, name_or_err = PakettiMODApplySampleToSlot(ins, slot, info)
    if not ok then
      failure = tostring(name_or_err)
      break
    end
    coroutine.yield()
  end

  local written = 0
  if not failure then
    local saved = pcall(function() renoise.app():save_instrument(out_path) end)
    if saved then written = 1 else failure = "could not write " .. out_path end
  end

  if song.instruments[scratch_index] then
    pcall(function() song:delete_instrument_at(scratch_index) end)
  end

  return written, 0, failure
end

--- Batch driver. Runs on a ProcessSlicer so Renoise stays responsive across
--- hundreds of modules and the run can be cancelled.
--- `per_module` false = one .xrni per sample, true = one .xrni per module.
function PakettiMODBatchConvertToXRNI(source_folder, output_folder, recurse, per_module, skip_existing)
  if not source_folder or source_folder == "" then
    renoise.app():show_status("MOD->XRNI: no source folder selected")
    return
  end

  local mod_files = PakettiMODCollectFiles(source_folder, recurse)
  if #mod_files == 0 then
    renoise.app():show_status("MOD->XRNI: no .mod files found in " .. source_folder)
    return
  end

  print("------------")
  print(string.format("-- MOD->XRNI: found %d .mod files under %s (%s)",
    #mod_files, source_folder, per_module and "one .xrni per module" or "one .xrni per sample"))

  local slicer
  local function worker()
    local dialog, vb = slicer:create_dialog("Converting .MOD to .XRNI")

    local song = renoise.song()
    local original_index = song.selected_instrument_index
    local scratch_index = original_index + 1

    local total_xrni, total_skipped, converted, failed = 0, 0, 0, 0
    local failed_files = {}
    -- output paths claimed during this run
    local seen = {}

    for i, mod_path in ipairs(mod_files) do
      if slicer:was_cancelled() then break end

      local filename = mod_path:match("[^/\\]+$") or mod_path
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "%d/%d  %s\n%d .xrni written so far", i, #mod_files, filename, total_xrni)
      end

      -- "same folder as the .mod" writes beside each module, so a recursive run
      -- keeps the source folder structure instead of flattening it
      local dest = output_folder
      if not dest or dest == "" then
        dest = mod_path:sub(1, #mod_path - #filename - 1)
        if dest == "" then dest = source_folder end
      end

      local data, read_err = PakettiMODParser.read_file(mod_path)
      local mod, parse_err = nil, nil
      if data then mod, parse_err = PakettiMODParser.parse(data) end

      if not mod then
        failed = failed + 1
        local why = tostring(read_err or parse_err)
        table.insert(failed_files, filename .. ": " .. why)
        print(string.format("-- MOD->XRNI: FAILED %s (%s)", filename, why))
      else
        local module_name = pakettiFSPath.sanitize_filename(
          filename:gsub("%.[mM][oO][dD]$", ""):gsub("^[mM][oO][dD]%.", ""), "module")

        local writer = per_module and PakettiMODWriteModuleXRNI or PakettiMODWriteSampleXRNIs
        local ok, written, skipped, err = pcall(writer,
          mod, module_name, dest, scratch_index, skip_existing, seen)

        if not ok then
          failed = failed + 1
          table.insert(failed_files, filename .. ": " .. tostring(written))
          print(string.format("-- MOD->XRNI: FAILED %s (%s)", filename, tostring(written)))
        else
          total_xrni = total_xrni + (written or 0)
          total_skipped = total_skipped + (skipped or 0)
          if err then
            failed = failed + 1
            table.insert(failed_files, filename .. ": " .. tostring(err))
            print(string.format("-- MOD->XRNI: FAILED %s (%s)", filename, tostring(err)))
          else
            converted = converted + 1
            print(string.format("-- MOD->XRNI: %s -> %d .xrni", filename, written or 0))
          end
        end
      end

      coroutine.yield()
    end

    song.selected_instrument_index = math.min(original_index, #song.instruments)

    if dialog and dialog.visible then dialog:close() end

    local summary
    if slicer:was_cancelled() then
      summary = string.format("MOD->XRNI cancelled: %d modules done, %d .xrni written", converted, total_xrni)
    else
      summary = string.format("MOD->XRNI complete: %d modules, %d .xrni written%s%s",
        converted, total_xrni,
        total_skipped > 0 and string.format(", %d skipped", total_skipped) or "",
        failed > 0 and string.format(", %d failed", failed) or "")
    end
    print("-- " .. summary)
    for _, f in ipairs(failed_files) do print("--   failed: " .. f) end
    renoise.app():show_status(summary)
  end

  slicer = ProcessSlicer(worker)
  slicer:start()
end

--------------------------------------------------------------------------------
-- dialog
--------------------------------------------------------------------------------

local mod_to_xrni_dialog = nil

function PakettiMODToXRNIBatchDialog()
  if mod_to_xrni_dialog and mod_to_xrni_dialog.visible then
    mod_to_xrni_dialog:close()
    mod_to_xrni_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

  local function refresh_count()
    local folder = preferences.pakettiMODToXRNISourceFolder.value
    if not folder or folder == "" then
      vb.views.modxrni_count_text.text = "No source folder selected."
      return
    end
    local files = PakettiMODCollectFiles(folder, preferences.pakettiMODToXRNIRecurse.value)
    vb.views.modxrni_count_text.text = string.format("%d .mod file%s found.", #files, #files == 1 and "" or "s")
  end

  local content = vb:column{
    margin = DEFAULT_MARGIN,
    spacing = 4,

    vb:row{
      vb:text{ text = "Source Folder", width = 90 },
      vb:textfield{
        id = "modxrni_source_field",
        width = 420,
        text = preferences.pakettiMODToXRNISourceFolder.value,
        notifier = function(value)
          preferences.pakettiMODToXRNISourceFolder.value = value
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
            preferences.pakettiMODToXRNISourceFolder.value = path
            preferences:save_as("preferences.xml")
            vb.views.modxrni_source_field.text = path
            refresh_count()
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:checkbox{
        value = preferences.pakettiMODToXRNIRecurse.value,
        notifier = function(value)
          preferences.pakettiMODToXRNIRecurse.value = value
          preferences:save_as("preferences.xml")
          refresh_count()
        end
      },
      vb:text{ text = "Include subfolders" },
      vb:checkbox{
        value = preferences.pakettiMODToXRNISkipExisting.value,
        notifier = function(value)
          preferences.pakettiMODToXRNISkipExisting.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:text{ text = "Skip .xrni files that already exist" }
    },

    vb:row{
      vb:text{ text = "Instruments", width = 90 },
      vb:switch{
        id = "modxrni_mode_switch",
        width = 300,
        items = { "One .XRNI per sample", "One .XRNI per module" },
        value = preferences.pakettiMODToXRNIPerModule.value and 2 or 1,
        notifier = function(value)
          preferences.pakettiMODToXRNIPerModule.value = (value == 2)
          preferences:save_as("preferences.xml")
          vb.views.modxrni_naming_text.text = (value == 2)
            and "Output filenames: modulename.xrni (all samples in one instrument)"
            or  "Output filenames: modulename-NN-samplename.xrni"
        end
      }
    },

    vb:row{
      vb:text{ text = "Write .XRNI to", width = 90 },
      vb:switch{
        id = "modxrni_output_switch",
        width = 300,
        items = { "Same folder as .MOD", "Separate folder" },
        value = preferences.pakettiMODToXRNISeparateOutput.value and 2 or 1,
        notifier = function(value)
          preferences.pakettiMODToXRNISeparateOutput.value = (value == 2)
          preferences:save_as("preferences.xml")
        end
      }
    },

    vb:row{
      vb:text{ text = "Output Folder", width = 90 },
      vb:textfield{
        id = "modxrni_output_field",
        width = 420,
        text = preferences.pakettiMODToXRNIOutputFolder.value,
        notifier = function(value)
          preferences.pakettiMODToXRNIOutputFolder.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function()
          local path = renoise.app():prompt_for_path("Select folder to write .XRNI files into")
          if path and path ~= "" then
            preferences.pakettiMODToXRNIOutputFolder.value = path
            preferences.pakettiMODToXRNISeparateOutput.value = true
            preferences:save_as("preferences.xml")
            vb.views.modxrni_output_field.text = path
            vb.views.modxrni_output_switch.value = 2
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ id = "modxrni_count_text", text = "No source folder selected.", width = 420 }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{
        id = "modxrni_naming_text",
        width = 480,
        text = preferences.pakettiMODToXRNIPerModule.value
          and "Output filenames: modulename.xrni (all samples in one instrument)"
          or  "Output filenames: modulename-NN-samplename.xrni"
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ text = "Paketti default instrument, loader preferences and the module's loop points are applied.", width = 480 }
    },

    vb:row{
      vb:button{
        text = "Convert",
        width = 120,
        notifier = function()
          local source = preferences.pakettiMODToXRNISourceFolder.value
          if not source or source == "" then
            renoise.app():show_status("MOD->XRNI: select a source folder first")
            return
          end
          local output = nil
          if preferences.pakettiMODToXRNISeparateOutput.value then
            output = preferences.pakettiMODToXRNIOutputFolder.value
            if not output or output == "" then
              renoise.app():show_status("MOD->XRNI: select an output folder, or switch to \"Same folder as .MOD\"")
              return
            end
          end
          if mod_to_xrni_dialog and mod_to_xrni_dialog.visible then
            mod_to_xrni_dialog:close()
            mod_to_xrni_dialog = nil
          end
          PakettiMODBatchConvertToXRNI(
            source, output,
            preferences.pakettiMODToXRNIRecurse.value,
            preferences.pakettiMODToXRNIPerModule.value,
            preferences.pakettiMODToXRNISkipExisting.value)
        end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if mod_to_xrni_dialog and mod_to_xrni_dialog.visible then
            mod_to_xrni_dialog:close()
          end
          mod_to_xrni_dialog = nil
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return mod_to_xrni_dialog end,
    function(value) mod_to_xrni_dialog = value end
  )
  mod_to_xrni_dialog = renoise.app():show_custom_dialog(
    "Batch Convert .MOD to .XRNI", content, keyhandler)

  refresh_count()
end

--------------------------------------------------------------------------------
-- registrations (always last — every function above is already defined)
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Batch Convert .MOD to .XRNI...",invoke=function() PakettiMODToXRNIBatchDialog() end}
PakettiAddMenuEntry{name="--Main Menu:File:Paketti Import:Batch Convert .MOD to .XRNI...",invoke=function() PakettiMODToXRNIBatchDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Load:Batch Convert .MOD to .XRNI...",invoke=function() PakettiMODToXRNIBatchDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Batch Convert .MOD to .XRNI...",invoke=function() PakettiMODToXRNIBatchDialog() end}
PakettiAddMenuEntry{name="Disk Browser Files:Paketti:Import/Export:Batch Convert .MOD to .XRNI...",invoke=function() PakettiMODToXRNIBatchDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Batch Convert .MOD to .XRNI",invoke=function() PakettiMODToXRNIBatchDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Convert .MOD to .XRNI",invoke=function(message) if message:is_trigger() then PakettiMODToXRNIBatchDialog() end end}
