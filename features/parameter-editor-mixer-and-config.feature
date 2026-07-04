# REPORT CARD — 2026-07-04 session: Parameter Editor ↔ Mixer exposure, grid visual, + two feasibility studies
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
  # cite: Research/parameter-editor/feasibility.md | REQUEST #3
  @feasibility
  Scenario: User curates which parameters show, in what order, under what names
    Given a plugin exposes dozens of parameters in a fixed engine order
    When the user opens a per-device "Configure..." dialog
    Then they can hide parameters, reorder the shown ones, and rename them for discoverability
    And the choice persists per device (keyed by device_path) across sessions
    # VERDICT: FEASIBLE (display-layer only; the device's own parameter order is immutable).
    # The editor already builds its own device_parameters list — inject a config layer there.

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
