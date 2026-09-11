# Report Card — Device Control actions record bypass automation

> Source: `features/device-toggle-automation.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want Device Control NN enable/disable/toggle actions to record automation, So that hardware or shortcut-driven device bypass moves become part of the pattern.

**Grades:** @built × 3 · @code-verified × 3 · @runtime-untested × 3 · @shipped × 3 · @stock × 1

**Scenarios: 4**


---


## 1. Pattern Effects mode writes x000 or x001

`@shipped @built @code-verified @runtime-untested`


- Given Edit Mode is on
- And the transport record parameter mode is Pattern Effects
- When Paketti Device Control 01 disables the first selected-track DSP device
- Then the selected track's first effect column receives command 10 with amount 00
- And enabling the same device writes command 10 with amount 01

<sub>cite: PakettiRequests.lua PakettiWriteDeviceBypassPatternCommand (~line 7285) - writes device Active state as Renoise x000/x001 pattern command ; commit worktree</sub>


## 2. Graphical Automation mode writes the Active envelope

`@shipped @built @code-verified @runtime-untested`


- Given Edit Mode is on
- And the transport record parameter mode is Graphical Automation
- When Paketti Device Control 01 toggles the first selected-track DSP device
- Then Paketti writes 1.0 for enabled or 0.0 for disabled to that device's Active automation envelope

<sub>cite: PakettiRequests.lua PakettiWriteDeviceBypassGraphicalAutomation (~line 7305) - creates or updates the target device Active envelope ; commit worktree</sub>


## 3. Follow-player decides cursor versus playhead line

`@shipped @built @code-verified @runtime-untested`


- Given Edit Mode is on
- When playback is running and Follow Pattern is on
- Then the bypass automation is written at the playback line
- When playback is stopped or Follow Pattern is off
- Then the bypass automation is written at the selected cursor line

<sub>cite: PakettiRequests.lua PakettiDeviceBypassAutomationLine (~line 7272) - chooses playhead only while playing with follow enabled ; commit worktree</sub>


## 4. Edit Mode off keeps Device Control as a live toggle only

`@stock`


- Given Edit Mode is off
- When a Device Control NN action enables, disables, or toggles a selected-track DSP device
- Then the device live is_active state still changes
- And no pattern command or graphical automation point is written

<sub>cite: PakettiRequests.lua PakettiRecordDeviceBypassAutomation (~line 7326) - returns without recording when Edit Mode is off ; commit worktree</sub>

