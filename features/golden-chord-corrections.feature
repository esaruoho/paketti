# WHAT THIS CARD SPAWNS:
# codespace: PakettiMicrotonalTunings.lua golden chord library and tests/golden-chords.lua
# thinkspace: golden-chord-corrections.session.md and bundled transcript
# areaspace: golden chord definitions and insertion; other tuning and waveform tools unchanged
# SESSION: golden-chord-corrections.session.md
# RESULT: Worktree changes only; no commit, push or PR. Files: PakettiMicrotonalTunings.lua, tests/golden-chords.lua, PLAN.md, this card/session/bundle, INDEX.md and generated views.
# WATCH: get_golden_chords insert_golden_chord show_golden_chord_dialog
# RESULT-LOG >>
Feature: Insert corrected golden chords in 36-EDO
  @code-verified @runtime-untested
  Scenario: Match David's averaged major chord
    # cite: PakettiMicrotonalTunings.lua get_golden_chords insert_golden_chord
    Given a common-root pitchwise mean of major, minor and augmented triads
    When Golden Major is inserted
    Then its offsets are 0, 11 and 22 degrees of 36-EDO
    And the selected instrument is tuned to 36-EDO

  @code-verified @runtime-untested
  Scenario: Define reflected minor and distinct sixth pitches
    # cite: PakettiMicrotonalTunings.lua get_golden_chords
    Given the exact stacked golden thirds at t and 2t cents
    When the chord definitions are built
    Then Golden Minor (Reflected) contains 0, 1200-2t and 1200-t cents
    And Golden Sixth contains 0, t, 2t and 1200 log2(phi) cents
    And all pitches remain distinct after 36-EDO quantization

  @code-verified @runtime-untested
  Scenario: Preserve microtonal offsets in both insertion commands
    # cite: PakettiMicrotonalTunings.lua insert_golden_chord show_golden_chord_dialog
    Given either single or successive-line insertion
    When each cents interval is written
    Then it is rounded to a 36-EDO degree rather than a semitone
    And lua tests/golden-chords.lua verifies both callbacks with a mocked host
