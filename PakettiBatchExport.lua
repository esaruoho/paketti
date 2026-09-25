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
-- Runs the whole batch inside a ProcessSlicer so Renoise stays responsive:
-- exporting a folder of long samples (ITI especially) otherwise blocks the UI
-- long enough for Renoise to offer to terminate the script.
function PakettiBatchXRNIExportRun(cfg)
  -- The folder picker runs here, on the main thread. Showing a modal file
  -- dialog from inside the ProcessSlicer's idle-driven coroutine is asking for
  -- trouble, so only the export loop goes in the coroutine.
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

  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    PakettiBatchXRNIExportWorker(cfg, parent, xrni_files, function(text)
      if vb and vb.views and vb.views.progress_text then vb.views.progress_text.text = text end
    end)
    if dialog and dialog.visible then dialog:close() end
  end)
  dialog, vb = slicer:create_dialog("Batch XRNI -> " .. tostring(cfg.label) .. "...")
  slicer:start()
end

function PakettiBatchXRNIExportWorker(cfg, parent, xrni_files, report)
  local song = renoise.song()

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
    if report then report(string.format("%d/%d - %s", i, #xrni_files, xrni_path:match("([^/\\]+)$") or "")) end
    coroutine.yield()
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
    -- iti_export_instrument yields on its own when it is running inside a
    -- coroutine, which keeps Renoise responsive on long samples
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

--------------------------------------------------------------------------------
-- BATCH .PTI FOLDER -> .WAV (with M8-safe embedded CUE headers)
--
-- Throw a folder of .pti files at this and get a .wav beside each one, carrying
-- the PTI's slice markers as WAV cue points in the layout the Dirtywave M8 will
-- load (fmt -> LIST/adtl -> data -> cue). This is the ".pti to .m8" conversion.
--
-- Each .pti is imported with the real loader (pti_loadsample_Worker, run
-- synchronously by passing no dialog), the base sample (samples[1], which holds
-- the slice markers) is written with sample_buffer:save_as, then rewritten by
-- PakettiWavCueWriteCueChunksToWav (both from PakettiWavCueExtract.lua) so the
-- chunk order is M8-safe. The temp instrument is deleted after each file so we
-- never pile up or hit the 255-instrument cap. Whole batch runs in a
-- ProcessSlicer so Renoise stays responsive.
--------------------------------------------------------------------------------
function PakettiCollectPTIFilesRecursive(folder)
  local results = {}
  local sep = package.config:sub(1, 1)

  local ok_files, files = pcall(os.filenames, folder, "*.pti")
  if ok_files and files then
    for _, fn in ipairs(files) do
      table.insert(results, folder .. sep .. fn)
    end
  end

  local ok_dirs, dirs = pcall(os.dirnames, folder)
  if ok_dirs and dirs then
    for _, d in ipairs(dirs) do
      if not d:match("^%.") then
        local sub_results = PakettiCollectPTIFilesRecursive(folder .. sep .. d)
        for _, p in ipairs(sub_results) do
          table.insert(results, p)
        end
      end
    end
  end

  return results
end

-- Pure-binary PTI reader. Does NOT create an instrument, load a plugin, or
-- touch the song - so it can never spin up the default-instrument template
-- (Amigo etc.). Mirrors PakettiPTILoader.lua's parse: sample_length at header
-- offset 60, slice_count at 376, slice offsets at 280+i*2 (uint16, normalized
-- to 0..65535 over the sample length), PCM after the 392-byte header (mono =
-- 16-bit LE; stereo = planar L block then R block). Returns a table describing
-- the WAV to write, or nil + error string.
function PakettiPTIReadForWav(pti_path)
  local f, oerr = io.open(pti_path, "rb")
  if not f then return nil, "cannot open: " .. tostring(oerr) end
  local header = f:read(392)
  if not header or #header < 392 then f:close() return nil, "header too short (not a PTI?)" end
  local pcm = f:read("*a") or ""
  f:close()

  local function u16(off) -- 0-based, matches read_uint16_le
    local a, b = header:byte(off + 1), header:byte(off + 2)
    if not a or not b then return 0 end
    return a + b * 256
  end
  local function u32(off)
    local a, b, c, d = header:byte(off + 1), header:byte(off + 2), header:byte(off + 3), header:byte(off + 4)
    if not (a and b and c and d) then return 0 end
    return a + b * 256 + c * 65536 + d * 16777216
  end

  local sample_length = u32(60)
  if sample_length == 0 then return nil, "sample has 0 frames" end

  local mono_bytes = sample_length * 2
  local stereo_bytes = sample_length * 4
  -- Same stereo detection as the loader (>= stereo_bytes means two planar blocks).
  local is_stereo = #pcm >= stereo_bytes
  local channels = is_stereo and 2 or 1

  -- The loader tolerates a PCM block a few bytes short by zero-filling the tail
  -- (pcm:byte(x) or 0); some real/fixture PTIs are a handful of frames short of
  -- their declared sample_length. Match that leniency instead of failing.
  local need = is_stereo and stereo_bytes or mono_bytes
  if #pcm < need then
    pcm = pcm .. string.rep(string.char(0), need - #pcm)
  end

  -- Interleave data for the WAV data chunk.
  local data
  if is_stereo then
    local left = pcm:sub(1, mono_bytes)
    local right = pcm:sub(mono_bytes + 1, stereo_bytes)
    local parts = {}
    for i = 1, sample_length do
      local o = (i - 1) * 2 + 1
      parts[i] = left:sub(o, o + 1) .. right:sub(o, o + 1)
    end
    data = table.concat(parts)
  else
    data = pcm:sub(1, mono_bytes)
  end

  -- Slice markers -> 1-based Renoise-style frame positions (frame+1), exactly
  -- as PakettiPTILoader inserts them, so the cue offsets match the loader path.
  local slice_count = header:byte(377) or 0
  local markers = {}
  for i = 0, slice_count - 1 do
    local raw = u16(280 + i * 2)
    local frame = math.floor((raw / 65535) * sample_length)
    markers[#markers + 1] = frame + 1
  end
  table.sort(markers)

  return {
    sample_rate = 44100,     -- PTI is always 44100 (matches the loader)
    channels = channels,
    data = data,
    markers = markers,
    name = get_clean_filename(pti_path),
  }
end

-- Write a parsed PTI as a WAV in the M8-safe layout: fmt -> LIST/adtl -> data
-- -> cue. Reuses the cue/label chunk builders from PakettiWavCueExtract.lua.
function PakettiWritePTIAsWavCue(pti_path, wav_path)
  local info, err = PakettiPTIReadForWav(pti_path)
  if not info then return false, err end

  local u16, u32 = PakettiWavCueWriteU16LE, PakettiWavCueWriteU32LE
  local byte_rate = info.sample_rate * info.channels * 2
  local block_align = info.channels * 2
  local fmt = u16(1) .. u16(info.channels) .. u32(info.sample_rate)
    .. u32(byte_rate) .. u16(block_align) .. u16(16)
  local fmt_chunk = "fmt " .. u32(#fmt) .. fmt

  local data_chunk = "data" .. u32(#info.data) .. info.data
  if (#info.data % 2) == 1 then data_chunk = data_chunk .. string.char(0) end

  local cue_chunk = (#info.markers > 0)
    and PakettiWavCueBuildCueChunk(info.markers, info.sample_rate) or nil
  local adtl_chunk = (#info.markers > 0)
    and PakettiWavCueBuildAdtlChunk(info.name, info.markers) or nil

  local body = fmt_chunk
  if adtl_chunk then body = body .. adtl_chunk end
  body = body .. data_chunk
  if cue_chunk then body = body .. cue_chunk end

  local wav = "RIFF" .. u32(#body + 4) .. "WAVE" .. body

  local f, werr = io.open(wav_path, "wb")
  if not f then return false, "cannot write: " .. tostring(werr) end
  f:write(wav)
  f:close()

  return true, #info.markers
end

function PakettiBatchPTIToWavCueWorker(parent, pti_files, report)
  print("------------")
  print(string.format("-- Batch PTI->WAV+CUE: Found %d .pti files under %s", #pti_files, parent))

  local done = 0
  local failed = 0
  local total_cues = 0
  local failures = {}

  for i, pti_path in ipairs(pti_files) do
    local wav_path = pti_path:gsub("%.[pP][tT][iI]$", ".wav")
    if wav_path == pti_path then wav_path = pti_path .. ".wav" end

    local ok, res = PakettiWritePTIAsWavCue(pti_path, wav_path)
    if ok then
      done = done + 1
      local ncues = (res > 0) and (res + 1) or 0  -- +1 implicit marker at frame 1
      total_cues = total_cues + ncues
      print(string.format("-- [%d/%d] %s -> %s (%s cues)",
        i, #pti_files, pti_path, wav_path, ncues > 0 and tostring(ncues) or "no"))
    else
      failed = failed + 1
      table.insert(failures, pti_path .. " (" .. tostring(res) .. ")")
      print(string.format("-- [%d/%d] FAILED %s: %s", i, #pti_files, pti_path, tostring(res)))
    end

    renoise.app():show_status(string.format("Batch PTI->WAV+CUE: %d/%d done...", done, #pti_files))
    if report then report(string.format("%d/%d - %s", i, #pti_files, pti_path:match("([^/\\]+)$") or "")) end
    coroutine.yield()
  end

  local msg = string.format("Batch PTI->WAV+CUE complete: %d/%d files, %d cue points total",
    done, #pti_files, total_cues)
  if failed > 0 then msg = msg .. string.format(" (%d failed)", failed) end
  renoise.app():show_status(msg)
  print("-- " .. msg)
  if failed > 0 then
    print("-- Batch PTI->WAV+CUE failures:")
    for _, f in ipairs(failures) do print("   - " .. f) end
  end
  print("------------")
end

function PakettiBatchPTIToWavCue()
  local parent_folder = renoise.app():prompt_for_path(
    "Select folder of .pti files to batch-convert to .wav with CUE (recurses subfolders)")
  if not parent_folder or parent_folder == "" then
    renoise.app():show_status("Batch PTI->WAV+CUE: No folder selected")
    return
  end

  local pti_files = PakettiCollectPTIFilesRecursive(parent_folder)
  if #pti_files == 0 then
    renoise.app():show_status("Batch PTI->WAV+CUE: No .pti files found in folder or subfolders")
    return
  end

  table.sort(pti_files, function(a, b) return a:lower() < b:lower() end)

  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    PakettiBatchPTIToWavCueWorker(parent_folder, pti_files, function(text)
      if dialog and dialog.visible and vb and vb.views.progress_text then
        vb.views.progress_text.text = text
      end
    end)
    if dialog and dialog.visible then dialog:close() end
  end)
  dialog, vb = slicer:create_dialog("Batch PTI -> WAV+CUE...")
  slicer:start()
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

-- .PTI folder -> .WAV (M8-safe embedded CUE) batch
renoise.tool():add_keybinding{ name = "Global:Paketti:Batch Convert PTI Folder to WAV with CUE",
  invoke = PakettiBatchPTIToWavCue }
renoise.tool():add_midi_mapping{ name = "Paketti:Batch Convert PTI Folder to WAV with CUE",
  invoke = function(message) if message:is_trigger() then PakettiBatchPTIToWavCue() end end }
PakettiAddMenuEntry{ name = "Main Menu:File:Paketti Export:Batch Convert PTI Folder to WAV with CUE...",
  invoke = PakettiBatchPTIToWavCue }
PakettiAddMenuEntry{ name = "Disk Browser:Paketti:Import/Export:Batch Convert PTI Folder to WAV with CUE...",
  invoke = PakettiBatchPTIToWavCue }
PakettiAddMenuEntry{ name = "Instrument Box:Paketti:Import/Export:Batch Convert PTI Folder to WAV with CUE...",
  invoke = PakettiBatchPTIToWavCue }
