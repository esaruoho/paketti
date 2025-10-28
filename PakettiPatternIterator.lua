-- PakettiPatternIterator.lua
-- Comprehensive pattern iterator helper tools for fast iteration over song data
-- Based on Renoise PatternIterator implementation
-- All functions are global and use Paketti namespace

------------------------------------------------------------------------------
-- Core Iterator Builders
------------------------------------------------------------------------------

function PakettiPatternIteratorMakeNoteColumnIter(song, line_iter, visible_columns_only)
  assert(type(line_iter) == 'function')
  visible_columns_only = visible_columns_only or false

  local pos, line = line_iter()

  if (pos == nil or line == nil) then
    return nil
  end

  local columns = line.note_columns
  local column_count = #columns

  if visible_columns_only then
    column_count = song.tracks[pos.track].visible_note_columns
  end

  -- we start by increasing the column
  pos.column = 0

  return function()
    pos.column = pos.column + 1

    if (pos.column <= column_count) then
      return pos, columns[pos.column]
    end

    -- loop until we found a line with visible columns
    while true do
      pos, line = line_iter()

      if (pos == nil or line == nil) then
        return nil
      end

      columns = line.note_columns
      column_count = #columns

      if visible_columns_only then
        column_count = song.tracks[pos.track].visible_note_columns
      end

      if (column_count > 0) then
        pos.column = 1
        return pos, columns[pos.column]
      end
    end

    return nil
  end
end

function PakettiPatternIteratorMakeEffectColumnIter(song, line_iter, visible_columns_only)
  assert(type(line_iter) == 'function')
  visible_columns_only = visible_columns_only or false
  
  local pos, line = line_iter()

  if (pos == nil or line == nil) then
    return nil
  end

  local columns = line.effect_columns
  local column_count = #columns

  if visible_columns_only then
    column_count = song.tracks[pos.track].visible_effect_columns
  end

  -- we start by increasing the column
  pos.column = 0

  return function()
    pos.column = pos.column + 1

    if (pos.column <= column_count) then
      return pos, columns[pos.column]
    end

    -- loop until we found a line with visible columns
    while true do
      pos, line = line_iter()

      if (pos == nil or line == nil) then
        return nil
      end

      columns = line.effect_columns
      column_count = #columns

      if visible_columns_only then
        column_count = song.tracks[pos.track].visible_effect_columns
      end

      if (column_count > 0) then
        pos.column = 1
        return pos, columns[pos.column]
      end
    end

    return nil
  end
end

------------------------------------------------------------------------------
-- Helper: Build Pattern Order List
------------------------------------------------------------------------------

function PakettiPatternIteratorBuildPatternOrder(song, visible_patterns_only)
  visible_patterns_only = visible_patterns_only or true
  local pattern_order = {}
  
  if visible_patterns_only then
    local pattern_sequence = song.sequencer.pattern_sequence
    local referenced_patterns = {}

    for seq_index, pattern_index in pairs(pattern_sequence) do 
      if not referenced_patterns[pattern_index] then
        referenced_patterns[pattern_index] = true
        pattern_order[#pattern_order + 1] = pattern_index
      end
    end
  else
    for pattern_index = 1, #song.patterns do
      pattern_order[#pattern_order + 1] = pattern_index
    end
  end
  
  return pattern_order
end

------------------------------------------------------------------------------
-- Lines in Song (Pattern → Track → Line)
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInSong(song, visible_patterns_only)
  visible_patterns_only = visible_patterns_only or true
  local pattern_order = PakettiPatternIteratorBuildPatternOrder(song, visible_patterns_only)

  local pattern_order_index = 1
  local start_pos = { pattern = pattern_order[1], track = 1, line = 1 }
  local pos = { pattern = pattern_order[1], track = 1, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pos.track = pos.track + 1

      if pos.track > #pattern_tracks then
        pos.track = 1
        pattern_order_index = pattern_order_index + 1 

        if pattern_order_index > #pattern_order then
          -- completed: reset and stop
          pattern_order_index = 1
          pos.pattern = start_pos.pattern
          pos.track = start_pos.track
          pos.line = start_pos.line

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
          return nil

        else
          -- new pattern
          pos.pattern = pattern_order[pattern_order_index]

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
        end

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInSong(song, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInSong(song, visible_only), visible_only)
end

function PakettiPatternIteratorEffectColumnsInSong(song, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInSong(song, visible_only), visible_only)
end

------------------------------------------------------------------------------
-- Lines in Pattern (Track → Line)
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInPattern(song, pattern_index)
  assert(type(pattern_index) == 'number', ('pattern_index parameter: ' ..
    'expected an index (a number), got a \'%s\' object'):format(type(pattern_index)))

  local start_pos = { pattern = pattern_index, track = 1, line = 1 }
  local pos = { pattern = pattern_index, track = 1, line = 1 }

  local pattern = song.patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pos.track = pos.track + 1

      if pos.track > #pattern_tracks then
        -- completed: reset and stop
        pos.track = start_pos.track
        pos.line = start_pos.line
        
        pattern_track = pattern_tracks[pos.track]
        return nil

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInPattern(song, pattern_index, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInPattern(song, pattern_index), visible_only)
end

function PakettiPatternIteratorEffectColumnsInPattern(song, pattern_index, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInPattern(song, pattern_index), visible_only)
end

------------------------------------------------------------------------------
-- Lines in Track (Pattern → Line) - Track First!
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInTrack(song, track_index, visible_patterns_only)
  assert(type(track_index) == 'number', ('track_index parameter: ' ..
    'expected an index (a number), got a \'%s\' object'):format(type(track_index)))

  visible_patterns_only = visible_patterns_only or true
  local pattern_order = PakettiPatternIteratorBuildPatternOrder(song, visible_patterns_only)

  local pattern_order_index = 1
  local start_pos = { pattern = pattern_order[1], track = track_index, line = 1 }
  local pos = { pattern = pattern_order[1], track = track_index, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pattern_order_index = pattern_order_index + 1 

      if pattern_order_index > #pattern_order then
        -- completed: reset and stop
        pattern_order_index = 1
        pos.pattern = start_pos.pattern
        pos.line = start_pos.line

        pattern = patterns[pos.pattern]
        pattern_tracks = pattern.tracks
        pattern_track = pattern_tracks[pos.track]
        return nil

      else
        -- new pattern
        pos.pattern = pattern_order[pattern_order_index]

        pattern = patterns[pos.pattern]
        pattern_tracks = pattern.tracks
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInTrack(song, track_index, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInTrack(song, track_index, visible_only), visible_only)
end

function PakettiPatternIteratorEffectColumnsInTrack(song, track_index, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInTrack(song, track_index, visible_only), visible_only)
end

------------------------------------------------------------------------------
-- Lines in Pattern Track (Line only)
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInPatternTrack(song, pattern_index, track_index)
  assert(type(pattern_index) == 'number', ('pattern_index parameter: ' ..
    'expected an index (a number), got a \'%s\' object'):format(type(pattern_index)))
  assert(type(track_index) == 'number', ('track_index parameter: ' ..
    'expected an index (a number), got a \'%s\' object'):format(type(track_index)))

  local start_pos = { pattern = pattern_index, track = track_index, line = 1 }
  local pos = { pattern = pattern_index, track = track_index, line = 1 }

  local pattern = song.patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      -- completed: reset and stop
      pos.line = start_pos.line
      return nil

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInPatternTrack(song, pattern_index, track_index, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInPatternTrack(song, pattern_index, track_index), visible_only)
end

function PakettiPatternIteratorEffectColumnsInPatternTrack(song, pattern_index, track_index, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInPatternTrack(song, pattern_index, track_index), visible_only)
end

------------------------------------------------------------------------------
-- NEW: Lines in All Tracks (Track → Pattern → Line)
-- This iterates through ALL tracks first before moving to next pattern
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInAllTracks(song, visible_patterns_only)
  visible_patterns_only = visible_patterns_only or true
  local pattern_order = PakettiPatternIteratorBuildPatternOrder(song, visible_patterns_only)

  local track_index = 1
  local pattern_order_index = 1
  local start_pos = { pattern = pattern_order[1], track = 1, line = 1 }
  local pos = { pattern = pattern_order[1], track = 1, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]
  local num_tracks = #song.tracks

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pattern_order_index = pattern_order_index + 1

      if pattern_order_index > #pattern_order then
        -- completed all patterns for this track, move to next track
        pattern_order_index = 1
        track_index = track_index + 1

        if track_index > num_tracks then
          -- completed: reset and stop
          track_index = 1
          pattern_order_index = 1
          pos.pattern = start_pos.pattern
          pos.track = start_pos.track
          pos.line = start_pos.line

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
          return nil

        else
          -- new track
          pos.track = track_index
          pos.pattern = pattern_order[pattern_order_index]

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
        end

      else
        -- new pattern (same track)
        pos.pattern = pattern_order[pattern_order_index]

        pattern = patterns[pos.pattern]
        pattern_tracks = pattern.tracks
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInAllTracks(song, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInAllTracks(song, visible_only), visible_only)
end

function PakettiPatternIteratorEffectColumnsInAllTracks(song, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInAllTracks(song, visible_only), visible_only)
end

------------------------------------------------------------------------------
-- NEW: Lines in Sequence Order (Sequence → Line → Track)
-- Iterates exactly as patterns appear in sequencer
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInSequence(song)
  local pattern_sequence = song.sequencer.pattern_sequence
  local sequence_index = 1
  local start_pos = { sequence = 1, pattern = pattern_sequence[1], track = 1, line = 1 }
  local pos = { sequence = 1, pattern = pattern_sequence[1], track = 1, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pos.track = pos.track + 1

      if pos.track > #pattern_tracks then
        pos.track = 1
        sequence_index = sequence_index + 1

        if sequence_index > #pattern_sequence then
          -- completed: reset and stop
          sequence_index = 1
          pos.sequence = start_pos.sequence
          pos.pattern = start_pos.pattern
          pos.track = start_pos.track
          pos.line = start_pos.line

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
          return nil

        else
          -- new sequence position (allows pattern repeats)
          pos.sequence = sequence_index
          pos.pattern = pattern_sequence[sequence_index]

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
        end

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInSequence(song, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInSequence(song), visible_only)
end

function PakettiPatternIteratorEffectColumnsInSequence(song, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInSequence(song), visible_only)
end

------------------------------------------------------------------------------
-- NEW: Lines in Track Range (Pattern → Line) for specific track range
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInTrackRange(song, start_track, end_track, visible_patterns_only)
  assert(type(start_track) == 'number', 'start_track must be a number')
  assert(type(end_track) == 'number', 'end_track must be a number')
  assert(start_track <= end_track, 'start_track must be <= end_track')

  visible_patterns_only = visible_patterns_only or true
  local pattern_order = PakettiPatternIteratorBuildPatternOrder(song, visible_patterns_only)

  local pattern_order_index = 1
  local start_pos = { pattern = pattern_order[1], track = start_track, line = 1 }
  local pos = { pattern = pattern_order[1], track = start_track, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pos.track = pos.track + 1

      if pos.track > end_track then
        pos.track = start_track
        pattern_order_index = pattern_order_index + 1

        if pattern_order_index > #pattern_order then
          -- completed: reset and stop
          pattern_order_index = 1
          pos.pattern = start_pos.pattern
          pos.track = start_pos.track
          pos.line = start_pos.line

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
          return nil

        else
          -- new pattern
          pos.pattern = pattern_order[pattern_order_index]

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
        end

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInTrackRange(song, start_track, end_track, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInTrackRange(song, start_track, end_track, visible_only), visible_only)
end

function PakettiPatternIteratorEffectColumnsInTrackRange(song, start_track, end_track, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInTrackRange(song, start_track, end_track, visible_only), visible_only)
end

------------------------------------------------------------------------------
-- NEW: Lines in Pattern Range (Track → Line)
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInPatternRange(song, start_pattern, end_pattern)
  assert(type(start_pattern) == 'number', 'start_pattern must be a number')
  assert(type(end_pattern) == 'number', 'end_pattern must be a number')
  assert(start_pattern <= end_pattern, 'start_pattern must be <= end_pattern')

  local pattern_index = start_pattern
  local start_pos = { pattern = start_pattern, track = 1, line = 1 }
  local pos = { pattern = start_pattern, track = 1, line = 1 }

  local patterns = song.patterns
  local pattern = patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  start_pos.line = start_pos.line - 1
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > pattern.number_of_lines then
      pos.line = 1
      pos.track = pos.track + 1

      if pos.track > #pattern_tracks then
        pos.track = 1
        pattern_index = pattern_index + 1

        if pattern_index > end_pattern then
          -- completed: reset and stop
          pattern_index = start_pattern
          pos.pattern = start_pos.pattern
          pos.track = start_pos.track
          pos.line = start_pos.line

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
          return nil

        else
          -- new pattern
          pos.pattern = pattern_index

          pattern = patterns[pos.pattern]
          pattern_tracks = pattern.tracks
          pattern_track = pattern_tracks[pos.track]
        end

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInPatternRange(song, start_pattern, end_pattern, visible_only)
  return PakettiPatternIteratorMakeNoteColumnIter(song, 
    PakettiPatternIteratorLinesInPatternRange(song, start_pattern, end_pattern), visible_only)
end

function PakettiPatternIteratorEffectColumnsInPatternRange(song, start_pattern, end_pattern, visible_only)
  return PakettiPatternIteratorMakeEffectColumnIter(song, 
    PakettiPatternIteratorLinesInPatternRange(song, start_pattern, end_pattern), visible_only)
end

------------------------------------------------------------------------------
-- NEW: Lines in Selection (if selection exists)
------------------------------------------------------------------------------

function PakettiPatternIteratorLinesInSelection(song)
  local selection = song.selection_in_pattern
  
  if not selection then
    return nil
  end

  local start_pos = { 
    pattern = song.selected_pattern_index, 
    track = selection.start_track, 
    line = selection.start_line 
  }
  
  local pos = { 
    pattern = song.selected_pattern_index, 
    track = selection.start_track, 
    line = selection.start_line 
  }

  local pattern = song.patterns[pos.pattern]
  local pattern_tracks = pattern.tracks
  local pattern_track = pattern_tracks[pos.track]

  -- we start by increasing the line
  pos.line = pos.line - 1

  local function line_iter()
    pos.line = pos.line + 1

    if pos.line > selection.end_line then
      pos.line = selection.start_line
      pos.track = pos.track + 1

      if pos.track > selection.end_track then
        -- completed: reset and stop
        pos.track = start_pos.track
        pos.line = start_pos.line
        
        pattern_track = pattern_tracks[pos.track]
        return nil

      else
        -- new track
        pattern_track = pattern_tracks[pos.track]
      end

    else
      -- new line
    end

    return pos, pattern_track:line(pos.line)
  end

  return line_iter
end

function PakettiPatternIteratorNoteColumnsInSelection(song, visible_only)
  local line_iter = PakettiPatternIteratorLinesInSelection(song)
  if not line_iter then
    return nil
  end
  return PakettiPatternIteratorMakeNoteColumnIter(song, line_iter, visible_only)
end

function PakettiPatternIteratorEffectColumnsInSelection(song, visible_only)
  local line_iter = PakettiPatternIteratorLinesInSelection(song)
  if not line_iter then
    return nil
  end
  return PakettiPatternIteratorMakeEffectColumnIter(song, line_iter, visible_only)
end

------------------------------------------------------------------------------
-- Utility: Count Functions
------------------------------------------------------------------------------

function PakettiPatternIteratorCountNotesInSong(song, visible_only)
  local count = 0
  local iter = PakettiPatternIteratorNoteColumnsInSong(song, visible_only)
  if not iter then return 0 end
  
  for pos, column in iter do
    if not column.is_empty then
      count = count + 1
    end
  end
  
  return count
end

function PakettiPatternIteratorCountNotesInPattern(song, pattern_index, visible_only)
  local count = 0
  local iter = PakettiPatternIteratorNoteColumnsInPattern(song, pattern_index, visible_only)
  if not iter then return 0 end
  
  for pos, column in iter do
    if not column.is_empty then
      count = count + 1
    end
  end
  
  return count
end

function PakettiPatternIteratorCountNotesInTrack(song, track_index, visible_only)
  local count = 0
  local iter = PakettiPatternIteratorNoteColumnsInTrack(song, track_index, visible_only)
  if not iter then return 0 end
  
  for pos, column in iter do
    if not column.is_empty then
      count = count + 1
    end
  end
  
  return count
end

function PakettiPatternIteratorCountNotesInPatternTrack(song, pattern_index, track_index, visible_only)
  local count = 0
  local iter = PakettiPatternIteratorNoteColumnsInPatternTrack(song, pattern_index, track_index, visible_only)
  if not iter then return 0 end
  
  for pos, column in iter do
    if not column.is_empty then
      count = count + 1
    end
  end
  
  return count
end

------------------------------------------------------------------------------
-- Utility: Find Functions
------------------------------------------------------------------------------

function PakettiPatternIteratorFindFirstNoteInSong(song, visible_only)
  local iter = PakettiPatternIteratorNoteColumnsInSong(song, visible_only)
  if not iter then return nil end
  
  for pos, column in iter do
    if not column.is_empty then
      return pos, column
    end
  end
  
  return nil
end

function PakettiPatternIteratorFindLastNoteInSong(song, visible_only)
  local iter = PakettiPatternIteratorNoteColumnsInSong(song, visible_only)
  if not iter then return nil end
  
  local last_pos = nil
  local last_column = nil
  
  for pos, column in iter do
    if not column.is_empty then
      last_pos = { pattern = pos.pattern, track = pos.track, line = pos.line, column = pos.column }
      last_column = column
    end
  end
  
  return last_pos, last_column
end

function PakettiPatternIteratorFindFirstNoteInTrack(song, track_index, visible_only)
  local iter = PakettiPatternIteratorNoteColumnsInTrack(song, track_index, visible_only)
  if not iter then return nil end
  
  for pos, column in iter do
    if not column.is_empty then
      return pos, column
    end
  end
  
  return nil
end

function PakettiPatternIteratorFindLastNoteInTrack(song, track_index, visible_only)
  local iter = PakettiPatternIteratorNoteColumnsInTrack(song, track_index, visible_only)
  if not iter then return nil end
  
  local last_pos = nil
  local last_column = nil
  
  for pos, column in iter do
    if not column.is_empty then
      last_pos = { pattern = pos.pattern, track = pos.track, line = pos.line, column = pos.column }
      last_column = column
    end
  end
  
  return last_pos, last_column
end

