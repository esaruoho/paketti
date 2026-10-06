# Preserve Keyjazz preview loops

The user reported that choosing a loop point and loading the sample produced slices. Inspection found that the native WAV path always called the cue importer and skipped applying the preview loop to sliced samples. The fix bypasses cue import for an active preview loop and applies its exact bounds and mode after loader defaults.

The user clarified that a Ping-Pong loop at 3–6 must remain a loop, and that a WAV with only one cue must never be sliced. The shared cue importer now returns through normal sample loading for zero or one cue. Mocked execution verifies the exact Ping-Pong loop and zero/single-cue behavior. Live Renoise remains untested.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/06/rollout-2026-10-06T10-17-46-01a11013-5d18-7792-b7fe-91af732f8ff1.jsonl
- Session ID: 01a11013-5d18-7792-b7fe-91af732f8ff1
- Resume: `codex --resume 01a11013-5d18-7792-b7fe-91af732f8ff1`
- Verified transcript timestamps: 2026-10-06T07:18:20.702Z through 2026-10-06T07:19:57.488Z (UTC).
- Bundled source: [sample-browser-loop-load.transcript.jsonl](sample-browser-loop-load.transcript.jsonl)
- Card: [sample-browser-loop-load.feature](sample-browser-loop-load.feature)
