Feature: Music Mouse — Laurie Spiegel's "Intelligent Instrument" (1986) in Renoise
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-15..16 (40th-anniversary tribute). A from-scratch Renoise Canvas
  # port of Laurie Spiegel's Music Mouse. New module PakettiMusicMouse.lua,
  # timed_require'd in main.lua before PakettiMenuConfig. Tested LIVE by Esa across
  # the build (no PakettiMCP this session, so Claude could not self-verify sound).
  #
  # CODESPACE:
  #   • PakettiMusicMouse.lua — the whole instrument (engine + canvas + keymap + record)
  #   • Paketti0G01_Loader.lua — 4 persisted prefs (TempoBasic/Alt/SyncBPM/Loudness/Seeds)
  #   • main.lua — timed_require("PakettiMusicMouse")
  #   • manual/CHANGESLOG.md — 2026-06-16 Feature entry
  #   • PakettiMusicMouse-PATTERNS.md, PakettiMusicMouse-KEYS.md — reference docs
  #
  # INNARDS (PakettiMusicMouse.lua):
  #   • MM_SCALES (intervals/vs3/vs4/centerNote) + MM_PATTERNS — transcribed from
  #     Spiegel's running implementation (teropa.info bundle), cross-checked vs the
  #     MacMM manual. mm_axis_degrees()/mm_compute_voices() build voices from these.
  #   • mm_render — 4-sided piano keyboards (white pass then black on top so the
  #     active-key highlight never covers a black key), woven grid, crosshair, seeds.
  #   • mm_note_on/off (trigger_instrument_note_on per voice), mm_play_chord,
  #     mm_retrigger (force re-strike; arp restarts the sequence), mm_play_one.
  #   • mm_tick — fixed 16ms clock + BPM-derived accumulator (mm_beat_ms reads
  #     transport.bpm/lpb live when Sync on); Gravity Play steps the seeds here.
  #   • mm_render_into_sample (Sustain loop vs Bell baked-decay) + mm_tune_sample
  #     (PCMWriterApplyPitchCorrectionToSample, 256-frame period) on the Paketti
  #     Default Instrument (pakettiPreferencesDefaultInstrumentLoader).
  #   • mm_stamp_to_line / mm_record_write — write-on-trigger imprint to the pattern.
  #   • mm_load_prefs/mm_save_prefs — tempo+loudness+seeds persistence.
  #
  # DESIGN DECISIONS (confirmed with Esa, this session):
  #   • Sound = selected instrument + classic waveforms (chosen via AskUserQuestion).
  #   • Bell is the DEFAULT mode (non-looping decay), not Sustain.
  #   • 4 voices = classic MM and must stay unbroken; 5-9 add rich chord tones on X.
  #   • Gravity seeds: NO auto-snap (it trapped the cursor) — reached via Gravity Play.
  #   • ';' is shift-comma on Esa's layout → bound to Gravity Play before loudness.
  #
  # WATCH: pakettiMusicMouseShow mm_compute_voices mm_render mm_tick mm_set_record mm_tune_sample mm_toggle_gravity_play

  Scenario: Open Music Mouse from the menu
    Given Paketti is loaded
    When the user picks Main Menu:Tools:Paketti:Music Mouse...
    Then the Music Mouse dialog opens with the keyboard grid and the control panel
    # @built @user-verified

  Scenario: Move the mouse to play a quantized 4-voice chord
    Given the Music Mouse dialog is open and an instrument is selected
    When the user moves the mouse over the play area in Diatonic harmony
    Then four voices sound (3-note chord on X + melody on Y), snapped to the scale
    And the active keys light up on all four edge keyboards
    # @built @user-verified

  Scenario: Generate a Pakettified Bell instrument by default
    Given the Music Mouse dialog is open
    When the user clicks Generate New Pakettified Instrument (or a waveform key)
    Then the Paketti Default Instrument is loaded and the single-cycle wave rendered into it
    And the sample is tuned with the PCM Writer convention (transpose + fine_tune)
    And Mode defaults to Bell (non-looping decay) so notes ring and fade
    # @built @user-verified

  Scenario: 4 voices is classic Music Mouse; 5-9 give richer chords
    Given the Voices switch
    When set to 4
    Then the voicing is exactly classic Music Mouse (3-note X chord + Y melody)
    When set to 5..9
    Then extra scale-thirds stack on the X chord (7th/9th/11th/13th voicings)
    # @built @user-verified

  Scenario: Record what you play into the pattern (right-shift)
    Given the Music Mouse dialog is open
    When the user presses right-shift (or the Record checkbox)
    Then the Pattern Editor becomes active, Edit Mode + Follow turn on, playback starts
    And as notes trigger they are written to the selected track at the playhead line
    And the picked Loudness is written as the note volume column
    And pressing right-shift again stops recording and turns Edit Mode + Follow off
    # @built @user-verified

  Scenario: Gravitation seeds and Gravity Play
    Given the Music Mouse dialog is open
    When the user left-clicks the play area
    Then a green diamond seed is dropped at that chord and it plays
    When the user triggers Gravity Play (shift-comma / button / MIDI)
    Then the timer steps through the seeds in recorded order, one chord per beat at tempo
    And the seeds persist across close/reopen and reloads
    # @built @user-verified

  Scenario: Music Mouse owns its keys but lets your shortcuts through
    Given the Music Mouse dialog is focused
    When the user presses a key Music Mouse maps (q, a, z, ...)
    Then Music Mouse handles it and Renoise does not
    When the user presses an unmapped key, shift+cmd combo, Alt/Option, or F5-F12
    Then it passes through to Renoise
    # @built @user-verified

  Scenario: Sync the pattern player to the song BPM, controllable by MIDI
    Given Sync-to-BPM is on (default)
    When the song BPM changes (or a MIDI slider mapped to Music Mouse BPM moves)
    Then the pattern/Gravity-Play step rate follows the song tempo live
    # @built @user-verified

  Scenario: tab cycles the selected instrument through Paketti's microtonal tunings
    Given the Music Mouse dialog is open
    When the user presses tab
    Then the selected instrument's tuning advances to the next preset (12-TET first, then wraps)
    And the notes re-strike and play in that tuning (trigger_options.tuning)
    # @built @user-verified — via PakettiMicrotonalCycleTuning (PakettiMicrotonalTunings.lua)

  Scenario: A Launchpad plays Music Mouse and runs a Raindrops light show
    Given a Novation Launchpad is connected and the Music Mouse dialog is open
    When the user sets the Launchpad selector to "Play chords"
    Then the device enters Programmer mode and pressing a pad (note = row*10+col)
      punches the chord at that pad's X/Y, and an LED mirrors the live cursor pad
    When the user sets it to "Raindrops demo"
    Then pads still trigger chords AND expanding rings of colour ripple out from
      each press and from ambient drops
    When the user sets it to "Off" (or closes Music Mouse / changes song)
    Then the LEDs clear and the in/out MIDI devices are released
    # @built — layout from Esa's live probe (row-by-row 1..8); colours = mk3 palette.
    #   Triggering/LEDs not yet self-verified by Claude (drives the device on Esa's rig).

  Scenario: Loudness persists and never boots silent
    Given the user set Loudness to a value and closed the dialog
    When the dialog is reopened (or the tool reloaded)
    Then the Loudness is restored
    And a stored 0 (silent) falls back to an audible default instead of booting near-mute
    # @built @user-verified

  # ============================================================================
  # 2026-07-02 feedback pass (commit a9bd4907). Loaded live (dialog opens clean via
  # pakettiMusicMouseShow); behaviours below are @built, live-verification in progress.
  # ============================================================================

  Scenario: Changing a control never re-strikes the chord (and never sounds while frozen)
    Given the Music Mouse dialog is open with a chord ringing
    When the user changes Voices, Harmonic Mode, Voicing Format, Transposition,
      Mouse Movement, Pattern Applies, or any dropdown / checkbox / switch
    Then the target notes are recomputed and the grid redraws WITHOUT re-triggering the chord
    And the new state is heard only on the next mouse move or i/o/p punch
    And while frozen (space) nothing is ever triggered
    # @built — via mm_requiet(); state keys q-y / d / f / v also quiet

  Scenario: Chord changes are batched so there is no MIDI jitter
    Given a chord is sounding
    When the mouse moves to a new chord
    Then the note-offs and note-ons are each sent as a SINGLE chord trigger call (no per-voice flam)
    And voices whose note is unchanged are left ringing (no boundary jitter)
    # @built — mm_play_chord batches trigger_instrument_note_off/on tables (API confirmed via MCP)

  Scenario: Pattern Applies = Melody sequences one voice over a sustained chord (no flood)
    Given Pattern is on, Treatment = Chord, and Pattern Applies = Melody
    When the pattern timer advances each beat
    Then only the melody voice steps its note; the chord voices are struck once then left ringing
    And the whole chord is NOT re-triggered on every melody step
    # @built @mcp-verified 2026-07-02 — recorded live: Melody mode wrote 1 note/line across 32
    #   lines (a stepping contour); All mode wrote 4-note chords. mm_tick apply-mask path.

  Scenario: Recording auto-widens the track to the voice count
    Given Voices = 6 and Record to Pattern is armed
    Then the selected track's visible note columns grow to at least 6 so the chord writes across columns
    # @built @mcp-verified 2026-07-02 — columns went 1 -> 4 the instant Record armed at 4 voices

  Scenario: space is owned by Music Mouse and never bleeds to the pattern editor
    Given the Music Mouse dialog is focused (even with the mouse off the grid, or while recording)
    When the user presses space
    Then Music Mouse freezes/unfreezes and consumes the key before any passthrough
    And Renoise transport / pattern editor never receives it
    # @built — space handled at the very top of mm_keyhandler

  Scenario: Gravity Play beat divisor
    Given gravitation seeds exist and Gravity Play is on
    When the divisor is set to Every 4th / 8th / 16th
    Then a seed is hit only every Nth base beat instead of every beat
    # @built — mm.gravity_div + gravity_beat counter

  Scenario: Arpeggiate has Up / Down / Scatter / Strum
    Given Treatment = Arpeggiate
    When the Arp Mode is Up / Down / Scatter
    Then the timer steps one voice per beat in that order (pitch-sorted; Scatter is random)
    When the Arp Mode is Strum and the user presses a sound key
    Then the chord is written on one line across note columns with rising delay-column offsets
    # @built

  Scenario: i / o / p punch saved favorite waveforms; å = current; shift-i round-robin
    Given the user picked three favorite waveforms in the panel (persisted)
    When the user presses i / o / p (in keyjazz punch or normally)
    Then the chord is punched with favorite 1 / 2 / 3 (keeping Bell/Sustain), not a fixed shape
    When the user presses å
    Then the currently selected sound re-triggers without switching waveform
    When the user presses shift-i
    Then the next favorite is chosen round-robin and punched
    # @built — mm.fav_waves saved via pakettiMusicMouseFav1..3

  Scenario: Tuning dropdown and < > transpose
    Given the Music Mouse dialog is open
    When the user picks a tuning from the Tuning dropdown
    Then that microtonal preset is applied to the selected instrument (tab still cycles)
    When the user presses < or >
    Then the pitch transposes down / up by the interval (alongside z / x)
    # @built — PakettiMicrotonalSetTuning / PakettiMicrotonalTuningNames

  Scenario: Layout polish and width toggles
    Given the Music Mouse dialog is open
    Then labels are strong proportional (not wide mono); the mute row is tight
    And Waveform + Mode + Create New share one aligned row ("Waveform"); the Pattern popup width is matched
    And Record to Pattern is a button that is RED when armed, grey when off
    And Launchpad / help text lives in tooltips
    When the user ticks Hide pianos
    Then only the woven grid draws (the 4 edge keyboards are skipped)
    When the user ticks Hide details
    Then the control panel + pattern editor collapse, leaving the grid for a narrow window
    # @built

  Scenario: Pattern contour up to 64 steps with a length switch
    Given the melodic-pattern editor
    When the user picks 8 / 16 / 32 / 64 on the length switch (or Len +)
    Then the contour grows/truncates to that length (max 64)
    And Len + reports a status when the maximum is reached
    # @built

  Scenario: Keyboard Map is clickable and MIDI-mappable
    Given the "Keys / MIDI Map..." dialog
    Then keys are buttons grouped under bold headings with even alignment and a de-duped title (no em-dash)
    When the user clicks a key button
    Then it fires the exact same keyhandler path as pressing the key
    When the user enters cmd-M MIDI-map mode, clicks a button and moves a MIDI control
    Then that Music Mouse action binds to the control (each button has a registered Paketti:Music Mouse Key mapping)
    # @built — buttons drive mm_keyhandler; per-key add_midi_mapping registered
