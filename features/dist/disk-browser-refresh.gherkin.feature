# Pure Gherkin test extracted from features/disk-browser-refresh.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/disk-browser-refresh.feature

Feature: Disk Browser refresh nudge
  As a Paketti user, I want a command that nudges Renoise's Disk Browser to reload its listing, So that newly-created or changed files can appear without manually cycling browser categories.

  @shipped @code-verified @runtime-untested
  Scenario: Refresh command nudges the Disk Browser category away and back
    # cite: Paketti35.lua PakettiRefreshDiskBrowser (line 751) — switches to the adjacent category and restores the original after a one-shot timer
    Given Renoise exposes ApplicationWindow.disk_browser_category
    When the user triggers PakettiRefreshDiskBrowser
    Then Paketti makes the Disk Browser visible
    And temporarily changes to the next Disk Browser category
    And restores the original category after 100 ms
    And reports "Disk Browser refreshed" in the Renoise status bar

  @shipped @code-verified @runtime-untested
  Scenario: Refresh command is reachable from shortcuts and menus
    # cite: Paketti35.lua Refresh Disk Browser keybinding (line 846) — registers the Global:Paketti keybinding
    # cite: PakettiMenuConfig.lua Refresh Disk Browser menu entries (lines 1666, 1678) — exposes Disk Browser and Main Menu entries
    Given Paketti's V3.5 Disk Browser commands are loaded
    When the user opens keybindings or Paketti's Disk Browser menus
    Then Refresh Disk Browser is available beside the existing category controls

  @stock
  Scenario: Existing Disk Browser category controls keep their behaviour
    # cite: Paketti35.lua DiskBrowserCategoryCycler and SetDiskBrowserCategory (lines 731, 740) — pre-existing category controls remain unchanged
    Given the user triggers Cycle Disk Browser Category or Set to Songs/Instruments/Samples/Other
    When Paketti handles the command
    Then Paketti still changes disk_browser_category directly through the existing functions
