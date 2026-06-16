# Music Mouse — Melodic Patterns (the `a` + `0-9` contours)

## What they are

Each of the 10 patterns is a list of **scale-degree offsets** (NOT notes, NOT semitones).
When patterning is on (`a`), one offset per tempo tick is **added** to the current voice
degree(s), then mapped through the active harmony mode. So:

- `0` = the current note (no offset)
- `2` = two scale-steps up (a "third" in a 7-note scale)
- `7` = seven scale-steps up (an octave in a 7-note scale)
- `11` = eleven scale-steps up (~a tenth/octave-and-a-third)

Because they are abstract contours, the same pattern sounds different in
Diatonic vs Pentatonic vs Quartal etc.

## The 10 built-in contours (from Spiegel's original)

| Key | Contour (scale-degree offsets) | Length | Character |
|-----|--------------------------------|--------|-----------|
| 1 | 0 4 5 0 4 3 4 5 0 4 | 10 | bouncy riff between root and 5th/6th |
| 2 | 0 2 4 7 4 2 | 6 | triad arpeggio up+down — the most "musical" |
| 3 | 0 1 2 3 4 3 2 1 | 8 | smooth scale run to the 5th and back |
| 4 | 0 1 2 3 4 5 6 7 6 5 4 3 2 1 | 14 | full octave scale wave |
| 5 | 0 4 7 11 7 4 7 4 | 8 | wide, dramatic ~2-octave arpeggio |
| 6 | 0 1 0 1 2 1 2 3 2 3 4 3 2 3 2 1 | 16 | aimless stepwise wander (the DEFAULT) |
| 7 | 0 2 3 4 5 6 5 4 3 2 | 10 | gentle scalar climb, skips the 2nd |
| 8 | 0 7 1 6 2 5 3 4 5 2 4 5 2 6 1 7 | 16 | chaotic wide zigzag leaps |
| 9 | 0 1 4 1 0 4 0 4 | 8 | small root/2nd/5th ostinato |
| 0 | 0 0 0 0 7 0 0 2 1 2 4 3 4 2 1 2 | 16 | sparse root with an octave poke |

## Why they can sound bad in the Renoise port

- The offset is applied to **all four voices in parallel**, so the whole chord leaps
  as a block — muddy, especially with the chord-stacking voicing.
- Fixed tempo, no phrasing — long/large-leap patterns (5, 8) sound random.
- The default is #6, a meander, which gives a poor first impression.

## Editing

The pattern editor (in the Music Mouse dialog) lets you redraw any of the 10 contours
as a step bar-graph: click/drag a step to set its offset, change the length, reset to the
original Spiegel contour. Edits take effect live (the player reads the arrays each tick).

Future: persist edited patterns to preferences; per-voice pattern application (so the
contour ornaments one voice instead of shifting the whole chord).
