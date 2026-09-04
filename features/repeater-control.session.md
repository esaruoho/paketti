# Repeater Control Session

## How To Get Back

- Transcript: not bundled in this worktree session.
- Session ID: unavailable from the local shell.
- Resume: use the current Codex thread for the full live context.
- Date: 2026-09-04 12:45 EEST, checked with `date`.

## User Request

Esa asked to look carefully at GitHub issue #538 and fix whatever could be grasped from it.

Issue #538 asks for key/MIDI control of the native Renoise Repeater:

- selected-track Repeater control
- master-track Repeater control
- enable, bypass, toggle
- Even/Triplet/Dotted mode actions and mode cycling
- divisor presets and divisor halve/double
- same-active-preset bypass
- sync Repeats/Lines toggle
- MIDI Hold behavior: press activates, release deactivates
- Free + Divisor MIDI knob behavior

## What Changed

`PakettiMidi.lua` now has shared Repeater helpers that resolve either the selected track or master track, find or insert the first native Repeater, and apply action commands consistently.

The old helper no longer rejects master tracks before trying insertion. It now uses `pcall` around `track:insert_device_at`, so the actual Renoise device-chain capability decides whether insertion is possible.

New registrations cover selected-track and master-track Repeater actions, per-preset MIDI buttons, per-preset Hold MIDI buttons, master-track preset keybindings, and Free Divisor knob mappings.

## Verification

Local verification is limited to static checks because Renoise's runtime API and MIDI mapping delivery are not executable from this shell.

The report card grades the behavior as `@code-verified @runtime-untested` until it has been exercised inside Renoise.
