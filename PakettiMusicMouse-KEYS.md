# Music Mouse — Keyboard Map

Music Mouse owns only the keys listed here while its window is focused. **Every other key —
F5–F12, all Alt/Option combos, all Shift+Cmd combos, and anything unlisted — passes straight
through to Renoise**, so your own shortcuts stay live.

## Pitch / Harmony
| Key | Action |
|-----|--------|
| `q w e r t y` | Harmony mode: Chromatic · Octatonic · Middle-Eastern · Diatonic · Pentatonic · Quartal |
| `cmd-q … cmd-y` | Same, quiet (set without replaying) |
| `z` / `x` | Transpose down / up by the interval (cmd = quiet) |
| `c` | Reset transposition to 0 (cmd = quiet) |
| `shift-z` / `shift-x` | Transpose step − / + |
| `shift-c` | Reset interval to 1 |
| `tab` | Microtonal — internal-sound only; not available via note triggers |

## Patterns (melodic contours)
| Key | Action |
|-----|--------|
| `a` | Patterning on / off |
| `0-9` | Select pattern 1..10 |
| `v` | Pattern Applies: All → Melody (top) → Bass (bottom) |
| `s` | Pattern movement: Parallel / Contrary |
| (mouse) | Draw the contour bars in the Pattern Editor; Len − / Len + / Reset buttons |

## Voicing
| Key | Action |
|-----|--------|
| `d` | Mouse movement: Parallel / Contrary |
| `f` | Format: Chord-melody / Voice-pairs |
| `g` | Grouping on / off |

## Articulation / Loudness / Muting
| Key | Action |
|-----|--------|
| `/` | Staccato / Legato |
| `shift-/` | Half / Full Legato |
| `,` / `.` | Loudness down / up (shift = min / max) |
| `shift-1..4` | Mute / unmute voice 1..4 |
| `~` | Reverse all mutes (`shift-~` = all voices on) |

## Tempo
| Key | Action |
|-----|--------|
| `-` / `+` | Tempo 1 slower / faster (shift = 50 / 200) |
| `[` / `]` | Tempo 2 slower / faster (shift = 50 / 200) |
| `\` | Use Tempo 1 / 2 (shift-\ = default) |
| `n` | Sync to song BPM on / off |

## Treatment (rhythm of a chord)
| Key | Action |
|-----|--------|
| `cmd-1..4` / `F1-F4` | Chord / Arpeggiate / Line / Improvise |

## Sound
| Key | Action |
|-----|--------|
| `u i o p` | Waveform: Triangle · Square · Saw · Sine (re-strikes the chord, keeps Bell) |
| `m` | Cycle the full waveform palette (8 shapes) |
| `b` | Bell / Sustain mode |
| `cmd-up` / `cmd-down` | Previous / next instrument |

## Performance
| Key | Action |
|-----|--------|
| `space` | Freeze: pause mouse-follow + auto-play + sound (keys still drive it). While recording, also stops recording. |
| `option` / `alt` | Trigger the selected grid entry |
| `enter` | Lock current notes (keep ringing) |
| `shift-enter` | Release all locked notes |
| `right-shift` | Record to Pattern on / off (play + edit mode + follow + pattern editor) |
| `;` (or `shift-,`) | Gravity Play on / off — sequence the dropped gravitation seeds in recorded order |
| `l` | Clear all gravitation seeds |
| `left` / `right` | Previous / next gravitation seed — trigger the seeds one at a time from the keyboard. Works with Gravity Play running (it re-phases the auto clock) or stopped (fully manual). |
| `up` / `down` | Octave up / down, re-articulated through the current Treatment (follows the arpeggio / strum / line / phrase instead of forcing a block chord) |
| `delete` | Disconnect / reconnect mouse |
| `k` | Light / Dark theme |
| `home` | Re-Init all values |
| `esc` | Close Music Mouse |

## Gravity Play
Left-click the grid to drop a **gravitation seed** (a diamond); right-click removes the nearest one.
Gravity Play then walks the seeds in the order you dropped them.

- **Gravity Play only moves the position.** The **Treatment** (Chord / Arpeggiate / Line / Improvise)
  articulates whatever chord it lands on, at the **Arp/Line Rate**. So a seed can be strummed,
  arpeggiated up/down, played as a line, or held as a block chord — and the phrase prototype applies too.
- **Gravity Rate** (control panel) sets how often it moves, in **pattern rows**: every 1 / 2 / 4 / 8 / 16 rows.
  It is a separate clock from the note rate, so a slow chord change can carry a fast arpeggio.
- The clock is the **row clock** whether or not Renoise is playing — stopping the transport no longer
  changes the Gravity Play tempo.
- Changing Treatment, Arp/Line Rate, Tempo or Sync **never** re-phases Gravity Play, so a dropdown
  change can't retrigger the chord that is already sounding.
- While Gravity Play runs, the **mouse only aims** (so you can still drop and remove seeds) — the seed
  sequencer owns the sounding position. This is what makes `right-shift` recording usable: one
  chord change per gravity beat, landing on the row, instead of several unrelated chords per row.
- `left` / `right`, the **◀ Prev / Next ▶** buttons, and the MIDI mappings
  *Music Mouse Gravity Seed Next / Previous* step the seeds by hand.

## Mouse-/button-only (no key)
- **Generate New Pakettified Instrument** — button.
- **Sound on/off** — checkbox (use `space` to pause).
- **Pattern Editor** — draw bars; Len −/+ and Reset buttons.

## Launchpad (8×8 grid controller)
A **Launchpad** selector in the control panel (also `Global:Paketti:Music Mouse Launchpad Mode Cycle`, the
Instruments menu, and a MIDI mapping) switches the hardware mode:

| Mode | What it does |
|------|--------------|
| `Off` | Devices released, LEDs cleared. |
| `Play chords` | Each pad = a point on the play area; press it to punch the 4–9-voice chord at that X/Y (works even when frozen / in Keyjazz). An LED mirrors the live cursor pad; your last press flashes white. |
| `Raindrops demo` | Everything Play does, **plus** an expanding-ring light show — colour ripples out from every press and from ambient drops. |

Layout = Programmer mode, `note = row*10 + col` (row 1 = bottom, col 1 = left); colours use the mk3 velocity palette.
The device opens/closes with the mode and is released when Music Mouse closes or the song changes.
