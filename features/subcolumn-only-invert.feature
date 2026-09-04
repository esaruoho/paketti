# =============================================================================
# WIKI PAGE / REPORT CARD: Subcolumn-only pattern inversion
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiRequests.lua note subcolumn inversion and PakettiMenuConfig.lua menu exposure
#   thinkspace — subcolumn-only-invert.session.md
#   areaspace  — OWNS: volume, panning, delay, and sample-FX amount inversion in note columns
#                MUST NOT TOUCH: note names, instruments, effect-column numbers, or unrelated subcolumns
#
# Innards linked back to this card (grep "features/subcolumn-only-invert.feature"):
#   PakettiRequests.lua - invert_content_subcolumn applies one requested note-column subcolumn
#   PakettiMenuConfig.lua - Pattern Editor menu entries expose the four specific commands
#
# SESSION:      subcolumn-only-invert.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: invert_content_subcolumn
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: invert_content_subcolumn
# =============================================================================

Feature: Subcolumn-only pattern inversion
  As a Pattern Editor user, I want to invert one note subcolumn at a time, So that volume, pan, delay, or sample-FX edits do not disturb the others.

  @shipped @code-verified @runtime-untested
  Scenario: Invert only the requested note subcolumn
    # cite: PakettiRequests.lua invert_content_subcolumn (~line 9693) — dispatches volume, panning, delay, and samplefx inversion
    Given a pattern selection exists, or no selection exists and the selected track is used
    When the user triggers one of the specific subcolumn inversion commands
    Then Paketti changes only that subcolumn's value range
    And the other note-column subcolumns are left unchanged

  @shipped @code-verified @runtime-untested
  Scenario: Reach the specific invert commands from the Pattern Editor menu
    # cite: PakettiMenuConfig.lua Pattern Editor invert menu entries (~line 2816) — exposes the four commands
    Given Paketti menu entries are loaded
    When the user opens the Pattern Editor Note Columns menu
    Then the volume-only, panning-only, delay-only, and sample-FX-only invert commands are present

  @stock
  Scenario: Existing broad inversion commands remain available
    # cite: PakettiRequests.lua invert_content (~line 9612) — existing all/note/effect inversion path
    Given the user wants to invert every note-column subcolumn or effect-column amount
    When the user triggers the existing broad invert commands
    Then Paketti still runs the original all/note/effect inversion behavior
