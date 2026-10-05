# Special keyjazz cycler delay refresh

User reported an add-column limit status after using a +1 action with twelve columns already visible, and asked for Special +1/−1 controls and delay regeneration at twelve.

Inspection found the status in ExposeAndSelectColumn, while the ordinary keyjazz cycler never calls GenerateDelayValue. The numbered Special command already regenerates delays without a column-limit early return. Added dedicated Special cycler keybindings, menus, trigger MIDI mappings and an absolute MIDI knob. Shared count is clamped; Special calls regenerate delays before ensuring the notifier remains active. Numbered same-count toggle behavior remains intact.

Verification: lua tests/keyjazz-special-cycler.lua passed against actual extracted functions with a mocked Renoise API; luajit bytecode compilation passed. Live Renoise use remains untested. No commit or external delivery performed.

## How to get back

- Transcript: file:///Users/esaruoho/.codex/sessions/2026/10/05/rollout-2026-10-05T18-43-41-01a10cbc-2e3e-7830-ac65-13832c5af416.jsonl
- Session ID: 01a10cbc-2e3e-7830-ac65-13832c5af416
- Resume: Codex --resume 01a10cbc-2e3e-7830-ac65-13832c5af416
- Verified transcript timestamps (UTC): 2026-10-05T15:45:11.546Z through 2026-10-05T15:47:56.980Z (snapshot during work).
- Bundled source: [keyjazz-special-cycler.transcript.jsonl](keyjazz-special-cycler.transcript.jsonl); [readable transcript](keyjazz-special-cycler.transcript.md).
- Card: [keyjazz-special-cycler.feature](keyjazz-special-cycler.feature).

User correction: Special 12 itself fails when twelve columns are already visible. The initial response overstated inspection as proof of behavior. Changed both numbered Special and Special cycler to use a shared preparation function that directly sets the absolute visible count and always regenerates delays; added a repeated numbered Special 12 regression check.

Live follow-up: User supplied the exact “Column Cycle Keyjazz Special (12)” binding after reporting the same column-limit message. The previous fixes did not establish that keyboard dispatch worked. PakettiMCP inspection confirmed the running tool uses the edited source (same filesystem inode through the Renoise Scripts path). Direct live invocation succeeded: notifier false→true and row-one delay values 0,21,42,64,85,106,128,149,170,192,213,234. This verifies direct invocation only; shortcut dispatch remains unresolved. Temporary live wrappers on ColumnCycleKeyjazzSpecial and ExposeAndSelectColumn record callers to /private/tmp/paketti-keyjazz-shortcut-trace.txt; remove them after diagnosis.
