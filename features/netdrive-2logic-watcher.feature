# =============================================================================
# WIKI PAGE / REPORT CARD: NetDrive 2logic watcher
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiSamples.lua folder watcher/load path and Paketti0G01_Loader.lua watcher preferences
#   thinkspace — netdrive-2logic-watcher.session.md
#   areaspace  — OWNS: detecting new audio files in the configured NetDrive folder, loading them as Paketti instruments, and creating their pattern trigger tracks
#                MUST NOT TOUCH: audio recording itself, external DAW output, existing random-sample loaders, or pre-existing files in the folder
#
# Innards linked back to this card (grep "features/netdrive-2logic-watcher.feature"):
#   PakettiSamples.lua - PakettiNetDriveWatcher* functions poll the watch folder, debounce new files, and load them
#   Paketti0G01_Loader.lua - pakettiNetDriveWatcher* preferences persist enable state, path, stability delay, and poll interval
#
# SESSION:      netdrive-2logic-watcher.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: PakettiNetDriveWatcher PakettiNetDriveWatcherStart PakettiNetDriveWatcherTick PakettiNetDriveWatcherLoadFile PakettiNetDriveWatcherRefreshTimer pakettiNetDriveWatcherFolder pakettiNetDriveWatcherPollSeconds
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-25  direct-commit  touched: PakettiNetDriveWatcher
#   2026-09-25  direct-commit  touched: PakettiNetDriveWatcher PakettiNetDriveWatcherTick PakettiNetDriveWatcherLoadFile PakettiNetDriveWatcherRefreshTimer pakettiNetDriveWatcherFolder pakettiNetDriveWatcherPollSeconds
#   2026-09-24  direct-commit  touched: PakettiNetDriveWatcher
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
    # cite: PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4207) — snapshots old existing file signatures and leaves the newest unseen signature eligible
    # cite: PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4085) — waits for unchanged size and mtime before loading new or rewritten signatures
    # cite: PakettiSamples.lua known_at_startup handling (~line 4195) — baselines genuinely old placeholder files but queues files written after watcher start
    Given the watch folder already contains audio files before the watcher starts
    When the watcher begins polling
    Then old existing files are marked known
    And the newest file is loaded once if its size/mtime signature has not already been loaded
    And placeholder-known files written after the watcher started are queued instead of silently baselined
    And later new or overwritten audio files that remain stable for the configured delay are loaded

  @shipped @code-verified @runtime-untested
  Scenario: Poll at the selected interval and prioritize newest takes
    # cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherPollSeconds (~line 253) — default schema polls once per second
    # cite: Paketti0G01_Loader.lua pakettiPreferences Sync Folder Poll (~line 1634) — exposes 0.5, 1, 5, and 10 second choices
    # cite: PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4135) — stats newest-looking known filenames before the older-file sweep
    # cite: PakettiSamples.lua PakettiNetDriveWatcherRefreshTimer (~line 4364) — reapplies the selected timer interval while the watcher is running
    Given the watch folder contains thousands of older known files
    When a new take appears near the newest end of the folder's sorted filenames
    Then the watcher stats that newest-looking file before the rotating old-file sweep
    And the user can choose a poll interval of 0.5, 1, 5, or 10 seconds from Paketti Preferences
    And changing the preference refreshes the running watcher timer immediately

  @shipped @code-verified @runtime-untested
  Scenario: Pause safely when the watched volume disconnects
    # cite: PakettiSamples.lua PakettiNetDriveWatcherVolumeMounted (~line 3977) — proves the /Volumes mount root before touching the configured child folder
    # cite: PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4140) — backs off for disconnected or failed folder scans
    # cite: PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4349) — starts in paused/offline mode when the configured /Volumes mount is absent
    Given the watched folder is on a /Volumes mount
    When that volume disconnects while Automatically Sync Folder to Samples is enabled
    Then the watcher pauses and reports the folder as unavailable
    And it retries on a slow 10-second backoff instead of touching the dead mount every poll tick
    And the Paketti script remains armed so the watcher can resume when the volume returns

  @shipped @code-verified @runtime-untested
  Scenario: Accept a readable NetDrive folder only after the mount root exists
    # cite: PakettiSamples.lua PakettiNetDriveWatcherPathExists (~line 3968) — safely checks existence behind pcall before using fallback paths
    # cite: PakettiSamples.lua PakettiNetDriveWatcherVolumeMounted (~line 3977) — treats trailing-slash mount names as mounted, then falls back via /Volumes/netdrive before /Volumes/netdrive/2logic
    # cite: preferences.xml pakettiNetDriveWatcherFolder (~line 1140) — stores Esa's /Volumes/netdrive/2logic folder selection
    Given the configured watch folder is /Volumes/netdrive/2logic
    And the /Volumes/netdrive mount root exists
    And the 2logic folder exists and is readable
    When Renoise's /Volumes listing does not report the netdrive mount exactly
    Then the watcher still treats the configured folder as available
    And it proceeds to scan the folder for loadable audio files
    But if /Volumes/netdrive is absent, the watcher does not probe /Volumes/netdrive/2logic

  @shipped @code-verified @runtime-untested
  Scenario: Load each arrival as a fresh Paketti instrument
    # cite: PakettiSamples.lua PakettiNetDriveWatcherLoadFile (~line 4121) — inserts a new instrument, loads the sample, applies loader settings, then forces Forward Loop and Autoseek
    Given a new audio file appears in the watch folder
    When the file is stable and loadable by Renoise
    Then Paketti inserts a new instrument after the current instrument
    And it loads the file into sample slot 1
    And it sets the loaded sample loop mode to Forward Loop after applying loader settings, which is Renoise's enabled loop state
    And it enables Autoseek regardless of the general loader preference
    And it names the sample and instrument from the audio filename

  @shipped @code-verified @runtime-untested
  Scenario: Create an adjacent sequencer trigger track for each loaded arrival
    # cite: PakettiSamples.lua PakettiNetDriveWatcherCreateTriggerTrack (~line 4014) — inserts the new track beside the current sequencer track and writes C-4 + 0G01
    # cite: PakettiSamples.lua PakettiNetDriveWatcherFindSequencerTrack (~line 3993) — resolves non-sequencer selections to a real sequencer-track anchor
    Given a new audio file has loaded from the watch folder
    When Paketti creates the playback trigger
    Then it inserts a new sequencer track directly after the current sequencer-track anchor
    And it never uses a group, master, or send track as the trigger track
    And row 1 of the current pattern contains C-4 for the loaded instrument
    And effect column 1 on that row contains 0G01

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
