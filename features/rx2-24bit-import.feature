# WHAT THIS CARD SPAWNS:
# Codespace: PakettiRX2Decode.lua and tests/rx2_wav_regression.lua
# Thinkspace: rx2-24bit-import.session.md
# Areaspace: Owns pure-Lua RX2 WAV serialization; external SDK decoding is unchanged.
# SESSION: rx2-24bit-import.session.md
# RESULT: Worktree changes only; no commit, push, or PR created.
# Files: PakettiRX2Decode.lua, tests/rx2_wav_regression.lua, PLAN.md and this card/session.
# WATCH: pcm_to_wav PakettiRX2ImportNative
# RESULT-LOG >>
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
