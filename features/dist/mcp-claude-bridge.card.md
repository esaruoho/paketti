# Report Card — Paketti × Claude MCP + probe bridges (Renoise ↔ Claude)

> Source: `features/mcp-claude-bridge.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 11 · @hw-verified × 4 · @untested × 7

**Scenarios: 11**


---


## 1. Start the MCP server

`@built @hw-verified`


- Given Renoise is running with Paketti loaded
- When the user opens the MCP Server Dialog (auto-starts), or triggers
- "Main Menu:Tools:Paketti:!Preferences:MCP Server Start"
- Then PakettiMCP/server.lua opens an HTTP listener on localhost:19714
- And router.load_tools_dir auto-loads every PakettiMCP/tools/*.lua (79 tools)
- And the dialog shows "PakettiMCP Server", "79 tools loaded", "Running on port 19714"


## 2. Any MCP client / curl discovers the tool surface

`@built @hw-verified`


- Given the MCP server is running
- When a client POSTs {"method":"tools/list"} to http://localhost:19714/mcp
- Then the server returns 79 JSON-RPC tool definitions
- And GET http://localhost:19714/health returns {"status":"ok","server":"PakettiMCP"}


## 3. Claude READS live song state (the "watch it render" half)

`@built @hw-verified`


- Given the MCP server is running and a song is loaded
- When Claude calls tool "song_get_info" (or transport_get_position / pattern_get_notes)
- Then the server returns the CURRENT bpm, lpb, track/instrument/pattern counts,
- playhead position, and actual note data — read live, not cached


## 4. Claude WRITES into the song (the bidirectional half)

`@built @hw-verified`


- Given the MCP server is running
- When Claude calls "transport_set_bpm" {"bpm":174}, then "pattern_set_note",
- then "transport_play"
- Then the song BPM changes to 174, the note lands in the pattern,
- and playback starts — all observable in Renoise in real time


## 5. The 79 tools span the whole Renoise object model

`@built @untested`


- Given the MCP server is running
- When Claude calls a tool in the "<group>" group
- Then it operates on the corresponding Renoise objects via the Lua API
- Examples:
- | group       | example tools                                              |
- | song        | song_get_info, song_set_name, song_undo, song_redo         |
- | transport   | transport_play/stop/panic, transport_set_bpm/lpb/tpl       |
- | tracks      | tracks_list, track_add/remove, track_set_volume, group_add |
- | patterns    | pattern_set_note, pattern_get_notes, pattern_fill_random   |
- | sequencer   | sequencer_insert, sequencer_clone_range, sequencer_jump_to |
- | instruments | instruments_list, sample_add, instrument_set_transpose     |
- | devices     | track_device_add, track_device_set_param, plugins_search   |
- | paketti     | paketti_groovebox, paketti_pattern_shrink/expand           |


## 6. Paketti-specific verbs drive Paketti's own dialogs over MCP

`@built @untested`


- Given the MCP server is running
- When Claude calls "paketti_groovebox" or "paketti_pattern_preset_dialog"
- Then the corresponding Paketti dialog opens/closes (calls the global fn directly)
- And "paketti_pattern_shrink"/"paketti_pattern_expand" halve/double the
- selected pattern length via the existing resize_pattern global


## 7. Index conventions are non-uniform (inherited from ReMCP)

`@built @untested`


- Given Claude is addressing patterns/instruments vs tracks/lines/columns
- Then patterns and instruments are 0-based
- But tracks, lines, note columns, effect columns and DSP devices are 1-based


## 8. Stop the server cleanly

`@built @untested`


- Given the MCP server is running
- When the user triggers "Main Menu:Tools:Paketti:!Preferences:MCP Server Stop"
- Then the listener closes and the status bar confirms "server stopped"


## 9. Dump arbitrary Renoise state for Claude to read off disk

`@built @untested`


- Given Paketti is loaded (no MCP server needed)
- When the user (or Claude via OSC) calls PakettiClaudeProbeRun("renoise.song().selected_track.name")
- Then the expression is evaluated in FULL tool context (real io access, unlike
- the /renoise/evaluate OSC sandbox)
- And the serialized result is written to /tmp/paketti-probe.txt with a header
- (timestamp, label, expression, lua type, ok flag) for Claude to cat


## 10. Zero-typing quick probes

`@built @untested`


- Given Paketti is loaded
- When the user triggers "Global:Paketti:Claude Probe <subject>"
- Then a structured snapshot of <subject> is written to /tmp/paketti-probe.txt
- Examples:
- | subject            |
- | Song               |
- | Selected Track     |
- | Selected Instrument|
- | Available Devices  |
- | Custom Expression  |


## 11. Talk to a Claude /loop session from a Renoise dialog

`@built @untested`


- Given a Claude /loop session is polling /tmp/claude-inbox.txt on the same Mac
- When the user opens "Global:Paketti:Claude Chat Dialog", types a message, hits Send
- Then the message is written (truncate-first for fresh mtime) to /tmp/claude-inbox.txt
- And Claude polls it, does work, and replies via OSC /renoise/evaluate calling
- _PakettiClaudeReply(text), which appends to the dialog's response area
- And a transcript is logged to /tmp/claude-chat-log.txt

