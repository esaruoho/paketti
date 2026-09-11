# Report Card — AKAI controller debug/demo entries moved out of the Groovebox menu

> Source: `features/2026-06-11-groovebox-controller-follow-and-menu.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @built × 6 · @hw-untested × 3

**Scenarios: 9**


---


## 1. Controller debug entries live under !Preferences:Debug:MidiControllers

`@built`


- Given the Groovebox menu was polluted with APC/MidiMix/LPD8 probe/demo/lights entries
- When the tool registers its menus
- Then all 29 of them appear under Main Menu:Tools:Paketti:!Preferences:Debug:MidiControllers
- And the Groovebox menu keeps only its real features (Sequential Load/Kit/Canvas/etc.)
- And "Trigger Sample Manual Test" moves from Tools:Paketti:Debug to !Preferences:Debug


## 2. The three Auto-Start toggles live only under Options

`(ungraded)`


- Given the Auto-Start AKAI entries were dual-registered (Options + Groovebox)
- When the tool registers its menus
- Then only the Main Menu:Options copies remain (the Groovebox duplicates are removed)
- Feature: KeyBindings preset + MIDI-mapping presets committed

<sub>cite: KeyBindings/2025_07_10_PakettiKeyBindings.xml + 3 new *.xrnm | commit 09e135c</sub>


## 3. The user's controller mapping work is in the repo

`@built`


- Given the working tree held an edited keybinding preset and 3 untracked MIDI maps
- When committed and pushed
- Then MidiMix+MPKMini3 and the two APCKEY25 mapping presets are tracked (cd.txt left out, later deleted)
- Feature: "Auto-samplify" capitalised to "Auto-Samplify"

<sub>cite: PakettiMenuConfig.lua:~3515-3516 + PakettiAutoSamplify.lua:~1545 | commit b4a229b</sub>


## 4. Menu entries and status text read "Auto-Samplify"

`@built @logic-verified`


- Given two Main Menu:Options toggles and one status string said "Auto-samplify"
- When the text is corrected
- Then all three read "Auto-Samplify"
- And the internal preference keys (pakettiAutoSamplify*) are left unchanged (no persistence break)
- Feature: APC Key 25 follow-page restores 16+16 layout at 32 steps

<sub>cite: PakettiEightOneTwenty.lua paketti_apc_seq_zone + paketti_apc_seq_refresh + paketti_apc_paged | commits b3f29c5, 7d3dd71</sub>


## 5. APC follow on at 32 steps shows 16 steps + 16 probability and pages

`@built @logic-verified @hw-untested`


- Given the 8120 is in 32-step mode and the APC sequencer is armed
- When the APC follow checkbox is on
- Then the APC shows 16 steps + 16 probability for the current page (not all 32 steps)
- And the page snaps to the playhead during playback (page 0 = 1..16, page 1 = 17..32)


## 6. APC left non-rotating shows every step

`(ungraded)`


- Given 32-step mode and the APC follow checkbox off
- Then all 32 steps fill the top four pad rows and the grid never pages
- Feature: MidiMix follow-page windows its 16 LEDs over 32 steps

<sub>cite: PakettiEightOneTwenty.lua paketti_midimix_redraw_all_leds + idle handler + page math | commits b3f29c5, 7d3dd71</sub>


## 7. MidiMix follow on at 32 steps keeps the playhead visible

`@built @logic-verified @hw-untested`


- Given the 8120 is in 32-step mode, the MidiMix bridge is open, transport playing
- When the MidiMix follow checkbox is on
- Then the 16 LEDs page between steps 1-16 and 17-32 to track the playhead
- And a button press toggles the correct global step for the current page
- Feature: Follow is PER-CONTROLLER and independent (final design)

<sub>cite: PakettiEightOneTwenty.lua paketti_{apc,midimix,lpd8}_follow_enabled + ...SetFollow + 3 dialog checkboxes; Paketti0G01_Loader.lua 3 prefs | commit 7d3dd71</sub>


## 8. Three independent persisted toggles, one per controller

`@built @logic-verified @hw-untested`


- Given the 8120 dialog is open
- When the user ticks the MidiMix follow checkbox but leaves the APC one off
- Then pakettiGroovebox8120FollowMidiMix is saved true and ...FollowAPC stays false
- And each controller's Toggle-Follow keybinding/MIDI/menu toggles only itself
- And arming a controller reads its own saved preference (follows-or-not headlessly)
- Feature: The global single-master "Ctrl Follow" checkbox (intermediate, replaced)

<sub>cite: pakettiGroovebox8120Follow + PakettiEightOneTwentySetControllerFollow | commit a31d111</sub>


## 9. A single master toggle drove all three controllers

`@superseded`


- Given an earlier turn shipped one checkbox + one preference for all controllers
- When the user asked for per-controller control instead
- Then commit 7d3dd71 replaced it with three independent toggles (this code no longer exists)

