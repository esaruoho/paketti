# WIKI PAGE / REPORT CARD: Preserve duplicated instrument devices
# WHAT THIS CARD SPAWNS:
# codespace — PakettiSamples.lua helper and both track/instrument duplication commands
# thinkspace — duplicate-instrument-devices.session.md
# areaspace — OWNS copied DSP presets, names and instrument targets; excludes clean duplication behavior
# SESSION: duplicate-instrument-devices.session.md
# RESULT: Worktree implementation; no commit, push or PR. Card authored in worktree.
# Files: PakettiSamples.lua, PakettiRequests.lua, tests/duplicate-instrument-devices.lua, PLAN.md and this card/session bundle
# WATCH: PakettiCopyDuplicatedInstrumentDevice duplicateTrackAndInstrumentCore duplicateTrackDuplicateInstrument
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: PakettiCopyDuplicatedInstrumentDevice
Feature: Preserve devices when duplicating a track and instrument
  @code-verified @runtime-untested
  Scenario: Bind Instrument Macros from 0B to 0C
    # cite: PakettiSamples.lua PakettiCopyDuplicatedInstrumentDevice; tests/duplicate-instrument-devices.lua
    Given the source instrument is 0B
    When its track and instrument are duplicated to 0C
    Then the copied Instrument Macros binds to selected instrument 0C
    And the source selector remains 0B

  @code-verified @runtime-untested
  Scenario: Preserve the wavetable LFO identity and setup
    # cite: PakettiSamples.lua PakettiCopyDuplicatedInstrumentDevice; tests/duplicate-instrument-devices.lua
    Given an LFO named Wavetable Mod *LFO with preset routing
    When either track and instrument duplication command copies it
    Then the duplicate retains its display name and complete preset
    And parameter values, mixer flags and maximized state are copied

  @code-verified @runtime-untested
  Scenario: Retain instrument automation retargeting
    # cite: PakettiRequests.lua duplicateTrackDuplicateInstrument; PakettiSamples.lua PakettiCopyDuplicatedInstrumentDevice
    Given an Instrument Automation device targeting 0B
    When the track and instrument are duplicated to 0C
    Then its preset targets 0C
    And device order and custom name are preserved

  @code-verified @runtime-verified
  Scenario: Preserve normalized macro values when binding to a duplicate
    # cite: PakettiSamples.lua PakettiCopyDuplicatedInstrumentDevice; tests/duplicate-instrument-devices.lua
    Given PitchBend is a normalized macro parameter with range 0 to 1
    When copying devices for instrument 0D
    Then no instrument number is assigned to PitchBend
    And a live copied Macros device exposes the target instrument's distinct macro name
