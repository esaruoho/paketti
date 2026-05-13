--------------------------------------------------------------------------------
-- PakettiModernViewsDemo.lua
-- Live demo of three Renoise 6.2 (Renoise 3.4+) view types that Paketti has
-- never used:
--   * vb:stack{}  — free-positioned children via origin = {x, y}
--   * vb:rotary{} — same widget as before, just hosted inside the stack
--   * vb:link{}   — clickable styled text (TextLink) with a pressed notifier
--
-- Auto-shows once on tool load. After that, use the menu entry or keybinding
-- to reopen it.
--------------------------------------------------------------------------------

local dialog = nil

local function show_modern_views_demo()
  -- Re-open guard (standard Paketti pattern)
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local value_id = "pmv_value_" .. tostring(math.random(2, 30000))
  local dot_id   = "pmv_dot_"   .. tostring(math.random(2, 30000))

  -- The Stack is a 280x120 free-positioning area. Children must declare
  -- their origin = {x, y}; row/column would ignore that.
  local stack = vb:stack{
    size = { width = 280, height = 120 },
    background = "panel",

    vb:text{
      origin = { 10, 8 },
      text = "ENCODER POSITION",
      font = "bold",
    },

    vb:text{
      id = value_id,
      origin = { 10, 28 },
      text = "0.500",
      font = "mono",
    },

    -- A small button used as a positioned dot. Its x-position is updated
    -- by the encoder notifier — proves the Stack lets us reposition children
    -- at runtime by writing back to origin.
    vb:button{
      id = dot_id,
      origin = { 130, 50 },
      size   = { width = 16, height = 16 },
      color  = { 220, 90, 70 },
    },

    vb:text{
      origin = { 150, 96 },
      text = "Stack: free origin {x,y}",
      style = "disabled",
    },
  }

  local function update_dot(v)
    -- Stack child positions are writable. The dot slides across the 280px
    -- stack width as the encoder turns.
    local x = math.floor(8 + v * (280 - 16 - 16))
    vb.views[dot_id].origin = { x, 50 }
    vb.views[value_id].text = string.format("%.3f", v)
  end

  local content = vb:column{
    margin = 10,
    spacing = 8,

    stack,

    vb:row{
      spacing = 8,
      vb:text{ text = "Cutoff", width = 60 },
      vb:rotary{
        width = 36, height = 36,
        min = 0.0,
        max = 1.0,
        default = 0.5,
        value = 0.5,
        tooltip = "Filter cutoff (0..1)",
        notifier = update_dot,
      },
      vb:text{
        text = "  vb:rotary{} drives the dot's x in the Stack",
        style = "disabled",
      },
    },

    vb:link{
      text = "Open Paketti manual",
      style = "strong",
      tooltip = "vb:link{} — clickable styled text (TextLink)",
      pressed = function()
        renoise.app():open_url("https://esaruoho.github.io/paketti-manual/")
      end,
    },

    vb:link{
      text = "Close this demo",
      style = "normal",
      pressed = function()
        if dialog and dialog.visible then dialog:close() end
        dialog = nil
      end,
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(d) dialog = d end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Modern Views Demo", content, keyhandler)
end

--------------------------------------------------------------------------------
-- Auto-show on tool load (API 6.2+ only — these views don't exist below 3.4)
--------------------------------------------------------------------------------

local function modern_views_demo_init()
  show_modern_views_demo()
end

if PAKETTI_API >= 6.2 then
  if PAKETTI_API >= 6.1 then
    renoise.tool().tool_finished_loading_observable:add_notifier(modern_views_demo_init)
  else
    renoise.tool().app_new_document_observable:add_notifier(modern_views_demo_init)
  end
end

--------------------------------------------------------------------------------
-- Menu entry + keybinding (gated on API 6.2)
--------------------------------------------------------------------------------

if PAKETTI_API >= 6.2 then
  PakettiAddMenuEntry{
    name = "Main Menu:Tools:Paketti:!Preferences:Modern Views Demo (6.2 only)",
    invoke = show_modern_views_demo,
  }

  renoise.tool():add_keybinding{
    name = "Global:Paketti:Modern Views Demo",
    invoke = show_modern_views_demo,
  }
end
