# WHAT THIS CARD SPAWNS:
# codespace: PakettiEightOneTwenty.lua live label helpers, timer hookup and checkbox; Paketti0G01_Loader.lua preference
# thinkspace: 8120-live-sample-names.session.md and transcript bundle
# areaspace: sample-name display experiment only; preserve sample selection, gates, mappings and pattern data
# SESSION: 8120-live-sample-names.session.md
# RESULT: Worktree delivery; no commit, push or PR. Files: PakettiEightOneTwenty.lua, Paketti0G01_Loader.lua, PLAN.md, card/session/bundle and generated views.
# WATCH: PakettiEightOneTwentyLiveSampleIndex PakettiEightOneTwentyUpdateLiveSampleName PakettiEightOneTwentyUpdatePlayheadHighlights pakettiEightOneTwentyLivePerStepNames
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: PakettiEightOneTwentyLiveSampleIndex PakettiEightOneTwentyUpdateLiveSampleName PakettiEightOneTwentyUpdatePlayheadHighlights pakettiEightOneTwentyLivePerStepNames
Feature: Follow the Groovebox step highlighter with sample names
  @code-verified @runtime-untested
  Scenario: Show the highlighted Per-Step sample name
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyLiveSampleIndex and PakettiEightOneTwentyUpdateLiveSampleName
    Given Per-Step mode and Live Step Names are enabled
    When the row's highlighter reaches a displayed step
    Then the wide button shows that step's sample name from the row instrument
    And inactive steps also show their chosen sample
    And unnamed or missing samples display Sample followed by their number
    And long names retain the existing 50-character display limit
    And unchanged names do not cause repeated text assignments
    And editing the current step updates its name without moving the highlighter
    And song selection and step gates remain unchanged

  @built @runtime-untested
  Scenario: Experiment starts enabled and is reversible
    # cite: Paketti0G01_Loader.lua pakettiEightOneTwentyLivePerStepNames
    # cite: PakettiEightOneTwenty.lua live_sample_names_checkbox and PakettiEightOneTwentyApplyStepMode
    Given a user has no saved choice for Live Step Names
    When the Groovebox opens
    Then the Live Step Names checkbox is checked
    When the user disables it or switches to Single mode
    Then normal sample labels are restored immediately
    And the checkbox choice is saved as a boolean preference

  @code-verified @runtime-untested
  Scenario: Follow the existing highlighter's timing
    # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyUpdatePlayheadHighlights
    Given playback is running or stopped
    When the existing highlighter updates from playback or the editing cursor
    Then sample names follow the same displayed step index
    And a window with no highlighted step restores the normal label
