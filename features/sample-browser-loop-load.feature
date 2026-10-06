# WHAT THIS CARD SPAWNS:
# codespace: PakettiLoadSampleBrowser.lua, PakettiWavCueExtract.lua, tests/sample-browser-loop-load.lua
# thinkspace: sample-browser-loop-load.session.md
# areaspace: native preview-loop loading and WAV cue import threshold
# SESSION: sample-browser-loop-load.session.md
# RESULT: Local working-tree fix; no commit, push or PR.
# Files: the two Lua sources, regression test, PLAN.md, this card and session bundle.
# WATCH: plsb_do_load PakettiWavCueImportWavWithCuesIntoSample
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: plsb_do_load PakettiWavCueImportWavWithCuesIntoSample
Feature: Preserve preview loops and reject single-cue slicing
  @sim-verified @runtime-untested
  Scenario: Load the exact preview loop
    # cite: PakettiLoadSampleBrowser.lua plsb_do_load
    # cite: tests/sample-browser-loop-load.lua
    Given a Ping-Pong preview loop from frame 3 to frame 6
    When the WAV is loaded
    Then cue slicing is bypassed and loader defaults are overridden with that loop
    And no slice markers are inserted

  @sim-verified @runtime-untested
  Scenario: A single cue does not define slices
    # cite: PakettiWavCueExtract.lua PakettiWavCueImportWavWithCuesIntoSample
    # cite: tests/sample-browser-loop-load.lua
    Given a WAV with zero or one cue point
    When imported through the cue loader
    Then the sample loads normally without slice markers

  @sim-verified @runtime-untested
  Scenario: Keep deliberate multi-cue imports
    # cite: PakettiLoadSampleBrowser.lua plsb_do_load
    Given no active preview loop
    When a WAV with multiple cues is loaded
    Then the existing cue importer remains in use
