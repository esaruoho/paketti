-- Import hook for XM files
local function import_xm_file(filename)
  -- Print debug information
  print("Attempting to import XM file:", filename)
  
  -- Show error message to user
  renoise.app():show_error(
    "XM Import Information",
    "XM file import was attempted.\n" ..
    "Filename: " .. filename .. "\n" ..
    "This is a test error message for XM import."
  )
  
  -- Return false to indicate import was not successful
  -- This is just for demonstration - you would implement actual import logic here
  return false
end

-- Define the import hook
local xm_import_hook = {
  ["category"] = "instrument",  -- XM files are typically instruments
  ["extensions"] = {"xm"},     -- File extension for XM files
  ["invoke"] = import_xm_file  -- Function to call when importing
}

-- Check if hook already exists before adding
if not renoise.tool():has_file_import_hook("instrument", {"xm"}) then
  -- Add the import hook
  renoise.tool():add_file_import_hook(xm_import_hook)
  print("XM import hook registered successfully")
else
  print("XM import hook already exists")
end
