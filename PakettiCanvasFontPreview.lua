-- PakettiCanvasFontPreview.lua
-- Preview dialog for PakettiCanvasFont glyphs (horizontal and vertical)

-- Global dialog state
PakettiCanvasFontPreviewDialog = nil
PakettiCanvasFontPreviewVB = nil
PakettiCanvasFontPreviewCanvasH = nil
PakettiCanvasFontPreviewCanvasV = nil

-- Canvas sizes
PakettiCanvasFontPreviewWidth = 1200
PakettiCanvasFontPreviewHeightH = 360
PakettiCanvasFontPreviewHeightV = 360

-- Sample lines to render
PakettiCanvasFontPreviewLines = {
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  "abcdefghijklmnopqrstuvwxyz",
  "0123456789",
  ".,:;!? _+-# % & () <> \" ' ^ / \\ *",
  "= §",
  "ä Ä ö Ö å Å",
  "⌘ ⌥ ⌃ ⇧  ↑ ↓ ← →  ↩"
}

-- Horizontal render
function PakettiCanvasFontPreviewRenderH(ctx)
  local w = PakettiCanvasFontPreviewWidth
  local h = PakettiCanvasFontPreviewHeightH
  ctx:clear_rect(0, 0, w, h)
  ctx.stroke_color = {220,220,220,255}
  ctx.line_width = 1
  local margin = 12
  local y = margin
  local size = 12
  for i = 1, #PakettiCanvasFontPreviewLines do
    local line = PakettiCanvasFontPreviewLines[i]
    PakettiCanvasFontDrawText(ctx, line, margin, y, size)
    y = y + math.floor(size * 1.8)
  end
  -- Footer
  ctx.stroke_color = {150,150,150,255}
  PakettiCanvasFontDrawText(ctx, "Horizontal Preview", margin, h - margin - size, size)
  -- Border
  ctx.stroke_color = {255,255,255,255}
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(0,0,w,h); ctx:stroke()
end

-- Vertical render (stacked glyphs)
function PakettiCanvasFontPreviewRenderV(ctx)
  local w = PakettiCanvasFontPreviewWidth
  local h = PakettiCanvasFontPreviewHeightV
  ctx:clear_rect(0, 0, w, h)
  ctx.stroke_color = {220,220,220,255}
  ctx.line_width = 1
  local margin = 12
  local x = margin
  local size = 10
  for i = 1, #PakettiCanvasFontPreviewLines do
    local line = PakettiCanvasFontPreviewLines[i]
    PakettiCanvasFontDrawTextVertical(ctx, line, x, margin, size)
    x = x + math.floor(size * 1.8)
  end
  -- Footer
  ctx.stroke_color = {150,150,150,255}
  PakettiCanvasFontDrawText(ctx, "Vertical Preview", margin, h - margin - size, size)
  -- Border
  ctx.stroke_color = {255,255,255,255}
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(0,0,w,h); ctx:stroke()
end

-- Open dialog
function PakettiCanvasFontPreviewInit()
  if PakettiCanvasFontPreviewDialog and PakettiCanvasFontPreviewDialog.visible then
    PakettiCanvasFontPreviewDialog:close()
    PakettiCanvasFontPreviewDialog = nil
  end

  PakettiCanvasFontPreviewVB = renoise.ViewBuilder()

  local content = PakettiCanvasFontPreviewVB:column{
    PakettiCanvasFontPreviewVB:canvas{
      id = "pcfp_canvas_h",
      width = PakettiCanvasFontPreviewWidth,
      height = PakettiCanvasFontPreviewHeightH,
      mode = "plain",
      render = PakettiCanvasFontPreviewRenderH
    },
    PakettiCanvasFontPreviewVB:canvas{
      id = "pcfp_canvas_v",
      width = PakettiCanvasFontPreviewWidth,
      height = PakettiCanvasFontPreviewHeightV,
      mode = "plain",
      render = PakettiCanvasFontPreviewRenderV
    },
    PakettiCanvasFontPreviewVB:row{
      PakettiCanvasFontPreviewVB:button{
        text = "Refresh",
        width = 100,
        notifier = function()
          if PakettiCanvasFontPreviewCanvasH then PakettiCanvasFontPreviewCanvasH:update() end
          if PakettiCanvasFontPreviewCanvasV then PakettiCanvasFontPreviewCanvasV:update() end
        end
      },
      PakettiCanvasFontPreviewVB:button{
        text = "Close",
        width = 100,
        notifier = function()
          if PakettiCanvasFontPreviewDialog then PakettiCanvasFontPreviewDialog:close() end
        end
      }
    }
  }

  PakettiCanvasFontPreviewDialog = renoise.app():show_custom_dialog(
    "Paketti Canvas Font Preview",
    content,
    my_keyhandler_func
  )

  PakettiCanvasFontPreviewCanvasH = PakettiCanvasFontPreviewVB.views.pcfp_canvas_h
  PakettiCanvasFontPreviewCanvasV = PakettiCanvasFontPreviewVB.views.pcfp_canvas_v

  -- Ensure Renoise gets keyboard presses
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

renoise.tool():add_keybinding{ name = "Global:Paketti:Canvas Font Preview", invoke = PakettiCanvasFontPreviewInit }
