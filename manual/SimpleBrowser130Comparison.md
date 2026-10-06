# SimpleBrowser 1.3.0 source review

Inspected main.lua from /Users/esaruoho/Downloads/com.phaos.SimpleBrowser-2.xrnx. C.VERSION is 1.3.0. Findings below are source-verified, not live Renoise tests.

The changelog corresponds to implemented code. Semitone, fine tune and panning target the highlighted file preview or, when the Multi-Sample pane is focused and visible, its selected instrument sample (C.pitch_target, ~2928). Semitone is -120 to +120; fine tune -127 to +127; panning maps -50..50 to Renoise's normalized 0..1 value (C.PITCH, ~2949).

File edits are recorded in the per-file operation history, reapplied when previewing, and transferred on import through C.apply_props (~2866). This is retention while browsing and transfer to the loaded sample; it does not mean the original WAV is rewritten or that these file-specific edits persist across tool sessions. S.ops is initialized as an in-memory table.

Beatsync has an enabled checkbox, line length and separate playback mode. Sync length operations include zero as Off internally, with positive lengths up to 512. Explicit per-file line length overrides inferred beatsync. The T button computes semitones as 12*log2(original duration / target duration), rounds to an integer transpose, and uses fine tune for the remainder. Target duration is lines*60/(BPM*LPB) (C.tempo_tune, ~3079).

Audition Changes is off by default and schedules a 180 ms delayed replay after control edits. Replay also requires auto-prehear to be enabled (pitch_timer, ~3043). Keyboard controls are registered for semitone, fine tune, panning, sync length and Set Pitch to Tempo (~7761 onwards). The sample controls use a two-column/five-row layout with one pane, or four columns/three rows with two panes (C.LAYOUT, ~5155).

Visibility and empty-list navigation guards are present: global kit-keyjazz mode checks the Multi-Sample panel's visibility (~6342), and Right enters the kit only if it has entries (~6447). Help title includes C.VERSION (~6224).

## New gaps in Paketti relative to 1.3.0

- Per-sample Semitone, Fine tune and Panning controls, their shortcuts, and retention during browsing.
- Renoise-style beatsync checkbox plus explicit 1–512 line length and separate Mode popup. Paketti currently uses an Off/mode popup and automatically estimates line count.
- T / Set Pitch to Tempo.
- Optional audition-after-edit with debounce.
- A compact aligned sample-control grid and complete keyboard navigation among its controls.

The earlier gaps remain: per-file edit retention and undo/redo/reset; browser loop crossfade and zero-crossing snapping; multisample assembly/mapping; multiple-file selection; preview routing/autoplay; replace-selected and load-and-write-note; two-pane browsing and extra folder management. Paketti now has preview volume, tempo sync, recursive root search, cut/trim, playback quality controls, source-file delete confirmation and an estimated moving playback cursor.

Implementation priority: retain per-file state first so pitch/pan/sync edits survive browsing; add the Renoise-style control grid and exact beatsync length/T; then undo/redo/reset and audition-after-edit.
