-- PakettiHack.lua
-- XRNI XML roundtrip to bypass Renoise UI clamps.
-- Currently: BeatSyncLines beyond the 1-512 API range (XML accepts 8192, 16384, 32768, ...).
-- Pipeline: save_instrument -> unzip Instrument.xml -> patch -> zip update -> load_instrument.
--
-- Save protection: the engine still holds the >512 in-memory value after the hack
-- is applied, and writing it into an XRNS produces a file that hard-crashes on reload
-- (SIGSEGV in TPatternPool teardown during the load swap). To prevent this, we hook
-- app_will_save_document_observable to clamp all hacked samples to 512 right before
-- the XRNS serializer reads them, then re-apply the hack via the XML roundtrip after
-- the save completes (app_saved_document_observable). The engine's beat_sync_lines
-- getter returns the actual value (not clamped on read), so we just iterate all
-- samples to find the hacked ones — no cache needed.

local paketti_hack_save_restore_queue = {}

local function paketti_hack_run_shell(cmd)
  local handle = io.popen(cmd .. " 2>&1; echo __RC__$?")
  if not handle then return false, "io.popen failed" end
  local out = handle:read("*a") or ""
  handle:close()
  local rc = out:match("__RC__(%d+)%s*$")
  out = out:gsub("__RC__%d+%s*$", "")
  return rc == "0", out
end

-- Core: patch one instrument's <BeatSyncLines> blocks in a SINGLE XRNI roundtrip.
-- sample_lines_map: { [sample_index] = target_lines, ... } (1-based sample indices).
-- The Nth <BeatSyncLines> block in Instrument.xml corresponds to samples[N], so a
-- sliced instrument's slice aliases each get their own block — we can patch every
-- over-512 slice in one save/reload instead of one reload per sample.
-- GLOBAL so PakettiSlicePro (and the save/reload restorers below) can call it.
-- Returns: ok(boolean), message(string), patched_count(number).
function pakettiBeatSyncHackRoundtrip(instr_idx, sample_lines_map)
  if os.platform() == "WINDOWS" then
    return false, "shell zip/unzip not wired for Windows yet", 0
  end
  local song = renoise.song()
  if not song then return false, "no song", 0 end
  local instr = song.instruments[instr_idx]
  if not instr then return false, "invalid instrument index " .. tostring(instr_idx), 0 end
  if #instr.samples == 0 then return false, "instrument has no samples", 0 end

  -- Validate + normalise targets
  local want = 0
  for s_idx, lines in pairs(sample_lines_map) do
    if type(lines) ~= "number" or lines < 1 or lines > 65535 then
      return false, string.format("target %s out of range (1-65535)", tostring(lines)), 0
    end
    sample_lines_map[s_idx] = math.floor(lines)
    want = want + 1
  end
  if want == 0 then return true, "nothing to patch", 0 end

  local sel_inst_before = song.selected_instrument_index
  local sel_sample_before = song.selected_sample_index
  local instr_name = instr.name

  -- save_instrument saves the SELECTED instrument; select the target.
  song.selected_instrument_index = instr_idx

  -- Force BeatSync on for the targeted samples so the patched value takes effect.
  for s_idx in pairs(sample_lines_map) do
    local s = instr.samples[s_idx]
    if s and s.beat_sync_enabled == false then s.beat_sync_enabled = true end
  end

  local t0 = os.clock()
  local tmp_xrni = os.tmpname() .. ".xrni"
  local tmp_dir = tmp_xrni .. ".d"
  os.mkdir(tmp_dir)

  renoise.app():save_instrument(tmp_xrni)

  local ok, err = paketti_hack_run_shell(string.format(
    'unzip -o -j %q Instrument.xml -d %q', tmp_xrni, tmp_dir))
  if not ok then
    os.remove(tmp_xrni)
    return false, "unzip failed - " .. tostring(err), 0
  end
  local xml_path = tmp_dir .. "/Instrument.xml"

  local f = io.open(xml_path, "rb")
  if not f then return false, "cannot read extracted XML", 0 end
  local xml = f:read("*a"); f:close()

  local count = 0
  local patched = 0
  xml = xml:gsub("(<BeatSyncLines>)(%-?%d+)(</BeatSyncLines>)", function(open_tag, val, close_tag)
    count = count + 1
    local target = sample_lines_map[count]
    if target then
      patched = patched + 1
      return open_tag .. tostring(target) .. close_tag
    end
    return open_tag .. val .. close_tag
  end)

  if patched == 0 then
    os.remove(xml_path); os.remove(tmp_xrni)
    return false, string.format("no matching <BeatSyncLines> tag (found %d blocks)", count), 0
  end

  local fo = io.open(xml_path, "wb")
  if not fo then return false, "cannot write XML", 0 end
  fo:write(xml); fo:close()

  ok, err = paketti_hack_run_shell(string.format(
    'cd %q && zip -q %q Instrument.xml', tmp_dir, tmp_xrni))
  if not ok then
    os.remove(xml_path); os.remove(tmp_xrni)
    return false, "zip update failed - " .. tostring(err), 0
  end

  renoise.app():load_instrument(tmp_xrni)

  -- Restore name + selection (load_instrument loads into the selected slot).
  local reloaded = song.instruments[instr_idx]
  if reloaded then reloaded.name = instr_name end
  song.selected_instrument_index = sel_inst_before
  if song.instruments[sel_inst_before]
    and sel_sample_before <= #song.instruments[sel_inst_before].samples then
    song.selected_sample_index = sel_sample_before
  end

  os.remove(xml_path)
  os.remove(tmp_xrni)
  return true, string.format("patched %d sample(s) in %.0fms", patched, (os.clock() - t0) * 1000), patched
end

-- Thin wrapper for the dialog / menu presets: hack the currently selected sample.
local function paketti_hack_set_beatsync_lines(target_lines)
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr or #instr.samples == 0 then
    renoise.app():show_status("PakettiHack: no instrument/sample selected")
    return
  end
  local sample_idx = song.selected_sample_index
  if sample_idx < 1 then sample_idx = 1 end
  local ok, msg = pakettiBeatSyncHackRoundtrip(song.selected_instrument_index, { [sample_idx] = target_lines })
  if ok then
    renoise.app():show_status(string.format(
      "PakettiHack: BeatSyncLines=%d on sample %d (%s)", math.floor(target_lines), sample_idx, msg))
  else
    renoise.app():show_status("PakettiHack: " .. msg)
  end
end

-- ============================================================================
-- Restoration metadata (tool_data): persisted INSIDE the XRNS as a legal string
-- so extended (>512) values come back automatically after a project reload.
-- We never store the illegal value in a song property — only the restore recipe.
-- ============================================================================
local PAKETTI_HACK_TOOLDATA_TAG = "PKTBSH1"

local function paketti_hack_serialize(entries)
  local t = { PAKETTI_HACK_TOOLDATA_TAG }
  for _, e in ipairs(entries) do
    t[#t + 1] = string.format("%d,%d,%d", e.instr_idx, e.sample_idx, e.lines)
  end
  return table.concat(t, "\n")
end

local function paketti_hack_deserialize(s)
  local entries = {}
  if type(s) ~= "string" or s == "" then return entries end
  local lines = {}
  for line in s:gmatch("[^\n]+") do lines[#lines + 1] = line end
  if lines[1] ~= PAKETTI_HACK_TOOLDATA_TAG then return entries end
  for i = 2, #lines do
    local a, b, c = lines[i]:match("^(%d+),(%d+),(%d+)$")
    if a then
      entries[#entries + 1] = { instr_idx = tonumber(a), sample_idx = tonumber(b), lines = tonumber(c) }
    end
  end
  return entries
end

-- Group entries by instrument and re-inject each instrument in ONE roundtrip.
-- Returns: restored(count), failed(count), last_fail_message.
local function paketti_hack_inject_entries(entries)
  local song = renoise.song()
  if not song then return 0, #entries, "no song" end
  local by_instr = {}
  for _, e in ipairs(entries) do
    by_instr[e.instr_idx] = by_instr[e.instr_idx] or {}
    by_instr[e.instr_idx][e.sample_idx] = e.lines
  end
  local sel_inst_before = song.selected_instrument_index
  local sel_sample_before = song.selected_sample_index
  local restored, failed, fail_msg = 0, 0, nil
  for instr_idx, map in pairs(by_instr) do
    local n_targets = 0
    for _ in pairs(map) do n_targets = n_targets + 1 end
    if song.instruments[instr_idx] then
      local pok, rok, rmsg, rn = pcall(pakettiBeatSyncHackRoundtrip, instr_idx, map)
      if pok and rok then
        restored = restored + (rn or n_targets)
      else
        failed = failed + n_targets
        fail_msg = pok and rmsg or tostring(rok)
      end
    else
      failed = failed + n_targets
      fail_msg = "instrument " .. instr_idx .. " no longer exists"
    end
  end
  song.selected_instrument_index = sel_inst_before
  if song.instruments[sel_inst_before]
    and sel_sample_before <= #song.instruments[sel_inst_before].samples then
    song.selected_sample_index = sel_sample_before
  end
  return restored, failed, fail_msg
end

-- ============================================================================
-- Render & Restore: bake the stretched audio to a new sample, then clamp the
-- original sample's BeatSyncLines back to 512 so the song is XRNS-safe.
-- DISABLED: engine bugs (TPlayerEngine OnCalcBuffer crash on Texture/Percussion
-- stretch + TPatternWasRemovedObservable dtor crash on slot deletion) make
-- this feature unreliable. Code preserved for future revisit.
-- ============================================================================

--[[ DISABLED
function pakettiBeatSyncHackRenderAndRestore()
  local song = renoise.song()
  if not song then return end

  local instr_idx = song.selected_instrument_index
  local sample_idx = song.selected_sample_index
  if instr_idx < 1 or sample_idx < 1 then
    renoise.app():show_status("BSHRender: no instrument/sample selected"); return
  end
  local instr = song.instruments[instr_idx]
  if not instr or not instr.samples[sample_idx] then
    renoise.app():show_status("BSHRender: invalid sample selection"); return
  end
  local sample = instr.samples[sample_idx]

  local hacked_lines = sample.beat_sync_lines
  if not hacked_lines or hacked_lines <= 512 then
    renoise.app():show_status(string.format(
      "BSHRender: sample's BeatSyncLines is %s (<=512); nothing to render. Apply hack first.",
      tostring(hacked_lines)))
    return
  end

  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local duration_sec = hacked_lines * 60 / (bpm * lpb)
  local lines_per_pattern = math.min(512, hacked_lines)
  local extra_slots = math.ceil(hacked_lines / lines_per_pattern) - 1

  local was_playing = song.transport.playing
  if was_playing then song.transport:stop() end

  local master_idx = #song.tracks
  for t = 1, #song.tracks do
    if song.tracks[t].type == renoise.Track.TRACK_TYPE_MASTER then
      master_idx = t; break
    end
  end
  if master_idx < 2 then
    renoise.app():show_status("BSHRender: no sequencer track exists to anchor render"); return
  end

  local seq = song.sequencer

  -- Snapshot state for cleanup
  local snap = {
    mutes = {},
    sel_track = song.selected_track_index,
    sel_instr = instr_idx,
    sel_sample = sample_idx,
    sel_seq = song.selected_sequence_index,
    edit_mode = song.transport.edit_mode,
    added_seq_indices = {},
    added_pattern_indices = {},
    bs_enabled = sample.beat_sync_enabled,
  }
  for t = 1, #song.tracks do snap.mutes[t] = song.tracks[t].mute_state end
  if song.transport.edit_mode then song.transport.edit_mode = false end

  -- Force BeatSync ON for the duration of the render. Without this, the engine
  -- plays the sample at its natural rate and ignores beat_sync_lines, so the
  -- render captures a tiny burst at the start followed by 24 minutes of silence.
  if not sample.beat_sync_enabled then
    sample.beat_sync_enabled = true
  end

  print(string.format(
    "[BSHRender] sample %d: beat_sync_lines=%d, mode=%d, expected duration=%.1fs",
    sample_idx, sample.beat_sync_lines, sample.beat_sync_mode, duration_sec))

  song:describe_undo("PakettiHack: Render & Restore sample " .. tostring(sample_idx))

  -- Temp track at master_idx - 1 (before master => regular sequencer track)
  local temp_track_idx = master_idx - 1
  local temp_track = song:insert_track_at(temp_track_idx)
  temp_track.name = "[BSH render]"

  -- Build render slots at the END of the sequence (don't touch user's existing
  -- sequence). Pattern A holds the C-4 note; Pattern B is empty filler so the
  -- note triggers ONCE in slot A and the stretched sample plays through all
  -- following B slots without re-trigger interruptions.
  local first_render_seq_idx = #seq.pattern_sequence + 1
  seq:insert_new_pattern_at(first_render_seq_idx)
  local pat_a_idx = seq:pattern(first_render_seq_idx)
  song.patterns[pat_a_idx].number_of_lines = lines_per_pattern
  song.patterns[pat_a_idx].name = "[BSH render A]"
  table.insert(snap.added_seq_indices, first_render_seq_idx)
  table.insert(snap.added_pattern_indices, pat_a_idx)

  -- Place C-4 on temp track of pattern A, line 1
  local note_col = song.patterns[pat_a_idx]:track(temp_track_idx):line(1).note_columns[1]
  note_col.note_value = 48 -- C-4
  note_col.instrument_value = instr_idx - 1
  note_col.volume_value = 0x80

  -- For hacked > 512 lines: one shared empty pattern B, reused across extra slots
  if extra_slots > 0 then
    seq:insert_new_pattern_at(first_render_seq_idx + 1)
    local pat_b_idx = seq:pattern(first_render_seq_idx + 1)
    song.patterns[pat_b_idx].number_of_lines = lines_per_pattern
    song.patterns[pat_b_idx].name = "[BSH render B]"
    table.insert(snap.added_seq_indices, first_render_seq_idx + 1)
    table.insert(snap.added_pattern_indices, pat_b_idx)
    -- Slots 2..extra_slots: all reference pattern B (no extra patterns created)
    for k = 2, extra_slots do
      local s_idx = first_render_seq_idx + k
      seq:insert_sequence_at(s_idx, pat_b_idx)
      table.insert(snap.added_seq_indices, s_idx)
    end
  end
  local last_seq_idx = first_render_seq_idx + extra_slots

  -- Solo the temp track (PakettiRender convention — cleaner than per-track mute)
  snap.solos = {}
  for t = 1, #song.tracks do snap.solos[t] = song.tracks[t].solo_state end
  for t = 1, #song.tracks do song.tracks[t].solo_state = false end
  song.tracks[temp_track_idx].solo_state = true

  -- Use Paketti's central temp file path helper (main.lua:77)
  local tmp_wav = pakettiGetTempFilePath(".wav")

  -- Same render options pattern PakettiRender uses (preferences-driven)
  local render_opts = {
    sample_rate = preferences.renderSampleRate.value,
    bit_depth = preferences.renderBitDepth.value,
    interpolation = preferences.renderInterpolation.value,
    priority = "high",
    start_pos = renoise.SongPos(first_render_seq_idx, 1),
    end_pos = renoise.SongPos(last_seq_idx, lines_per_pattern),
  }

  local function restore_state()
    -- Unsolo + rename temp track (still alive at this point)
    if song.tracks[temp_track_idx]
      and song.tracks[temp_track_idx].name == "[BSH render]" then
      song.tracks[temp_track_idx].name = "[BSH render — delete me]"
      song.tracks[temp_track_idx].solo_state = false
    end
    -- Restore mute + solo states for original tracks
    for t = 1, math.min(#song.tracks, #snap.mutes) do
      if t ~= temp_track_idx
        and song.tracks[t].type == renoise.Track.TRACK_TYPE_SEQUENCER then
        song.tracks[t].mute_state = snap.mutes[t]
      end
    end
    if snap.solos then
      for t = 1, math.min(#song.tracks, #snap.solos) do
        if t ~= temp_track_idx then
          song.tracks[t].solo_state = snap.solos[t] or false
        end
      end
    end
    -- Restore edit mode + selection
    if snap.edit_mode then song.transport.edit_mode = true end
    if snap.sel_seq and snap.sel_seq <= #seq.pattern_sequence then
      song.selected_sequence_index = snap.sel_seq
    end
    if song.instruments[snap.sel_instr] then
      song.selected_instrument_index = snap.sel_instr
    end
  end

  -- Run the destructive cleanup prompts on an idle tick, NOT inside the render
  -- callback. Renoise's command queue is mid-flight on the render-done path,
  -- and destructive ops there crash. Idle tick = clean dispatcher state.
  local function ask_user_about_cleanup()
    if renoise.tool():has_timer(ask_user_about_cleanup) then
      renoise.tool():remove_timer(ask_user_about_cleanup)
    end

    -- Prompt 1: delete the temp track?
    local ans = renoise.app():show_prompt(
      "BSH Render — cleanup step 1 of 2",
      "Delete the temporary render track '[BSH render — delete me]'?\n\n"
      .. "(If Renoise crashes during deletion, the rendered sample is already "
      .. "loaded and saved-safe — just relaunch.)",
      {"Yes, delete track", "No, keep it"})
    if ans == "Yes, delete track" then
      if song.tracks[temp_track_idx]
        and (song.tracks[temp_track_idx].name == "[BSH render — delete me]"
             or song.tracks[temp_track_idx].name == "[BSH render]") then
        pcall(function() song:delete_track_at(temp_track_idx) end)
      end
    end

    -- Prompt 2: delete the added sequence slots?
    if #snap.added_seq_indices > 0 then
      ans = renoise.app():show_prompt(
        "BSH Render — cleanup step 2 of 2",
        string.format(
          "Delete the %d added sequence slot(s) at the end of the song?\n\n"
          .. "(This may trigger a Renoise engine bug — TPatternWasRemovedObservable "
          .. "SIGSEGV. If it crashes, the rendered sample is already loaded; "
          .. "just relaunch and manually delete leftover slots/patterns.)",
          #snap.added_seq_indices),
        {"Yes, delete slots", "No, keep them"})
      if ans == "Yes, delete slots" then
        table.sort(snap.added_seq_indices, function(a, b) return a > b end)
        for _, s_idx in ipairs(snap.added_seq_indices) do
          if seq.pattern_sequence[s_idx] then
            pcall(function() seq:delete_sequence_at(s_idx) end)
          end
        end
      end
    end

    renoise.app():show_status("BSH Render: cleanup done.")
  end

  local function on_render_done()
    if renoise.tool():has_timer(monitor_rendering) then
      renoise.tool():remove_timer(monitor_rendering)
    end
    local new_idx = #instr.samples + 1
    local new_sample = instr:insert_sample_at(new_idx)
    local ok = new_sample.sample_buffer:load_from(tmp_wav)
    if not ok then
      instr:delete_sample_at(new_idx)
      restore_state()
      os.remove(tmp_wav)
      renoise.app():show_status("BSHRender: WAV load_from failed")
      return
    end
    new_sample.name = sample.name .. " (BSH render)"
    new_sample.beat_sync_enabled = false
    new_sample.beat_sync_lines = 512

    -- Clamp original sample so the song is XRNS-safe now
    sample.beat_sync_lines = 512
    sample.beat_sync_enabled = false

    restore_state()
    os.remove(tmp_wav)

    if #instr.samples >= new_idx then
      song.selected_sample_index = new_idx
    end
    renoise.app():show_status(string.format(
      "BSHRender: rendered to sample [%d] (%.1fs). Original clamped to 512.",
      new_idx, duration_sec))

    -- Defer cleanup prompts to a clean idle tick (avoids crashing inside the
    -- render-done dispatch path).
    if not renoise.tool():has_timer(ask_user_about_cleanup) then
      renoise.tool():add_timer(ask_user_about_cleanup, 250)
    end
  end

  renoise.app():show_status(string.format(
    "BSHRender: rendering %d lines (~%.1fs)... GUI will be blocked.",
    hacked_lines, duration_sec))

  local success, err = song:render(render_opts, tmp_wav, on_render_done)
  if not success then
    cleanup()
    os.remove(tmp_wav)
    renoise.app():show_status("BSHRender: render call failed: " .. tostring(err))
  else
    if not renoise.tool():has_timer(monitor_rendering) then
      renoise.tool():add_timer(monitor_rendering, 500)
    end
  end
end
--]] -- end DISABLED Render & Restore

-- ============================================================================
-- Save protection: clamp hacked samples to 512 before XRNS save, re-apply after.
-- ============================================================================

local function paketti_hack_on_will_save()
  local song = renoise.song()
  if not song then return end
  paketti_hack_save_restore_queue = {}
  for i_idx = 1, #song.instruments do
    local instr = song.instruments[i_idx]
    for s_idx = 1, #instr.samples do
      local sample = instr.samples[s_idx]
      local lines = sample.beat_sync_lines
      if lines and lines > 512 then
        table.insert(paketti_hack_save_restore_queue, {
          instr_idx = i_idx,
          sample_idx = s_idx,
          lines = lines,
          had_sync = sample.beat_sync_enabled
        })
        sample.beat_sync_lines = 512
      end
    end
  end
  -- Persist the restore recipe inside the song (legal string) so a reload can
  -- re-apply the extended values automatically. Clear stale data when none.
  if #paketti_hack_save_restore_queue > 0 then
    song.tool_data = paketti_hack_serialize(paketti_hack_save_restore_queue)
    renoise.app():show_status(string.format(
      "BeatSyncHack: clamped %d sample(s) to 512 for safe XRNS save (metadata stored, will restore)",
      #paketti_hack_save_restore_queue))
  elseif song.tool_data and song.tool_data ~= "" then
    song.tool_data = ""
  end
end

local function paketti_hack_on_did_save()
  if #paketti_hack_save_restore_queue == 0 then return end
  local song = renoise.song()
  if not song then
    paketti_hack_save_restore_queue = {}
    return
  end
  local restored, failed, fail_msg = paketti_hack_inject_entries(paketti_hack_save_restore_queue)
  paketti_hack_save_restore_queue = {}
  if failed > 0 then
    renoise.app():show_status(string.format(
      "BeatSyncHack: restored %d, FAILED %d sample(s) after save (%s) - re-apply manually",
      restored, failed, tostring(fail_msg)))
  else
    renoise.app():show_status(string.format(
      "BeatSyncHack: restored %d sample(s) to extended BeatSyncLines after save", restored))
  end
end

-- After a project reload: read tool_data and re-inject any extended values.
-- Run on a one-shot idle tick, NOT inside the new-document notifier (the document
-- just swapped in; instrument reloads there are risky).
local function paketti_hack_restore_from_tool_data()
  if renoise.tool():has_timer(paketti_hack_restore_from_tool_data) then
    renoise.tool():remove_timer(paketti_hack_restore_from_tool_data)
  end
  local song = renoise.song()
  if not song then return end
  local entries = paketti_hack_deserialize(song.tool_data)
  if #entries == 0 then return end
  -- Only restore entries still clamped (<=512) to avoid double-injecting.
  local todo = {}
  for _, e in ipairs(entries) do
    local instr = song.instruments[e.instr_idx]
    local s = instr and instr.samples[e.sample_idx]
    if s and (s.beat_sync_lines or 0) <= 512 and e.lines > 512 then
      todo[#todo + 1] = e
    end
  end
  if #todo == 0 then return end
  local restored, failed, fail_msg = paketti_hack_inject_entries(todo)
  if failed > 0 then
    renoise.app():show_status(string.format(
      "BeatSyncHack: reload restore - %d done, %d FAILED (%s)", restored, failed, tostring(fail_msg)))
  else
    renoise.app():show_status(string.format(
      "BeatSyncHack: reload restore - re-applied extended BeatSyncLines to %d sample(s)", restored))
  end
end

local function paketti_hack_on_new_document()
  if not renoise.tool():has_timer(paketti_hack_restore_from_tool_data) then
    renoise.tool():add_timer(paketti_hack_restore_from_tool_data, 400)
  end
end

if not renoise.tool().app_will_save_document_observable:has_notifier(paketti_hack_on_will_save) then
  renoise.tool().app_will_save_document_observable:add_notifier(paketti_hack_on_will_save)
end
if not renoise.tool().app_saved_document_observable:has_notifier(paketti_hack_on_did_save) then
  renoise.tool().app_saved_document_observable:add_notifier(paketti_hack_on_did_save)
end
if not renoise.tool().app_new_document_observable:has_notifier(paketti_hack_on_new_document) then
  renoise.tool().app_new_document_observable:add_notifier(paketti_hack_on_new_document)
end

local paketti_hack_dialog = nil

function pakettiBeatSyncHackDialog()
  if paketti_hack_dialog and paketti_hack_dialog.visible then
    paketti_hack_dialog:close()
    paketti_hack_dialog = nil
    return
  end
  local vb = renoise.ViewBuilder()
  local value_view = vb:valuebox{min = 1, max = 65535, value = 8192, width = 100}
  local content = vb:column{
    margin = 8, spacing = 6,
    vb:text{
      style = "strong", font = "bold",
      text = "DO NOT SAVE THESE SONGS AS XRNS"
    },
    vb:text{
      style = "strong", font = "bold",
      text = "WITHOUT SETTING BEATSYNC BACK TO <512"
    },
    vb:text{text = "BeatSyncLines (1 - 65535). UI normally caps at 512."},
    vb:row{
      spacing = 4,
      vb:text{text = "Lines:", width = 50},
      value_view
    },
    vb:row{
      spacing = 4,
      vb:button{text = "1024", notifier = function() paketti_hack_set_beatsync_lines(1024) end},
      vb:button{text = "2048", notifier = function() paketti_hack_set_beatsync_lines(2048) end},
      vb:button{text = "4096", notifier = function() paketti_hack_set_beatsync_lines(4096) end},
      vb:button{text = "8192", notifier = function() paketti_hack_set_beatsync_lines(8192) end},
      vb:button{text = "16384", notifier = function() paketti_hack_set_beatsync_lines(16384) end},
      vb:button{text = "32768", notifier = function() paketti_hack_set_beatsync_lines(32768) end},
    },
    vb:button{
      text = "Apply Custom Value",
      notifier = function()
        paketti_hack_set_beatsync_lines(value_view.value)
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      end
    }
    -- Render & Restore button disabled (engine bugs cause crashes); see top of file
  }
  paketti_hack_dialog = renoise.app():show_custom_dialog("Paketti BeatSyncHack Dialog", content)
end

local presets = {1024, 2048, 4096, 8192, 16384, 32768}
for _, n in ipairs(presets) do
  local label = string.format("%05d", n)
  PakettiAddMenuEntry{
    name = "Main Menu:Tools:Paketti:Xperimental/WIP:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  PakettiAddMenuEntry{
    name = "Sample Editor:Paketti:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  PakettiAddMenuEntry{
    name = "Instrument Box:Paketti:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Xperimental/WIP:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Set BeatSyncLines Dialog",
  invoke = pakettiBeatSyncHackDialog
}

-- Render & Restore menu entries / keybinding disabled (engine crash bugs):
--[[ DISABLED
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Xperimental/WIP:BeatSyncHack:Render & Restore Current Sample",
  invoke = pakettiBeatSyncHackRenderAndRestore
}
PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:BeatSyncHack:Render & Restore Current Sample",
  invoke = pakettiBeatSyncHackRenderAndRestore
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:BeatSyncHack:Render & Restore Current Sample",
  invoke = pakettiBeatSyncHackRenderAndRestore
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:BeatSyncHack Render & Restore",
  invoke = pakettiBeatSyncHackRenderAndRestore
}
--]] -- end DISABLED Render & Restore entries
