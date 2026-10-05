# Report Card — Delete note-offs while preserving neighboring data

> Source: `features/note-off-cleanup.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @built × 1 · @runtime-untested × 3 · @sim-verified × 2

**Scenarios: 3**


---


## 1. Remove OFFs only in the requested scope

`@sim-verified @runtime-untested`


- Given note-offs in visible and hidden columns across used and unused patterns
- When I invoke Delete Note Offs in <scope>
- Then only OFF note values in that scope become empty
- And notes, instruments, volume, panning, delay and effects are preserved
- Examples:
- | scope |
- | Track |
- | Pattern |
- | Track (Whole Song) |
- | Song |

<sub>cite: PakettiPatternEditor.lua PakettiDeleteNoteOffs</sub>


## 2. Cleanup commands are accessible and repeat safe

`@sim-verified @runtime-untested`


- Given the four cleanup commands
- When I use their menu, keybinding or trigger MIDI mapping
- Then the requested scope is processed with an undo description and deletion count
- And repeated key events and non-trigger MIDI messages do nothing
- And selected group, master and send tracks are rejected for track-only scopes

<sub>cite: PakettiPatternEditor.lua PakettiDeleteNoteOffs registration block</sub>


## 3. Credit the source idea

`@built @runtime-untested`


- Given the Ideas and Thanks dialog
- When I read Ideas provided by
- Then Phaos appears in the list

<sub>cite: PakettiMainMenuEntries.lua IDEAS</sub>

