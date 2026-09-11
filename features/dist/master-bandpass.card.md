# Report Card — Paketti Master Bandpass audition filter

> Source: `features/master-bandpass.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @build-verified × 4 · @runtime-untested × 4 · @shipped × 4

**Scenarios: 4**


---


## 1. Insert or reuse the tagged master Doofer

`@shipped @build-verified @runtime-untested`


- Given a Renoise song with no Paketti Master Bandpass device on the master track
- When the user opens the Paketti Master Bandpass dialog or toggles the filter active
- Then Paketti inserts one native Doofer named "Paketti Master Bandpass" on the master track
- And repeated invocations reuse that tagged device instead of adding duplicates

<sub>cite: PakettiMasterBandpass.lua PakettiMasterBandpassEnsure (~line 210) - API guard, master-track lookup, tagged Doofer insertion · PakettiMasterBandpass.lua paketti_master_bandpass_find (~line 38) - finds only Paketti's tagged master-bandpass Doofer</sub>


## 2. Control cutoff, Q, gain, and filter character

`@shipped @build-verified @runtime-untested`


- Given the Paketti Master Bandpass Doofer exists
- When the user adjusts Cutoff, Q, Gain, or selects a preset model in the dialog
- Then the mapped Doofer macros update the underlying Digital Filter and Gainer chain
- And the chosen model can switch between Butterworth, Chebyshev, Tight Focus, and Gentle Sweep variants

<sub>cite: PakettiMasterBandpass.lua paketti_master_bandpass_preset_xml (~line 51) - Doofer XML with Digital Filter plus Gainer mappings · PakettiMasterBandpass.lua paketti_master_bandpass_apply_preset (~line 187) - changes model preset while preserving macro values</sub>


## 3. Audition through a compact dialog

`@shipped @build-verified @runtime-untested`


- Given the dialog is open
- When the user tweaks the rotaries or closes the dialog
- Then the Cutoff/Q/Gain value labels refresh from Renoise parameter value strings
- And closing the dialog disables the tagged bandpass so the master mix returns to normal

<sub>cite: PakettiMasterBandpass.lua PakettiMasterBandpassShowDialog (~line 314) - ViewBuilder dialog, live labels, reset/view buttons · PakettiMasterBandpass.lua paketti_master_bandpass_timer (~line 294) - disables the audition filter when the dialog closes</sub>


## 4. Drive the bandpass from shortcuts, menus, and MIDI

`@shipped @build-verified @runtime-untested`


- Given Paketti has loaded
- When the user invokes the global commands, Tools menu entries, or MIDI mappings
- Then the dialog, active toggle, hold behavior, and device-focus command are available from Paketti

<sub>cite: PakettiMasterBandpass.lua registrations (~line 429) - global keybindings, MIDI mappings, Tools menu entries · PakettiMasterBandpass.lua PakettiMasterBandpassMomentary (~line 257) - hold mapping reads switch/absolute/trigger messages · main.lua timed_require (~line 1305) - module is loaded during Paketti startup</sub>

