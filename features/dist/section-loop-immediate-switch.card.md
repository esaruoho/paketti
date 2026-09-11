# Report Card — Section loop switches trigger immediately

> Source: `features/section-loop-immediate-switch.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti live performer, I want next/previous section loop commands that switch immediately, So that a footswitch can move a song between section loops without waiting for scheduled playback.

**Grades:** @built × 4 · @code-verified × 4 · @runtime-untested × 4 · @shipped × 4 · @stock × 1

**Scenarios: 5**


---


## 1. Next command starts the current section when it is not already looped

`@shipped @built @code-verified @runtime-untested`


- Given the selected sequence is inside a section
- And the transport loop range is not exactly the current section
- When the user invokes "Global:Paketti:Set Section Loop and Switch Section Immediately (Next)"
- Then Paketti sets the loop range to the current section
- And immediately triggers the first sequence of the current section

<sub>cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2028) - compares current section bounds against transport.loop_sequence_range before deciding the target ; commit worktree</sub>


## 2. Next command advances when the current section is already looped

`@shipped @built @code-verified @runtime-untested`


- Given the selected sequence is inside a section
- And the transport loop range exactly matches that section
- When the user invokes the immediate next section-loop command
- Then Paketti sets the loop range to the next section
- And immediately triggers the first sequence of the next section

<sub>cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2070) - advances from the current section to the next section only when the current section is already looping ; commit worktree</sub>


## 3. Previous command retreats when the current section is already looped

`@shipped @built @code-verified @runtime-untested`


- Given the selected sequence is inside a section
- And the transport loop range exactly matches that section
- When the user invokes "Global:Paketti:Set Section Loop and Switch Section Immediately (Previous)"
- Then Paketti sets the loop range to the previous section
- And immediately triggers the first sequence of the previous section

<sub>cite: PakettiTkna.lua tknaSetSectionLoopAndSwitchImmediately (~line 2077) - retreats from the current section to the previous section only when the current section is already looping ; commit worktree</sub>


## 4. Commands are available from shortcuts, MIDI, and Pattern Sequencer menus

`@shipped @built @code-verified @runtime-untested`


- Given the Paketti tool is installed
- When Renoise lists Paketti section-loop actions
- Then the two global shortcut actions are available
- And the two MIDI trigger mappings are available
- And the two Pattern Sequencer menu entries are available

<sub>cite: PakettiTkna.lua keybinding and MIDI registrations (~line 2112) - registers next/previous shortcut and MIDI trigger mappings ; commit worktree · PakettiMenuConfig.lua menu registrations (~line 4158) - exposes next/previous immediate switch actions in the Pattern Sequencer menu ; commit worktree</sub>


## 5. Scheduled section command remains separate

`@stock`


- Given the user invokes "Global:Paketti:Set Section Loop and Schedule Section"
- When the current section is found
- Then Paketti still uses scheduled playback instead of immediate trigger switching

<sub>cite: PakettiTkna.lua tknaAddLoopAndScheduleSection (~line 1975) - existing scheduled-section command remains registered and unchanged ; commit worktree</sub>

