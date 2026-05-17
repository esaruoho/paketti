--[[============================================================================
PakettiEXS24Loader.lua — Logic EXS24 sampler instrument (.exs) importer

Registers as a Renoise instrument-category file_import_hook (see
PakettiImport.lua for the hook wiring). The parser lives in
PakettiEXS24Parser.lua; this file is the Renoise glue layer.

What is supported per zone:
  name, fine_tune, pan, volume (dB→lin), oneshot, base_note, note_range,
  velocity_range, loop_start/end, loop_mode (forward/reverse/ping-pong).

Groups → instruments:
  EXS24 patches commonly use 28+ "groups" to separate articulations (e.g.
  one group per guitar string, or palm-mute / harmonic / release layers).
  Logic's runtime decides which group plays via group routing (round-
  robin, polyphony, key-switches, mod-wheel) — none of which Renoise has
  a direct equivalent for. When pakettiImportEXS24SplitGroups is true
  (default), we map each EXS group to its own Renoise instrument; the
  user picks which articulation to play by selecting the instrument. When
  false (or for single-group patches), all zones go into one instrument
  with first-wins overlap dedup as a safety net.

Known limitations:
  • The 132-byte group chunk body is not parsed — only the group name and
    index. Group-level volume / pan / output / mute / poly flags are not
    transferred. Drum-kit patches relying on group-level balance may
    sound wrong.
  • Param + binary-plist chunks (4, 0xB) are skipped — no filter / env /
    LFO transfer. Sustained EXS patches play as raw samples.
  • renoise.Sample.sample_buffer:load_from() handles whatever Renoise
    natively reads (WAV / AIFF / CAF on macOS via CoreAudio). Formats
    Renoise can't load are counted as missing.
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
---Wrapped between prepare/finalize. Yields every ~65536 frames per channel
---so Renoise stays responsive on large slices without paying for context
---switches too often. The inner loop hoists the userdata method refs into
---locals — LuaJIT's optimiser cares about this.
---NOTE: per-frame copy is the only path. There is no buffer-level copy in
---renoise.SampleBuffer (verified against the Renoise Lua API definition);
---see ~/.claude/skills/paketti/Renoise API Limits.md for the full surface.
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
  local master_sample_data = master.sample_data
  local target_set_sample_data = target.set_sample_data
  for ch = 1, channels do
    for f = 1, length do
      target_set_sample_data(target, ch, f,
        master_sample_data(master, ch, master_start + f - 1))
      if (f % 65536) == 0 then coroutine.yield() end
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

  -- First-wins dedupe — used per group (or for the whole patch when split is
  -- off) as a safety net against any within-set overlap.
  local function dedupe_zones(zones)
    local kept, coverage, skipped = {}, {}, 0
    for _, zone in ipairs(zones) do
      local kl = clamp(zone.key_low, 0, 119)
      local kh = math.max(kl, clamp(zone.key_high, 0, 119))
      local vl = clamp(zone.velocity_low, 0, 127)
      local vh = math.max(vl, clamp(zone.velocity_high, 0, 127))
      local clash = false
      for k = kl, kh do
        if clash then break end
        for v = vl, vh do
          if coverage[k * 128 + v] then clash = true; break end
        end
      end
      if clash then
        skipped = skipped + 1
      else
        table.insert(kept, zone)
        for k = kl, kh do
          for v = vl, vh do coverage[k * 128 + v] = true end
        end
      end
    end
    return kept, skipped
  end

  -- Group zones by their EXS group_index. Logic's "groups" are separate
  -- articulations meant to be routed at runtime; we map them onto Renoise
  -- instruments, one per group, so the user picks the articulation by
  -- selecting the instrument.
  local zones_by_group = {}
  for _, zone in ipairs(exs_file.zones) do
    local g = zone.group_index or 0
    zones_by_group[g] = zones_by_group[g] or {}
    table.insert(zones_by_group[g], zone)
  end
  local group_ids = {}
  for g in pairs(zones_by_group) do table.insert(group_ids, g) end
  table.sort(group_ids)

  -- Resolve the split-groups preference. Default ON. Single-group patches
  -- always import as one instrument regardless.
  local split_groups = true
  if preferences and preferences.pakettiImportEXS24SplitGroups then
    split_groups = preferences.pakettiImportEXS24SplitGroups.value
  end
  if #group_ids <= 1 then split_groups = false end

  local function group_name_for(group_idx)
    local meta = exs_file.groups and exs_file.groups[group_idx]
    if meta and meta.name and meta.name ~= "" then return meta.name end
    return string.format("Group %d", group_idx)
  end

  -- Now drive the heavy work (instrument creation + per-zone sample loads)
  -- through a ProcessSlicer so Renoise's UI thread keeps breathing.
  local slicer = nil
  local function process_import()
    local dialog, vb = nil, nil
    if slicer and slicer.create_dialog then
      dialog, vb = slicer:create_dialog("Importing EXS24: " .. exs_name)
    end

    local song = renoise.song()
    local base_idx = song.selected_instrument_index

    -- Phase 1: load each unique master sample WAV into a hidden scratch
    -- instrument. We slice every group's zones from these buffers without
    -- re-reading the WAV per group (Vintage Strat references one 580-second
    -- CAF — reloading per group would be 28× slower).
    if not safeInsertInstrumentAt(song, base_idx + 1) then
      if dialog and dialog.visible then dialog:close() end
      app:show_error("EXS24: could not allocate scratch instrument")
      return
    end
    song.selected_instrument_index = base_idx + 1
    local scratch_instrument = song.selected_instrument
    scratch_instrument.name = string.format("[EXS24 scratch: %s]", exs_name)

    -- Empty whatever the default template might have inserted.
    while #scratch_instrument.samples > 0 do
      scratch_instrument:delete_sample_at(#scratch_instrument.samples)
    end

    local sample_buffer_by_idx = {}  -- exs sample_idx (1-based) → SampleBuffer
    local needed_samples = {}
    for _, zone in ipairs(exs_file.zones) do
      needed_samples[zone.sample_index + 1] = true
    end

    local total_missing = 0
    local total_zones = #exs_file.zones

    for exs_sample_idx in pairs(needed_samples) do
      local exs_sample = exs_file.samples[exs_sample_idx]
      if exs_sample then
        local filename = exs_sample.file_name or exs_sample.header.name
        local sample_path = pakettiFSPath.join(samples_path, filename)
        if vb and vb.views and vb.views.progress_text then
          vb.views.progress_text.text = "Loading master sample: " .. filename
        end
        if io.exists(sample_path) then
          scratch_instrument:insert_sample_at(#scratch_instrument.samples + 1)
          local s = scratch_instrument.samples[#scratch_instrument.samples]
          if s.sample_buffer:load_from(sample_path) then
            sample_buffer_by_idx[exs_sample_idx] = s.sample_buffer
          else
            dprint("failed to load master:", sample_path)
          end
        else
          dprint("missing master:", sample_path)
        end
      end
      coroutine.yield()
    end

    -- Phase 2: per group, allocate a Renoise instrument and slice the
    -- group's zones from the scratch buffers. Inserts always go above
    -- `current_inst_idx` so we know exactly where each new instrument lands.
    local current_inst_idx = base_idx + 1  -- scratch sits here
    local created_instruments = {}  -- list of indices we made (pre-scratch-delete)
    local group_count = 0

    local function create_user_instrument(name)
      if not safeInsertInstrumentAt(song, current_inst_idx + 1) then return nil end
      current_inst_idx = current_inst_idx + 1
      song.selected_instrument_index = current_inst_idx
      if type(pakettiPreferencesDefaultInstrumentLoader) == "function" then
        pakettiPreferencesDefaultInstrumentLoader()
      end
      local inst = song.selected_instrument
      inst.name = name
      while #inst.samples > 0 do
        inst:delete_sample_at(#inst.samples)
      end
      table.insert(created_instruments, current_inst_idx)
      return inst
    end

    local function slice_zones_into(inst, zones_to_load)
      local done = 0
      local total = #zones_to_load
      for _, zone in ipairs(zones_to_load) do
        local master = sample_buffer_by_idx[zone.sample_index + 1]
        if not master then
          total_missing = total_missing + 1
        else
          local total_frames = master.number_of_frames
          local s_start_0 = zone.sample_start or 0
          local s_end_0   = zone.sample_end or 0
          if s_end_0 <= s_start_0 then
            s_start_0 = 0
            s_end_0 = total_frames - 1
          end
          s_start_0 = math.max(0, math.min(s_start_0, total_frames - 1))
          s_end_0   = math.max(s_start_0, math.min(s_end_0, total_frames - 1))
          local length = s_end_0 - s_start_0 + 1

          local target_idx = #inst.samples + 1
          inst:insert_sample_at(target_idx)
          local target = inst.samples[target_idx]
          copy_frame_range(master, target.sample_buffer, s_start_0 + 1, length)
          apply_zone_metadata(target, zone, exs_file.samples[zone.sample_index + 1], s_start_0)
        end
        done = done + 1
        if vb and vb.views and vb.views.progress_text then
          vb.views.progress_text.text = string.format(
            "[%s] zone %d / %d", inst.name, done, total)
        end
        app:show_status(string.format(
          "Importing EXS24 %s (%d%%)...", exs_name,
          math.floor((done / total) * 100)))
        coroutine.yield()
      end
    end

    if split_groups then
      for _, group_idx in ipairs(group_ids) do
        local zones = zones_by_group[group_idx]
        local kept, skipped = dedupe_zones(zones)
        local g_name = group_name_for(group_idx)
        local inst_name = string.format("%s (%s)", exs_name, g_name)
        if skipped > 0 then
          dprint(string.format("[%s] %d/%d zones kept (%d within-group dedup)",
            inst_name, #kept, #zones, skipped))
        end
        local inst = create_user_instrument(inst_name)
        if inst and #kept > 0 then
          slice_zones_into(inst, kept)
          group_count = group_count + 1
        end
        coroutine.yield()
      end
    else
      -- Lump everything into one instrument with cross-group dedup.
      local kept, skipped = dedupe_zones(exs_file.zones)
      local inst = create_user_instrument(exs_name)
      if inst and #kept > 0 then
        slice_zones_into(inst, kept)
        group_count = 1
      end
      if skipped > 0 then
        dprint(string.format("Lumped mode: %d/%d zones kept (%d overlap-dedup)",
          #kept, #exs_file.zones, skipped))
      end
    end

    if preferences.pakettiLoaderNormalizeSamples and preferences.pakettiLoaderNormalizeSamples.value then
      if type(normalize_all_samples_in_instrument) == "function" then
        normalize_all_samples_in_instrument()
      end
    end

    -- Phase 3: delete the scratch instrument. Created instruments above
    -- base_idx + 1 shift down by 1. Focus the first newly-created group
    -- instrument so the user lands on a playable patch.
    song:delete_instrument_at(base_idx + 1)
    song.selected_instrument_index = math.min(base_idx + 1, #song.instruments)

    if dialog and dialog.visible then dialog:close() end

    if split_groups then
      app:show_status(string.format(
        "EXS24 import complete: %s → %d articulation instruments%s",
        exs_name, group_count,
        total_missing > 0 and string.format(" (%d zones with missing samples)", total_missing) or ""))
    else
      app:show_status(string.format(
        "EXS24 import complete: %s%s",
        exs_name,
        total_missing > 0 and string.format(" (%d zones with missing samples)", total_missing) or ""))
    end
  end

  slicer = ProcessSlicer(process_import)
  slicer:start()

  -- Return true synchronously so Renoise records the hook as handled; the
  -- actual instrument population continues on the slicer.
  return true
end
