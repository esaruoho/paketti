# RX2 24-bit import fix

The user supplied a legitimate 24-bit ReCycle file and reported that Windows imported it as 16-bit white noise. Their diagnosis identified low-word truncation in pcm_to_wav.

Inspection confirmed that the importer dropped info.bit_depth and the writer hardcoded 16-bit headers and two bytes per sample. A regression through PakettiRX2ImportNative failed before the fix. The importer now passes the depth, and the writer emits all three bytes for 24-bit signed PCM with correct RIFF word padding. Existing 16-bit serialization is retained.

Validation: luajit tests/rx2_wav_regression.lua with the supplied Downloads file passed: 200386 exact sample comparisons, comprising 200348 real-file samples plus 38 boundary fixture samples. Real source: 24-bit stereo, 100174 frames. Renoise is mocked at the load boundary; actual Windows Renoise playback has not been tested. No commit or external delivery was requested or performed.

## How to get back

Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/16/rollout-2026-10-16T23-03-11-01a1464f-b791-7141-9253-ed7f4e572f5c.jsonl

Session ID: 01a1464f-b791-7141-9253-ed7f4e572f5c

Resume: `codex --resume 01a1464f-b791-7141-9253-ed7f4e572f5c`

Verified transcript timestamps: 2026-10-16T20:03:49.019Z through 2026-10-16T20:05:12.295Z.

Bundled snapshot: [rx2-24bit-import.transcript.jsonl](rx2-24bit-import.transcript.jsonl), [rx2-24bit-import.transcript.md](rx2-24bit-import.transcript.md).

## Follow-up: 8-, 16-, and 24-bit Lua import on Windows

User: “yeah please make lua handle 8bit 16bit 24bit thanks for windows too”.

Added signed 8-bit decoder limits and unsigned 8-bit WAV packing. Enabled Lua in the default preference and the saved preference, preserving other saved settings. Reject unsupported depths before decoding. The sliced fallback now compares instrument count before cleanup, so a rejection before insertion cannot delete the user's selected existing instrument.

Verification exercises the real codec roundtrip at all three depths in mono/stereo, 8-bit clamping, exact WAV samples/headers/padding, unsupported 32-bit metadata rejection, and the real loader dispatch preamble with Windows selected including force_exe bypass. Actual Windows Renoise playback remains untested. The supplied real 24-bit file remains sample-exact. No commit or push performed.

## Follow-up: optional Windows debug dialog

User requested a Paketti preference named “RX2 Debug Dialog”, On/Off, default Off. Added a persistent checkbox beside RX2 decode in Lua in Import Hooks preferences and an early strict-boolean preference gate in PakettiRX2WindowsImportDiagnostic. Default and saved settings are Off. All callers share the gate, including Lua and external imports. Verification checked the actual gate for missing/false/true settings on Windows and true on non-Windows. Renoise checkbox interaction remains runtime untested.
