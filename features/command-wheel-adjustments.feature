# =============================================================================
# WIKI PAGE / REPORT CARD: Command Wheel adjustments use one router
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiCommandWheel.lua adjustment router and generated nudge keybindings
#   thinkspace — command-wheel-adjustments.session.md
#   areaspace  — OWNS: Command Wheel index/value adjustment keybindings and compatibility wrappers
#                MUST NOT TOUCH: mode selection semantics, pattern write placement, MIDI absolute value mapping
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "command-wheel-adjustments"):
#   PakettiCommandWheel.lua - adjustment router, wrappers, generated keybinding table
#
# Commit log:   worktree  Command Wheel adjustment refactor
# SESSION:      command-wheel-adjustments.session.md
# RESULT:       Feature delivery worktree (direct to main, no PR); card worktree
#
# WATCH: PakettiCommandWheelAdjust PakettiCommandWheelAdjustIndex PakettiCommandWheelAdjustValue PakettiCommandWheelMakeAdjustInvoke paketti_command_wheel_adjust_keybindings
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-25  direct-commit  touched: PakettiCommandWheelAdjust PakettiCommandWheelAdjustIndex PakettiCommandWheelAdjustValue PakettiCommandWheelMakeAdjustInvoke paketti_command_wheel_adjust_keybindings
# =============================================================================

Feature: Command Wheel adjustments use one router
  As a Paketti maintainer, I want Command Wheel index and value nudges to share one adjustment path, So that adding new deltas does not require bespoke functions and repeated keybinding registrations.

  @shipped @code-verified @runtime-untested
  Scenario: Index and value keybindings share one adjustment router
    # cite: PakettiCommandWheel.lua PakettiCommandWheelAdjust
    # cite: PakettiCommandWheel.lua paketti_command_wheel_adjust_keybindings
    Given the Command Wheel exposes Index +/-1 and Value +/-1/+/-10 keybindings
    When those keybindings are registered
    Then they are generated from one table of target/delta pairs
    And each keybinding invokes PakettiCommandWheelAdjust(target, delta) through a per-row callback factory

  @shipped @code-verified @runtime-untested
  Scenario: Existing internal wrapper names remain callable
    # cite: PakettiCommandWheel.lua PakettiCommandWheelIndexNext
    # cite: PakettiCommandWheel.lua PakettiCommandWheelIndexPrev
    # cite: PakettiCommandWheel.lua PakettiCommandWheelValueUp1
    # cite: PakettiCommandWheel.lua PakettiCommandWheelValueDown10
    Given existing dialog buttons and MIDI button mappings call the older wrapper functions
    When those functions run
    Then they delegate to the shared adjustment router
    And the existing call sites do not need to change

  @shipped @code-verified @runtime-untested
  Scenario: Index adjustment wraps through the valid index range
    # cite: PakettiCommandWheel.lua PakettiCommandWheelAdjustIndex
    Given the Command Wheel has a current mode with a maximum index
    When an index delta moves before the first index or past the maximum index
    Then the selected index wraps into the valid range
    And the selected target value is resynced for macro, MIDI CC, and device modes
