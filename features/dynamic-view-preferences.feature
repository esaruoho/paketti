# WHAT THIS CARD SPAWNS:
# codespace: PakettiDynamicViews.lua; tests/dynamic-view-preferences.lua
# thinkspace: dynamic-view-preferences.session.md
# areaspace: standalone Dynamic View preferences initialization; preserve navigation
# SESSION: dynamic-view-preferences.session.md
# RESULT: Worktree fix; no commit, push or PR. Source, test, PLAN, card, session and generated views.
# WATCH: loadDynamicViewPreferences
# RESULT-LOG >>
Feature: Initialize Dynamic View preferences as a standalone document
  @code-verified @runtime-untested
  Scenario: The loader has already assigned a DocumentList global
    # cite: PakettiDynamicViews.lua initialization and loadDynamicViewPreferences; tests/dynamic-view-preferences.lua
    Given DynamicViewPrefs contains the loader's DocumentList
    When Dynamic Views initializes or reloads
    Then a fresh standalone DocumentNode loads preferencesDynamicView.xml
    And existing saved values are preserved
    And missing properties default to Change Nothing

  @code-verified @runtime-untested
  Scenario: No saved preferences file exists
    # cite: PakettiDynamicViews.lua loadDynamicViewPreferences; tests/dynamic-view-preferences.lua
    Given preferencesDynamicView.xml does not exist
    When Dynamic Views initializes
    Then all view properties retain their default value of one
