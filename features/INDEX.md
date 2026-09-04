# Report Cards — Index

The commit ⇄ card map. Every behaviour cluster in this repo gets ONE card
(`<name>.feature`), its spawning conversation (`<name>.session.md`), and a
RESULT-LOG of what shipped. Enrol each new card here.

Derived views — GENERATED, never hand-edit:
- `README.md` — what each card does + how it does it (`print-card.py --readme`)
- `STATUS.md` — the test matrix from the `@grade` tags (`gen-status.py`)
- `SESSIONS.generated.md` — the conversations behind the cards (`gen-sessions.py`)

| Card | What it covers | Session | Shipped in |
|------|----------------|---------|------------|
| `2026-06-11-groovebox-controller-follow-and-menu.feature` | AKAI controller debug/demo entries moved out of the Groovebox menu | `2026-06-11-groovebox-controller-follow-and-menu.session.md` | `37f054b1` `aae34805` `5483d3e3` |
| `2026-06-11-ui-fixes-and-menu-config.feature` | Groovebox 8120 Kit loader status column alignment | `2026-06-11-ui-fixes-and-menu-config.session.md` | `47e81a77` `bc06819a` `2a1bce7a` |
| `device-hotswap-missing-to-actual.feature` | Device hotswap — missing plugins → actually-installed equivalents | — | `bc06819a` `2300b421` |
| `device-toggle-automation.feature` | Device Control NN enable/disable/toggle records bypass automation | `device-toggle-automation.session.md` | worktree |
| `execute-command-slots.feature` | 128 labeled os.execute command slots with shortcut, MIDI, and $s sample-range support | `execute-command-slots.session.md` | pending |
| `groovebox-8120-default-instrument-slots.feature` | Groovebox 8120 fills 8 instrument slots with the Paketti Default Instrument on empty-song open | — | `bc06819a` `d045e817` |
| `groovebox-8120-grid-controllers.feature` | Groovebox 8120 grid controllers (Akai MidiMix + APC Key 25 + LPD8) | — | `bc06819a` `a3636675` `7d3dd71f` |
| `groovebox-8120-lpd8.feature` | Groovebox 8120 — AKAI LPD8 controller (8 pads + pages + follow + row select) | — | `bc06819a` `a3636675` `7d3dd71f` |
| `groovebox-8120-record-pakettified-instrument.feature` | Groovebox 8120 Record button records into a Pakettified instrument | — | `1797e45a` `34fac2d3` `bc06819a` |
| `master-low-cut-200hz.feature` | Master Low-Cut 200Hz punch toggle | — | `bc06819a` `d348b0be` |
| `mcp-claude-bridge.feature` | Paketti × Claude MCP + probe bridges (Renoise ↔ Claude) | — | `4bc8daab` `26c583a5` `bc06819a` |
| `mlx-renoise-bridge.feature` | Human → local-LLM → Renoise bridge (zero Claude, zero Anthropic tokens) | — | `4bc8daab` `26c583a5` `bc06819a` |
| `music-mouse.feature` | Music Mouse — Laurie Spiegel's "Intelligent Instrument" (1986) in Renoise | `music-mouse.session.md` | `37f054b1` `c3465c5d` `ab144dc2` |
| `parameter-editor-mixer-and-config.feature` | Parameter Editor exposes on the Mixer the parameter you're modifying | `parameter-editor-mixer-and-config.session.md` | `bc06819a` `b4a43b27` `94e4c343` |
| `pattern-song-jumps.feature` | Pattern fraction jumps and reversible last row-jump commands for pattern/song navigation | `pattern-song-jumps.session.md` | worktree |
| `pattern-editor-example.feature` | Pattern Editor note manipulation | — | `bc06819a` `b953f2f4` |
| `repeater-control.feature` | Repeater selected-track/master keybindings and MIDI controls | `repeater-control.session.md` | worktree |
| `selection-reversed-instrument.feature` | Reverse-duplicate selected instrument and retarget selected pattern notes to it | `selection-reversed-instrument.session.md` | worktree |
| `section-loop-immediate-switch.feature` | Section-loop next/previous commands that switch immediately instead of scheduling | `section-loop-immediate-switch.session.md` | worktree |
| `song-lifecycle-safety.feature` | Song-lifecycle safety for canvas dialogs and song observers | — | `bc06819a` `3d2cd863` `83526e80` |
| `subcolumn-only-invert.feature` | Volume/panning/delay/sample-FX-only note subcolumn inversion | `subcolumn-only-invert.session.md` | worktree |
