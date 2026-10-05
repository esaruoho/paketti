# Report Card — Command Wheel adjustments use one router

> Source: `features/command-wheel-adjustments.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti maintainer, I want Command Wheel index and value nudges to share one adjustment path, So that adding new deltas does not require bespoke functions and repeated keybinding registrations.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3

**Scenarios: 3**


---


## 1. Index and value keybindings share one adjustment router

`@shipped @code-verified @runtime-untested`


- Given the Command Wheel exposes Index +/-1 and Value +/-1/+/-10 keybindings
- When those keybindings are registered
- Then they are generated from one table of target/delta pairs
- And each keybinding invokes PakettiCommandWheelAdjust(target, delta) through a per-row callback factory

<sub>cite: PakettiCommandWheel.lua PakettiCommandWheelAdjust · PakettiCommandWheel.lua paketti_command_wheel_adjust_keybindings</sub>


## 2. Existing internal wrapper names remain callable

`@shipped @code-verified @runtime-untested`


- Given existing dialog buttons and MIDI button mappings call the older wrapper functions
- When those functions run
- Then they delegate to the shared adjustment router
- And the existing call sites do not need to change

<sub>cite: PakettiCommandWheel.lua PakettiCommandWheelIndexNext · PakettiCommandWheel.lua PakettiCommandWheelIndexPrev · PakettiCommandWheel.lua PakettiCommandWheelValueUp1 · PakettiCommandWheel.lua PakettiCommandWheelValueDown10</sub>


## 3. Index adjustment wraps through the valid index range

`@shipped @code-verified @runtime-untested`


- Given the Command Wheel has a current mode with a maximum index
- When an index delta moves before the first index or past the maximum index
- Then the selected index wraps into the valid range
- And the selected target value is resynced for macro, MIDI CC, and device modes

<sub>cite: PakettiCommandWheel.lua PakettiCommandWheelAdjustIndex</sub>

