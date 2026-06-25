# PakettiMCP — improvement plan (tiers, feasibility, status)

Grounded in `/Users/esaruoho/work/paketti/PakettiMCP/server.lua`,
`/Users/esaruoho/work/paketti/PakettiMCP/router.lua`,
`/Users/esaruoho/work/paketti/PakettiMCPMain.lua`, and the brittleness hit live on 2026-06-25.

## Architecture (as-is)
- ReMCP-derived TCP socket server (`renoise.Socket.create_server`, port 19714), serviced two ways:
  **(A)** `socket_message` callback (event loop) and **(B)** a 100 ms `add_timer` poll (`safe_poll_clients`).
- `router.handle(body)` dispatches JSON-RPC; tools live in `PakettiMCP/tools/*.lua`, registered into
  `router.tools`. `router.load_tools_dir()` already hot-reloads tool files **in place**.
- `M.stop()` does NOT close the server socket ("port still reserved"); `start()` resumes the same socket.

## Root causes of the two brittleness points
1. **Backgrounding pause** — path B is a Renoise `add_timer`, which Renoise throttles/pauses when it is
   not the front app. So requests stall when Renoise is backgrounded. (Mitigation, not a true fix: the
   socket_message path A can still fire; but reliably, the answer is foreground-for-45s.)
2. **Reload wedge** — `PakettiMCPReloadTools()` clears `package.loaded["PakettiMCP.server"]` and
   re-requires the server module, creating a NEW `M` with `socket_srv=nil` while the OLD bound socket is
   orphaned (still holds the port + callbacks). The new module's `create_server` can't bind → port stays
   `LISTEN` but never answers. **Self-inflicted; reloading tools never needed the server restarted.**

Note there are TWO distinct "reloads":
- **(a) MCP-tool reload** = `PakettiMCP/tools/*.lua`. Safe + in-place via `router.load_tools_dir`. No wedge.
- **(b) Paketti feature reload** = `PakettiPolyendPatternData.lua` etc. (the actual globals `paketti_eval`
  calls). Re-`require`ing one of these re-runs its file-scope `add_menu_entry`/`add_midi_mapping` →
  Renoise throws on duplicate registration. So (b) needs the FULL Renoise tool reload — which only the
  `_AUTO_RELOAD_DEBUG` focus-watch or a Renoise restart does. **foreground-for-45s is the (b) trigger.**

---

## TIER 1 — kill the brittleness (do first)
| Item | Feasibility | Status |
|------|-------------|--------|
| **Reload-without-restart** — `PakettiMCPReloadTools` + `paketti_reload` tool call ONLY `router.load_tools_dir`. | HIGH | ✅ DONE — reloaded 89 tools, MCP stayed live, no wedge |
| **Watchdog self-heal** — retry-rebind on `create_server` failure (don't give up), throttled to ~1s; reap half-open clients after ~30s. | HIGH | ✅ DONE (server.lua) |

## TIER 2 — more capable (schedule after Tier 1)
| Item | Feasibility | Notes |
|------|-------------|-------|
| **`paketti_eval_json`** — `{ok,type,value,stdout,error}`, captures `print`. | HIGH | ✅ DONE & tested |
| **`paketti_screenshot`** — fires `screencapture` DETACHED (`&`) so it never blocks the main thread (a blocking version tripped Renoise's not-responding guard — fixed). | MEDIUM | ✅ DONE & tested (captured a dialog) |
| **`paketti_undo_checkpoint`** — `song:describe_undo(label)`; revert via song_undo. | HIGH | ✅ DONE & tested |
| **`paketti_render`** — `song:render` to WAV; GUI blocks during render so poll the file on disk. | MEDIUM | ✅ DONE & tested (1.2MB wav in ~1s) |
| **`paketti_read_file` / `paketti_write_file`** | HIGH | ✅ DONE |

## TIER 3 — "slay"
| Item | Feasibility | Notes |
|------|-------------|-------|
| **Capability/schema introspection** — a tool listing Paketti globals + signatures. | MEDIUM | |
| **Server-initiated notifications** (pattern/transport change push). | LOW | MCP supports it, but our HTTP-`Connection: close` transport is request/response; needs SSE/streaming the client also supports. Document, don't build yet. |

## LOW / NOT FEASIBLE (documented, not attempted)
- **Headless reload of Paketti FEATURE code (b) over MCP** — re-`require`ing a feature file re-runs its
  file-scope registrations → Renoise duplicate-registration crash. No safe in-process API to reload the
  whole tool from within itself. **foreground-for-45s remains the method.** (The watchdog + non-wedging
  reload make this painless: feature edits → foreground 45s; MCP-tool/Tier-2 edits → `paketti_reload`.)
- **Beating the backgrounding pause** — path B is timer-bound to Renoise's front-app state; can't be
  fixed from Lua. Foreground when you need guaranteed servicing.
