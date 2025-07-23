-- PakettiFuzzySearchUtil.lua
-- Unified fuzzy search utility for Paketti
-- Combines character-based fuzzy matching and multi-word substring search

-- Character-based fuzzy matching (subsequence matching)
-- Characters from pattern must appear in target string in order, but not necessarily consecutive
local function fuzzy_match_characters(pattern, str)
  if not pattern or not str then return false end
  
  pattern = string.lower(pattern)
  str = string.lower(str)
  
  local pattern_len = #pattern
  local str_len = #str
  local j = 1
  
  for i = 1, pattern_len do
    local pattern_char = pattern:sub(i,i)
    local found = false
    
    while j <= str_len do
      if pattern_char == str:sub(j,j) then
        found = true
        j = j + 1
        break
      end
      j = j + 1
    end
    
    if not found then return false end
  end
  
  return true
end

-- Multi-word substring search
-- All words in search query must be found as substrings in any of the searchable fields
local function multi_word_substring_match(search_query, searchable_strings)
  if not search_query or #search_query == 0 then return true end
  if not searchable_strings or #searchable_strings == 0 then return false end
  
  local query_lower = string.lower(search_query)
  
  -- Convert all searchable strings to lowercase
  local strings_lower = {}
  for _, str in ipairs(searchable_strings) do
    if str then
      table.insert(strings_lower, string.lower(str))
    end
  end
  
  -- Check each word in the search query
  for word in query_lower:gmatch("%S+") do
    local word_found = false
    
    -- Check if word exists in any of the searchable strings
    for _, str in ipairs(strings_lower) do
      if str:find(word) then
        word_found = true
        break
      end
    end
    
    -- If any word is not found, the match fails
    if not word_found then
      return false
    end
  end
  
  return true
end

-- Main fuzzy search utility function
-- @param items: array/table of items to search through
-- @param search_query: string to search for
-- @param options: table with configuration options
--   - search_type: "fuzzy" (character-based) or "substring" (multi-word substring)
--   - fields: array of field names to search in (for objects/tables)
--   - field_extractor: function(item) -> array of strings to search in
--   - custom_matcher: function(search_query, item) -> boolean
function PakettiFuzzySearchUtil(items, search_query, options)
  if not items or #items == 0 then return {} end
  if not search_query or search_query == "" then return items end
  
  -- Default options
  options = options or {}
  local search_type = options.search_type or "substring"
  local fields = options.fields or {}
  local field_extractor = options.field_extractor
  local custom_matcher = options.custom_matcher
  
  local results = {}
  
  for i, item in ipairs(items) do
    local matches = false
    
    if custom_matcher then
      -- Use custom matching function
      matches = custom_matcher(search_query, item)
      
    elseif field_extractor then
      -- Use custom field extraction function
      local searchable_strings = field_extractor(item)
      if search_type == "fuzzy" then
        -- For fuzzy search, check each string individually
        for _, str in ipairs(searchable_strings) do
          if fuzzy_match_characters(search_query, str) then
            matches = true
            break
          end
        end
      else
        -- For substring search, check all strings together
        matches = multi_word_substring_match(search_query, searchable_strings)
      end
      
    elseif #fields > 0 then
      -- Use specified fields
      local searchable_strings = {}
      for _, field in ipairs(fields) do
        if item[field] then
          table.insert(searchable_strings, tostring(item[field]))
        end
      end
      
      if search_type == "fuzzy" then
        for _, str in ipairs(searchable_strings) do
          if fuzzy_match_characters(search_query, str) then
            matches = true
            break
          end
        end
      else
        matches = multi_word_substring_match(search_query, searchable_strings)
      end
      
    elseif type(item) == "string" then
      -- Simple string matching
      if search_type == "fuzzy" then
        matches = fuzzy_match_characters(search_query, item)
      else
        matches = multi_word_substring_match(search_query, {item})
      end
      
    else
      -- Fallback: convert item to string
      local item_str = tostring(item)
      if search_type == "fuzzy" then
        matches = fuzzy_match_characters(search_query, item_str)
      else
        matches = multi_word_substring_match(search_query, {item_str})
      end
    end
    
    if matches then
      table.insert(results, item)
    end
  end
  
  return results
end

-- Helper function specifically for keybindings search (maintains backward compatibility)
function PakettiFuzzySearchKeybindings(keybindings, search_query)
  return PakettiFuzzySearchUtil(keybindings, search_query, {
    search_type = "substring",
    field_extractor = function(binding)
      return {
        binding.Topic or "",
        binding.Binding or "",
        binding.Identifier or "",
        binding.Key or ""
      }
    end
  })
end

-- Helper function specifically for track search (maintains backward compatibility)
function PakettiFuzzySearchTracks(tracks, search_query)
  return PakettiFuzzySearchUtil(tracks, search_query, {
    search_type = "fuzzy",
    field_extractor = function(track)
      return {track.name or ""}
    end
  })
end

-- Helper function for simple string arrays
function PakettiFuzzySearchStrings(strings, search_query, use_fuzzy)
  local search_type = use_fuzzy and "fuzzy" or "substring"
  return PakettiFuzzySearchUtil(strings, search_query, {
    search_type = search_type
  })
end

-- Example usage for dialog buttons or menu items
function PakettiFuzzySearchDialogItems(items, search_query)
  return PakettiFuzzySearchUtil(items, search_query, {
    search_type = "substring",
    field_extractor = function(item)
      local searchable = {}
      -- Handle different item structures
      if item.text then table.insert(searchable, item.text) end
      if item.name then table.insert(searchable, item.name) end
      if item.label then table.insert(searchable, item.label) end
      if item.title then table.insert(searchable, item.title) end
      if item.description then table.insert(searchable, item.description) end
      return searchable
    end
  })
end 