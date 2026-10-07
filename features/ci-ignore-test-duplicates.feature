# WHAT THIS CARD SPAWNS:
# codespace: .spine/check.py _source_lua_paths; .github/workflows/main.yml validate
# thinkspace: ci-ignore-test-duplicates.session.md
# areaspace: static CI scan inputs; preserve runtime registration validation
# SESSION: ci-ignore-test-duplicates.session.md
# RESULT: Worktree change; no commit, push, or PR. Files: .spine/check.py,
# .github/workflows/main.yml, PLAN.md, this card and its session.
# WATCH: _source_lua_paths _duplicate_globals _undeclared_calls
# RESULT-LOG >>
Feature: Ignore test fixtures in CI source scans
  @build-verified
  Scenario: Test helper copies never create source duplicate failures
    # cite: .spine/check.py _source_lua_paths and _duplicate_globals
    Given a source helper is copied into tests/ and nested test folders
    When the duplicate global function scan runs
    Then test definitions are excluded and no duplicate is reported

  @build-verified
  Scenario: Real source duplicates remain detectable
    # cite: .spine/check.py _duplicate_globals
    Given two source files outside tests/ define the same helper
    When the duplicate scan runs
    Then both source locations are reported
    And source files with names such as contest.lua remain included

  @code-verified
  Scenario: Registration validation keeps the real startup path
    # cite: .github/workflows/main.yml validate
    # cite: .spine/harness.lua isolated_dofile
    Given the GitHub Actions validation job runs
    When it invokes check.py
    Then the registration harness loads main.lua and its dependencies
