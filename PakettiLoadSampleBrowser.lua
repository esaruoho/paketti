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
--   Mod+Up/Down     any modifier (Cmd/Option/Shift/Ctrl) + Up/Down jumps to top/bottom
--   PageUp/PageDown jump a screenful
--   Enter / Return  on a folder: enter it; on a file: LOAD into target + return to Pattern Editor
--   Backspace / Left go up to the parent folder
--   Esc             cancel + unload (delete scratch instrument)
--   F1-F12          jump to folder preset N; Shift+F1-F12 stores the current folder as preset N
--   Piano keys      keyjazz the highlighted file (zsxdcvgbhnjm + 23 567 9 + qwertyuiop)
--   (the toggle shortcut pressed again confirms-and-loads, or just closes if not on a file)
--
-- The folder you are in is remembered (and becomes the default next time); if it has
-- since been deleted it reverts to ~/Music/Samples. The first time you ever open the
-- dialog it asks you to pick a default folder. The highlighted file is remembered too,
-- so reopening lands you back where you were (clamped if the folder now has fewer files).

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
  dir_id = nil, list_id = nil, meta_id = nil, wave_id = nil,
  octave_notifier = nil,
  doc_notifier = nil,
}

-- forward declaration: refreshes the text widgets + waveform canvas (defined below,
-- but called by functions above its definition)
local plsb_refresh

-- The list / path / metadata are normal Renoise text widgets; only the waveform
-- is drawn on a Canvas.
local VISIBLE_ROWS = 28     -- number of file-list rows shown at once
local LIST_ROW_H = 16       -- pixel height of one list row
local LIST_FONT = 9         -- canvas font size for list rows
local LIST_CHAR_W = LIST_FONT * 1.4
local LIST_CANVAS_W = 560
local LIST_CANVAS_H = VISIBLE_ROWS * LIST_ROW_H
local META_W = 340
local META_H = 170
local WAVE_W = 340
local WAVE_H = 150

-- waveform canvas colors
local COL_BG = {18, 22, 26, 255}
local COL_WAVE = {90, 220, 120, 255}
local COL_FRAME = {70, 90, 100, 255}
local COL_ZERO = {50, 64, 72, 255}

-- file-list canvas colors (inverted selection bar, like Impulse Tracker)
local COL_LIST_BG = {0, 0, 0, 255}          -- black background
local COL_LIST_TEXT = {235, 235, 235, 255}  -- white text (files)
local COL_LIST_DIR = {150, 220, 150, 255}   -- green text (folders)
local COL_SEL_BG = {232, 232, 214, 255}     -- selected row: cream/white bar
local COL_SEL_FG = {0, 0, 0, 255}           -- selected row: black text

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

-- Split a filename into { base, extra, ext } so the base left-aligns and the
-- "extra data" (a trailing YYYY-MM-DD HHMMSS timestamp, plus the extension) can
-- be shown right-aligned in its own column. Degrades to { name, "", ext }.
local function plsb_split_file(name)
  local stem, ext = name:match("^(.*)%.([%w]+)$")
  if not stem then stem = name; ext = "" end
  local base, date, time = stem:match("^(.-)%s+(%d%d%d%d%-%d%d%-%d%d)%s+([%d]+)$")
  if base and base ~= "" then
    return base, (date .. " " .. time), ext
  end
  return stem, "", ext
end

local function plsb_home()
  local h = os.getenv("HOME") or os.getenv("USERPROFILE")
  if h and io.exists(h) then return h end
  return (os.platform() == "WINDOWS") and "C:\\" or "/"
end

-- sensible sample folder under the user's home, falling back to home
local function plsb_fallback_dir()
  local home = plsb_home()
  local sep = plsb_sep()
  local candidates = {
    home .. sep .. "Music" .. sep .. "Samples",
    home .. sep .. "Music" .. sep .. "samples",
    home .. sep .. "Samples",
    home .. sep .. "samples",
    home .. sep .. "Music",
    home .. sep .. "Documents",
  }
  for _, c in ipairs(candidates) do
    if io.exists(c) then return c end
  end
  return home
end

local function plsb_save_dir(dir)
  if preferences and preferences.pakettiLoadSampleBrowserLastDir then
    preferences.pakettiLoadSampleBrowserLastDir.value = dir or ""
    preferences:save_as("preferences.xml")
  end
end

-- Resolve the folder to open in:
--  * last folder, if it still exists
--  * if the saved folder is GONE, silently revert to ~/Music/Samples (no prompt)
--  * if nothing was ever saved (first boot), ask the user to pick a default folder
local function plsb_resolve_start_dir()
  local pref = (preferences and preferences.pakettiLoadSampleBrowserLastDir
    and preferences.pakettiLoadSampleBrowserLastDir.value) or ""
  if pref ~= "" then
    if io.exists(pref) then return pref end
    return plsb_fallback_dir()
  end
  -- first boot: ask for a folder
  local chosen = ""
  local ok, p = pcall(function()
    return renoise.app():prompt_for_path("Choose your default sample folder")
  end)
  if ok and p and p ~= "" and io.exists(p) then chosen = p end
  if chosen ~= "" then
    plsb_save_dir(chosen)
    return chosen
  end
  return plsb_fallback_dir()
end

-- 12 folder presets (F1-F12), stored newline-separated in one preference
local function plsb_get_presets()
  local raw = (preferences and preferences.pakettiLoadSampleBrowserPresets
    and preferences.pakettiLoadSampleBrowserPresets.value) or ""
  local t = {}
  for line in (raw .. "\n"):gmatch("(.-)\n") do t[#t + 1] = line end
  for i = 1, 12 do if t[i] == nil then t[i] = "" end end
  return t
end

local function plsb_set_preset(n, path)
  local t = plsb_get_presets()
  t[n] = path or ""
  if preferences and preferences.pakettiLoadSampleBrowserPresets then
    preferences.pakettiLoadSampleBrowserPresets.value = table.concat(t, "\n", 1, 12)
    preferences:save_as("preferences.xml")
  end
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
    if plsb_refresh then plsb_refresh() end
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
  if plsb_refresh then plsb_refresh() end
end

-- directory listing -----------------------------------------------------------
local function plsb_adjust_scroll()
  if S.selected < S.scroll + 1 then S.scroll = S.selected - 1 end
  if S.selected > S.scroll + VISIBLE_ROWS then S.scroll = S.selected - VISIBLE_ROWS end
  if S.scroll < 0 then S.scroll = 0 end
end

local function plsb_rebuild_entries(select_name)
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
  -- optionally land the cursor on a named entry (e.g. the folder we just came up from)
  if select_name and select_name ~= "" then
    for i, e in ipairs(S.entries) do
      if e.name == select_name then S.selected = i break end
    end
  end
  S.scroll = 0
  plsb_adjust_scroll()
  plsb_preview_selected()
end

local function plsb_enter_dir(path, select_name)
  if io.exists(path) then
    S.current_dir = path
    plsb_rebuild_entries(select_name)
    plsb_save_dir(path)   -- navigating updates the saved default folder
  end
end

-- rendering -------------------------------------------------------------------
local function plsb_set_color(ctx, c)
  ctx.stroke_color = c
  ctx.fill_color = c
  ctx.line_width = 1
end

-- the file list, drawn on a canvas so the selected row is a full inverted bar
-- (black bg / white text normally; white bar / black text when selected)
local function plsb_list_render(ctx)
  ctx:clear_rect(0, 0, LIST_CANVAS_W, LIST_CANVAS_H)
  ctx.fill_color = COL_LIST_BG
  ctx:begin_path(); ctx:rect(0, 0, LIST_CANVAS_W, LIST_CANVAS_H); ctx:fill()

  for r = 1, VISIBLE_ROWS do
    local i = S.scroll + r
    local e = S.entries[i]
    if e then
      local ytop = (r - 1) * LIST_ROW_H
      local ytext = ytop + 3
      local selected = (i == S.selected)
      if selected then
        ctx.fill_color = COL_SEL_BG
        ctx:begin_path(); ctx:rect(0, ytop, LIST_CANVAS_W, LIST_ROW_H); ctx:fill()
      end
      local left, right, isdir
      if e.kind == "updir" then
        left = ".. (up)"; right = ""; isdir = true
      elseif e.kind == "dir" then
        left = e.name; right = "<DIR>"; isdir = true
      else
        local base, extra, ext = plsb_split_file(e.name)
        left = base
        right = (extra ~= "" and (extra .. "  ") or "") .. (ext ~= "" and ("." .. ext:upper()) or "")
        isdir = false
      end
      local textcol = selected and COL_SEL_FG or (isdir and COL_LIST_DIR or COL_LIST_TEXT)
      -- right-aligned extra column (fixed position so <DIR> never shifts)
      local extra_w = #right * LIST_CHAR_W
      local extra_x = LIST_CANVAS_W - extra_w - 6
      -- truncate the name so it never collides with the extra column
      local name_limit_px = (right ~= "" and (extra_x - 8) or LIST_CANVAS_W) - 6
      local max_chars = math.max(1, math.floor(name_limit_px / LIST_CHAR_W))
      if #left > max_chars then
        left = (max_chars > 1) and (left:sub(1, max_chars - 1) .. "~") or left:sub(1, 1)
      end
      plsb_set_color(ctx, textcol)
      PakettiCanvasFontDrawText(ctx, left, 6, ytext, LIST_FONT)
      if right ~= "" then PakettiCanvasFontDrawText(ctx, right, extra_x, ytext, LIST_FONT) end
    end
  end
end

-- The waveform of the previewed sample.
local function plsb_wave_render(ctx)
  ctx:clear_rect(0, 0, WAVE_W, WAVE_H)
  ctx.fill_color = COL_BG
  ctx:begin_path(); ctx:rect(0, 0, WAVE_W, WAVE_H); ctx:fill()
  ctx.stroke_color = COL_FRAME
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(0, 0, WAVE_W, WAVE_H); ctx:stroke()

  if not (S.peaks and S.preview_ok) then return end
  local lanes = math.min(#S.peaks, 2)
  if lanes < 1 then return end
  local lane_h = WAVE_H / lanes
  for ch = 1, lanes do
    local base = (ch - 1) * lane_h + lane_h / 2
    -- zero line
    ctx.stroke_color = COL_ZERO
    ctx:begin_path(); ctx:move_to(0, base); ctx:line_to(WAVE_W, base); ctx:stroke()
    -- peaks
    local col = S.peaks[ch]
    local pw = #col
    ctx.stroke_color = COL_WAVE
    ctx:begin_path()
    for px = 1, pw do
      local x = (px - 1) * (WAVE_W / pw)
      local mn = col[px][1]
      local mx = col[px][2]
      ctx:move_to(x, base - mx * (lane_h / 2 - 2))
      ctx:line_to(x, base - mn * (lane_h / 2 - 2))
    end
    ctx:stroke()
  end
end


-- the human-readable metadata block (plain text, not canvas font)
local function plsb_meta_string()
  local m = S.meta
  local e = S.entries[S.selected]
  local oct = (renoise.song() and renoise.song().transport.octave) or 0
  if not e then return "No file selected\n\nKeyjazz octave: " .. oct end
  if e.kind ~= "file" then
    return (e.kind == "updir" and ".. (parent folder)" or ("Folder: " .. e.name))
      .. "\n\nEnter to open\n\nKeyjazz octave: " .. oct
  end
  local lines = {}
  lines[#lines + 1] = "Filename:    " .. (m.name or "-")
  lines[#lines + 1] = "Format:      " .. (m.format or "-")
  if S.preview_ok then
    lines[#lines + 1] = "Sample rate: " .. tostring(m.sample_rate or 0) .. " Hz"
    lines[#lines + 1] = "Quality:     " .. tostring(m.bit_depth or 0) .. " bit "
      .. ((m.channels == 2) and "Stereo" or "Mono")
    lines[#lines + 1] = "Length:      " .. tostring(m.frames or 0) .. " frames"
    lines[#lines + 1] = "Loop:        " .. (m.loop_mode or "Off")
      .. ((m.loop_mode and m.loop_mode ~= "Off")
        and ("  (" .. tostring(m.loop_start or 0) .. " - " .. tostring(m.loop_end or 0) .. ")") or "")
  elseif m.note then
    lines[#lines + 1] = "Preview:     " .. m.note
  end
  if m.size then lines[#lines + 1] = "Size:        " .. tostring(m.size) .. " bytes" end
  if m.date then lines[#lines + 1] = "Date:        " .. m.date .. (m.time and ("  " .. m.time) or "") end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Keyjazz octave: " .. oct
  return table.concat(lines, "\n")
end

-- refresh the text widgets + waveform canvas (assigned to the forward-declared local)
plsb_refresh = function()
  if not S.vb then return end
  local v = S.vb.views
  if S.dir_id and v[S.dir_id] then v[S.dir_id].text = S.current_dir or "" end
  if S.list_id and v[S.list_id] then v[S.list_id]:update() end
  if S.meta_id and v[S.meta_id] then v[S.meta_id].text = plsb_meta_string() end
  if S.wave_id and v[S.wave_id] then v[S.wave_id]:update() end
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
local function plsb_remove_octave_notifier()
  if S.octave_notifier then
    pcall(function()
      local obs = renoise.song().transport.octave_observable
      if obs:has_notifier(S.octave_notifier) then obs:remove_notifier(S.octave_notifier) end
    end)
    S.octave_notifier = nil
  end
end

local function plsb_remove_doc_notifier()
  if S.doc_notifier then
    pcall(function()
      local o = renoise.tool().app_release_document_observable
      if o:has_notifier(S.doc_notifier) then o:remove_notifier(S.doc_notifier) end
    end)
    S.doc_notifier = nil
  end
end

-- Song is being torn down (New/Load Song). A custom dialog + its key_handler and
-- the octave observer would dangle and crash Renoise's keyboard dispatch
-- (TWeakRefOwner / SIGSEGV), so drop everything WITHOUT touching renoise.song()
-- (its observables die with it; the scratch instrument goes with the song too).
local function plsb_on_document_release()
  S.octave_notifier = nil      -- its observable dies with the song; don't remove
  S.active_notes = {}
  S.scratch_index = nil
  S.loaded_path = nil
  S.preview_ok = false
  if S.dialog then pcall(function() if S.dialog.visible then S.dialog:close() end end) end
  S.dialog = nil
  plsb_remove_doc_notifier()
end

local function plsb_persist_selection()
  if not preferences then return end
  if preferences.pakettiLoadSampleBrowserLastDir then
    preferences.pakettiLoadSampleBrowserLastDir.value = S.current_dir or ""
  end
  if preferences.pakettiLoadSampleBrowserLastFile then
    local e = S.entries[S.selected]
    preferences.pakettiLoadSampleBrowserLastFile.value = (e and e.name) or ""
  end
  preferences:save_as("preferences.xml")
end

function PakettiLoadSampleBrowser_Close(cancelled)
  plsb_persist_selection()   -- remember folder + highlighted file for next open
  plsb_remove_octave_notifier()
  plsb_remove_doc_notifier()
  plsb_all_notes_off()
  if cancelled then plsb_cleanup_scratch() end
  if S.dialog and S.dialog.visible then
    S.dialog:close()
  end
  S.dialog = nil
end

function PakettiLoadSampleBrowser_Confirm()
  -- if we're not on a file (e.g. on a folder/updir), pressing the shortcut just closes
  local e = S.entries[S.selected]
  if not (e and e.kind == "file") then
    PakettiLoadSampleBrowser_Close(true)
    return
  end
  local path = e.path
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

  PakettiLoadSampleBrowser_Close(false)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- go up to the parent, landing the cursor on the folder we just left
local function plsb_go_up()
  local leaving = plsb_basename(S.current_dir or "")
  local parent = plsb_parent(S.current_dir)
  if parent ~= S.current_dir then
    plsb_enter_dir(parent, leaving)
    plsb_refresh()
  end
end

local function plsb_activate_entry()
  local e = S.entries[S.selected]
  if not e then return end
  if e.kind == "updir" then
    plsb_go_up()
  elseif e.kind == "dir" then
    plsb_enter_dir(e.path)
    plsb_refresh()
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
  plsb_refresh()
end

-- jump to an absolute index (clamped) -- used by Cmd/Option+Up/Down for top/bottom
local function plsb_move_to(idx)
  if #S.entries == 0 then return end
  plsb_all_notes_off()
  S.selected = idx
  if S.selected < 1 then S.selected = 1 end
  if S.selected > #S.entries then S.selected = #S.entries end
  plsb_adjust_scroll()
  plsb_preview_selected()
  plsb_refresh()
end

-- click a row on the list canvas to select it; click the selected row to activate it
local function plsb_list_mouse(ev)
  if ev.type ~= "down" or ev.button ~= "left" then return end
  local r = math.floor(ev.position.y / LIST_ROW_H) + 1
  local i = S.scroll + r
  if i < 1 or i > #S.entries then return end
  if i == S.selected then
    plsb_activate_entry()
  else
    plsb_all_notes_off()
    S.selected = i
    plsb_adjust_scroll()
    plsb_preview_selected()
    plsb_refresh()
  end
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
    -- any modifier (Cmd / Option / Shift / Ctrl) + Up jumps to the top
    local jump = key.modifiers and key.modifiers ~= ""
    if jump then plsb_move_to(1) else plsb_move(-1) end
    return nil
  elseif name == "down" then
    -- any modifier (Cmd / Option / Shift / Ctrl) + Down jumps to the bottom
    local jump = key.modifiers and key.modifiers ~= ""
    if jump then plsb_move_to(#S.entries) else plsb_move(1) end
    return nil
  elseif name == "prior" then       -- Page Up
    plsb_move(-VISIBLE_ROWS); return nil
  elseif name == "next" then        -- Page Down
    plsb_move(VISIBLE_ROWS); return nil
  elseif name == "left" or name == "back" then
    plsb_go_up()
    return nil
  elseif name == "right" then
    local e = S.entries[S.selected]
    if e and e.kind == "updir" then
      plsb_go_up()
    elseif e and e.kind == "dir" then
      plsb_enter_dir(e.path)
      plsb_refresh()
    end
    return nil
  end

  -- F1-F12 folder presets: Fn recalls, Shift+Fn stores the current folder
  local fn = name and name:match("^f(%d+)$")
  if fn then
    local n = tonumber(fn)
    if n and n >= 1 and n <= 12 then
      if key.modifiers and key.modifiers:find("shift") then
        plsb_set_preset(n, S.current_dir)
        renoise.app():show_status("Paketti Load Sample: stored folder preset F" .. n .. " = " .. (S.current_dir or ""))
      else
        local presets = plsb_get_presets()
        local p = presets[n]
        if p and p ~= "" and io.exists(p) then
          plsb_enter_dir(p)
          plsb_refresh()
        else
          renoise.app():show_status("Paketti Load Sample: folder preset F" .. n .. " is empty (Shift+F" .. n .. " to store current folder)")
        end
      end
      return nil
    end
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
  S.current_dir = plsb_resolve_start_dir()

  local vb = renoise.ViewBuilder()
  S.vb = vb
  S.dir_id = "plsb_dir"
  S.list_id = "plsb_list"
  S.meta_id = "plsb_meta"
  S.wave_id = "plsb_wave"

  local content = vb:column {
    margin = 6,
    spacing = 6,
    vb:text{ id = S.dir_id, font = "mono", style = "strong", text = "", width = LIST_CANVAS_W },
    vb:row {
      spacing = 10,
      -- the file list is a canvas so the selected row is a full inverted bar
      vb:canvas{
        id = S.list_id,
        width = LIST_CANVAS_W,
        height = LIST_CANVAS_H,
        mode = "plain",
        render = plsb_list_render,
        mouse_handler = plsb_list_mouse,
        mouse_events = { "down" },
      },
      vb:column {
        spacing = 6,
        -- the metadata panel is ordinary, human-readable Renoise text
        vb:multiline_text{ id = S.meta_id, font = "mono", text = "", width = META_W, height = META_H },
        vb:text{ text = "Waveform", font = "bold" },
        vb:canvas{ id = S.wave_id, width = WAVE_W, height = WAVE_H, mode = "plain", render = plsb_wave_render },
      },
    },
  }

  plsb_rebuild_entries()

  -- restore the last highlighted file (by name, so it survives files being added/removed)
  local want = (preferences and preferences.pakettiLoadSampleBrowserLastFile
    and preferences.pakettiLoadSampleBrowserLastFile.value) or ""
  if want ~= "" then
    for i, e in ipairs(S.entries) do
      if e.name == want then S.selected = i break end
    end
    plsb_adjust_scroll()
    plsb_preview_selected()
  end

  local key_opts = { send_key_repeat = true, send_key_release = true }
  S.dialog = renoise.app():show_custom_dialog("Paketti Load Sample (Keyjazz Preview)",
    content, plsb_key_handler, key_opts)

  -- keep the metadata (incl. keyjazz octave) live when the transport octave changes
  S.octave_notifier = function() plsb_refresh() end
  pcall(function()
    renoise.song().transport.octave_observable:add_notifier(S.octave_notifier)
  end)

  -- tear the dialog down if the song is replaced, so its key_handler/observers
  -- never dangle into a freed window (Renoise keyboard-dispatch SIGSEGV class)
  S.doc_notifier = function() plsb_on_document_release() end
  pcall(function()
    renoise.tool().app_release_document_observable:add_notifier(S.doc_notifier)
  end)

  plsb_refresh()
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
PakettiAddMenuEntry{name="Instrument Box:Paketti Gadgets:Load Sample (Keyjazz Preview)...",
  invoke=function() PakettiLoadSampleBrowserToggle() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Load Sample Browser Keyjazz Preview",
  invoke = function() PakettiLoadSampleBrowserToggle() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Load Sample Browser Keyjazz Preview",
  invoke = function(message) if message:is_trigger() then PakettiLoadSampleBrowserToggle() end end
}
