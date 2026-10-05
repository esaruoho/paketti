# Report Card — Longer loaded-sample AHDSR release

> Source: `features/loader-ahdsr-release.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 3 · @runtime-verified × 1 · @sim-verified × 3

**Scenarios: 4**


---


## 1. Loader preference on gives the envelope a 480 ms release

`@sim-verified @runtime-untested`


- Given a freshly loaded instrument with Volume AHDSR and the loader envelope preference on
- When loader modulation settings are applied
- Then the AHDSR is activated and Release is assigned as 480 ms with tempo sync off
- And other AHDSR parameters and operator remain unchanged

<sub>cite: PakettiSamples.lua PakettiApplyLoaderModulationSettings</sub>


## 2. Loader preference off leaves release and timing unchanged

`@sim-verified @runtime-untested`


- Given the loader envelope preference is off
- When loader modulation settings are applied
- Then AHDSR activation, release and tempo sync are not changed

<sub>cite: PakettiSamples.lua PakettiApplyLoaderModulationSettings</sub>


## 3. Timestretch offers a deliberate 480 ms release action

`@sim-verified @runtime-untested`


- Given a selected sample with an assigned Volume AHDSR
- When the 480 ms button is pressed
- Then only Release and its unsynced timing are set
- And enabled state, operator and other parameter values are preserved

<sub>cite: PakettiStretch.lua set_stretch_release_480ms and 480 ms button</sub>


## 4. Renoise parses real 480 ms

`@runtime-verified`


- Given an unsynced Volume AHDSR Release parameter
- When its value_string is assigned 480 ms
- Then its display reads 480 ms and normalized value is approximately 0.2

<sub>cite: loader-ahdsr-release.session.md live parser verification</sub>

