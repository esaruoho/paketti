local tool_folder = renoise.tool().bundle_path
local bluethereal_folder = tool_folder .. "Customization/Bluethereal fonts/"
local customization_folder = tool_folder .. "Customization/"
local destination_folder
local renoise_version = tostring(renoise.RENOISE_VERSION)
local os_name = os.platform()

-- Detect OS
if os_name == "MACINTOSH" then
  destination_folder = "/Applications/Renoise.app/Contents/Resources/Skin/Fonts"
elseif os_name == "WINDOWS" then
  destination_folder = "C:\\Program Files\\Renoise " .. renoise_version .. "\\Resources\\Skin\\Fonts"
else
  renoise.app():show_status("Linux OS detected. Please provide the Fonts folder path.")
  return
end

-- Copy function
local function copy_file(source, destination)
  local command
  if os_name == "WINDOWS" then
    command = 'xcopy "' .. source .. '" "' .. destination .. '" /Y /Q'
  else
    command = 'cp -f "' .. source .. '" "' .. destination .. '"'
  end
  os.execute(command)
end

-- Shortcut 1: Copy PatternFont.ttf and PatternConfig.xml
local function ChangeFonts1()
  copy_file(bluethereal_folder .. "PatternFont.ttf", destination_folder .. "/PatternFont.ttf")
  copy_file(bluethereal_folder .. "PatternConfig.xml", destination_folder .. "/PatternConfig.xml")
renoise.app():show_status("Make sure to restart Renoise to see the change.")
end

-- Shortcut 2: Copy and Rename PatternConfig_original.xml
local function ChangeFonts2()
  local source_file = customization_folder .. "PatternConfig_original.xml"
  local temp_destination = destination_folder .. "/PatternConfig_original.xml"
  copy_file(source_file, temp_destination)
  
  -- Rename the copied file
  local final_destination = destination_folder .. "/PatternConfig.xml"
  os.rename(temp_destination, final_destination)
renoise.app():show_status("Make sure to restart Renoise to see the change.")
end

local function ChangeFonts3()
  copy_file(customization_folder .. "Agave-Regular.ttf", destination_folder .. "/Agave-Regular.ttf")
  copy_file(customization_folder .. "PatternConfig_agave.xml", destination_folder .. "/PatternConfig.xml")
renoise.app():show_status("Make sure to restart Renoise to see the change.")
end



--renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:!Preferences:Change Fonts (classic)",invoke=function() ChangeFonts1() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Change Fonts (default)",invoke=function() ChangeFonts2() end}
--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Change Fonts (Agave)",invoke=function() ChangeFonts3() end}



