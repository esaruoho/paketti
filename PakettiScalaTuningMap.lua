-- PakettiScalaTuningMap.lua
-- Visual note -> frequency map for the native Renoise 3.5 Scala / custom tuning.
--
-- Reads the SELECTED instrument's `trigger_options.tuning` (the array of pitch
-- ratios relative to 1/1 that Renoise builds when you load a .scl file) and draws
-- a colour-coded interval table on a canvas: for every note it shows the scale
-- degree, the within-period ratio, cents, and the absolute frequency in Hz.
--
-- Octave-equivalent notes (same scale degree) share the SAME colour, so you can
-- see at a glance which notes are "an octave apart" even when the period has more
-- or fewer than 12 notes (e.g. 22EDO). This is the in-dialog answer to the
-- pattern-editor recolour request, which the Renoise API does not allow per-cell.
--
-- The row under the pattern-editor cursor is highlighted live; the table auto-
-- refreshes when you load a different tuning or switch instruments. Click a row
-- to preview that note through the selected instrument.
--
-- Complements (does not duplicate):
--   * PakettiMicrotonalTunings.lua  -- GENERATES + APPLIES tunings (the write side)
--   * PakettiTuningDisplay.lua      -- older sample-FX microtuning from .txt files
-- This file is the READ / VISUALISE side of the native Scala tuning.

-- ===========================================================================
-- State
-- ===========================================================================

PakettiScalaTuningMapDialog = nil

local CANVAS_ID = "paketti_scala_tuning_map_canvas"
local CANVAS_W = 560
local CANVAS_H = 470
local HEADER_H = 76
local ROW_H = 16
local ROWS = math.floor((CANVAS_H - HEADER_H) / ROW_H)

local ROOT_NOTE = 48                              -- Renoise C-4 = tuning root (1/1)
local C4_HZ = 440 * 2 ^ ((ROOT_NOTE - 57) / 12)  -- middle C in standard A4=440 (~261.63 Hz)
local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}

-- column x positions (canvas pixels)
local SW_X    = 6     -- colour swatch
local NAME_X  = 30    -- note name
local DEG_X   = 96    -- degree d/n
local RATIO_X = 158   -- within-period ratio
local CENTS_X = 226   -- within-period cents
local HZ_X    = 300   -- absolute frequency
local BAR_X   = 378   -- within-period position bar
local BAR_W   = 174
local ROW_SIZE = 7

local PSTM_vb = nil
local PSTM_canvas = nil
local PSTM_view_start = 36
local PSTM_highlight_note = -1
local PSTM_follow = true
local PSTM_last_sig = nil
local PSTM_dirty = false
local PSTM_playing = nil          -- {i=instr_idx, t=track_idx, n=note}
local PSTM_release_installed = false

-- ===========================================================================
-- Helpers
-- ===========================================================================

local function ratio_to_cents(ratio)
  if ratio <= 0 then return 0 end
  return 1200 * math.log(ratio) / math.log(2)
end

local function note_name(note)
  return NOTE_NAMES[(note % 12) + 1] .. tostring(math.floor(note / 12))
end

-- HSV (0..1) -> {r,g,b} 0..255
local function hsv_rgb(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  local r, g, b
  i = i % 6
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- Same colour per scale degree -> octave-equivalent notes match.
-- Degree 0 (the period root) is always the same off-white, so period starts pop.
local function degree_color(degree, n, alpha)
  if degree == 0 then return {235, 235, 245, alpha or 255} end
  local r, g, b = hsv_rgb(degree / n, 0.62, 0.95)
  return {r, g, b, alpha or 255}
end

-- Read the selected instrument's active tuning. Falls back to 12-TET so the map
-- is still useful when no custom tuning is loaded.
local function get_tuning()
  local out = {ratios = {}, name = "12-TET (default \226\128\148 no custom tuning loaded)",
               n = 12, is_default = true, instr_name = "(no instrument)"}
  local song = renoise.song()
  if not song then return out end
  local instr = song.selected_instrument
  if not instr then return out end
  out.instr_name = (instr.name ~= "" and instr.name)
    or ("Instrument " .. string.format("%02X", song.selected_instrument_index - 1))
  local topt = instr.trigger_options
  local t = topt.tuning
  if t and #t > 0 then
    for i = 1, #t do out.ratios[i] = t[i] end
    out.name = (topt.tuning_name ~= "" and topt.tuning_name) or "Custom tuning"
    out.n = #t
    out.is_default = false
  else
    for i = 1, 12 do out.ratios[i] = 2 ^ (i / 12) end
    if topt.mts_esp_tuning then
      out.name = "MTS-ESP client (live host tuning \226\128\148 12-TET shown for reference)"
    end
  end
  return out
end

-- For a note: returns degree (0..n-1), within-period ratio, absolute ratio.
local function note_info(note, ratios)
  local n = #ratios
  local period = ratios[n]
  local delta = note - ROOT_NOTE
  local octrep = math.floor(delta / n)
  local degree = delta - octrep * n
  local ratio_in = (degree == 0) and 1.0 or ratios[degree]
  local total = ratio_in * (period ^ octrep)
  return degree, ratio_in, total
end

-- ===========================================================================
-- Canvas render
-- ===========================================================================

local function draw_text(ctx, text, x, y, size, color)
  ctx.stroke_color = color
  ctx.line_width = 1
  PakettiCanvasFontDrawText(ctx, text, x, y, size)
end

function PakettiScalaTuningMapRender(ctx)
  -- background
  ctx.fill_color = {18, 18, 24, 255}
  ctx:fill_rect(0, 0, CANVAS_W, CANVAS_H)

  local tun = get_tuning()
  local ratios = tun.ratios
  local n = tun.n
  local period = ratios[n]
  local period_cents = ratio_to_cents(period)

  -- header
  draw_text(ctx, tun.name, 6, 6, 9, {180, 220, 255, 255})
  local info = n .. " NOTES/PERIOD   PERIOD " .. string.format("%.3f", period)
    .. " = " .. string.format("%.1f", period_cents) .. "C   ROOT C-4 = "
    .. string.format("%.1f", C4_HZ) .. " HZ"
  draw_text(ctx, info, 6, 22, 6, {150, 150, 165, 255})
  draw_text(ctx, "INSTR: " .. tun.instr_name, 6, 34, 6, {150, 150, 165, 255})

  -- current-note readout
  if PSTM_highlight_note >= 0 and PSTM_highlight_note <= 119 then
    local d, ri, tot = note_info(PSTM_highlight_note, ratios)
    local line = note_name(PSTM_highlight_note) .. "   DEG " .. d .. "/" .. n
      .. "   " .. string.format("%.3f", ri)
      .. "   " .. string.format("%.1f", ratio_to_cents(ri)) .. "C"
      .. "   " .. string.format("%.1f", C4_HZ * tot) .. " HZ"
    draw_text(ctx, line, 6, 46, 8, {255, 245, 150, 255})
  else
    draw_text(ctx, "PLAY OR SELECT A NOTE TO SEE ITS PITCH", 6, 46, 6, {120, 120, 135, 255})
  end

  -- column headers
  draw_text(ctx, "NOTE", NAME_X, 62, 6, {120, 120, 140, 255})
  draw_text(ctx, "DEG",  DEG_X, 62, 6, {120, 120, 140, 255})
  draw_text(ctx, "RATIO", RATIO_X, 62, 6, {120, 120, 140, 255})
  draw_text(ctx, "CENTS", CENTS_X, 62, 6, {120, 120, 140, 255})
  draw_text(ctx, "HZ", HZ_X, 62, 6, {120, 120, 140, 255})

  -- rows
  for i = 0, ROWS - 1 do
    local note = PSTM_view_start + i
    if note >= 0 and note <= 119 then
      local y = HEADER_H + i * ROW_H
      local degree, ratio_in, total = note_info(note, ratios)
      local is_hl = (note == PSTM_highlight_note)

      -- row background
      if is_hl then
        ctx.fill_color = {70, 95, 130, 255}
      else
        local c = degree_color(degree, n, 40)
        ctx.fill_color = c
      end
      ctx:fill_rect(0, y, CANVAS_W, ROW_H - 1)

      -- period boundary line at each period root
      if degree == 0 then
        ctx.stroke_color = {120, 120, 150, 255}
        ctx.line_width = 1
        ctx:begin_path()
        ctx:move_to(0, y)
        ctx:line_to(CANVAS_W, y)
        ctx:stroke()
      end

      -- colour swatch
      ctx.fill_color = degree_color(degree, n, 255)
      ctx:fill_rect(SW_X, y + 3, 16, ROW_H - 6)

      -- text
      local txt_col = is_hl and {255, 255, 255, 255} or {210, 210, 222, 255}
      draw_text(ctx, note_name(note), NAME_X, y + 4, ROW_SIZE, txt_col)
      draw_text(ctx, degree .. "/" .. n, DEG_X, y + 4, ROW_SIZE, txt_col)
      draw_text(ctx, string.format("%.3f", ratio_in), RATIO_X, y + 4, ROW_SIZE, txt_col)
      draw_text(ctx, string.format("%.1f", ratio_to_cents(ratio_in)), CENTS_X, y + 4, ROW_SIZE, txt_col)
      draw_text(ctx, string.format("%.1f", C4_HZ * total), HZ_X, y + 4, ROW_SIZE, txt_col)

      -- within-period position bar (log-pitch ladder)
      local frac = (period_cents > 0) and (ratio_to_cents(ratio_in) / period_cents) or 0
      ctx.fill_color = {40, 40, 52, 255}
      ctx:fill_rect(BAR_X, y + 5, BAR_W, ROW_H - 10)
      local c = degree_color(degree, n, 230)
      ctx.fill_color = c
      ctx:fill_rect(BAR_X, y + 5, math.max(1, frac * BAR_W), ROW_H - 10)
    end
  end
end

-- ===========================================================================
-- Preview triggering
-- ===========================================================================

local function find_sequencer_track()
  local song = renoise.song()
  if not song then return nil end
  local idx = song.selected_track_index
  local tr = song.tracks[idx]
  if tr and tr.type == renoise.Track.TRACK_TYPE_SEQUENCER then return idx end
  for i, t in ipairs(song.tracks) do
    if t.type == renoise.Track.TRACK_TYPE_SEQUENCER then return i end
  end
  return nil
end

local function preview_off()
  if not PSTM_playing then return end
  local song = renoise.song()
  if song then
    pcall(function()
      song:trigger_instrument_note_off(PSTM_playing.i, PSTM_playing.t, PSTM_playing.n)
    end)
  end
  PSTM_playing = nil
end

local function preview_on(note)
  local song = renoise.song()
  if not song then return end
  local tidx = find_sequencer_track()
  if not tidx then return end
  preview_off()
  local iidx = song.selected_instrument_index
  pcall(function() song:trigger_instrument_note_on(iidx, tidx, note, 1.0) end)
  PSTM_playing = {i = iidx, t = tidx, n = note}
end

-- ===========================================================================
-- Mouse
-- ===========================================================================

function PakettiScalaTuningMapMouse(ev)
  if ev.type == "exit" or ev.type == "up" then
    preview_off()
    return
  end
  if ev.type == "down" then
    local y = ev.position.y
    if y < HEADER_H then return end
    local row = math.floor((y - HEADER_H) / ROW_H)
    local note = PSTM_view_start + row
    if note < 0 or note > 119 then return end
    PSTM_highlight_note = note
    preview_on(note)
    if PSTM_canvas then PSTM_canvas:invalidate() end
  end
end

-- ===========================================================================
-- Navigation / follow
-- ===========================================================================

local function clamp_view()
  local maxstart = math.max(0, 120 - ROWS)
  if PSTM_view_start < 0 then PSTM_view_start = 0 end
  if PSTM_view_start > maxstart then PSTM_view_start = maxstart end
end

local function follow_to_note(force)
  if PSTM_highlight_note < 0 then return end
  if force or PSTM_highlight_note < PSTM_view_start
     or PSTM_highlight_note > PSTM_view_start + ROWS - 1 then
    PSTM_view_start = PSTM_highlight_note - math.floor(ROWS / 2)
    clamp_view()
  end
end

local function shift_view(delta)
  PSTM_view_start = PSTM_view_start + delta
  clamp_view()
  if PSTM_canvas then PSTM_canvas:invalidate() end
end

-- ===========================================================================
-- Live tick (polling — robust, self-cleaning, song-lifecycle safe)
-- ===========================================================================

function PakettiScalaTuningMapTick()
  if not (PakettiScalaTuningMapDialog and PakettiScalaTuningMapDialog.visible) then
    PakettiScalaTuningMapCleanup()
    return
  end
  pcall(function()
    local song = renoise.song()
    if not song then return end
    local instr = song.selected_instrument
    if not instr then return end

    -- detect tuning / instrument change
    local topt = instr.trigger_options
    local t = topt.tuning
    local sig = (topt.tuning_name or "") .. "|" .. tostring(#t)
      .. "|i" .. tostring(song.selected_instrument_index)
    if #t > 0 then
      sig = sig .. "|" .. string.format("%.5f", t[1]) .. "|" .. string.format("%.5f", t[#t])
    end
    if sig ~= PSTM_last_sig then
      PSTM_last_sig = sig
      PSTM_dirty = true
    end

    -- read note under the pattern-editor cursor (the "last entered" note)
    local cidx = song.selected_note_column_index
    if cidx and cidx >= 1 then
      local line = song.selected_line
      if line then
        local col = line.note_columns[cidx]
        if col and col.note_value <= 119 and col.note_value ~= PSTM_highlight_note then
          PSTM_highlight_note = col.note_value
          PSTM_dirty = true
          if PSTM_follow then follow_to_note(false) end
        end
      end
    end

    if PSTM_dirty then
      PSTM_dirty = false
      if PSTM_canvas then PSTM_canvas:invalidate() end
    end
  end)
end

-- ===========================================================================
-- Lifecycle
-- ===========================================================================

function PakettiScalaTuningMapCleanup()
  if renoise.tool():has_timer(PakettiScalaTuningMapTick) then
    renoise.tool():remove_timer(PakettiScalaTuningMapTick)
  end
  preview_off()
  PSTM_canvas = nil
end

-- Detach + close on document release so a left-open canvas/timer cannot crash
-- Renoise on New/Load Song (the song-lifecycle SIGSEGV class).
local function install_release_guard()
  if PSTM_release_installed then return end
  PSTM_release_installed = true
  renoise.tool().app_release_document_observable:add_notifier(function()
    if PakettiScalaTuningMapDialog and PakettiScalaTuningMapDialog.visible then
      pcall(function() PakettiScalaTuningMapDialog:close() end)
    end
    PakettiScalaTuningMapDialog = nil
    PakettiScalaTuningMapCleanup()
  end)
end

local function key_handler(dialog, key)
  if key.modifiers == "" and key.name == preferences.pakettiDialogClose.value then
    dialog:close()
    PakettiScalaTuningMapDialog = nil
    PakettiScalaTuningMapCleanup()
    return nil
  end
  return key
end

-- ===========================================================================
-- Buttons
-- ===========================================================================

local function load_scala()
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr then
    renoise.app():show_status("Paketti Scala Tuning Map: no instrument selected")
    return
  end
  local fn = renoise.app():prompt_for_filename_to_read({"*.scl"}, "Load Scala (.scl) tuning file")
  if not fn or fn == "" then return end
  local ok = instr.trigger_options:load_tuning(fn)
  if ok then
    renoise.app():show_status("Loaded tuning: " .. (instr.trigger_options.tuning_name or fn))
  else
    renoise.app():show_status("Paketti Scala Tuning Map: failed to load " .. fn)
  end
  PSTM_last_sig = nil
  if PSTM_canvas then PSTM_canvas:invalidate() end
end

local function reset_12tet()
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr then return end
  instr.trigger_options.tuning = {}        -- empty disables custom tuning
  instr.trigger_options.tuning_name = ""
  renoise.app():show_status("Tuning reset to 12-TET on selected instrument")
  PSTM_last_sig = nil
  if PSTM_canvas then PSTM_canvas:invalidate() end
end

-- ===========================================================================
-- Dialog
-- ===========================================================================

function PakettiScalaTuningMapShow()
  if not PAKETTI_HAS_CANVAS then
    renoise.app():show_warning("Paketti Scala Tuning Map requires Renoise 3.5 or newer (Canvas API).")
    return
  end
  if PakettiScalaTuningMapDialog and PakettiScalaTuningMapDialog.visible then
    PakettiScalaTuningMapDialog:close()
    PakettiScalaTuningMapDialog = nil
    PakettiScalaTuningMapCleanup()
    return
  end

  local vb = renoise.ViewBuilder()
  PSTM_vb = vb
  PSTM_highlight_note = -1
  PSTM_view_start = 36
  PSTM_last_sig = nil

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:canvas{
      id = CANVAS_ID,
      width = CANVAS_W,
      height = CANVAS_H,
      mode = "plain",
      render = PakettiScalaTuningMapRender,
      mouse_events = {"down", "up", "exit"},
      mouse_handler = PakettiScalaTuningMapMouse,
    },
    vb:row{
      spacing = 4,
      vb:button{text = "\226\151\132 Period", width = 70, notifier = function() shift_view(-get_tuning().n) end},
      vb:button{text = "Period \226\150\182", width = 70, notifier = function() shift_view(get_tuning().n) end},
      vb:button{text = "\226\151\132 Note", width = 60, notifier = function() shift_view(-1) end},
      vb:button{text = "Note \226\150\182", width = 60, notifier = function() shift_view(1) end},
      vb:button{text = "Jump to Current", width = 110, notifier = function()
        follow_to_note(true)
        if PSTM_canvas then PSTM_canvas:invalidate() end
      end},
      vb:checkbox{value = PSTM_follow, notifier = function(v) PSTM_follow = v end},
      vb:text{text = "Follow note input"},
    },
    vb:row{
      spacing = 4,
      vb:button{text = "Load Scala (.scl) onto Instrument...", width = 230, notifier = load_scala},
      vb:button{text = "Reset to 12-TET", width = 120, notifier = reset_12tet},
    },
    vb:text{
      text = "Same colour = octave-equivalent (same scale degree). Off-white rows are period roots.\n"
        .. "Click a row to preview the note. The row under the pattern cursor is highlighted live.",
      font = "italic",
    },
  }

  PakettiScalaTuningMapDialog = renoise.app():show_custom_dialog(
    "Paketti Scala Tuning Map", content, key_handler)
  PSTM_canvas = vb.views[CANVAS_ID]

  if not renoise.tool():has_timer(PakettiScalaTuningMapTick) then
    renoise.tool():add_timer(PakettiScalaTuningMapTick, 120)
  end
  install_release_guard()

  -- restore pattern editor focus so note input keeps flowing while the map is open
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  if PSTM_canvas then PSTM_canvas:invalidate() end
end

-- ===========================================================================
-- Registration (functions above are all defined before this block)
-- ===========================================================================

local menus = {"Main Menu:Tools:Paketti:Microtonal Tunings", "Instrument Box:Paketti:Microtonal Tunings"}
for _, base in ipairs(menus) do
  PakettiAddMenuEntry{name = base .. ":Scala Tuning Map...", invoke = PakettiScalaTuningMapShow}
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Scala Tuning Map",
  invoke = function() PakettiScalaTuningMapShow() end,
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Scala Tuning Map",
  invoke = function(message) if message:is_trigger() then PakettiScalaTuningMapShow() end end,
}
