# =============================================================================
# WIKI PAGE / REPORT CARD: Menu registration skips exact duplicates
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiFlushMenuEntries duplicate guard and exact duplicate cleanup
#   thinkspace — menu-registration-duplicates.session.md
#   areaspace  — OWNS: startup menu-entry duplicate handling and known exact duplicate fixes
#                MUST NOT TOUCH: per-context menu preference semantics, shortcut hint injection, menu sorting order
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "menu-registration-duplicates"):
#   Paketti0G01_Loader.lua - PakettiFlushMenuEntries duplicate guard
#   PakettiMenuConfig.lua - Pattern/Phrase Init Preferences duplicate source cleanup
#
# Commit log:   worktree  Menu registration exact duplicate startup guard
# SESSION:      menu-registration-duplicates.session.md
# RESULT:       Feature delivery worktree (direct to main, no PR); card worktree
#
# WATCH: PakettiFlushMenuEntries Paketti Pattern / Phrase Init Preferences
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-26  direct-commit  touched: Paketti Pattern / Phrase Init Preferences
#   2026-09-26  direct-commit  touched: Paketti Pattern / Init
#   2026-09-25  direct-commit  touched: Paketti /
#   2026-09-25  direct-commit  touched: Paketti /
#   2026-09-25  direct-commit  touched: PakettiFlushMenuEntries Paketti Pattern / Phrase Init Preferences
# =============================================================================

Feature: Menu registration skips exact duplicates
  As a Paketti maintainer, I want exact duplicate menu registrations to be detected before Renoise sees them, So that one duplicate path cannot abort Paketti startup.

  @shipped @code-verified @runtime-untested
  Scenario: Duplicate pending menu names are skipped during sorted flush
    # cite: Paketti0G01_Loader.lua PakettiFlushMenuEntries
    Given boot-time menu entries have been queued for sorted registration
    When two pending entries have the same exact Renoise menu name
    Then the first one is registered
    And the later duplicate is skipped with a console message naming the duplicate path
    And Paketti startup continues instead of raising Renoise's invalid menu entry error

  @shipped @code-verified @runtime-untested
  Scenario: Existing menu entries are not registered again
    # cite: Paketti0G01_Loader.lua PakettiFlushMenuEntries
    Given a menu entry already exists in Renoise before the flush reaches a pending row
    When the pending row has the same exact name
    Then the pending row is skipped before calling add_menu_entry

  @shipped @code-verified @runtime-untested
  Scenario: Pattern/Phrase Init Preferences keeps one Preferences path
    # cite: PakettiMenuConfig.lua Main Menu:Tools:Paketti:!Preferences:Paketti Pattern / Phrase Init Preferences...
    Given the Main Menu:Tools context is enabled
    When PakettiMenuConfig.lua registers Pattern/Phrase Init Preferences entries
    Then the Preferences path appears only once
    And the separate Pattern Editor and Phrases menu paths remain available
