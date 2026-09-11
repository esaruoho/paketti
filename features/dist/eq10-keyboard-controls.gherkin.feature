# Pure Gherkin test extracted from features/eq10-keyboard-controls.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/eq10-keyboard-controls.feature

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

  @shipped @code-verified @runtime-untested
  Scenario: Keyboard gain shortcuts keep XY pads visually synchronized
    # cite: PakettiExperimental_Verify.lua refresh_eq10_band_xypad — recalculates and writes the matching XY pad value after a shortcut nudge
    # cite: PakettiExperimental_Verify.lua pakettiEQ10XYDialog — calls the pad refresh helper after handled Shift shortcuts and displays the shortcut hints
    Given the EQ10 XY Control dialog is open
    When the user changes a band gain with a Shift shortcut
    Then the matching XY pad moves to the updated gain position
    And the dialog shows the raise and lower shortcut rows
