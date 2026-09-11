# Report Card — Parameter Editor exposes on the Mixer the parameter you're modifying

> Source: `features/parameter-editor-mixer-and-config.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @built × 4 · @untested × 1

**Scenarios: 7**


---


## 1. Dragging a parameter with "Expose on Mixer" on surfaces it in the mixer

`@built @logic-verified`


- Given the Parameter Editor is open on a device
- And "Expose on Mixer" is enabled
- And Automation Sync is OFF
- When I drag a parameter bar
- Then that parameter's show_in_mixer becomes true
- And it appears in the Renoise mixer immediately
- Feature: One-shot "Expose Automated Parameters on Mixer"

<sub>cite: PakettiCanvasExperiments.lua PakettiExposeAutomatedParamsOnMixer + registrations | REQUEST #2</sub>


## 2. Surface only the automated parameters of the selected track

`@built @logic-verified`


- Given the selected track has devices, some of whose parameters are automated
- When I trigger "Expose Automated Parameters on Mixer" (keybinding / MIDI / Mixer:Paketti Gadgets menu)
- Then every parameter with is_automated == true gets show_in_mixer = true
- And parameters WITHOUT automation are left alone (not "show all")
- And a status line reports how many were exposed
- Feature: Grid-stripe visual mode for the Parameter Editor

<sub>cite: PakettiCanvasExperiments.lua render bar loop + grid_stripe_checkbox | REQUEST #4</sub>


## 3. Alternating column backgrounds for grid-style reading

`@built @untested`


- Given the Parameter Editor is open
- When I enable the "Grid stripes" checkbox
- Then odd parameter columns paint a light background and even columns a dark one
- And the parameter bars draw on top, so columns read as a checker grid
- Feature: Per-plugin Parameter Editor configuration (reorder / hide / rename)

<sub>cite: PakettiCanvasExperiments.lua (BuildDisplayedParameters/ApplyDisplayConfig/OpenConfigDialog +</sub>


## 4. Mode OFF or no config behaves exactly like today (no-op)

`@built @in-renoise`


- Given the Parameter Editor builds its parameter list
- When Customized Ordering Mode is OFF, or ON but the device has no saved config
- Then the displayed parameter list equals the baseline list byte-for-byte
- And the Wavetable Mod *LFO skip-first-3 rule still applies


## 5. User curates which parameters show, in what order, under what names

`(ungraded)`


- Given Customized Ordering Mode is ON
- When the user opens the "Configure..." dialog (editor button / Mixer:Paketti Gadgets menu /
- keybinding "Global:Paketti:Configure Parameter Editor for Selected Device")
- And hides parameters (Show checkbox), reorders them (up/down), and renames displayed labels
- And presses Save
- Then the config is stored keyed by device.device_path and persisted (Upsert + save_as)
- And the editor rebuilds so hidden params drop out, order follows the config, and labels rename
- And the real device parameters/order/names are never mutated (display layer only)


## 6. Reset to Plugin Default restores the baseline

`(ungraded)`


- Given a device has a saved config
- When the user presses "Reset to Plugin Default"
- Then the config entry is removed and the editor rebuilds to the baseline order/count
- Feature: Renoise as a round-trip sample editor for Ableton Live

<sub>cite: Research/parameter-editor/feasibility.md | REQUEST #6</sub>


## 7. Edit a Live sample in Renoise and save it back so Live reloads it

`@feasibility`


- Given a sample referenced by an Ableton Live set at a known file path
- When I load it into Renoise, edit it, and press "Save Back"
- Then Renoise overwrites the original WAV in place and removes its .asd sidecar
- And Live picks up the new audio on next clip load (full auto-reload needs AbletonOSC/M4L)

