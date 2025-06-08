local dialog = nil

local function retain_current_view()
  -- Do nothing - this removes the forced pattern editor focus
end

function loadFormula(filepath, display_name, mixer_params)
  local song=renoise.song()
  local window = renoise.app().window
  local device_path = "Audio/Effects/Native/*Formula"
  local formula_index = nil
  local insert_index = 2  -- Default insert position
  
  -- Check if we're in sample fx chain view
  if window.active_middle_frame == 7 then
    -- Check if the selected sample device chain exists, and create one if it doesn't
    local chain = song.selected_sample_device_chain
    local chain_index = song.selected_sample_device_chain_index

    if chain == nil or chain_index == 0 then
      song.selected_instrument:insert_sample_device_chain_at(1)
      chain = song.selected_sample_device_chain
      chain_index = 1
    end

    if chain then
      local sample_devices = chain.devices
      -- Determine insert position
      insert_index = (#sample_devices < 2) and 2 or 
                    (sample_devices[2] and sample_devices[2].name == "#Line Input" and 3 or 2)
      insert_index = math.min(insert_index, #sample_devices + 1)
      
      -- Find existing Formula device
      for i = 1, #sample_devices do
        if sample_devices[i].name:find("*Formula") then
          formula_index = i
          break
        end
      end
      
      -- Insert or use existing Formula device
      if not formula_index then
        chain:insert_device_at(device_path, insert_index)
        formula_index = insert_index
      end
      
      -- Load preset
      local infile = io.open(renoise.tool().bundle_path .. filepath, "rb")
      if infile then
        local data = infile:read("*all")
        infile:close()
        chain.devices[formula_index].active_preset_data = data
        chain.devices[formula_index].display_name = display_name
        song.selected_sample_device_index = formula_index
      else
        renoise.app():show_status("Could not load formula preset: " .. filepath)
      end
    else
      renoise.app():show_status("No sample selected.")
      return
    end
  else
    -- We're in track DSP chain
    local track = song.tracks[song.selected_track_index]
    
    -- Determine insert position for track
    if track.devices[2] and track.devices[2].name == "#Line Input" then
      insert_index = 3
    end
    
    -- Find existing Formula device
    for i, device in ipairs(track.devices) do
      if device.name:find("*Formula") then
        formula_index = i
        renoise.song().selected_device_index = formula_index
        break
      end
    end
    
    -- Insert or use existing Formula device
    if not formula_index then
      track:insert_device_at(device_path, insert_index)
      formula_index = insert_index
      renoise.song().selected_device_index = formula_index
    end
    
    -- Load preset
    local infile = io.open(renoise.tool().bundle_path .. filepath, "rb")
    if infile then
      local data = infile:read("*all")
      infile:close()
      track.devices[formula_index].active_preset_data = data
      track.devices[formula_index].display_name = display_name
      
      -- Handle mixer parameters
      if mixer_params == 0 then
        -- Hide all parameters
        for i = 1, 6 do
          track.devices[formula_index].parameters[i].show_in_mixer = false
        end
      else
        -- Show only requested parameters
        for i = 1, 3 do
          track.devices[formula_index].parameters[i].show_in_mixer = (i <= mixer_params)
        end
      end
    else
      renoise.app():show_status("Could not load formula preset: " .. filepath)
    end
  end
end


function insert_formula_text(text)
  local track = renoise.song().tracks[renoise.song().selected_track_index]

  for _, device in ipairs(track.devices) do
    if device.name:find("*Formula") then
      local preset_data = device.active_preset_data

      -- Ensure preset_data is valid XML before modifying
      if not preset_data or preset_data == "" then
        renoise.app():show_status("Formula device has no preset data!")
        return
      end

      -- Find the last FunctionsParagraph and append to it
      local new_data = preset_data:gsub("(<FunctionsParagraphs>.-)(</FunctionsParagraphs>)", 
        function(start, ending)
          return string.format("%s<FunctionsParagraph>%s</FunctionsParagraph>%s", 
            start, text, ending)
        end)

      -- Update the preset data
      device.active_preset_data = new_data
      
      retain_current_view()  -- Instead of forcing pattern editor
     return
    end
  end

  renoise.app():show_status("No Formula device found in the current track.")
end

function create_variable_row(vb, name, description)
  return vb:row{
    vb:button{
      width=100,
      text = name,
      notifier=function() insert_formula_text(name) end
    },
    vb:text{
      width=200,
      text = description
    }
  }
end

function pakettiFormulaDeviceDialog()
  
  retain_current_view()  -- Instead of forcing pattern editor
  renoise.app().window.lower_frame_is_visible = true
  renoise.app().window.active_lower_frame = 1

  local track = renoise.song().tracks[renoise.song().selected_track_index]
  local formula_index = nil

  -- Search for an existing Formula device
  for i, device in ipairs(track.devices) do
    if device.name:find("*Formula") then
      formula_index = i
      break
    end
  end

  -- If not found, insert Formula device at index 2 and load preset
  if not formula_index then
    track:insert_device_at("Audio/Effects/Native/*Formula", 2)
    formula_index = 2

    local infile = io.open(renoise.tool().bundle_path .. "Research/FormulaDeviceXML.txt", "rb")
    if infile then
      local preset_data = infile:read("*all")
      if preset_data and preset_data:find("<FormulaDevicePreset") then
        track.devices[formula_index].active_preset_data = preset_data
      else
        renoise.app():show_status("Invalid preset file! Check XML formatting.")
      end
      infile:close()
    end
  end

  -- Select the Formula device
  renoise.song().selected_device_index = formula_index

  -- Close existing dialog if it's open
  if dialog and dialog.visible then
    dialog:close()
  end

  local vb = renoise.ViewBuilder()
  local content = vb:column{
      -- Forum buttons row
      vb:row{vb:text{text="A selection of Forum posts on the Formula Device", font = "bold", style="strong"}},
      vb:row{
        vb:button{text="Forum 1", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/formula-device-ama/71755") end},
        vb:button{text="Forum 2", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/post-your-formula-device-code-here/47307") end},
        vb:button{text="Forum 3", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/formula-transpose-for-eq-other-devices/41880") end},
        vb:button{text="Forum 4", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/formula-device-how-to-learn-to-write-formulas/64197") end},
        vb:button{text="Forum 5", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/what-is-the-formula-device/34346") end},
        vb:button{text="Forum 6", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/generative-sequences-with-the-formula-device/48938") end},
        vb:button{text="Forum 7", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/mathematically-come-up-with-eq-frequencies-for-specific-notes/58739/5") end},
        vb:button{text="Forum 8", notifier=function() renoise.app():open_url("https://forum.renoise.com/t/formula-device/39980/4") end},
      },
      vb:row{vb:text{text="Presets", font = "bold", style="strong"}},
      vb:row{
        vb:button{text="Input Inertia", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Input_Inertia.txt", "Input Inertia", 2) end},
        vb:button{text="Input Line Quantize", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Input_Line_Quantize.txt", "Input Line Quantize", 3) end},
        vb:button{text="LFO Beat Sync", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_LFO_Beat_Sync.txt", "LFO Beat Sync", 3) end},
        vb:button{text="LFO Chaotic", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_LFO_Chaotic.txt", "LFO Chaotic", 3) end},
        vb:button{text="Mixer Equal Weight", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Mixer_Equal_Weight.txt", "Mixer Equal Weight", 3) end},
          vb:button{text="kRAkEn/gORe Inertial Slider", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Inertial_Slider.txt", "Inertial Slider", 2) end},
          vb:button{text="kRAkEn/gORe The Stepper", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_The_Stepper.txt", "The Stepper", 3) end},
      },
      vb:row{
          vb:button{text="jk123 Spring Slider", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Spring_Slider.txt", "Spring Slider", 3) end},
          vb:button{text="Cas Super Formula", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Super_Formula.txt", "Super Formula", 2) end},
          vb:button{text="Cas Sample & Hold", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Sample_and_Hold.txt", "Sample & Hold", 2) end},
          vb:button{text="Martblek Lorenz LFO", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_LorenzLFO.txt", "LorenzLFO", 3) end},
          vb:button{text="Bit_Arts Meta Modulator", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Meta_Modulator.txt", "Meta Modulator", 3) end},
          vb:button{text="Afta8 Slew Limiter", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Slew_Limiter.txt", "Slew Limiter", 2) end},
      },
      vb:row{vb:text{text="Paketti Experiments", font = "bold", style="strong"}},
      vb:row{         
          vb:button{text="Paketti Silencer 1-3", 
          notifier=function() loadFormula("./Research/FormulaDeviceXML_Silencer_1-3.txt", "Paketti Silencer 1-3", 0) end},
        vb:button{text="Paketti Play/Silence/Tremolo", 
          notifier=function() 
            loadFormula("./Research/FormulaDeviceXML_Playcount_Silencecount.txt", "PakettiPlay/Silence/Tremolo", 3)
            local device = renoise.song().selected_device
            device.parameters[4].value = renoise.song().selected_track_index - 1
            device.parameters[5].value = 0
            device.parameters[6].value = 2
          end
        },      
        vb:button{text="Paketti Fadeout (Instant)", notifier=function() loadFormula("./Research/FormulaDeviceXML_Fadeout.txt", "Paketti Fadeout", 2)
          local device = renoise.song().selected_device
          device.parameters[4].value = renoise.song().selected_track_index - 1
          device.parameters[5].value = 0
          device.parameters[6].value = 2
          delay(0.1)
          device.parameters[2].value=0.1
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
        },
        vb:button{text="Paketti Fadeout (Manual)", notifier=function() loadFormula("./Research/FormulaDeviceXML_Fadeout.txt", "Paketti Fadeout", 2)
          local device = renoise.song().selected_device
          device.parameters[4].value = renoise.song().selected_track_index - 1
          device.parameters[5].value = 0
          device.parameters[6].value = 2
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        end
        }

      },
  

  vb:row{
    -- Left Column: Input Variables + Math Constants
    vb:column{
      vb:text{text="INPUT VARIABLES", font = "bold", style="strong" },
      create_variable_row(vb, "A", "First input parameter [0..1]"),
      create_variable_row(vb, "B", "Second input parameter [0..1]"),
      create_variable_row(vb, "C", "Third input parameter [0..1]"),
      create_variable_row(vb, "OUTPUT", "Output parameter from previous run"),
      
      vb:text{text="MATH CONSTANTS", font = "bold", style="strong" },
      create_variable_row(vb, "PI", "Pi constant"),
      create_variable_row(vb, "TWOPI", "2*Pi constant"),
      create_variable_row(vb, "INF", "Infinity (huge positive number)"),
      
      vb:text{text="MUSICAL VARIABLES", font = "bold", style="strong" },
      create_variable_row(vb, "PLAYING", "Playing or stopped (1 or 0)"),
      create_variable_row(vb, "SRATE", "Actual sampling rate"),
      create_variable_row(vb, "BPM", "Beats per minute"),
      create_variable_row(vb, "LPB", "Lines per beat"),
      create_variable_row(vb, "TPL", "Ticks per line"),
      create_variable_row(vb, "SPL", "Samples per line"),
      create_variable_row(vb, "NUMLINES", "Number of lines in current pattern"),
      create_variable_row(vb, "TICK", "Tick number in current line"),
      create_variable_row(vb, "LINE", "Line number in currentpattern"),
      create_variable_row(vb, "LINEF", "Line number with tick fractions"),
      create_variable_row(vb, "SAMPLES", "Absolute position in song in samples"),
      create_variable_row(vb, "BEATS", "Absolute position in song in beats"),
      create_variable_row(vb, "LINES", "Absolute position in song in lines"),
      create_variable_row(vb, "SEQPOS", "Absolute position in song in patterns"),
      create_variable_row(vb, "SAMPLECOUNTER", "Continuously running sample counter"),
      create_variable_row(vb, "TICKCOUNTER", "Continuously running tick counter"),
      create_variable_row(vb, "LINECOUNTER", "Continuously running line counter"),
      create_variable_row(vb, "LINEFCOUNTER", "Line counter with tick fractions"),      
    },

    -- Right Column: Functions
    vb:column{
      vb:text{text="FUNCTIONS", font = "bold", style="strong" },
      create_variable_row(vb, "abs(x)", "Absolute value"),
      create_variable_row(vb, "acos(x)", "Arc cosine"),
      create_variable_row(vb, "asin(x)", "Arc sine"),
      create_variable_row(vb, "atan(x)", "Arc tangent"),
      create_variable_row(vb, "ceil(x)", "Round number to ceil"),
      create_variable_row(vb, "cos(x)", "Cosine"),
      create_variable_row(vb, "cosh(x)", "Hyperbolic cosine"),
      create_variable_row(vb, "deg(x)", "Convert to degrees"),
      create_variable_row(vb, "exp(x)", "Exponential (e^x)"),
      create_variable_row(vb, "floor(x)", "Round number to floor"),
      create_variable_row(vb, "fmod(x)", "Modulo operator for float numbers"),
      create_variable_row(vb, "frexp(x)", "Split value in fraction and exponent"),
      create_variable_row(vb, "ldexp(x)", "Float representation for a normalised number"),
      create_variable_row(vb, "lin2db(x)", "Convert a 0..1 number to its decibel value"),
      create_variable_row(vb, "db2lin(x)", "Convert a decibel value to its 0..1 normalised value"),
      create_variable_row(vb, "log(x)", "Natural logarithm of a number"),
      create_variable_row(vb, "log10(x)", "Logarithm base 10 of a number"),
      create_variable_row(vb, "max()", "a, b [, c[, ...]] Maximum of two or more numbers"),
      create_variable_row(vb, "min()", "a, b [, c[, ...]]Minimum of two or more numbers"),
      create_variable_row(vb, "mod(x)", "Modulo operator"),
      create_variable_row(vb, "modf(x)", "Integral and fractional parts of a number"),
      create_variable_row(vb, "pow(x, n)", "Nth power of x"),
      create_variable_row(vb, "rad(x)", "Convert to radians"),
      create_variable_row(vb, "random()", "[a [, b [, c]]] Random value"),
      create_variable_row(vb, "randomseed(x)", "Seed the random number generator"),
      create_variable_row(vb, "sin(x)", "Sine"),
      create_variable_row(vb, "sinh(x)", "Hyperbolic sine"),
      create_variable_row(vb, "sqrt(x)", "Square root"),
      create_variable_row(vb, "tan(x)", "Tangent"),
      create_variable_row(vb, "tanh(x)", "Hyperbolic tangent"),
    },
  }
}

  dialog = renoise.app():show_custom_dialog("Paketti Formula Device Manual", content, my_keyhandler_func)
  retain_current_view()
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Show Paketti Formula Dialog...",invoke = pakettiFormulaDeviceDialog}

renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Show Paketti Formula Device Manual Dialog...",invoke = pakettiFormulaDeviceDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Show Paketti Formula Device Manual Dialog...",invoke = pakettiFormulaDeviceDialog}

------
function add_input_inertia()
  local track = renoise.song().tracks[renoise.song().selected_track_index]
  
  track:insert_device_at("Audio/Effects/Native/*Formula", 2)
  local device = track.devices[2]
  device.display_name = "Input Inertia"
  
  -- Load the preset
  local infile = io.open(renoise.tool().bundle_path .. "Research/FormulaDeviceXML_Input_Inertia.txt", "rb")
  if infile then
    local data = infile:read("*all")
    infile:close()
    device.active_preset_data = data
  end
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Add Input Inertia Formula Device",invoke = add_input_inertia}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Add Input Inertia Formula Device",invoke = add_input_inertia}
renoise.tool():add_keybinding{name="Global:Paketti:Add Input Inertia Formula Device",invoke = add_input_inertia}