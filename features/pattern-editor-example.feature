Feature: Pattern Editor note manipulation
Context: Pattern Editor

  # This is the shape: a Context: line (or the context's name in the title) wires
  # this feature to the Pattern Editor binding-tree node. Drop more like it.

  Scenario: Replicate the current row down the pattern
    Given the cursor is on a note in the Pattern Editor
    When the user triggers Paketti Replicate at Cursor
    Then the row content is duplicated downward from the cursor

  Scenario: Toggle the Pattern Matrix
    Given a song is loaded
    When the user triggers Show/Hide Pattern Matrix
    Then the Pattern Matrix panel visibility toggles
