# REPORT CARD — 2026-07-04 session: Parameter Editor ↔ Mixer exposure, grid visual, per-plugin config, + one feasibility study
# (updated: REQUEST #3 per-plugin config graduated @feasibility -> @built @in-renoise, commit eec944cc)
#
# WHAT THIS CARD SPAWNS
#   Codespace : PakettiCanvasExperiments.lua (the Selected-Device Parameter Editor —
#               the drag handler's Expose-on-Mixer, the render bar loop, the option
#               checkboxes, and the new PakettiExposeAutomatedParamsOnMixer global +
#               its keybinding/MIDI/menu).
#   Thinkspace : parameter-editor-mixer-and-config.session.md (spawning chat) +
#                Research/parameter-editor/feasibility.md (studies for #3, #6).
#   Areaspace  : the Parameter Editor canvas + its relationship to the Renoise Mixer
#               (DeviceParameter.show_in_mixer / .is_automated). Does NOT touch the
#               automation-write engine, A/B crossfade, or PhraseGrid snapshotting.
#
# GRADE LEGEND (honest)
#   @built            — code written, luac -p clean, .spine/check.py clean, committed+pushed.
#   @logic-verified   — correctness argued by hand against the Renoise API.
#   @in-renoise       — confirmed working live in Renoise this session.
#   @untested         — not yet exercised live.
#   @feasibility      — study only; no shipping code (see the .md).

Feature: Parameter Editor exposes on the Mixer the parameter you're modifying
  # cite: PakettiCanvasExperiments.lua drag handler (Edit-A branch) | REQUEST #1
  # BUG: show_in_mixer=true was nested inside `if follow_automation`, so with
  # Automation Sync OFF, dragging a bar never exposed the param on the mixer.
  @built @logic-verified
  Scenario: Dragging a parameter with "Expose on Mixer" on surfaces it in the mixer
    Given the Parameter Editor is open on a device
    And "Expose on Mixer" is enabled
    And Automation Sync is OFF
    When I drag a parameter bar
    Then that parameter's show_in_mixer becomes true
    And it appears in the Renoise mixer immediately

Feature: One-shot "Expose Automated Parameters on Mixer"
  # cite: PakettiCanvasExperiments.lua PakettiExposeAutomatedParamsOnMixer + registrations | REQUEST #2
  @built @logic-verified
  Scenario: Surface only the automated parameters of the selected track
    Given the selected track has devices, some of whose parameters are automated
    When I trigger "Expose Automated Parameters on Mixer" (keybinding / MIDI / Mixer:Paketti Gadgets menu)
    Then every parameter with is_automated == true gets show_in_mixer = true
    And parameters WITHOUT automation are left alone (not "show all")
    And a status line reports how many were exposed

Feature: Grid-stripe visual mode for the Parameter Editor
  # cite: PakettiCanvasExperiments.lua render bar loop + grid_stripe_checkbox | REQUEST #4
  @built @untested
  Scenario: Alternating column backgrounds for grid-style reading
    Given the Parameter Editor is open
    When I enable the "Grid stripes" checkbox
    Then odd parameter columns paint a light background and even columns a dark one
    And the parameter bars draw on top, so columns read as a checker grid

Feature: Per-plugin Parameter Editor configuration (reorder / hide / rename)
  # cite: PakettiCanvasExperiments.lua (BuildDisplayedParameters/ApplyDisplayConfig/OpenConfigDialog +
  #       Configure button/menu/keybinding) + Paketti0G01_Loader.lua (config schema + Upsert/Remove
  #       helpers + CustomOrderingMode pref) | REQUEST #3
  # SHIPPED across commits 50ce876e (mode pref), 8f8ccc7c (build-path refactor), 6569fbc2 (config
  # schema), and eec944cc (apply-layer wiring + Configure dialog + reorder/hide/rename). Original
  # feasibility study: Research/parameter-editor/feasibility.md.
  @built @in-renoise
  Scenario: Mode OFF or no config behaves exactly like today (no-op)
    Given the Parameter Editor builds its parameter list
    When Customized Ordering Mode is OFF, or ON but the device has no saved config
    Then the displayed parameter list equals the baseline list byte-for-byte
    And the Wavetable Mod *LFO skip-first-3 rule still applies
    # verified: GetDisplayedParameterSummary == GetBaseParameterSummary (Mixer/TrackVolPan)

  Scenario: User curates which parameters show, in what order, under what names
    Given Customized Ordering Mode is ON
    When the user opens the "Configure..." dialog (editor button / Mixer:Paketti Gadgets menu /
      keybinding "Global:Paketti:Configure Parameter Editor for Selected Device")
    And hides parameters (Show checkbox), reorders them (up/down), and renames displayed labels
    And presses Save
    Then the config is stored keyed by device.device_path and persisted (Upsert + save_as)
    And the editor rebuilds so hidden params drop out, order follows the config, and labels rename
    And the real device parameters/order/names are never mutated (display layer only)
    # verified live via BuildDisplayedParameters: moved last param to first + renamed, hid the middle
    # one -> count 3->2, position 1 = renamed label with original name preserved

  Scenario: Reset to Plugin Default restores the baseline
    Given a device has a saved config
    When the user presses "Reset to Plugin Default"
    Then the config entry is removed and the editor rebuilds to the baseline order/count
    # verified: after Remove, displayed summary == baseline summary

Feature: Renoise as a round-trip sample editor for Ableton Live
  # cite: Research/parameter-editor/feasibility.md | REQUEST #6
  @feasibility
  Scenario: Edit a Live sample in Renoise and save it back so Live reloads it
    Given a sample referenced by an Ableton Live set at a known file path
    When I load it into Renoise, edit it, and press "Save Back"
    Then Renoise overwrites the original WAV in place and removes its .asd sidecar
    And Live picks up the new audio on next clip load (full auto-reload needs AbletonOSC/M4L)
    # VERDICT: Renoise side EASY; the "Live reloads automatically" half is HARD (cross-app) —
    # achievable only via AbletonOSC / Max-for-Live, not from Renoise alone.
