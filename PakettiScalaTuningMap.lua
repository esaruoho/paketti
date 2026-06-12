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
local SCROLL_ID = "paketti_scala_tuning_map_scroll"
local CANVAS_W = 700
local CANVAS_H = 470
local HEADER_H = 76
local ROW_H = 16
local ROWS = math.floor((CANVAS_H - HEADER_H) / ROW_H)

local ROOT_NOTE = 48                              -- Renoise C-4 = tuning root (1/1)
local C4_HZ = 440 * 2 ^ ((ROOT_NOTE - 57) / 12)  -- middle C in standard A4=440 (~261.63 Hz)
local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}

-- column layout (x positions computed dynamically from enabled columns)
local SW_X    = 6     -- colour swatch
local NAME_X  = 30    -- first text column starts here
local ROW_SIZE = 7

local PSTM_vb = nil
local PSTM_canvas = nil
local PSTM_scrollbar = nil
local PSTM_suppress_scroll = false   -- guard against scrollbar<->view_start feedback
local PSTM_view_start = 36
local PSTM_highlight_note = -1
local PSTM_follow = true
local PSTM_show_notation = true       -- "MICRO": ups-and-downs microtonal notation (EDO tunings)
local PSTM_show_fraction = true       -- "FRAC": within-period ratio as a fraction (JI / approximation)
local PSTM_show_cents_period = true   -- "CENTS-P": cents within the period (interval-table style)
local PSTM_show_cents_root = true     -- "CENTS-R": cents from the absolute root (C-4 = 0)
local PSTM_playing = nil          -- {i=instr_idx, t=track_idx, n=note}
local PSTM_release_installed = false

-- observer bookkeeping (event-driven refresh on instrument / tuning change)
local PSTM_song = nil
local PSTM_idx_fn = nil           -- bound to selected_instrument_index_observable
local PSTM_tuning_obs = {}        -- array of {obs=, fn=} for current instrument

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

-- Best rational approximation p/q of a ratio, via continued-fraction convergents.
-- Returns the simplest fraction within TOL cents; if none, the most accurate one
-- under the denominator cap. Works for any ratio: exact for JI .scl files
-- (3/2, 5/4 ...), and the nearest just-intonation reading for EDO/irrational
-- steps (e.g. 31edo step 18 -> 3/2, step 1 -> 45/44). errcents flags how far off.
local function ratio_to_fraction(r)
  local DENOM_CAP, TOL = 128, 7.0
  local function cents(p, q) return 1200 * math.log((p / q) / r) / math.log(2) end
  local hm1, hm2 = 1, 0
  local km1, km2 = 0, 1
  local x = r
  local best_p, best_q, best_err = 1, 1, math.abs(cents(1, 1))
  local simple_p, simple_q, simple_err   -- simplest fraction within TOL cents
  for _ = 1, 40 do
    local a = math.floor(x + 1e-9)
    local h = a * hm1 + hm2
    local k = a * km1 + km2
    if k > DENOM_CAP or k <= 0 then break end
    local err = math.abs(cents(h, k))
    if err < best_err then best_p, best_q, best_err = h, k, err end
    if not simple_p and err < TOL then simple_p, simple_q, simple_err = h, k, err end
    local frac = x - a
    if frac < 1e-9 then return h, k, err end   -- CF terminated => exact rational (JI .scl)
    hm2, hm1 = hm1, h
    km2, km1 = km1, k
    x = 1 / frac
  end
  if simple_p then return simple_p, simple_q, simple_err end   -- EDO: simplest close ratio
  return best_p, best_q, best_err
end

-- "p/q" (exact) or "~p/q" (approximation, > 0.5 cents off)
local function fraction_str(r)
  local p, q, err = ratio_to_fraction(r)
  local s = p .. "/" .. q
  if err > 0.5 then s = "~" .. s end
  return s
end

-- ---------------------------------------------------------------------------
-- Ups-and-downs microtonal notation (for equal divisions of the octave).
-- Spells each EDO degree as the nearest 12-tone note (the anchors ARE the 12TET
-- notes, placed by the EDO's native circle of fifths) plus up/down arrows for
-- the steps in between. e.g. in 22EDO: 0=C, 1=^C, 2=vC#, 3=C#, 4=D ...
-- This is the universal up/down notation; it only applies to octave EDOs.
-- ---------------------------------------------------------------------------
local NOTATE_PC = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- is this tuning an equal division of the (2/1) octave? returns N or nil
local function detect_edo(ratios)
  local n = #ratios
  if n < 2 then return nil end
  if math.abs(ratios[n] - 2.0) > 0.0015 then return nil end   -- octave period only
  for i = 1, n do
    local expected = 2 ^ (i / n)
    if math.abs(ratios[i] - expected) > expected * 0.003 then return nil end
  end
  return n
end

-- the 12 chromatic anchors of an N-EDO as {pc=0..11, step=0..N-1}
local function edo_anchors(n)
  local fifth = math.floor(n * (math.log(1.5) / math.log(2)) + 0.5)
  local apotome = 7 * fifth - 4 * n
  -- chain-of-fifths index per natural nominal: F=-1 C=0 G=1 D=2 A=3 E=4 B=5
  local nat = {C = 0, G = 1, D = 2, A = 3, E = 4, B = 5, F = -1}
  local function step_of(letter) return (nat[letter] * fifth) % n end
  local naturals = {C = step_of("C"), D = step_of("D"), E = step_of("E"),
                    F = step_of("F"), G = step_of("G"), A = step_of("A"), B = step_of("B")}
  local anchors = {
    {pc = 0,  step = naturals.C},
    {pc = 1,  step = (naturals.C + apotome) % n},
    {pc = 2,  step = naturals.D},
    {pc = 3,  step = (naturals.D + apotome) % n},
    {pc = 4,  step = naturals.E},
    {pc = 5,  step = naturals.F},
    {pc = 6,  step = (naturals.F + apotome) % n},
    {pc = 7,  step = naturals.G},
    {pc = 8,  step = (naturals.G + apotome) % n},
    {pc = 9,  step = naturals.A},
    {pc = 10, step = (naturals.A + apotome) % n},
    {pc = 11, step = naturals.B},
  }
  return anchors
end

local function ups_downs(u)
  if u == 0 then return "" end
  local sym = (u > 0) and "\226\134\145" or "\226\134\147"   -- ↑ / ↓
  local mag = math.abs(u)
  if mag <= 3 then return string.rep(sym, mag) end
  return sym .. tostring(mag)
end

-- ups-and-downs spelling for degree d of an N-EDO (anchors precomputed)
local function edo_notation(d, n, anchors)
  local best_u, best_pc, best_abs = 0, 0, 1e9
  for _, a in ipairs(anchors) do
    local u = (d - a.step) % n
    if u > n / 2 then u = u - n end            -- signed nearest (-n/2 .. n/2]
    local au = math.abs(u)
    -- prefer smallest |u|; on tie prefer up-spelling (u>0); then lower pc
    if au < best_abs
       or (au == best_abs and u > best_u)
       or (au == best_abs and u == best_u and a.pc < best_pc) then
      best_u, best_pc, best_abs = u, a.pc, au
    end
  end
  return ups_downs(best_u) .. NOTATE_PC[best_pc + 1]
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

  -- microtonal (ups-and-downs) notation only applies to equal octave divisions
  local edoN = detect_edo(ratios)
  local anchors = edoN and edo_anchors(edoN) or nil

  -- build the enabled-column layout (left to right), then the bar fills the rest
  local cols = {}
  cols[#cols + 1] = {h = "NOTE",  w = 42, get = function(note) return note_name(note) end}
  if PSTM_show_notation then
    cols[#cols + 1] = {h = "MICRO", w = 58, get = function(_, deg)
      if edoN then return edo_notation(deg, edoN, anchors) else return "\226\128\148" end  -- em dash
    end}
  end
  cols[#cols + 1] = {h = "DEG",   w = 44, get = function(_, deg) return tostring(deg) end}
  if PSTM_show_fraction then
    cols[#cols + 1] = {h = "FRAC", w = 86, get = function(_, _, ri) return fraction_str(ri) end}
  end
  cols[#cols + 1] = {h = "RATIO", w = 64, get = function(_, _, ri) return string.format("%.3f", ri) end}
  if PSTM_show_cents_period then
    cols[#cols + 1] = {h = "CENTS-P", w = 74, get = function(_, _, ri) return string.format("%.1f", ratio_to_cents(ri)) end}
  end
  if PSTM_show_cents_root then
    cols[#cols + 1] = {h = "CENTS-R", w = 80, get = function(_, _, _, tot) return string.format("%.1f", ratio_to_cents(tot)) end}
  end
  cols[#cols + 1] = {h = "HZ", w = 70, get = function(_, _, _, tot) return string.format("%.1f", C4_HZ * tot) end}
  local x = NAME_X
  for _, c in ipairs(cols) do c.x = x; x = x + c.w end
  local bar_x = x + 8
  local bar_w = math.max(20, CANVAS_W - 8 - bar_x)

  -- current-note readout (communicates whichever columns are enabled)
  if PSTM_highlight_note >= 0 and PSTM_highlight_note <= 119 then
    local d, ri, tot = note_info(PSTM_highlight_note, ratios)
    local line = note_name(PSTM_highlight_note)
    if PSTM_show_notation and edoN then line = line .. " = " .. edo_notation(d, edoN, anchors) end
    line = line .. "   DEG " .. d .. " OF " .. n
    if PSTM_show_fraction then line = line .. "   " .. fraction_str(ri) end
    line = line .. "   " .. string.format("%.3f", ri)
    if PSTM_show_cents_period then line = line .. "   " .. string.format("%.1f", ratio_to_cents(ri)) .. "C-P" end
    if PSTM_show_cents_root then line = line .. "   " .. string.format("%.1f", ratio_to_cents(tot)) .. "C-R" end
    line = line .. "   " .. string.format("%.1f", C4_HZ * tot) .. " HZ"
    draw_text(ctx, line, 6, 46, 8, {255, 245, 150, 255})
  else
    draw_text(ctx, "PLAY OR SELECT A NOTE TO SEE ITS PITCH", 6, 46, 6, {120, 120, 135, 255})
  end

  -- column headers
  for _, c in ipairs(cols) do
    draw_text(ctx, c.h, c.x, 62, 6, {120, 120, 140, 255})
  end

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
        ctx.fill_color = degree_color(degree, n, 40)
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

      -- text columns
      local txt_col = is_hl and {255, 255, 255, 255} or {210, 210, 222, 255}
      for _, c in ipairs(cols) do
        draw_text(ctx, c.get(note, degree, ratio_in, total), c.x, y + 4, ROW_SIZE, txt_col)
      end

      -- within-period position bar (log-pitch ladder)
      local frac = (period_cents > 0) and (ratio_to_cents(ratio_in) / period_cents) or 0
      ctx.fill_color = {40, 40, 52, 255}
      ctx:fill_rect(bar_x, y + 5, bar_w, ROW_H - 10)
      ctx.fill_color = degree_color(degree, n, 230)
      ctx:fill_rect(bar_x, y + 5, math.max(1, frac * bar_w), ROW_H - 10)
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
    if PSTM_canvas then PSTM_canvas:update() end
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

-- push the current view_start into the scrollbar thumb (suppress its notifier)
local function sync_scrollbar()
  if not PSTM_scrollbar then return end
  PSTM_suppress_scroll = true
  pcall(function() PSTM_scrollbar.value = PSTM_view_start end)
  PSTM_suppress_scroll = false
end

local function follow_to_note(force)
  if PSTM_highlight_note < 0 then return end
  if force or PSTM_highlight_note < PSTM_view_start
     or PSTM_highlight_note > PSTM_view_start + ROWS - 1 then
    PSTM_view_start = PSTM_highlight_note - math.floor(ROWS / 2)
    clamp_view()
    sync_scrollbar()
  end
end

local function shift_view(delta)
  PSTM_view_start = PSTM_view_start + delta
  clamp_view()
  sync_scrollbar()
  if PSTM_canvas then PSTM_canvas:update() end
end

-- ===========================================================================
-- Observers — event-driven refresh on instrument switch / tuning change
-- ===========================================================================

local function refresh_now()
  if PSTM_canvas then pcall(function() PSTM_canvas:update() end) end
end

local function unbind_tuning_obs()
  for _, o in ipairs(PSTM_tuning_obs) do
    pcall(function()
      if o.obs and o.obs:has_notifier(o.fn) then o.obs:remove_notifier(o.fn) end
    end)
  end
  PSTM_tuning_obs = {}
end

-- (re)bind to the CURRENT instrument's tuning + tuning_name observables
local function bind_tuning_obs()
  unbind_tuning_obs()
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr then return end
  local topt = instr.trigger_options
  local list = {topt.tuning_observable, topt.tuning_name_observable}
  for _, obs in ipairs(list) do
    if obs then
      pcall(function()
        obs:add_notifier(refresh_now)
        table.insert(PSTM_tuning_obs, {obs = obs, fn = refresh_now})
      end)
    end
  end
end

local function bind_observers()
  local song = renoise.song()
  if not song then return end
  PSTM_song = song
  if not PSTM_idx_fn then
    PSTM_idx_fn = function()
      bind_tuning_obs()   -- new instrument => rebind tuning observers
      refresh_now()
    end
  end
  pcall(function()
    if not song.selected_instrument_index_observable:has_notifier(PSTM_idx_fn) then
      song.selected_instrument_index_observable:add_notifier(PSTM_idx_fn)
    end
  end)
  bind_tuning_obs()
end

local function unbind_observers()
  unbind_tuning_obs()
  if PSTM_song and PSTM_idx_fn then
    pcall(function()
      if PSTM_song.selected_instrument_index_observable:has_notifier(PSTM_idx_fn) then
        PSTM_song.selected_instrument_index_observable:remove_notifier(PSTM_idx_fn)
      end
    end)
  end
  PSTM_song = nil
end

-- ===========================================================================
-- Live tick — follows the pattern cursor (the "last entered" note) and keeps
-- the canvas fresh. Self-cleaning and song-lifecycle safe. Instrument/tuning
-- changes are handled by the observers above; this also re-reads every tick as
-- a backstop, so the map can never go stale.
-- ===========================================================================

function PakettiScalaTuningMapTick()
  if not (PakettiScalaTuningMapDialog and PakettiScalaTuningMapDialog.visible) then
    PakettiScalaTuningMapCleanup()
    return
  end
  pcall(function()
    local song = renoise.song()
    if not song then return end

    -- read note under the pattern-editor cursor (the "last entered" note)
    local cidx = song.selected_note_column_index
    if cidx and cidx >= 1 then
      local line = song.selected_line
      if line then
        local col = line.note_columns[cidx]
        if col and col.note_value <= 119 and col.note_value ~= PSTM_highlight_note then
          PSTM_highlight_note = col.note_value
          if PSTM_follow then follow_to_note(false) end
        end
      end
    end

    -- backstop: always reflect current instrument/tuning state
    if PSTM_canvas then PSTM_canvas:update() end
  end)
end

-- ===========================================================================
-- Lifecycle
-- ===========================================================================

function PakettiScalaTuningMapCleanup()
  if renoise.tool():has_timer(PakettiScalaTuningMapTick) then
    renoise.tool():remove_timer(PakettiScalaTuningMapTick)
  end
  unbind_observers()
  preview_off()
  PSTM_canvas = nil
  PSTM_scrollbar = nil
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
  if PSTM_canvas then PSTM_canvas:update() end
end

local function reset_12tet()
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr then return end
  instr.trigger_options.tuning = {}        -- empty disables custom tuning
  instr.trigger_options.tuning_name = ""
  renoise.app():show_status("Tuning reset to 12-TET on selected instrument")
  if PSTM_canvas then PSTM_canvas:update() end
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

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:row{
      spacing = 2,
      vb:canvas{
        id = CANVAS_ID,
        width = CANVAS_W,
        height = CANVAS_H,
        mode = "plain",
        render = PakettiScalaTuningMapRender,
        mouse_events = {"down", "up", "exit"},
        mouse_handler = PakettiScalaTuningMapMouse,
      },
      vb:scrollbar{
        id = SCROLL_ID,
        min = 0,
        max = 120,                  -- 120 notes (0..119)
        value = PSTM_view_start,
        step = 1,
        pagestep = ROWS,            -- visible window = number of rows
        autohide = false,
        width = 18,
        height = CANVAS_H,
        notifier = function(v)
          if PSTM_suppress_scroll then return end
          PSTM_view_start = v
          if PSTM_canvas then PSTM_canvas:update() end
        end,
      },
    },
    vb:row{
      spacing = 4,
      vb:button{text = "\226\151\132 Period", width = 70, notifier = function() shift_view(-get_tuning().n) end},
      vb:button{text = "Period \226\150\182", width = 70, notifier = function() shift_view(get_tuning().n) end},
      vb:button{text = "\226\151\132 Note", width = 60, notifier = function() shift_view(-1) end},
      vb:button{text = "Note \226\150\182", width = 60, notifier = function() shift_view(1) end},
      vb:button{text = "Jump to Current", width = 110, notifier = function()
        follow_to_note(true)
        if PSTM_canvas then PSTM_canvas:update() end
      end},
      vb:checkbox{value = PSTM_follow, notifier = function(v) PSTM_follow = v end},
      vb:text{text = "Follow note input"},
    },
    vb:row{
      spacing = 4,
      vb:checkbox{value = PSTM_show_notation, notifier = function(v)
        PSTM_show_notation = v
        if PSTM_canvas then PSTM_canvas:update() end
      end},
      vb:text{text = "Microtonal notation (MICRO)"},
      vb:checkbox{value = PSTM_show_fraction, notifier = function(v)
        PSTM_show_fraction = v
        if PSTM_canvas then PSTM_canvas:update() end
      end},
      vb:text{text = "Fraction (FRAC)"},
      vb:checkbox{value = PSTM_show_cents_period, notifier = function(v)
        PSTM_show_cents_period = v
        if PSTM_canvas then PSTM_canvas:update() end
      end},
      vb:text{text = "Cents within period (CENTS-P)"},
      vb:checkbox{value = PSTM_show_cents_root, notifier = function(v)
        PSTM_show_cents_root = v
        if PSTM_canvas then PSTM_canvas:update() end
      end},
      vb:text{text = "Cents from root (CENTS-R)"},
    },
    vb:row{
      spacing = 4,
      vb:button{text = "Load Scala (.scl) onto Instrument...", width = 230, notifier = load_scala},
      vb:button{text = "Reset to 12-TET", width = 120, notifier = reset_12tet},
    },
    vb:text{
      text = "Same colour = octave-equivalent (same scale degree). Off-white rows are period roots.\n"
        .. "DEG = scale-degree number within the period. MICRO = ups-and-downs notation (EDO tunings only).\n"
        .. "FRAC = ratio as a fraction (exact for JI tunings; nearest just-intonation reading for EDO, marked ~).\n"
        .. "CENTS-P = cents within the period (resets each octave). CENTS-R = cents from the absolute root (C-4 = 0).\n"
        .. "Click a row to preview the note. The row under the pattern cursor is highlighted live.",
      font = "italic",
    },
  }

  PakettiScalaTuningMapDialog = renoise.app():show_custom_dialog(
    "Paketti Scala Tuning Map", content, key_handler)
  PSTM_canvas = vb.views[CANVAS_ID]
  PSTM_scrollbar = vb.views[SCROLL_ID]

  if not renoise.tool():has_timer(PakettiScalaTuningMapTick) then
    renoise.tool():add_timer(PakettiScalaTuningMapTick, 120)
  end
  bind_observers()        -- instant refresh on instrument switch / tuning change
  install_release_guard()

  -- restore pattern editor focus so note input keeps flowing while the map is open
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  if PSTM_canvas then PSTM_canvas:update() end
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
