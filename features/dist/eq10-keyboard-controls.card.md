# Report Card — EQ10 keyboard controls

> Source: `features/eq10-keyboard-controls.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want quick keyboard control of EQ10 bands, So that I can shape gains without reaching for each GUI control.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3

**Scenarios: 3**


---


## 1. Shift-number shortcuts raise individual EQ10 bands

`@shipped @code-verified @runtime-untested`


- Given the EQ10 XY Control dialog is open
- When the user presses Shift+1 through Shift+0
- Then the matching EQ10 band gain increases by 1 dB
- And the gain remains within the EQ10 parameter limits

<sub>cite: PakettiExperimental_Verify.lua adjust_eq10_band_gain (line 55) — clamps and applies the requested gain step · PakettiExperimental_Verify.lua pakettiEQ10XYDialog (line 70) — maps Shift+1..0 to bands 1..10</sub>


## 2. Shift-QWERTY shortcuts lower individual EQ10 bands

`@shipped @code-verified @runtime-untested`


- Given the EQ10 XY Control dialog is open
- When the user presses Shift+Q through Shift+P
- Then the matching EQ10 band gain decreases by 1 dB
- And the gain remains within the EQ10 parameter limits

<sub>cite: PakettiExperimental_Verify.lua pakettiEQ10XYDialog (line 70) — maps Shift+Q..P to bands 1..10</sub>


## 3. Keyboard gain shortcuts keep XY pads visually synchronized

`@shipped @code-verified @runtime-untested`


- Given the EQ10 XY Control dialog is open
- When the user changes a band gain with a Shift shortcut
- Then the matching XY pad moves to the updated gain position
- And the dialog shows the raise and lower shortcut rows

<sub>cite: PakettiExperimental_Verify.lua refresh_eq10_band_xypad — recalculates and writes the matching XY pad value after a shortcut nudge · PakettiExperimental_Verify.lua pakettiEQ10XYDialog — calls the pad refresh helper after handled Shift shortcuts and displays the shortcut hints</sub>

