# WHAT THIS CARD SPAWNS:
# codespace: PakettiMicrotonalTunings.lua golden chords/scales/cadences/circle/passing + tests/golden-chords.lua; PakettiArpeggiator.lua golden modes
# thinkspace: golden-chord-corrections.session.md and bundled transcript; Research/golden-harmony-chapter-by-chapter.md
# areaspace: golden chord/scale/progression tools + Arpeggiator golden modes; other tuning and waveform tools unchanged
# SESSION: golden-chord-corrections.session.md
# RESULT: see RESULT-LOG. Files: PakettiMicrotonalTunings.lua, PakettiArpeggiator.lua, tests/golden-chords.lua, manual/CHANGESLOG.md, manual/Experimental.md, this card.
# WATCH: get_golden_chords golden_chain_steps generate_silver13 golden_cadences PakettiInsertGoldenCircle PakettiInsertGoldenPassing PakettiArp_GenerateScale PakettiArp_ResolveNoteValue PakettiApply36EDOToInstrument
# RESULT-LOG >>
#   2026-10-22  direct-commit  touched: PakettiArp_ResolveNoteValue PakettiApply36EDOToInstrument
#   2026-10-22  direct-commit  touched: get_golden_chords golden_chain_steps generate_silver13 golden_cadences PakettiInsertGoldenCircle PakettiInsertGoldenPassing
#   2026-10-22  direct-commit  touched: PakettiArp_GenerateScale PakettiArp_ResolveNoteValue PakettiApply36EDOToInstrument (golden modes in Arpeggiator)
Feature: Golden harmony per David Chester (Music Theory of Golden Harmony, 36-EDO)
  # Source analysis: Research/golden-harmony-chapter-by-chapter.md (full-book read).

  @code-verified
  Scenario: Canonical golden chords (ch. 25)
    # cite: PakettiMicrotonalTunings.lua get_golden_chords insert_golden_chord
    Given David's four canonical chords in 36-EDO
    When the chord library is built
    Then it contains Golden Triad {0,11,22}, Golden Seventh {0,11,22,33}, Silver Triad {0,10,20} and Bronze Triad {0,13,26}
    And the Silver triad (major+minor+diminished)/3 replaces the earlier non-canonical "Golden Minor (Reflected)"
    And insertion tunes the selected instrument to 36-EDO and rounds each cents value to a 36-EDO degree
    And lua tests/golden-chords.lua verifies both insertion callbacks with a mocked host

  @code-verified
  Scenario: Well-formed golden scales (ch. 23/36)
    # cite: PakettiMicrotonalTunings.lua golden_chain_steps generate_golden_mos_scale generate_silver13
    Given the golden sixth (25 sixth-steps) stacked into consecutive chain windows containing the tonic golden triad
    When the scale presets are generated
    Then Golden-7 is {0,3,11,14,22,25,33}, Golden-10 {0,3,8,11,14,17,22,25,28,33}, Golden-13 {0,3,6,8,11,14,17,19,22,25,28,30,33}
    And Golden-4 is {0,11,22,25} and Silver-13 is the layer mirror {0,3,6,10,13,16,17,19,20,23,26,30,33}
    And each matches David's printed note sets exactly (verified by computation)

  @built @runtime-untested
  Scenario: Golden cadences, golden circle and golden passing chords (ch. 27/29/31)
    # cite: PakettiMicrotonalTunings.lua golden_cadences PakettiInsertGoldenCircle golden_passing_pair PakettiInsertGoldenPassing
    Given the selected line as the first chord position
    When a golden cadence, a golden-circle walk, or a golden passing pair is inserted
    Then successive lines receive the 36-EDO chords and the instrument is tuned to 36-EDO
    And the golden circle steps the triad root by a golden third (11 steps), keeping two common tones
    And the passing chords between X and Y are the voice-wise averages (2X+Y)/3 and (X+2Y)/3
    # Runtime in Renoise not driven this session (PakettiMCP offline); logic unit-shape verified only.

  @code-verified @runtime-untested
  Scenario: Golden harmony scales in the Arpeggiator (ch. 23/25/36)
    # cite: PakettiArpeggiator.lua PakettiArp_GenerateScale PakettiArp_ResolveNoteValue PakettiArp_IsGoldenMode PakettiArp_EnsureGoldenTuning; PakettiMicrotonalTunings.lua PakettiApply36EDOToInstrument
    Given the Arpeggiator Mode dropdowns list Golden, Golden-10, Golden Chromatic and Silver alongside the 12-TET modes
    When a golden mode builds its scale
    Then each degree is in 36-EDO steps and is harmonised with the golden triad {0,11,22} (silver mode uses {0,10,20})
    And PakettiArp_ResolveNoteValue anchors a golden note at octave_base*12 + degree + rel_octave*36, clamped to 0..119
    And the tonic golden triad at octave base 4 resolves to note_values 48, 59, 70 and the silver tonic to 48, 58, 68
    And the plain 12-TET modes are unchanged (C Ionian tonic stays 48, 52, 55) and key-detection skips golden modes
    And auditioning or writing a golden arp auto-applies 36-EDO to the selected instrument (idempotent)
    And luajit over the real PakettiArpeggiator.lua source verifies the note_values, octave wrap and 12-TET regression
    # Live Renoise audition/write not driven this session (PakettiMCP offline); note_value math is code-verified.
