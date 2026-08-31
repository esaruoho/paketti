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
  # RESULT — 2026-08-31 session "musicmouse" (Gravity nodes / strum / treatments)
  # ----------------------------------------------------------------------------
  # Delivery: direct-push to master, no PR (verified by first-parent ancestry on
  # origin/master; interleaved with commits from a sibling Claude session and from Esa).
  #   c3465c5d  Gravity Play feeds the Treatment engine; cursor keys step the seeds
  #             (swept into Esa's own commit "again" while both sessions shared the index)
  #   ec49e262  .spine local-variable headroom warning + Launchpad do...end scope (20 -> 36)
  #   44a01e89  strum rake fits the beat, cancels in flight, staccato-safe; MM_STRUM_MS hoisted
  #   aae34805  Arp Mode = Strum rakes in the Chord treatment too; mm_state_summary + menu entry
  #   15f5c7d0  seed steps play in every treatment; mm.prefs_loaded guard
  #   e1f6495f  a node performs the WHOLE gesture; mm_set_treatment; mm_rand hoisted;
  #             .spine/check.py undeclared-call sweep
  # Files: PakettiMusicMouse.lua, PakettiMusicMouse-KEYS.md, PakettiMusicMouse-LOCALS.md,
  #        manual/CHANGESLOG.md, .spine/check.py, .spine/localroom.lua,
  #        features/music-mouse.feature + .session.md
  # Outside the repo: ~/.local/bin/gumroad-paketti — size-settle budget 45s -> 300s, and a
  #        foreign file size now fails fast instead of being read as "still processing".
  #
  # WHAT WENT WRONG HERE, kept on the record because the grades depend on it:
  #   • Two wrong diagnoses before measuring. Guessing cost Esa two rounds.
  #   • A half-written file was picked up by Renoise's auto-reload mid-session and crashed
  #     his live tool (`variable 'mm_strum_cancel' is not declared` + notifier death).
  #     The working tree IS the running tool; every write must be internally coherent.
  #   • My own reload cycles destroyed his three saved gravitation seeds. Restored by hand;
  #     the mm.prefs_loaded guard exists so it cannot recur.
  #   • "launched detached pid N" reported twice for ~/work/apple/bin/gumroad-paketti, a
  #     path that does not exist. nohup had already failed. The tool is in ~/.local/bin.
  #
  # WATCH: pakettiMusicMouseShow mm_compute_voices mm_render mm_tick mm_set_record mm_tune_sample mm_toggle_gravity_play mm_articulate mm_perform_burst mm_burst_order mm_gravity_goto mm_gravity_step mm_set_treatment mm_strum_active mm_strum_spacing mm_strum_cancel mm_save_prefs mm_state_summary
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
  #   2026-08-31  direct-commit  touched: mm_compute_voices mm_render mm_set_record
  #   2026-08-31  direct-commit  touched: mm_compute_voices mm_toggle_gravity_play
  #   2026-08-31  direct-commit  touched: mm_compute_voices
  #   2026-08-29  direct-commit  touched: mm_compute_voices
  #   2026-08-29  direct-commit  touched: mm_compute_voices mm_tick
  #   2026-08-27  direct-commit  touched: mm_compute_voices
  #   2026-08-27  direct-commit  touched: mm_compute_voices mm_set_record

  @built @user-verified
  Scenario: Open Music Mouse from the menu
    Given Paketti is loaded
    When the user picks Main Menu:Tools:Paketti:Music Mouse...
    Then the Music Mouse dialog opens with the keyboard grid and the control panel
    # built user-verified

  @built @user-verified
  Scenario: Move the mouse to play a quantized 4-voice chord
    Given the Music Mouse dialog is open and an instrument is selected
    When the user moves the mouse over the play area in Diatonic harmony
    Then four voices sound (3-note chord on X + melody on Y), snapped to the scale
    And the active keys light up on all four edge keyboards
    # built user-verified

  @built @user-verified
  Scenario: Generate a Pakettified Bell instrument by default
    Given the Music Mouse dialog is open
    When the user clicks Generate New Pakettified Instrument (or a waveform key)
    Then the Paketti Default Instrument is loaded and the single-cycle wave rendered into it
    And the sample is tuned with the PCM Writer convention (transpose + fine_tune)
    And Mode defaults to Bell (non-looping decay) so notes ring and fade
    # built user-verified

  @built @user-verified
  Scenario: 4 voices is classic Music Mouse; 5-9 give richer chords
    Given the Voices switch
    When set to 4
    Then the voicing is exactly classic Music Mouse (3-note X chord + Y melody)
    When set to 5..9
    Then extra scale-thirds stack on the X chord (7th/9th/11th/13th voicings)
    # built user-verified

  @built @user-verified
  Scenario: Record what you play into the pattern (right-shift)
    Given the Music Mouse dialog is open
    When the user presses right-shift (or the Record checkbox)
    Then the Pattern Editor becomes active, Edit Mode + Follow turn on, playback starts
    And as notes trigger they are written to the selected track at the playhead line
    And the picked Loudness is written as the note volume column
    And pressing right-shift again stops recording and turns Edit Mode + Follow off
    # built user-verified

  @built @user-verified
  Scenario: Gravitation seeds and Gravity Play
    Given the Music Mouse dialog is open
    When the user left-clicks the play area
    Then a green diamond seed is dropped at that chord and it plays
    When the user triggers Gravity Play (shift-comma / button / MIDI)
    Then the timer steps through the seeds in recorded order, one seed per gravity beat
    And the seeds persist across close/reopen and reloads
    # built user-verified

  @built @user-verified
  Scenario: Music Mouse owns its keys but lets your shortcuts through
    Given the Music Mouse dialog is focused
    When the user presses a key Music Mouse maps (q, a, z, ...)
    Then Music Mouse handles it and Renoise does not
    When the user presses an unmapped key, shift+cmd combo, Alt/Option, or F5-F12
    Then it passes through to Renoise
    # built user-verified

  @built @user-verified
  Scenario: Sync the pattern player to the song BPM, controllable by MIDI
    Given Sync-to-BPM is on (default)
    When the song BPM changes (or a MIDI slider mapped to Music Mouse BPM moves)
    Then the pattern/Gravity-Play step rate follows the song tempo live
    # built user-verified

  @built @user-verified
  Scenario: tab cycles the selected instrument through Paketti's microtonal tunings
    Given the Music Mouse dialog is open
    When the user presses tab
    Then the selected instrument's tuning advances to the next preset (12-TET first, then wraps)
    And the notes re-strike and play in that tuning (trigger_options.tuning)
    # built user-verified — via PakettiMicrotonalCycleTuning (PakettiMicrotonalTunings.lua)

  @built
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
    # built — layout from Esa's live probe (row-by-row 1..8); colours = mk3 palette.
    #   Triggering/LEDs not yet self-verified by Claude (drives the device on Esa's rig).

  @built @user-verified
  Scenario: Loudness persists and never boots silent
    Given the user set Loudness to a value and closed the dialog
    When the dialog is reopened (or the tool reloaded)
    Then the Loudness is restored
    And a stored 0 (silent) falls back to an audible default instead of booting near-mute
    # built user-verified

  # ============================================================================
  # 2026-07-02 feedback pass (commit a9bd4907). Loaded live (dialog opens clean via
  # pakettiMusicMouseShow); behaviours below are built, live-verification in progress.
  # ============================================================================

  @built
  Scenario: Changing a control never re-strikes the chord (and never sounds while frozen)
    Given the Music Mouse dialog is open with a chord ringing
    When the user changes Voices, Harmonic Mode, Voicing Format, Transposition,
      Mouse Movement, Pattern Applies, or any dropdown / checkbox / switch
    Then the target notes are recomputed and the grid redraws WITHOUT re-triggering the chord
    And the new state is heard only on the next mouse move or i/o/p punch
    And while frozen (space) nothing is ever triggered
    # built — via mm_requiet(); state keys q-y / d / f / v also quiet

  @built
  Scenario: Chord changes are batched so there is no MIDI jitter
    Given a chord is sounding
    When the mouse moves to a new chord
    Then the note-offs and note-ons are each sent as a SINGLE chord trigger call (no per-voice flam)
    And voices whose note is unchanged are left ringing (no boundary jitter)
    # built — mm_play_chord batches trigger_instrument_note_off/on tables (API confirmed via MCP)

  @built @mcp-verified
  Scenario: Pattern Applies = Melody sequences one voice over a sustained chord (no flood)
    Given Pattern is on, Treatment = Chord, and Pattern Applies = Melody
    When the pattern timer advances each beat
    Then only the melody voice steps its note; the chord voices are struck once then left ringing
    And the whole chord is NOT re-triggered on every melody step
    # built mcp-verified 2026-07-02 — recorded live: Melody mode wrote 1 note/line across 32
    #   lines (a stepping contour); All mode wrote 4-note chords. mm_tick apply-mask path.

  @built @mcp-verified
  Scenario: Recording auto-widens the track to the voice count
    Given Voices = 6 and Record to Pattern is armed
    Then the selected track's visible note columns grow to at least 6 so the chord writes across columns
    # built mcp-verified 2026-07-02 — columns went 1 -> 4 the instant Record armed at 4 voices

  @built
  Scenario: space is owned by Music Mouse and never bleeds to the pattern editor
    Given the Music Mouse dialog is focused (even with the mouse off the grid, or while recording)
    When the user presses space
    Then Music Mouse freezes/unfreezes and consumes the key before any passthrough
    And Renoise transport / pattern editor never receives it
    # built — space handled at the very top of mm_keyhandler

  @built
  Scenario: Gravity Play rate is stated in pattern rows
    Given gravitation seeds exist and Gravity Play is on
    When the Gravity Rate is set to every 1 / 2 / 4 / 8 / 16 rows
    Then a seed is moved to only every Nth crossed row
    # built — mm.gravity_div + gravity_beat counter, clocked by mm_gravity_on_line

  @built
  Scenario: Gravity Play moves the position; the Treatment plays it
    Given gravitation seeds exist and Gravity Play is on
    When the Treatment is Chord / Arpeggiate / Line / Improvise
    Then each seed is articulated by that Treatment at the Arp/Line Rate
    And Strum, Articulation and the phrase-arpeggio prototype apply to it
    And the seed clock and the note clock stay independent
    # built — mm_gravity_goto -> mm_articulate; the bypass branch in
    # mm_play_synced_beat is gone and mm_is_rate_treatment no longer excludes gravity

  @built
  Scenario: Changing a dropdown never retriggers Gravity Play
    Given Gravity Play is running
    When Treatment / Arp-Line Rate / Tempo / Sync is changed
    Then the note timer restarts but the gravity phase is untouched
    And the chord that is already sounding is not struck again
    # built — mm_restart_timer no longer re-phases gravity; gravity keeps
    # its own gravity_beat / mm_grav.accum counters

  @built
  Scenario: Gravity Play keeps one tempo whether or not Renoise is playing
    Given Gravity Play is running with Sync to BPM on
    When playback is stopped
    Then it keeps stepping at the same row length instead of drifting to another tempo
    # built — mm_gravity_free_tick uses mm_beat_ms (the same row length the
    # playback_pos path uses), not the free-run 16th-note clock

  @built
  Scenario: Gravity Play owns the sounding position
    Given Gravity Play is running
    When the mouse is moved over the play area
    Then it only aims (seeds can still be dropped/removed) and does not sound
    And Record to Pattern stamps one chord change per gravity beat, on the row
    # built — the gravity guard in mm_update_from_mouse restores deg_x/deg_y to the live seed

  @runtime-verified
  Scenario: Pressing a gravitation node performs the WHOLE gesture, not one note of it
    Given gravitation seeds exist and the Music Mouse window is open
    When the user presses cursor right to step to the next seed
    Then the current Treatment's entire gesture is played for that seed's chord:
      the full arpeggio run in the chosen direction, the complete rake in Strum,
      the ascending run in Line, the four-voice entry in Improvise,
      and a struck or raked chord in Chord
    And the free-running clock stands aside until the burst finishes
    And pressing again cancels a burst still in flight rather than piling voices up
    # runtime-verified 2026-08-31 over PakettiMCP, frozen clock, 4 voices, ONE press each:
    #   Arpeggiate Up 4 | Down 4 | Up/Down 6 (1-2-3-4-3-2) | Strum 4
    #   Line 4 | Improvise 4 | Chord+Strum 4      — every one of them was 1 before.
    #   Patterning ON: Chord 4, Arpeggiate 4, Line 4 (x3 runs), Improvise 4.
    # cite: PakettiMusicMouse.lua mm_perform_burst / mm_burst_order / mm_articulate; e1f6495f
    # NOT ear-confirmed by Esa yet — the counts are note-on counts, not a listening test.

  @built
  Scenario: Cursor up / down shifts an octave through the current Treatment
    Given the Music Mouse window is open
    When the user presses cursor up or cursor down
    Then the instrument shifts an octave and the new position is performed by the Treatment
    And cmd-up / cmd-down still select the previous / next instrument
    # built — mm_octave_shift -> mm_articulate(true). Seed stepping is also on the
    # ◀ Prev / Next ▶ buttons and the Gravity Seed Next/Previous MIDI mappings.

  @runtime-verified
  Scenario: A strum rake fits inside the beat that started it
    Given Strum is on with a spacing wide enough to overrun the row
    When a chord change arrives on the row clock
    Then the spacing is narrowed so the whole rake lands before the next chord
    And a new chord cancels any rake still in flight
    And staccato releases each strummed note just after that note sounds
    # runtime-verified 2026-08-31: at 94 BPM / LPB 4 the budget is 159.6 ms;
    # 28 ms spacing is left alone (84 ms fits), 67 ms x 3 gaps = 201 ms narrows to ~43 ms.
    # Before this, 67 ms left the last notes firing after their voices had been released
    # and re-assigned — stuck notes, and no audible strum. Gravity Play made it constant.
    # cite: mm_strum_spacing / mm_strum_budget_ms / mm_strum_cancel / mm_strum_pending; 44a01e89

  @runtime-verified
  Scenario: Strum can be chosen from either control that offers it
    Given the Treatment is Chord
    When Arp Mode is set to Strum
    Then the chord is raked, exactly as if the Strum checkbox were ticked
    # The Arp Mode popup sits beside the Treatment popup, so "Chord | Strum" reads as one
    # setting; Chord ignored arp_mode entirely and the real control was an unlabelled
    # checkbox elsewhere in the panel. Picking Strum there did nothing, silently.
    # runtime-verified 2026-08-31: Chord+ArpMode=Up -> Strum=false, Chord+ArpMode=Strum
    # -> Strum=true, with the checkbox off in both. cite: mm_strum_active; aae34805

  @runtime-verified
  Scenario: Automatic Gravity Play is not disturbed by the manual one
    Given Gravity Play is running on the row clock
    When it advances to the next seed on its own
    Then it only MOVES the harmony; the continuously running clock keeps articulating it
    And no burst is fired, so the automatic mode sounds as it did before
    # cite: mm_gravity_goto(delta, strike) — auto passes false, mm_gravity_step passes true

  @built
  Scenario: Leaving a Treatment stops the phrase it was driving
    Given the phrase-arpeggio prototype is on in Line or Arpeggiate
    When the Treatment is changed from the dropdown, cmd-1..4, F1-F4 or MIDI
    Then the held phrase is stopped before the new treatment starts
    And two phrases can no longer sound at once
    # Only the dropdown used to do this; the three keyboard/MIDI paths did not, so
    # leaving Line for Improvise left the old phrase playing underneath.
    # cite: mm_set_treatment — all four paths now route through it; e1f6495f

  @runtime-verified
  Scenario: A tool reload cannot destroy the saved gravitation seeds
    Given seeds and settings are saved in preferences
    When the tool reloads while the Music Mouse window is closed
    Then the rebuilt default state is never written back over them
    And the saved seeds, Sync and Strum spacing survive until the window loads them
    # A reload rebuilds mm from defaults (no seeds, Sync on, 28 ms) and the saved values are
    # only read back on dialog OPEN. In between, any control that saved — a loudness key, a
    # checkbox, a MIDI tempo knob — wrote the defaults over the real ones. Esa's three seeds
    # were destroyed this way during this session and had to be restored by hand.
    # cite: mm.prefs_loaded, set by mm_load_prefs, required by mm_save_prefs; 15f5c7d0

  @runtime-verified
  Scenario: No helper is called before it is declared
    Given Renoise runs Lua with strict globals, where reading an unassigned name throws
    When the file is scanned for calls to names declared later, or not at all
    Then PakettiMusicMouse.lua reports zero of either
    # This class is invisible to luac AND to the .spine load harness. It produced three real
    # faults here: mm_strum_cancel (a crash Esa hit mid-session, from a half-written file),
    # MM_STRUM_MS (dormant only because mm.strum_ms is never nil), and mm_rand — which sat
    # ~390 lines below mm_stamp_arpeggio, so stamping a Scatter arpeggio would have thrown.
    # `python3 .spine/check.py` now sweeps the whole repo for it: 61 pre-existing hits
    # elsewhere, 48 of them calls to functions that do not exist anywhere. cite: e1f6495f

  @stock
  Scenario: The file still fits Lua's 200-locals-per-chunk ceiling
    Given a .lua file is a function and every top-level local spends one of 200
    When PakettiMusicMouse.lua is compiled with N extra locals appended
    Then it still builds, and .spine/check.py warns below 25 of headroom
    # Crossing the line is not a warning: the file stops compiling, which in Renoise is a
    # brittle file and a dead tool load. 180/200 when this session started (8120 is three
    # times the size at 126). Scoping the Launchpad section in do...end took it to 36.
    # cite: .spine/localroom.lua + the check.py headroom section; PakettiMusicMouse-LOCALS.md

  @built
  Scenario: Arpeggiate has Up / Down / Scatter / Strum
    Given Treatment = Arpeggiate
    When the Arp Mode is Up / Down / Scatter
    Then the timer steps one voice per beat in that order (pitch-sorted; Scatter is random)
    When the Arp Mode is Strum and the user presses a sound key
    Then the chord is written on one line across note columns with rising delay-column offsets
    # built

  @built
  Scenario: i / o / p punch saved favorite waveforms; å = current; shift-i round-robin
    Given the user picked three favorite waveforms in the panel (persisted)
    When the user presses i / o / p (in keyjazz punch or normally)
    Then the chord is punched with favorite 1 / 2 / 3 (keeping Bell/Sustain), not a fixed shape
    When the user presses å
    Then the currently selected sound re-triggers without switching waveform
    When the user presses shift-i
    Then the next favorite is chosen round-robin and punched
    # built — mm.fav_waves saved via pakettiMusicMouseFav1..3

  @built
  Scenario: Tuning dropdown and < > transpose
    Given the Music Mouse dialog is open
    When the user picks a tuning from the Tuning dropdown
    Then that microtonal preset is applied to the selected instrument (tab still cycles)
    When the user presses < or >
    Then the pitch transposes down / up by the interval (alongside z / x)
    # built — PakettiMicrotonalSetTuning / PakettiMicrotonalTuningNames

  @built
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
    # built

  @built
  Scenario: Pattern contour up to 64 steps with a length switch
    Given the melodic-pattern editor
    When the user picks 8 / 16 / 32 / 64 on the length switch (or Len +)
    Then the contour grows/truncates to that length (max 64)
    And Len + reports a status when the maximum is reached
    # built

  @built
  Scenario: Keyboard Map is clickable and MIDI-mappable
    Given the "Keys / MIDI Map..." dialog
    Then keys are buttons grouped under bold headings with even alignment and a de-duped title (no em-dash)
    When the user clicks a key button
    Then it fires the exact same keyhandler path as pressing the key
    When the user enters cmd-M MIDI-map mode, clicks a button and moves a MIDI control
    Then that Music Mouse action binds to the control (each button has a registered Paketti:Music Mouse Key mapping)
    # built — buttons drive mm_keyhandler; per-key add_midi_mapping registered
