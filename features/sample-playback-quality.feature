# WIKI PAGE / REPORT CARD: Checked sample playback quality controls
# WHAT THIS CARD SPAWNS:
# codespace: PakettiTkna.lua and tests/sample-playback-quality.lua
# thinkspace: sample-playback-quality.session.md and manual/NativeSampleDefaults.md
# areaspace: manual sample interpolation/oversampling; no automatic native-import edits.
# SESSION: sample-playback-quality.session.md
# RESULT: Local working-tree change; no commit, push or PR.
# Files: source, tests, native-default design document, plan, changelog, card and session bundle.
# WATCH: PakettiSampleQualityTargets PakettiSampleQualityChange
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: PakettiSampleQualityTargets PakettiSampleQualityChange
Feature: Show and change sample playback quality
  @sim-verified @runtime-untested
  Scenario: Checked menus describe the complete target scope
    # cite: PakettiTkna.lua PakettiSampleQualityTargets
    Given samples with uniform or mixed interpolation and oversampling settings
    When I inspect Tools, Sample List, Sample Editor or Instrument Box quality menus
    Then a mode is checked only if every target shares it
    And Oversampling is checked only if every target is enabled
    And every selected callback returns a strict boolean including empty scopes

  @sim-verified @runtime-untested
  Scenario: Cycle and toggle sample, instrument or song
    # cite: PakettiTkna.lua PakettiSampleQualityChange
    Given a selected sample, instrument or whole song scope
    When I cycle interpolation
    Then all targets advance from the first target's mode with Sinc wrapping to None
    When I toggle oversampling
    Then all targets turn off if all were on and otherwise all turn on
    And repeated key events and non-trigger MIDI messages do nothing
    And unrelated sample fields are preserved

  @built @runtime-untested
  Scenario: Native import detection is a proposal only
    # cite: manual/NativeSampleDefaults.md
    Given the documented native import detector design
    When I load or record audio through Renoise
    Then these new manual controls do not automatically change that audio's settings

  @sim-verified @runtime-untested
  Scenario: Quality menus are flat and ordered
    # cite: PakettiTkna.lua add_scope
    Given the Sample Playback Quality menu
    When I view its entries
    Then current-instrument modes appear directly as 00 None, 01 Linear, 02 Cubic, 03 Sinc
    And sample and song actions identify their scope without another submenu
    And the first Whole Song mode carries a -- separator prefix
    And Oversampling stays in the same block as its interpolation controls
    And the advancing action is named Interpolation (Next)
