-- PakettiCanvasFontMono.lua
-- A clean MONOSPACE canvas font, offered alongside the existing 8bit "tDR"
-- (Asteroids-style) font. Selected globally via the Paketti preference
-- preferences.pakettiCanvasFontStyle ("8bit" | "monospace"); the dispatcher in
-- PakettiCanvasFont.lua routes every canvas dialog's PakettiCanvasFontDrawText
-- call to whichever style is active. Default is "8bit".
--
-- DESIGN: deliberately distinct from the 8bit font so the two read differently
-- side by side. The 8bit font is angular/pointed; this monospace uses ROUND
-- bowls (arcs) on C G O Q S U B D P R J and the digits, plus SLAB SERIFS (feet)
-- on the vertical stems (typewriter / terminal feel).
--
-- Glyphs are data-driven: each character is a list of polylines in normalised
-- 0..1 cell coordinates (0,0 = top-left, 1,1 = bottom-right of the glyph cell).
-- Curves are generated with arc() so they're genuinely round. One small renderer
-- turns the polylines into canvas strokes; stroke colour + width are set by the
-- caller (same contract as the 8bit glyph functions).
--
-- Anything not defined here automatically falls back to the 8bit glyph (handled
-- in PakettiCanvasFont.lua), so exotic characters (⌘ ⌥ ↑ ä …) keep rendering.

-- same per-character advance as 8bit, so column layouts stay aligned on switch
PakettiCanvasFontMonoSpacing = 1.4

-- arc as a polyline of {fx,fy} points (degrees; y grows downward)
local function arc(cx, cy, rx, ry, a0, a1, steps)
  local pts = {}
  for k = 0, steps do
    local a = math.rad(a0 + (a1 - a0) * k / steps)
    pts[#pts + 1] = {cx + rx * math.cos(a), cy + ry * math.sin(a)}
  end
  return pts
end

-- glyph data: char -> { polyline, polyline, ... }
local M = {
  -- letters with slab serifs on stems / pointed apex with feet
  A = {{{0.1,1},{0.5,0},{0.9,1}}, {{0.28,0.55},{0.72,0.55}}, {{0.0,1},{0.22,1}}, {{0.78,1},{1.0,1}}},
  E = {{{0.85,0},{0.18,0},{0.18,1},{0.85,1}}, {{0.18,0.5},{0.7,0.5}}},
  F = {{{0.85,0},{0.18,0},{0.18,1}}, {{0.18,0.5},{0.7,0.5}}, {{0.03,1},{0.33,1}}},
  H = {{{0.18,0},{0.18,1}}, {{0.82,0},{0.82,1}}, {{0.18,0.5},{0.82,0.5}},
       {{0.02,0},{0.34,0}}, {{0.02,1},{0.34,1}}, {{0.66,0},{0.98,0}}, {{0.66,1},{0.98,1}}},
  I = {{{0.22,0},{0.78,0}}, {{0.5,0},{0.5,1}}, {{0.22,1},{0.78,1}}},
  J = {{{0.35,0},{0.85,0}}, {{0.7,0},{0.7,0.72}}, arc(0.45,0.72,0.25,0.28,0,180,6)},
  K = {{{0.18,0},{0.18,1}}, {{0.82,0},{0.18,0.52},{0.82,1}},
       {{0.02,0},{0.34,0}}, {{0.02,1},{0.34,1}}},
  L = {{{0.2,0},{0.2,1},{0.85,1}}, {{0.05,0},{0.35,0}}},
  M = {{{0.12,1},{0.12,0},{0.5,0.55},{0.88,0},{0.88,1}}, {{0.0,1},{0.24,1}}, {{0.76,1},{1.0,1}}},
  N = {{{0.18,1},{0.18,0},{0.82,1},{0.82,0}}, {{0.02,0},{0.34,0}}, {{0.66,1},{0.98,1}}},
  T = {{{0.1,0},{0.9,0}}, {{0.5,0},{0.5,1}}, {{0.3,1},{0.7,1}}},
  V = {{{0.1,0},{0.5,1},{0.9,0}}, {{0.0,0},{0.22,0}}, {{0.78,0},{1.0,0}}},
  W = {{{0.1,0},{0.3,1},{0.5,0.4},{0.7,1},{0.9,0}}},
  X = {{{0.12,0},{0.88,1}}, {{0.88,0},{0.12,1}}},
  Y = {{{0.12,0},{0.5,0.5},{0.88,0}}, {{0.5,0.5},{0.5,1}}, {{0.3,1},{0.7,1}}},
  Z = {{{0.12,0},{0.9,0},{0.12,1},{0.9,1}}},
  -- round-bowl letters
  B = {{{0.18,0},{0.18,1}}, arc(0.18,0.25,0.5,0.25,-90,90,8), arc(0.18,0.75,0.58,0.25,-90,90,8),
       {{0.02,0},{0.3,0}}, {{0.02,1},{0.3,1}}},
  C = {arc(0.5,0.5,0.42,0.48,42,318,14)},
  D = {{{0.18,0},{0.18,1}}, arc(0.18,0.5,0.74,0.5,-90,90,12), {{0.02,0},{0.3,0}}, {{0.02,1},{0.3,1}}},
  G = {arc(0.5,0.5,0.42,0.48,40,320,14), {{0.92,0.5},{0.58,0.5}}, {{0.92,0.5},{0.92,0.78}}},
  O = {arc(0.5,0.5,0.44,0.49,0,360,16)},
  P = {{{0.18,0},{0.18,1}}, arc(0.18,0.27,0.6,0.27,-90,90,8), {{0.02,1},{0.34,1}}},
  Q = {arc(0.5,0.5,0.42,0.48,0,360,16), {{0.6,0.66},{0.95,1.05}}},
  R = {{{0.18,0},{0.18,1}}, arc(0.18,0.27,0.6,0.27,-90,90,8), {{0.45,0.54},{0.85,1}},
       {{0.02,1},{0.34,1}}},
  S = {{{0.86,0.16},{0.6,0.02},{0.34,0.04},{0.14,0.26},{0.34,0.48},{0.66,0.52},{0.86,0.74},{0.66,0.96},{0.4,0.98},{0.14,0.84}}},
  U = {{{0.16,0},{0.16,0.62}}, {{0.84,0},{0.84,0.62}}, arc(0.5,0.62,0.34,0.38,0,180,8),
       {{0.0,0},{0.32,0}}, {{0.68,0},{1.0,0}}},

  -- digits (round)
  ["0"] = {arc(0.5,0.5,0.4,0.49,0,360,14), {{0.3,0.78},{0.7,0.22}}},
  ["1"] = {{{0.28,0.22},{0.5,0.02},{0.5,1}}, {{0.28,1},{0.72,1}}},
  ["2"] = {{{0.12,0.28},{0.32,0.04},{0.66,0.04},{0.86,0.28},{0.74,0.52},{0.12,1},{0.9,1}}},
  ["3"] = {{{0.12,0.14},{0.5,0.0},{0.85,0.2},{0.56,0.48},{0.85,0.76},{0.5,1.0},{0.12,0.86}}},
  ["4"] = {{{0.72,1},{0.72,0},{0.12,0.68},{0.92,0.68}}},
  ["5"] = {{{0.85,0.04},{0.26,0.04},{0.2,0.44},{0.56,0.38},{0.85,0.6},{0.78,0.9},{0.4,1.0},{0.12,0.9}}},
  ["6"] = {{{0.82,0.12},{0.48,0.0},{0.2,0.26},{0.12,0.62}}, arc(0.5,0.7,0.38,0.3,0,360,12)},
  ["7"] = {{{0.12,0.04},{0.9,0.04},{0.4,1.0}}, {{0.3,0.5},{0.66,0.5}}},
  ["8"] = {arc(0.5,0.27,0.32,0.27,0,360,12), arc(0.5,0.73,0.4,0.27,0,360,12)},
  ["9"] = {arc(0.5,0.3,0.38,0.3,0,360,12), {{0.88,0.4},{0.86,0.74},{0.52,1.0},{0.2,0.9}}},

  -- punctuation
  [" "] = {},
  ["."] = {{{0.42,0.86},{0.58,0.86},{0.58,1.0},{0.42,1.0},{0.42,0.86}}},
  [","] = {{{0.56,0.82},{0.5,1.0},{0.34,1.15}}},
  ["-"] = {{{0.18,0.5},{0.82,0.5}}},
  ["_"] = {{{0.05,1},{0.95,1}}},
  ["#"] = {{{0.28,0.05},{0.22,0.95}}, {{0.62,0.05},{0.56,0.95}}, {{0.12,0.36},{0.84,0.36}}, {{0.1,0.64},{0.82,0.64}}},
  ["+"] = {{{0.5,0.2},{0.5,0.8}}, {{0.2,0.5},{0.8,0.5}}},
  [":"] = {{{0.42,0.28},{0.58,0.28},{0.58,0.42},{0.42,0.42},{0.42,0.28}}, {{0.42,0.62},{0.58,0.62},{0.58,0.76},{0.42,0.76},{0.42,0.62}}},
  [";"] = {{{0.42,0.28},{0.58,0.28},{0.58,0.42},{0.42,0.42},{0.42,0.28}}, {{0.56,0.62},{0.5,0.82},{0.34,0.98}}},
  ["!"] = {{{0.5,0},{0.5,0.7}}, {{0.42,0.88},{0.58,0.88},{0.58,1.0},{0.42,1.0},{0.42,0.88}}},
  ["?"] = {arc(0.5,0.26,0.34,0.26,160,360,8), {{0.84,0.26},{0.5,0.55},{0.5,0.68}}, {{0.42,0.86},{0.58,0.86},{0.58,1.0},{0.42,1.0},{0.42,0.86}}},
  ["/"] = {{{0.15,1},{0.85,0}}},
  ["\\"] = {{{0.15,0},{0.85,1}}},
  ["="] = {{{0.18,0.4},{0.82,0.4}}, {{0.18,0.6},{0.82,0.6}}},
  ["("] = {arc(0.62,0.5,0.32,0.5,120,240,8)},
  [")"] = {arc(0.38,0.5,0.32,0.5,-60,60,8)},
  ["<"] = {{{0.8,0.12},{0.2,0.5},{0.8,0.88}}},
  [">"] = {{{0.2,0.12},{0.8,0.5},{0.2,0.88}}},
  ["*"] = {{{0.2,0.3},{0.8,0.7}}, {{0.8,0.3},{0.2,0.7}}, {{0.5,0.18},{0.5,0.82}}},
  ["%"] = {{{0.12,1},{0.88,0}}, arc(0.26,0.22,0.16,0.18,0,360,7), arc(0.74,0.78,0.16,0.18,0,360,7)},
}

-- draw one glyph (list of polylines) into the cell at (x,y) with side `s`
local function PakettiCanvasFontMonoDrawGlyph(g, ctx, x, y, s)
  if not g then return end
  for _, poly in ipairs(g) do
    if #poly >= 2 then
      ctx:begin_path()
      for k = 1, #poly do
        local px = x + poly[k][1] * s
        local py = y + poly[k][2] * s
        if k == 1 then ctx:move_to(px, py) else ctx:line_to(px, py) end
      end
      ctx:stroke()
    end
  end
end

-- build the glyph-function table the dispatcher expects:
-- char -> function(ctx, x, y, size)
PakettiCanvasFontMonoFunctions = {}
for ch, g in pairs(M) do
  PakettiCanvasFontMonoFunctions[ch] = function(ctx, x, y, size)
    PakettiCanvasFontMonoDrawGlyph(g, ctx, x, y, size)
  end
end

-- ===========================================================================
-- Canvas Font Demo — shows the SAME sample text in BOTH fonts side by side,
-- plus the live preference switch. Screenshot this for Ronny.
-- ===========================================================================

PakettiCanvasFontDemoDialog = nil

local DEMO_W = 920
local DEMO_H = 470

local PCFD_SAMPLE = {
  "ABCDEFGHIJKLM",
  "NOPQRSTUVWXYZ",
  "0123456789",
  "PAKETTI CANVAS FONT",
  "-+:;!?/#=<>().,",
  "C-4 G-3 A#5 1.587",
  "261.6 HZ  1200.0C",
}

local function PCFD_render_column(ctx, style, x0, w)
  local title = (style == "monospace") and "MONOSPACE" or "8BIT (TDR)"
  -- panel
  ctx.fill_color = {16, 16, 22, 255}
  ctx:fill_rect(x0, 0, w, DEMO_H)
  -- title
  ctx.stroke_color = {180, 220, 255, 255}
  ctx.line_width = 1
  PakettiCanvasFontDrawTextStyled(ctx, title, x0 + 16, 14, 14, style)
  -- divider under title
  ctx.stroke_color = {70, 70, 90, 255}
  ctx:begin_path(); ctx:move_to(x0 + 8, 44); ctx:line_to(x0 + w - 8, 44); ctx:stroke()
  -- sample lines
  local y = 64
  ctx.stroke_color = {220, 220, 230, 255}
  for _, line in ipairs(PCFD_SAMPLE) do
    PakettiCanvasFontDrawTextStyled(ctx, line, x0 + 16, y, 16, style)
    y = y + 30
  end
  -- a big size sample
  ctx.stroke_color = {120, 230, 140, 255}
  PakettiCanvasFontDrawTextStyled(ctx, "PAKETTI", x0 + 16, y + 16, 34, style)
end

function PakettiCanvasFontDemoRender(ctx)
  ctx.fill_color = {10, 10, 14, 255}
  ctx:fill_rect(0, 0, DEMO_W, DEMO_H)
  local half = DEMO_W / 2
  PCFD_render_column(ctx, "8bit", 0, half)
  PCFD_render_column(ctx, "monospace", half, half)
  -- center divider
  ctx.stroke_color = {90, 90, 110, 255}
  ctx.line_width = 2
  ctx:begin_path(); ctx:move_to(half, 0); ctx:line_to(half, DEMO_H); ctx:stroke()
end

function PakettiCanvasFontDemoShow()
  if not PAKETTI_HAS_CANVAS then
    renoise.app():show_warning("Canvas Font Demo requires Renoise 3.5 or newer (Canvas API).")
    return
  end
  if PakettiCanvasFontDemoDialog and PakettiCanvasFontDemoDialog.visible then
    PakettiCanvasFontDemoDialog:close()
    PakettiCanvasFontDemoDialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local current = (preferences.pakettiCanvasFontStyle.value == "monospace") and 2 or 1

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:canvas{
      id = "pcfd_canvas",
      width = DEMO_W,
      height = DEMO_H,
      mode = "plain",
      render = PakettiCanvasFontDemoRender,
    },
    vb:row{
      spacing = 6,
      vb:text{text = "Active canvas font (all Paketti canvas dialogs):", style = "strong"},
      vb:switch{
        id = "pcfd_switch",
        width = 220,
        items = {"8bit", "Monospace"},
        value = current,
        notifier = function(idx)
          preferences.pakettiCanvasFontStyle.value = (idx == 2) and "monospace" or "8bit"
          preferences:save_as("preferences.xml")
          renoise.app():show_status("Canvas font set to: " .. preferences.pakettiCanvasFontStyle.value
            .. " (open any canvas dialog to see it)")
        end,
      },
    },
    vb:text{
      text = "Left = 8bit (tDR / Asteroids). Right = monospace. The switch sets the Paketti preference\n"
        .. "that every canvas dialog reads, so changing it restyles them all. The two panels above\n"
        .. "always show both styles regardless of the setting, for comparison.",
      font = "italic",
    },
  }

  PakettiCanvasFontDemoDialog = renoise.app():show_custom_dialog(
    "Paketti Canvas Font Demo (8bit vs Monospace)", content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ===========================================================================
-- Registration
-- ===========================================================================

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Canvas Font Demo (8bit vs Monospace)...", invoke = PakettiCanvasFontDemoShow}

renoise.tool():add_keybinding{name = "Global:Paketti:Canvas Font Demo", invoke = function() PakettiCanvasFontDemoShow() end}
