Feature: Paketti × Claude MCP + probe bridges (Renoise ↔ Claude)
Context: Global

  # WHAT THIS IS / THE GIST
  # -----------------------
  # Paketti ships THREE distinct Renoise↔Claude bridges, not one. They differ on
  # two axes: direction (read / write / both) and transport (HTTP / file / OSC).
  # Together they are the "MCP bridge" — yes, it exists, and one leg of it (the
  # MCP server) is fully bidirectional and live, so Claude CAN watch the song
  # change while Renoise renders. Grades below are honest: code is @built and
  # git-tracked + wired into main.lua (timed_require lines 1318-1320), and the
  # MCP server leg is HARDWARE-VERIFIED (curl'd live: 79 tools, /health ok on
  # 2026-06-11). The Probe and Chat legs are @untested-here because they need a
  # running Renoise + a Claude /loop session.
  #
  #   1. PakettiMCP        — HTTP MCP server, 79 tools, READ+WRITE, bidirectional
  #   2. PakettiClaudeProbe— one-shot Lua eval in TOOL context → /tmp file, READ
  #   3. PakettiClaudeChat — in-Renoise chat dialog, file-in / OSC-out, BOTH
  #
  # NOT IN SCOPE HERE: PakettiXRNSProbe (offline .xrns binary analyzer) is a
  # SEPARATE project — see features/device-hotswap-missing-to-actual.feature,
  # where the XRNS dissection feeds the missing-device hotswap idea.
  #
  # ATTRIBUTION: the MCP core (PakettiMCP/json.lua, router.lua, server.lua,
  # dialog.lua, tools/{song,transport,tracks,patterns,sequencer,instruments,
  # devices}.lua) is adapted from kraken@renoise.com's ReMCP (MIT). Paketti adds
  # tools/paketti.lua and Paketti-specific verbs (plugins_search,
  # pattern_fill_random, pattern_copy_track, paketti_*).
  #
  # WHY I KEPT SAYING "no MCP bridge": wrong. PakettiMCP is a real MCP server.
  # The thing that was missing was a FEATURE CARD describing it — this file.

  # =====================================================================
  # LEG 1 — PakettiMCP: the real MCP server (HTTP JSON-RPC 2.0, 79 tools)
  # PakettiMCPMain.lua + PakettiMCP/{server,router,json,dialog}.lua + tools/*.lua
  # =====================================================================

  @built @hw-verified
  Scenario: Start the MCP server
    Given Renoise is running with Paketti loaded
    When the user opens the MCP Server Dialog (auto-starts), or triggers
         "Main Menu:Tools:Paketti:!Preferences:MCP Server Start"
      # the dialog auto-starts on open, so its toggle reads "Stop Server" while up
    Then PakettiMCP/server.lua opens an HTTP listener on localhost:19714
    And router.load_tools_dir auto-loads every PakettiMCP/tools/*.lua (79 tools)
    And the dialog shows "PakettiMCP Server", "79 tools loaded", "Running on port 19714"

  @built @hw-verified
  Scenario: Any MCP client / curl discovers the tool surface
    Given the MCP server is running
    When a client POSTs {"method":"tools/list"} to http://localhost:19714/mcp
    Then the server returns 79 JSON-RPC tool definitions
    And GET http://localhost:19714/health returns {"status":"ok","server":"PakettiMCP"}

  @built @untested
  Scenario: Claude READS live song state (the "watch it render" half)
    Given the MCP server is running and a song is loaded
    When Claude calls tool "song_get_info" (or transport_get_position / pattern_get_notes)
    Then the server returns the CURRENT bpm, lpb, track/instrument/pattern counts,
         playhead position, and actual note data — read live, not cached
    # This is the answer to "no way to watch something render alive": there is.

  @built @untested
  Scenario: Claude WRITES into the song (the bidirectional half)
    Given the MCP server is running
    When Claude calls "transport_set_bpm" {"bpm":174}, then "pattern_set_note",
         then "transport_play"
    Then the song BPM changes to 174, the note lands in the pattern,
         and playback starts — all observable in Renoise in real time

  @built @untested
  Scenario Outline: The 79 tools span the whole Renoise object model
    Given the MCP server is running
    When Claude calls a tool in the "<group>" group
    Then it operates on the corresponding Renoise objects via the Lua API

    Examples:
      | group       | example tools                                              |
      | song        | song_get_info, song_set_name, song_undo, song_redo         |
      | transport   | transport_play/stop/panic, transport_set_bpm/lpb/tpl       |
      | tracks      | tracks_list, track_add/remove, track_set_volume, group_add |
      | patterns    | pattern_set_note, pattern_get_notes, pattern_fill_random   |
      | sequencer   | sequencer_insert, sequencer_clone_range, sequencer_jump_to |
      | instruments | instruments_list, sample_add, instrument_set_transpose     |
      | devices     | track_device_add, track_device_set_param, plugins_search   |
      | paketti     | paketti_groovebox, paketti_pattern_shrink/expand           |

  @built @untested
  Scenario: Paketti-specific verbs drive Paketti's own dialogs over MCP
    Given the MCP server is running
    When Claude calls "paketti_groovebox" or "paketti_pattern_preset_dialog"
    Then the corresponding Paketti dialog opens/closes (calls the global fn directly)
    And "paketti_pattern_shrink"/"paketti_pattern_expand" halve/double the
        selected pattern length via the existing resize_pattern global

  @built @untested
  Scenario: Index conventions are non-uniform (inherited from ReMCP)
    Given Claude is addressing patterns/instruments vs tracks/lines/columns
    Then patterns and instruments are 0-based
    But tracks, lines, note columns, effect columns and DSP devices are 1-based
    # pattern_set_note takes pattern=0, track=1, line=1. Get this wrong = wrong slot.

  @built @untested
  Scenario: Stop the server cleanly
    Given the MCP server is running
    When the user triggers "Main Menu:Tools:Paketti:!Preferences:MCP Server Stop"
    Then the listener closes and the status bar confirms "server stopped"

  # =====================================================================
  # LEG 2 — PakettiClaudeProbe: one-shot Lua eval in TOOL context → /tmp
  # PakettiClaudeProbe.lua  (READ-only snapshot, no server required)
  # =====================================================================

  @built @untested
  Scenario: Dump arbitrary Renoise state for Claude to read off disk
    Given Paketti is loaded (no MCP server needed)
    When the user (or Claude via OSC) calls PakettiClaudeProbeRun("renoise.song().selected_track.name")
    Then the expression is evaluated in FULL tool context (real io access, unlike
         the /renoise/evaluate OSC sandbox)
    And the serialized result is written to /tmp/paketti-probe.txt with a header
        (timestamp, label, expression, lua type, ok flag) for Claude to cat

  @built @untested
  Scenario Outline: Zero-typing quick probes
    Given Paketti is loaded
    When the user triggers "Global:Paketti:Claude Probe <subject>"
    Then a structured snapshot of <subject> is written to /tmp/paketti-probe.txt

    Examples:
      | subject            |
      | Song               |
      | Selected Track     |
      | Selected Instrument|
      | Available Devices  |
      | Custom Expression  |

  # =====================================================================
  # LEG 3 — PakettiClaudeChat: chat dialog INSIDE Renoise
  # PakettiClaudeChat.lua  (file-in / OSC-out, ~20-60s lag)
  # =====================================================================

  @built @untested
  Scenario: Talk to a Claude /loop session from a Renoise dialog
    Given a Claude /loop session is polling /tmp/claude-inbox.txt on the same Mac
    When the user opens "Global:Paketti:Claude Chat Dialog", types a message, hits Send
    Then the message is written (truncate-first for fresh mtime) to /tmp/claude-inbox.txt
    And Claude polls it, does work, and replies via OSC /renoise/evaluate calling
        _PakettiClaudeReply(text), which appends to the dialog's response area
    And a transcript is logged to /tmp/claude-chat-log.txt

  # WHICH LEG WHEN
  # --------------
  #   Read live state + write back, real-time, scriptable from curl/bash  → LEG 1 (MCP)
  #   One-shot "what's selected right now" snapshot, no server            → LEG 2 (Probe)
  #   Conversational, type-in-Renoise, Claude replies in the dialog       → LEG 3 (Chat)
  #
  # (Inspecting a song FILE on disk lives in its own project — see
  #  features/device-hotswap-missing-to-actual.feature.)
