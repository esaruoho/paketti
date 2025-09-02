local dialog
local os_name = os.platform()
local preferences = renoise.tool().preferences
local temporary_selected_theme
local selected_theme_index
local themes_path = renoise.tool().bundle_path .. "Themes/"
local themes = os.filenames(themes_path, "*.xrnc")

-- Ensure FavoritedList is properly initialized
if not preferences.pakettiThemeSelector:property("FavoritedList") then
  preferences.pakettiThemeSelector:define_property("FavoritedList", renoise.Document { Favorited = renoise.Document.ObservableStringList { "<No Theme Selected>" } })
end

if preferences.pakettiThemeSelector.PreviousSelectedTheme == nil then
  preferences.pakettiThemeSelector.PreviousSelectedTheme = ""
end

if preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad == nil then
  preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad = false
end

if preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad == nil then
  preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad = false
end


if #themes == 0 then
  renoise.app():show_status("No themes found in Themes folder.")
  return
end

for i, theme in ipairs(themes) do
  themes[i] = theme:gsub("%.xrnc$", "")
end

table.sort(themes, function(a, b) return a:lower() < b:lower() end)
table.insert(themes, 1, "<No Theme Selected>")

local function save_preferences()
  preferences:save_as("preferences.xml")
end

local function pakettiThemeSelectorUpdateLoadTheme(theme_name)
  if not theme_name then
    renoise.app():show_status("Error: Theme name is nil.")
    return
  end

  -- Strip any trailing .xrnc extensions (just in case)
  theme_name = theme_name:gsub("%.xrnc$", "")
  
  print("Loading theme:", theme_name)

  if theme_name == "<No Theme Selected>" then
    renoise.app():show_status("No theme selected.")
    return
  end
  
  local theme_path = themes_path .. theme_name .. ".xrnc"
  
  if io.open(theme_path) then
    renoise.app():load_theme(theme_path)
    renoise.app():show_status("Loaded theme: " .. theme_name)
    temporary_selected_theme = theme_name
  else
    renoise.app():show_status("Error: Theme file not found for " .. theme_name)
  end
end


local function pakettiThemeSelectorOpenThemesPath()
  local command
  if os_name == "WINDOWS" then command = 'start "" "' .. themes_path .. '"'
  elseif os_name == "MACINTOSH" then command = 'open "' .. themes_path .. '"'
  else command = 'xdg-open "' .. themes_path .. '"' end
  os.execute(command)
end

local function pakettiThemeSelectorRefreshThemes(vb)
  themes = os.filenames(themes_path, "*.xrnc")
  for i, theme in ipairs(themes) do themes[i] = theme:gsub("%.xrnc$", "") end
  table.sort(themes, function(a, b) return a:lower() < b:lower() end)
  table.insert(themes, 1, "<No Theme Selected>")
  vb.views["themes_popup"].items = themes
  vb.views["themes_popup"].value = 1 -- Initialize the dropdown to "<No Theme Selected>"
  vb.views["themes_count"].text="Select Theme (" .. tostring(#themes - 1) .. ")"  -- Exclude "<No Theme Selected>"
end

local function pakettiThemeSelectorDialogClose(vb)
  if dialog and dialog.visible then
    if temporary_selected_theme then
      preferences.pakettiThemeSelector.PreviousSelectedTheme.value = temporary_selected_theme
      vb.views["previous_theme"].text = temporary_selected_theme  -- Update UI
    end
    dialog:close()
    save_preferences()
    if vb.views["launch_randomrandom_checkbox"] then
      preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad.value = vb.views["launch_randomrandom_checkbox"].value
      save_preferences()
    end

    if vb.views["launch_random_checkbox"] then
      preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad.value = vb.views["launch_random_checkbox"].value
      save_preferences()
    end
  end
end

local function pakettiThemeSelectorAddFavorite(theme_name)
  -- Strip the .xrnc extension if it exists
  theme_name = theme_name:gsub("%.xrnc$", "")
  
  local favorited_list = preferences.pakettiThemeSelector.FavoritedList
  local found = false
  for i = 1, #favorited_list do
    if tostring(favorited_list[i]) == theme_name then
      found = true
      break
    end
  end

  if not found then
    favorited_list:insert(#favorited_list + 1, theme_name)
    save_preferences()
  else
    renoise.app():show_status("Theme (" .. theme_name .. ") is already in your Favorites")
  end
end

local function pakettiThemeSelectorRemoveFavorite(vb, index)
  local favorited_list = preferences.pakettiThemeSelector.FavoritedList
  if index == 1 then
    renoise.app():show_status("<No Theme Selected> cannot be removed.")
    return
  end
  if index > 1 and index <= #favorited_list then
    favorited_list:remove(index)
    save_preferences()
    pakettiThemeSelectorUpdateFavoritesDropdown(vb)
    if #favorited_list > 1 then
      local new_index = math.min(index, #favorited_list)
      vb.views["favorites_popup"].value = new_index
      local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[new_index])
      selected_theme_index = table.find(themes, theme_name)
      pakettiThemeSelectorUpdateLoadTheme(theme_name)
    else
      vb.views["favorites_popup"].value = 1
      pakettiThemeSelectorUpdateLoadTheme("<No Theme Selected>")
    end
  else
    renoise.app():show_status("There are no Favorites to be removed.")
  end
end

local function save_favorites()
  if #preferences.pakettiThemeSelector.FavoritedList <= 1 then
    renoise.app():show_status("There are no Favorites to be saved")
    return
  end

  local file_path = renoise.app():prompt_for_filename_to_write("*.xml", "Save Favorites")
  if not file_path then
    renoise.app():show_status("No filename was selected, did not save Paketti Theme Selector Favorites")
    return
  end

  -- Add .xml extension if no extension is provided
  if not file_path:match("%.%w+$") then
    file_path = file_path .. ".xml"
  end

  local file = io.open(file_path, "w")
  if not file then
    renoise.app():show_status("Failed to open file for writing.")
    return
  end

  file:write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  file:write("<FavoritedList>\n")
  file:write("  <Favorited/>\n")
  for i = 2, #preferences.pakettiThemeSelector.FavoritedList do  -- Start from 2 to skip "<No Theme Selected>"
    local theme = tostring(preferences.pakettiThemeSelector.FavoritedList[i])
    if theme ~= "" then
      file:write("  <Favorited>"..theme.."</Favorited>\n")
    end
  end
  file:write("</FavoritedList>\n")
  file:close()
  renoise.app():show_status("Favorites saved to "..file_path)
end

local function load_favorites(vb)
  local file_path = renoise.app():prompt_for_filename_to_read({"*.xml"}, "Load Favorites")
  if not file_path then
    renoise.app():show_status("No filename was selected, did not load Paketti Theme Selector Favorites")
    return
  end

  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("Failed to open the selected file.")
    return
  end

  local content = file:read("*all")
  file:close()

  local favorited_list = preferences.pakettiThemeSelector.FavoritedList
  while #favorited_list > 0 do
    favorited_list:remove(#favorited_list)
  end

  favorited_list:insert(1, "<No Theme Selected>")

  local index = 2
  for theme in content:gmatch("<Favorited>(.-)</Favorited>") do
    favorited_list:insert(index, theme)
    index = index + 1
  end

  pakettiThemeSelectorUpdateFavoritesDropdown(vb)
  save_preferences()
  renoise.app():show_status("Successfully loaded Favorites")
end

function pakettiThemeSelectorUpdateFavoritesDropdown(vb)
  local items = {"<No Theme Selected>"}
  for i = 2, #preferences.pakettiThemeSelector.FavoritedList do
    local theme = tostring(preferences.pakettiThemeSelector.FavoritedList[i])
    -- Strip .xrnc extension before displaying
    theme = theme:gsub("%.xrnc$", "")
    table.insert(items, theme)
  end
  vb.views["favorites_popup"].items = items
  vb.views["favorites_count"].text="Favorites (" .. tostring(#preferences.pakettiThemeSelector.FavoritedList - 1) .. ")"  -- Exclude "<No Theme Selected>"
end

local function pakettiThemeSelectorPickRandomThemeFromAll()
  -- Initialize random seed for true randomness
  math.randomseed(os.time())
  
  local new_index
  
  -- If we have a current theme and more than 1 theme, avoid repeating it
  if selected_theme_index and #themes > 1 then
    repeat
      new_index = math.random(#themes - 1) + 1
    until new_index ~= selected_theme_index
  else
    -- First time or only one theme - just pick random
    new_index = math.random(#themes - 1) + 1
  end
  
  selected_theme_index = new_index
  pakettiThemeSelectorUpdateLoadTheme(themes[selected_theme_index])
  renoise.app():show_status("Picked a random theme from all themes: " .. themes[selected_theme_index])
end

local function pakettiThemeSelectorPickRandomThemeFromFavorites(vb)
  if not vb.views["favorites_popup"] then return end  -- Check if favorites_popup exists
  if #preferences.pakettiThemeSelector.FavoritedList <= 1 then
    renoise.app():show_status("You currently have no Favorite Themes set.")
    return
  end
  if #preferences.pakettiThemeSelector.FavoritedList == 2 then
    renoise.app():show_status("You only have 1 favorite, cannot randomize.")
    return
  end
  
  -- Initialize random seed for true randomness
  math.randomseed(os.time())
  
  local current_index = vb.views["favorites_popup"].value or 2
  local new_index
  
  repeat
    new_index = math.random(2, #preferences.pakettiThemeSelector.FavoritedList)
  until new_index ~= current_index
  
  vb.views["favorites_popup"].value = new_index
  local random_theme = preferences.pakettiThemeSelector.FavoritedList[new_index]
  local theme_name = tostring(random_theme)  -- Convert ObservableString to string
  selected_theme_index = table.find(themes, theme_name)
  pakettiThemeSelectorUpdateLoadTheme(themes[selected_theme_index])
end

local function pakettiThemeSelectorLoadNextFavoriteTheme(vb)
  local current_index = vb.views["favorites_popup"].value
  if current_index < #preferences.pakettiThemeSelector.FavoritedList then
    current_index = current_index + 1
  else
    current_index = 2
  end
  vb.views["favorites_popup"].value = current_index
  local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[current_index])
  selected_theme_index = table.find(themes, theme_name)
  pakettiThemeSelectorUpdateLoadTheme(themes[selected_theme_index])
end

local function pakettiThemeSelectorLoadPreviousFavoriteTheme(vb)
  local current_index = vb.views["favorites_popup"].value
  if current_index > 2 then
    current_index = current_index - 1
  else
    current_index = #preferences.pakettiThemeSelector.FavoritedList
  end
  vb.views["favorites_popup"].value = current_index
  local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[current_index])
  selected_theme_index = table.find(themes, theme_name)
  pakettiThemeSelectorUpdateLoadTheme(themes[selected_theme_index])
end

local function pakettiThemeSelectorDialogOpen(vb)
  selected_theme_index = 1 -- Initialize to "<No Theme Selected>"
  return vb:row{style = "panel", margin=10,
    vb:column{
      vb:row{vb:text{id = "themes_count", text="Select Theme (" .. tostring(#themes - 1) .. ")", font = "bold" } },  -- Exclude "<No Theme Selected>"
      vb:row{
        vb:popup{tooltip="popupp",id = "themes_popup", items = themes, value = selected_theme_index,width=300, notifier=function(index)
          selected_theme_index = index
          local theme_name = themes[selected_theme_index]
          pakettiThemeSelectorUpdateLoadTheme(theme_name)
        end},
        vb:button{ text="-", tooltip="hullo hello", notifier=function()
          selected_theme_index = (selected_theme_index - 2) % #themes + 1
          if selected_theme_index == 1 then selected_theme_index = #themes end
          vb.views["themes_popup"].value = selected_theme_index
          local theme_name = themes[selected_theme_index]
          pakettiThemeSelectorUpdateLoadTheme(theme_name)
        end},
        vb:button{ text="+", notifier=function()
          selected_theme_index = selected_theme_index % #themes + 1
          if selected_theme_index == 1 then selected_theme_index = 2 end
          vb.views["themes_popup"].value = selected_theme_index
          local theme_name = themes[selected_theme_index]
          pakettiThemeSelectorUpdateLoadTheme(theme_name)
        end},
        vb:button{ text="Randomize", notifier=function()
          -- Initialize random seed for true randomness
          math.randomseed(os.time())
          
          local new_index
          if #themes > 1 then
            repeat
              new_index = math.random(#themes - 1) + 1
            until new_index ~= selected_theme_index
          else
            new_index = math.random(#themes - 1) + 1
          end
          
          selected_theme_index = new_index
          vb.views["themes_popup"].value = selected_theme_index
          local theme_name = themes[selected_theme_index]
          pakettiThemeSelectorUpdateLoadTheme(theme_name)
          renoise.app():show_status("Picked a random theme at random.")
        end},
        vb:button{ text="Add as Favorite", notifier=function()
          local theme_name = themes[selected_theme_index] .. ".xrnc"
          renoise.app():show_status("Added (" .. theme_name .. ") to Favorites list.")
          if theme_name ~= "<No Theme Selected>.xrnc" then
            pakettiThemeSelectorAddFavorite(theme_name)
            pakettiThemeSelectorUpdateFavoritesDropdown(vb)
          end
        end}
      },
      vb:row{vb:text{text="Previously Loaded Theme", font = "bold" } },
      vb:row{
        vb:text{id = "previous_theme", text = tostring(preferences.pakettiThemeSelector.PreviousSelectedTheme.value) ~= "" and tostring(preferences.pakettiThemeSelector.PreviousSelectedTheme.value) or "<None>" },
        vb:button{ text="Load Previous Theme", notifier=function()
          local prev_theme = tostring(preferences.pakettiThemeSelector.PreviousSelectedTheme.value)
          if prev_theme ~= "" and prev_theme ~= "<None>" then
            local theme_path = themes_path .. prev_theme .. ".xrnc"
            renoise.app():load_theme(theme_path)
            renoise.app():show_status("Loaded Previous Theme: " .. prev_theme)
          else
            renoise.app():show_status("There was no previous theme saved, please select a theme and close the dialog and reopen the dialog.")
          end end}},
      vb:row{vb:text{id = "favorites_count", text="Favorites (" .. tostring(#preferences.pakettiThemeSelector.FavoritedList - 1) .. ")", font = "bold" } },  -- Exclude "<No Theme Selected>"
      vb:row{vb:button{text="Load Favorites", notifier=function() load_favorites(vb) end},
             vb:button{text="Save Favorites", notifier=function() save_favorites() end}},
      vb:row{vb:popup{id="favorites_popup", items={"<No Theme Selected>"},width=300, notifier=function(index)
          if index > 1 then
            local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[index])
            selected_theme_index = table.find(themes, theme_name)
            pakettiThemeSelectorUpdateLoadTheme(themes[selected_theme_index])
          end
        end},
        vb:row{
          vb:button{ text="-", notifier=function()
            local current_index = vb.views["favorites_popup"].value
            if current_index > 2 then current_index = current_index - 1 else current_index = #preferences.pakettiThemeSelector.FavoritedList end
            vb.views["favorites_popup"].value = current_index
            local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[current_index])
            selected_theme_index = table.find(themes, theme_name)
            pakettiThemeSelectorUpdateLoadTheme(theme_name)
          end},
          vb:button{ text="+", notifier=function()
            local current_index = vb.views["favorites_popup"].value
            if current_index < #preferences.pakettiThemeSelector.FavoritedList then current_index = current_index + 1 else current_index = 2 end
            vb.views["favorites_popup"].value = current_index
            local theme_name = tostring(preferences.pakettiThemeSelector.FavoritedList[current_index])
            selected_theme_index = table.find(themes, theme_name)
            pakettiThemeSelectorUpdateLoadTheme(theme_name)
          end},
          vb:button{ text="Randomize", notifier=function()
            if #preferences.pakettiThemeSelector.FavoritedList <= 1 then
              renoise.app():show_status("You currently have no Favorite Themes set.")
              return
            end
            if #preferences.pakettiThemeSelector.FavoritedList == 2 then
              renoise.app():show_status("You only have 1 favorite, cannot randomize.")
              return
            end
            
            -- Initialize random seed for true randomness
            math.randomseed(os.time())
            
            local current_index = vb.views["favorites_popup"] and vb.views["favorites_popup"].value or 2
            local new_index
            
            repeat
              new_index = math.random(2, #preferences.pakettiThemeSelector.FavoritedList)
            until new_index ~= current_index
            
            vb.views["favorites_popup"].value = new_index
            local random_theme = preferences.pakettiThemeSelector.FavoritedList[new_index]
            local theme_name = tostring(random_theme)
            
            selected_theme_index = table.find(themes, theme_name)
            if selected_theme_index then
              local full_path = themes_path .. themes[selected_theme_index]
              renoise.app():load_theme(full_path)
              renoise.app():show_status("Randomized a theme out of your favorite list: " .. theme_name)
            else
              renoise.app():show_status("Selected theme not found: " .. theme_name)
            end
          end},
          vb:button{ text="Remove Favorite", notifier=function()
            local current_index = vb.views["favorites_popup"].value
            if current_index > 1 and current_index <= #preferences.pakettiThemeSelector.FavoritedList then
              pakettiThemeSelectorRemoveFavorite(vb, current_index)
            else
              renoise.app():show_status("There are no Favorites to be removed.")
            end
          end}}},
      vb:row{vb:text{text="Paketti Theme Selector Settings", font="bold"}},
      vb:row{vb:button{text="Open Themes Path", notifier=pakettiThemeSelectorOpenThemesPath},
        vb:button{text="Refresh", notifier=function() pakettiThemeSelectorRefreshThemes(vb) end}},
      vb:row{vb:checkbox{
          id="launch_randomrandom_checkbox",
          value=preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad.value,  -- Correctly initialize the checkbox value
          notifier=function(value)
            preferences.pakettiThemeSelector.RenoiseLaunchRandomLoad.value = value
            save_preferences() end},
        vb:text{text="On Renoise Launch, Randomize Any Theme" }},

      vb:row{vb:checkbox{
          id="launch_random_checkbox",
          value=preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad.value,  -- Correctly initialize the checkbox value
          notifier=function(value)
            preferences.pakettiThemeSelector.RenoiseLaunchFavoritesLoad.value = value
            save_preferences() end},
        vb:text{text="On Renoise Launch, Randomize Favorite Theme" }},
      vb:row{vb:button{text="Close",notifier=function() pakettiThemeSelectorDialogClose(vb) end}}}}
end

function pakettiThemeSelectorDialogShow()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  -- Create keyhandler that can manage dialog variable
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Theme Selector", pakettiThemeSelectorDialogOpen(vb), keyhandler)
  pakettiThemeSelectorUpdateFavoritesDropdown(vb)
end

function pakettiThemeSelectorPickRandomThemeFromFavoritesNoGUI()
  local themes_path = renoise.tool().bundle_path .. "Themes/"
  local themes = os.filenames(themes_path, "*.xrnc")
  local selected_theme_index = nil

  if #preferences.pakettiThemeSelector.FavoritedList <= 1 then
    renoise.app():show_status("You currently have no Favorite Themes set.")
    return
  end
  if #preferences.pakettiThemeSelector.FavoritedList == 2 then
    renoise.app():show_status("You only have 1 favorite, cannot randomize.")
    return
  end

  -- Initialize random seed for true randomness
  math.randomseed(os.time())

  local current_index = math.random(2, #preferences.pakettiThemeSelector.FavoritedList)
  local random_theme = preferences.pakettiThemeSelector.FavoritedList[current_index]

  local cleaned_theme_name = tostring(random_theme)

  selected_theme_index = table.find(themes, cleaned_theme_name)

  if cleaned_theme_name then
    local full_path = themes_path .. cleaned_theme_name .. ".xrnc"
    renoise.app():load_theme(full_path)
    renoise.app():show_status("Randomized a theme out of your favorite list: " .. cleaned_theme_name)
  else
    renoise.app():show_status("Selected theme not found.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti Theme Selector:Open Paketti Theme Selector Dialog...",invoke=function() pakettiThemeSelectorDialogShow() end}
renoise.tool():add_keybinding{name="Global:Paketti Theme Selector:Pick a Random Theme (All)",invoke=function() pakettiThemeSelectorPickRandomThemeFromAll() end}
renoise.tool():add_keybinding{name="Global:Paketti Theme Selector:Pick a Random Theme (Favorites)",invoke=function() 
    local vb=renoise.ViewBuilder()
    pakettiThemeSelectorPickRandomThemeFromFavoritesNoGUI() end}

