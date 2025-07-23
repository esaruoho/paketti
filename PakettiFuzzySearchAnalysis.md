# Paketti Fuzzy Search Analysis & Unified Utility

## Analysis of Existing Search Implementations

### 1. Fuzzy Search Track (Character-based Subsequence Matching)

**Original Location:** `PakettiRequests.lua` - `fuzzy_match()` function

**Algorithm:** Character-by-character subsequence matching
- Characters from the search pattern must appear in the target string **in order**
- Characters don't need to be consecutive
- Case-insensitive matching

**Example:**
- Pattern: `"kt"` matches `"Kit"`, `"Kick Track"`, `"Synth Kit"`
- Pattern: `"drm"` matches `"Drum"`, `"Drum Machine"`, `"Distorted Rhythm"`

**Use Case:** Quick track selection when you know part of the track name

### 2. KeyBindings Search (Multi-word Substring Matching)

**Original Location:** `PakettiKeyBindings.lua` - both update functions

**Algorithm:** Multi-word substring search across multiple fields
- Splits search query into words (whitespace-separated)
- ALL words must be found as substrings in ANY of the searchable fields
- Case-insensitive matching
- Searches across: Topic, Binding, Identifier, Key

**Example:**
- Query: `"paketti sample"` must find both "paketti" AND "sample" somewhere in the fields
- Query: `"ctrl shift"` finds shortcuts with both modifiers

**Use Case:** Complex filtering across structured data with multiple searchable fields

## Key Differences

| Aspect | Fuzzy Track Search | KeyBindings Search |
|--------|-------------------|-------------------|
| **Match Type** | Character subsequence | Word substrings |
| **Field Count** | Single field (name) | Multiple fields |
| **Word Handling** | Treats as character sequence | Splits into separate words |
| **Match Requirements** | Characters in order | All words found anywhere |

## Unified Utility: `PakettiFuzzySearchUtil()`

### Core Function Signature

```lua
PakettiFuzzySearchUtil(items, search_query, options)
```

### Parameters

- **`items`**: Array/table of items to search through
- **`search_query`**: String to search for
- **`options`**: Configuration table with these fields:
  - `search_type`: `"fuzzy"` (character-based) or `"substring"` (multi-word)
  - `fields`: Array of field names to search in
  - `field_extractor`: Function to extract searchable strings from items
  - `custom_matcher`: Custom matching function

### Helper Functions

1. **`PakettiFuzzySearchKeybindings(keybindings, search_query)`**
   - Maintains backward compatibility with keybindings search
   - Uses substring search across Topic, Binding, Identifier, Key fields

2. **`PakettiFuzzySearchTracks(tracks, search_query)`**
   - Maintains backward compatibility with track search
   - Uses fuzzy character matching on track names

3. **`PakettiFuzzySearchStrings(strings, search_query, use_fuzzy)`**
   - For simple string arrays
   - Choose between fuzzy or substring matching

4. **`PakettiFuzzySearchDialogItems(items, search_query)`**
   - For dialog buttons/menu items
   - Searches text, name, label, title, description fields

### Usage Examples

#### Dialog of Dialogs Integration

```lua
-- Example for filtering dialog buttons
local dialog_buttons = {
  {text = "Sample Editor", description = "Edit samples"},
  {text = "Track Automation", description = "Automate parameters"},
  {text = "Pattern Editor", description = "Edit patterns"}
}

-- User searches for "sample"
local filtered = PakettiFuzzySearchDialogItems(dialog_buttons, "sample")
-- Returns: {text = "Sample Editor", description = "Edit samples"}

-- User searches for "edit param"
local filtered = PakettiFuzzySearchDialogItems(dialog_buttons, "edit param")
-- Returns: {text = "Track Automation", description = "Automate parameters"}
```

#### Custom Field Extraction

```lua
-- Custom field extractor for complex objects
local devices = {
  {name = "Reverb", type = "Effect", category = "Spatial"},
  {name = "Delay", type = "Effect", category = "Time"}
}

local filtered = PakettiFuzzySearchUtil(devices, "effect spatial", {
  search_type = "substring",
  field_extractor = function(device)
    return {device.name, device.type, device.category}
  end
})
```

#### Fuzzy vs Substring Comparison

```lua
local items = {"Kick Drum", "Snare Hit", "Hi-Hat"}

-- Fuzzy search: "kdr" matches "Kick Drum" (K-ick D-R-um)
local fuzzy_results = PakettiFuzzySearchStrings(items, "kdr", true)

-- Substring search: "kick drum" matches "Kick Drum" exactly
local substring_results = PakettiFuzzySearchStrings(items, "kick drum", false)
```

## Integration Points

### Current Integration
- **PakettiKeyBindings.lua**: Uses `PakettiFuzzySearchKeybindings()` for filtering
- **PakettiRequests.lua**: Uses `PakettiFuzzySearchTracks()` for track selection

### Future Integration Opportunities
1. **Dialog of Dialogs**: Filter available dialogs/functions
2. **Plugin Browser**: Search through available plugins
3. **Sample Browser**: Find samples across libraries
4. **Preset Browser**: Search instrument/effect presets
5. **Menu Search**: Global menu item search

## Performance Considerations

- **Character-based fuzzy**: O(n*m) where n=pattern length, m=string length
- **Multi-word substring**: O(w*n*m) where w=word count, n=strings, m=avg length
- **Memory**: Minimal overhead, results returned as new arrays
- **Caching**: No internal caching, implement externally if needed

## Backward Compatibility

The utility maintains 100% backward compatibility with existing search behavior:
- Existing KeyBindings search works identically
- Existing Track search works identically
- No breaking changes to existing APIs

## Future Enhancements

1. **Fuzzy Scoring**: Return match quality scores
2. **Highlighting**: Mark matched characters/words in results
3. **Sorting**: Sort results by relevance/match quality
4. **Caching**: Optional result caching for performance
5. **Regex Support**: Optional regex pattern matching
6. **Weighted Fields**: Give different importance to different fields 