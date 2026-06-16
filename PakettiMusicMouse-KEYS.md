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
| `shift-z` / `shift-x` | Interval of transposition − / + |
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
| `enter` | Lock current notes (keep ringing) |
| `shift-enter` | Release all locked notes |
| `right-shift` | Record to Pattern on / off (play + edit mode + follow + pattern editor) |
| `delete` | Disconnect / reconnect mouse |
| `k` | Light / Dark theme |
| `home` | Re-Init all values |
| `esc` | Close Music Mouse |

## Mouse-/button-only (no key)
- **Generate New Pakettified Instrument** — button.
- **Sound on/off** — checkbox (use `space` to pause).
- **Pattern Editor** — draw bars; Len −/+ and Reset buttons.
