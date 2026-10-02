-- PakettiLoadSampleBrowser.lua
-- Impulse Tracker "Load Sample" screen for Renoise: a Canvas file browser that
-- lets you navigate folders, see a highlighted file's metadata + waveform, and
-- KEYJAZZ the file on the qwerty piano keyboard WITHOUT loading it into your song.
--
-- How the "loadless preview" works: highlighting a file loads it into a single
-- hidden scratch instrument (created at the end of the instrument list). The piano
-- keys trigger that scratch instrument via trigger_instrument_note_on, so you hear
-- the file during playback without disturbing your song. Nothing touches your real
-- instruments until you CONFIRM (Enter, or press the toggle shortcut again), which
-- loads the file fresh into the smart target slot with the Paketti default template
-- and returns you to the Pattern Editor. Esc cancels and deletes the scratch
-- instrument, leaving no residue.
--
-- Keys in dialog:
--   Up/Down         move the file cursor (loads the highlighted file for preview)
--   PageUp/PageDown jump a screenful
--   Enter / Return  on a folder: enter it; on a file: LOAD into target + return to Pattern Editor
--   Backspace / Left go up to the parent folder
--   Esc             cancel + unload (delete scratch instrument)
--   Piano keys      keyjazz the highlighted file (zsxdcvgbhnjm + 23 567 9 + qwertyuiop)
--   (the toggle shortcut pressed again also confirms-and-loads)

PakettiLoadSampleBrowser = {}

local SCRATCH_NAME = "~Paketti Preview (scratch)"

-- classic Impulse Tracker / Renoise computer-keyboard piano layout --------------
-- lower octave = transport.octave * 12
local PLSB_LOWER = {
  z = 0, s = 1, x = 2, d = 3, c = 4, v = 5, g = 6, b = 7, h = 8, n = 9, j = 10, m = 11,
  [","] = 12, l = 13, ["."] = 14, ["ö"] = 15, ["-"] = 16, ["ä"] = 17,
}
-- upper octave = (transport.octave + 1) * 12
local PLSB_UPPER = {
  q = 0, ["2"] = 1, w = 2, ["3"] = 3, e = 4, r = 5, ["5"] = 6, t = 7, ["6"] = 8,
  y = 9, ["7"] = 10, u = 11, i = 12, ["9"] = 13, o = 14, ["0"] = 15, p = 16,
  ["å"] = 17, ["´"] = 18, ["¨"] = 18,
}

-- extensions load_from() can decode directly (for the scratch preview). Non-native
-- formats (.mod/.rex/.rx2/.iff ...) still appear in the list and still load on
-- confirm (via PakettiExpandLoadableFiles), they just can't be keyjazzed live.
local PLSB_NATIVE = { wav=true, aif=true, aiff=true, flac=true, ogg=true, mp3=true,
  raw=true, snd=true, caf=true, au=true, wv=true, voc=true, w64=true, aifc=true }

-- module state ----------------------------------------------------------------
local S = {
  dialog = nil,
  vb = nil,
  canvas_id = nil,
  current_dir = nil,
  entries = {},          -- { {kind="updir"/"dir"/"file", name=, path=}, ... }
  selected = 1,
  scroll = 0,
  scratch_index = nil,
  loaded_path = nil,
  preview_ok = false,
  meta = {},
  peaks = nil,           -- { ch1 = {{min,max},...}, ch2 = {...} or nil }
  active_notes = {},     -- key_name -> note value
}

local CANVAS_W = 900
local CANVAS_H = 600
local ROW_H = 15
local LIST_Y = 36
local VISIBLE_ROWS = math.floor((CANVAS_H - LIST_Y - 10) / ROW_H)
local LIST_NUM_X = 8
local LIST_TXT_X = 52
local LIST_RIGHT = 500
local PANEL_X = 524
local FONT = 8
local CHAR_W = FONT * 1.4

-- colors
local COL_BG = {12, 16, 20, 255}
local COL_DIR = {90, 220, 120, 255}
local COL_FILE = {210, 220, 225, 255}
local COL_SEL_BG = {210, 220, 225, 255}
local COL_SEL_FG = {12, 16, 20, 255}
local COL_LABEL = {150, 190, 210, 255}
local COL_VALUE = {230, 235, 120, 255}
local COL_WAVE = {90, 220, 120, 255}
local COL_FRAME = {70, 90, 100, 255}

-- helpers ---------------------------------------------------------------------
local function plsb_sep()
  return (os.platform() == "WINDOWS") and "\\" or "/"
end

local function plsb_join(dir, name)
  local sep = plsb_sep()
  if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then return dir .. name end
  return dir .. sep .. name
end

local function plsb_parent(dir)
  -- strip trailing sep then last component
  local d = dir:gsub("[/\\]+$", "")
  local parent = d:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    -- top of a drive / filesystem root
    if os.platform() == "WINDOWS" then
      local drive = d:match("^(%a:)")
      return drive and (drive .. "\\") or d
    end
    return "/"
  end
  if os.platform() ~= "WINDOWS" and not parent:match("^/") then parent = "/" .. parent end
  return parent
end

local function plsb_basename(path)
  return path:match("[^/\\]+$") or path
end

local function plsb_ext(name)
  local e = name:match("%.([%w_]+)$")
  return e and e:lower() or ""
end

local function plsb_home()
  local h = os.getenv("HOME") or os.getenv("USERPROFILE")
  if h and io.exists(h) then return h end
  return (os.platform() == "WINDOWS") and "C:\\" or "/"
end

local function plsb_start_dir()
  local pref = (preferences and preferences.pakettiLoadSampleBrowserLastDir
    and preferences.pakettiLoadSampleBrowserLastDir.value) or ""
  if pref ~= "" and io.exists(pref) then return pref end
  return plsb_home()
end

-- format strings for the IT-style panel
local function plsb_pad(n, width)
  local s = tostring(math.floor(n or 0))
  while #s < width do s = "0" .. s end
  return s
end

local function plsb_format_for_ext(ext)
  local map = {
    wav = "IBM/Microsoft RIFF", w64 = "Sony Wave64", aif = "Apple/SGI AIFF",
    aiff = "Apple/SGI AIFF", aifc = "Apple/SGI AIFF-C", flac = "FLAC",
    ogg = "Ogg Vorbis", mp3 = "MPEG Layer-3", caf = "Apple CoreAudio",
    au = "Sun/NeXT AU", voc = "Creative VOC", snd = "Raw/SND", raw = "Raw PCM",
    mod = "ProTracker MOD", rex = "ReCycle REX", rx2 = "ReCycle RX2",
    iff = "Amiga IFF/8SVX", ["8svx"] = "Amiga IFF/8SVX", wv = "WavPack",
  }
  return map[ext] or (ext ~= "" and (ext:upper() .. " file") or "Unknown")
end

local function plsb_loop_mode_name(mode)
  if mode == renoise.Sample.LOOP_MODE_FORWARD then return "Forward" end
  if mode == renoise.Sample.LOOP_MODE_REVERSE then return "Backward" end
  if mode == renoise.Sample.LOOP_MODE_PING_PONG then return "PingPong" end
  return "Off"
end

-- scratch instrument ----------------------------------------------------------
local function plsb_cleanup_scratch()
  local song = renoise.song()
  if not song then return end
  -- remove ANY leftover scratch instruments by name (self-healing)
  for i = #song.instruments, 1, -1 do
    if song.instruments[i].name == SCRATCH_NAME then
      pcall(function() song:delete_instrument_at(i) end)
    end
  end
  S.scratch_index = nil
  S.loaded_path = nil
  S.preview_ok = false
  S.peaks = nil
  S.meta = {}
end

local function plsb_ensure_scratch()
  local song = renoise.song()
  if S.scratch_index and song.instruments[S.scratch_index]
    and song.instruments[S.scratch_index].name == SCRATCH_NAME then
    return S.scratch_index
  end
  local idx = #song.instruments + 1
  song:insert_instrument_at(idx)
  local instr = song.instruments[idx]
  instr.name = SCRATCH_NAME
  if #instr.samples == 0 then instr:insert_sample_at(1) end
  S.scratch_index = idx
  return idx
end

local function plsb_safe_track_index()
  local song = renoise.song()
  local ti = song.selected_track_index
  if song.tracks[ti] and song.tracks[ti].type == renoise.Track.TRACK_TYPE_SEQUENCER then
    return ti
  end
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then return i end
  end
  return 1
end

-- waveform peaks: sample a bounded subset per pixel column so big files stay fast
local function plsb_compute_peaks(buffer, pixel_width)
  local chans = buffer.number_of_channels
  local frames = buffer.number_of_frames
  if frames < 1 or pixel_width < 1 then return nil end
  local result = {}
  local max_probe = 24  -- frames sampled per column, capped
  for ch = 1, math.min(chans, 2) do
    local col = {}
    for px = 0, pixel_width - 1 do
      local f0 = math.floor(px * frames / pixel_width) + 1
      local f1 = math.floor((px + 1) * frames / pixel_width)
      if f1 < f0 then f1 = f0 end
      if f1 > frames then f1 = frames end
      local span = f1 - f0 + 1
      local step = math.max(1, math.floor(span / max_probe))
      local mn, mx = 1.0, -1.0
      local f = f0
      while f <= f1 do
        local v = buffer:sample_data(ch, f)
        if v < mn then mn = v end
        if v > mx then mx = v end
        f = f + step
      end
      if mn > mx then mn, mx = 0, 0 end
      col[px + 1] = { mn, mx }
    end
    result[ch] = col
  end
  return result
end

-- load the highlighted file into the scratch instrument for preview
local function plsb_preview_selected()
  S.preview_ok = false
  S.peaks = nil
  S.meta = {}
  local e = S.entries[S.selected]
  if not e or e.kind ~= "file" then S.loaded_path = nil; return end
  S.loaded_path = e.path
  local ext = plsb_ext(e.name)

  -- file-level metadata (best effort)
  local meta = { name = e.name, format = plsb_format_for_ext(ext), size = nil, date = nil }
  local ok_stat, st = pcall(function() return io.stat(e.path) end)
  if ok_stat and st then
    if st.size then meta.size = st.size end
    if st.mtime then
      meta.date = os.date("%B %d, %Y", st.mtime)
      meta.time = os.date("%I:%M%p", st.mtime)
    end
  end
  S.meta = meta

  if not PLSB_NATIVE[ext] then
    -- non-native: list + confirm-load supported, but no live preview/waveform
    S.meta.note = "Preview N/A - press Enter to load"
    if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
    return
  end

  local idx = plsb_ensure_scratch()
  local song = renoise.song()
  local sample = song.instruments[idx].samples[1]
  local loaded = false
  pcall(function() loaded = sample.sample_buffer:load_from(e.path) end)
  if loaded and sample.sample_buffer.has_sample_data then
    local buf = sample.sample_buffer
    sample.name = e.name
    S.preview_ok = true
    S.meta.sample_rate = buf.sample_rate
    S.meta.bit_depth = buf.bit_depth
    S.meta.channels = buf.number_of_channels
    S.meta.frames = buf.number_of_frames
    S.meta.loop_mode = plsb_loop_mode_name(sample.loop_mode)
    S.meta.loop_start = sample.loop_start
    S.meta.loop_end = sample.loop_end
    S.peaks = plsb_compute_peaks(buf, 300)
  else
    S.meta.note = "Could not decode for preview"
  end
  if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
end

-- directory listing -----------------------------------------------------------
local function plsb_rebuild_entries()
  S.entries = {}
  local dir = S.current_dir
  -- up-dir entry (unless at a filesystem root)
  local parent = plsb_parent(dir)
  if parent ~= dir then
    S.entries[#S.entries + 1] = { kind = "updir", name = "..", path = parent }
  end
  -- directories
  local ok_dirs, dirs = pcall(function() return os.dirnames(dir) end)
  if ok_dirs and dirs then
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    for _, d in ipairs(dirs) do
      S.entries[#S.entries + 1] = { kind = "dir", name = d, path = plsb_join(dir, d) }
    end
  end
  -- files (loadable extensions)
  local patterns = { "*" }
  local ok_pat, p = pcall(function() return PakettiLoadableExtensions() end)
  if ok_pat and p then patterns = p end
  local ok_files, files = pcall(function() return os.filenames(dir, patterns) end)
  if ok_files and files then
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    for _, f in ipairs(files) do
      S.entries[#S.entries + 1] = { kind = "file", name = f, path = plsb_join(dir, f) }
    end
  end
  S.selected = 1
  S.scroll = 0
  plsb_preview_selected()
end

local function plsb_enter_dir(path)
  if io.exists(path) then
    S.current_dir = path
    plsb_rebuild_entries()
  end
end

local function plsb_adjust_scroll()
  if S.selected < S.scroll + 1 then S.scroll = S.selected - 1 end
  if S.selected > S.scroll + VISIBLE_ROWS then S.scroll = S.selected - VISIBLE_ROWS end
  if S.scroll < 0 then S.scroll = 0 end
end

-- rendering -------------------------------------------------------------------
local function plsb_text(ctx, color, text, x, y)
  ctx.stroke_color = color
  ctx.fill_color = color
  ctx.line_width = 1
  PakettiCanvasFontDrawText(ctx, text, x, y, FONT)
end

local function plsb_truncate(text, max_px)
  local max_chars = math.floor(max_px / CHAR_W)
  if #text <= max_chars then return text end
  if max_chars <= 1 then return text:sub(1, 1) end
  return text:sub(1, max_chars - 1) .. "~"
end

local function plsb_draw_meta(ctx)
  local m = S.meta
  local lx = PANEL_X
  local vx = PANEL_X + 160
  local y = LIST_Y
  local function row(label, value, is_val)
    plsb_text(ctx, COL_LABEL, label, lx, y)
    if value ~= nil then plsb_text(ctx, is_val and COL_VALUE or COL_FILE, value, vx, y) end
    y = y + ROW_H
  end
  row("FILENAME", plsb_truncate(m.name or "-", 200), true)
  if S.preview_ok then
    row("SPEED", plsb_pad(m.sample_rate, 7), true)
    row("LOOP", m.loop_mode or "Off", true)
    row("LOOPBEG", plsb_pad(m.loop_start, 7), true)
    row("LOOPEND", plsb_pad(m.loop_end, 7), true)
    row("QUALITY", tostring(m.bit_depth or 0) .. " bit " ..
      ((m.channels == 2) and "Stereo" or "Mono"), true)
    row("LENGTH", plsb_pad(m.frames, 7), true)
  elseif m.note then
    row(m.note, nil)
  end

  -- waveform strips
  local wy = LIST_Y + 9 * ROW_H
  local ww = CANVAS_W - PANEL_X - 20
  local wx = PANEL_X
  ctx.stroke_color = COL_FRAME
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(wx, wy, ww, 110); ctx:stroke()
  if S.peaks and S.preview_ok then
    local n = #S.peaks
    local lanes = math.min(n, 2)
    local lane_h = 110 / lanes
    ctx.stroke_color = COL_WAVE
    for ch = 1, lanes do
      local base = wy + (ch - 1) * lane_h + lane_h / 2
      local col = S.peaks[ch]
      local pw = #col
      ctx:begin_path()
      for px = 1, pw do
        local x = wx + (px - 1) * (ww / pw)
        local mn = col[px][1]
        local mx = col[px][2]
        ctx:move_to(x, base - mx * (lane_h / 2 - 2))
        ctx:line_to(x, base - mn * (lane_h / 2 - 2))
      end
      ctx:stroke()
    end
  end

  -- footer: format / size / date / time
  local fy = wy + 120
  local function frow(label, value)
    plsb_text(ctx, COL_LABEL, label, lx, fy)
    if value then plsb_text(ctx, COL_VALUE, value, vx, fy) end
    fy = fy + ROW_H
  end
  frow("FORMAT", plsb_truncate(m.format or "-", 200))
  frow("SIZE", m.size and tostring(m.size) or "-")
  frow("DATE", m.date or "-")
  frow("TIME", m.time or "-")

  -- octave hint
  local oct = renoise.song() and renoise.song().transport.octave or 0
  plsb_text(ctx, COL_LABEL, "KEYJAZZ OCT " .. tostring(oct), lx, fy + ROW_H)
end

local function plsb_render(ctx)
  ctx:clear_rect(0, 0, CANVAS_W, CANVAS_H)
  ctx.fill_color = COL_BG
  ctx:begin_path(); ctx:rect(0, 0, CANVAS_W, CANVAS_H); ctx:fill()

  -- title
  plsb_text(ctx, COL_LABEL, "LOAD SAMPLE", CANVAS_W / 2 - 60, 10)
  -- current dir
  plsb_text(ctx, COL_FILE, plsb_truncate(S.current_dir or "", LIST_RIGHT - LIST_NUM_X), LIST_NUM_X, 22)

  -- file list
  for r = 1, VISIBLE_ROWS do
    local i = S.scroll + r
    local e = S.entries[i]
    if e then
      local y = LIST_Y + (r - 1) * ROW_H
      local selected = (i == S.selected)
      if selected then
        ctx.fill_color = COL_SEL_BG
        ctx:begin_path(); ctx:rect(LIST_NUM_X - 2, y - 1, LIST_RIGHT - LIST_NUM_X, ROW_H); ctx:fill()
      end
      local num_col = selected and COL_SEL_FG or COL_LABEL
      plsb_text(ctx, num_col, plsb_pad(i, 3), LIST_NUM_X, y)
      local label
      local col
      if e.kind == "updir" then
        label = ".. (up)"; col = COL_DIR
      elseif e.kind == "dir" then
        label = e.name .. "/"; col = COL_DIR
      else
        label = e.name; col = COL_FILE
      end
      if selected then col = COL_SEL_FG end
      plsb_text(ctx, col, plsb_truncate(label, LIST_RIGHT - LIST_TXT_X), LIST_TXT_X, y)
    end
  end

  -- vertical divider
  ctx.stroke_color = COL_FRAME
  ctx.line_width = 1
  ctx:begin_path(); ctx:move_to(LIST_RIGHT + 8, LIST_Y - 6); ctx:line_to(LIST_RIGHT + 8, CANVAS_H - 6); ctx:stroke()

  plsb_draw_meta(ctx)
end

-- keyjazz ---------------------------------------------------------------------
local function plsb_key_to_note(key_name)
  if not key_name then return nil end
  local song = renoise.song()
  local oct = song.transport.octave or 4
  local off = PLSB_LOWER[key_name]
  if off ~= nil then
    local n = oct * 12 + off
    if n < 0 then n = 0 elseif n > 119 then n = 119 end
    return n
  end
  off = PLSB_UPPER[key_name]
  if off ~= nil then
    local n = (oct + 1) * 12 + off
    if n < 0 then n = 0 elseif n > 119 then n = 119 end
    return n
  end
  return nil
end

local function plsb_note_on(key_name)
  if not S.preview_ok or not S.scratch_index then return false end
  if S.active_notes[key_name] then return true end
  local note = plsb_key_to_note(key_name)
  if not note then return false end
  local song = renoise.song()
  if not song.instruments[S.scratch_index] then return false end
  local ti = plsb_safe_track_index()
  pcall(function()
    song:trigger_instrument_note_on(S.scratch_index, ti, { note }, 1.0)
  end)
  S.active_notes[key_name] = note
  return true
end

local function plsb_note_off(key_name)
  local note = S.active_notes[key_name]
  if not note then return false end
  local song = renoise.song()
  local ti = plsb_safe_track_index()
  if S.scratch_index and song.instruments[S.scratch_index] then
    pcall(function()
      song:trigger_instrument_note_off(S.scratch_index, ti, { note })
    end)
  end
  S.active_notes[key_name] = nil
  return true
end

local function plsb_all_notes_off()
  for k, _ in pairs(S.active_notes) do plsb_note_off(k) end
  S.active_notes = {}
end

-- open / confirm / close ------------------------------------------------------
function PakettiLoadSampleBrowser_Close(cancelled)
  plsb_all_notes_off()
  if cancelled then plsb_cleanup_scratch() end
  if S.dialog and S.dialog.visible then
    S.dialog:close()
  end
  S.dialog = nil
end

function PakettiLoadSampleBrowser_Confirm()
  local path = S.loaded_path
  if not path then
    renoise.app():show_status("Paketti Load Sample: no file selected")
    return
  end
  plsb_all_notes_off()

  -- expand non-native formats to real audio (temp wavs)
  local realpath = path
  local temps = {}
  local ext = plsb_ext(path)
  if not PLSB_NATIVE[ext] then
    local ok, expanded, tmp = pcall(function() return PakettiExpandLoadableFiles({ path }) end)
    if ok and expanded and #expanded > 0 then
      realpath = expanded[1]
      temps = tmp or {}
    end
  end

  -- remove the scratch instrument BEFORE picking a target (so it isn't a candidate)
  plsb_cleanup_scratch()

  local song = renoise.song()
  local function is_empty(inst)
    return #inst.samples == 0 and not inst.plugin_properties.plugin_loaded
  end
  local tgt = nil
  local sel = song.selected_instrument_index
  if song.instruments[sel] and is_empty(song.instruments[sel]) then
    tgt = sel
  else
    for i = 1, #song.instruments do
      if is_empty(song.instruments[i]) then tgt = i break end
    end
  end
  if not tgt then
    if not safeInsertInstrumentAt(song, #song.instruments + 1) then
      renoise.app():show_status("Paketti Load Sample: could not create instrument slot")
      return
    end
    tgt = #song.instruments
  end
  song.selected_instrument_index = tgt

  -- load the Paketti default instrument template into the target slot
  pakettiPreferencesDefaultInstrumentLoader()
  tgt = song.selected_instrument_index
  local instr = song.instruments[tgt]
  local sample = instr.samples[1]
  if not sample then
    instr:insert_sample_at(1)
    sample = instr.samples[1]
  end
  local base = plsb_basename(path)
  local loaded = false
  pcall(function() loaded = sample.sample_buffer:load_from(realpath) end)
  sample.name = base
  instr.name = string.format("%02X_", tgt - 1) .. base
  if loaded then
    pcall(function() PakettiInjectApplyLoaderSettings(sample) end)
    renoise.app():show_status("Loaded " .. base .. " into instrument " .. string.format("%02X", tgt - 1))
  else
    renoise.app():show_status("Paketti Load Sample: failed to load " .. base)
  end

  pcall(function() PakettiExpandLoadableCleanup(temps) end)

  -- remember last folder
  if preferences and preferences.pakettiLoadSampleBrowserLastDir then
    preferences.pakettiLoadSampleBrowserLastDir.value = S.current_dir or ""
    preferences:save_as("preferences.xml")
  end

  PakettiLoadSampleBrowser_Close(false)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function plsb_activate_entry()
  local e = S.entries[S.selected]
  if not e then return end
  if e.kind == "updir" or e.kind == "dir" then
    plsb_enter_dir(e.path)
    if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
  else
    PakettiLoadSampleBrowser_Confirm()
  end
end

local function plsb_move(delta)
  if #S.entries == 0 then return end
  plsb_all_notes_off()
  S.selected = S.selected + delta
  if S.selected < 1 then S.selected = 1 end
  if S.selected > #S.entries then S.selected = #S.entries end
  plsb_adjust_scroll()
  plsb_preview_selected()
  if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
end

local function plsb_key_handler(dialog, key)
  local name = key.name

  -- key releases: stop keyjazz notes
  if key.state == "released" then
    if name and (PLSB_LOWER[name] ~= nil or PLSB_UPPER[name] ~= nil) then
      plsb_note_off(name)
      return nil
    end
    return nil
  end

  -- navigation + actions (not key-repeat sensitive except arrows)
  if name == "esc" then
    PakettiLoadSampleBrowser_Close(true)
    return nil
  elseif name == "return" then
    plsb_activate_entry()
    return nil
  elseif name == "up" then
    plsb_move(-1); return nil
  elseif name == "down" then
    plsb_move(1); return nil
  elseif name == "prior" then       -- Page Up
    plsb_move(-VISIBLE_ROWS); return nil
  elseif name == "next" then        -- Page Down
    plsb_move(VISIBLE_ROWS); return nil
  elseif name == "left" or name == "back" then
    local parent = plsb_parent(S.current_dir)
    if parent ~= S.current_dir then plsb_enter_dir(parent)
      if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
    end
    return nil
  elseif name == "right" then
    local e = S.entries[S.selected]
    if e and (e.kind == "dir" or e.kind == "updir") then plsb_enter_dir(e.path)
      if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
    end
    return nil
  end

  -- keyjazz piano keys (consume so they don't type / navigate)
  if name and (PLSB_LOWER[name] ~= nil or PLSB_UPPER[name] ~= nil) then
    if not key.repeated then plsb_note_on(name) end
    return nil
  end

  -- everything else passes through to Renoise so the user's toggle shortcut
  -- (pressed again) confirms-and-loads, and other global shortcuts still work
  return key
end

local function plsb_mouse_handler(ev)
  if ev.type ~= "down" then return end
  local x = ev.position.x
  local y = ev.position.y
  if x < LIST_NUM_X - 2 or x > LIST_RIGHT then return end
  if y < LIST_Y - 1 then return end
  local r = math.floor((y - (LIST_Y - 1)) / ROW_H) + 1
  local i = S.scroll + r
  if i < 1 or i > #S.entries then return end
  if ev.button == "left" then
    if i == S.selected then
      plsb_activate_entry()
    else
      plsb_all_notes_off()
      S.selected = i
      plsb_adjust_scroll()
      plsb_preview_selected()
      if S.canvas_id and S.vb and S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
    end
  end
end

function PakettiLoadSampleBrowser_Open()
  if not renoise.song() then
    renoise.app():show_status("Paketti Load Sample: no song")
    return
  end
  if S.dialog and S.dialog.visible then
    S.dialog:show()
    return
  end
  plsb_cleanup_scratch()
  S.active_notes = {}
  S.current_dir = plsb_start_dir()

  local vb = renoise.ViewBuilder()
  S.vb = vb
  S.canvas_id = "plsb_canvas"
  local content = vb:column {
    vb:canvas {
      id = S.canvas_id,
      width = CANVAS_W,
      height = CANVAS_H,
      mode = "plain",
      render = plsb_render,
      mouse_handler = plsb_mouse_handler,
      mouse_events = { "down" },
    },
  }

  plsb_rebuild_entries()

  local key_opts = { send_key_repeat = true, send_key_release = true }
  S.dialog = renoise.app():show_custom_dialog("Paketti Load Sample (Keyjazz Preview)",
    content, plsb_key_handler, key_opts)
  if S.vb.views[S.canvas_id] then S.vb.views[S.canvas_id]:invalidate() end
end

function PakettiLoadSampleBrowserToggle()
  if S.dialog and S.dialog.visible then
    PakettiLoadSampleBrowser_Confirm()
  else
    PakettiLoadSampleBrowser_Open()
  end
end

-- registrations ---------------------------------------------------------------
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:Load Sample (Keyjazz Preview)",
  invoke=function() PakettiLoadSampleBrowserToggle() end}
PakettiAddMenuEntry{name="Sample Navigator:Paketti:Load Sample (Keyjazz Preview)",
  invoke=function() PakettiLoadSampleBrowserToggle() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Load Sample Browser Keyjazz Preview",
  invoke = function() PakettiLoadSampleBrowserToggle() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Load Sample Browser Keyjazz Preview",
  invoke = function(message) if message:is_trigger() then PakettiLoadSampleBrowserToggle() end end
}
