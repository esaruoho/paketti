# Paketti — the TRUE spine (from the running code)

*Captured by executing Paketti's own registration code under a mocked Renoise (`paketti-harness.lua`) — for-loops expanded, concatenation resolved, wrappers honoured. NOT from stale XML or a text scan.*

## Headline: where Paketti touches Renoise

- **24,860 unique registration points** total
  - **11,356 keyboard shortcuts**
  - **6,701 menu entries**
  - **6,803 MIDI mappings**

**Validation:** Paketti's *own* runtime counters say 11,351 keybindings / 6,802 MIDI / 6,698 menus — matching the harness within a handful. The numbers are real.

**For contrast:** the stale `KeyBindings.xml` (2025-07) shows ~8,383 keybindings; a text scan of the source shows ~2,935. The code registers ~3–4× more than either — because of the for-loops. *This* is the only count that's true.

## Where the features live (Renoise regions, by Paketti's own taxonomy)

| Region | shortcuts | menus | MIDI | total |
|---|--:|--:|--:|--:|
| **Song & pattern** | | | | |
| &nbsp;&nbsp;PatternEditor | 1,441 | 903 | 17 | 2,361 |
| &nbsp;&nbsp;PatternSequencer | 44 | 480 | 0 | 524 |
| &nbsp;&nbsp;PhraseEditor | 425 | 70 | 4 | 499 |
| &nbsp;&nbsp;PatternMatrix | 185 | 251 | 0 | 436 |
| &nbsp;&nbsp;PhraseGrid | 0 | 7 | 0 | 7 |
| &nbsp;&nbsp;PhraseMappings | 0 | 4 | 0 | 4 |
| **Samples & instruments** | | | | |
| &nbsp;&nbsp;InstrumentBox | 483 | 758 | 0 | 1,241 |
| &nbsp;&nbsp;SampleNavigator | 501 | 641 | 0 | 1,142 |
| &nbsp;&nbsp;SampleKeyzone | 512 | 585 | 0 | 1,097 |
| &nbsp;&nbsp;SampleEditor | 527 | 415 | 63 | 1,005 |
| &nbsp;&nbsp;SampleFXMixer | 0 | 83 | 0 | 83 |
| &nbsp;&nbsp;SampleModulationMatrix | 0 | 67 | 0 | 67 |
| &nbsp;&nbsp;SampleEditorRuler | 0 | 32 | 0 | 32 |
| **Mixing, FX & automation** | | | | |
| &nbsp;&nbsp;Mixer | 187 | 267 | 0 | 454 |
| &nbsp;&nbsp;TrackDSPDevice | 1 | 206 | 0 | 207 |
| &nbsp;&nbsp;Automation | 7 | 62 | 1 | 70 |
| &nbsp;&nbsp;TrackDSPChain | 0 | 24 | 0 | 24 |
| &nbsp;&nbsp;TrackAutomationList | 0 | 17 | 0 | 17 |
| &nbsp;&nbsp;DSPDeviceAutomation | 0 | 1 | 0 | 1 |
| **Files** | | | | |
| &nbsp;&nbsp;DiskBrowserFiles | 0 | 55 | 0 | 55 |
| **Menus & global** | | | | |
| &nbsp;&nbsp;Global | 7,043 | 482 | 515 | 8,040 |
| &nbsp;&nbsp;Paketti | 0 | 0 | 6,198 | 6,198 |
| &nbsp;&nbsp;MainMenuTools | 0 | 1,111 | 0 | 1,111 |
| &nbsp;&nbsp;MainMenuFile | 0 | 67 | 0 | 67 |
| &nbsp;&nbsp;MainMenuView | 0 | 58 | 0 | 58 |
| **Other / uncategorized** | | | | |
| &nbsp;&nbsp;Modulation Set | 0 | 48 | 0 | 48 |
| &nbsp;&nbsp;Sononymph | 0 | 0 | 5 | 5 |
| &nbsp;&nbsp;Instrument Phrases | 0 | 4 | 0 | 4 |
| &nbsp;&nbsp; DSP Device | 0 | 1 | 0 | 1 |
| &nbsp;&nbsp; Mixer | 0 | 1 | 0 | 1 |
| &nbsp;&nbsp; Sample FX Mixer | 0 | 1 | 0 | 1 |

*(MIDI mappings are named `Paketti:…` without a GUI region, so they bucket under Global/Paketti — they fire regardless of focus.)*

## Robustness: 194/194 files load clean, 0 brittle

**Robust (194):** loaded and registered without error under the harness.


## How to regenerate
```
paketti-spine-report      # runs the harness + rewrites this file
```
Mechanism: `bin/paketti-harness.lua` (LuaJIT, mocked Renoise) → `spine-true.json`.