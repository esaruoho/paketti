# =============================================================================
# WIKI PAGE / REPORT CARD: Transient navigation detection
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiTransientNavigation.lua adaptive Schmitt detector and the fixture regression probe
#   thinkspace — transient-navigation-detection.session.md
#   areaspace  — OWNS: Sample Editor Transient Next/Previous detection sensitivity and cached transient positions
#                MUST NOT TOUCH: slice marker insertion, destructive crop behavior, or BPM detector defaults
#
# Innards linked back to this card (grep "features/transient-navigation-detection.feature"):
#   PakettiTransientNavigation.lua - TN_DEFAULTS controls nav-only adaptive Schmitt timing and hysteresis
#   PakettiTransientNavigation.lua - tn_create_adaptive_schmitt catches dense attacks missed by the old level-Schmitt detector
#   tests/transient_navigation_detector_regression.py - mirrors the adaptive Schmitt detector against a concrete WAV fixture
#
# SESSION:      transient-navigation-detection.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: TN_DEFAULTS tn_create_adaptive_schmitt tn_debug_positions PakettiTransientNextOnset PakettiTransientPreviousOnset PakettiTransientNextPoint PakettiTransientPreviousPoint transient_navigation_detector_regression
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-29  direct-commit  touched: transient_navigation_detector_regression
#   2026-09-27  direct-commit  touched: TN_DEFAULTS tn_create_adaptive_schmitt tn_debug_positions
#   2026-09-26  direct-commit  touched: PakettiTransientNextPoint PakettiTransientPreviousPoint
# =============================================================================

Feature: Transient navigation detection
  As a Sample Editor user, I want Transient Next/Previous to re-arm between dense hits, So that visible attacks after the first beat are reachable.

  @shipped @code-verified
  Scenario: Re-arm the adaptive Schmitt detector after the opening transient
    # cite: PakettiTransientNavigation.lua TN_DEFAULTS (~line 22) — fast/slow envelope timing and novelty hysteresis replace fixed level thresholds
    Given a mono sample whose filtered envelope stays above 0.005 after the first hit
    When Transient Navigation runs its lowpass and highpass adaptive Schmitt pair
    Then the detector reacts to sharp envelope rises above the recent background
    And it can unlatch before later attacks even when the absolute level remains high
    And Transient Next can advance beyond the first two visible hits

  @shipped @sim-verified
  Scenario: Farmman fixture reaches later visible attacks
    # cite: tests/transient_navigation_detector_regression.py detect_adaptive (~line 149) — mirrors Lua adaptive Schmitt and zero-crossing filtering
    Given the farmman-369finlp.wav fixture that previously detected only frames 160 and 18132
    When the regression probe compares the old level-Schmitt detector with the adaptive Schmitt detector
    Then the old threshold reproduces the two-hit failure
    And the adaptive Schmitt detector detects at least 80 transients
    And the detected positions include the previously skipped middle range
    And the detected positions reach beyond frame 130000

  @shipped @code-verified
  Scenario: Print detector internals for debugging
    # cite: PakettiTransientNavigation.lua tn_debug_positions (~line 111) — prints labeled frame lists
    # cite: PakettiTransientNavigation.lua tn_start_detection (~line 220) — prints legacy level-Schmitt, adaptive Schmitt, and final snapped positions
    Given Transient Navigation runs detection
    When it finishes collecting candidates
    Then the scripting console receives the legacy level-Schmitt raw hit list
    And it receives the adaptive Schmitt raw hit list
    And it receives the candidates suppressed by minimum spacing with their frame distances
    And it receives the final snapped transient frame list

  @shipped @code-verified
  Scenario: Use adaptive Schmitt hits as the final candidate source
    # cite: PakettiTransientNavigation.lua tn_create_adaptive_schmitt (~line 119) — fast envelope, slow background, novelty and ratio hysteresis
    # cite: PakettiTransientNavigation.lua tn_start_detection (~line 217) — filters adaptive Schmitt hits through spacing and zero-cross snapping
    Given the old level-Schmitt detector skips attacks while its envelope remains latched
    When adaptive Schmitt candidates pass the novelty and ratio thresholds
    Then Paketti uses those candidates as the transient navigation source
    And the final 10ms minimum-distance and zero-crossing pass still runs over the adaptive candidates

  @stock
  Scenario: Navigation stays cache-backed and non-slicing
    # cite: PakettiTransientNavigation.lua tn_start_detection (~line 112) — fills tn_cached_positions without inserting slice markers
    Given the user triggers Transient Next or Previous
    When detection is needed
    Then Paketti populates transient navigation cache positions
    And it does not create or delete slice markers

  @shipped @code-verified
  Scenario: Expose no-zoom navigation with obvious demo labels
    # cite: PakettiTransientNavigation.lua registrations (~line 590) — No Zoom menu/keybinding aliases call the point-cursor functions
    Given the user wants to demonstrate transient stepping without changing the waveform zoom
    When they bind or trigger Transient Next Without Zoom
    Then Paketti calls the point-cursor transient navigation path
    And the existing Point Cursor bindings remain available
