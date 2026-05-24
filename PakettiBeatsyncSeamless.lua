-- PakettiBeatsyncSeamless.lua
-- Auto-chop a long sample into N pieces that each fit Renoise's
-- beat_sync_lines = 512 cap, keyzone them as a drumkit, and lay them
-- across the pattern so playback at the song BPM is seamless.

local SILENCE_THRESHOLD = 0.001 -- -60 dB peak
local MAX_PATTERN_LINES = 512
local MAX_BEAT_SYNC_LINES = 512
local BASE_NOTE = 48 -- C-4

local function find_audible_bounds(sbuf)
  local frames = sbuf.number_of_frames
  local channels = sbuf.number_of_channels
  local first_audible, last_audible
  for f = 1, frames do
    for ch = 1, channels do
      if math.abs(sbuf:sample_data(ch, f)) > SILENCE_THRESHOLD then
        first_audible = f
        break
      end
    end
    if first_audible then break end
  end
  if not first_audible then return nil, nil end
  for f = frames, first_audible, -1 do
    for ch = 1, channels do
      if math.abs(sbuf:sample_data(ch, f)) > SILENCE_THRESHOLD then
        last_audible = f
        break
      end
    end
    if last_audible then break end
  end
  return first_audible, last_audible
end

local function trim_sample_range(instr, sample_idx, first, last)
  local source = instr.samples[sample_idx]
  local sbuf = source.sample_buffer
  local rate = sbuf.sample_rate
  local depth = sbuf.bit_depth
  local channels = sbuf.number_of_channels
  local out_frames = last - first + 1

  local new_sample = instr:insert_sample_at(sample_idx)
  new_sample:copy_from(source)
  local nb = new_sample.sample_buffer
  -- create_sample_data allocates a fresh buffer — prepare/finalize_sample_data_changes
  -- is ONLY for modifying existing data, not for freshly created buffers.
  nb:create_sample_data(rate, depth, channels, out_frames)
  for ch = 1, channels do
    for f = 1, out_frames do
      nb:set_sample_data(ch, f, sbuf:sample_data(ch, first + f - 1))
    end
  end
  instr:delete_sample_at(sample_idx + 1)
  return instr.samples[sample_idx]
end

local function compute_chop_params(seconds, bpm, lpb)
  local needed = math.ceil(seconds * bpm * lpb / 60)
  if needed < 1 then needed = 1 end
  if needed <= MAX_BEAT_SYNC_LINES then return 1, needed end
  local N = math.ceil(needed / MAX_BEAT_SYNC_LINES)
  local per_chunk = math.ceil(needed / N)
  if per_chunk > MAX_BEAT_SYNC_LINES then
    N = N + 1
    per_chunk = math.ceil(needed / N)
  end
  return N, per_chunk
end

function PakettiBeatsyncSeamlessAutoChop()
  local song = renoise.song()
  local instr = song.selected_instrument
  local sample_idx = song.selected_sample_index
  local sample = instr.samples[sample_idx]

  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Beatsync Seamless: no sample data on selected sample")
    return
  end
  if sample.sample_buffer.read_only then
    renoise.app():show_status("Beatsync Seamless: selected sample is read-only (sliced?)")
    return
  end

  song:describe_undo("Paketti Beatsync Seamless Auto-Chop")

  -- 1. Trim leading/trailing silence
  local sbuf = sample.sample_buffer
  local first, last = find_audible_bounds(sbuf)
  if not first then
    renoise.app():show_status("Beatsync Seamless: entire sample is below -60 dB")
    return
  end
  if first > 1 or last < sbuf.number_of_frames then
    sample = trim_sample_range(instr, sample_idx, first, last)
    sbuf = sample.sample_buffer
  end

  -- 2. Normalize (uses the shared PakettiNormalizeSample helper from PakettiProcess.lua)
  PakettiNormalizeSample(sample, 0)
  sbuf = sample.sample_buffer

  -- 3. Compute chop params from current BPM / LPB
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local seconds = sbuf.number_of_frames / sbuf.sample_rate
  local N, per_chunk = compute_chop_params(seconds, bpm, lpb)

  -- 4. Duplicate + chop into N equal pieces (only if N > 1)
  local rate = sbuf.sample_rate
  local depth = sbuf.bit_depth
  local channels = sbuf.number_of_channels
  local total_frames = sbuf.number_of_frames
  local chunk_frames = math.floor(total_frames / N)
  local source_name = sample.name

  local function populate_chunk(target, chunk_index)
    local nb = target.sample_buffer
    -- create_sample_data allocates a fresh buffer — no prepare/finalize wrap.
    nb:create_sample_data(rate, depth, channels, chunk_frames)
    local source_start = (chunk_index - 1) * chunk_frames
    for ch = 1, channels do
      for f = 1, chunk_frames do
        nb:set_sample_data(ch, f, sbuf:sample_data(ch, source_start + f))
      end
    end
    target.name = string.format("%s [%d/%d]", source_name, chunk_index, N)
  end

  if N > 1 then
    -- Insert chunk 1 at sample_idx (pushes source to sample_idx+1)
    local chunk1 = instr:insert_sample_at(sample_idx)
    chunk1:copy_from(sample)
    populate_chunk(chunk1, 1)
    -- chunks 2..N go at sample_idx+i-1 each time (source slides further down)
    for i = 2, N do
      local chunki = instr:insert_sample_at(sample_idx + i - 1)
      chunki:copy_from(sample)
      populate_chunk(chunki, i)
    end
    -- Remove the now-redundant source sample (sits at sample_idx + N)
    instr:delete_sample_at(sample_idx + N)
  else
    sample.name = source_name
  end

  -- 5/6/7. Apply beatsync, autoseek, autofade, keyzone
  for i = 1, N do
    local s = instr.samples[sample_idx + i - 1]
    s.beat_sync_enabled = true
    s.beat_sync_lines = per_chunk
    s.autoseek = true
    s.autofade = false
    s.loop_mode = renoise.Sample.LOOP_MODE_OFF
    local note = BASE_NOTE + i - 1
    if note > 119 then note = 119 end
    s.sample_mapping.note_range = {note, note}
    s.sample_mapping.base_note = note
    s.sample_mapping.velocity_range = {0, 127}
  end

  -- 8. Resize pattern + place notes
  local pattern = song.selected_pattern
  local track_idx = song.selected_track_index
  local track = song.tracks[track_idx]
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Beatsync Seamless: chops created, but selected track is not a sequencer track \226\128\148 notes not placed")
    return
  end

  local total_lines = per_chunk * N
  local fit_chunks = N
  local overflow = false
  if total_lines > MAX_PATTERN_LINES then
    pattern.number_of_lines = MAX_PATTERN_LINES
    fit_chunks = math.floor(MAX_PATTERN_LINES / per_chunk)
    overflow = true
  else
    pattern.number_of_lines = total_lines
  end

  if track.visible_note_columns < 1 then
    track.visible_note_columns = 1
  end

  local pattern_track = pattern:track(track_idx)
  local instr_value = song.selected_instrument_index - 1
  for i = 1, fit_chunks do
    local line_idx = (i - 1) * per_chunk + 1
    if line_idx > pattern.number_of_lines then break end
    local note_col = pattern_track:line(line_idx).note_columns[1]
    note_col.note_value = BASE_NOTE + i - 1
    note_col.instrument_value = instr_value
  end

  if overflow then
    renoise.app():show_status(string.format(
      "Beatsync Seamless: %d chunks \195\151 %d lines @ %.2f BPM / %d LPB \226\128\148 sample too long for single pattern, placed %d of %d chunks",
      N, per_chunk, bpm, lpb, fit_chunks, N))
  else
    renoise.app():show_status(string.format(
      "Beatsync Seamless: %d chunks \195\151 %d lines @ %.2f BPM / %d LPB",
      N, per_chunk, bpm, lpb))
  end
end

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Samples:Beatsync Seamless (Auto-Chop Long Sample)",
  invoke = function() PakettiBeatsyncSeamlessAutoChop() end
}
renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Process:Beatsync Seamless (Auto-Chop Long Sample)",
  invoke = function() PakettiBeatsyncSeamlessAutoChop() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Beatsync Seamless Auto-Chop",
  invoke = function() PakettiBeatsyncSeamlessAutoChop() end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Beatsync Seamless Auto-Chop",
  invoke = function(message) if message:is_trigger() then PakettiBeatsyncSeamlessAutoChop() end end
}
