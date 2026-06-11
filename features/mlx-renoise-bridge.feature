Feature: Human → local-LLM → Renoise bridge (zero Claude, zero Anthropic tokens)
Context: Global

  # WHAT THIS IS / THE GIST
  # -----------------------
  # Type plain English; a LOCAL model drives Renoise. No Claude, no Anthropic
  # tokens — the reasoning runs on the Mac Mini's on-device Qwen3-4B (MLX), and
  # the actions go through PakettiMCP (this tool's HTTP MCP server, see
  # features/mcp-claude-bridge.feature). Proven live 2026-06-11.
  #
  #   you (English) -> [ Qwen picks a PakettiMCP tool -> execute -> result back ]* -> done
  #
  # PIECES:
  #   • PakettiMCP            — the 79-tool HTTP MCP server inside Renoise (this repo).
  #   • Auto-Start PakettiMCP — Main Menu:Options toggle that keeps the server alive
  #     across tool reloads / song loads (this repo: PakettiMCPMain.lua,
  #     pref PakettiMCPAutoStart in Paketti0G01_Loader.lua).
  #   • mlx-drive-renoise     — the orchestrator loop (~/work/apple/bin/, NOT this repo):
  #     shows the local Qwen a curated tool menu, parses its JSON choice, POSTs to
  #     PakettiMCP, feeds the result back so it can chain steps.
  #   • pakettimcp            — friendly CLI front-end (~/work/apple/bin/): a health
  #     preflight + mlx-drive-renoise. `pakettimcp "set the tempo to 155.2 bpm"`.
  #
  # TOPOLOGY (Tailscale): raymac (this Mac) 100.115.65.70 ; cloudcitymacmini
  # 100.117.30.102. MLX = mlx_lm.server on the Mini, bound 127.0.0.1:8080, exposed
  # to the tailnet by hostname (route by Host header — use the name, not the IP).
  # PakettiMCP binds *:19714 so the Mini reaches it across the tailnet.

  # =====================================================================
  # PART A — Auto-Start PakettiMCP (the resilience toggle)
  # PakettiMCPMain.lua + pref PakettiMCPAutoStart
  # =====================================================================

  @built
  Scenario: Turning Auto-Start ON starts the server and keeps it up
    Given Paketti is loaded
    When the user clicks "Main Menu:Options:Auto-Start PakettiMCP" (checkmark on)
    Then the PakettiMCP server starts immediately on localhost:19714
    And the preference PakettiMCPAutoStart is saved as true
    And a 5s keepalive timer re-starts the server any time it is found not running

  @built
  Scenario: The server survives a tool code-reload
    Given Auto-Start PakettiMCP is ON
    When a Paketti .lua file changes and Renoise reloads the tool (Lua state resets)
    Then the reloaded PakettiMCPMain re-runs, and the boot timer + keepalive bring
         the server back up within a few seconds — external clients reconnect
    # This is the fix for the teardown that previously dropped the bridge on every edit.

  @built
  Scenario: The server survives a song load
    Given Auto-Start PakettiMCP is ON
    When the user loads or creates a different song
    Then the app_new_document notifier re-ensures the server is running

  @designed
  Scenario: Auto-Start defaults OFF
    Given a fresh install with no saved preference
    Then PakettiMCPAutoStart is false and the server only runs when the user opens
         the MCP Server Dialog or enables the toggle

  # =====================================================================
  # PART B — The local-LLM drive loop (external orchestrator)
  # ~/work/apple/bin/mlx-drive-renoise + pakettimcp
  # =====================================================================

  @built @hw-verified
  Scenario: One English line, run ON THE MINI, drives Renoise here
    Given the Mini's MLX (Qwen3-4B) is up and PakettiMCP is running on this Mac
    When the orchestrator runs on the Mini with intent
         "set the song tempo to 140 then read it back to confirm, then finish"
    Then Qwen calls transport_set_bpm{bpm:140}, then transport_get_bpm (reads 140),
         then done — and Renoise's tempo changes to 140, with NO Anthropic tokens
    # VERIFIED 2026-06-11: ran via ssh on cloudcitymacmini, FM_MLX_HOST=localhost:8080,
    # PAKETTIMCP_URL=http://raymac:19714/mcp. Transcript: step1 "BPM set to 140.00",
    # step2 "140.00", done "set to 140 BPM and confirmed."

  @built @hw-verified
  Scenario: The Mini can reach this Mac's PakettiMCP over Tailscale
    Given PakettiMCP binds *:19714 and both machines are on the tailnet
    When the Mini curls http://raymac:19714/health (and the bare IP)
    Then it gets {"status":"ok","server":"PakettiMCP"} — the relay path is open
    # VERIFIED 2026-06-11 from the Mini, by MagicDNS name and by IP.

  @built @hw-verified
  Scenario: pakettimcp refuses cleanly when the server is down
    Given the PakettiMCP server is not running
    When the user runs `pakettimcp "set the tempo to 155.2 bpm"`
    Then it prints a one-line "server not running — enable Auto-Start PakettiMCP"
         message and exits 1 — no Python traceback
    # VERIFIED 2026-06-11.

  @built @untested
  Scenario: pakettimcp drives Renoise from this Mac with a fractional tempo
    Given the PakettiMCP server is running
    When the user runs `pakettimcp "set the tempo to 155.2 bpm"`
    Then the Mini's Qwen emits transport_set_bpm{bpm:155.2} and Renoise's tempo
         becomes 155.2 — shown as the step it took
    # PENDING: needs Auto-Start enabled (server up) to run end-to-end.

  @built
  Scenario: Multi-step chaining and graceful failure
    Given a multi-part intent like "set tempo to 140 then start playback"
    When the orchestrator runs
    Then it executes one tool per turn, feeding each result back, until Qwen calls
         done or hits the step cap
    And on Ctrl-C it prints "(interrupted)" not a stack trace
    And on MLX timeout it reports "the Mini's MLX serializes one request — try again"
        (mlx_lm.server runs --prompt-concurrency 1, so concurrent calls queue)

  # WHICH FRONT-END WHEN
  # --------------------
  #   From this Mac, friendly:        pakettimcp "set the tempo to 150"
  #   From this Mac, raw orchestrator: mlx-drive-renoise "..."
  #   From the Mini (hands-free):      FM_MLX_HOST=http://localhost:8080
  #                                    PAKETTIMCP_URL=http://raymac:19714/mcp
  #                                    mlx-drive-renoise "..."   (future: a Cloudcity pane)
