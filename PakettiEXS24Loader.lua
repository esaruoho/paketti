--[[============================================================================
PakettiEXS24Loader.lua — Logic EXS24 sampler instrument (.exs) importer

Registers as a Renoise instrument-category file_import_hook (see
PakettiImport.lua for the hook wiring). The parser lives in
PakettiEXS24Parser.lua; this file is the Renoise glue layer.

What is supported per zone:
  name, fine_tune, pan, volume (dB→lin), oneshot, base_note, note_range,
  velocity_range, loop_start/end, loop_mode (forward/reverse/ping-pong).

Known limitations (inherited from the upstream parser, document and accept
for the first cut — tracked in the EXS24 follow-up):
  • Group chunks (chunk_type 2) are skipped — group-level volume/pan/output
    is not honoured. Drum kits relying on group balance will sound wrong.
  • Param + binary-plist chunks (4, 0xB) are skipped — no filter/env/LFO
    transfer. Sustained EXS patches play as raw samples.
  • renoise.Sample.sample_buffer:load_from() handles WAV/AIFF only —
    EXS24 patches referencing CAF or Apple Loops will count as missing.
  • Multi-folder velocity-layer libraries (samples split into subfolders)
    fall back to the user folder-prompt; recursive search not implemented.
  • Tool-ID collision: if matt-allan/renoise-exs24 (com.matta.exs24) is
    also installed, only one of the two .exs import hooks wins. Disable
    one of them in the Renoise tool browser to choose.

Derived from matt-allan/renoise-exs24's tool.lua (MIT, 2018) — adapted for
Paketti (GPLv3).

  MIT License — Copyright (c) 2018 Matt Allan and all contributors.
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction. The above copyright notice and this
  permission notice shall be included in all copies or substantial portions of
  the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
============================================================================]]--

local _DEBUG = false
local function dprint(...) if _DEBUG then print("EXS24:", ...) end end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Sample-library-roots reader lives in PakettiFSPath.lua so OT, EXS24, and any
-- future importer share the same user-configured search roots.

---Locate the samples folder for an EXS24 file. Tries the parser's stored
---absolute sample path, then the same folder as the .exs, then rebases at
---common-segment depths against the .exs and each configured library root,
---then finally prompts the user.
---@param filepath string
---@param exs_file EXS24File
---@return string?
local function find_samples_folder(filepath, exs_file)
  local zone = exs_file.zones[1]
  if not zone then return nil end
  local sample = exs_file.samples[zone.sample_index + 1]
  if not sample then return nil end

  local dirname, basename = pakettiFSPath.split(filepath)
  local sample_filename = sample.file_name or sample.header.name
  local extra_roots = pakettiFSPath.library_roots()

  -- Stored absolute path is sometimes a directory and sometimes a file path —
  -- try it directly, then as a directory containing the sample.
  if sample.file_path and sample.file_path ~= "" then
    if io.exists(pakettiFSPath.join(sample.file_path, sample_filename)) then
      return sample.file_path
    end
    local resolved = pakettiFSPath.resolve(
      pakettiFSPath.join(sample.file_path, sample_filename),
      filepath,
      extra_roots
    )
    if resolved then return pakettiFSPath.dirname(resolved) end
  end

  if io.exists(pakettiFSPath.join(dirname, sample_filename)) then
    return dirname
  end

  return renoise.app():prompt_for_path("Samples folder for " .. basename .. ":")
end

---Apply zone metadata (name, mapping, loop, pan/vol) to a sample slot whose
---audio data is already in place. `frame_offset` is the master-buffer frame
---index that corresponds to frame 1 of the destination buffer — used to
---rebase the zone's loop offsets to be relative to the (possibly sliced)
---destination buffer.
---@param rns_sample renoise.Sample
---@param zone EXS24Zone
---@param sample EXS24Sample
---@param frame_offset integer
local function apply_zone_metadata(rns_sample, zone, sample, frame_offset)
  rns_sample.name = sample.header.name
  rns_sample.volume = math.db2lin(zone.volume)
  rns_sample.fine_tune = zone.fine_tuning
  rns_sample.panning = clamp((zone.pan / 200) + 0.5, 0.0, 1.0)
  rns_sample.oneshot = zone.zone_flags.oneshot
  rns_sample.sample_mapping.base_note = clamp(zone.key, 0, 119)
  rns_sample.sample_mapping.note_range = {
    clamp(zone.key_low, 0, 119),
    clamp(zone.key_high, 0, 119),
  }
  rns_sample.sample_mapping.velocity_range = {
    zone.velocity_low,
    zone.velocity_high,
  }

  local buf_len = rns_sample.sample_buffer.number_of_frames
  if zone.loop_flags.loop_on and zone.loop_end > zone.loop_start then
    local ls = math.max(1, (zone.loop_start - frame_offset) + 1)
    local le = math.max(ls, (zone.loop_end - frame_offset) - 1)
    rns_sample.loop_start = math.min(ls, buf_len)
    rns_sample.loop_end = math.min(le, buf_len)
    if zone.play_mode == pakettiEXS24Parser.PLAY_MODE_REVERSE then
      rns_sample.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
    elseif zone.play_mode == pakettiEXS24Parser.PLAY_MODE_ALTERNATE then
      rns_sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
    else
      rns_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    end
  end

  if preferences.pakettiLoaderAutofade and preferences.pakettiLoaderAutofade.value then
    rns_sample.autofade = true
  end
end

---Copy a frame range from the master buffer into the destination buffer.
---Wrapped between prepare/finalize. Yields every ~16384 frames per channel
---so Renoise stays responsive on large slices.
---@param master renoise.SampleBuffer
---@param target renoise.SampleBuffer
---@param master_start integer  -- 1-based master frame index
---@param length integer
local function copy_frame_range(master, target, master_start, length)
  target:create_sample_data(
    master.sample_rate,
    master.bit_depth,
    master.number_of_channels,
    length
  )
  target:prepare_sample_data_changes()
  local channels = master.number_of_channels
  for ch = 1, channels do
    for f = 1, length do
      target:set_sample_data(ch, f, master:sample_data(ch, master_start + f - 1))
      if (f % 16384) == 0 then coroutine.yield() end
    end
  end
  target:finalize_sample_data_changes()
end

---File_import_hook entry point (registered in PakettiImport.lua).
---Runs the per-zone insertion loop inside a ProcessSlicer so Renoise stays
---responsive on large patches (autosampled libraries can hit 100+ zones with
---50-200 individual sample loads — without yielding Renoise locks up and
---triggers the "Script not responding" terminate-or-wait dialog).
---@param filepath string
---@return boolean handled
function exs24_loadinstrument(filepath)
  local app = renoise.app()

  -- Read + parse synchronously: these are fast (single file read, pure-Lua
  -- byte parsing) and we need to bail early if the file is invalid before
  -- spinning up the slicer + progress dialog.
  local fh, ferr = io.open(filepath, "rb")
  if not fh then
    app:show_error("EXS24 file could not be opened: " .. tostring(ferr))
    return false
  end
  local data = fh:read("*a")
  fh:close()
  if not data then
    app:show_error("EXS24 file could not be read")
    return false
  end

  local ok, result = pcall(pakettiEXS24Parser.parse, data)
  if not ok then
    app:show_error("EXS24 instrument could not be parsed")
    dprint("parse error:", result)
    return false
  end

  ---@type EXS24File
  local exs_file = result

  if #exs_file.zones == 0 then
    app:show_status("EXS24 instrument contained no zones")
    return true
  end
  if #exs_file.samples == 0 then
    app:show_status("EXS24 instrument contained no samples")
    return true
  end

  -- Locate samples folder synchronously too: this may prompt the user, which
  -- must happen before we hand off to the slicer (modal dialogs don't mix
  -- well with a yielding coroutine).
  local samples_path = find_samples_folder(filepath, exs_file)
  if not samples_path or samples_path == "" then
    app:show_error("EXS24 sample folder could not be found")
    return false
  end

  local exs_name
  if exs_file.headers[1] and exs_file.headers[1].name ~= "" then
    exs_name = exs_file.headers[1].name
  else
    exs_name = pakettiFSPath.basename(filepath, ".exs")
  end

  -- Now drive the heavy work (instrument creation + per-zone sample loads)
  -- through a ProcessSlicer so Renoise's UI thread keeps breathing.
  local slicer = nil
  local function process_import()
    local dialog, vb = nil, nil
    if slicer and slicer.create_dialog then
      dialog, vb = slicer:create_dialog("Importing EXS24: " .. exs_name)
    end

    if type(pakettiPreferencesDefaultInstrumentLoader) == "function" then
      if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then
        if dialog and dialog.visible then dialog:close() end
        return
      end
      renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
      pakettiPreferencesDefaultInstrumentLoader()
    end

    local instrument = renoise.song().selected_instrument
    instrument.name = exs_name

    -- Empty out anything the default-instrument template left behind so we
    -- start with a clean slot list. (The template typically leaves an empty
    -- placeholder sample at index 1.)
    while #instrument.samples > 0 do
      instrument:delete_sample_at(#instrument.samples)
    end

    coroutine.yield()

    -- Group zones by the EXS24 sample they reference. Logic's factory patches
    -- commonly use the "monolithic" layout where every zone points to a
    -- single big WAV and each zone is a sub-range defined by sample_start/
    -- sample_end (frame offsets, not bytes). We load each unique sample WAV
    -- once into a scratch slot, then for each zone create a destination slot
    -- and copy just the zone's frame range from the scratch buffer.
    local zones_by_sample = {}
    for _, zone in ipairs(exs_file.zones) do
      local idx = zone.sample_index + 1
      zones_by_sample[idx] = zones_by_sample[idx] or {}
      table.insert(zones_by_sample[idx], zone)
    end

    local missing = 0
    local total = #exs_file.zones
    local done = 0

    for sample_idx = 1, #exs_file.samples do
      local zones = zones_by_sample[sample_idx]
      local exs_sample = exs_file.samples[sample_idx]
      if zones and exs_sample then
        local filename = exs_sample.file_name or exs_sample.header.name
        local sample_path = pakettiFSPath.join(samples_path, filename)

        if not io.exists(sample_path) then
          missing = missing + #zones
          done = done + #zones
          dprint("missing wav:", sample_path)
        else
          -- Load the master WAV into a temporary scratch slot at position 1.
          -- We delete it after all zones for this sample are sliced out.
          local scratch_index = #instrument.samples + 1
          instrument:insert_sample_at(scratch_index)
          local scratch = instrument.samples[scratch_index]
          if not scratch.sample_buffer:load_from(sample_path) then
            instrument:delete_sample_at(scratch_index)
            missing = missing + #zones
            done = done + #zones
            dprint("failed to load wav:", sample_path)
          else
            local master = scratch.sample_buffer
            local total_frames = master.number_of_frames
            coroutine.yield()

            for _, zone in ipairs(zones) do
              -- sample_start / sample_end are 0-based frame offsets into the
              -- master WAV. Treat 0/0 (or end <= start) as "use whole sample".
              local s_start_0 = zone.sample_start or 0
              local s_end_0   = zone.sample_end or 0
              if s_end_0 <= s_start_0 then
                s_start_0 = 0
                s_end_0 = total_frames - 1
              end
              s_start_0 = math.max(0, math.min(s_start_0, total_frames - 1))
              s_end_0   = math.max(s_start_0, math.min(s_end_0, total_frames - 1))
              local length = s_end_0 - s_start_0 + 1

              local target_idx = #instrument.samples + 1
              instrument:insert_sample_at(target_idx)
              local target = instrument.samples[target_idx]
              copy_frame_range(master, target.sample_buffer, s_start_0 + 1, length)
              apply_zone_metadata(target, zone, exs_sample, s_start_0)

              done = done + 1
              if vb and vb.views and vb.views.progress_text then
                vb.views.progress_text.text = string.format(
                  "Slicing zone %d / %d (%d missing)", done, total, missing)
              end
              app:show_status(string.format(
                "Importing EXS24 %s (%d%%)...", exs_name,
                math.floor((done / total) * 100)))
              coroutine.yield()
            end

            -- Scratch sits at scratch_index; per-zone targets are always
            -- inserted at the tail (higher indices), so the scratch never
            -- shifts. Delete it by its recorded index.
            instrument:delete_sample_at(scratch_index)
          end
        end
      end
      coroutine.yield()
    end

    if preferences.pakettiLoaderNormalizeSamples and preferences.pakettiLoaderNormalizeSamples.value then
      if type(normalize_all_samples_in_instrument) == "function" then
        normalize_all_samples_in_instrument()
      end
    end

    if dialog and dialog.visible then dialog:close() end

    if missing > 0 then
      app:show_warning(string.format(
        "EXS24 import complete — %d of %d samples could not be found.\n" ..
        "Tip: add the sample library root to Preferences > pakettiSampleLibraryRoots.",
        missing, total))
    else
      app:show_status(string.format("EXS24 import complete: %s (%d zones)", exs_name, total))
    end
  end

  slicer = ProcessSlicer(process_import)
  slicer:start()

  -- Return true synchronously so Renoise records the hook as handled; the
  -- actual instrument population continues on the slicer.
  return true
end
