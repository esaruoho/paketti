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
- Replaced the fixed-level Schmitt trigger used by Transient Navigation with an adaptive Schmitt detector: fast envelope, slow background envelope, novelty threshold, ratio threshold, and release hysteresis.
- Kept the old level-Schmitt detector only as debug comparison output.
- Added console debug logging for `Legacy level-Schmitt raw hits`, `Adaptive Schmitt raw hits`, and `Final snapped transients`.
- Reduced Transient Navigation's final minimum spacing from 35ms to 10ms, because 35ms suppressed many visible dense hits after the adaptive detector had already found them.
- Added `Suppressed by min spacing` debug logging with `frame(+distance)` entries.
- Strengthened the regression probe: the farmman fixture now verifies the adaptive Schmitt detector returns at least 80 transients, covers the skipped middle range, and reaches the tail.

## Verification

- `python3 tests/transient_navigation_detector_regression.py /Users/esaruoho/Downloads/farmman-369finlp.wav`
- `lua -e "assert(loadfile('PakettiTransientNavigation.lua')); print('lua parse ok')"`

The probe reported 2 positions with the old threshold and 89 snapped positions with the adaptive Schmitt detector plus 10ms spacing, including `59290, 62031, 63605, 67759, 68435, 73078` in the previously skipped middle section.
