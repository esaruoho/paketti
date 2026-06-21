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
  #   select instrument/row 1..8. 32-step mode (follow OFF): top 4 rows = steps 1..32,
  #   bottom row selects the row. 32-step mode (follow ON): the paged 16-steps +
  #   16-probability layout returns and pages across the pattern (page 0 = 1..16,
  #   page 1 = 17..32), so probability is editable at 32 steps too. Auto-arms when
  #   the 8120 opens; "Auto-Start AKAI APC Key 25" (Main Menu:Options) arms it at
  #   launch (headless). Disabled APC 01..40 absorb the pad notes.
  #
  # FOLLOW WITH CONTROLLER (PER-CONTROLLER, independent): three checkboxes in the
  #   8120 dialog under a "Ctrl Follow:" label — APC / MM / LPD8 — each backed by its
  #   own persisted preference (pakettiGroovebox8120FollowAPC / ...FollowMidiMix /
  #   ...FollowLPD8, all off by default). When a controller's follow is ON it pages
  #   its step view to track the playhead through a 32-step pattern — MidiMix's 16
  #   LEDs window steps 1-16 / 17-32, the APC switches to its paged 16+16 layout, the
  #   LPD8 snaps its page. They are INDEPENDENT: e.g. APC left off ("non-rotating",
  #   all 32 steps shown) while MidiMix/LPD8 follow. Each has its own setter
  #   (PakettiEightOneTwenty{APC,MidiMix,LPD8}SetFollow) + accessor
  #   (paketti_{apc,midimix,lpd8}_follow_enabled, read live by that controller's
  #   refresh). Each controller's "Toggle Follow Page" keybinding/MIDI/menu entry
  #   toggles only that controller and stays in sync with its own checkbox. Arming a
  #   controller reads its own saved pref, so each follows (or not) headlessly after
  #   a restart. Manual Next/Previous Page still browses; while following + playing,
  #   the window re-snaps on the next refresh. @built 2026-06-12 (not yet hw-verified).
  #
  # AKAI LPD8 SEQUENCER (paketti_lpd8_*): the 8 pads sequence the focused row. It
  #   does NOT force a step mode — its 8 pads PAGE over the current 8/16/32-step
  #   pattern (Next/Prev Page, an absolute Select-Page knob, or Follow mode that
  #   tracks the playhead). A 4-steps+4-probability layout puts steps on the top row
  #   and their yxx on the bottom row. Pad notes editable (PAKETTI_LPD8_PAD_NOTES,
  #   default 36..43 top-first); LPD8 probe confirms. Disabled LPD8 01..08 absorb the
  #   pads. Full detail in features/groovebox-8120-lpd8.feature.
  #
  # TWO-WAY SYNC: all bridges write the same pattern and re-read it on their own
  # refresh loop (MidiMix idle poller / APC + LPD8 50ms timers), so a press on one
  # controller lights up on the others, and the row selector on any follows on all.
  # Hardware-verified with MidiMix + APC plugged in together, 2026-06-11.
  #
  # WATCH: PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepState PakettiEightOneTwentyGetStepYxx PakettiEightOneTwentyToggleStepYxx PakettiEightOneTwentyAPCSeqStart PakettiEightOneTwentyMidiMixOpen PakettiEightOneTwentyAPCAutoArm PakettiEightOneTwentyAPCSetFollow PakettiEightOneTwentyMidiMixSetFollow PakettiEightOneTwentyLPD8SetFollow PakettiEightOneTwentyMidiMixNextPage PakettiEightOneTwentyAPCNextPage
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-22  direct-commit  touched: PakettiEightOneTwentyAPCSeqStart PakettiEightOneTwentyMidiMixNextPage PakettiEightOneTwentyAPCNextPage
#   2026-06-12  direct-commit  touched: PakettiEightOneTwentyAPCSetFollow PakettiEightOneTwentyMidiMixSetFollow PakettiEightOneTwentyLPD8SetFollow
#   2026-06-11  direct-commit  touched: PakettiEightOneTwentyGetStepState PakettiEightOneTwentyToggleStepState
#   2026-06-11  direct-commit  touched: PakettiEightOneTwentyAPCSeqStart
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

  Scenario: LPD8 pages its 8 pads over the focused row (no forced step mode)
    Given the LPD8 step sequencer is started in any step mode
    When the user presses a pad
    Then that step toggles on the selected row and the pad LED highlights it
    # Detail (pages, follow, 4+4, row-select): features/groovebox-8120-lpd8.feature
    # @hw-verified 2026-06-11

  Scenario: Follow is per-controller and independent
    Given the 8120 dialog is open
    When the user ticks the MidiMix follow checkbox but leaves the APC follow checkbox off
    Then preference pakettiGroovebox8120FollowMidiMix is set true and saved
    And pakettiGroovebox8120FollowAPC stays false
    And the MidiMix tracks the playhead while the APC keeps showing all its steps (non-rotating)
    # @built 2026-06-12  # code-complete; not yet hardware-verified

  Scenario: Each controller's follow persists and applies headlessly on the next session
    Given a controller's own follow preference was left on in a previous session
    When that controller arms (dialog open, or via its Auto-Start setting)
    Then it reads its own saved preference and follows the playhead without any dialog action
    # @built 2026-06-12  # code-complete; not yet hardware-verified

  Scenario: APC follow restores the 16+16 paged layout at 32 steps
    Given the 8120 is in 32-step mode and the APC sequencer is armed
    When the APC follow checkbox is on
    Then the APC shows 16 steps + 16 probability for the current page (not all 32 steps)
    And the page snaps to the playhead during playback (page 0 = 1..16, page 1 = 17..32)
    # @built 2026-06-12  # code-complete; not yet hardware-verified

  Scenario: APC left non-rotating shows every step at 32 steps
    Given the 8120 is in 32-step mode and the APC sequencer is armed
    When the APC follow checkbox is off
    Then all 32 steps are shown across the top four pad rows and the grid never pages
    # @built 2026-06-12  # code-complete; not yet hardware-verified

  Scenario: MidiMix follow windows its 16 LEDs over a 32-step pattern
    Given the 8120 is in 32-step mode and the MidiMix bridge is open
    When the MidiMix follow checkbox is on and the transport is playing
    Then the 16 LEDs page between steps 1-16 and 17-32 to keep the playhead visible
    # @built 2026-06-12  # code-complete; not yet hardware-verified

  Scenario: A controller's follow keybinding stays in sync with its own checkbox
    Given the 8120 dialog is open with the LPD8 follow checkbox off
    When the user triggers "Global:Paketti:Paketti Groovebox 8120 LPD8 Toggle Follow Page"
    Then only the LPD8 follow turns on (APC and MidiMix are unaffected)
    And the LPD8 follow checkbox updates to checked
    # @built 2026-06-12  # code-complete; not yet hardware-verified
