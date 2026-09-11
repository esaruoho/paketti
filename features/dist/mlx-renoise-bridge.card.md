# Report Card — Human → local-LLM → Renoise bridge (zero Claude, zero Anthropic tokens)

> Source: `features/mlx-renoise-bridge.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 9 · @designed × 1 · @hw-verified × 5

**Scenarios: 10**


---


## 1. Turning Auto-Start ON starts the server and keeps it up

`@built`


- Given Paketti is loaded
- When the user clicks "Main Menu:Options:Auto-Start PakettiMCP" (checkmark on)
- Then the PakettiMCP server starts immediately on localhost:19714
- And the preference PakettiMCPAutoStart is saved as true
- And a 5s keepalive timer re-starts the server any time it is found not running


## 2. The server survives a tool code-reload

`@built`


- Given Auto-Start PakettiMCP is ON
- When a Paketti .lua file changes and Renoise reloads the tool (Lua state resets)
- Then the reloaded PakettiMCPMain re-runs, and the boot timer + keepalive bring
- the server back up within a few seconds — external clients reconnect


## 3. The server survives a song load

`@built`


- Given Auto-Start PakettiMCP is ON
- When the user loads or creates a different song
- Then the app_new_document notifier re-ensures the server is running


## 4. Auto-Start defaults OFF

`@designed`


- Given a fresh install with no saved preference
- Then PakettiMCPAutoStart is false and the server only runs when the user opens
- the MCP Server Dialog or enables the toggle


## 5. One English line, run ON THE MINI, drives Renoise here

`@built @hw-verified`


- Given the Mini's MLX (Qwen3-4B) is up and PakettiMCP is running on this Mac
- When the orchestrator runs on the Mini with intent
- "set the song tempo to 140 then read it back to confirm, then finish"
- Then Qwen calls transport_set_bpm{bpm:140}, then transport_get_bpm (reads 140),
- then done — and Renoise's tempo changes to 140, with NO Anthropic tokens


## 6. The Mini can reach this Mac's PakettiMCP over Tailscale

`@built @hw-verified`


- Given PakettiMCP binds *:19714 and both machines are on the tailnet
- When the Mini curls http://raymac:19714/health (and the bare IP)
- Then it gets {"status":"ok","server":"PakettiMCP"} — the relay path is open


## 7. pakettimcp refuses cleanly when the server is down

`@built @hw-verified`


- Given the PakettiMCP server is not running
- When the user runs `pakettimcp "set the tempo to 155.2 bpm"`
- Then it prints a one-line "server not running — enable Auto-Start PakettiMCP"
- message and exits 1 — no Python traceback


## 8. pakettimcp drives Renoise from this Mac with a fractional tempo

`@built @hw-verified`


- Given the PakettiMCP server is running
- When the user runs `pakettimcp "set the tempo to 155.2 bpm"`
- Then the Mini's Qwen emits transport_set_bpm{bpm:155.2} and Renoise's tempo
- becomes 155.2 — shown as the step it took


## 9. "give me an amen break at 174" chains tempo + a composition generator

`@built @hw-verified`


- Given the PakettiMCP server is running with the composition tools loaded
- When the user runs `pakettimcp "give me an amen break at 174"`
- Then the Mini's Qwen calls transport_set_bpm{bpm:174}, then
- generate_breakbeat{style:amen}, writing the break into the pattern


## 10. Multi-step chaining and graceful failure

`@built`


- Given a multi-part intent like "set tempo to 140 then start playback"
- When the orchestrator runs
- Then it executes one tool per turn, feeding each result back, until Qwen calls
- done or hits the step cap
- And on Ctrl-C it prints "(interrupted)" not a stack trace
- And on MLX timeout it reports "the Mini's MLX serializes one request — try again"
- (mlx_lm.server runs --prompt-concurrency 1, so concurrent calls queue)

