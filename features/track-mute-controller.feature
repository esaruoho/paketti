# WHAT THIS CARD SPAWNS:
# codespace: PakettiTrackMuteController.lua; main.lua; tests/track_mute_controller.lua
# thinkspace: track-mute-controller.session.md and bundled transcripts
# areaspace: MIDI pad mute bridge and two dialogs; preserve keyboard and knob mappings.
# SESSION: track-mute-controller.session.md
# RESULT: Working tree, no commit or PR. Runtime and MPK hardware unverified.
# Files: PakettiTrackMuteController.lua, PakettiEightOneTwenty.lua, main.lua,
#        tests/track_mute_controller.lua, manual/TrackMuteController.md, PLAN.md, report-card files.
# WATCH: PakettiTrackMuteControllerDialog PakettiTrackMuteModesDialog PakettiTrackMute
# RESULT-LOG >>
#   2026-10-18  direct-commit  touched: PakettiTrackMuteControllerDialog PakettiTrackMuteModesDialog PakettiTrackMute

Feature: Control track mutes with pads and synchronized feedback

  @built @runtime-untested @hw-untested
  Scenario: Configure the controller and open the highlighted performance dialog
    # cite: PakettiTrackMuteController.lua PakettiTrackMuteControllerDialog PakettiTrackMuteModesDialog
    Given the user opens Track Mute Controller from Tools Paketti Controllers
    When they choose MIDI ports, channels, pad numbers and LED values
    Then Start opens the bridge with saved settings
    And Track Mute Modes shows green active tracks and red muted tracks
    And clicking a track toggles its actual mute state

  @sim-verified @runtime-untested @hw-untested
  Scenario: Every hardware-toggle tap toggles a mute
    # cite: PakettiTrackMuteController.lua M.on_midi
    # cite: tests/track_mute_controller.lua
    Given hardware toggle input is selected
    When pads alternate positive Note On and Note Off or nonzero and zero CC
    Then both alternating edges toggle the track
    And repeated messages in the same state do not toggle twice

  @sim-verified @runtime-untested @hw-untested
  Scenario: Momentary releases do not toggle tracks
    # cite: PakettiTrackMuteController.lua M.on_midi
    Given momentary input and toggle mute mode
    When a pad is pressed and released
    Then its track toggles once
    And notes on other channels and Master tracks are ignored

  @sim-verified @runtime-untested @hw-untested
  Scenario: External mute changes repaint host-controlled LEDs
    # cite: PakettiTrackMuteController.lua M.refresh
    Given LED output is enabled on a controller supporting the configured protocol
    When another action changes a track mute state
    Then the next refresh sends its configured active or muted LED value
    And unchanged states do not send redundant messages
    And no MPK model is declared compatible without a hardware test

  @sim-verified @runtime-untested
  Scenario: Held mutes restore on release or stop
    # cite: PakettiTrackMuteController.lua restore_held M.stop M.on_midi
    Given Hold to mute or Hold to enable is selected
    When the user releases a pad or stops the bridge
    Then the original state of each held track is restored
    And Stop closes MIDI devices and removes the bridge timer

  @built @runtime-untested @hw-untested
  Scenario: A step bridge and a mute bridge relinquish the same controller
    # cite: PakettiTrackMuteController.lua M.start M.release_family
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyMidiMixOpen PakettiEightOneTwentyAPCSeqStart PakettiEightOneTwentyLPD8SeqStart
    Given an APC, MIDImix or LPD8 is owned by an 8120 step bridge
    When the mute bridge starts on that controller
    Then the old step bridge is stopped before opening MIDI
    And starting its step bridge again stops the mute bridge
