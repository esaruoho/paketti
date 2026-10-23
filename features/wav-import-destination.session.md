# Additive WAV import without duplicate slots

## Follow-up: sample recorder imports

The user confirmed that the hook runs while the sample recorder is open, identified a recording file named `TempSampleRef1`, and reported Renoise's "Failed to load the recorded sample" / memory error. They requested bypassing the WAV hook whenever the sample recorder is visible. Added an immediate visibility guard before either preference branch; it returns false without song access, template loading, sample allocation, monitoring changes or deferred import work. This applies to all formats sharing the callback. The regression exercises both preference states with song access set to throw, then runs the existing normal-import cases with the recorder hidden. Live recorder recovery remains unverified. Current follow-up transcript ID/path and timestamps have not been confirmed; the How to get back block below identifies the original implementation session only. Delivery: worktree change, no commit or push.

The user reported that dragging eight WAV files produced an empty set of instrument slots before the loaded set. Inspection found unconditional instrument insertion in PakettiWavImportHookInvoke. Renoise's documented hook contract says to load into the selected component: https://renoise.github.io/xrnx/API/renoise/renoise.ScriptingTool.html . A simulated batch with eight host-selected destinations reproduced eight additional instruments before the fix.

The initial proposed direction was to use the selected destination unconditionally. The user explicitly rejected overwriting: “no, i want it to be additive, not ‘overwrite’, don't change it like that.” No unconditional reuse change had been made. The final implementation remembers existing instrument objects between drops via idle and reuses only a newly seen blank destination; any pre-existing slot gets a separate inserted instrument, including intentionally empty slots. Blank checks exclude samples with audio, names, phrases, sample effect chains, plugins and MIDI output devices. Existing slots are never swept or deleted.

Verification: luajit tests/wav_import_hook_regression.lua passes for eight assigned new destinations, no extra instruments, preserving pre-existing empty slots, full sample mapping, monitor restoration and preference-off behavior. This is a mocked host regression, not a live Finder drop; real Renoise scheduling of idle and hook callbacks remains runtime unverified. If the host runs idle between allocation and invocation, the conservative snapshot may cause an extra slot rather than risking an overwrite. Template loading behavior is mocked too; this check does not establish every real-host allocation side effect.

## How to get back

Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/16/rollout-2026-10-16T23-03-11-01a1464f-b791-7141-9253-ed7f4e572f5c.jsonl

Session ID: 01a1464f-b791-7141-9253-ed7f4e572f5c

Resume: `codex --resume 01a1464f-b791-7141-9253-ed7f4e572f5c`

Verified timestamp range: 2026-10-16T20:03:49.019Z to 2026-10-16T21:26:03.727Z.

Lossless snapshot: [wav-import-destination.transcript.jsonl](wav-import-destination.transcript.jsonl). Readable snapshot: [wav-import-destination.transcript.md](wav-import-destination.transcript.md).

## Follow-up: empty Sample 01 slots and C-0-only final file

The user reported a real four-file external drop: the first three instruments retained an empty “Sample 01”, while the last had no empty slot but only triggered at C-0. Inspection showed both cleanup and mapping reset were performed before returning from the hook. This timing is consistent with subsequent host mutation, but the exact host callback schedule has not been observed live.

Extended the regression to insert empty sample placeholders after hook callbacks and restrict the last imported sample to C-0. It failed before the fix. Successful imports now queue their song, instrument and sample objects. On idle the hook checks that the document and instrument still exist, locates the captured loaded sample, deletes other empty slots and reapplies base note 48, note range 0–119 and velocity range 0–127. It retains the immediate cleanup too. Cleanup never follows current selection, skips removed samples, and preserves other audio-bearing samples. Failed WAV loads now return failure instead of being reported as successful imports.

Validation: luajit tests/wav_import_hook_regression.lua passes, including simulated post-callback placeholders and last-file mapping changes, additive batch allocation, preserving other audio, preserving selection and harmless repeat idle. Live Finder drag in Renoise remains unverified. No commit or push performed.

## Follow-up: additional audio formats and WAV cues

User requested the same import for AIFF, AIF, FLAC and MP3, then requested correct embedded WAV cue import. Registration now iterates WAV/AIFF/AIF/FLAC/MP3 independently, retaining the saved preference and old keybinding. The menu is labeled Audio Import Hook with its supported extensions. Renoise handles actual audio decoding through sample_buffer:load_from.

The hook reuses PakettiWavCueParseWavCues rather than the existing full cue importer: that importer writes source-adjacent sidecars and applies positions directly. The new hook retains parsed cue sets (more than one point) and applies them after deferred cleanup. It converts zero-based RIFF offsets to one-based Renoise frames, deduplicates, bounds-checks, inserts frame 1 and caps at 255. Existing markers are replaced to avoid duplicate native interpretations. Cleanup skips slice aliases. Non-WAV imports bypass cue parsing; zero/one-cue WAVs keep ordinary-sample behavior.

Validation: the Lua regression passes format registration even with WAV already registered, invokes each added format through its registered callback, and exercises cleanup/mapping. A generated real RIFF WAV with cue offsets 0,100,100,999,1000 at 1000 frames yields exactly 1,101,1000; no sidecar is created. Decoder support for actual AIFF/FLAC/MP3 and native slice-alias mapping behavior require live Renoise verification, not established by these host mocks. No commit or push performed.

## Correction: remove registration while recorder is visible

The previous claim that returning false delegates to the native loader was wrong: the official hook contract defines false as import failure. User reported the same error and reiterated: visible recorder means Paketti imports nothing; hidden means use the enabled import hook. A proposed selected-buffer recording loader was removed before delivery because the user explicitly rejected importing anything while visible. The final implementation removes Paketti-owned registrations on idle while visible or disabled, and restores them when hidden and enabled. The callback also returns immediately without song access while visible. Existing foreign registrations are not removed. The old comment claiming runtime removal was impossible was incorrect; remove_file_import_hook is documented. Mock regressions pass for registration suspension, restoration, foreign-hook preservation and existing import behavior. There is no visibility observable in the documented ApplicationWindow API, so polling is on idle; opening and immediately stopping a recording before any idle tick remains a live-host timing limitation. No live recorder test or completion claim. No commit or push.
