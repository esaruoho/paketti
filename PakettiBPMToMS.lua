local vb = renoise.ViewBuilder()
local dialog

function pakettiBPMMSCalculator()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local song = renoise.song()
  local bpm = song.transport.bpm

  local function msPerFraction(frac)
    return math.floor((60000 / bpm) * frac + 0.5)
  end

  local text_views = {}

  local note_factors = {
    {div=1, label="1/1"}, {div=2, label="1/2"}, {div=4, label="1/4"}, {div=8, label="1/8"},
    {div=16, label="1/16"}, {div=32, label="1/32"}, {div=64, label="1/64"}, {div=128, label="1/128"}
  }

  local original_labels = {
    {id="whole_note", label="Whole-note delay (1/1)", frac=4.0},
    {id="whole_note_dotted", label="Whole-note dotted", frac=4.0 * 1.5},
    {id="whole_note_triplet", label="Whole-note triplet", frac=4.0 * 2/3},
    {id="half_note", label="Half-note delay (1/2)", frac=2.0},
    {id="half_note_dotted", label="Half-note dotted", frac=2.0 * 1.5},
    {id="half_note_triplet", label="Half-note triplet", frac=2.0 * 2/3},
    {id="quarter_note", label="Quarter-note delay (1/4)", frac=1.0},
    {id="quarter_note_dotted", label="Quarter-note dotted", frac=1.0 * 1.5},
    {id="quarter_note_triplet", label="Quarter-note triplet", frac=2/3},
    {id="eighth_note", label="Eighth-note delay (1/8)", frac=0.5},
    {id="eighth_note_dotted", label="Eighth-note dotted", frac=0.5 * 1.5},
    {id="eighth_note_triplet", label="Eighth-note triplet", frac=1/3},
    {id="sixteenth_note", label="Sixteenth-note delay (1/16)", frac=0.25},
    {id="sixteenth_note_dotted", label="Sixteenth-note dotted", frac=0.25 * 1.5},
    {id="sixteenth_note_triplet", label="Sixteenth-note triplet", frac=1/6},
    {id="three_sixteenth", label="3/16-note delay", frac=0.75}
  }

  for _, entry in ipairs(original_labels) do
    text_views[entry.id] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
  end

  for _, item in ipairs(note_factors) do
    local base = 1 / item.div
    text_views[item.label.." Even"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
    text_views[item.label.." Dotted"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
    text_views[item.label.." Triplet"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
  end

  local function updateDelayTexts()
    for _, entry in ipairs(original_labels) do
      text_views[entry.id].text = string.format("%d ms", msPerFraction(entry.frac))
    end
    for _, item in ipairs(note_factors) do
      local base = 1 / item.div
      text_views[item.label.." Even"].text = string.format("%d ms", msPerFraction(base))
      text_views[item.label.." Dotted"].text = string.format("%d ms", msPerFraction(base * 1.5))
      text_views[item.label.." Triplet"].text = string.format("%d ms", msPerFraction(base * 2/3))
    end
  end

  local function buildContent()
    local rows = {}

    table.insert(rows, vb:row {
      vb:text{ text = "Tempo", font = "bold", style = "strong" },
      vb:valuebox {
        value = bpm, min = 20, max = 999,
        notifier=function(val)
          bpm = val
          updateDelayTexts()
        end
      },
      vb:text{ text = "BPM", font = "bold", style = "strong" }
    })

    table.insert(rows, vb:space{ height = 8 })
    table.insert(rows, vb:text{ text = "Base Note Delays", font = "bold", style = "strong" })

    for _, entry in ipairs(original_labels) do
      table.insert(rows, vb:row {
        vb:text{ text = entry.label, font = "bold", style = "strong", width = 150 },
        text_views[entry.id]
      })
    end

    table.insert(rows, vb:space{ height = 8 })
    table.insert(rows, vb:text{ text = "Extended Delay Times", font = "bold", style = "strong" })

    for _, item in ipairs(note_factors) do
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Even", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Even"]
      })
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Dotted", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Dotted"]
      })
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Triplet", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Triplet"]
      })
    end

    updateDelayTexts()

    return vb:column { margin = 5, unpack(rows) }
  end

  dialog = renoise.app():show_custom_dialog("Paketti BPM to MS Delay Calculator Dialog", buildContent())
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:BPM&LPB..:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}
