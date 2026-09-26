# Transient Navigation Detection Session

## How To Get Back

- Date: 2026-09-26 21:52:12 EEST (+0300)
- Transcript file: not available from this sandbox session
- Session ID: not available from this sandbox session
- Resume command: not available without the session ID

## Request

Esa reported that `Sample Editor:Paketti:Transient Next` on `/Users/esaruoho/Downloads/farmman-369finlp.wav` detected only frames `160, 18132`, even though the waveform screenshot clearly showed many later transients.

## Findings

The command lives in `PakettiTransientNavigation.lua` and reuses Paketti's `BeatDetector` envelope/Schmitt trigger. A local reproduction against the WAV matched the Renoise result exactly: the nav defaults emitted raw hits near `162`, `224`, and `18181`, which became zero-crossing-snapped positions `160, 18132`.

The failure was not in Next/Previous cycling. The trigger remained latched because `peak_off = 0.005` was far below the noisy post-hit envelope. Raising the nav-only release threshold to `0.03` lets the detector re-arm between dense hits while keeping `peak_on = 0.04`.

## Changes

- Added a report-card back-link to `PakettiTransientNavigation.lua`.
- Changed `TN_DEFAULTS.peak_off_low` and `TN_DEFAULTS.peak_off_high` from `0.005` to `0.03`.
- Added `tests/transient_navigation_detector_regression.py`, which mirrors the Lua detector and proves the old threshold reproduces the two-hit failure while the new threshold detects later hits in the same WAV.
- Added demo-friendly `Next Transient (No Zoom)` / `Previous Transient (No Zoom)` menu entries and `Transient Next Without Zoom` / `Previous Without Zoom` keybindings that call the existing point-cursor navigation path.

## Verification

- `python3 tests/transient_navigation_detector_regression.py /Users/esaruoho/Downloads/farmman-369finlp.wav`

The probe reported 2 positions with the old threshold and 20 positions with the new threshold, reaching the sample tail.
