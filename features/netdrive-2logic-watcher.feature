# =============================================================================
# WIKI PAGE / REPORT CARD: NetDrive 2logic watcher
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiSamples.lua folder watcher/load path and Paketti0G01_Loader.lua watcher preferences
#   thinkspace — netdrive-2logic-watcher.session.md
#   areaspace  — OWNS: detecting new audio files in the configured NetDrive folder and loading them as Paketti instruments
#                MUST NOT TOUCH: audio recording itself, external DAW output, existing random-sample loaders, or pre-existing files in the folder
#
# Innards linked back to this card (grep "features/netdrive-2logic-watcher.feature"):
#   PakettiSamples.lua - PakettiNetDriveWatcher* functions poll the watch folder, debounce new files, and load them
#   Paketti0G01_Loader.lua - pakettiNetDriveWatcher* preferences persist enable state, path, and stability delay
#
# SESSION:      netdrive-2logic-watcher.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: PakettiNetDriveWatcher PakettiNetDriveWatcherStart PakettiNetDriveWatcherTick PakettiNetDriveWatcherLoadFile pakettiNetDriveWatcherFolder
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-23  direct-commit  touched: PakettiNetDriveWatcher
#   2026-09-22  direct-commit  touched: PakettiNetDriveWatcher PakettiNetDriveWatcherStart PakettiNetDriveWatcherTick PakettiNetDriveWatcherLoadFile pakettiNetDriveWatcherFolder
# =============================================================================

Feature: NetDrive 2logic watcher
  As a Paketti user recording audio into a known handoff folder, I want Paketti to notice new files under /private/tmp/netdrive/2logic, So that Renoise can load each completed take without a manual file picker.

  @shipped @code-verified @runtime-untested
  Scenario: Keep the global default off while allowing Esa's local preference to arm it
    # cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherEnabled (~line 250) — default schema is off for new installs
    # cite: preferences.xml pakettiNetDriveWatcherEnabled (~line 3054) — Esa's local tool preferences arm the watcher
    Given Paketti is installed on a new machine with no saved preference
    When preferences are initialized
    Then the NetDrive watcher is off by default
    And Esa's local saved preference can still turn it on

  @shipped @code-verified @runtime-untested
  Scenario: Watch the default 2logic folder when armed
    # cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherFolder (~line 251) — defaults the watch path to /private/tmp/netdrive/2logic
    # cite: PakettiSamples.lua PakettiNetDriveWatcherGetFolder (~line 3919) — reads the configured folder with the same default fallback
    Given the NetDrive watcher has no custom folder configured
    When the watcher starts
    Then it watches /private/tmp/netdrive/2logic

  @shipped @code-verified @runtime-untested
  Scenario: Ignore old existing files and load changed file signatures
    # cite: PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4085) — snapshots old existing file signatures and leaves the newest unseen signature eligible
    # cite: PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4037) — waits for unchanged size and mtime before loading new or rewritten signatures
    Given the watch folder already contains audio files before the watcher starts
    When the watcher begins polling
    Then old existing files are marked known
    And the newest file is loaded once if its size/mtime signature has not already been loaded
    And later new or overwritten audio files that remain stable for the configured delay are loaded

  @shipped @code-verified @runtime-untested
  Scenario: Load each arrival as a fresh Paketti instrument
    # cite: PakettiSamples.lua PakettiNetDriveWatcherLoadFile (~line 3988) — inserts a new instrument, applies the default XRNI, loads the sample, and applies loader settings
    Given a new audio file appears in the watch folder
    When the file is stable and loadable by Renoise
    Then Paketti inserts a new instrument after the current instrument
    And it loads the file into sample slot 1
    And it names the sample and instrument from the audio filename

  @shipped @code-verified @runtime-untested
  Scenario: Expose manual control for the watcher
    # cite: PakettiSamples.lua keybinding and menu registrations (~line 4165) — toggle, MIDI mapping, menu entry, and folder selector
    Given Paketti has loaded its sample tools
    When the user wants to control the NetDrive watcher
    Then the watcher can be toggled from a Global keybinding, MIDI trigger mapping, and Tools menu entry
    And the watched folder can be changed from a Tools menu entry

  @stock
  Scenario: Existing sample loaders remain separate
    # cite: PakettiSamples.lua loadRandomSample (~line 4829) — existing manual random-folder loader
    Given the user invokes an existing random sample loader
    When that loader prompts for or receives a folder
    Then the NetDrive watcher state is not required for that manual workflow
