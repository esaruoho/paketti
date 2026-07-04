# Parameter Editor / Mixer batch — plan, difficulty & feasibility (2026-07-04)

Five requests. Three shipped as code this session; two are feasibility studies with a
proposed design. Report card: `features/parameter-editor-mixer-and-config.feature`.

| # | Request | Difficulty | Status |
|---|---------|-----------|--------|
| 1 | "Expose on Mixer" should show the parameter you're modifying | **Easy** (1-line gating bug) | ✅ SHIPPED |
| 2 | Shortcut to expose only *automated* params (not all) | **Easy** (`is_automated` loop) | ✅ SHIPPED |
| 4 | Grid visual mode — alternating black/white column backgrounds | **Medium** (canvas render + toggle) | ✅ SHIPPED |
| 3 | Per-plugin editor config: reorder / hide / rename params | **Medium-Hard** | 📐 FEASIBILITY (below) |
| 6 | Renoise as a round-trip Ableton Live sample editor | **Hard (cross-app)** | 📐 FEASIBILITY (below) |

---

## Shipped (1, 2, 4)

- **#1** — the exposer was nested inside `if follow_automation`, so with Automation Sync OFF
  dragging a bar never set `show_in_mixer`. Moved it out: now, whenever "Expose on Mixer" is
  ticked, dragging a parameter exposes it in the mixer regardless of Automation Sync.
- **#2** — `PakettiExposeAutomatedParamsOnMixer()`: walks the selected track's devices and sets
  `show_in_mixer = true` for every param whose read-only `is_automated` is true (has automation
  in the current pattern). Leaves un-automated params alone — it is NOT "show all". Bound to
  `Global:Paketti:Expose Automated Parameters on Mixer`, a `[Trigger]` MIDI mapping, and
  `Mixer:Paketti Gadgets:Expose Automated Parameters on Mixer`.
- **#4** — `grid_stripe` toggle ("Grid stripes" checkbox). When on, each parameter column paints
  an alternating light/dark background behind the bars so the columns read as a checker grid.

---

## #3 — Per-plugin Parameter Editor configuration — FEASIBLE (display layer)

**Key fact:** a plugin's `device.parameters` order is fixed by the plugin engine and cannot be
reordered, and the parameter *names* come from the plugin. BUT the Parameter Editor already builds
its **own** `device_parameters` array of `param_info` records — the canvas renders from *that*, not
directly from the device. So reorder / hide / rename are all achievable as a **display layer** over
the device without touching Renoise's device at all.

### Design
1. **Config store** — a per-device table keyed by a stable id: `device.device_path` (VST/AU/native
   path; stable per plugin) — optionally `device_path .. "|" .. display_name` if you want per-name
   overrides. Shape:
   ```
   { order = { 5, 2, 9, ... },              -- device param indices, in display order (omitted = hidden)
     names = { [5] = "Cutoff", [9] = "Drive" } }  -- optional display-name overrides
   ```
   Persist as a serialized string in `preferences` (one string field; encode as a compact
   `idx:name;idx:name` list, or JSON via an existing Paketti serializer).
2. **Apply on build** — where `device_parameters` is assembled from `device.parameters`, look up
   the config for the current `device.device_path`; if present, build `param_info` records only for
   `order`, in that order, and set each `param_info.name` to the override if any. No config → today's
   behavior (all params, engine order). Everything downstream (render, drag, automation, A/B) already
   works off `param_info`, so it "just works".
3. **Configure dialog** — a list of all real params with, per row: a **show** checkbox, **▲/▼**
   reorder, and a **rename** textfield. Save writes the config for `device_path`; reopen the editor
   (or invalidate) to apply.

### Cost / risk
- ~200-400 lines, most of it the Configure dialog. The apply-layer is small.
- Rename is display-only (canvas font labels + status text) — automation/mixer still use the real
  param, so nothing downstream breaks.
- Caveat: keying by `device_path` means all instances of the same plugin share a config (usually
  desirable). If per-instance is wanted, key by track+device index instead (less portable).
- Drag maps screen-column → `device_parameters[i]` → `param_info.parameter`, so hiding/reordering
  Just Works because the mapping goes through the (reordered) list.

**Verdict: do it.** Clean, self-contained, high discoverability payoff. Recommend `device_path`
keying + a serialized-string pref.

---

## #6 — Renoise as a round-trip Ableton Live sample editor — HALF EASY, HALF HARD

**Goal:** edit a Live sample in Renoise, press a button, it saves back to the exact path so Live
reloads it.

### What's easy (Renoise side)
- Load a WAV by absolute path into a sample slot (Paketti already loads samples from paths).
- **Save back:** `sample.sample_buffer:save_as(path, "wav")` overwrites the original file in place.
  This is ~50 lines: remember the source path on load, "Save Back" button writes to it.
- Live keeps an **`.asd`** analysis sidecar next to each sample (warp/transient cache). After
  overwriting the WAV, **delete the matching `.asd`** so Live re-analyzes instead of trusting stale
  warp data. (`io`/`os.remove` on `<same-name>.asd`.)

### What's hard (the "Live reloads automatically" half — cross-app)
- Live caches sample audio in RAM and does **not** reliably hot-reload a WAV that changed on disk.
  There is **no way from Renoise** to make Live re-read a clip. Options, worst→best:
  1. **Manual:** overwrite + delete `.asd`; the user re-loads the clip / reopens the set → picks up
     new audio. Works today, no magic.
  2. **AbletonOSC (the user already has this skill):** after Renoise saves, send OSC to Live to
     reload the clip's sample (`clip_slot` re-fire / re-set sample). This is the real "press a button
     → Live updates" path, but it lives on the **Live side**, driven over OSC — not inside Renoise.
  3. **Max for Live** device that watches the file's mtime and reloads the clip — most seamless,
     most work, M4L-only.

### Proposed shippable slice
A Paketti **"Sample Round-Trip"** helper: (a) load-by-path (from a watched drop folder or a path
field), (b) **"Save Back"** = overwrite original WAV + remove `.asd` + status. Document the
AbletonOSC bridge as the stretch for true auto-reload. This gives 80% of the value with Renoise-only
code; the last 20% (Live auto-refresh) is inherently an Ableton-side job.

**Verdict:** ship the Renoise round-trip (easy); wire auto-reload later via AbletonOSC. Do NOT
promise Renoise-alone auto-reload — it's not possible.
