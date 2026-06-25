**Polyend Tracker ⇄ Renoise — patterns AND whole projects now go both ways (in Paketti)**

Following up on the "exporting tracker projects to Renoise" question — this works now, in both directions, in the latest [Paketti](https://github.com/esaruoho/paketti).

**Polyend → Renoise (import)**
- Drop a whole Tracker project (`project.mt` + its `patterns/` + `.pti` instruments) into Renoise — BPM, project/track names, the pattern sequence, instruments, notes and the mapped effects all come across.
- Or import a single `.mtp` pattern, or a project's pattern straight into a Renoise pattern.

**Renoise → Polyend (export)**
- Export a Renoise pattern to `.mtp` — byte-shaped exactly like a file the Tracker itself wrote.
- Export just the **selected line-range** to a single `.mtp` (lift a chunk of a Renoise song onto the Tracker).
- Renoise patterns longer than the Tracker's 128-step max **auto-split** into multiple `.mtp` parts, and the device playlist is chained so they play back in order (a 200-line pattern → a 128-step part + a 72-step part).
- Export a **full Renoise song as a Tracker project** — patterns, `project.mt` (with the right tempo/names/sequence) **and the instruments written out as `.pti`**, so the project opens on the device with sound, not empty slots.

Menu: *Tools → Paketti → Xperimental/WIP → Polyend*. Most actions are MIDI-mappable too.

**On trust:** this isn't guesswork. Import was checked against my whole corpus of real device files (200+ `.mtp` + every `project.mt`), and every Paketti-written file is validated against **Sandroid's `tracker-lib`** — the same library the official Polyend web editors use — so a file Paketti writes parses identically to a real device file. Exports were also run live in Renoise end-to-end (build a song → export → re-validate). The effect mapping round-trips both ways for the common musical effects (volume, panning, tempo, glide, arp, slice, reverse, retrigger, gate, pitch slides, filter, swing, micro-tune).

That testing turned up a small 8/12-track-detection bug in `tracker-lib` — one-line fix PR'd upstream ([#3](https://github.com/polyend/tracker-lib/pull/3)).

Honest caveats: Renoise's note column has a single note-off, so Polyend's fade/cut/off distinction collapses to OFF on the way through; and the device-only effects with no Renoise equivalent (chance, the random/LFO effects, per-step send levels, MIDI CC) don't map. Everything else round-trips.

Huge thanks to @Sandroid for the `tracker-lib` + editors, and for the nudge to build a proper test-harness around them. Bug reports + real projects that don't convert cleanly are very welcome.
