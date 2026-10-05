# Report Card — Close the unfocused parameter editor

> Source: `features/parameter-editor-close.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 1 · @runtime-verified × 1 · @sim-verified × 2

**Scenarios: 2**


---


## 1. Hide editors from Pattern Editor or Global closes the custom dialog

`@sim-verified @runtime-verified`


- Given the Selected Device Parameter Editor is visible but unfocused
- When the existing hide external editors shortcut is invoked
- Then parameter editor automation observers and timers are cleaned up
- And the parameter editor closes without requiring its keyboard focus
- And existing external device editors also close

<sub>cite: PakettiLoaders.lua hide_all_external_editors; PakettiCanvasExperiments.lua PakettiCanvasExperimentsCloseDialog</sub>


## 2. Repeated hide calls and an unavailable parameter editor remain safe

`@sim-verified @runtime-untested`


- Given the parameter editor is already closed or its module is unavailable
- When hide external editors is invoked
- Then external device editors still close without a missing-function error

<sub>cite: PakettiLoaders.lua hide_all_external_editors; tests/parameter-editor-close.lua</sub>

