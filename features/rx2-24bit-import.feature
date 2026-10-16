# WHAT THIS CARD SPAWNS:
# Codespace: PakettiRX2Decode.lua and tests/rx2_wav_regression.lua
# Thinkspace: rx2-24bit-import.session.md
# Areaspace: Owns pure-Lua RX2 WAV serialization; external SDK decoding is unchanged.
# SESSION: rx2-24bit-import.session.md
# RESULT: Worktree changes only; no commit, push, or PR created.
# Files: PakettiRX2Decode.lua, tests/rx2_wav_regression.lua, PLAN.md and this card/session.
# WATCH: PakettiRX2WindowsImportDiagnostic pakettiRX2DebugDialog pcm_to_wav PakettiRX2ImportNative clamp_sample PakettiRX2DecodeFile PakettiRX2ImportNativeSliced pakettiRX2NativeDecoder
# RESULT-LOG >>
#   2026-10-17  direct-commit  touched: pakettiRX2DebugDialog PakettiRX2ImportNative PakettiRX2ImportNativeSliced pakettiRX2NativeDecoder
#   2026-10-16  direct-commit  touched: pcm_to_wav PakettiRX2ImportNative
Feature: Preserve RX2 sample depth during pure-Lua import
  @code-verified @runtime-untested
  Scenario: Preserve real 24-bit stereo audio
    # cite: PakettiRX2Decode.lua pcm_to_wav and PakettiRX2ImportNative
    # cite: tests/rx2_wav_regression.lua verify
    Given the user's 24-bit Power Chord RX2 with 100174 stereo frames
    When the pure-Lua importer writes its temporary WAV
    Then the header declares 24-bit PCM with matching byte rate and block alignment
    And all 200348 decoded samples are preserved exactly

  @code-verified @runtime-untested
  Scenario: Preserve signed PCM and align mono chunks
    # cite: tests/rx2_wav_regression.lua verify
    Given mono and stereo fixtures at 16 and 24 bits including signed extrema
    When the pure-Lua importer writes its WAV
    Then each signed sample is preserved exactly
    And odd data sizes have a padding byte excluded from the data length
    And the RIFF length includes padding

  @code-verified @runtime-untested
  Scenario: Import supported sample depths through Lua on Windows too
    # cite: PakettiRX2Decode.lua clamp_sample pcm_to_wav PakettiRX2DecodeFile
    # cite: Paketti0G01_Loader.lua pakettiRX2NativeDecoder
    # cite: tests/rx2_wav_regression.lua verify
    Given 8-, 16-, and 24-bit mono or stereo RX2 audio
    When Lua decodes the audio and builds the import WAV
    Then signed samples survive codec roundtrip and WAV serialization
    And 8-bit WAV stores unsigned bytes with 128 as silence
    And Lua is enabled by default including Windows
    And unsupported depths are rejected before decoding for external fallback

  @code-verified @runtime-untested
  Scenario: Preserve existing instruments when decode rejects the file
    # cite: PakettiRX2Decode.lua PakettiRX2ImportNativeSliced
    Given a Lua attempt creates no instrument before failing
    When the sliced importer falls back to the external decoder
    Then cleanup does not delete an existing instrument

  @code-verified @runtime-untested
  Scenario: Show Windows import diagnostics only when requested
    # cite: PakettiRX2Loader.lua PakettiRX2WindowsImportDiagnostic
    # cite: Paketti0G01_Loader.lua pakettiRX2DebugDialog
    Given RX2 Debug Dialog is off by default
    When an RX2 import requests its Windows diagnostic
    Then the diagnostic returns before collecting data or opening a dialog
    And enabling RX2 Debug Dialog in import preferences permits Windows diagnostics
    And changing the checkbox saves the preference
