# Report Card — Pedal Record

> Source: `features/pedal-record.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user with a sustain-style MIDI pedal, I want Record to Current Track to run only while the pedal is fully down, So that releasing the pedal reliably stops the recording.

**Grades:** @code-verified × 10 · @runtime-untested × 10 · @shipped × 10 · @stock × 1

**Scenarios: 11**


---


## 1. Pedal value 127 starts Record to Current Track

`@shipped @code-verified @runtime-untested`


- Given the user maps a pedal or CC source to `Paketti:Record to Current Track (Pedal) x[Knob]`
- When the MIDI value is 127
- Then Paketti starts the same Record to Current Track workflow used by `Paketti:Record to Current Track x[Toggle]`
- And it applies the same playback, follow, and lower-frame setup as the original mapping

<sub>cite: PakettiMidi.lua PakettiPedalRecord (~line 349) — detects value 127 and starts the guarded recorder path · PakettiRecorder.lua PakettiRecordToCurrentTrackStart (~line 332) — starts only when Record to Current Track is not already active</sub>


## 2. Any pedal value other than 127 stops recording

`@shipped @code-verified @runtime-untested`


- Given Pedal Record has started a Record to Current Track take
- When the mapped pedal sends 0, 1, 64, 126, or any other value that is not 127
- Then Paketti stops the recording
- And repeated release values do not start a new take

<sub>cite: PakettiMidi.lua PakettiPedalRecord (~line 349) — treats every non-127 value as release/off · PakettiRecorder.lua PakettiRecordToCurrentTrackStop (~line 341) — stops only when that workflow is active</sub>


## 3. The original toggle mapping remains available

`@stock`


- Given the user maps `Paketti:Record to Current Track x[Toggle]`
- When the user triggers that mapping
- Then it still toggles the existing Record to Current Track workflow

<sub>cite: PakettiMidi.lua Record to Current Track mapping (~line 323) — still calls recordtocurrenttrack as a toggle</sub>


## 4. Pattern Sync pedal alias is findable under Record to Current Track

`@shipped @code-verified @runtime-untested`


- Given the user searches MIDI mappings for Record to Current Track
- When the mapping list is shown
- Then `Paketti:Record to Current Track (Pattern Sync) (Pedal) x[Knob]` is available beside the original toggle and pedal mappings

<sub>cite: PakettiMidi.lua Pattern Sync pedal mapping (~line 412) — exposes an explicit pattern-sync pedal name · PakettiMIDIMappings.lua mapping list (~line 139) — keeps the alias beside the original mapping</sub>


## 5. Row pedal writes C-4 with the current instrument immediately

`@shipped @code-verified @runtime-untested`


- Given the user maps `Paketti:Record to Current Track and Row Pedal x[Knob]`
- When the MIDI value is 127
- Then Paketti starts Record to Current Track
- And it immediately writes `C-4` with the current selected instrument to the current row
- And it suppresses the normal finalizer's automatic row-1 `C-4` placement for that take
- And it records with Sample Recorder Pattern Sync forced off for that take
- And repeated 127 values do not rewrite the row while the same recording is already active

<sub>cite: PakettiMidi.lua PakettiPedalRecordAndWriteRow (~line 389) — starts recording and writes the row only on the pedal-down edge · PakettiMidi.lua PakettiRecordToCurrentTrackWriteCurrentRow (~line 366) — writes C-4 and selected instrument into the current row</sub>


## 6. New Track Row Pedal always records on a fresh sequencer track

`@shipped @code-verified @runtime-untested`


- Given the user maps `Paketti:Record to Current Track and Row New Track Pedal x[Knob]`
- When the MIDI value is 127
- Then Paketti creates a new normal sequencer track
- And it selects that new track before starting Record to Current Track
- And it writes `C-4` with the current selected instrument to the current row on that new track

<sub>cite: PakettiMidi.lua PakettiPedalRecordNewTrackAndWriteRow (~line 445) — creates a fresh track before starting the take · PakettiMidi.lua PakettiRecordToCurrentTrackCreateFreshSequencerTrack (~line 401) — inserts a normal sequencer track, never master/group/send</sub>


## 7. Pattern Sync takes are named with a timestamp, not Overdub<NN>

`@shipped @code-verified @runtime-untested`


- Given the user records via the Pattern Sync pedal or the Pattern Sync shortcut
- When the take is finalized
- Then the track and instrument are named "YYYY-MM-DD HH-MM-SS Recording PTN:<lines> BPM:<bpm> LPB:<lpb>"
- And the timestamp is the wall-clock time when recording started
- And the multi-column Paketti Overdub 12/01 takes and the plain pedal keep their Overdub<NN> names

<sub>cite: PakettiRecorder.lua pakettiRecordTakeNames (~line 405) — timestamp-mode returns "<ts> Recording PTN:x BPM:y LPB:z" for both track and instrument · PakettiRecorder.lua record_name_timestamp capture (~line 335) — os.date is captured at record START so the name reflects when recording began · PakettiMidi.lua PakettiPedalRecordPatternSync / PakettiRecordToCurrentTrackPatternSyncShortcut — the only entry points that enable timestamp naming</sub>


## 8. Pattern Sync recording is available as a single keyboard shortcut

`@shipped @code-verified @runtime-untested`


- Given the user binds `Global:Paketti:Record to Current Track (Pattern Sync)`
- When the shortcut is pressed while no Record to Current Track take is active
- Then Paketti starts Record to Current Track with Sample Recorder Pattern Sync on
- And pressing the same shortcut again stops the take

<sub>cite: PakettiMidi.lua PakettiRecordToCurrentTrackPatternSyncShortcut (~line 329) — toggles start/stop with Pattern Sync forced on</sub>


## 9. Stopping a take never changes the Sample Recorder sync mode

`@shipped @code-verified @runtime-untested`


- Given the user starts a Record to Current Track (Pattern Sync) take
- When the user stops the take
- Then Renoise finishes recording the tail to the end of the pattern
- And Paketti does not grab the buffer or run the finalizer while recording is still active
- And Paketti never writes the Sample Recorder sync setting on stop
- And the sync mode is left exactly where it was, whether that is Pattern or None

<sub>cite: PakettiRecorder.lua recordtocurrenttrackMonitor (~line 445) — the normal-polling branch waits while pakettiSampleRecordingIsActive() is true, so nothing runs mid-tail · PakettiRecorder.lua cleanupMonitorAndVars (~line 847) — no longer restores the Sample Recorder sync setting; it leaves the sync mode exactly as it is</sub>


## 10. Current-row non-sync recording is available as a single keyboard shortcut

`@shipped @code-verified @runtime-untested`


- Given the user binds `Global:Paketti:Record to Current Track and Row`
- When the shortcut is pressed while no Record to Current Track take is active
- Then Paketti starts Record to Current Track with Sample Recorder Pattern Sync off
- And it immediately writes `C-4` with the current selected instrument to the current row
- And pressing the same shortcut again stops the take

<sub>cite: PakettiMidi.lua PakettiRecordToCurrentTrackAndRowShortcut (~line 344) — toggles start/stop, disables Pattern Sync, and writes C-4/current instrument</sub>


## 11. New-track current-row recording is available as a single keyboard shortcut

`@shipped @code-verified @runtime-untested`


- Given the user binds `Global:Paketti:Record to Current Track and Row New Track`
- When the shortcut is pressed while no Record to Current Track take is active
- Then Paketti creates and selects a new normal sequencer track
- And it starts Record to Current Track with Sample Recorder Pattern Sync off
- And it immediately writes `C-4` with the current selected instrument to the current row on that new track
- And pressing the same shortcut again stops the take

<sub>cite: PakettiMidi.lua PakettiRecordToCurrentTrackAndRowNewTrackShortcut (~line 365) — creates a fresh sequencer track, disables Pattern Sync, starts recording, and writes C-4/current instrument · PakettiMidi.lua keybinding registration (~line 520) — exposes the command as `Global:Paketti:Record to Current Track and Row New Track`</sub>

