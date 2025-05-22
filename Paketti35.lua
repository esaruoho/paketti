  -- Paketti35.lua
  -- This script demonstrates various GUI elements in Renoise,
  -- including button alignments, button styles, text orientations,
  -- text styles, and cursor shapes.
  -- It also integrates new controls (Chooser, RotaryEncoder, Switch, ScrollBar)
  -- and a Canvas that draws shapes based on these controls.
  function show_gui_demo()
  local vb = renoise.ViewBuilder()

  --------------------------------------------------------------------------------
  -- Global Variables for the Controls (Prefixing to avoid conflicts)
  --------------------------------------------------------------------------------
  local demo_chooser_value = 1      -- Chooser: 1 = Blue, 2 = Red, 3 = Green.
  local demo_rotary_value  = 50     -- Rotary: value between 0 and 100 (used for rotation).
  local demo_switch_value  = 2      -- Switch: determines which shape to draw.
  local demo_scrollbar_value = 100  -- ScrollBar: Start at the middle value (0 to 200).

  -- Map chooser values to RGBA colors.
  local demo_chooser_colors = {
    [1] = {0, 0, 255, 255},   -- Blue
    [2] = {255, 0, 0, 255},   -- Red
    [3] = {0, 255, 0, 255}    -- Green
  }

  -- List of shapes to include in the switch control
  local demo_switch_items = {
    "Circle",
    "Square",
    "Triangle",
    "Star",
    "Heart",
    "Spiral",
    "Hexagon",
    "Pentagon",
    "Cross",
    "Arrow",
    "Diamond",
    "Parallelogram",
    "Trapezoid",
    "Crescent",
    "Cloud",
    "Lightning",
    "Gear"
  }

  --------------------------------------------------------------------------------
  -- Canvas Render Callback Function
  --------------------------------------------------------------------------------
  local function demo_canvas_render(ctx)
    -- Clear the entire canvas to transparent black.
    ctx:clear_rect(0, 0, ctx.size.width, ctx.size.height)

    ctx:save()
    -- Map the scrollbar value (0 to 200) to an offset (-100 to 100)
    local offset = demo_scrollbar_value - 100
    -- Translate horizontally using the mapped offset and vertically fix at 100.
    ctx:translate(250 + offset, 100)

    -- Map demo_rotary_value (0 to 100) to an angle (0 to 2π radians).
    local angle = (demo_rotary_value / 100) * 2 * math.pi
    ctx:rotate(angle)

    -- Use the chooser selection to set the fill color.
    ctx.fill_color = demo_chooser_colors[demo_chooser_value] or {200, 200, 200, 255}
    ctx.stroke_color = ctx.fill_color

    -- Size of the shapes
    local shape_size = 30

    -- Draw a shape based on the switch value.
    if demo_switch_value == 1 then
      -- Circle
      ctx:begin_path()
      ctx:arc(0, 0, shape_size, 0, 2 * math.pi, false)
      ctx:fill()
    elseif demo_switch_value == 2 then
      -- Square
      ctx:begin_path()
      ctx:rect(-shape_size, -shape_size, shape_size * 2, shape_size * 2)
      ctx:fill()
    elseif demo_switch_value == 3 then
      -- Triangle
      ctx:begin_path()
      ctx:move_to(0, -shape_size)
      ctx:line_to(shape_size, shape_size)
      ctx:line_to(-shape_size, shape_size)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 4 then
      -- Star
      ctx:begin_path()
      local num_points = 5
      local outer_radius = shape_size
      local inner_radius = shape_size / 2.5
      for i = 0, num_points * 2 do
        local angle = (i / (num_points * 2)) * 2 * math.pi - math.pi / 2
        local radius = (i % 2 == 0) and outer_radius or inner_radius
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        if i == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 5 then
      -- Heart
      ctx:begin_path()
      local scale = shape_size / 16
      ctx:move_to(0, -scale * 4)
      for t = 0, 2 * math.pi, 0.01 do
        local x = scale * 16 * math.sin(t)^3
        local y = -scale * (13 * math.cos(t) - 5 * math.cos(2 * t)
                - 2 * math.cos(3 * t) - math.cos(4 * t))
        ctx:line_to(x, y)
      end
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 6 then
      -- Spiral
      ctx:begin_path()
      local num_spirals = 3
      local max_radius = shape_size
      local num_points = 200
      for i = 0, num_points do
        local theta = i / num_points * num_spirals * 2 * math.pi
        local radius = (i / num_points) * max_radius
        local x = radius * math.cos(theta)
        local y = radius * math.sin(theta)
        if i == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
      ctx:stroke()
    elseif demo_switch_value == 7 then
      -- Hexagon
      ctx:begin_path()
      for i = 0, 5 do
        local angle = (i / 6) * 2 * math.pi
        local x = shape_size * math.cos(angle)
        local y = shape_size * math.sin(angle)
        if i == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 8 then
      -- Pentagon
      ctx:begin_path()
      for i = 0, 4 do
        local angle = (i / 5) * 2 * math.pi - math.pi / 2
        local x = shape_size * math.cos(angle)
        local y = shape_size * math.sin(angle)
        if i == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 9 then
      -- Cross
      ctx:begin_path()
      ctx:rect(-shape_size / 2, -shape_size * 1.5, shape_size, shape_size * 3)
      ctx:rect(-shape_size * 1.5, -shape_size / 2, shape_size * 3, shape_size)
      ctx:fill()
    elseif demo_switch_value == 10 then
      -- Arrow
      ctx:begin_path()
      ctx:move_to(-shape_size, -shape_size / 2)
      ctx:line_to(shape_size, -shape_size / 2)
      ctx:line_to(shape_size, -shape_size)
      ctx:line_to(shape_size * 1.5, 0)
      ctx:line_to(shape_size, shape_size)
      ctx:line_to(shape_size, shape_size / 2)
      ctx:line_to(-shape_size, shape_size / 2)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 11 then
      -- Diamond
      ctx:begin_path()
      ctx:move_to(0, -shape_size)
      ctx:line_to(shape_size, 0)
      ctx:line_to(0, shape_size)
      ctx:line_to(-shape_size, 0)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 12 then
      -- Parallelogram
      ctx:begin_path()
      ctx:move_to(-shape_size * 0.5, -shape_size)
      ctx:line_to(shape_size * 1.5, -shape_size)
      ctx:line_to(shape_size * 0.5, shape_size)
      ctx:line_to(-shape_size * 1.5, shape_size)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 13 then
      -- Trapezoid
      ctx:begin_path()
      ctx:move_to(-shape_size, -shape_size)
      ctx:line_to(shape_size, -shape_size)
      ctx:line_to(shape_size * 0.5, shape_size)
      ctx:line_to(-shape_size * 0.5, shape_size)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 14 then
      -- Crescent
      ctx:begin_path()
      ctx:arc(0, 0, shape_size, math.pi / 4, (7 * math.pi) / 4, false)
      ctx:arc(-shape_size / 2, 0, shape_size, (7 * math.pi) / 4, math.pi / 4, true)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 15 then
      -- Cloud
      ctx:begin_path()
      ctx:arc(-shape_size / 2, -shape_size / 4, shape_size / 2, math.pi, 0, false)
      ctx:arc(0, -shape_size / 2, shape_size / 2, math.pi, 0, false)
      ctx:arc(shape_size / 2, -shape_size / 4, shape_size / 2, math.pi, 0, false)
      ctx:arc(shape_size / 2, shape_size / 4, shape_size / 2, 3 * math.pi / 2, math.pi / 2, false)
      ctx:arc(-shape_size / 2, shape_size / 4, shape_size / 2, 3 * math.pi / 2, math.pi / 2, false)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 16 then
      -- Lightning
      ctx:begin_path()
      ctx:move_to(-shape_size / 2, -shape_size)
      ctx:line_to(0, -shape_size / 2)
      ctx:line_to(-shape_size / 4, -shape_size / 2)
      ctx:line_to(shape_size / 2, shape_size)
      ctx:line_to(0, 0)
      ctx:line_to(shape_size / 4, 0)
      ctx:close_path()
      ctx:fill()
    elseif demo_switch_value == 17 then
      -- Gear (simple representation)
      ctx:begin_path()
      local num_teeth = 8
      local outer_radius = shape_size
      local inner_radius = shape_size * 0.7
      for i = 0, num_teeth * 2 do
        local angle = (i / (num_teeth * 2)) * 2 * math.pi
        local radius = (i % 2 == 0) and outer_radius or inner_radius
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        if i == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
      ctx:close_path()
      ctx:fill()
    else
      -- Fallback: draw a rectangle.
      ctx:begin_path()
      ctx:rect(-shape_size, -shape_size, shape_size * 2, shape_size * 2)
      ctx:fill()
    end
    ctx:restore()
  end

  --------------------------------------------------------------------------------
  -- Create the Canvas View and Capture It for Later Updates
  --------------------------------------------------------------------------------
  local demo_canvas_view  -- forward declaration
  demo_canvas_view = vb:canvas{
    width=500,
    height = 200,
    render = demo_canvas_render,
    mode = "transparent"  -- uses alpha blending
  }

  --------------------------------------------------------------------------------
  -- Create Controls
  --------------------------------------------------------------------------------
  local demo_chooser_view = vb:chooser{
    items = {"Blue", "Red", "Green"},
    value = demo_chooser_value,
    notifier=function(new_value)
      demo_chooser_value = new_value
      demo_canvas_view:update()  -- update the canvas when the chooser changes
    end
  }

  local demo_rotary_view = vb:rotary{
    min = 0,
    max = 100,
    value = demo_rotary_value,
    width=50,  -- set width and height equal for a circular appearance
    height = 50,
    notifier=function(new_value)
      demo_rotary_value = new_value
      demo_canvas_view:update()  -- update the canvas when the rotary changes
    end
  }

  local demo_switch_view = vb:switch{
    width= 800,  -- Increased width to display longer list of shapes
    items = demo_switch_items,
    value = demo_switch_value,
    notifier=function(new_value)
      demo_switch_value = new_value
      demo_canvas_view:update()  -- update the canvas when the switch selection changes
    end
  }

  local demo_scrollbar_view = vb:scrollbar{
    min = 0,
    max = 200,
    value = demo_scrollbar_value,
    width=400,
    height = 20,
    notifier=function(new_value)
      demo_scrollbar_value = new_value
      demo_canvas_view:update()  -- update the canvas when scrolling
    end
  }

  --------------------------------------------------------------------------------
  -- Prepare the list of cursor shapes, excluding "busy"
  --------------------------------------------------------------------------------
  local cursor_shapes = {
    "none",
    "empty",
    "default",
    "change_value",
    "edit_text",
    "pencil",
    "marker",
    "crosshair",
    "move",
    "erase",
    "play",
    "resize_vertical",
    "resize_horizontal",
    "resize_edge_vertical",
    "resize_edge_horizontal",
    "resize_edge_diagonal_left",
    "resize_edge_diagonal_right",
    "extend_left",
    "extend_right",
    "extend_top",
    "extend_bottom",
    "extend_left_alias",
    "extend_right_alias",
    "extend_top_alias",
    "extend_bottom_alias",
    "zoom_vertical",
    "zoom_horizontal",
    "zoom",
    "drag",
    "drop",
    "nodrop",
    "busy"
  }

  --------------------------------------------------------------------------------
  -- Function to create the dialog content
  --------------------------------------------------------------------------------
  local function create_dialog()
    -- Build the content for cursor shape demonstration
    local cursor_demo_columns = {}
    local column_count = 5  -- Adjust this to change the number of columns
    local items_per_column = math.ceil(#cursor_shapes / column_count)

    for i = 1, column_count do
      local column_items = {}
      for j = 1, items_per_column do
        local index = (i - 1) * items_per_column + j
        local cursor_shape = cursor_shapes[index]
        if cursor_shape then
          column_items[#column_items + 1] = vb:button{
            text = cursor_shape,
            width=120,
            tooltip = "Click to set cursor: " .. cursor_shape,
            notifier=function()
              -- Set the cursor of the dialog content using its ID
              vb.views.dialog_content.cursor = cursor_shape
            end
          }
        end
      end
      -- Build column without using unpack
      local column_view_args = {spacing=3, margin=3}
      for _, item in ipairs(column_items) do
        table.insert(column_view_args, item)
      end
      local column_view = vb:column(column_view_args)
      cursor_demo_columns[#cursor_demo_columns + 1] = column_view
    end

    -- Build the row containing cursor demo columns without using unpack
    local cursor_demo_row_args = {spacing=3}
    for _, column in ipairs(cursor_demo_columns) do
      table.insert(cursor_demo_row_args, column)
    end
    local cursor_demo_row = vb:row(cursor_demo_row_args)

    -- Reset Cursor Button
    local reset_cursor_button = vb:button{
      text="Reset Cursor",
      width=150,
      notifier=function()
        -- Reset the cursor to default
        vb.views.dialog_content.cursor = "default"
      end
    }

    -- Dialog content
    local dialog_content = vb:column{
      id = "dialog_content", -- Assign an ID for easy access
      spacing=3,
      margin=3,

      -- Button styles
      vb:row{
        vb:text{
          text="Button styles",
          font="bold",
          style="strong",
          align="center",
          width=800
        }
      },
      -- Row of buttons demonstrating text alignment
      vb:row{vb:button{
          text="Left Aligned",
          align="left",
          width=140},
        vb:button{
          text="Center Aligned",
          align="center", -- Center alignment is default
          width=140
        },
        vb:button{
          text="Right Aligned",
          align="right",
          width=140
        }
      },

      -- Row of buttons demonstrating button styles
      vb:row{
        spacing=3,
        vb:button{
          text="Normal",
          style = "normal",
          width=120
        },
        vb:button{
          text="Rounded",
          style = "rounded",
          width=120},
        vb:button{
          text="Rounded Left",
          style = "rounded_left",
          width=120},
        vb:button{
          text="Rounded Right",
          style = "rounded_right",
          width=120},
        vb:button{
          text="Rounded Top",
          style = "rounded_top",
          width=120},
        vb:button{
          text="Rounded Bottom",
          style = "rounded_bottom",
          width=120}},

      -- Section for Text Orientation Examples
      vb:column{
        spacing=3,
        vb:text{
          text="Text Orientation Examples",
          font = "bold",
          align="center",},
        vb:row{
          spacing=3,

          -- Horizontal (Default)
          vb:text{
            text="Horizontal",
            orientation = "horizontal", -- Default orientation
            width=100,
          },

          -- Horizontal Right to Left
          vb:text{
            text="Horizontal-RL",
            orientation = "horizontal-rl",
            width=100,
          },
        },

        vb:row{
          spacing=3,

          -- Vertical (Bottom to Top)
          vb:text{
            text="Vertical",
            orientation = "vertical",
            width=20,      -- Adjust width for vertical text
            height = 100,
          },

          -- Vertical Top to Bottom
          vb:text{
            text="Vertical-TB",
            orientation = "vertical-tb",
            width=20,
            height = 100,
          },
        },
      },

      -- Section for Text Style Examples
      vb:column{
        vb:text{
          text="Text Style Examples",
          font = "bold",
          align="center",
        },
        vb:column{
          -- Bold Text
          vb:text{
            text="This is bold text",
            font = "bold",
          },

          -- Italic Text
          vb:text{
            text="This is italic text",
            font = "italic",
          },

          -- Monospace Text
          vb:text{
            text="This is monospace text",
            font = "mono",
          },

          -- Code Font
          vb:text{
            text="This is code font",
            font = "code",
          },
        },
      },

      -- Section for Cursor Shape Examples
      vb:column{
        vb:text{
          text="Cursor Shape Examples",
          font = "bold",
          align="center",
        },

        -- Row containing columns of cursor demos
        cursor_demo_row,

        -- Reset Cursor Button
        reset_cursor_button,
      },

      -- Integration of the new controls and canvas
      vb:column{
        vb:text{
          text="Canvas and Controls Demo",
          font = "bold",
          align="center",
        },

        -- Canvas View
        demo_canvas_view,

        -- Controls
        vb:row{
          spacing=10,
          demo_chooser_view,
          demo_rotary_view,
          demo_switch_view,},

        -- Scrollbar
        demo_scrollbar_view,
      },
    }

    -- Return the constructed dialog content
    return dialog_content
  end

  local dialog_content = create_dialog()
  local dialog = renoise.app():show_custom_dialog("GUI Demo", dialog_content, my_keyhandler_func)
  -- Reset cursor when dialog is closed
  renoise.tool().app_release_document_observable:add_notifier(function()
    if dialog_content then
      dialog_content.cursor = "default"
    end end)
end

if renoise.API_VERSION >= 6.2 then
-- Register the tool in Renoise
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:V3.5..:Example Tool...",
  invoke=function()
    if renoise.API_VERSION >= 6.2 then show_gui_demo()
    else print("soon you'll be in v3.5") end end}
end