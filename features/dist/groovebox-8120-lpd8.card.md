# Report Card — Groovebox 8120 — AKAI LPD8 controller (8 pads + pages + follow + row select)

> Source: `features/groovebox-8120-lpd8.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 3 · @hw-verified × 3

**Scenarios: 6**


---


## 1. 8 pads sequence the selected row (headless)

`@hw-verified`


- Given the LPD8 step sequencer is started
- When the user presses a pad
- Then the corresponding step toggles on the selected row and the pad LED follows


## 2. Do-nothing absorbers keep the pads from triggering samples

`@built @untested-in-renoise`


- Given the 8 "Disabled LPD8 01".."Disabled LPD8 08" MIDI mappings exist
- When the user maps each LPD8 pad to one in Renoise MIDI Map mode
- Then pressing a pad sequences the row without also playing a sample


## 3. Flip a page through a 16/32-step pattern

`@hw-verified`


- Given the groovebox is in 16- or 32-step mode and the LPD8 sequencer is on
- When the user triggers "LPD8 Next Page"
- Then the 8 pads show the next 8 steps (1-8 -> 9-16 -> 17-24 -> 25-32, wrapping)


## 4. Follow mode tracks the playhead across pages

`@hw-verified`


- Given the LPD8 follow-page mode is ON
- When playback crosses from steps 1-8 into 9-16
- Then the LPD8 auto-flips to the page showing 9-16, then back for 1-8


## 5. 4 steps + 4 probability layout

`@built @untested-in-renoise`


- Given the user triggers "LPD8 Toggle 4Steps+4Probability Layout"
- Then the top 4 pads edit 4 steps and the bottom 4 pads edit those steps' probability
- And paging then advances 4 steps at a time


## 6. Select the row with a single knob (three bindable copies)

`@built @untested-in-renoise`


- Given a knob is mapped to "Select Row (Knob 01-08) 1st Bind" (or 2nd/3rd, or the 08-01 reverse)
- When the user sweeps the knob 0..127
- Then the selected/focused row walks 1..8 (or 8..1), setting that row's track + instrument

