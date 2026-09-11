# Pure Gherkin test extracted from features/master-bandpass.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/master-bandpass.feature

Feature: Paketti Master Bandpass audition filter
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-09-11. A Paketti-native version of Ledger's Master Bandpass tool:
  # one compact dialog inserts/reuses a tagged Doofer on the master track, exposes
  # Cutoff/Q/Gain macros, offers Butterworth/Chebyshev/focus presets, and provides
  # shortcut/MIDI commands for toggle, hold, and viewing the device.
  #
  # INNARDS:
  #   PakettiMasterBandpass.lua:
  #     PakettiMasterBandpassEnsure / paketti_master_bandpass_find - find or insert
  #       the tagged master Doofer without duplicating it.
  #     paketti_master_bandpass_preset_xml / paketti_master_bandpass_apply_preset -
  #       generate the Doofer XML and swap filter model presets while preserving
  #       current macro values.
  #     PakettiMasterBandpassShowDialog / PakettiMasterBandpassToggleDialog -
  #       compact ViewBuilder control surface with live value labels.
  #     PakettiMasterBandpassToggleActive / PakettiMasterBandpassMomentary /
  #       PakettiMasterBandpassFocusDevice - global/MIDI control surface.
  #   main.lua:
  #     timed_require("PakettiMasterBandpass") loads the module with the API 4+
  #       registration group; runtime commands guard the API 6.1 Doofer dependency.
  #
  # Source studied:
  #   /Users/esaruoho/Downloads/ledger.scripts.MasterBandpass_V0.54.xrnx
  #
  # WATCH: PakettiMasterBandpassEnsure PakettiMasterBandpassShowDialog PakettiMasterBandpassToggleDialog PakettiMasterBandpassToggleActive PakettiMasterBandpassMomentary PakettiMasterBandpassFocusDevice paketti_master_bandpass_preset_xml paketti_master_bandpass_apply_preset
  # RESULT: worktree implementation, direct to local checkout, no PR yet
  # SESSION: master-bandpass.session.md
  # RESULT-LOG >> (auto-maintained by convey hooks - newest below)
  #   2026-09-11  direct-commit  touched: PakettiMasterBandpassEnsure PakettiMasterBandpassShowDialog PakettiMasterBandpassToggleDialog PakettiMasterBandpassToggleActive PakettiMasterBandpassMomentary PakettiMasterBandpassFocusDevice paketti_master_bandpass_preset_xml paketti_master_bandpass_apply_preset

  @shipped @build-verified @runtime-untested
  Scenario: Insert or reuse the tagged master Doofer
    # cite: PakettiMasterBandpass.lua PakettiMasterBandpassEnsure (~line 210) - API guard, master-track lookup, tagged Doofer insertion
    # cite: PakettiMasterBandpass.lua paketti_master_bandpass_find (~line 38) - finds only Paketti's tagged master-bandpass Doofer
    Given a Renoise song with no Paketti Master Bandpass device on the master track
    When the user opens the Paketti Master Bandpass dialog or toggles the filter active
    Then Paketti inserts one native Doofer named "Paketti Master Bandpass" on the master track
    And repeated invocations reuse that tagged device instead of adding duplicates

  @shipped @build-verified @runtime-untested
  Scenario: Control cutoff, Q, gain, and filter character
    # cite: PakettiMasterBandpass.lua paketti_master_bandpass_preset_xml (~line 51) - Doofer XML with Digital Filter plus Gainer mappings
    # cite: PakettiMasterBandpass.lua paketti_master_bandpass_apply_preset (~line 187) - changes model preset while preserving macro values
    Given the Paketti Master Bandpass Doofer exists
    When the user adjusts Cutoff, Q, Gain, or selects a preset model in the dialog
    Then the mapped Doofer macros update the underlying Digital Filter and Gainer chain
    And the chosen model can switch between Butterworth, Chebyshev, Tight Focus, and Gentle Sweep variants

  @shipped @build-verified @runtime-untested
  Scenario: Audition through a compact dialog
    # cite: PakettiMasterBandpass.lua PakettiMasterBandpassShowDialog (~line 314) - ViewBuilder dialog, live labels, reset/view buttons
    # cite: PakettiMasterBandpass.lua paketti_master_bandpass_timer (~line 294) - disables the audition filter when the dialog closes
    Given the dialog is open
    When the user tweaks the rotaries or closes the dialog
    Then the Cutoff/Q/Gain value labels refresh from Renoise parameter value strings
    And closing the dialog disables the tagged bandpass so the master mix returns to normal

  @shipped @build-verified @runtime-untested
  Scenario: Drive the bandpass from shortcuts, menus, and MIDI
    # cite: PakettiMasterBandpass.lua registrations (~line 429) - global keybindings, MIDI mappings, Tools menu entries
    # cite: PakettiMasterBandpass.lua PakettiMasterBandpassMomentary (~line 257) - hold mapping reads switch/absolute/trigger messages
    # cite: main.lua timed_require (~line 1305) - module is loaded during Paketti startup
    Given Paketti has loaded
    When the user invokes the global commands, Tools menu entries, or MIDI mappings
    Then the dialog, active toggle, hold behavior, and device-focus command are available from Paketti
