# Pure Gherkin test extracted from features/menu-registration-duplicates.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/menu-registration-duplicates.feature

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
