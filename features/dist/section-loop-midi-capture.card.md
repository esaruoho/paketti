# Report Card — Section loop and MIDI capture

> Source: `features/section-loop-midi-capture.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a live Paketti user, I want section loop actions to advance predictably and static MIDI values to be recordable, So that footswitches and controllers work without manual corrective steps.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3

**Scenarios: 3**


---


## 1. Schedule the current section and advance on repeated triggers

`@shipped @code-verified @runtime-untested`


- Given the cursor is inside a defined section
- When the schedule-section action is triggered
- Then a non-looping current section is looped and its first sequence is added to the schedule
- And a currently-looping section advances to the next section and adds its first sequence to the schedule

<sub>cite: PakettiTkna.lua tknaAddLoopAndScheduleSection — detects whether the current section is already looped, then targets current or next section</sub>


## 2. Switch immediately between sections

`@shipped @code-verified @runtime-untested`


- Given the cursor is inside a defined section
- When the immediate next or previous action is triggered
- Then a non-looping current section becomes the active loop and starts immediately
- And a looping current section switches immediately to the adjacent section

<sub>cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately — loops the current section first, then immediately triggers adjacent sections</sub>


## 3. Capture a static selected-device parameter value

`@shipped @code-verified @runtime-untested`


- Given a selected device parameter is automatable and its controller has not moved
- When the matching Capture Selected Device Automation Parameter MIDI trigger is received
- Then the current parameter value is written to the selected automation envelope
- And the write uses the playhead when playback and follow mode are active, otherwise the cursor

<sub>cite: PakettiMidi.lua PakettiCaptureSelectedDeviceAutomationParameter — writes the existing parameter value at the cursor or playhead</sub>

