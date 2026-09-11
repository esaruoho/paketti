# Paketti Master Bandpass Session

## How to Get Back

- Date: 2026-09-11, started around 15:21 EEST
- Workspace: `/Users/esaruoho/Library/Mobile Documents/com~apple~CloudDocs/Renoise/Tools/org.lackluster.Paketti.xrnx`
- Source tool studied: `/Users/esaruoho/Downloads/ledger.scripts.MasterBandpass_V0.54.xrnx`
- Transcript file: not available from this sandboxed turn
- Session ID: not available from this sandboxed turn
- Resume command: cannot be stated honestly without the session ID

## Request

Esa asked: "study this. /Users/esaruoho/Downloads/ledger.scripts.MasterBandpass_V0.54.xrnx can we create a paketti version of this and somehow make it better and betterer?"

## Source Tool Notes

The downloaded `.xrnx` contains only `main.lua` and `manifest.xml`. Its `main.lua`
registers a global keybinding, a toggle keybinding, and a Tools menu entry. On use, it
adds a native Doofer named "Master Bandpass" to the master track, injects XML containing
a Digital Filter plus Gainer, exposes one rotary for Doofer parameter 1, and disables
the device when the dialog closes.

The original also carries a commented Chebyshev preset variant, which is a good signal
that the Paketti version should not be limited to one fixed Butterworth bandpass shape.

## Implementation

I added `PakettiMasterBandpass.lua` and wired it from `main.lua` with
`timed_require("PakettiMasterBandpass")`. The module keeps the original idea but makes
it more Paketti-shaped:

- It tags the device as "Paketti Master Bandpass" and reuses that exact Doofer instead
  of adding duplicates.
- It exposes Cutoff, Q, and Gain as dialog rotaries, not only Cutoff.
- It adds preset character choices: Butterworth, Chebyshev, Tight Focus, and Gentle Sweep.
- It provides dialog, toggle active, view device, MIDI toggle, and MIDI hold controls.
- It keeps the source tool's audition behavior by disabling the filter when the dialog
  closes.
- It guards the feature for Renoise API 6.1+, where the Doofer/Digital Filter preset
  shape from the source tool is expected.

## Verification

`luac -p PakettiMasterBandpass.lua main.lua` passed.

Runtime verification inside Renoise has not been performed in this turn, so the card is
graded `@build-verified @runtime-untested`.
