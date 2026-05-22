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

local function paketti_hack_set_beatsync_lines(target_lines)
  if os.platform() == "WINDOWS" then
    renoise.app():show_status("PakettiHack: shell zip/unzip not wired for Windows yet")
    return
  end

  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr or #instr.samples == 0 then
    renoise.app():show_status("PakettiHack: no instrument/sample selected")
    return
  end
  local sample_idx = song.selected_sample_index
  if sample_idx < 1 then sample_idx = 1 end
  local sample = instr.samples[sample_idx]

  if type(target_lines) ~= "number" or target_lines < 1 or target_lines > 65535 then
    renoise.app():show_status("PakettiHack: target_lines out of range (1-65535)")
    return
  end
  target_lines = math.floor(target_lines)

  -- Force BeatSync on so the patched value has effect when reloaded
  if sample.beat_sync_enabled == false then
    sample.beat_sync_enabled = true
  end

  local instr_name = instr.name
  local sel_inst_idx = song.selected_instrument_index
  local sel_sample_idx = sample_idx

  local t0 = os.clock()
  local tmp_xrni = os.tmpname() .. ".xrni"
  local tmp_dir = tmp_xrni .. ".d"
  os.mkdir(tmp_dir)

  renoise.app():save_instrument(tmp_xrni)
  local t_saved = os.clock()

  local ok, err = paketti_hack_run_shell(string.format(
    'unzip -o -j %q Instrument.xml -d %q', tmp_xrni, tmp_dir))
  if not ok then
    renoise.app():show_status("PakettiHack: unzip failed - " .. tostring(err))
    return
  end
  local xml_path = tmp_dir .. "/Instrument.xml"

  local f = io.open(xml_path, "rb")
  if not f then renoise.app():show_status("PakettiHack: cannot read extracted XML") return end
  local xml = f:read("*a"); f:close()

  local count = 0
  local patched = false
  xml = xml:gsub("(<BeatSyncLines>)(%-?%d+)(</BeatSyncLines>)", function(open_tag, val, close_tag)
    count = count + 1
    if count == sel_sample_idx then
      patched = true
      return open_tag .. tostring(target_lines) .. close_tag
    end
    return open_tag .. val .. close_tag
  end)

  if not patched then
    renoise.app():show_status(string.format(
      "PakettiHack: no <BeatSyncLines> tag for sample %d (only %d found)", sel_sample_idx, count))
    return
  end

  local fo = io.open(xml_path, "wb")
  if not fo then renoise.app():show_status("PakettiHack: cannot write XML") return end
  fo:write(xml); fo:close()

  ok, err = paketti_hack_run_shell(string.format(
    'cd %q && zip -q %q Instrument.xml', tmp_dir, tmp_xrni))
  if not ok then
    renoise.app():show_status("PakettiHack: zip update failed - " .. tostring(err))
    return
  end

  renoise.app():load_instrument(tmp_xrni)
  local t_loaded = os.clock()

  -- Restore name + selection (load_instrument can rename based on filename)
  local reloaded = song.instruments[sel_inst_idx]
  if reloaded then
    reloaded.name = instr_name
  end
  song.selected_instrument_index = sel_inst_idx
  if sel_sample_idx <= #song.selected_instrument.samples then
    song.selected_sample_index = sel_sample_idx
  end

  -- Best-effort cleanup
  os.remove(xml_path)
  os.remove(tmp_xrni)

  renoise.app():show_status(string.format(
    "PakettiHack: BeatSyncLines=%d on sample %d (save %.0fms + load %.0fms = %.0fms)",
    target_lines, sel_sample_idx,
    (t_saved - t0) * 1000,
    (t_loaded - t_saved) * 1000,
    (t_loaded - t0) * 1000))
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
          original_lines = lines,
          had_sync = sample.beat_sync_enabled
        })
        sample.beat_sync_lines = 512
      end
    end
  end
  if #paketti_hack_save_restore_queue > 0 then
    renoise.app():show_status(string.format(
      "BeatSyncHack: clamped %d sample(s) to 512 for safe XRNS save (will restore after)",
      #paketti_hack_save_restore_queue))
  end
end

local function paketti_hack_on_did_save()
  if #paketti_hack_save_restore_queue == 0 then return end
  local song = renoise.song()
  if not song then
    paketti_hack_save_restore_queue = {}
    return
  end
  local restored = 0
  local sel_inst_before = song.selected_instrument_index
  local sel_sample_before = song.selected_sample_index
  for _, entry in ipairs(paketti_hack_save_restore_queue) do
    if song.instruments[entry.instr_idx]
      and song.instruments[entry.instr_idx].samples[entry.sample_idx] then
      song.selected_instrument_index = entry.instr_idx
      song.selected_sample_index = entry.sample_idx
      paketti_hack_set_beatsync_lines(entry.original_lines)
      restored = restored + 1
    end
  end
  song.selected_instrument_index = sel_inst_before
  if sel_sample_before <= #song.selected_instrument.samples then
    song.selected_sample_index = sel_sample_before
  end
  paketti_hack_save_restore_queue = {}
  renoise.app():show_status(string.format(
    "BeatSyncHack: restored %d sample(s) to hacked BeatSyncLines after save",
    restored))
end

if not renoise.tool().app_will_save_document_observable:has_notifier(paketti_hack_on_will_save) then
  renoise.tool().app_will_save_document_observable:add_notifier(paketti_hack_on_will_save)
end
if not renoise.tool().app_saved_document_observable:has_notifier(paketti_hack_on_did_save) then
  renoise.tool().app_saved_document_observable:add_notifier(paketti_hack_on_did_save)
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
