# WHAT THIS CARD SPAWNS:
# codespace: PakettiPatternMatrix.lua duplication variants; PakettiMenuConfig.lua exposure
# thinkspace: pattern-matrix-duplicate-x.session.md and bundled transcripts
# areaspace: duplicate according to selected sequence Matrix mutes; preserve legacy actions
# SESSION: pattern-matrix-duplicate-x.session.md
# RESULT: Worktree implementation; no commit, push or PR made. Files: PakettiPatternMatrix.lua, PakettiMenuConfig.lua, PLAN.md, this card and session bundle.
# WATCH: duplicate_pattern_and_clear_muted_above duplicate_pattern_and_clear_muted duplicate_pattern_and_clear_muted_above_x duplicate_pattern_and_clear_muted_below_x
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: duplicate_pattern_and_clear_muted_above duplicate_pattern_and_clear_muted duplicate_pattern_and_clear_muted_above_x duplicate_pattern_and_clear_muted_below_x
Feature: Duplicate patterns with Pattern Matrix slot mutes X
  @code-verified @runtime-untested
  Scenario: Clear source Matrix-muted tracks above or below
    # cite: PakettiPatternMatrix.lua duplicate_pattern_and_clear_muted_above and duplicate_pattern_and_clear_muted
    Given the selected sequence slot has muted and unmuted Matrix tracks
    When Duplicate Pattern Above or Below & Clear Muted Tracks X runs
    Then source slot mutes are captured before insertion shifts sequence positions
    And only Matrix-muted tracks are cleared in the duplicate, including their automation
    And source pattern data stays intact
    And source Matrix mute flags are copied to the duplicate
    And channel mute state does not decide which tracks are cleared
    And send and master tracks are retained without querying invalid Matrix slots

  @code-verified @runtime-untested
  Scenario: Preserve pattern length and hand over looping playback
    # cite: PakettiPatternMatrix.lua PakettiCapturePatternLoopState and PakettiHandoverPatternLoopAndPlayback
    Given the source pattern has 128 lines and a single-slot sequence loop
    When an X duplicate is made
    Then its length and copied pattern content are preserved for uncleared tracks
    And the loop follows the duplicate
    And playing transport schedules the duplicate at the next pattern boundary
    And stopped transport stays stopped

  @built @runtime-untested
  Scenario: Expose both flavors alongside existing commands
    # cite: PakettiPatternMatrix.lua duplicate_pattern_and_clear_muted_above_x and duplicate_pattern_and_clear_muted_below_x
    # cite: PakettiMenuConfig.lua Duplicate Pattern Above & Clear Muted X and Duplicate Pattern Below & Clear Muted X registrations
    Given Paketti loads
    When the user browses menus, keybindings or MIDI mappings
    Then above and below X commands are available
    And legacy commands retain channel-mute clearing behavior
