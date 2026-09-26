# =============================================================================
# WIKI PAGE / REPORT CARD: Transient navigation detection
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiTransientNavigation.lua detector defaults and the fixture regression probe
#   thinkspace — transient-navigation-detection.session.md
#   areaspace  — OWNS: Sample Editor Transient Next/Previous detection sensitivity and cached transient positions
#                MUST NOT TOUCH: slice marker insertion, destructive crop behavior, or BPM detector defaults
#
# Innards linked back to this card (grep "features/transient-navigation-detection.feature"):
#   PakettiTransientNavigation.lua - TN_DEFAULTS controls nav-only BeatDetector latch thresholds
#   tests/transient_navigation_detector_regression.py - mirrors the detector against a concrete WAV fixture
#
# SESSION:      transient-navigation-detection.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: TN_DEFAULTS PakettiTransientNextOnset PakettiTransientPreviousOnset PakettiTransientNextPoint PakettiTransientPreviousPoint transient_navigation_detector_regression
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-26  direct-commit  touched: PakettiTransientNextPoint PakettiTransientPreviousPoint
# =============================================================================

Feature: Transient navigation detection
  As a Sample Editor user, I want Transient Next/Previous to re-arm between dense hits, So that visible attacks after the first beat are reachable.

  @shipped @code-verified
  Scenario: Re-arm the nav detector after the opening transient
    # cite: PakettiTransientNavigation.lua TN_DEFAULTS (~line 22) — peak_off is close enough to peak_on for noisy loops to unlatch between hits
    Given a mono sample whose filtered envelope stays above 0.005 after the first hit
    When Transient Navigation runs its lowpass and highpass BeatDetector pair
    Then the detector can unlatch before later attacks
    And Transient Next can advance beyond the first two visible hits

  @shipped @sim-verified
  Scenario: Farmman fixture reaches later visible attacks
    # cite: tests/transient_navigation_detector_regression.py detect (~line 102) — mirrors Lua BeatDetector and zero-crossing filtering
    Given the farmman-369finlp.wav fixture that previously detected only frames 160 and 18132
    When the regression probe compares peak_off 0.005 with the nav default 0.03
    Then the old threshold reproduces the two-hit failure
    And the new threshold detects at least 18 transients
    And the detected positions reach beyond frame 130000

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
