# Report Card — Pattern and song row jumps

> Source: `features/pattern-song-jumps.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Renoise user, I want bounded jump commands with a fast way back, So that navigation is reversible while composing.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Reverse the last explicit pattern row jump

`@shipped @code-verified @runtime-untested`


- Given the user has triggered an explicit forward or backward row jump within the current pattern
- When the user triggers "Jump Back by Last Pattern Row Jump"
- Then Paketti moves the cursor by the same row amount in the opposite direction within the pattern
- And the reverse action becomes the stored jump, so invoking it again toggles back

<sub>cite: PakettiRequests.lua PakettiJumpRows (~line 9138) — records the last pattern row jump · PakettiRequests.lua PakettiJumpBackByLastPatternJump (~line 9163) — invokes the opposite jump</sub>


## 2. Reverse the last explicit song row jump

`@shipped @code-verified @runtime-untested`


- Given the user has triggered an explicit forward or backward row jump across the song
- When the user triggers "Jump Back by Last Song Row Jump"
- Then Paketti moves by the same row amount in the opposite direction across sequence/pattern boundaries
- And playback-follow mode uses the transport playback position as the source position

<sub>cite: PakettiRequests.lua PakettiJumpRowsInSong (~line 9255) — records the last song row jump · PakettiRequests.lua PakettiJumpBackByLastSongJump (~line 9280) — invokes the opposite jump</sub>


## 3. Jump to pattern fractions from Pattern Editor and Global contexts

`@shipped @code-verified @runtime-untested`


- Given the current pattern has any supported line count
- When the user triggers a pattern fraction command such as 03/08
- Then Paketti moves the cursor to the matching fractional row of the current pattern
- And the same command is available from both Pattern Editor and Global keybinding contexts

<sub>cite: PakettiPatternEditor.lua PakettiJumpToPatternFraction (~line 11373) — calculates fraction row targets · PakettiPatternEditor.lua fraction binding loop (~line 11389) — exposes /2, /4, /8, and /16 commands</sub>


## 4. Existing fixed row jumps remain available

`@stock`


- Given PakettiJumpForwardBackwardCommands is enabled
- When Paketti registers the fixed row-jump commands
- Then the existing forward/backward within-pattern and within-song commands remain registered

<sub>cite: PakettiRequests.lua jump binding loop (~line 12724) — existing 001-128 row commands</sub>

