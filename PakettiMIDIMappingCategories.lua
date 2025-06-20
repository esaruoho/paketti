-- PakettiMIDIMappingCategories.lua
-- MIDI Mapping Category Management System
-- Provides persistent categorization and filtering for MIDI mappings

local separator = package.config:sub(1,1)

-- Default categories (can be extended by user)
local DEFAULT_CATEGORIES = {
  "Uncategorized",
  "Pattern Editor: Navigation", 
  "Pattern Editor: Editing",
  "Pattern Editor: Effects",
  "Sample Editor: Process",
  "Sample Editor: Navigation", 
  "Sample Editor: Selection",
  "Automation: Control",
  "Automation: Editing",
  "Playback: Control",
  "Playback: Recording",
  "Track: Navigation",
  "Track: Control",
  "Track: Effects",
  "Instrument: Control",
  "Instrument: Loading",
  "Sequencer: Control",
  "Sequencer: Navigation",
  "Mixer: Control",
  "Utility: General",
  "Experimental: Test",
  "Paketti Gadgets: General",
  "Paketti Gadgets: Tools"
}

-- Hierarchical category structure
local CATEGORY_HIERARCHY = {
  ["Pattern Editor"] = {"Navigation", "Editing", "Effects"},
  ["Sample Editor"] = {"Process", "Navigation", "Selection"},
  ["Automation"] = {"Control", "Editing"},
  ["Playback"] = {"Control", "Recording"},
  ["Track"] = {"Navigation", "Control", "Effects"},
  ["Instrument"] = {"Control", "Loading"},
  ["Sequencer"] = {"Control", "Navigation"},
  ["Mixer"] = {"Control"},
  ["Utility"] = {"General"},
  ["Experimental"] = {"Test"},
  ["Paketti Gadgets"] = {"General", "Tools"}
}

-- Create preferences document for category management
local category_preferences = renoise.Document.create("PakettiMIDIMappingCategoryPreferences") {
  -- Available categories
  categories = renoise.Document.DocumentList(),
  
  -- Mapping assignments: mapping_name -> category_name
  assignments = renoise.Document.DocumentList(),
  
  -- User preferences
  last_selected_category = renoise.Document.ObservableString("All Mappings"),
  show_uncategorized_only = renoise.Document.ObservableBoolean(false),
  auto_save_changes = renoise.Document.ObservableBoolean(true)
}

-- Document structures for categories and assignments
renoise.Document.create("PakettiMIDICategoryEntry") {
  name = renoise.Document.ObservableString()
}

renoise.Document.create("PakettiMIDIAssignmentEntry") {
  mapping_name = renoise.Document.ObservableString(),
  category_name = renoise.Document.ObservableString()
}

-- Helper functions to create document entries
function create_category_entry(name)
  local entry = renoise.Document.instantiate("PakettiMIDICategoryEntry")
  entry.name.value = name
  return entry
end

function create_assignment_entry(mapping_name, category_name)
  local entry = renoise.Document.instantiate("PakettiMIDIAssignmentEntry")
  entry.mapping_name.value = mapping_name
  entry.category_name.value = category_name
  return entry
end

-- File paths
local CATEGORIES_FILE = renoise.tool().bundle_path .. "PakettiMIDIMappingCategories.xml"

-- Initialize categories with defaults if none exist
function initialize_default_categories()
  if #category_preferences.categories == 0 then
    print("Initializing default MIDI mapping categories...")
    for _, category in ipairs(DEFAULT_CATEGORIES) do
      local entry = create_category_entry(category)
      category_preferences.categories:insert(#category_preferences.categories + 1, entry)
    end
    save_category_preferences()
  end
end

-- Save categories and assignments to file
function save_category_preferences()
  category_preferences:save_as(CATEGORIES_FILE)
  print("MIDI mapping categories saved to: " .. CATEGORIES_FILE)
end

-- Load categories and assignments from file
function load_category_preferences()
  if io.exists(CATEGORIES_FILE) then
    category_preferences:load_from(CATEGORIES_FILE)
    print("MIDI mapping categories loaded from: " .. CATEGORIES_FILE)
  else
    print("No existing categories file found, using defaults")
    initialize_default_categories()
  end
end

-- Get all category names as a table
function get_all_categories()
  local categories = {}
  for i = 1, #category_preferences.categories do
    local category = category_preferences.categories:property(i)
    table.insert(categories, category.name.value)
  end
  return categories
end

-- Get main categories (the part before the colon)
function get_main_categories()
  local main_categories = {}
  local seen = {}
  
  for i = 1, #category_preferences.categories do
    local category = category_preferences.categories:property(i)
    local full_name = category.name.value
    
    if full_name ~= "Uncategorized" then
      local main_part = full_name:match("^([^:]+):")
      if main_part and not seen[main_part] then
        table.insert(main_categories, main_part)
        seen[main_part] = true
      end
    end
  end
  
  -- Sort main categories
  table.sort(main_categories)
  
  -- Add Uncategorized at the beginning
  table.insert(main_categories, 1, "Uncategorized")
  
  return main_categories
end

-- Get sub-categories for a main category
function get_sub_categories(main_category)
  if main_category == "Uncategorized" then
    return {"Uncategorized"}
  end
  
  local sub_categories = {}
  
  for i = 1, #category_preferences.categories do
    local category = category_preferences.categories:property(i)
    local full_name = category.name.value
    
    local main_part, sub_part = full_name:match("^([^:]+):%s*(.+)")
    if main_part == main_category and sub_part then
      table.insert(sub_categories, sub_part)
    end
  end
  
  -- Sort sub-categories
  table.sort(sub_categories)
  
  return sub_categories
end

-- Add sub-categories for a main category based on hierarchy
function add_sub_categories_for_main(main_category)
  local hierarchy = CATEGORY_HIERARCHY[main_category]
  if not hierarchy then
    return false, "No hierarchy defined for: " .. main_category
  end
  
  local added_count = 0
  for _, sub_cat in ipairs(hierarchy) do
    local full_name = main_category .. ": " .. sub_cat
    local success, msg = add_category(full_name)
    if success then
      added_count = added_count + 1
    end
  end
  
  return true, string.format("Added %d sub-categories for %s", added_count, main_category)
end

-- Get full category name from main and sub parts
function get_full_category_name(main_category, sub_category)
  if main_category == "Uncategorized" then
    return "Uncategorized"
  end
  return main_category .. ": " .. sub_category
end

-- Add a new category
function add_category(category_name)
  if not category_name or category_name == "" then
    return false, "Category name cannot be empty"
  end
  
  -- Check if category already exists
  for i = 1, #category_preferences.categories do
    local category = category_preferences.categories:property(i)
    if category.name.value == category_name then
      return false, "Category already exists"
    end
  end
  
  -- Add new category
  local entry = create_category_entry(category_name)
  category_preferences.categories:insert(#category_preferences.categories + 1, entry)
  
  if category_preferences.auto_save_changes.value then
    save_category_preferences()
  end
  
  print("Added category: " .. category_name)
  return true, "Category added successfully"
end

-- Remove a category (and reassign its mappings to "Uncategorized")
function remove_category(category_name)
  if category_name == "Uncategorized" then
    return false, "Cannot remove 'Uncategorized' category"
  end
  
  -- Find and remove the category
  local removed = false
  for i = #category_preferences.categories, 1, -1 do
    local category = category_preferences.categories:property(i)
    if category.name.value == category_name then
      category_preferences.categories:remove(i)
      removed = true
      break
    end
  end
  
  if not removed then
    return false, "Category not found"
  end
  
  -- Reassign all mappings from this category to "Uncategorized"
  for i = 1, #category_preferences.assignments do
    local assignment = category_preferences.assignments:property(i)
    if assignment.category_name.value == category_name then
      assignment.category_name.value = "Uncategorized"
    end
  end
  
  if category_preferences.auto_save_changes.value then
    save_category_preferences()
  end
  
  print("Removed category: " .. category_name)
  return true, "Category removed successfully"
end

-- Assign a mapping to a category
function assign_mapping_to_category(mapping_name, category_name)
  if not mapping_name or not category_name then
    return false, "Mapping name and category name are required"
  end
  
  -- Check if assignment already exists
  for i = 1, #category_preferences.assignments do
    local assignment = category_preferences.assignments:property(i)
    if assignment.mapping_name.value == mapping_name then
      assignment.category_name.value = category_name
      if category_preferences.auto_save_changes.value then
        save_category_preferences()
      end
      print("Updated assignment: " .. mapping_name .. " -> " .. category_name)
      return true, "Assignment updated"
    end
  end
  
  -- Create new assignment
  local entry = create_assignment_entry(mapping_name, category_name)
  category_preferences.assignments:insert(#category_preferences.assignments + 1, entry)
  
  if category_preferences.auto_save_changes.value then
    save_category_preferences()
  end
  
  print("Created assignment: " .. mapping_name .. " -> " .. category_name)
  return true, "Assignment created"
end

-- Get the category for a mapping (returns "Uncategorized" if not assigned)
function get_mapping_category(mapping_name)
  for i = 1, #category_preferences.assignments do
    local assignment = category_preferences.assignments:property(i)
    if assignment.mapping_name.value == mapping_name then
      -- Debug output for the first few lookups
      if i <= 3 then
        print("DEBUG: Found assignment for " .. mapping_name .. " -> " .. assignment.category_name.value)
      end
      return assignment.category_name.value
    end
  end
  -- Debug output for uncategorized items (first few)
  if #category_preferences.assignments <= 10 then  -- Only if not too many assignments
    print("DEBUG: No assignment found for " .. mapping_name .. " -> returning Uncategorized")
  end
  return "Uncategorized"
end

-- Get all mappings for a specific category
function get_mappings_for_category(category_name, all_mappings)
  local result = {}
  
  if category_name == "All Mappings" then
    return all_mappings
  end
  
  for _, mapping in ipairs(all_mappings) do
    local mapping_category = get_mapping_category(mapping)
    if mapping_category == category_name then
      table.insert(result, mapping)
    end
  end
  
  return result
end

-- Get uncategorized mappings
function get_uncategorized_mappings(all_mappings)
  return get_mappings_for_category("Uncategorized", all_mappings)
end

-- Get category statistics
function get_category_statistics(all_mappings)
  local stats = {}
  local categories = get_all_categories()
  
  -- Initialize counts
  for _, category in ipairs(categories) do
    stats[category] = 0
  end
  
  -- Count mappings per category
  for _, mapping in ipairs(all_mappings) do
    local category = get_mapping_category(mapping)
    if stats[category] then
      stats[category] = stats[category] + 1
    else
      stats["Uncategorized"] = (stats["Uncategorized"] or 0) + 1
    end
  end
  
  return stats
end

-- Remove assignment for a mapping
function remove_mapping_assignment(mapping_name)
  for i = #category_preferences.assignments, 1, -1 do
    local assignment = category_preferences.assignments:property(i)
    if assignment.mapping_name.value == mapping_name then
      category_preferences.assignments:remove(i)
      if category_preferences.auto_save_changes.value then
        save_category_preferences()
      end
      print("Removed assignment for: " .. mapping_name)
      return true
    end
  end
  return false
end

-- Export categories and assignments to a text file for backup/sharing
function export_categories_to_txt()
  local filename = renoise.app():prompt_for_filename_to_write("*.txt", "Export MIDI Categories")
  if not filename then return end
  
  local file = io.open(filename, "w")
  if not file then
    renoise.app():show_error("Could not create file: " .. filename)
    return
  end
  
  file:write("-- Paketti MIDI Mapping Categories Export\n")
  file:write("-- Generated: " .. os.date() .. "\n\n")
  
  file:write("-- Categories:\n")
  local categories = get_all_categories()
  for _, category in ipairs(categories) do
    file:write("CATEGORY: " .. category .. "\n")
  end
  
  file:write("\n-- Assignments:\n")
  for i = 1, #category_preferences.assignments do
    local assignment = category_preferences.assignments:property(i)
    file:write("ASSIGN: " .. assignment.mapping_name.value .. " -> " .. assignment.category_name.value .. "\n")
  end
  
  file:close()
  renoise.app():show_status("Categories exported to: " .. filename)
end

-- Import categories and assignments from a text file
function import_categories_from_txt()
  local filename = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Import MIDI Categories")
  if not filename then return end
  
  local file = io.open(filename, "r")
  if not file then
    renoise.app():show_error("Could not read file: " .. filename)
    return
  end
  
  local imported_categories = 0
  local imported_assignments = 0
  
  for line in file:lines() do
    line = line:match("^%s*(.-)%s*$") -- trim whitespace
    
    if line:match("^CATEGORY:%s*") then
      local category_name = line:match("^CATEGORY:%s*(.+)")
      if category_name then
        local success, msg = add_category(category_name)
        if success then
          imported_categories = imported_categories + 1
        end
      end
    elseif line:match("^ASSIGN:%s*") then
      local assignment = line:match("^ASSIGN:%s*(.+)")
      if assignment then
        local mapping_name, category_name = assignment:match("^(.+)%s*%->%s*(.+)")
        if mapping_name and category_name then
          local success, msg = assign_mapping_to_category(mapping_name, category_name)
          if success then
            imported_assignments = imported_assignments + 1
          end
        end
      end
    end
  end
  
  file:close()
  save_category_preferences()
  
  renoise.app():show_status(string.format("Imported %d categories and %d assignments", 
    imported_categories, imported_assignments))
end

-- Debug function to print all assignments
function debug_print_all_assignments()
  print("=== DEBUG: ALL CATEGORY ASSIGNMENTS ===")
  print("Total assignments: " .. #category_preferences.assignments)
  for i = 1, math.min(10, #category_preferences.assignments) do
    local assignment = category_preferences.assignments:property(i)
    print(string.format("  %d: %s -> %s", i, assignment.mapping_name.value, assignment.category_name.value))
  end
  if #category_preferences.assignments > 10 then
    print("  ... and " .. (#category_preferences.assignments - 10) .. " more")
  end
  print("===============================")
end

-- Initialize on load
load_category_preferences()

print("PakettiMIDIMappingCategories.lua loaded - Category management system ready!") 