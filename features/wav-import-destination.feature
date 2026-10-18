# WHAT THIS CARD SPAWNS:
# Codespace: PakettiDebug.lua and tests/wav_import_hook_regression.lua
# Thinkspace: wav-import-destination.session.md
# Areaspace: Additive WAV hook allocation; preserve every pre-existing instrument.
# SESSION: wav-import-destination.session.md
# RESULT: Worktree only; no commit, push or PR.
# WATCH: PakettiWavImportHookRegister paketti_wav_finish_sample PakettiWavImportHookInvoke paketti_wav_blank_destination paketti_wav_remember_instruments
# RESULT-LOG >>
#   2026-10-18  direct-commit  touched: PakettiWavImportHookRegister PakettiWavImportHookInvoke
Feature: Add dropped WAVs without duplicate empty instruments
  @code-verified @runtime-untested
  Scenario: Fill newly allocated drop destinations
    # cite: PakettiDebug.lua paketti_wav_blank_destination PakettiWavImportHookInvoke
    # cite: tests/wav_import_hook_regression.lua
    Given two existing instrument slots and eight new blank drop destinations
    When Renoise invokes the WAV hook for each selected destination
    Then eight WAVs occupy eight new instruments with no second set of eight slots
    And each sample retains full chromatic mapping

  @code-verified @runtime-untested
  Scenario: Preserve existing slots and keep imports additive
    # cite: PakettiDebug.lua paketti_wav_remember_instruments PakettiWavImportHookInvoke
    Given a selected instrument existed before the drop, even if intentionally empty
    When the WAV hook imports a file
    Then it inserts a separate instrument instead of replacing the existing slot

  @code-verified @runtime-untested
  Scenario: Retain preference-off behavior
    # cite: tests/wav_import_hook_regression.lua
    Given the WAV hook preference is off
    When the registered hook receives a file
    Then the plain sample path runs without creating an instrument or applying a template

  @code-verified @runtime-untested
  Scenario: Finalize every imported WAV after the host finishes the drop
    # cite: PakettiDebug.lua paketti_wav_finish_sample paketti_wav_remember_instruments
    # cite: tests/wav_import_hook_regression.lua
    Given the host adds empty samples or restricts key mapping after the hook returns
    When the next idle runs
    Then every queued imported sample has base note C-4 and range C-0 through B-9
    And empty placeholder samples are removed from its instrument
    And other samples containing audio and the current selection are preserved
    And deleted instruments and changed song documents are skipped

  @code-verified @runtime-untested
  Scenario: Import WAV AIFF AIF FLAC and MP3 through the same additive hook
    # cite: PakettiDebug.lua PakettiWavImportHookRegister PakettiWavImportHookInvoke
    # cite: tests/wav_import_hook_regression.lua
    Given the existing audio import preference is enabled
    When audio hooks register
    Then WAV AIFF AIF FLAC and MP3 each use the same additive importer
    And an existing WAV registration does not prevent registering the other formats
    And the existing toggle preference and keybinding stay compatible

  @code-verified @runtime-untested
  Scenario: Apply embedded WAV cue sets after drop cleanup
    # cite: PakettiDebug.lua paketti_wav_finish_sample PakettiWavImportHookInvoke
    # cite: PakettiWavCueExtract.lua PakettiWavCueParseWavCues
    # cite: tests/wav_import_hook_regression.lua
    Given a WAV with more than one embedded cue point
    When the import finalizes on idle
    Then zero-based cue offsets become one-based Renoise slice frames
    And duplicate and out-of-range offsets are ignored
    And slice markers start at frame 1 and are limited to 255
    And no cue sidecar is written
    And WAVs with zero or one cue remain ordinary samples
