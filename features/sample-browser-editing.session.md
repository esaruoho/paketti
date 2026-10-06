# Preview editing

The user requested full button labels, a wider/taller waveform, stable octave placement when clearing selection, Cmd-Backspace source-file deletion with Y/Enter confirmation and Escape cancellation, and Cmd-X cuts that survive final loading. The implementation keeps a selection metadata row, expands the panel and waveform, cuts inclusive selected frames using a temporary backup sample, adjusts loops, and saves edited preview audio temporarily for final import. Cuts leave the source file untouched. Explicit file deletion uses a separate confirmation dialog and deferred completion.

Mocked tests verify frame contents, shifted Ping-Pong loop, edited-audio final loading, and Y/Enter versus N/Escape behavior. Lua syntax passes. Live Renoise layout and keyboard behavior remain untested.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/06/rollout-2026-10-06T10-17-46-01a11013-5d18-7792-b7fe-91af732f8ff1.jsonl
- Session ID: 01a11013-5d18-7792-b7fe-91af732f8ff1
- Resume: `codex --resume 01a11013-5d18-7792-b7fe-91af732f8ff1`
- Verified UTC timestamps: 2026-10-06T07:18:20.702Z through 2026-10-06T07:29:30.480Z.
- Bundled transcript: [sample-browser-editing.transcript.jsonl](sample-browser-editing.transcript.jsonl)
- Card: [sample-browser-editing.feature](sample-browser-editing.feature)

The user required deletion to retain the current row, clamped to the new last row. The rebuild function now accepts an optional retained row for deletion and keeps scroll position within the reduced list. Regression execution verifies middle-row retention, 20-to-19 clamping, and an empty list.

The user requested interpolation, oversampling and autofade controls. Added native playback controls that modify the scratch sample immediately and carry explicit choices through final import after loader defaults. UI building and synchronization suppress notifiers; switching files resets explicit choices. Mocked final loading verifies all three properties, including false autofade. Live Renoise remains untested.

The user requested angle-key octave changes independent of Caps Lock. The handler now resolves typed punctuation first, then named keys with a Shift fallback. Mocked tests cover caps/capslock combined with Shift and typed characters. Live keyboard events remain unverified.

The user requested preview volume, beatsync, recursive root-wide search and trim. Added a scratch-volume slider, a tempo-sync mode popup with nearest-power-of-two beat length, and Trim Selection. Trim uses the same edited-audio delivery path as cuts. Find now searches relative paths recursively from the opening/chosen root, one folder per 20 ms timer, with cancellation on rebuild/close/document release and a depth guard of 64. Navigation is held while searching; Escape still closes. Tests verify trimmed frame data, shifted loop bounds, two-second/120-BPM beatsync, final import mode retention and nested root search. UI and large real folder performance are not live-tested.

The user requested a moving playback cursor especially for click-and-play. Added a white cursor updated every 30 ms. Click slices start at the clicked frame and are tracked as one-shots; Keyjazz accounts for pitch, fine tuning, beatsync and loop mode. Position is estimated from os.clock trigger timing, not native audio-engine telemetry. Stop, preview change, closure and document release clean up the timer. Mocked tests verify offsets, end disappearance, loop modes, octave speed and cleanup; live visual/timing verification remains pending.

The user requested exact beatsync length. Replaced automatic duration estimation with a 1–512 integer valuebox (default 16), an independent checkbox and a three-mode popup. Explicit line count remains while disabled, across cuts/trims and into final loading. Regression tests verify 37-line preview/import, Texture mode, disable retention, bounds and notifier suppression. Live Renoise remains untested.
