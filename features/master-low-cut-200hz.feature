Feature: Master Low-Cut 200Hz punch toggle
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-09, HARDWARE-VERIFIED 2026-06-11. A one-button "punch it in, punch
  # it off" high-pass at 200Hz on the master track for live low-end drops.
  #
  # INNARDS (PakettiEightOneTwenty.lua):
  #   • PakettiToggleMasterLowCut200 / PakettiMasterLowCut200SetState(active) —
  #     inserts a native Digital Filter on the master and injects the proven
  #     "Hipass (Preset++)" XML (Biquad model, Type Value 3 = HIGH PASS), then
  #     raises Cutoff to ~200Hz by reading the parameter's value_string back. The
  #     device is tagged by display name ("Paketti LowCut 200Hz") so toggling off
  #     removes exactly that device and nothing else.
  #   • PakettiMasterLowCut200Momentary(message) — momentary "Hold": the high-pass
  #     is active while the controller button is held and off the moment it's
  #     released (reads the button value, so it catches both press and release).
  #
  # First version wrongly used the analog Filter device in Low Pass mode; fixed to
  # the Digital Filter Biquad high-pass.
  #
  # WATCH: PakettiToggleMasterLowCut200 PakettiMasterLowCut200SetState PakettiMasterLowCut200Momentary
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)

  Scenario: Punch in the low-cut
    Given the song is playing
    When the user triggers "Paketti:Master Low-Cut 200Hz Toggle"
    Then a Digital Filter high-pass at ~200Hz is added to the master track
    And everything below 200Hz is filtered out
    # @hw-verified 2026-06-11

  Scenario: Punch it off
    Given the master low-cut is active
    When the user triggers "Paketti:Master Low-Cut 200Hz Toggle"
    Then the tagged high-pass device is removed and the low end returns
    # @hw-verified 2026-06-11

  Scenario: Momentary hold
    Given the song is playing
    When the user holds a button mapped to "Paketti:Master Low-Cut 200Hz Hold"
    Then the high-pass is active while held and removed on release
    # @hw-verified 2026-06-11
