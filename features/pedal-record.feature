# =============================================================================
# WIKI PAGE / REPORT CARD: Pedal Record
#
# WHAT THIS CARD SPAWNS:
#   codespace  — PakettiRecorder.lua explicit Record to Current Track start/stop wrappers,
#                PakettiMidi.lua pedal MIDI value handling, PakettiMIDIMappings.lua mapping index
#   thinkspace — pedal-record.session.md
#   areaspace  — OWNS: the pedal-held duplicate of Record to Current Track
#                MUST NOT TOUCH: the existing Record to Current Track toggle semantics
#
# Innards linked back to this card (grep "features/pedal-record.feature"):
#   PakettiRecorder.lua - PakettiRecordToCurrentTrackStart/Stop guard the existing toggle state
#   PakettiRecorder.lua - PakettiRecordToCurrentTrackSkipDefaultRow1Note suppresses the default row-1 finalizer note for Row Pedal
#   PakettiRecorder.lua - PakettiRecordToCurrentTrackPatternSyncMode selects sync-on or sync-off per take
#   PakettiMidi.lua - PakettiRecordToCurrentTrackPatternSyncShortcut exposes one-shot pattern-sync keyboard control
#   PakettiMidi.lua - PakettiRecordToCurrentTrackAndRowShortcut exposes one-shot non-sync current-row keyboard control
#   PakettiMidi.lua - PakettiPedalRecord maps MIDI value 127 to start and any other value to stop
#   PakettiMidi.lua - PakettiPedalRecordAndWriteRow writes C-4/current instrument immediately on pedal-down
#   PakettiMidi.lua - PakettiPedalRecordNewTrackAndWriteRow creates a fresh sequencer track before recording
#   PakettiMIDIMappings.lua - exposes the Record to Current Track pedal mappings in the MIDI mapping list
#
# SESSION:      pedal-record.session.md
# RESULT:       Worktree delivery; direct-push/PR not yet known
#
# WATCH: PakettiPedalRecord PakettiPedalRecordAndWriteRow PakettiPedalRecordNewTrackAndWriteRow PakettiRecordToCurrentTrackPatternSyncShortcut PakettiRecordToCurrentTrackAndRowShortcut PakettiRecordToCurrentTrackStart PakettiRecordToCurrentTrackStop PakettiRecordToCurrentTrackSkipDefaultRow1Note PakettiRecordToCurrentTrackPatternSyncMode
#
# RESULT-LOG >> (auto-maintained by the report-card hooks — newest below)
#   2026-09-21  direct-commit  touched: PakettiPedalRecord PakettiPedalRecordAndWriteRow PakettiPedalRecordNewTrackAndWriteRow PakettiRecordToCurrentTrackPatternSyncShortcut PakettiRecordToCurrentTrackAndRowShortcut PakettiRecordToCurrentTrackStart PakettiRecordToCurrentTrackStop PakettiRecordToCurrentTrackSkipDefaultRow1Note PakettiRecordToCurrentTrackPatternSyncMode
# =============================================================================

Feature: Pedal Record
  As a Paketti user with a sustain-style MIDI pedal, I want Record to Current Track to run only while the pedal is fully down, So that releasing the pedal reliably stops the recording.

  @shipped @code-verified @runtime-untested
  Scenario: Pedal value 127 starts Record to Current Track
    # cite: PakettiMidi.lua PakettiPedalRecord (~line 349) — detects value 127 and starts the guarded recorder path
    # cite: PakettiRecorder.lua PakettiRecordToCurrentTrackStart (~line 332) — starts only when Record to Current Track is not already active
    Given the user maps a pedal or CC source to `Paketti:Record to Current Track (Pedal) x[Knob]`
    When the MIDI value is 127
    Then Paketti starts the same Record to Current Track workflow used by `Paketti:Record to Current Track x[Toggle]`
    And it applies the same playback, follow, and lower-frame setup as the original mapping

  @shipped @code-verified @runtime-untested
  Scenario: Any pedal value other than 127 stops recording
    # cite: PakettiMidi.lua PakettiPedalRecord (~line 349) — treats every non-127 value as release/off
    # cite: PakettiRecorder.lua PakettiRecordToCurrentTrackStop (~line 341) — stops only when that workflow is active
    Given Pedal Record has started a Record to Current Track take
    When the mapped pedal sends 0, 1, 64, 126, or any other value that is not 127
    Then Paketti stops the recording
    And repeated release values do not start a new take

  @stock
  Scenario: The original toggle mapping remains available
    # cite: PakettiMidi.lua Record to Current Track mapping (~line 323) — still calls recordtocurrenttrack as a toggle
    Given the user maps `Paketti:Record to Current Track x[Toggle]`
    When the user triggers that mapping
    Then it still toggles the existing Record to Current Track workflow

  @shipped @code-verified @runtime-untested
  Scenario: Pattern Sync pedal alias is findable under Record to Current Track
    # cite: PakettiMidi.lua Pattern Sync pedal mapping (~line 412) — exposes an explicit pattern-sync pedal name
    # cite: PakettiMIDIMappings.lua mapping list (~line 139) — keeps the alias beside the original mapping
    Given the user searches MIDI mappings for Record to Current Track
    When the mapping list is shown
    Then `Paketti:Record to Current Track (Pattern Sync) (Pedal) x[Knob]` is available beside the original toggle and pedal mappings

  @shipped @code-verified @runtime-untested
  Scenario: Row pedal writes C-4 with the current instrument immediately
    # cite: PakettiMidi.lua PakettiPedalRecordAndWriteRow (~line 389) — starts recording and writes the row only on the pedal-down edge
    # cite: PakettiMidi.lua PakettiRecordToCurrentTrackWriteCurrentRow (~line 366) — writes C-4 and selected instrument into the current row
    Given the user maps `Paketti:Record to Current Track and Row Pedal x[Knob]`
    When the MIDI value is 127
    Then Paketti starts Record to Current Track
    And it immediately writes `C-4` with the current selected instrument to the current row
    And it suppresses the normal finalizer's automatic row-1 `C-4` placement for that take
    And it records with Sample Recorder Pattern Sync forced off for that take
    And repeated 127 values do not rewrite the row while the same recording is already active

  @shipped @code-verified @runtime-untested
  Scenario: New Track Row Pedal always records on a fresh sequencer track
    # cite: PakettiMidi.lua PakettiPedalRecordNewTrackAndWriteRow (~line 445) — creates a fresh track before starting the take
    # cite: PakettiMidi.lua PakettiRecordToCurrentTrackCreateFreshSequencerTrack (~line 401) — inserts a normal sequencer track, never master/group/send
    Given the user maps `Paketti:Record to Current Track and Row New Track Pedal x[Knob]`
    When the MIDI value is 127
    Then Paketti creates a new normal sequencer track
    And it selects that new track before starting Record to Current Track
    And it writes `C-4` with the current selected instrument to the current row on that new track

  @shipped @code-verified @runtime-untested
  Scenario: Pattern Sync recording is available as a single keyboard shortcut
    # cite: PakettiMidi.lua PakettiRecordToCurrentTrackPatternSyncShortcut (~line 329) — toggles start/stop with Pattern Sync forced on
    Given the user binds `Global:Paketti:Record to Current Track (Pattern Sync)`
    When the shortcut is pressed while no Record to Current Track take is active
    Then Paketti starts Record to Current Track with Sample Recorder Pattern Sync on
    And pressing the same shortcut again stops the take

  @shipped @code-verified @runtime-untested
  Scenario: Current-row non-sync recording is available as a single keyboard shortcut
    # cite: PakettiMidi.lua PakettiRecordToCurrentTrackAndRowShortcut (~line 344) — toggles start/stop, disables Pattern Sync, and writes C-4/current instrument
    Given the user binds `Global:Paketti:Record to Current Track and Row`
    When the shortcut is pressed while no Record to Current Track take is active
    Then Paketti starts Record to Current Track with Sample Recorder Pattern Sync off
    And it immediately writes `C-4` with the current selected instrument to the current row
    And pressing the same shortcut again stops the take
