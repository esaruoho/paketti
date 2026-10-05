# AHDSR sample-loader inspection

Read-only source and preset inspection; no PakettiMCP calls or instrument changes.

PakettiSamples.lua PakettiApplyLoaderModulationSettings (~336) checks preferences.pakettiPitchbendLoaderEnvelope.value and sets the first modulation set's Volume AHDSR device.is_active=true when enabled. It does not assign Release or any other AHDSR parameter. pakettiPreferencesDefaultInstrumentLoader loads the configured XRNI and calls this helper (~394); drumkit and other sample-import paths also call it. No changes were made to PakettiSamples.lua during the Timestretch reload fix (git diff empty).

Both bundled Presets/12st_Pitchbend.xrni and Presets/12st_Pitchbend_Drumkit_C0.xrni store Release normalized value 0.118563108. This inspection does not establish that this value displays 480 ms in Renoise; normalized time is not linearly mapped milliseconds. The hardcoded 480/20000 assignment previously found was in the destructive Timestretch activation handlers, not the loader. Those handlers have been removed.

Conclusion: loader preference-controlled activation remains intact, but an explicit “sample loaded + AHDSR preference on → Release 480 ms” behavior is not present in the inspected loader. It must not be claimed verified. The saved preferences currently have pakettiPitchbendLoaderEnvelope=false; no preference was changed.
