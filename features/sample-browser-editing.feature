# WHAT THIS CARD SPAWNS:
# codespace: PakettiLoadSampleBrowser.lua, tests/sample-browser-editing.lua
# thinkspace: sample-browser-editing.session.md
# areaspace: browser waveform layout, preview audio cuts, source deletion confirmation
# SESSION: sample-browser-editing.session.md
# RESULT: Working-tree implementation; no commit, push or PR.
# WATCH: plsb_set_sync plsb_start_playhead plsb_stop_playhead plsb_playhead_position plsb_wave_render plsb_apply_beatsync plsb_octave_key_delta plsb_set_playback plsb_rebuild_entries plsb_cut_selection plsb_confirm_delete_file plsb_do_load plsb_meta_string plsb_key_handler PakettiLoadSampleBrowser_Open
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: plsb_set_sync plsb_start_playhead plsb_stop_playhead plsb_playhead_position plsb_apply_beatsync plsb_octave_key_delta plsb_rebuild_entries plsb_cut_selection plsb_confirm_delete_file plsb_do_load plsb_key_handler
Feature: Edit preview audio and confirm source deletion
  @sim-verified @runtime-untested
  Scenario: Preserve selection cuts in the loaded sample
    # cite: PakettiLoadSampleBrowser.lua plsb_cut_selection plsb_do_load
    # cite: tests/sample-browser-editing.lua tests/sample-browser-loop-load.lua
    Given selected preview frames and an active loop
    When Cmd-X cuts those frames and the sample is loaded
    Then remaining audio stays in order and loop bounds shift with the cut
    And final loading uses the edited preview instead of the original file

  @sim-verified @runtime-untested
  Scenario: Confirm source file deletion
    # cite: PakettiLoadSampleBrowser.lua plsb_confirm_delete_file
    # cite: tests/sample-browser-editing.lua
    Given a selected file and the delete prompt
    When Y or Enter is pressed
    Then that file is deleted after keyboard dispatch
    When N or Escape is pressed
    Then the file stays and browsing resumes

  @built @runtime-untested
  Scenario: Keep waveform controls clear and stable
    # cite: PakettiLoadSampleBrowser.lua plsb_meta_string PakettiLoadSampleBrowser_Open
    Given a preview with or without a selection
    Then the selection metadata line remains present
    And the waveform measures 420 by 220 logical pixels
    And buttons say Selection to Loop and Clear Selection

  @sim-verified @runtime-untested
  Scenario: Retain the cursor after deleting a file
    # cite: PakettiLoadSampleBrowser.lua plsb_rebuild_entries plsb_confirm_delete_file
    # cite: tests/sample-browser-editing.lua
    Given the cursor is on a file row
    When that file is deleted
    Then the cursor stays on that row if it still exists
    And deleting row 20 of 20 selects row 19
    And an empty list has no out-of-range preview access

  @sim-verified @runtime-untested
  Scenario: Carry chosen playback quality into native imports
    # cite: PakettiLoadSampleBrowser.lua plsb_set_playback plsb_do_load
    # cite: tests/sample-browser-loop-load.lua
    Given interpolation, oversampling and autofade choices in the browser
    When the sample is imported
    Then those choices override loader defaults including explicit false values

  @built @runtime-untested
  Scenario: Adjust playback quality during preview
    # cite: PakettiLoadSampleBrowser.lua plsb_set_playback plsb_refresh PakettiLoadSampleBrowser_Open
    Given a decoded preview sample
    When an interpolation or oversampling or autofade control changes
    Then the scratch sample property changes immediately
    And UI synchronization does not record edits

  @sim-verified @runtime-untested
  Scenario: Ignore Caps Lock for octave punctuation
    # cite: PakettiLoadSampleBrowser.lua plsb_octave_key_delta plsb_key_handler
    # cite: tests/sample-browser-editing.lua
    Given Caps Lock is on or off
    When less-than or greater-than is typed
    Then the preview octave decreases or increases respectively
    And Shift on the less key increases the octave when no character is supplied

  @sim-verified @runtime-untested
  Scenario: Trim to selected audio
    # cite: PakettiLoadSampleBrowser.lua plsb_cut_selection plsb_do_load
    # cite: tests/sample-browser-editing.lua tests/sample-browser-loop-load.lua
    Given frames 3 through 7 are selected in a ten-frame preview
    When Trim Selection is pressed
    Then only frames 3 through 7 remain and loop bounds shift
    And final loading uses the edited preview audio

  @sim-verified @runtime-untested
  Scenario: Sync preview and import to song tempo
    # cite: PakettiLoadSampleBrowser.lua plsb_apply_beatsync plsb_do_load
    # cite: tests/sample-browser-editing.lua tests/sample-browser-loop-load.lua
    Given an explicit or default sync length of 16 lines
    When Texture beatsync is selected
    Then tempo sync uses 16 lines and Texture mode
    And final native loading carries the selected sync mode
    When Off is selected
    Then tempo sync is disabled

  @sim-verified @runtime-untested
  Scenario: Search recursively from the browser root
    # cite: PakettiLoadSampleBrowser.lua plsb_rebuild_entries
    # cite: tests/sample-browser-editing.lua
    Given a root with a nested folder containing kick.wav
    When Find searches for kick while browsing another folder
    Then the nested root file appears with its full path
    And scanning runs one directory per timer tick

  @built @runtime-untested
  Scenario: Change preview volume without changing imported gain
    # cite: PakettiLoadSampleBrowser.lua plsb_preview_selected PakettiLoadSampleBrowser_Open
    Given a scratch preview sample
    When Preview Volume changes
    Then only its sample volume changes
    And final imports retain loader volume settings

  @sim-verified @runtime-untested
  Scenario: Follow click playback and whole-sample loops
    # cite: PakettiLoadSampleBrowser.lua plsb_start_playhead plsb_playhead_position
    # cite: tests/sample-browser-editing.lua
    Given playback starts at frame 300 at 100 frames per second
    When two seconds pass
    Then the estimated cursor reaches frame 500
    And click slices are tracked to their end as one-shots
    And whole-sample Forward, Reverse and Ping-Pong loops are followed
    And an octave above the base note doubles frame speed

  @sim-verified @runtime-untested
  Scenario: Clean up the cursor timer
    # cite: PakettiLoadSampleBrowser.lua plsb_stop_playhead
    # cite: tests/sample-browser-editing.lua
    Given an active playback cursor
    When playback stops or the browser is no longer visible
    Then the cursor state and timer are removed

  @built @runtime-untested
  Scenario: Draw a visible waveform playback cursor
    # cite: PakettiLoadSampleBrowser.lua plsb_wave_render
    Given an estimated playback frame
    Then a white two-pixel line spans the waveform lanes above other overlays

  @sim-verified @runtime-untested
  Scenario: Set exact beatsync length independently of mode
    # cite: PakettiLoadSampleBrowser.lua plsb_set_sync plsb_apply_beatsync plsb_do_load
    # cite: tests/sample-browser-editing.lua tests/sample-browser-loop-load.lua
    Given beatsync is disabled
    When 37 lines and Texture mode are chosen and beatsync is enabled
    Then the preview uses exactly 37 lines and Texture mode
    And imports retain the exact line count
    And disabling beatsync preserves the length for re-enabling
    And line count is bounded to 1 through 512
