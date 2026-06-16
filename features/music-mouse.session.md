# Music Mouse — session backing (the conversation that spawned features/music-mouse.feature)

Faithful, not flattering: this is the design trail, including the corrections and the
things Claude got wrong, so the grades in the .feature have an audit trail.

## How to get back
- Session name: **musicmouse-renoise**
- Transcript: `file:///Users/esaruoho/.claude/projects/-Users-esaruoho-Library-Mobile-Documents-com-apple-CloudDocs-Renoise-Tools-org-lackluster-Paketti-xrnx/9639e2d9-f1d7-4ef6-91cd-5df5eaaa8f31.jsonl`
- Session ID: `9639e2d9-f1d7-4ef6-91cd-5df5eaaa8f31`
- Resume: `claude --resume 9639e2d9-f1d7-4ef6-91cd-5df5eaaa8f31`
- Dates: 2026-06-15 → 2026-06-16

## Source of truth used
- The MacMM manual PDF (`~/Downloads/MacMM Manual.pdf`) — read in full for the model.
- teropa.info/musicmouse JS bundle — pulled the EXACT scale tables (intervals,
  voiceSteps, centerNote) and the 10 pattern arrays, cross-checked against the manual
  (the manual's printed pattern table is mangled by its multi-column PDF layout).

## Decisions Esa made (via AskUserQuestion or directly)
- Sound source: **selected instrument + classic waveforms** (u/i/o switch; Load Classic).
- Scope: **full faithful core** (not a minimal subset).
- Instruments must be **Pakettified**: load the Paketti Default Instrument, then render
  the wavefile into it (not a bare insert_instrument_at).
- **Bell is the default**, not Sustain.
- **4 voices stays classic Music Mouse and must not break**; 5–9 add rich chords.
- Rich chords = extra thirds stacked on the **X-axis chord**.

## Corrections Esa gave (Claude was wrong — recorded honestly)
- **Canvas path-accumulation bug**: first render flooded the whole grid orange because
  `ctx:rect()`+`ctx:fill()` accumulate; switched everything to `ctx:fill_rect`.
- **Keyboards/grid invisible** (white-on-white) and **not real pianos** — rebuilt as
  four real piano keyboards with proper white/black geometry + dark mode.
- **Triangle started from the bottom**, should start from center — fixed.
- **i/o/p must retrigger** the chord (and keep Bell) — the grouping-aware play silently
  skipped same-pitch re-strikes; added a force-retrigger.
- **Recorder "threw things in"**: it sampled the held chord onto every line. Changed to
  **write-on-trigger** (obey the timer).
- **Velocity wasn't written** to the pattern — now writes the loudness as volume column.
- **MM used its own tuning** (base_note), clashing with the PCM Writer single-wave —
  switched to `PCMWriterApplyPitchCorrectionToSample` so they match.
- **Active-key highlight covered black keys** — moved highlighting into the white-pass /
  black-pass draw so black keys stay on top.
- **Gravity snap trapped the cursor** (couldn't place new seeds) — removed the auto-snap;
  seeds are reached via Gravity Play instead.
- **right-shift bug**: toggled record on ANY bare shift (left too) and on auto-repeat —
  fixed to right-shift only, ignore repeat.
- **Claude punted on `;`**: claimed Renoise can't deliver it. Esa corrected — on his
  layout `;` IS **shift-comma**, which the loudness handler was eating. Bound shift-comma
  to Gravity Play before loudness. (Lesson: read the probe output properly.)
- **Keys were over-captured**: shift-v/d/m (Esa's Renoise shortcuts) got eaten — rebuilt
  the keyhandler so MM owns only what it maps and passes everything else through.

## New ideas Esa added beyond the 1986 original
- Keyjazz punch (silent aim, fire with i/o/p), freeze (space), lock/retain (enter),
  Record → Pattern (right-shift first-class-citizen context), 4–9 voices, gravitation
  seeds + Gravity Play, BPM/Tempo/Gravity MIDI mappings, persistence of tempo/loudness/seeds.

## Known limitations (honest)
- Claude could NOT self-verify sound this session (PakettiMCP never connected) — all live
  verification was Esa's. Grades say @user-verified where he tested, @built otherwise.
- `tab` true-microtonal is not available (12-TET note triggers).
- Voice count is session-only (not persisted); contrary-motion / voice-pairs >4 split is
  simplified; Improvise is a pseudo-random subset, not the manual's exact 4-beat suspension.
