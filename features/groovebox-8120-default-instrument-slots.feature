Feature: Groovebox 8120 fills 8 instrument slots with the Paketti Default Instrument on empty-song open
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-09. When 8120 is opened on an EMPTY song (no real
  # instruments), it creates the 8 instrument slots (rows 01-08) and loads the
  # Paketti Default Instrument into each, so the groovebox is ready to play.
  #
  # IMPORTANT (clarified by Esa 2026-06-09): this fires ONLY from the 8120
  # dialog-open path — NOT on "Load New Song". There is deliberately no
  # app_new_document_observable hook. Opening 8120 on a fresh/empty song is the
  # only trigger.
  #
  # INNARDS (PakettiEightOneTwenty.lua):
  #   • PakettiEightOneTwentyInitializeDefaultSlots() — called at the TOP of
  #     pakettiEightSlotsByOneTwentyDialog(), before ensure_instruments_exist().
  #     Guards: (1) preference pakettiEightOneTwentyAutoFillDefaultSlots (default
  #     true, declared in Paketti0G01_Loader.lua); (2) empty-song check —
  #     #instruments == 1 AND that instrument is empty (no samples, no plugin).
  #     For i=1..8: ensure slot exists (safeInsertInstrumentAt), select it,
  #     pakettiPreferencesDefaultInstrumentLoader().
  #   • Self-resetting: once 8 slots are filled the song is no longer "empty", so
  #     reopening 8120 never re-fires; and it never overwrites an existing song.
  #   • Toggle: Main Menu:Tools:Paketti:Groovebox:Toggle Auto-Fill Default
  #     Instrument Slots (empty song); keybinding Global:Paketti:Groovebox 8120
  #     Toggle Auto-Fill Default Slots → PakettiEightOneTwentyToggleAutoFillDefaultSlots.
  #
  # WATCH: PakettiEightOneTwentyInitializeDefaultSlots pakettiEightOneTwentyAutoFillDefaultSlots PakettiEightOneTwentyToggleAutoFillDefaultSlots
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-09  direct-commit  touched: PakettiEightOneTwentyInitializeDefaultSlots pakettiEightOneTwentyAutoFillDefaultSlots PakettiEightOneTwentyToggleAutoFillDefaultSlots

  Scenario: Opening 8120 on an empty song fills all 8 slots with the default instrument
    Given the song is empty (a single empty instrument, no samples or plugin)
    And the pakettiEightOneTwentyAutoFillDefaultSlots preference is ON
    When the user opens Groovebox 8120
    Then the Paketti Default Instrument is loaded into instrument slots 1 through 8 (rows 01-08)
    And the slots are ready to be used
    # @built @untested-in-renoise

  Scenario: Opening 8120 on a song that already has instruments leaves them untouched
    Given the song already contains instruments (not the empty fresh-song state)
    When the user opens Groovebox 8120
    Then the existing instruments are not overwritten
    And the auto-fill does not run
    # @built @untested-in-renoise

  Scenario: New Song never triggers the auto-fill
    Given a song is loaded or created while 8120 is closed
    When a New Song is created in Renoise
    Then no instruments are armed or replaced by 8120
    And the auto-fill happens only when 8120 is next opened on an empty song
    # @built @untested-in-renoise
