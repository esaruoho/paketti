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
--   Backspace / Left go up to the parent folder; from a Windows drive root (C:\) this
--                   goes up to a synthetic "Drives" list to hop between C:/D:/E: etc.
--   Open Folder…    button: native folder picker, reaches any folder/drive (C:/D:/E:, network)
--   Esc             cancel + unload (delete scratch instrument)
--   F1-F12          jump to folder preset N; Shift+F1-F12 stores the current folder as preset N
--   Right-Shift     "load and jam": load into the smart target slot (selected-if-empty,
--                   else first empty, else new), select it, close, turn on Edit Mode +
--                   Follow Pattern, jump to the Pattern Editor
--   Piano keys      keyjazz the highlighted file (zsxdcvgbhnjm + 23 567 9 + qwertyuiop)
--   < / >           lower / raise the keyboard (transport) octave for keyjazz
--   Space           passes through to Renoise transport (start/stop during audition)
--   Shift+Enter     load all sample files directly inside the selected folder
--   < / >           pass through to Renoise octave controls
--   Toggle shortcut confirms + closes through the same deferred action as Enter.
--
-- The folder you are in is remembered (and becomes the default next time); if it has
-- since been deleted it reverts to ~/Music/Samples. The first time you ever open the
-- dialog it asks you to pick a default folder. The highlighted file is remembered too,
-- so reopening lands you back where you were (clamped if the folder now has fewer files).

PakettiLoadSampleBrowser = {}
-- REPORT-CARD >> features/sample-browser-deferred-close.feature

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
  dir_id = nil, list_id = nil, meta_id = nil, wave_id = nil, find_id = nil, loopbtn_id = nil,
  octave_notifier = nil,
  doc_notifier = nil,
  pending_action = nil,
  -- interactive waveform state
  loop = nil,            -- { mode, start, end, frames } mirror of the scratch sample's loop
  sel_range = nil,       -- { frame_a, frame_b } drag-selection on the waveform (1-based)
  drag = nil,            -- "start" | "end" | "select" while a wave drag is in progress
  drag_moved = false,    -- did the pointer move since mouse-down (click vs drag)
  sliced = false,        -- a click-to-play slice marker is currently on the scratch sample
  -- find / search
  find_query = "",       -- current filter text ("" = show everything)
}

-- forward declaration: refreshes the text widgets + waveform canvas (defined below,
-- but called by functions above its definition)
local plsb_refresh
-- forward declaration: removes any click-to-play slice marker from the scratch
-- sample (assigned in the interactive-waveform block, called by preview + keyjazz above it)
local plsb_clear_preview_slices

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
-- synthetic "all drives" level, so Windows users can hop between C:/D:/E: etc.
local PLSB_DRIVE_ROOT = "::drives::"

local function plsb_is_windows()
  return os.platform() == "WINDOWS"
end

local function plsb_sep()
  return plsb_is_windows() and "\\" or "/"
end

-- probe drive letters A..Z and return the ones that exist, as {path="C:\\", label="C:"}
local function plsb_list_drives()
  local drives = {}
  for i = 0, 25 do
    local letter = string.char(65 + i)
    local root = letter .. ":\\"
    if io.exists(root) then
      drives[#drives + 1] = { path = root, label = letter .. ":" }
    end
  end
  return drives
end

-- the drive label ("C:") of a path, or nil
local function plsb_drive_label(path)
  return path and path:match("^(%a:)")
end

local function plsb_join(dir, name)
  local sep = plsb_sep()
  if dir:sub(-1) == "/" or dir:sub(-1) == "\\" then return dir .. name end
  return dir .. sep .. name
end

local function plsb_parent(dir)
  if dir == PLSB_DRIVE_ROOT then return PLSB_DRIVE_ROOT end  -- drives list has no parent
  -- strip trailing sep then last component
  local d = dir:gsub("[/\\]+$", "")
  local parent = d:match("^(.*)[/\\][^/\\]+$")
  if not parent or parent == "" then
    -- top of a drive / filesystem root
    if plsb_is_windows() then
      -- at a drive root (e.g. C:\) go up to the synthetic "all drives" list
      if d:match("^%a:$") then return PLSB_DRIVE_ROOT end
      local drive = d:match("^(%a:)")
      return drive and (drive .. "\\") or d
    end
    return "/"
  end
  if not plsb_is_windows() and not parent:match("^/") then parent = "/" .. parent end
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

-- find / search ----------------------------------------------------------------
-- A tiny query language over file + folder names (ported from phaos SimpleBrowser):
--   kick 909        both words (AND)
--   kick or snare   either word (also: kick | snare)
--   -loop / not loop   leave out names containing "loop"
--   "tr 909"        the exact phrase, spaces included
--   kick*.wav       * any run of chars, ? any single char
local function plsb_glob_to_pat(s)
  -- escape Lua pattern magic, leaving * and ? to become wildcards
  s = s:gsub("[%^%$%(%)%.%[%]%+%-%%]", "%%%0")
  s = s:gsub("%*", ".*")
  s = s:gsub("%?", ".")
  return s
end

local function plsb_find_tokens(q)
  local toks, i, n = {}, 1, #q
  while i <= n do
    local c = q:sub(i, i)
    if c == '"' then
      local j = q:find('"', i + 1, true)
      if j then toks[#toks + 1] = q:sub(i + 1, j - 1); i = j + 1
      else toks[#toks + 1] = q:sub(i + 1); i = n + 1 end
    elseif c == " " then
      i = i + 1
    else
      local j = q:find(" ", i, true) or (n + 1)
      toks[#toks + 1] = q:sub(i, j - 1); i = j
    end
  end
  return toks
end

-- returns a parsed query (list of AND-groups, each a list of OR-alternatives),
-- or nil for an empty query (= match everything)
local function plsb_find_parse(q)
  q = tostring(q or "")
  if q:match("^%s*$") then return nil end
  local toks = plsb_find_tokens(q:lower())
  local groups, want_or, want_not = {}, false, false
  for _, t in ipairs(toks) do
    if t == "or" or t == "|" then
      want_or = true
    elseif t == "not" then
      want_not = true
    else
      local neg = want_not
      if t:sub(1, 1) == "-" and #t > 1 then neg = true; t = t:sub(2) end
      local alt = { neg = neg, pat = plsb_glob_to_pat(t) }
      if want_or and #groups > 0 then
        local g = groups[#groups]; g[#g + 1] = alt
      else
        groups[#groups + 1] = { alt }
      end
      want_or, want_not = false, false
    end
  end
  if #groups == 0 then return nil end
  return groups
end

local function plsb_find_match(groups, hay)
  if not groups then return true end
  hay = (hay or ""):lower()
  for _, g in ipairs(groups) do
    local ok = false
    for _, alt in ipairs(g) do
      local found = string.find(hay, alt.pat) ~= nil
      if found ~= alt.neg then ok = true; break end
    end
    if not ok then return false end
  end
  return true
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
  S.loop = nil
  S.sel_range = nil
  S.drag = nil
  if plsb_clear_preview_slices then plsb_clear_preview_slices() end
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
    S.loop = { mode = sample.loop_mode, start = sample.loop_start,
               stop = sample.loop_end, frames = buf.number_of_frames }
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

  -- synthetic "all drives" level (Windows): list each mounted drive, no up-dir
  if dir == PLSB_DRIVE_ROOT then
    for _, d in ipairs(plsb_list_drives()) do
      S.entries[#S.entries + 1] = { kind = "dir", name = d.label, path = d.path }
    end
  else
    -- the find filter (nil = show everything). Folders are only filtered when the
    -- query is active, so you can still navigate; the updir "." always stays.
    local filt = plsb_find_parse(S.find_query)
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
        if not filt or plsb_find_match(filt, d) then
          S.entries[#S.entries + 1] = { kind = "dir", name = d, path = plsb_join(dir, d) }
        end
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
        if not filt or plsb_find_match(filt, f) then
          S.entries[#S.entries + 1] = { kind = "file", name = f, path = plsb_join(dir, f) }
        end
      end
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
  if path == PLSB_DRIVE_ROOT then
    -- synthetic drives list: no io.exists, and don't persist it as the default folder
    S.current_dir = PLSB_DRIVE_ROOT
    plsb_rebuild_entries(select_name)
  elseif io.exists(path) then
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

  -- frames->x in this canvas (inlined; the shared helper is defined further down)
  local frames = (S.loop and S.loop.frames) or S.meta.frames or 1
  if frames < 1 then frames = 1 end
  local function fx(f) return (f - 1) / frames * WAVE_W end

  -- drag-selection band
  if S.sel_range then
    local a = math.min(S.sel_range[1], S.sel_range[2])
    local b = math.max(S.sel_range[1], S.sel_range[2])
    local x1 = fx(a)
    local x2 = fx(b)
    ctx.fill_color = { 232, 232, 214, 70 }   -- translucent cream
    ctx:begin_path(); ctx:rect(x1, 0, math.max(1, x2 - x1), WAVE_H); ctx:fill()
  end

  -- loop markers (start/end lines + small flags, like the sample editor)
  if S.loop and S.loop.mode and S.loop.mode ~= renoise.Sample.LOOP_MODE_OFF then
    local xs = fx(S.loop.start)
    local xe = fx(S.loop.stop)
    ctx.fill_color = { 255, 190, 60, 255 }   -- amber loop flags/lines
    ctx:begin_path(); ctx:rect(xs, 0, 1, WAVE_H); ctx:fill()
    ctx:begin_path(); ctx:rect(xe, 0, 1, WAVE_H); ctx:fill()
    -- start flag points right, end flag points left (6x6)
    ctx:begin_path(); ctx:move_to(xs + 1, 0); ctx:line_to(xs + 7, 0); ctx:line_to(xs + 1, 6); ctx:close_path(); ctx:fill()
    ctx:begin_path(); ctx:move_to(xe, 0); ctx:line_to(xe - 6, 0); ctx:line_to(xe, 6); ctx:close_path(); ctx:fill()
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
    if S.sel_range then
      local a = math.min(S.sel_range[1], S.sel_range[2])
      local b = math.max(S.sel_range[1], S.sel_range[2])
      lines[#lines + 1] = "Selection:   " .. a .. " - " .. b .. " frames"
    end
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
  if S.dir_id and v[S.dir_id] then
    v[S.dir_id].text = (S.current_dir == PLSB_DRIVE_ROOT) and "Drives" or (S.current_dir or "")
  end
  if S.list_id and v[S.list_id] then v[S.list_id]:update() end
  if S.meta_id and v[S.meta_id] then v[S.meta_id].text = plsb_meta_string() end
  if S.wave_id and v[S.wave_id] then v[S.wave_id]:update() end
  if S.loopbtn_id and v[S.loopbtn_id] then
    local name = (S.loop and plsb_loop_mode_name(S.loop.mode)) or "Off"
    v[S.loopbtn_id].text = "Loop: " .. name
  end
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
  -- a keyjazz note uses the whole sample again: drop any click-to-play slice first
  if plsb_clear_preview_slices then plsb_clear_preview_slices() end
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

-- interactive waveform: loop editing, click-to-play, drag ----------------------
-- Everything here mutates the hidden scratch sample that keyjazz already plays,
-- so changing the loop (or playing from a point) is heard live on the next note.

local function plsb_scratch_sample()
  if not S.scratch_index then return nil end
  local song = renoise.song()
  local inst = song and song.instruments[S.scratch_index]
  if not inst or #inst.samples < 1 then return nil end
  local smp = inst.samples[1]
  if not smp.sample_buffer.has_sample_data then return nil end
  return smp
end

-- map a canvas x (0..WAVE_W) to a frame (1..frames), and back
local function plsb_frame_at_x(x)
  local n = (S.loop and S.loop.frames) or (S.meta and S.meta.frames)
  if not n or n < 1 then return nil end
  local f = math.floor(x / WAVE_W * n) + 1
  if f < 1 then f = 1 elseif f > n then f = n end
  return f
end

-- keep S.loop in sync with the scratch sample after an edit
local function plsb_sync_loop()
  local smp = plsb_scratch_sample()
  if not smp then S.loop = nil; return end
  S.loop = { mode = smp.loop_mode, start = smp.loop_start,
             stop = smp.loop_end, frames = smp.sample_buffer.number_of_frames }
  S.meta.loop_mode = plsb_loop_mode_name(smp.loop_mode)
  S.meta.loop_start = smp.loop_start
  S.meta.loop_end = smp.loop_end
end

local function plsb_set_loop_mode(mode)
  local smp = plsb_scratch_sample()
  if not smp then return end
  local n = smp.sample_buffer.number_of_frames
  pcall(function()
    if mode ~= renoise.Sample.LOOP_MODE_OFF and smp.loop_start >= smp.loop_end then
      smp.loop_start = 1; smp.loop_end = n
    end
    smp.loop_mode = mode
  end)
  plsb_sync_loop()
  if plsb_refresh then plsb_refresh() end
  renoise.app():show_status("Load Sample: loop " .. plsb_loop_mode_name(mode))
end

local PLSB_LOOP_CYCLE = {
  renoise.Sample.LOOP_MODE_OFF, renoise.Sample.LOOP_MODE_FORWARD,
  renoise.Sample.LOOP_MODE_REVERSE, renoise.Sample.LOOP_MODE_PING_PONG,
}
local function plsb_cycle_loop_mode(delta)
  local smp = plsb_scratch_sample()
  if not smp then return end
  local idx = 1
  for i, m in ipairs(PLSB_LOOP_CYCLE) do if m == smp.loop_mode then idx = i break end end
  idx = ((idx - 1 + (delta or 1)) % #PLSB_LOOP_CYCLE) + 1
  plsb_set_loop_mode(PLSB_LOOP_CYCLE[idx])
end

-- move one loop flag to `frame`; turns a dormant loop on (Forward) so you hear it
local function plsb_set_loop_point(which, frame)
  local smp = plsb_scratch_sample()
  if not smp then return end
  local n = smp.sample_buffer.number_of_frames
  frame = math.max(1, math.min(n, math.floor(frame)))
  pcall(function()
    if which == "start" then
      if frame >= smp.loop_end then frame = smp.loop_end - 1 end
      if frame < 1 then frame = 1 end
      smp.loop_start = frame
    else
      if frame <= smp.loop_start then frame = smp.loop_start + 1 end
      smp.loop_end = frame
    end
    if smp.loop_mode == renoise.Sample.LOOP_MODE_OFF then
      smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    end
  end)
  plsb_sync_loop()
  if plsb_refresh then plsb_refresh() end
end

-- set the loop to the current drag-selection (Forward)
local function plsb_loop_to_selection()
  local smp = plsb_scratch_sample()
  if not smp or not S.sel_range then
    renoise.app():show_status("Load Sample: drag a selection on the waveform first")
    return
  end
  local n = smp.sample_buffer.number_of_frames
  local a = math.max(1, math.min(n - 1, math.min(S.sel_range[1], S.sel_range[2])))
  local b = math.max(a + 1, math.min(n, math.max(S.sel_range[1], S.sel_range[2])))
  pcall(function()
    smp.loop_mode = renoise.Sample.LOOP_MODE_OFF   -- reset so start<end never clashes
    smp.loop_start = 1
    smp.loop_end = b
    smp.loop_start = a
    smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  end)
  plsb_sync_loop()
  if plsb_refresh then plsb_refresh() end
  renoise.app():show_status("Load Sample: loop = selection (" .. a .. " - " .. b .. ")")
end

local function plsb_clear_selection()
  S.sel_range = nil
  if plsb_refresh then plsb_refresh() end
end

-- assigned to the forward-declared local so preview + keyjazz (above) can call it
plsb_clear_preview_slices = function()
  if not S.sliced then return end
  S.sliced = false
  local smp = plsb_scratch_sample()
  if not smp then return end
  pcall(function()
    local marks = {}
    for _, m in ipairs(smp.slice_markers) do marks[#marks + 1] = m end
    for _, m in ipairs(marks) do smp:delete_slice_marker(m) end
  end)
  pcall(function()
    smp.sample_mapping.base_note = 48
    smp.sample_mapping.note_range = { 0, 119 }
  end)
end

-- click-to-play: play the scratch sample from `frac` (0..1) of its length.
-- Uses a temporary slice marker (removed before the next keyjazz note).
local function plsb_play_from(frac)
  local smp = plsb_scratch_sample()
  if not smp then return end
  plsb_all_notes_off()
  plsb_clear_preview_slices()
  local song = renoise.song()
  local ti = plsb_safe_track_index()
  local n = smp.sample_buffer.number_of_frames
  local pos = math.floor(math.max(0, math.min(1, frac)) * n) + 1
  if pos <= 1 or n < 64 or pos >= n - 16 then
    pcall(function() song:trigger_instrument_note_on(S.scratch_index, ti, { 48 }, 1.0) end)
    S.active_notes["__wave__"] = 48
    return
  end
  local ok = pcall(function()
    smp:insert_slice_marker(pos)
    S.sliced = true
    local inst = song.instruments[S.scratch_index]
    local alias = inst.samples[#inst.samples]          -- the slice starting at pos
    local base = alias.sample_mapping.base_note
    song:trigger_instrument_note_on(S.scratch_index, ti, { base }, 1.0)
    S.active_notes["__wave__"] = base
  end)
  if not ok then
    plsb_clear_preview_slices()
    pcall(function() song:trigger_instrument_note_on(S.scratch_index, ti, { 48 }, 1.0) end)
    S.active_notes["__wave__"] = 48
  end
end

-- the waveform canvas mouse handler: drag a loop flag, drag to select, click to play
local function plsb_wave_mouse(ev)
  if S.pending_action then return end
  local x = ev.position.x
  if ev.type == "down" then
    if ev.button ~= "left" then return end
    S.drag_moved = false
    local grabbed
    if S.loop and S.loop.mode ~= renoise.Sample.LOOP_MODE_OFF then
      local xs = (S.loop.start - 1) / math.max(1, S.loop.frames) * WAVE_W
      local xe = (S.loop.stop - 1) / math.max(1, S.loop.frames) * WAVE_W
      if math.abs(x - xs) <= 6 then grabbed = "start"
      elseif math.abs(x - xe) <= 6 then grabbed = "end" end
    end
    if grabbed then
      S.drag = grabbed
    else
      S.drag = "select"
      local f = plsb_frame_at_x(x)
      S.sel_anchor = f
      S.sel_range = f and { f, f } or nil
      if plsb_refresh then plsb_refresh() end
    end
  elseif ev.type == "move" or ev.type == "drag" then
    if not S.drag then return end
    S.drag_moved = true
    local f = plsb_frame_at_x(x)
    if not f then return end
    if S.drag == "start" or S.drag == "end" then
      plsb_set_loop_point(S.drag, f)
    elseif S.drag == "select" then
      S.sel_range = { S.sel_anchor or f, f }
      if plsb_refresh then plsb_refresh() end
    end
  elseif ev.type == "up" then
    local was = S.drag
    S.drag = nil
    if was == "select" and not S.drag_moved then
      -- a plain click (no drag) = play from that point
      S.sel_range = nil
      local f = plsb_frame_at_x(x)
      local n = (S.loop and S.loop.frames) or 1
      plsb_play_from(f and ((f - 1) / math.max(1, n)) or 0)
    end
  end
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

local function plsb_cancel_pending_action()
  local callback = S.pending_action
  S.pending_action = nil
  if callback and renoise.tool():has_timer(callback) then
    renoise.tool():remove_timer(callback)
  end
end

-- Keep the originating window alive until native keyboard dispatch has returned.
-- Freeze the selection while queued and remove the repeating timer BEFORE work.
local function plsb_defer_action(action)
  if S.pending_action then return end
  local dialog = S.dialog
  if not (dialog and dialog.visible) then return end
  local callback
  callback = function()
    plsb_cancel_pending_action()
    if S.dialog ~= dialog or not dialog.visible then return end
    local ok, err = pcall(action)
    if not ok then
      renoise.app():show_error("Paketti Load Sample: " .. tostring(err))
    end
  end
  S.pending_action = callback
  renoise.tool():add_timer(callback, 50)
end

-- Song is being torn down (New/Load Song). A custom dialog + its key_handler and
-- the octave observer would dangle and crash Renoise's keyboard dispatch
-- (TWeakRefOwner / SIGSEGV), so drop everything WITHOUT touching renoise.song()
-- (its observables die with it; the scratch instrument goes with the song too).
local function plsb_on_document_release()
  plsb_cancel_pending_action()
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

local function plsb_close_now(cancelled)
  plsb_persist_selection()   -- remember folder + highlighted file for next open
  plsb_remove_octave_notifier()
  plsb_remove_doc_notifier()
  plsb_all_notes_off()
  -- restore the Edit Mode state we may have turned off on open (the jam path
  -- re-enables it afterwards in plsb_finalize)
  if S.prev_edit_mode ~= nil then
    pcall(function() renoise.song().transport.edit_mode = S.prev_edit_mode end)
    S.prev_edit_mode = nil
  end
  if cancelled then plsb_cleanup_scratch() end
  if S.dialog and S.dialog.visible then
    S.dialog:close()
  end
  S.dialog = nil
end

function PakettiLoadSampleBrowser_Close(cancelled)
  plsb_defer_action(function() plsb_close_now(cancelled) end)
end

-- pick the smart target slot: selected-if-empty, else first empty, else a new slot
-- at the end. force_new skips straight to a new slot. Returns the index, or nil.
local function plsb_pick_target(force_new)
  local song = renoise.song()
  local function is_empty(inst)
    return #inst.samples == 0 and not inst.plugin_properties.plugin_loaded
  end
  local tgt = nil
  if not force_new then
    local sel = song.selected_instrument_index
    if song.instruments[sel] and is_empty(song.instruments[sel]) then
      tgt = sel
    else
      for i = 1, #song.instruments do
        if is_empty(song.instruments[i]) then tgt = i break end
      end
    end
  end
  if not tgt then
    if not safeInsertInstrumentAt(song, #song.instruments + 1) then
      renoise.app():show_status("Paketti Load Sample: could not create instrument slot")
      return nil
    end
    tgt = #song.instruments
  end
  return tgt
end

-- select the target, optionally arm jam mode, and drop into the Pattern Editor
local function plsb_finalize(tgt, jam)
  local song = renoise.song()
  if tgt and song.instruments[tgt] then song.selected_instrument_index = tgt end
  if jam then
    pcall(function() song.transport.edit_mode = true end)
    pcall(function() song.transport.follow_player = true end)
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- load a list of audio wavs into ONE pakettified target instrument (multi-sample)
local function plsb_load_wavs_into_target(wavs, force_new)
  local tgt = plsb_pick_target(force_new)
  if not tgt then return nil end
  local song = renoise.song()
  song.selected_instrument_index = tgt
  pakettiPreferencesDefaultInstrumentLoader()      -- template (one placeholder sample)
  tgt = song.selected_instrument_index
  local instr = song.instruments[tgt]
  local n = math.min(#wavs, 120)                    -- Renoise/Paketti drumkit cap
  for i = 1, n do
    if #instr.samples < i then instr:insert_sample_at(i) end
    local smp = instr.samples[i]
    local base = plsb_basename(wavs[i])
    pcall(function() smp.sample_buffer:load_from(wavs[i]) end)
    smp.name = base
    pcall(function() PakettiInjectApplyLoaderSettings(smp) end)
  end
  instr.name = string.format("%02X_", tgt - 1) .. plsb_basename(wavs[1] or "")
  renoise.app():show_status("Loaded " .. n .. " sample(s) into instrument " .. string.format("%02X", tgt - 1))
  return tgt
end

-- The full load: branches by format.
--   plain audio  -> smart target + default template; .wav runs cue-slicing if present
--   rex/rx2/iff/iti/ot/wt/mti/mod -> async expand to wavs, ALL loaded into one instrument
--   pti/sf2/exs  -> async importer builds their own (full-fidelity) instrument; we select it
local function plsb_do_load(path, opts)
  opts = opts or {}
  local jam = opts.jam
  local force_new = opts.force_new
  local ext = plsb_ext(path)

  -- the loop the user shaped on the waveform (a mirror of the scratch sample), so
  -- what you keyjazzed is what gets loaded. nil / Off means "leave the file's own loop".
  local tuned_loop = S.loop

  -- the scratch preview instrument must not be a target candidate or left behind
  plsb_cleanup_scratch()

  if PLSB_NATIVE[ext] then
    local tgt = plsb_pick_target(force_new)
    if not tgt then return end
    local song = renoise.song()
    song.selected_instrument_index = tgt
    pakettiPreferencesDefaultInstrumentLoader()
    tgt = song.selected_instrument_index
    local instr = song.instruments[tgt]
    local smp = instr.samples[1]
    if not smp then instr:insert_sample_at(1); smp = instr.samples[1] end
    local base = plsb_basename(path)
    if ext == "wav" then
      -- auto-slices if the wav carries cue chunks, else plain load_from
      pcall(function() PakettiWavCueImportWavWithCuesIntoSample(smp, path) end)
    else
      pcall(function() smp.sample_buffer:load_from(path) end)
    end
    smp.name = base
    instr.name = string.format("%02X_", tgt - 1) .. base
    pcall(function() PakettiInjectApplyLoaderSettings(smp) end)
    -- carry the waveform-tuned loop onto the freshly loaded sample (same audio only,
    -- and never over a cue-sliced load) so the loop you keyjazzed survives the load
    if tuned_loop and tuned_loop.mode and tuned_loop.mode ~= renoise.Sample.LOOP_MODE_OFF then
      pcall(function()
        local buf = smp.sample_buffer
        if buf.has_sample_data and buf.number_of_frames == tuned_loop.frames
          and #smp.slice_markers == 0 then
          local n = buf.number_of_frames
          local a = math.max(1, math.min(n - 1, tuned_loop.start))
          local b = math.max(a + 1, math.min(n, tuned_loop.stop))
          smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
          smp.loop_start = 1
          smp.loop_end = b
          smp.loop_start = a
          smp.loop_mode = tuned_loop.mode
        end
      end)
    end
    renoise.app():show_status("Loaded " .. base .. " into instrument " .. string.format("%02X", tgt - 1))
    plsb_finalize(tgt, jam)
  else
    -- async handles pti/sf2/exs (self-import) AND harvests rex/rx2/iff/iti/ot/wt/mti/mod
    PakettiExpandLoadableFilesAsync({ path }, function(expanded, temps, failures)
      local tgt
      if expanded and #expanded > 0 then
        tgt = plsb_load_wavs_into_target(expanded, force_new)
      else
        -- pti/sf2/exs loaded straight into their own instrument (already selected)
        tgt = renoise.song().selected_instrument_index
      end
      pcall(function() PakettiExpandLoadableCleanup(temps) end)
      plsb_finalize(tgt, jam)
    end)
  end
end

local function plsb_confirm_now()
  local e = S.entries[S.selected]
  if not (e and e.kind == "file") then
    plsb_close_now(true)
    return
  end
  local path = e.path
  plsb_all_notes_off()
  plsb_close_now(false)          -- close our dialog first; loaders may show their own
  plsb_do_load(path, { force_new = false, jam = false })
end

-- Right-Shift "load and jam": same smart target, plus Edit Mode + Follow Pattern on.
local function plsb_confirm_jam_now()
  local e = S.entries[S.selected]
  if not (e and e.kind == "file") then
    plsb_close_now(true)
    return
  end
  local path = e.path
  plsb_all_notes_off()
  plsb_close_now(false)
  plsb_do_load(path, { force_new = false, jam = true })
end

function PakettiLoadSampleBrowser_Confirm()
  plsb_defer_action(plsb_confirm_now)
end

function PakettiLoadSampleBrowser_ConfirmJam()
  plsb_defer_action(plsb_confirm_jam_now)
end

-- load a single file into its own pakettified target slot; returns true on success.
-- Used by the Shift+Enter "load every sample in this folder" path. Native audio only
-- here (load pti/sf2/mod/etc one at a time with Enter, which uses the async expander).
local function plsb_load_path(path)
  local ext = plsb_ext(path)
  if not PLSB_NATIVE[ext] then return false end
  local song = renoise.song()
  local tgt = plsb_pick_target(false)
  if not tgt then return false end
  song.selected_instrument_index = tgt
  pakettiPreferencesDefaultInstrumentLoader()
  tgt = song.selected_instrument_index
  local instr = song.instruments[tgt]
  local smp = instr.samples[1]
  if not smp then instr:insert_sample_at(1); smp = instr.samples[1] end
  local base = plsb_basename(path)
  if ext == "wav" then
    pcall(function() PakettiWavCueImportWavWithCuesIntoSample(smp, path) end)
  else
    pcall(function() smp.sample_buffer:load_from(path) end)
  end
  if not smp.sample_buffer.has_sample_data then return false end
  smp.name = base
  instr.name = string.format("%02X_", tgt - 1) .. base
  pcall(function() PakettiInjectApplyLoaderSettings(smp) end)
  return true
end

local function plsb_load_folder_now()
  local e = S.entries[S.selected]
  if not (e and e.kind == "dir") then return end
  local files = os.filenames(e.path, PakettiLoadableExtensions())
  table.sort(files, function(a, b) return a:lower() < b:lower() end)
  if #files == 0 then
    renoise.app():show_status("Paketti Load Sample: no loadable samples in " .. e.name)
    return
  end
  local loaded = 0
  for _, name in ipairs(files) do
    if plsb_load_path(plsb_join(e.path, name)) then loaded = loaded + 1 end
  end
  plsb_close_now(false)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Paketti Load Sample: loaded " .. loaded .. " of " .. #files .. " files from " .. e.name)
end

-- go up to the parent, landing the cursor on the folder we just left
local function plsb_go_up()
  local parent = plsb_parent(S.current_dir)
  if parent == S.current_dir then return end
  -- when going up to the drives list, land on the drive we came from (its label)
  local leaving
  if parent == PLSB_DRIVE_ROOT then
    leaving = plsb_drive_label(S.current_dir)
  else
    leaving = plsb_basename(S.current_dir or "")
  end
  plsb_enter_dir(parent, leaving)
  plsb_refresh()
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

-- change the keyboard (transport) octave, clamped, and refresh the readout
local function plsb_shift_octave(delta)
  local song = renoise.song()
  if not song then return end
  local oct = (song.transport.octave or 4) + delta
  if oct < 0 then oct = 0 elseif oct > 8 then oct = 8 end
  plsb_all_notes_off()   -- avoid stuck notes when the octave moves mid-hold
  pcall(function() song.transport.octave = oct end)
  plsb_refresh()
end

-- click a row on the list canvas to select it; click the selected row to activate it
local function plsb_list_mouse(ev)
  if S.pending_action then return end
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
  if S.pending_action then return nil end
  local name = key.name

  -- key releases: stop keyjazz notes
  if key.state == "released" then
    if name and (PLSB_LOWER[name] ~= nil or PLSB_UPPER[name] ~= nil) then
      plsb_note_off(name)
      return nil
    end
    return key
  end

  -- navigation + actions (not key-repeat sensitive except arrows)
  if name == "esc" then
    PakettiLoadSampleBrowser_Close(true)
    return nil
  elseif name == "rshift" then
    -- Right-Shift = load into a NEW instrument, close, Edit Mode + Follow Pattern on,
    -- and jump to the Pattern Editor ready to jam
    if not key.repeated then PakettiLoadSampleBrowser_ConfirmJam() end
    return nil
  elseif name == "return" then
    if not key.repeated then
      local e = S.entries[S.selected]
      if key.modifiers and key.modifiers:find("shift", 1, true) and e and e.kind == "dir" then
        plsb_defer_action(plsb_load_folder_now)
      else
        plsb_activate_entry()
      end
    end
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
  elseif name == "<" or name == "less" then
    plsb_shift_octave(-1); return nil
  elseif name == ">" or name == "greater" then
    plsb_shift_octave(1); return nil
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

  -- Modified piano keys belong to Renoise's global shortcuts.
  if (not key.modifiers or key.modifiers == "") and name
    and (PLSB_LOWER[name] ~= nil or PLSB_UPPER[name] ~= nil) then
    if not key.repeated then plsb_note_on(name) end
    return nil
  end

  -- Octave controls and the opening shortcut must reach Renoise. Confirmation
  -- queues a timer, so forwarding does not destroy this window during dispatch.
  return key
end

function PakettiLoadSampleBrowser_Open()
  if S.pending_action then return end
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
  S.find_query = ""
  S.sel_range = nil
  S.drag = nil
  S.sliced = false

  -- If transport is PLAYING, turn Edit Mode off while the dialog is open so keyjazz
  -- preview works cleanly; remember the state and restore it on close (the jam path
  -- re-enables Edit Mode afterwards).
  local song = renoise.song()
  S.prev_edit_mode = song.transport.edit_mode
  if song.transport.playing then
    pcall(function() song.transport.edit_mode = false end)
  end

  S.current_dir = plsb_resolve_start_dir()

  local vb = renoise.ViewBuilder()
  S.vb = vb
  S.dir_id = "plsb_dir"
  S.list_id = "plsb_list"
  S.meta_id = "plsb_meta"
  S.wave_id = "plsb_wave"
  S.find_id = "plsb_find"
  S.loopbtn_id = "plsb_loopbtn"

  local content = vb:column {
    margin = 6,
    spacing = 6,
    vb:row {
      spacing = 6,
      vb:button {
        text = "Open Folder…",
        width = 110,
        notifier = function()
          -- native folder picker -> reaches any folder/drive (C:/D:/E:, network, etc.)
          local ok, path = pcall(function()
            return renoise.app():prompt_for_path("Load Sample Browser: choose a folder")
          end)
          if ok and path and path ~= "" and io.exists(path) then
            plsb_enter_dir(path)
            plsb_refresh()
          end
        end,
      },
      vb:text{ id = S.dir_id, font = "mono", style = "strong", text = "", width = LIST_CANVAS_W - 116 },
    },
    -- Find: filters the file/folder list. kick 909 (both) · kick or snare · -loop · "tr 909" · kick*.wav
    vb:row {
      spacing = 6,
      vb:text{ text = "Find", font = "bold", width = 34 },
      vb:textfield{
        id = S.find_id,
        width = LIST_CANVAS_W - 34 - 70 - 12,
        text = S.find_query or "",
        notifier = function(txt)
          -- ViewBuilder fires this once while the dialog is being built; ignore the
          -- no-op so we don't rebuild entries before the dialog exists.
          txt = txt or ""
          if txt == (S.find_query or "") then return end
          S.find_query = txt
          plsb_rebuild_entries()
          plsb_refresh()
        end,
      },
      vb:button{
        text = "Clear",
        width = 70,
        notifier = function()
          S.find_query = ""
          if S.vb and S.vb.views[S.find_id] then S.vb.views[S.find_id].text = "" end
          plsb_rebuild_entries()
          plsb_refresh()
        end,
      },
    },
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
        vb:text{ text = "Waveform  (click = play from point · drag = select · drag flags = loop)", font = "bold" },
        -- interactive: click plays from the point, drag selects, drag the loop flags to move the loop
        vb:canvas{
          id = S.wave_id, width = WAVE_W, height = WAVE_H, mode = "plain",
          render = plsb_wave_render,
          mouse_handler = plsb_wave_mouse,
          mouse_events = { "down", "up", "move", "drag" },
        },
        vb:row {
          spacing = 6,
          vb:button{ id = S.loopbtn_id, text = "Loop: Off", width = 110,
            notifier = function() plsb_cycle_loop_mode(1) end },
          vb:button{ text = "Loop → Selection", width = 130,
            notifier = function() plsb_loop_to_selection() end },
          vb:button{ text = "Clear Sel", width = 80,
            notifier = function() plsb_clear_selection() end },
        },
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
  if S.pending_action then return end
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
  invoke = function(repeated)
    if not repeated then PakettiLoadSampleBrowserToggle() end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Load Sample Browser Keyjazz Preview",
  invoke = function(message) if message:is_trigger() then PakettiLoadSampleBrowserToggle() end end
}
