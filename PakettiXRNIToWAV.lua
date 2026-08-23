--[[============================================================================
PakettiXRNIToWAV.lua — Batch convert a folder of .xrni instruments to .wav

Companion to the batch .MOD -> .WAV converter in PakettiMODLoader.lua, same
shape and same output naming:

    <instrumentname>-<NN>-<samplename>.wav

Point it at a folder of .xrni files and every sample of every instrument comes
out as its own .wav. Unlike the .MOD converter this one has to go through
Renoise: .xrni is a zip archive whose audio may be FLAC, so each instrument is
loaded into a temporary instrument slot, its sample buffers are written out with
SampleBuffer:save_as(), and the temporary slot is deleted again. The user's own
instruments are left where they were and the selected instrument is restored
when the run finishes.

Helpers are declared above their callers and all registrations sit at the bottom
of the file, after the functions they name (skill rules 18 and 28).
============================================================================]]--

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function paketti_xrni_is_xrni_filename(filename)
  return filename:lower():match("%.xrni$") ~= nil
end

-- Filesystem-safe instrument name taken from the .xrni filename.
local function paketti_xrni_instrument_basename(filename)
  local base = filename:gsub("%.[xX][rR][nN][iI]$", "")
  return pakettiFSPath.sanitize_filename(base, "instrument")
end

--- Collects .xrni files under a folder, optionally recursing.
function PakettiXRNICollectFiles(folder, recurse)
  return pakettiFSPath.collect_files(folder, recurse, paketti_xrni_is_xrni_filename)
end

--------------------------------------------------------------------------------
-- conversion
--------------------------------------------------------------------------------

--- Writes every sample of an already-loaded instrument out as .wav.
--- `seen` is the shared set of output paths claimed during this run, so two
--- instruments sharing a filename (different subfolders, one output folder) get
--- suffixed apart while a re-run still overwrites its own previous output.
--- Yields between samples, so this must be called from inside a ProcessSlicer.
--- Returns written_count, skipped_count, error_string_or_nil.
function PakettiXRNIWriteInstrumentSamples(instrument, instrument_name, output_folder, skip_existing, seen)
  seen = seen or {}
  local sep = package.config:sub(1, 1)
  local written, skipped = 0, 0

  for sample_index = 1, #instrument.samples do
    local sample = instrument.samples[sample_index]
    local buffer = sample.sample_buffer

    if not buffer or not buffer.has_sample_data then
      -- an empty slot carries no audio to write
      skipped = skipped + 1
    else
      local sample_name = pakettiFSPath.sanitize_filename(
        pakettiFSPath.strip_audio_extension(sample.name), "untitled")
      local out_path = string.format("%s%s%s-%02d-%s.wav",
        output_folder, sep, instrument_name, sample_index, sample_name)

      local n = 2
      while seen[out_path:lower()] and n < 1000 do
        out_path = string.format("%s%s%s-%02d-%s (%d).wav",
          output_folder, sep, instrument_name, sample_index, sample_name, n)
        n = n + 1
      end
      seen[out_path:lower()] = true

      if skip_existing and io.exists(out_path) then
        skipped = skipped + 1
      else
        local ok, saved = pcall(function() return buffer:save_as(out_path, "wav") end)
        if ok and saved then
          written = written + 1
        else
          return written, skipped, string.format("could not write %s", out_path)
        end
      end
    end

    coroutine.yield()
  end

  return written, skipped, nil
end

--- Batch driver. Loads each .xrni into a scratch instrument slot, exports its
--- samples and deletes the slot again, all on a ProcessSlicer so Renoise stays
--- responsive and the run can be cancelled.
function PakettiXRNIBatchConvertToWAV(source_folder, output_folder, recurse, skip_existing)
  if not source_folder or source_folder == "" then
    renoise.app():show_status("XRNI->WAV: no source folder selected")
    return
  end

  local xrni_files = PakettiXRNICollectFiles(source_folder, recurse)
  if #xrni_files == 0 then
    renoise.app():show_status("XRNI->WAV: no .xrni files found in " .. source_folder)
    return
  end

  print("------------")
  print(string.format("-- XRNI->WAV: found %d .xrni files under %s", #xrni_files, source_folder))

  local slicer
  local function worker()
    local dialog, vb = slicer:create_dialog("Converting .XRNI to .WAV")

    local song = renoise.song()
    local original_index = song.selected_instrument_index
    local scratch_index = original_index + 1

    local total_wavs, total_skipped, converted, failed = 0, 0, 0, 0
    local failed_files = {}
    -- output paths claimed during this run
    local seen = {}

    for i, xrni_path in ipairs(xrni_files) do
      if slicer:was_cancelled() then break end

      local filename = xrni_path:match("[^/\\]+$") or xrni_path
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format(
          "%d/%d  %s\n%d .wav written so far", i, #xrni_files, filename, total_wavs)
      end

      -- "same folder as the .xrni" writes beside each instrument, so a
      -- recursive run keeps the source folder structure instead of flattening it
      local dest = output_folder
      if not dest or dest == "" then
        dest = xrni_path:sub(1, #xrni_path - #filename - 1)
        if dest == "" then dest = source_folder end
      end

      local loaded = false
      local load_ok, load_err = pcall(function()
        if not safeInsertInstrumentAt(song, scratch_index) then
          error("maximum of 255 instruments reached")
        end
        loaded = true
        song.selected_instrument_index = scratch_index
        renoise.app():load_instrument(xrni_path)
      end)

      if not load_ok then
        failed = failed + 1
        table.insert(failed_files, filename .. ": " .. tostring(load_err))
        print(string.format("-- XRNI->WAV: FAILED to load %s (%s)", filename, tostring(load_err)))
      else
        local instrument_name = paketti_xrni_instrument_basename(filename)
        local ok, written, skipped, err = pcall(PakettiXRNIWriteInstrumentSamples,
          song.instruments[scratch_index], instrument_name, dest, skip_existing, seen)

        if not ok then
          failed = failed + 1
          table.insert(failed_files, filename .. ": " .. tostring(written))
          print(string.format("-- XRNI->WAV: FAILED %s (%s)", filename, tostring(written)))
        else
          total_wavs = total_wavs + (written or 0)
          total_skipped = total_skipped + (skipped or 0)
          if err then
            failed = failed + 1
            table.insert(failed_files, filename .. ": " .. tostring(err))
            print(string.format("-- XRNI->WAV: FAILED %s (%s)", filename, tostring(err)))
          else
            converted = converted + 1
            print(string.format("-- XRNI->WAV: %s -> %d .wav", filename, written or 0))
          end
        end
      end

      -- always drop the scratch slot again, success or failure, so a long run
      -- never walks into the 255-instrument ceiling
      if loaded and song.instruments[scratch_index] then
        pcall(function() song:delete_instrument_at(scratch_index) end)
      end

      coroutine.yield()
    end

    song.selected_instrument_index = math.min(original_index, #song.instruments)

    if dialog and dialog.visible then dialog:close() end

    local summary
    if slicer:was_cancelled() then
      summary = string.format("XRNI->WAV cancelled: %d instruments done, %d .wav written", converted, total_wavs)
    else
      summary = string.format("XRNI->WAV complete: %d instruments, %d .wav written%s%s",
        converted, total_wavs,
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

local xrni_to_wav_dialog = nil

function PakettiXRNIToWAVBatchDialog()
  if xrni_to_wav_dialog and xrni_to_wav_dialog.visible then
    xrni_to_wav_dialog:close()
    xrni_to_wav_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN

  local function refresh_count()
    local folder = preferences.pakettiXRNIToWAVSourceFolder.value
    if not folder or folder == "" then
      vb.views.xrni_count_text.text = "No source folder selected."
      return
    end
    local files = PakettiXRNICollectFiles(folder, preferences.pakettiXRNIToWAVRecurse.value)
    vb.views.xrni_count_text.text = string.format("%d .xrni file%s found.", #files, #files == 1 and "" or "s")
  end

  local content = vb:column{
    margin = DEFAULT_MARGIN,
    spacing = 4,

    vb:row{
      vb:text{ text = "Source Folder", width = 90 },
      vb:textfield{
        id = "xrni_source_field",
        width = 420,
        text = preferences.pakettiXRNIToWAVSourceFolder.value,
        notifier = function(value)
          preferences.pakettiXRNIToWAVSourceFolder.value = value
          preferences:save_as("preferences.xml")
          refresh_count()
        end
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function()
          local path = renoise.app():prompt_for_path("Select folder of .XRNI files")
          if path and path ~= "" then
            preferences.pakettiXRNIToWAVSourceFolder.value = path
            preferences:save_as("preferences.xml")
            vb.views.xrni_source_field.text = path
            refresh_count()
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:checkbox{
        value = preferences.pakettiXRNIToWAVRecurse.value,
        notifier = function(value)
          preferences.pakettiXRNIToWAVRecurse.value = value
          preferences:save_as("preferences.xml")
          refresh_count()
        end
      },
      vb:text{ text = "Include subfolders" },
      vb:checkbox{
        value = preferences.pakettiXRNIToWAVSkipExisting.value,
        notifier = function(value)
          preferences.pakettiXRNIToWAVSkipExisting.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:text{ text = "Skip .wav files that already exist" }
    },

    vb:row{
      vb:text{ text = "Write .WAV to", width = 90 },
      vb:switch{
        id = "xrni_output_switch",
        width = 260,
        items = { "Same folder as .XRNI", "Separate folder" },
        value = preferences.pakettiXRNIToWAVSeparateOutput.value and 2 or 1,
        notifier = function(value)
          preferences.pakettiXRNIToWAVSeparateOutput.value = (value == 2)
          preferences:save_as("preferences.xml")
        end
      }
    },

    vb:row{
      vb:text{ text = "Output Folder", width = 90 },
      vb:textfield{
        id = "xrni_output_field",
        width = 420,
        text = preferences.pakettiXRNIToWAVOutputFolder.value,
        notifier = function(value)
          preferences.pakettiXRNIToWAVOutputFolder.value = value
          preferences:save_as("preferences.xml")
        end
      },
      vb:button{
        text = "Browse",
        width = 70,
        notifier = function()
          local path = renoise.app():prompt_for_path("Select folder to write .WAV files into")
          if path and path ~= "" then
            preferences.pakettiXRNIToWAVOutputFolder.value = path
            preferences.pakettiXRNIToWAVSeparateOutput.value = true
            preferences:save_as("preferences.xml")
            vb.views.xrni_output_field.text = path
            vb.views.xrni_output_switch.value = 2
          end
        end
      }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ id = "xrni_count_text", text = "No source folder selected.", width = 420 }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ text = "Output filenames: instrumentname-NN-samplename.wav", width = 420 }
    },

    vb:row{
      vb:text{ text = "", width = 90 },
      vb:text{ text = "Each .xrni is loaded into a temporary instrument slot and removed again.", width = 480 }
    },

    vb:row{
      vb:button{
        text = "Convert",
        width = 120,
        notifier = function()
          local source = preferences.pakettiXRNIToWAVSourceFolder.value
          if not source or source == "" then
            renoise.app():show_status("XRNI->WAV: select a source folder first")
            return
          end
          local output = nil
          if preferences.pakettiXRNIToWAVSeparateOutput.value then
            output = preferences.pakettiXRNIToWAVOutputFolder.value
            if not output or output == "" then
              renoise.app():show_status("XRNI->WAV: select an output folder, or switch to \"Same folder as .XRNI\"")
              return
            end
          end
          if xrni_to_wav_dialog and xrni_to_wav_dialog.visible then
            xrni_to_wav_dialog:close()
            xrni_to_wav_dialog = nil
          end
          PakettiXRNIBatchConvertToWAV(
            source, output,
            preferences.pakettiXRNIToWAVRecurse.value,
            preferences.pakettiXRNIToWAVSkipExisting.value)
        end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if xrni_to_wav_dialog and xrni_to_wav_dialog.visible then
            xrni_to_wav_dialog:close()
          end
          xrni_to_wav_dialog = nil
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return xrni_to_wav_dialog end,
    function(value) xrni_to_wav_dialog = value end
  )
  xrni_to_wav_dialog = renoise.app():show_custom_dialog(
    "Batch Convert .XRNI to .WAV", content, keyhandler)

  refresh_count()
end

--------------------------------------------------------------------------------
-- registrations (always last — every function above is already defined)
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Batch Convert .XRNI to .WAV...",invoke=function() PakettiXRNIToWAVBatchDialog() end}
PakettiAddMenuEntry{name="--Main Menu:File:Paketti Import:Batch Convert .XRNI to .WAV...",invoke=function() PakettiXRNIToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Load:Batch Convert .XRNI to .WAV...",invoke=function() PakettiXRNIToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Batch Convert .XRNI to .WAV...",invoke=function() PakettiXRNIToWAVBatchDialog() end}
PakettiAddMenuEntry{name="Disk Browser Files:Paketti:Import/Export:Batch Convert .XRNI to .WAV...",invoke=function() PakettiXRNIToWAVBatchDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Batch Convert .XRNI to .WAV",invoke=function() PakettiXRNIToWAVBatchDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Batch Convert .XRNI to .WAV",invoke=function(message) if message:is_trigger() then PakettiXRNIToWAVBatchDialog() end end}
