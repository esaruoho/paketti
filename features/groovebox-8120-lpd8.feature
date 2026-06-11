Feature: Groovebox 8120 — AKAI LPD8 controller (8 pads + pages + follow + row select)
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-11. The AKAI LPD8 (8 pads, notes 36..43, ordered top-row-first)
  # drives the Groovebox 8120's selected row as a step sequencer. Because the LPD8
  # only has 8 pads, a PAGE offset windows the 8 pads over a 16- or 32-step pattern,
  # and a FOLLOW mode auto-flips the page to track the playhead. Everything reads/
  # writes the selected pattern directly, so it all works with the 8120 dialog open
  # OR closed (headless), and cross-syncs with the MidiMix/APC.
  #
  # INNARDS (PakettiEightOneTwenty.lua, paketti_lpd8_*):
  #   • paketti_lpd8_pad_target(pad) — maps a pad to a ("step"|"prob", index) using
  #     paketti_lpd8_page + paketti_lpd8_mode.
  #   • mode "steps": 8 steps/page (page 0 = 1-8, 1 = 9-16, 2 = 17-24, 3 = 25-32).
  #   • mode "stepsprob": top 4 pads = 4 steps, bottom 4 pads = those steps'
  #     probability (0Y Maybe); a page covers 4 steps.
  #   • paketti_lpd8_seq_refresh / _on_midi — LED highlight + pad-press toggle via the
  #     shared PakettiEightOneTwentyGet/ToggleStepState + Get/ToggleStepYxx engine.
  #   • Follow: refresh snaps paketti_lpd8_page to the playhead's page each tick.
  #   • PakettiEightOneTwentySelectRowByValue(v, reversed) — 0..127 -> row 1..8, with
  #     three independently-bindable copies each of 01-08 and 08-01.
  #
  # WATCH: PakettiEightOneTwentyLPD8SeqStart PakettiEightOneTwentyLPD8NextPage PakettiEightOneTwentyLPD8ToggleFollow PakettiEightOneTwentyLPD8ToggleProbMode PakettiEightOneTwentySelectRowByValue PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepYxx
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-11  direct-commit  touched: PakettiEightOneTwentyLPD8NextPage PakettiEightOneTwentyLPD8ToggleFollow PakettiEightOneTwentyLPD8ToggleProbMode PakettiEightOneTwentySelectRowByValue PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepYxx

  Scenario: 8 pads sequence the selected row (headless)
    Given the LPD8 step sequencer is started
    When the user presses a pad
    Then the corresponding step toggles on the selected row and the pad LED follows
    # @built @untested-in-renoise

  Scenario: Do-nothing absorbers keep the pads from triggering samples
    Given the 8 "Disabled LPD8 01".."Disabled LPD8 08" MIDI mappings exist
    When the user maps each LPD8 pad to one in Renoise MIDI Map mode
    Then pressing a pad sequences the row without also playing a sample
    # @built @untested-in-renoise

  Scenario: Flip a page through a 16/32-step pattern
    Given the groovebox is in 16- or 32-step mode and the LPD8 sequencer is on
    When the user triggers "LPD8 Next Page"
    Then the 8 pads show the next 8 steps (1-8 -> 9-16 -> 17-24 -> 25-32, wrapping)
    # @built @untested-in-renoise

  Scenario: Follow mode tracks the playhead across pages
    Given the LPD8 follow-page mode is ON
    When playback crosses from steps 1-8 into 9-16
    Then the LPD8 auto-flips to the page showing 9-16, then back for 1-8
    # @built @untested-in-renoise

  Scenario: 4 steps + 4 probability layout
    Given the user triggers "LPD8 Toggle 4Steps+4Probability Layout"
    Then the top 4 pads edit 4 steps and the bottom 4 pads edit those steps' probability
    And paging then advances 4 steps at a time
    # @built @untested-in-renoise

  Scenario: Select the row with a single knob (three bindable copies)
    Given a knob is mapped to "Select Row (Knob 01-08) 1st Bind" (or 2nd/3rd, or the 08-01 reverse)
    When the user sweeps the knob 0..127
    Then the selected/focused row walks 1..8 (or 8..1), setting that row's track + instrument
    # @built @untested-in-renoise
