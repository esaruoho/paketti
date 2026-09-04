# =============================================================================
# WIKI PAGE / REPORT CARD: EQ10 keyboard controls
#
# WHAT THIS CARD SPAWNS:
#   codespace  — EQ10 dialog gain shortcut handler
#   thinkspace — eq10-keyboard-controls.session.md
#   areaspace  — OWNS: keyboard gain nudges for the existing EQ10 dialog
#                MUST NOT TOUCH: plugin parameter layouts or unrelated dialogs
#
# Innards linked back to this card (grep "features/eq10-keyboard-controls.feature"):
#   PakettiExperimental_Verify.lua - EQ10 gain adjustment and dialog keyhandler
#
# SESSION:      eq10-keyboard-controls.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: adjust_eq10_band_gain pakettiEQ10XYDialog
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: adjust_eq10_band_gain
# =============================================================================

Feature: EQ10 keyboard controls
  As a Paketti user, I want quick keyboard control of EQ10 bands, So that I can shape gains without reaching for each GUI control.

  @shipped @code-verified @runtime-untested
  Scenario: Shift-number shortcuts raise individual EQ10 bands
    # cite: PakettiExperimental_Verify.lua adjust_eq10_band_gain (line 55) — clamps and applies the requested gain step
    # cite: PakettiExperimental_Verify.lua pakettiEQ10XYDialog (line 70) — maps Shift+1..0 to bands 1..10
    Given the EQ10 XY Control dialog is open
    When the user presses Shift+1 through Shift+0
    Then the matching EQ10 band gain increases by 1 dB
    And the gain remains within the EQ10 parameter limits

  @shipped @code-verified @runtime-untested
  Scenario: Shift-QWERTY shortcuts lower individual EQ10 bands
    # cite: PakettiExperimental_Verify.lua pakettiEQ10XYDialog (line 70) — maps Shift+Q..P to bands 1..10
    Given the EQ10 XY Control dialog is open
    When the user presses Shift+Q through Shift+P
    Then the matching EQ10 band gain decreases by 1 dB
    And the gain remains within the EQ10 parameter limits
