# Report Card — Show and change sample playback quality

> Source: `features/sample-playback-quality.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @built × 1 · @runtime-untested × 4 · @sim-verified × 3

**Scenarios: 4**


---


## 1. Checked menus describe the complete target scope

`@sim-verified @runtime-untested`


- Given samples with uniform or mixed interpolation and oversampling settings
- When I inspect Tools, Sample List, Sample Editor or Instrument Box quality menus
- Then a mode is checked only if every target shares it
- And Oversampling is checked only if every target is enabled
- And every selected callback returns a strict boolean including empty scopes

<sub>cite: PakettiTkna.lua PakettiSampleQualityTargets</sub>


## 2. Cycle and toggle sample, instrument or song

`@sim-verified @runtime-untested`


- Given a selected sample, instrument or whole song scope
- When I cycle interpolation
- Then all targets advance from the first target's mode with Sinc wrapping to None
- When I toggle oversampling
- Then all targets turn off if all were on and otherwise all turn on
- And repeated key events and non-trigger MIDI messages do nothing
- And unrelated sample fields are preserved

<sub>cite: PakettiTkna.lua PakettiSampleQualityChange</sub>


## 3. Native import detection is a proposal only

`@built @runtime-untested`


- Given the documented native import detector design
- When I load or record audio through Renoise
- Then these new manual controls do not automatically change that audio's settings

<sub>cite: manual/NativeSampleDefaults.md</sub>


## 4. Quality menus are flat and ordered

`@sim-verified @runtime-untested`


- Given the Sample Playback Quality menu
- When I view its entries
- Then current-instrument modes appear directly as 00 None, 01 Linear, 02 Cubic, 03 Sinc
- And sample and song actions identify their scope without another submenu
- And the first Whole Song mode carries a -- separator prefix
- And Oversampling stays in the same block as its interpolation controls
- And the advancing action is named Interpolation (Next)

<sub>cite: PakettiTkna.lua add_scope</sub>

