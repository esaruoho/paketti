# Report Card — Preserve crafted envelopes in Timestretch

> Source: `features/stretch-envelope-preservation.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 4 · @sim-verified × 4

**Scenarios: 4**


---


## 1. Activate without disabling or overwriting the envelope

`@sim-verified @runtime-untested`


- Given a crafted Volume AHDSR with custom parameters and operator
- When the module is loaded or the dialog is initialized
- Then its existing enabled or disabled state is preserved
- And all parameters, operator, sample looping and new-note action are preserved

<sub>cite: PakettiStretch.lua and read-only envelope display</sub>


## 2. Displaying envelope state never enables or disables it

`@sim-verified @runtime-untested`


- Given the selected sample has an enabled Volume AHDSR
- When the dialog displays envelope state repeatedly
- Then the envelope stays enabled with every parameter and sample setting preserved

<sub>cite: PakettiStretch.lua and read-only envelope display</sub>


## 3. Release and Release Scaling edit only their parameter

`@sim-verified @runtime-untested`


- Given a crafted envelope
- When Release or Release Scaling is edited
- Then only parameter five or eight respectively changes
- And Release editing preserves enabled state and other envelope and sample settings

<sub>cite: PakettiStretch.lua pakettiTimestretchDialog Release and Release Scaling notifiers</sub>


## 4. Target the selected sample modulation set

`@sim-verified @runtime-untested`


- Given several modulation sets contain Volume AHDSR devices
- When an envelope control is used
- Then only the selected sample assigned set is targeted
- And an unassigned sample leaves unrelated sets untouched

<sub>cite: PakettiStretch.lua find_stretch_volume_ahdsr_device</sub>

