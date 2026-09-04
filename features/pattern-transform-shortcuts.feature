# =============================================================================
# WIKI PAGE / REPORT CARD: Pattern transform shortcuts
#
# WHAT THIS CARD SPAWNS:
#   codespace  — interpolation menus, pattern LPB expansion, and selection/row note transpose mappings
#   thinkspace — pattern-transform-shortcuts.session.md
#   areaspace  — OWNS: small Pattern Editor transform commands exposed as shortcuts/MIDI
#                MUST NOT TOUCH: sample buffers, device chains, or instrument loading workflows
#
# Innards linked back to this card (grep "features/pattern-transform-shortcuts.feature"):
#   PakettiRequests.lua - exponential interpolation implementation
#   PakettiPatternEditor.lua - LPB1-to-LPB4 pattern expansion command
#   PakettiMidi.lua - selection-or-row note transpose helper and mappings
#
# SESSION:      pattern-transform-shortcuts.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: interpolate_current_subcolumn_exponential PakettiExpandPatternLPB1ToLPB4 PakettiTransposeNotesInSelectionOrRow
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-04  direct-commit  touched: interpolate_current_subcolumn_exponential PakettiExpandPatternLPB1ToLPB4 PakettiTransposeNotesInSelectionOrRow
# =============================================================================

Feature: Pattern transform shortcuts
  As a Paketti user, I want small Pattern Editor transforms exposed consistently, So that interpolation, timing expansion, and note transpose operations can be performed from menus, shortcuts, or MIDI without opening a custom workflow.

  @shipped @code-verified @runtime-untested
  Scenario: Exponential interpolation is visible from the Pattern Editor menu
    # cite: PakettiRequests.lua interpolate_current_subcolumn_exponential (line 8656) — implements the t^2 interpolation command family
    # cite: PakettiMenuConfig.lua exponential interpolation menu entries (line 2900) — exposes current-subcolumn and column-specific actions
    Given the user is in the Pattern Editor with editable pattern data
    When the user opens Paketti pattern interpolation commands
    Then exponential interpolation commands are available beside the existing linear interpolation entries
    And the current-subcolumn command dispatches to volume, panning, delay, sample-FX, or effect-column interpolation from cursor context

  @shipped @code-verified @runtime-untested
  Scenario: Expand the current pattern from LPB1-style spacing to LPB4-style spacing
    # cite: PakettiPatternEditor.lua PakettiExpandPatternLPB1ToLPB4 (line 1899) — expands the current pattern by 4x and sets LPB to 4
    # cite: PakettiMenuConfig.lua LPB expansion menu entry (line 2907) — exposes the command in Pattern Editor menus
    Given the selected pattern is short enough that four times its length is at most 512 rows
    When the user triggers Pattern Expand LPB1 16 Rows to LPB4 64 Rows
    Then Paketti expands the pattern data by a factor of four
    And sets the song LPB to 4
    And keeps the selected line aligned to the expanded musical position

  @shipped @code-verified @runtime-untested
  Scenario: Transpose selected notes or the current row from shortcuts and MIDI
    # cite: PakettiMidi.lua PakettiTransposeNotesInSelectionOrRow (line 1896) — transposes only note columns in selection or selected note column
    # cite: PakettiMidi.lua transpose MIDI/keybindings (line 1975) — exposes up/down trigger commands and a rotary mapping
    # cite: PakettiMenuConfig.lua transpose menu entries (line 2803) — exposes the same actions in the Note Columns menu
    Given the user has a pattern selection or a selected note column on the current row
    When the user triggers transpose up, transpose down, or turns the transpose rotary mapping
    Then Paketti changes playable note values by semitone steps
    And clamps notes between C-0 and B-9
    And leaves empty cells, note-off values, and effect columns unchanged
