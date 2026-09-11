# Report Card — Groovebox 8120 grid controllers (Akai MidiMix + APC Key 25 + LPD8)

> Source: `features/groovebox-8120-grid-controllers.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 6 · @hw-verified × 6

**Scenarios: 12**


---


## 1. APC pad toggles a step on the selected row (headless)

`@hw-verified`


- Given the APC Key 25 step sequencer is armed and the 8120 dialog is closed
- When the user presses a top-row pad
- Then that step toggles on the selected row's pattern
- And the pad lights green


## 2. APC mid-row pad toggles per-step probability (headless)

`@hw-verified`


- Given the APC Key 25 step sequencer is armed and the 8120 dialog is closed
- When the user presses a probability-row pad on a step that has a note
- Then a 0Y Maybe effect is written to that step in the pattern
- And the pad lights red


## 3. APC bottom row selects the instrument/row

`@hw-verified`


- Given the APC Key 25 step sequencer is armed
- When the user presses a bottom-row pad
- Then that row becomes the selected/focused row
- And the whole grid repaints for the new row


## 4. APC works headless via the Auto-Start setting

`@hw-verified`


- Given "Main Menu:Options:Auto-Start AKAI APC Key 25" is enabled
- When Renoise launches or a song loads with an APC Key 25 connected
- Then the step sequencer arms without opening the 8120 dialog


## 5. A MidiMix press reflects on the APC and vice-versa

`@hw-verified`


- Given both the MidiMix bridge and the APC sequencer are active on the same 8120
- When the user toggles a step on the MidiMix
- Then the same step lights up on the APC grid
- And selecting a different row on either controller updates both


## 6. LPD8 pages its 8 pads over the focused row (no forced step mode)

`@hw-verified`


- Given the LPD8 step sequencer is started in any step mode
- When the user presses a pad
- Then that step toggles on the selected row and the pad LED highlights it


## 7. Follow is per-controller and independent

`@built`


- Given the 8120 dialog is open
- When the user ticks the MidiMix follow checkbox but leaves the APC follow checkbox off
- Then preference pakettiGroovebox8120FollowMidiMix is set true and saved
- And pakettiGroovebox8120FollowAPC stays false
- And the MidiMix tracks the playhead while the APC keeps showing all its steps (non-rotating)


## 8. Each controller's follow persists and applies headlessly on the next session

`@built`


- Given a controller's own follow preference was left on in a previous session
- When that controller arms (dialog open, or via its Auto-Start setting)
- Then it reads its own saved preference and follows the playhead without any dialog action


## 9. APC follow restores the 16+16 paged layout at 32 steps

`@built`


- Given the 8120 is in 32-step mode and the APC sequencer is armed
- When the APC follow checkbox is on
- Then the APC shows 16 steps + 16 probability for the current page (not all 32 steps)
- And the page snaps to the playhead during playback (page 0 = 1..16, page 1 = 17..32)


## 10. APC left non-rotating shows every step at 32 steps

`@built`


- Given the 8120 is in 32-step mode and the APC sequencer is armed
- When the APC follow checkbox is off
- Then all 32 steps are shown across the top four pad rows and the grid never pages


## 11. MidiMix follow windows its 16 LEDs over a 32-step pattern

`@built`


- Given the 8120 is in 32-step mode and the MidiMix bridge is open
- When the MidiMix follow checkbox is on and the transport is playing
- Then the 16 LEDs page between steps 1-16 and 17-32 to keep the playhead visible


## 12. A controller's follow keybinding stays in sync with its own checkbox

`@built`


- Given the 8120 dialog is open with the LPD8 follow checkbox off
- When the user triggers "Global:Paketti:Paketti Groovebox 8120 LPD8 Toggle Follow Page"
- Then only the LPD8 follow turns on (APC and MidiMix are unaffected)
- And the LPD8 follow checkbox updates to checked

