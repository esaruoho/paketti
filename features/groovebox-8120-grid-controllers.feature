Feature: Groovebox 8120 grid controllers (Akai MidiMix + APC Key 25 + LPD8)
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-09..11, HARDWARE-VERIFIED 2026-06-11. Two MIDI controllers drive
  # the Groovebox 8120's selected row as a step sequencer, working WHETHER OR NOT
  # the 8120 dialog is open (headless), with LED feedback + a moving playhead. Both
  # controllers share ONE source of truth (the pattern), so a change on either
  # reflects on both — true two-way sync.
  #
  # SHARED HEADLESS STEP ENGINE (PakettiEightOneTwenty.lua):
  #   • PakettiEightOneTwentyGetStepState / ToggleStepState — step note on/off; uses
  #     the dialog checkbox when the dialog is open, else writes the selected
  #     pattern's note column directly (row -> track, step -> line, ON = C-4),
  #     propagated across MAX_STEPS repeats.
  #   • PakettiEightOneTwentyGetStepYxx / ToggleStepYxx — per-step PROBABILITY via
  #     Renoise's "0Y" Maybe command; dialog yxx checkbox when open, else the
  #     pattern effect column directly. Headless probability hardware-verified
  #     2026-06-11.
  #   • paketti_8120_selected_row() — the focused row, shared by both controllers.
  #
  # AKAI MIDIMIX BRIDGE (paketti_midimix_*): 16 buttons = the focused row's 16 steps;
  #   bank L/R move the focused row; LEDs mirror step state and invert the playhead
  #   step. Stays open after the dialog closes; "Auto-Start AKAI MidiMix Bridge"
  #   (Main Menu:Options) opens it at launch. Disabled 01..16 do-nothing mappings
  #   absorb the button notes so they don't also trigger samples.
  #
  # AKAI APC KEY 25 SEQUENCER (paketti_apc_seq_*): 8x5 pad grid (note = row*8+col,
  #   note 0 = bottom-left; LED velocity 1 green / 3 red / 5 yellow). 16-step mode:
  #   top 2 rows = steps 1..16, next 2 rows = per-step probability, bottom row =
  #   select instrument/row 1..8. 32-step mode: top 4 rows = steps 1..32, bottom row
  #   selects the row. Auto-arms when the 8120 opens; "Auto-Start AKAI APC Key 25"
  #   (Main Menu:Options) arms it at launch (headless). Disabled APC 01..40 absorb
  #   the pad notes.
  #
  # AKAI LPD8 SEQUENCER (paketti_lpd8_*): the 8 pads as an 8-step sequencer for the
  #   focused row. Starting it forces MAX_STEPS=8 so the 8 pads == steps 1..8; press
  #   toggles, LED highlights on + inverts on the playhead. Pad notes vary by the
  #   LPD8's program — PAKETTI_LPD8_PAD_NOTES is editable (default 36..43) and there
  #   is an LPD8 probe (read notes + test LEDs). Disabled LPD8 01..08 absorb the pads.
  #
  # TWO-WAY SYNC: all bridges write the same pattern and re-read it on their own
  # refresh loop (MidiMix idle poller / APC + LPD8 50ms timers), so a press on one
  # controller lights up on the others, and the row selector on any follows on all.
  # Hardware-verified with MidiMix + APC plugged in together, 2026-06-11.
  #
  # WATCH: PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepState PakettiEightOneTwentyGetStepYxx PakettiEightOneTwentyToggleStepYxx PakettiEightOneTwentyAPCSeqStart PakettiEightOneTwentyMidiMixOpen PakettiEightOneTwentyAPCAutoArm
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-11  direct-commit  touched: PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepState PakettiEightOneTwentyGetStepYxx PakettiEightOneTwentyToggleStepYxx
#   2026-06-11  direct-commit  touched: PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepState

  Scenario: APC pad toggles a step on the selected row (headless)
    Given the APC Key 25 step sequencer is armed and the 8120 dialog is closed
    When the user presses a top-row pad
    Then that step toggles on the selected row's pattern
    And the pad lights green
    # @hw-verified 2026-06-11

  Scenario: APC mid-row pad toggles per-step probability (headless)
    Given the APC Key 25 step sequencer is armed and the 8120 dialog is closed
    When the user presses a probability-row pad on a step that has a note
    Then a 0Y Maybe effect is written to that step in the pattern
    And the pad lights red
    # @hw-verified 2026-06-11

  Scenario: APC bottom row selects the instrument/row
    Given the APC Key 25 step sequencer is armed
    When the user presses a bottom-row pad
    Then that row becomes the selected/focused row
    And the whole grid repaints for the new row
    # @hw-verified 2026-06-11

  Scenario: APC works headless via the Auto-Start setting
    Given "Main Menu:Options:Auto-Start AKAI APC Key 25" is enabled
    When Renoise launches or a song loads with an APC Key 25 connected
    Then the step sequencer arms without opening the 8120 dialog
    # @hw-verified 2026-06-11

  Scenario: A MidiMix press reflects on the APC and vice-versa
    Given both the MidiMix bridge and the APC sequencer are active on the same 8120
    When the user toggles a step on the MidiMix
    Then the same step lights up on the APC grid
    And selecting a different row on either controller updates both
    # @hw-verified 2026-06-11

  Scenario: LPD8 8 pads sequence the focused row's first 8 steps
    Given the LPD8 step sequencer is started
    Then the groovebox is forced to 8-step mode
    When the user presses a pad
    Then that step toggles on the selected row and the pad LED highlights it
    # @built @untested-in-renoise
