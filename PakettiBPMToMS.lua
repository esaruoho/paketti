local vb     = renoise.ViewBuilder()
local dialog

function pakettiBPMMSCalculator()
  -- toggle dialog
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  -- get BPM inside the function
  local song = renoise.song()
  local bpm  = song.transport.bpm

  local function msPerFraction(frac)
    return math.floor((60000 / bpm) * frac + 0.5)
  end

  local function buildContent()
    -- Create text views first
    local text_views = {
      whole_note = vb:text{ text = string.format("%d ms", msPerFraction(4.0)), font = "bold", style = "strong", width = 80 },
      half_note = vb:text{ text = string.format("%d ms", msPerFraction(2.0)), font = "bold", style = "strong", width = 80 },
      quarter_note = vb:text{ text = string.format("%d ms", msPerFraction(1.0)), font = "bold", style = "strong", width = 80 },
      quarter_triplet = vb:text{ text = string.format("%d ms", msPerFraction(2/3)), font = "bold", style = "strong", width = 80 },
      eighth_note = vb:text{ text = string.format("%d ms", msPerFraction(0.5)), font = "bold", style = "strong", width = 80 },
      eighth_triplet = vb:text{ text = string.format("%d ms", msPerFraction(1/3)), font = "bold", style = "strong", width = 80 },
      three_sixteenth = vb:text{ text = string.format("%d ms", msPerFraction(0.75)), font = "bold", style = "strong", width = 80 },
      sixteenth_note = vb:text{ text = string.format("%d ms", msPerFraction(0.25)), font = "bold", style = "strong", width = 80 },
      sixteenth_triplet = vb:text{ text = string.format("%d ms", msPerFraction(1/6)), font = "bold", style = "strong", width = 80 }
    }

    -- Function to update all text views
    local function updateDelayTexts()
      text_views.whole_note.text = string.format("%d ms", msPerFraction(4.0))
      text_views.half_note.text = string.format("%d ms", msPerFraction(2.0))
      text_views.quarter_note.text = string.format("%d ms", msPerFraction(1.0))
      text_views.quarter_triplet.text = string.format("%d ms", msPerFraction(2/3))
      text_views.eighth_note.text = string.format("%d ms", msPerFraction(0.5))
      text_views.eighth_triplet.text = string.format("%d ms", msPerFraction(1/3))
      text_views.three_sixteenth.text = string.format("%d ms", msPerFraction(0.75))
      text_views.sixteenth_note.text = string.format("%d ms", msPerFraction(0.25))
      text_views.sixteenth_triplet.text = string.format("%d ms", msPerFraction(1/6))
    end

    return vb:column {
      margin  = 5,
      vb:row {
      --  spacing = 6,
        vb:text     { text = "Tempo", font = "bold", style = "strong" },
        vb:valuebox {
          value    = bpm,
          min      = 20,
          max      = 999,
          notifier = function(val)
            bpm = val
            updateDelayTexts()
          end,
        },
        vb:text     { text = "BPM", font = "bold", style = "strong" },
      },

      -- delay rows
      vb:row {
        vb:text      { text = "Whole-note delay",     font = "bold", style = "strong", width=150 },
        text_views.whole_note
      },
      vb:row {
        
        vb:text      { text = "Half-note delay",      font = "bold", style = "strong", width=150 },
        text_views.half_note
      },
      vb:row {
        vb:text      { text = "Quarter-note delay",   font = "bold", style = "strong", width=150 },
        text_views.quarter_note
      },
      vb:row {
        
        vb:text      { text = "Quarter-triplet delay",font = "bold", style = "strong", width=150 },
        text_views.quarter_triplet
      },
      vb:row {
        
        vb:text      { text = "Eighth-note delay",    font = "bold", style = "strong", width=150 },
        text_views.eighth_note
      },
      vb:row {
        
        vb:text      { text = "Eighth-triplet delay", font = "bold", style = "strong", width=150 },
        text_views.eighth_triplet
      },
      vb:row {
        
        vb:text      { text = "3/16-note delay",      font = "bold", style = "strong", width=150 },
        text_views.three_sixteenth
      },
      vb:row {
        
        vb:text      { text = "Sixteenth-note delay", font = "bold", style = "strong", width=150 },
        text_views.sixteenth_note
      },
      vb:row {
        
        vb:text      { text = "Sixteenth-triplet delay", font = "bold", style = "strong", width=150 },
        text_views.sixteenth_triplet
      },
    }
  end

  dialog = renoise.app():show_custom_dialog("Paketti BPM to MS Delay Calculator Dialog", buildContent(), my_keyhandler_func)
end

renoise.tool():add_menu_entry {name   = "Main Menu:Tools:Paketti BPM to MS Delay Calculator Dialog...",invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry {name   = "Pattern Editor:Tools:Paketti BPM to MS Delay Calculator Dialog...",invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry {name   = "Pattern Matrix:Tools:Paketti BPM to MS Delay Calculator Dialog...",invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry {name   = "Mixer:Tools:Paketti BPM to MS Delay Calculator Dialog...",invoke = pakettiBPMMSCalculator}

renoise.tool():add_keybinding {name   = "Global:Tools:Paketti BPM to MS Delay Calculator Dialog...",invoke = pakettiBPMMSCalculator}
