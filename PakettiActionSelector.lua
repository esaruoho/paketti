-- Paketti files list (keep your existing list)
local paketti_files = {
  "Paketti0G01_Loader",
  "PakettieSpeak",
  "PakettiPlayerProSuite",
  "PakettiChordsPlus",
  "PakettiLaunchApp",
  "PakettiSampleLoader",
  "PakettiCustomization",
  "PakettiDeviceChains",
  "base64float",
  "PakettiLoadDevices",
  "PakettiSandbox",
  "PakettiTupletGenerator",
  "PakettiLoadPlugins",
  "PakettiPatternSequencer",
  "PakettiPatternMatrix",
  "PakettiInstrumentBox",
  "PakettiYTDLP",
  "PakettiStretch",
  "PakettiBeatDetect",
  "PakettiStacker",
  "PakettiRecorder",
  "PakettiControls",
  "PakettiKeyBindings",
  "PakettiPhraseEditor",
  "PakettiOctaMEDSuite",
  "PakettiWavetabler",
  "PakettiAudioProcessing",
  "PakettiPatternEditorCheatSheet",
  "PakettiThemeSelector",
  "PakettiMidiPopulator",
  "PakettiImpulseTracker",
  "PakettiGater",
  "PakettiAutomation",
  "PakettiUnisonGenerator",
  "PakettiMainMenuEntries",
  "PakettiMidi",
  "PakettiDynamicViews",
  "PakettiEightOneTwenty",
  "PakettiExperimental_Verify",
  "PakettiLoaders",
  "PakettiPatternEditor",
  "PakettiTkna",
  "PakettiRequests",
  "PakettiSamples",
  "Paketti35"
}

local dialog = nil

function pakettiActionSelectorDialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  local actions = {}
  local selected_actions = {}
  local vb = renoise.ViewBuilder()

  -- Pre-declare all helper functions
  local ActionSelectorSaveToFile
  local ActionSelectorLoadPreferences
  local ActionSelectorReset
  
  -- Helper function to scan a file for menu entries and keybindings
  local function ActionSelectorScanFile(filename)
    local file = io.open(renoise.tool().bundle_path .. filename .. ".lua", "r")
    if not file then 
      print("Could not open file: " .. filename)
      return 
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Look for menu entries with their invoke functions
    for entry, invoke_func in content:gmatch('add_menu_entry%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
      print("Adding menu entry:", entry)
      table.insert(actions, {
        type = "Menu Entry",
        name = entry:gsub("^%-%-%s*", ""),  -- Remove leading --
        invoke = invoke_func:match("^%s*(.-)%s*$") -- Trim whitespace
      })
    end
    
    -- Look for keybindings with their invoke functions
    for binding, invoke_func in content:gmatch('add_keybinding%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
      print("Adding keybinding:", binding)
      table.insert(actions, {
        type = "Keybinding",
        name = binding:gsub("^%-%-%s*", ""),  -- Remove leading --
        invoke = invoke_func:match("^%s*(.-)%s*$") -- Trim whitespace
      })
    end
  end

  -- First, require all files to ensure functions are in scope
  for _, filename in ipairs(paketti_files) do
    require(filename)
  end
  
  -- Then scan for menu entries and keybindings
  for _, filename in ipairs(paketti_files) do
    ActionSelectorScanFile(filename)
  end
  
  -- Sort actions: Menu Entries first (alphabetically), then Keybindings (alphabetically)
  table.sort(actions, function(a,b) 
    if a.type ~= b.type then
      return a.type == "Menu Entry"
    else
      return a.name < b.name 
    end
  end)
  
  print("Total actions found:", #actions)

  -- Define helper functions
  ActionSelectorSaveToFile = function()
    local file = io.open(renoise.tool().bundle_path .. "action_selector_settings.txt", "w")
    if file then
      for i = 1, 50 do
        local dropdown = vb.views["dropdown_" .. i]
        local value = dropdown.value
        local selected_item = dropdown.items[value]
        file:write(selected_item .. "\n")
        -- Also save to preferences with correct index naming
        preferences.ActionSelector["Index" .. string.format("%02d", i)].value = 
          value > 1 and (actions[value - 1].type .. ": " .. actions[value - 1].name .. "||" .. actions[value - 1].invoke) or ""
      end
      file:close()
      renoise.app():show_status("Action Selector settings saved")
    end
  end

  ActionSelectorLoadPreferences = function()
    -- First try to load from file
    local file = io.open(renoise.tool().bundle_path .. "action_selector_settings.txt", "r")
    if file then
      for i = 1, 50 do
        local line = file:read("*line")
        if line then
          local dropdown = vb.views["dropdown_" .. i]
          -- Find matching item in dropdown
          for idx, item in ipairs(dropdown.items) do
            if item == line then
              dropdown.value = idx
              selected_actions[i] = idx > 1 and actions[idx - 1] or nil
              -- Also update preferences
              preferences.ActionSelector["Index" .. string.format("%02d", i)].value = 
                idx > 1 and (actions[idx - 1].type .. ": " .. actions[idx - 1].name .. "||" .. actions[idx - 1].invoke) or ""
              break
            end
          end
        end
      end
      file:close()
      renoise.app():show_status("Action Selector settings loaded from file")
    else
      -- Fall back to preferences if file doesn't exist
      for i = 1, 50 do
        local pref_value = preferences.ActionSelector["Index" .. string.format("%02d", i)].value
        if pref_value and pref_value ~= "" then
          local display_text, invoke_func = pref_value:match("(.+)||(.+)")
          if display_text and invoke_func then
            local dropdown = vb.views["dropdown_" .. i]
            -- Find matching item by display text
            for idx, item in ipairs(dropdown.items) do
              if item == display_text then
                dropdown.value = idx
                -- Store the actual action data
                selected_actions[i] = {
                  type = display_text:match("^([^:]+):"),
                  name = display_text:match(": (.+)$"),
                  invoke = invoke_func
                }
                break
              end
            end
          end
        end
      end
    end
  end

  ActionSelectorReset = function()
    for i = 1, 50 do
      local dropdown = vb.views["dropdown_" .. i]
      dropdown.value = 1
      selected_actions[i] = nil
      preferences.ActionSelector["Index" .. string.format("%02d", i)].value = ""
    end
    renoise.app():show_status("Action Selector reset complete")
  end

  -- Create dialog content
  local dialog_content = vb:column{
    margin=0,
    spacing=0,
    vb:row{
      margin=0,
      spacing=2,
      vb:button{
        text="Debug All Actions",
        width=150,
        notifier=function()
          print("\n=== Starting Debug Test of All Actions ===\n")
          local failed_actions = {}
          
          for i, action in ipairs(actions) do
            local success = false
            
            -- Wrap everything in pcall to prevent any errors from stopping the process
            local ok, err = pcall(function()
              -- Method 1: Try direct evaluation
              local func = loadstring("return " .. action.invoke)
              if func then
                local ok, result = pcall(func)
                if ok and type(result) == "function" then
                  success = true
                end
              end
              
              -- Method 2: Try global lookup if Method 1 failed
              if not success and _G[action.invoke] and type(_G[action.invoke]) == "function" then
                success = true
              end
            end)
            
            -- If either the test failed or there was an error, record it
            if not (ok and success) then
              table.insert(failed_actions, {
                index = i,
                type = action.type,
                name = action.name,
                invoke = action.invoke,
                error = not ok and err or "Could not execute action"
              })
            end
          end
          
          -- Print summary of failures only
          print(string.format("\nTotal actions tested: %d", #actions))
          print(string.format("Failed actions: %d", #failed_actions))
          
          if #failed_actions > 0 then
            print("\nFailed Actions:")
            for _, fail in ipairs(failed_actions) do
              print(string.format("\n#%d: %s: %s", fail.index, fail.type, fail.name))
              print("Invoke code:", fail.invoke)
              print("Error:", fail.error)
            end
          end
          print("\n=== End of Debug Report ===\n")
        end
      },
            vb:button{
        text="Save",
        width=60,
        notifier=function()
          ActionSelectorSaveToFile()
        end
      },
      vb:button{
        text="Load",
        width=60,
        notifier=function()
          ActionSelectorLoadPreferences()
        end
      },
      vb:button{
        text="Reset",
        width=60,
        notifier=function()
          ActionSelectorReset()
        end
      },
      vb:button{
        text="Random Fill",
        width=80,
        notifier=function()
          local available = {}
          for i, action in ipairs(actions) do
            table.insert(available, i)
          end
          for i = 1, 50 do
            if #available > 0 then
              local rand_idx = math.random(1, #available)
              local action_idx = available[rand_idx]
              table.remove(available, rand_idx)
              local dropdown = vb.views["dropdown_" .. i]
              dropdown.value = action_idx + 1  -- +1 because of <None>
            end
          end
          ActionSelectorSaveToFile()
        end
      }
    }
  }
  
  -- Create 50 rows of dropdown + button
  for i = 1, 50 do
    local row = vb:row{
      margin=0,
      spacing=2,
      vb:text{
        text = string.format("%02d. ", i),
        style="strong",
        font="bold",
        width=24,
      },
      vb:popup{
        id = "dropdown_" .. i,
        width=650,
        items = {"<None>"},
        value = 1,
        notifier=function(idx)
          selected_actions[i] = idx > 1 and actions[idx - 1] or nil
          preferences.ActionSelector["Index" .. string.format("%02d", i)].value = 
            idx > 1 and (actions[idx - 1].type .. ": " .. actions[idx - 1].name .. "||" .. actions[idx - 1].invoke) or ""
        end
      },
      vb:button{
        text="Run",
        width=50,
        notifier=function()
          local action = selected_actions[i]
          if action then
            local func = loadstring("return " .. action.invoke)
            if func then
              local success, result = pcall(func)
              if success and type(result) == "function" then
                result()
              elseif _G[action.invoke] and type(_G[action.invoke]) == "function" then
                _G[action.invoke]()
              end
            end
          end
          renoise.app().window.active_middle_frame=renoise.app().window.active_middle_frame
        end
      }
    }
    dialog_content:add_child(row)
  end
  
  -- Add all actions to each dropdown
  for i = 1, 50 do
    local dropdown = vb.views["dropdown_" .. i]
    local items = {"<None>"}
    for _, action in ipairs(actions) do
      table.insert(items, action.type .. ": " .. action.name)
    end
    dropdown.items = items
  end

  -- Load initial values from preferences
  ActionSelectorLoadPreferences()
  
  dialog = renoise.app():show_custom_dialog(string.format("Paketti Action Selector (%d actions available)", #actions),
    dialog_content, my_keyhandler_func)

--  if renoise.app().window.active_middle_frame==1 then
---  renoise.app().window.active_middle_frame=1 end
renoise.app().window.active_middle_frame=renoise.app().window.active_middle_frame
end

-- Helper function to ensure correct sequential channel numbering
local function ensure_sequential_channel_prefix(name, channel_number)
    -- Strip any existing [CHxx] prefix if it exists
    local base_name = string.match(name, "^%[CH%d%d%]%s*(.+)") or name
    -- Add the correct sequential channel number
    return "[CH" .. string.format("%02d", channel_number) .. "] " .. base_name
end

-- Usage example:
-- song.instruments[i].name = ensure_sequential_channel_prefix(song.instruments[i].name, i)

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Mixer:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets..:Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
