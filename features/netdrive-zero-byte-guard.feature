# WIKI PAGE / REPORT CARD: Skip empty NetDrive recordings
# WHAT THIS CARD SPAWNS:
#   codespace — PakettiSamples.lua watcher guards; tests/netdrive_zero_byte_guard.py
#   thinkspace — netdrive-zero-byte-guard.session.md and bundled transcripts
#   areaspace — OWNS: zero-byte detection and recovery in the NetDrive watcher
#                MUST NOT TOUCH: external recording, general loaders, existing song contents
# SESSION: netdrive-zero-byte-guard.session.md
# RESULT: Worktree implementation; no commit or PR. Files: PakettiSamples.lua,
#   tests/netdrive_zero_byte_guard.py, PLAN.md, this card/session/transcripts and generated views.
# WATCH: PakettiNetDriveWatcherLoadFile PakettiNetDriveWatcherProcessQueue PakettiNetDriveWatcherTick PakettiNetDriveWatcherStart
# RESULT-LOG >>
#   2026-10-07  direct-commit  touched: PakettiNetDriveWatcherLoadFile PakettiNetDriveWatcherProcessQueue

Feature: Skip empty NetDrive recordings
  As a user recording in Ableton, I want empty placeholders skipped before import.

  @built @sim-verified @runtime-untested
  Scenario: Hold empty files until bytes arrive and stabilize
    # cite: PakettiSamples.lua PakettiNetDriveWatcherTick queue_or_load_changed_file
    # verify: python3 tests/netdrive_zero_byte_guard.py
    Given a new zero-byte audio file in the watched folder
    When repeated watcher polls observe it
    Then no import is queued and the same empty signature produces only one status notice
    And after bytes arrive the file must pass the stability delay before being queued

  @built @sim-verified @runtime-untested
  Scenario: Reject a file truncated after queuing
    # cite: PakettiSamples.lua PakettiNetDriveWatcherProcessQueue and PakettiNetDriveWatcherLoadFile
    # verify: python3 tests/netdrive_zero_byte_guard.py
    Given a queued recording becomes empty before loading
    When the queue or loader rechecks its size
    Then the sample decoder and song mutation are not reached
    And the status reports "NetDrive watcher: Zero Bytes - stop loading"
    And no failure retry is counted and no cutoff advances

  @built @code-verified @runtime-untested
  Scenario: Skip empty files during startup
    # cite: PakettiSamples.lua PakettiNetDriveWatcherStart
    Given the watch folder contains a recent zero-byte audio file
    When the watcher starts
    Then it baselines the empty signature without queuing import
    And later positive-size changes remain detectable by polling
