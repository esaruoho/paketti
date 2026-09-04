# =============================================================================
# WIKI PAGE / REPORT CARD: Pattern and song row jumps
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiRequests.lua explicit row jumps and PakettiPatternEditor.lua fraction jumps
#   thinkspace — pattern-song-jumps.session.md
#   areaspace  — OWNS: cursor navigation commands for pattern fractions and last row-jump reversal
#                MUST NOT TOUCH: note data, automation data, sample data, or pattern contents
#
# Innards linked back to this card (grep "features/pattern-song-jumps.feature"):
#   PakettiRequests.lua - PakettiJumpRows, PakettiJumpRowsInSong, and last-jump reversal helpers
#   PakettiPatternEditor.lua - PakettiJumpToPatternFraction and previous-position toggle
#
# SESSION:      pattern-song-jumps.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: PakettiJumpRows PakettiJumpRowsInSong PakettiJumpBackByLastPatternJump PakettiJumpBackByLastSongJump PakettiJumpToPatternFraction PakettiJumpToPreviousPosition
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: PakettiJumpRows PakettiJumpRowsInSong PakettiJumpBackByLastPatternJump PakettiJumpBackByLastSongJump PakettiJumpToPatternFraction
# =============================================================================

Feature: Pattern and song row jumps
  As a Renoise user, I want bounded jump commands with a fast way back, So that navigation is reversible while composing.

  @shipped @code-verified @runtime-untested
  Scenario: Reverse the last explicit pattern row jump
    # cite: PakettiRequests.lua PakettiJumpRows (~line 9138) — records the last pattern row jump
    # cite: PakettiRequests.lua PakettiJumpBackByLastPatternJump (~line 9163) — invokes the opposite jump
    Given the user has triggered an explicit forward or backward row jump within the current pattern
    When the user triggers "Jump Back by Last Pattern Row Jump"
    Then Paketti moves the cursor by the same row amount in the opposite direction within the pattern
    And the reverse action becomes the stored jump, so invoking it again toggles back

  @shipped @code-verified @runtime-untested
  Scenario: Reverse the last explicit song row jump
    # cite: PakettiRequests.lua PakettiJumpRowsInSong (~line 9255) — records the last song row jump
    # cite: PakettiRequests.lua PakettiJumpBackByLastSongJump (~line 9280) — invokes the opposite jump
    Given the user has triggered an explicit forward or backward row jump across the song
    When the user triggers "Jump Back by Last Song Row Jump"
    Then Paketti moves by the same row amount in the opposite direction across sequence/pattern boundaries
    And playback-follow mode uses the transport playback position as the source position

  @shipped @code-verified @runtime-untested
  Scenario: Jump to pattern fractions from Pattern Editor and Global contexts
    # cite: PakettiPatternEditor.lua PakettiJumpToPatternFraction (~line 11373) — calculates fraction row targets
    # cite: PakettiPatternEditor.lua fraction binding loop (~line 11389) — exposes /2, /4, /8, and /16 commands
    Given the current pattern has any supported line count
    When the user triggers a pattern fraction command such as 03/08
    Then Paketti moves the cursor to the matching fractional row of the current pattern
    And the same command is available from both Pattern Editor and Global keybinding contexts

  @stock
  Scenario: Existing fixed row jumps remain available
    # cite: PakettiRequests.lua jump binding loop (~line 12724) — existing 001-128 row commands
    Given PakettiJumpForwardBackwardCommands is enabled
    When Paketti registers the fixed row-jump commands
    Then the existing forward/backward within-pattern and within-song commands remain registered
