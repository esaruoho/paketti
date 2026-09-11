# Report Card — Music Mouse — Laurie Spiegel's "Intelligent Instrument" (1986) in Renoise

> Source: `features/music-mouse.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 29 · @runtime-verified × 6 · @stock × 1

**Scenarios: 36**


---


## 1. Open Music Mouse from the menu

`@built @user-verified`


- Given Paketti is loaded
- When the user picks Main Menu:Tools:Paketti:Music Mouse...
- Then the Music Mouse dialog opens with the keyboard grid and the control panel


## 2. Move the mouse to play a quantized 4-voice chord

`@built @user-verified`


- Given the Music Mouse dialog is open and an instrument is selected
- When the user moves the mouse over the play area in Diatonic harmony
- Then four voices sound (3-note chord on X + melody on Y), snapped to the scale
- And the active keys light up on all four edge keyboards


## 3. Generate a Pakettified Bell instrument by default

`@built @user-verified`


- Given the Music Mouse dialog is open
- When the user clicks Generate New Pakettified Instrument (or a waveform key)
- Then the Paketti Default Instrument is loaded and the single-cycle wave rendered into it
- And the sample is tuned with the PCM Writer convention (transpose + fine_tune)
- And Mode defaults to Bell (non-looping decay) so notes ring and fade


## 4. 4 voices is classic Music Mouse; 5-9 give richer chords

`@built @user-verified`


- Given the Voices switch
- When set to 4
- Then the voicing is exactly classic Music Mouse (3-note X chord + Y melody)
- When set to 5..9
- Then extra scale-thirds stack on the X chord (7th/9th/11th/13th voicings)


## 5. Record what you play into the pattern (right-shift)

`@built @user-verified`


- Given the Music Mouse dialog is open
- When the user presses right-shift (or the Record checkbox)
- Then the Pattern Editor becomes active, Edit Mode + Follow turn on, playback starts
- And as notes trigger they are written to the selected track at the playhead line
- And the picked Loudness is written as the note volume column
- And pressing right-shift again stops recording and turns Edit Mode + Follow off


## 6. Gravitation seeds and Gravity Play

`@built @user-verified`


- Given the Music Mouse dialog is open
- When the user left-clicks the play area
- Then a green diamond seed is dropped at that chord and it plays
- When the user triggers Gravity Play (shift-comma / button / MIDI)
- Then the timer steps through the seeds in recorded order, one seed per gravity beat
- And the seeds persist across close/reopen and reloads


## 7. Music Mouse owns its keys but lets your shortcuts through

`@built @user-verified`


- Given the Music Mouse dialog is focused
- When the user presses a key Music Mouse maps (q, a, z, ...)
- Then Music Mouse handles it and Renoise does not
- When the user presses an unmapped key, shift+cmd combo, Alt/Option, or F5-F12
- Then it passes through to Renoise


## 8. Sync the pattern player to the song BPM, controllable by MIDI

`@built @user-verified`


- Given Sync-to-BPM is on (default)
- When the song BPM changes (or a MIDI slider mapped to Music Mouse BPM moves)
- Then the pattern/Gravity-Play step rate follows the song tempo live


## 9. tab cycles the selected instrument through Paketti's microtonal tunings

`@built @user-verified`


- Given the Music Mouse dialog is open
- When the user presses tab
- Then the selected instrument's tuning advances to the next preset (12-TET first, then wraps)
- And the notes re-strike and play in that tuning (trigger_options.tuning)


## 10. A Launchpad plays Music Mouse and runs a Raindrops light show

`@built`


- Given a Novation Launchpad is connected and the Music Mouse dialog is open
- When the user sets the Launchpad selector to "Play chords"
- Then the device enters Programmer mode and pressing a pad (note = row*10+col)
- punches the chord at that pad's X/Y, and an LED mirrors the live cursor pad
- When the user sets it to "Raindrops demo"
- Then pads still trigger chords AND expanding rings of colour ripple out from
- each press and from ambient drops
- When the user sets it to "Off" (or closes Music Mouse / changes song)
- Then the LEDs clear and the in/out MIDI devices are released


## 11. Loudness persists and never boots silent

`@built @user-verified`


- Given the user set Loudness to a value and closed the dialog
- When the dialog is reopened (or the tool reloaded)
- Then the Loudness is restored
- And a stored 0 (silent) falls back to an audible default instead of booting near-mute


## 12. Changing a control never re-strikes the chord (and never sounds while frozen)

`@built`


- Given the Music Mouse dialog is open with a chord ringing
- When the user changes Voices, Harmonic Mode, Voicing Format, Transposition,
- Mouse Movement, Pattern Applies, or any dropdown / checkbox / switch
- Then the target notes are recomputed and the grid redraws WITHOUT re-triggering the chord
- And the new state is heard only on the next mouse move or i/o/p punch
- And while frozen (space) nothing is ever triggered


## 13. Chord changes are batched so there is no MIDI jitter

`@built`


- Given a chord is sounding
- When the mouse moves to a new chord
- Then the note-offs and note-ons are each sent as a SINGLE chord trigger call (no per-voice flam)
- And voices whose note is unchanged are left ringing (no boundary jitter)


## 14. Pattern Applies = Melody sequences one voice over a sustained chord (no flood)

`@built @mcp-verified`


- Given Pattern is on, Treatment = Chord, and Pattern Applies = Melody
- When the pattern timer advances each beat
- Then only the melody voice steps its note; the chord voices are struck once then left ringing
- And the whole chord is NOT re-triggered on every melody step


## 15. Recording auto-widens the track to the voice count

`@built @mcp-verified`


- Given Voices = 6 and Record to Pattern is armed
- Then the selected track's visible note columns grow to at least 6 so the chord writes across columns


## 16. space is owned by Music Mouse and never bleeds to the pattern editor

`@built`


- Given the Music Mouse dialog is focused (even with the mouse off the grid, or while recording)
- When the user presses space
- Then Music Mouse freezes/unfreezes and consumes the key before any passthrough
- And Renoise transport / pattern editor never receives it


## 17. Gravity Play rate is stated in pattern rows

`@built`


- Given gravitation seeds exist and Gravity Play is on
- When the Gravity Rate is set to every 1 / 2 / 4 / 8 / 16 rows
- Then a seed is moved to only every Nth crossed row


## 18. Gravity Play moves the position; the Treatment plays it

`@built`


- Given gravitation seeds exist and Gravity Play is on
- When the Treatment is Chord / Arpeggiate / Line / Improvise
- Then each seed is articulated by that Treatment at the Arp/Line Rate
- And Strum, Articulation and the phrase-arpeggio prototype apply to it
- And the seed clock and the note clock stay independent


## 19. Changing a dropdown never retriggers Gravity Play

`@built`


- Given Gravity Play is running
- When Treatment / Arp-Line Rate / Tempo / Sync is changed
- Then the note timer restarts but the gravity phase is untouched
- And the chord that is already sounding is not struck again


## 20. Gravity Play keeps one tempo whether or not Renoise is playing

`@built`


- Given Gravity Play is running with Sync to BPM on
- When playback is stopped
- Then it keeps stepping at the same row length instead of drifting to another tempo


## 21. Gravity Play owns the sounding position

`@built`


- Given Gravity Play is running
- When the mouse is moved over the play area
- Then it only aims (seeds can still be dropped/removed) and does not sound
- And Record to Pattern stamps one chord change per gravity beat, on the row


## 22. Pressing a gravitation node performs the WHOLE gesture, not one note of it

`@runtime-verified`


- Given gravitation seeds exist and the Music Mouse window is open
- When the user presses cursor right to step to the next seed
- Then the current Treatment's entire gesture is played for that seed's chord:
- the full arpeggio run in the chosen direction, the complete rake in Strum,
- the ascending run in Line, the four-voice entry in Improvise,
- and a struck or raked chord in Chord
- And the free-running clock stands aside until the burst finishes
- And pressing again cancels a burst still in flight rather than piling voices up

<sub>cite: PakettiMusicMouse.lua mm_perform_burst / mm_burst_order / mm_articulate; e1f6495f</sub>


## 23. Cursor up / down shifts an octave through the current Treatment

`@built`


- Given the Music Mouse window is open
- When the user presses cursor up or cursor down
- Then the instrument shifts an octave and the new position is performed by the Treatment
- And cmd-up / cmd-down still select the previous / next instrument


## 24. A strum rake fits inside the beat that started it

`@runtime-verified`


- Given Strum is on with a spacing wide enough to overrun the row
- When a chord change arrives on the row clock
- Then the spacing is narrowed so the whole rake lands before the next chord
- And a new chord cancels any rake still in flight
- And staccato releases each strummed note just after that note sounds

<sub>cite: mm_strum_spacing / mm_strum_budget_ms / mm_strum_cancel / mm_strum_pending; 44a01e89</sub>


## 25. Strum can be chosen from either control that offers it

`@runtime-verified`


- Given the Treatment is Chord
- When Arp Mode is set to Strum
- Then the chord is raked, exactly as if the Strum checkbox were ticked


## 26. Automatic Gravity Play is not disturbed by the manual one

`@runtime-verified`


- Given Gravity Play is running on the row clock
- When it advances to the next seed on its own
- Then it only MOVES the harmony; the continuously running clock keeps articulating it
- And no burst is fired, so the automatic mode sounds as it did before

<sub>cite: mm_gravity_goto(delta, strike) — auto passes false, mm_gravity_step passes true</sub>


## 27. Leaving a Treatment stops the phrase it was driving

`@built`


- Given the phrase-arpeggio prototype is on in Line or Arpeggiate
- When the Treatment is changed from the dropdown, cmd-1..4, F1-F4 or MIDI
- Then the held phrase is stopped before the new treatment starts
- And two phrases can no longer sound at once

<sub>cite: mm_set_treatment — all four paths now route through it; e1f6495f</sub>


## 28. A tool reload cannot destroy the saved gravitation seeds

`@runtime-verified`


- Given seeds and settings are saved in preferences
- When the tool reloads while the Music Mouse window is closed
- Then the rebuilt default state is never written back over them
- And the saved seeds, Sync and Strum spacing survive until the window loads them

<sub>cite: mm.prefs_loaded, set by mm_load_prefs, required by mm_save_prefs; 15f5c7d0</sub>


## 29. No helper is called before it is declared

`@runtime-verified`


- Given Renoise runs Lua with strict globals, where reading an unassigned name throws
- When the file is scanned for calls to names declared later, or not at all
- Then PakettiMusicMouse.lua reports zero of either


## 30. The file still fits Lua's 200-locals-per-chunk ceiling

`@stock`


- Given a .lua file is a function and every top-level local spends one of 200
- When PakettiMusicMouse.lua is compiled with N extra locals appended
- Then it still builds, and .spine/check.py warns below 25 of headroom

<sub>cite: .spine/localroom.lua + the check.py headroom section; PakettiMusicMouse-LOCALS.md</sub>


## 31. Arpeggiate has Up / Down / Scatter / Strum

`@built`


- Given Treatment = Arpeggiate
- When the Arp Mode is Up / Down / Scatter
- Then the timer steps one voice per beat in that order (pitch-sorted; Scatter is random)
- When the Arp Mode is Strum and the user presses a sound key
- Then the chord is written on one line across note columns with rising delay-column offsets


## 32. i / o / p punch saved favorite waveforms; å = current; shift-i round-robin

`@built`


- Given the user picked three favorite waveforms in the panel (persisted)
- When the user presses i / o / p (in keyjazz punch or normally)
- Then the chord is punched with favorite 1 / 2 / 3 (keeping Bell/Sustain), not a fixed shape
- When the user presses å
- Then the currently selected sound re-triggers without switching waveform
- When the user presses shift-i
- Then the next favorite is chosen round-robin and punched


## 33. Tuning dropdown and < > transpose

`@built`


- Given the Music Mouse dialog is open
- When the user picks a tuning from the Tuning dropdown
- Then that microtonal preset is applied to the selected instrument (tab still cycles)
- When the user presses < or >
- Then the pitch transposes down / up by the interval (alongside z / x)


## 34. Layout polish and width toggles

`@built`


- Given the Music Mouse dialog is open
- Then labels are strong proportional (not wide mono); the mute row is tight
- And Waveform + Mode + Create New share one aligned row ("Waveform"); the Pattern popup width is matched
- And Record to Pattern is a button that is RED when armed, grey when off
- And Launchpad / help text lives in tooltips
- When the user ticks Hide pianos
- Then only the woven grid draws (the 4 edge keyboards are skipped)
- When the user ticks Hide details
- Then the control panel + pattern editor collapse, leaving the grid for a narrow window


## 35. Pattern contour up to 64 steps with a length switch

`@built`


- Given the melodic-pattern editor
- When the user picks 8 / 16 / 32 / 64 on the length switch (or Len +)
- Then the contour grows/truncates to that length (max 64)
- And Len + reports a status when the maximum is reached


## 36. Keyboard Map is clickable and MIDI-mappable

`@built`


- Given the "Keys / MIDI Map..." dialog
- Then keys are buttons grouped under bold headings with even alignment and a de-duped title (no em-dash)
- When the user clicks a key button
- Then it fires the exact same keyhandler path as pressing the key
- When the user enters cmd-M MIDI-map mode, clicks a button and moves a MIDI control
- Then that Music Mouse action binds to the control (each button has a registered Paketti:Music Mouse Key mapping)

