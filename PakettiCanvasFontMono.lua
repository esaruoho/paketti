-- PakettiCanvasFontMono.lua
-- A clean MONOSPACE canvas font, offered alongside the existing 8bit "tDR"
-- (Asteroids-style) font. Selected globally via the Paketti preference
-- preferences.pakettiCanvasFontStyle ("8bit" | "monospace"); the dispatcher in
-- PakettiCanvasFont.lua routes every canvas dialog's PakettiCanvasFontDrawText
-- call to whichever style is active. Default is "8bit".
--
-- Glyphs are data-driven: each character is a list of polylines in normalised
-- 0..1 cell coordinates (0,0 = top-left, 1,1 = bottom-right of the glyph cell).
-- One small renderer turns them into canvas strokes, so the whole alphabet is
-- compact and easy to tweak for Ronny's review. Stroke colour + width are set by
-- the caller (same contract as the 8bit glyph functions).
--
-- Coverage: A-Z, 0-9, space and common punctuation. Anything not defined here
-- automatically falls back to the 8bit glyph (handled in PakettiCanvasFont.lua),
-- so exotic characters (⌘ ⌥ ↑ ä …) keep rendering while mono coverage grows.

-- same per-character advance as 8bit, so column layouts stay aligned on switch
PakettiCanvasFontMonoSpacing = 1.4

-- glyph data: char -> { polyline, polyline, ... }; polyline = { {fx,fy}, ... }
local M = {
  A = {{{0,1},{0.5,0},{1,1}}, {{0.2,0.6},{0.8,0.6}}},
  B = {{{0,0},{0,1}}, {{0,0},{0.7,0},{0.95,0.25},{0.7,0.5},{0,0.5}}, {{0,0.5},{0.75,0.5},{1,0.75},{0.75,1},{0,1}}},
  C = {{{1,0.2},{0.65,0},{0.25,0},{0,0.25},{0,0.75},{0.25,1},{0.65,1},{1,0.8}}},
  D = {{{0,0},{0,1}}, {{0,0},{0.55,0},{0.95,0.3},{0.95,0.7},{0.55,1},{0,1}}},
  E = {{{1,0},{0,0},{0,1},{1,1}}, {{0,0.5},{0.7,0.5}}},
  F = {{{1,0},{0,0},{0,1}}, {{0,0.5},{0.7,0.5}}},
  G = {{{1,0.2},{0.65,0},{0.25,0},{0,0.25},{0,0.75},{0.25,1},{0.7,1},{1,0.8},{1,0.55},{0.6,0.55}}},
  H = {{{0,0},{0,1}}, {{1,0},{1,1}}, {{0,0.5},{1,0.5}}},
  I = {{{0.2,0},{0.8,0}}, {{0.5,0},{0.5,1}}, {{0.2,1},{0.8,1}}},
  J = {{{0.3,0},{1,0}}, {{0.7,0},{0.7,0.78},{0.5,1},{0.2,1},{0,0.78}}},
  K = {{{0,0},{0,1}}, {{1,0},{0,0.5},{1,1}}},
  L = {{{0,0},{0,1},{1,1}}},
  M = {{{0,1},{0,0},{0.5,0.5},{1,0},{1,1}}},
  N = {{{0,1},{0,0},{1,1},{1,0}}},
  O = {{{0.25,0},{0.75,0},{1,0.25},{1,0.75},{0.75,1},{0.25,1},{0,0.75},{0,0.25},{0.25,0}}},
  P = {{{0,1},{0,0},{0.7,0},{0.95,0.25},{0.7,0.5},{0,0.5}}},
  Q = {{{0.25,0},{0.75,0},{1,0.25},{1,0.75},{0.75,1},{0.25,1},{0,0.75},{0,0.25},{0.25,0}}, {{0.6,0.7},{1,1.05}}},
  R = {{{0,1},{0,0},{0.7,0},{0.95,0.25},{0.7,0.5},{0,0.5}}, {{0.45,0.5},{1,1}}},
  S = {{{1,0.2},{0.7,0},{0.3,0},{0,0.25},{0.3,0.5},{0.7,0.5},{1,0.75},{0.7,1},{0.3,1},{0,0.8}}},
  T = {{{0,0},{1,0}}, {{0.5,0},{0.5,1}}},
  U = {{{0,0},{0,0.75},{0.25,1},{0.75,1},{1,0.75},{1,0}}},
  V = {{{0,0},{0.5,1},{1,0}}},
  W = {{{0,0},{0.25,1},{0.5,0.4},{0.75,1},{1,0}}},
  X = {{{0,0},{1,1}}, {{1,0},{0,1}}},
  Y = {{{0,0},{0.5,0.5},{1,0}}, {{0.5,0.5},{0.5,1}}},
  Z = {{{0,0},{1,0},{0,1},{1,1}}},

  ["0"] = {{{0.25,0},{0.75,0},{1,0.25},{1,0.75},{0.75,1},{0.25,1},{0,0.75},{0,0.25},{0.25,0}}, {{0.25,0.8},{0.75,0.2}}},
  ["1"] = {{{0.3,0.2},{0.5,0},{0.5,1}}, {{0.3,1},{0.7,1}}},
  ["2"] = {{{0,0.25},{0.3,0},{0.7,0},{1,0.3},{0,1},{1,1}}},
  ["3"] = {{{0,0.1},{0.7,0},{1,0.25},{0.6,0.5},{1,0.75},{0.7,1},{0,0.9}}},
  ["4"] = {{{0.7,1},{0.7,0},{0,0.65},{1,0.65}}},
  ["5"] = {{{1,0},{0,0},{0,0.45},{0.7,0.45},{1,0.7},{0.7,1},{0.2,1},{0,0.85}}},
  ["6"] = {{{0.9,0.1},{0.5,0},{0.2,0.1},{0,0.5},{0,0.8},{0.25,1},{0.6,1},{0.9,0.78},{0.6,0.5},{0.1,0.55}}},
  ["7"] = {{{0,0},{1,0},{0.4,1}}},
  ["8"] = {{{0.3,0},{0.7,0},{0.9,0.25},{0.7,0.5},{0.3,0.5},{0.1,0.25},{0.3,0}}, {{0.3,0.5},{0.7,0.5},{0.95,0.75},{0.7,1},{0.3,1},{0.05,0.75},{0.3,0.5}}},
  ["9"] = {{{0.1,0.9},{0.5,1},{0.8,0.9},{1,0.5},{1,0.2},{0.75,0},{0.4,0},{0.1,0.22},{0.4,0.5},{0.9,0.45}}},

  [" "] = {},
  ["."] = {{{0.42,0.88},{0.58,0.88},{0.58,1},{0.42,1},{0.42,0.88}}},
  [","] = {{{0.55,0.82},{0.5,1},{0.35,1.15}}},
  ["-"] = {{{0.2,0.5},{0.8,0.5}}},
  ["_"] = {{{0,1},{1,1}}},
  ["#"] = {{{0.25,0},{0.25,1}}, {{0.6,0},{0.6,1}}, {{0.1,0.35},{0.85,0.35}}, {{0.1,0.65},{0.85,0.65}}},
  ["+"] = {{{0.5,0.2},{0.5,0.8}}, {{0.2,0.5},{0.8,0.5}}},
  [":"] = {{{0.42,0.28},{0.58,0.28},{0.58,0.42},{0.42,0.42},{0.42,0.28}}, {{0.42,0.62},{0.58,0.62},{0.58,0.76},{0.42,0.76},{0.42,0.62}}},
  [";"] = {{{0.42,0.28},{0.58,0.28},{0.58,0.42},{0.42,0.42},{0.42,0.28}}, {{0.55,0.62},{0.5,0.82},{0.35,0.98}}},
  ["!"] = {{{0.5,0},{0.5,0.7}}, {{0.5,0.88},{0.5,1}}},
  ["?"] = {{{0,0.22},{0.3,0},{0.7,0},{1,0.28},{0.5,0.55},{0.5,0.7}}, {{0.5,0.88},{0.5,1}}},
  ["/"] = {{{0,1},{1,0}}},
  ["\\"] = {{{0,0},{1,1}}},
  ["="] = {{{0.18,0.4},{0.82,0.4}}, {{0.18,0.6},{0.82,0.6}}},
  ["("] = {{{0.65,0},{0.35,0.25},{0.35,0.75},{0.65,1}}},
  [")"] = {{{0.35,0},{0.65,0.25},{0.65,0.75},{0.35,1}}},
  ["<"] = {{{0.8,0.1},{0.2,0.5},{0.8,0.9}}},
  [">"] = {{{0.2,0.1},{0.8,0.5},{0.2,0.9}}},
  ["*"] = {{{0.2,0.3},{0.8,0.7}}, {{0.8,0.3},{0.2,0.7}}, {{0.5,0.2},{0.5,0.8}}},
  ["%"] = {{{0,1},{1,0}}, {{0.1,0.1},{0.3,0.1},{0.3,0.3},{0.1,0.3},{0.1,0.1}}, {{0.7,0.7},{0.9,0.7},{0.9,0.9},{0.7,0.9},{0.7,0.7}}},
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
  -- sample lines at a few sizes
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
