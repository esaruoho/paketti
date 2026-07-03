-- PakettiBatchExport.lua
-- Batch "folder of .xrni -> hardware format" converters.
--
-- Same chassis as PakettiBatchXRNIToPTI (PakettiPTILoader.lua): pick a folder,
-- recursively walk it for .xrni, load each into a temp instrument, run a per-file
-- exporter that writes IN PLACE (right beside the source .xrni so folder structure
-- is preserved), then delete the temp instrument so Renoise's 255-instrument cap is
-- never hit no matter how many hundreds you convert.
--
-- No exporter is duplicated - each adapter calls the existing, shipped single-file
-- exporter (saveCurrentSampleAs8SVX/16SV/IFF, iti_export_instrument, PakettiOTExport,
-- export_digitakt_chain), which were given an optional output-path argument so batch
-- mode can skip their interactive Save dialog.
--
-- Reuses PakettiCollectXRNIFilesRecursive (defined in PakettiPTILoader.lua).

-- Generic driver. cfg = { label = "8SVX", export = function(inst, base_no_ext) -> files_written }
function PakettiBatchXRNIExportRun(cfg)
  local song = renoise.song()

  local parent = renoise.app():prompt_for_path(
    "Select folder of .xrni to batch-export to " .. cfg.label .. " (recurses subfolders)")
  if not parent or parent == "" then
    renoise.app():show_status("Batch XRNI->" .. cfg.label .. ": No folder selected")
    return
  end

  if type(PakettiCollectXRNIFilesRecursive) ~= "function" then
    renoise.app():show_status("Batch XRNI->" .. cfg.label .. ": PTI loader not available")
    return
  end

  local xrni_files = PakettiCollectXRNIFilesRecursive(parent)
  if #xrni_files == 0 then
    renoise.app():show_status("Batch XRNI->" .. cfg.label .. ": No .xrni files found in folder or subfolders")
    return
  end

  table.sort(xrni_files, function(a, b) return a:lower() < b:lower() end)

  print("------------")
  print(string.format("-- Batch XRNI->%s: Found %d .xrni files under %s", cfg.label, #xrni_files, parent))

  local done = 0
  local failed = 0
  local files_written = 0
  local failures = {}

  for i, xrni_path in ipairs(xrni_files) do
    local base = xrni_path:gsub("%.[xX][rR][nN][iI]$", "")

    local load_ok, load_err = pcall(function()
      if not safeInsertInstrumentAt(song, song.selected_instrument_index + 1) then
        error("maximum of 255 instruments reached")
      end
      song.selected_instrument_index = song.selected_instrument_index + 1
      renoise.app():load_instrument(xrni_path)
    end)

    if load_ok then
      local inst = song.selected_instrument
      local exp_ok, n = pcall(cfg.export, inst, base)

      -- Remove the temp instrument so we never pile up / hit the 255 cap
      pcall(function()
        if #song.instruments > 1 then
          song:delete_instrument_at(song.selected_instrument_index)
        end
      end)

      if exp_ok then
        done = done + 1
        files_written = files_written + (tonumber(n) or 1)
        print(string.format("-- [%d/%d] %s -> %s.* (%s)", i, #xrni_files, xrni_path, base, cfg.label))
      else
        failed = failed + 1
        table.insert(failures, xrni_path .. " (" .. tostring(n) .. ")")
        print(string.format("-- [%d/%d] EXPORT FAILED %s: %s", i, #xrni_files, xrni_path, tostring(n)))
      end
    else
      failed = failed + 1
      table.insert(failures, xrni_path .. " (" .. tostring(load_err) .. ")")
      print(string.format("-- [%d/%d] LOAD FAILED %s: %s", i, #xrni_files, xrni_path, tostring(load_err)))
      if tostring(load_err):match("maximum of 255") then
        renoise.app():show_status("Batch XRNI->" .. cfg.label .. ": Hit 255-instrument cap - stopping")
        break
      end
    end

    renoise.app():show_status(string.format("Batch XRNI->%s: %d/%d done...", cfg.label, done, #xrni_files))
  end

  local msg = string.format("Batch XRNI->%s complete: %d/%d instruments, %d files written",
    cfg.label, done, #xrni_files, files_written)
  if failed > 0 then msg = msg .. string.format(" (%d failed)", failed) end
  renoise.app():show_status(msg)
  print("-- " .. msg)
  if failed > 0 then
    print("-- Batch XRNI->" .. cfg.label .. " failures:")
    for _, f in ipairs(failures) do print("   - " .. f) end
  end
  print("------------")
end

-- Sample-format helper: export every sample in the instrument. Single-sample
-- instruments write <base>.<ext>; multi-sample write <base>-NN.<ext>.
function PakettiBatchExportEachSample(inst, base, saver, ext)
  local song = renoise.song()
  local n = 0
  local nsamp = #inst.samples
  for s = 1, nsamp do
    local smp = inst.samples[s]
    if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
      song.selected_sample_index = s
      local path = (nsamp == 1) and (base .. "." .. ext)
                                or (string.format("%s-%02d.%s", base, s, ext))
      saver(path)
      n = n + 1
    end
  end
  return n
end

-- ── Per-format entry points ─────────────────────────────────────────────
-- WAV with CUE points. Renoise's sample_buffer:save_as(path, "wav") natively
-- embeds the sample's slice markers as standard WAV CUE points (verified: 4
-- slice markers -> 4 cues at exact frame positions), so no separate cue writer
-- is needed - and adding one would duplicate the first marker. One WAV per sample.
function PakettiBatchXRNIToWAV()
  PakettiBatchXRNIExportRun{ label = "WAV (with CUE)", export = function(inst, base)
    local song = renoise.song()
    local n = 0
    local nsamp = #inst.samples
    for s = 1, nsamp do
      local smp = inst.samples[s]
      if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
        song.selected_sample_index = s
        local path = (nsamp == 1) and (base .. ".wav")
                                  or (string.format("%s-%02d.wav", base, s))
        smp.sample_buffer:save_as(path, "wav")
        n = n + 1
      end
    end
    return n
  end }
end

function PakettiBatchXRNITo8SVX()
  PakettiBatchXRNIExportRun{ label = "8SVX", export = function(inst, base)
    return PakettiBatchExportEachSample(inst, base, saveCurrentSampleAs8SVX, "8svx")
  end }
end

function PakettiBatchXRNITo16SV()
  PakettiBatchXRNIExportRun{ label = "16SV", export = function(inst, base)
    return PakettiBatchExportEachSample(inst, base, saveCurrentSampleAs16SV, "16sv")
  end }
end

function PakettiBatchXRNIToIFF()
  PakettiBatchXRNIExportRun{ label = "IFF", export = function(inst, base)
    return PakettiBatchExportEachSample(inst, base, saveCurrentSampleAsIFF, "iff")
  end }
end

function PakettiBatchXRNIToITI()
  PakettiBatchXRNIExportRun{ label = "ITI", export = function(inst, base)
    local ok = iti_export_instrument(inst, base .. ".iti")
    return ok and 1 or 0
  end }
end

function PakettiBatchXRNIToOctatrack()
  PakettiBatchXRNIExportRun{ label = "Octatrack", export = function(inst, base)
    -- Octatrack export works on the selected (sliced) sample -> base.wav + base.ot
    renoise.song().selected_sample_index = 1
    PakettiOTExport(base .. ".wav")
    return 1
  end }
end

function PakettiBatchXRNIToDigitaktChain()
  PakettiBatchXRNIExportRun{ label = "Digitakt Chain", export = function(inst, base)
    local params = {
      digitakt_version = "digitakt2",
      export_mode = "chain",
      slot_count = nil,
      mono_method = "average",
      apply_fadeout = true,
      apply_dither = false,
      pad_with_zero = false,
      output_path = base .. ".wav",
    }
    local ok = export_digitakt_chain(params)
    return ok and 1 or 0
  end }
end

-- ── Registrations ───────────────────────────────────────────────────────
local batch_export_formats = {
  { fmt = "WAV (with CUE)",    fn = PakettiBatchXRNIToWAV },
  { fmt = "8SVX",              fn = PakettiBatchXRNITo8SVX },
  { fmt = "16SV",              fn = PakettiBatchXRNITo16SV },
  { fmt = "IFF",               fn = PakettiBatchXRNIToIFF },
  { fmt = "Octatrack (WAV+.ot)", fn = PakettiBatchXRNIToOctatrack },
  { fmt = "ITI",               fn = PakettiBatchXRNIToITI },
  { fmt = "Digitakt Chain",    fn = PakettiBatchXRNIToDigitaktChain },
}

for _, e in ipairs(batch_export_formats) do
  local kb_name = "Global:Paketti:Batch Convert XRNI Folder to " .. e.fmt
  renoise.tool():add_keybinding{ name = kb_name, invoke = e.fn }
  renoise.tool():add_midi_mapping{ name = "Paketti:Batch Convert XRNI Folder to " .. e.fmt,
    invoke = function(message) if message:is_trigger() then e.fn() end end }
  PakettiAddMenuEntry{ name = "Main Menu:File:Paketti Export:Batch Convert XRNI Folder to " .. e.fmt .. "...",
    invoke = e.fn }
  PakettiAddMenuEntry{ name = "Disk Browser:Paketti:Import/Export:Batch Convert XRNI Folder to " .. e.fmt .. "...",
    invoke = e.fn }
end
