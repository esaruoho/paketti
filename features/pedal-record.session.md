# Pedal Record Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-21 18:29:34 EEST
- Note: session file created during live implementation; click-back can be backfilled by content search for `Paketti:Record to Current Track (Pedal) x[Knob]`.

## User Request

Esa asked for a duplicate of `Paketti:Record to Current Track x[Toggle]` named Pedal Record. The critical behavior is pedal-held recording: the feature should trigger only when the incoming pedal value reaches `127`, and it should stop recording when the incoming value is anything other than `127`.

## Implementation Notes

The existing `recordtocurrenttrack()` function is a toggle with private state inside `PakettiRecorder.lua`. Calling it directly from every pedal value would be unsafe because repeated CC values could flip recording on and off. I added explicit guarded wrappers:

- `PakettiRecordToCurrentTrackStart(...)` calls the existing toggle only when the workflow is not already recording.
- `PakettiRecordToCurrentTrackStop()` calls the existing toggle only when the workflow is currently recording.
- `PakettiRecordToCurrentTrackIsRecording()` exposes the current workflow state.

In `PakettiMidi.lua`, I split the original Record to Current Track transport setup into `PakettiRecordToCurrentTrackTransportSetup()`. The original toggle mapping still calls `recordtocurrenttrack()` and then that setup helper. The new `PakettiPedalRecord(message)` reads `message.int_value`, falling back to normalized `message.value` or `message.boolean_value` if needed. Value `127` starts and prepares transport; every other value stops.

The new MIDI mapping is `Paketti:Record to Current Track (Pedal) x[Knob]`, and it is also listed in `PakettiMIDIMappings.lua`.

## Follow-up: Findable Pattern Sync and Row Variants

Esa said the first pedal mapping was too hard to find under `Pedal Record`, so it was renamed to `Paketti:Record to Current Track (Pedal) x[Knob]`. He then asked for another version that immediately writes the current instrument and `C-4` into the pattern so the freshly recorded thing can play, with names that remain grouped under Record to Current Track.

I added:

- `Paketti:Record to Current Track (Pattern Sync) (Pedal) x[Knob]` as an explicit pattern-sync pedal alias beside the original. The underlying `recordtocurrenttrack()` path already forces Pattern Sync on where Renoise supports it.
- `Paketti:Record to Current Track and Row Pedal x[Knob]`, which starts the same guarded pedal recording flow and, only on the pedal-down edge, writes `C-4` with `song.selected_instrument_index - 1` into the current pattern row. It uses the selected note column if one is active, otherwise column 1, and makes at least one note column visible.

## Follow-up: Row Pedal Must Not Also Write Row 1

Esa reported that Row Pedal wrote the wanted `C-4 04` at the current row, but also wrote a duplicate `C-4 04` on the first row. Root cause: `recordtocurrenttrack()` always performs its normal finalizer row-1 note placement after sample data appears.

I added `PakettiRecordToCurrentTrackSkipDefaultRow1Note(true)` for the Row Pedal start path. `finalrecord()` now bypasses both normal row-1 placement and the "row1 full, create new track and write row1" branch when that per-take flag is set. Cleanup resets the flag after the take.

## Follow-up: Row Pedal Is Non-Sync

Esa clarified that the Row Pedal non-sync version must not enable Sample Recorder Pattern Sync. I added `PakettiRecordToCurrentTrackPatternSyncMode(false)` to the Row Pedal start path and made `recordtocurrenttrack()` honor that per-take mode. The explicit `Paketti:Record to Current Track (Pattern Sync) (Pedal) x[Knob]` path still forces Pattern Sync on; Row Pedal forces it off for the take and cleanup restores the user's previous Sample Recorder sync setting.

## Follow-up: Always-Safe New Track Pedal

Esa asked for another version that creates a new track on every record start, so the target is always safe and always a real sequencer track rather than master, group, or send. I added `Paketti:Record to Current Track and Row New Track Pedal x[Knob]`.

On pedal-down, if no Record to Current Track take is already active, it creates a fresh sequencer track first. If the current selection is already a normal sequencer track, the new track is inserted after it. If the current selection is master/group/send/non-sequencer, the new track is inserted at the end of the sequencer-track area, before master/send tracks. Then it starts the same non-sync Row Pedal recording flow and writes `C-4` with the current selected instrument into the current row on that fresh track.

## Follow-up: Keyboard Shortcuts for the Two Core Workflows

Esa asked why there were no shortcut-bindable versions for the two core workflows: one shortcut to start/stop loop recording with Pattern Sync, and one shortcut to start/stop non-sync recording while writing `C-4` with the current instrument to the current row.

I added:

- `Global:Paketti:Record to Current Track (Pattern Sync)` — starts/stops Record to Current Track with Pattern Sync forced on.
- `Global:Paketti:Record to Current Track and Row` — starts/stops Record to Current Track with Pattern Sync forced off, suppresses the finalizer row-1 note, and writes `C-4` with the current selected instrument to the current row immediately on start.

## Verification

- `luac -p PakettiRecorder.lua PakettiMidi.lua PakettiMIDIMappings.lua` passed.
- Load order checked in `main.lua`: `PakettiRecorder` is required before `PakettiMidi`.
- Runtime verification in Renoise was not performed from this shell session.
