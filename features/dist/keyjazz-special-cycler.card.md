# Report Card — Refresh Special keyjazz delays at every count

> Source: `features/keyjazz-special-cycler.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 4 · @sim-verified × 4

**Scenarios: 4**


---


## 1. Reapply delays at the upper limit

`@sim-verified @runtime-untested`


- Given twelve note columns are visible and delays have been erased
- When Special cycler plus one is triggered with its stored count at twelve
- Then all rows receive floor(256 / 12 * (column - 1)) delays
- And cycling stays on with edit mode enabled, edit step zero and column one selected

<sub>cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerApply; tests/keyjazz-special-cycler.lua</sub>


## 2. Select Special counts through keys, menus and a MIDI knob

`@sim-verified @runtime-untested`


- Given a sequencer track
- When a Special step or absolute MIDI knob selects a count
- Then the count is clamped to one through twelve and pattern delays are regenerated

<sub>cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerStep and Special registrations</sub>


## 3. Preserve ordinary cycler behavior

`@sim-verified @runtime-untested`


- Given existing delay values
- When the ordinary cycler changes count
- Then existing delays are preserved

<sub>cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzCyclerApply</sub>


## 4. Numbered Special twelve refreshes already-visible columns

`@sim-verified @runtime-untested`


- Given twelve columns are already visible
- When numbered Special twelve is invoked again
- Then the visible count is assigned directly and every row receives regenerated delays

<sub>cite: PakettiExperimental_Verify.lua PakettiColumnCycleKeyjazzSpecialPrepare and ColumnCycleKeyjazzSpecial</sub>

