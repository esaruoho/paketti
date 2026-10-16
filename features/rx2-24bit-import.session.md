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
