# WHAT THIS CARD SPAWNS:
# codespace: PakettiForeignSnippets.lua and tests/disk-browser-auto-toggle.lua
# thinkspace: disk-browser-auto-toggle.session.md
# areaspace: automatic Disk Browser state, menu checkmark and persistence; preserve explicit popup modes
# SESSION: disk-browser-auto-toggle.session.md
# RESULT: Worktree fix; no commit, push or PR. Source, regression test, card/session bundle, INDEX and generated views changed.
# WATCH: pakettiAutoHideDiskBrowserToggle pakettiAutoHideDiskBrowserIsEnabled pakettiAutoDiskBrowserNewDocumentHandler
# RESULT-LOG >>
#   2026-10-23  direct-commit  touched: pakettiAutoHideDiskBrowserToggle pakettiAutoHideDiskBrowserIsEnabled
Feature: Switch automatic Disk Browser control off from its checked menu
  @code-verified @runtime-untested
  Scenario: A checked entry disables and saves automation
    # cite: PakettiForeignSnippets.lua pakettiAutoHideDiskBrowserToggle; tests/disk-browser-auto-toggle.lua
    Given the saved mode is Hide or Show
    When the user invokes the toggle
    Then the mode becomes Do Nothing and preferences.xml is saved
    And the menu checkmark becomes false

  @code-verified @runtime-untested
  Scenario: Disabled automation leaves browser visibility alone
    # cite: PakettiForeignSnippets.lua pakettiAutoDiskBrowserNewDocumentHandler; tests/disk-browser-auto-toggle.lua
    Given mode zero and either browser visibility
    When a song loads
    Then browser visibility is unchanged

  @code-verified @runtime-untested
  Scenario: Read observable values for explicit modes
    # cite: PakettiForeignSnippets.lua pakettiAutoDiskBrowserNewDocumentHandler; tests/disk-browser-auto-toggle.lua
    Given mode Hide or Show chosen through preferences
    When a song loads
    Then the corresponding browser visibility is applied
    And toggling from Do Nothing enables Hide
