# Polyend Tracker ⇄ Renoise — Bidirectional Pattern/Project Conversion

**Goal (user):** Any Polyend Tracker pattern/project → importable into a Renoise song; any Renoise
song / pattern / clipboard selection → exportable to Polyend Tracker as a pattern. Formats back-and-forth.

**Forum context:** "Would be really interested in successfully exporting tracker projects to Renoise…
@esaruoho may just be the person to achieve this." The headline ask is **Polyend → Renoise import**
(already Paketti's stronger side); the gap is a faithful **Renoise → Polyend export** plus correctness
fixes on import, plus clipboard support.

## Sources compared (this session)
- `~/work/tracker-lib` — **official Polyend TypeScript library** (format authority; v0.1.1).
- `~/work/tracker-mtp-editor`, `~/work/tracker-pti-editor` — official editors built on tracker-lib.
- `~/work/paketti/Research/TrackerFilesDocs/*.py` — official Polyend reference parsers (@shuler323).
- Paketti: `PakettiPolyendPatternData.lua` (2632 lines) — all pattern/project/MTP code.

---

## VERIFIED format truths (cross-checked across official Python + TS + decoded template)

### Pattern `.mtp`
- Header **14 bytes** (`<2sH4s4sH` = id_file, type, fwVersion[4], fileStructureVersion[4], size)
  then **2 padding** then **12 unused** (`<ff4B`). **Base before tracks = 28.**
- Each track = **1 byte lastStep + 128 steps × 6 bytes = 769**. CRC = 4 bytes (LE uint32) at end.
- **Total file size = 28 + 769·tracks + 4** → **8 trk = 6184, 12 trk = 9260, 16 trk = 12336.**
  (The Paketti *skill* doc's 6180/9256/12332 are WRONG. tracker-lib's `detectTrackCount` has a
  2-byte bug—uses base 26—but its writer emits the correct 28-base sizes.)
- Step bytes: `note` (signed int8), `instrument` (uint8), then two FX pairs (type,value),(type,value).
  Official Python labels them fx0 (bytes 2–3) then fx1 (bytes 4–5); tracker-lib labels the *same
  bytes* in opposite order. **Layout is identical** — only the column-naming differs. Map
  bytes 2–3 → Renoise effect column 1, bytes 4–5 → column 2 (matches official print "FX1, FX2").
- FX type 0 (None) forces its value byte to 0 on read & write.
- All 128 steps always stored regardless of lastStep; lastStep = steps−1 (only track 0's is used).
- Note specials: −1 empty, −2 off/fade, −3 off/cut, −4 off/default. 0–127 real notes (C-5 = 60).
- id_file written `"PM"` (reader also accepts `"KS"`). CRC commonly 0 from tools; device tolerates.

### Project `.mt`  (offsets PROVEN by decoding the official 2324-byte template)
- Header 16 (incl. 2 pad) + song data: **playlist[255] @ 0x10**, **playlistPos @ 0x10F**.
- **globalTempo = float32 @ 0x1C0** (template = 130.0). ⚠️ **Paketti reads 0x80 (=0.0) — BUG.**
- Project name: version-gated read — major>16 → **0x810**, >15 → 0x80C, else 0x600; writer always 0x810.
  Template name "New Project" is at **0x810**. ⚠️ Paketti reads 0x80C (off for newest files).
- Track names: tracks 0–7 = 8×**21 bytes @ 0x428**; tracks 8–15 = 8×**8 bytes @ 0x603**.
- Delay: feedback@0x11A(u8), time@0x11C(u16), params@0x11F. Reverb: size/damp/predelay/diffusion
  float32 @ 0x418/0x41C/0x420/0x424. reverbVol@0x538, delayVol@0x539, reverbMute@0x53A, delayMute@0x53B.
- tracker-lib **writes from the 2324-byte template**, patching ~20 absolute offsets; untouched regions
  inherited verbatim. ⚠️ Paketti hand-rolls a 2096-byte file with hardcoded delay/reverb — incomplete.
- **No MIDI CC A–F number-assignment offsets exist** in any source. That's an undocumented gap, not a
  conflict — leave unmapped.

### patternsMetadata (`PAMD`)
- Header 16 (`PAMD`, version u16=1, total_size u32 @0x08, flags u32 @0x0C) + 50-byte records
  (31-byte name + 19 reserved). Matches Paketti.

---

## Paketti CURRENT STATE (audit)

**Mature (import, "Python-port-grade"):** MTP read, MT read, patternsMetadata read, note import,
Polyend→Renoise FX (~18/43), full project import (sequence/BPM/names/send-tracks).

**Confirmed bugs to fix on import:**
1. **BPM offset 0x80 → 0x1C0** (BPM currently imports as 0/default). *(proven)*
2. **Project-name offset** → version-gate 0x810 / 0x80C / 0x600 (Paketti hardcodes 0x80C).
3. **Note-cut fidelity** — Polyend CUT(−3) collapses to Renoise "OFF" on import (121→"OFF").
4. Verify pattern reader uses the 28-byte base (14+2+12) and correct track-count by size.

**"Fledgling throwaway" (export — Renoise→Polyend):**
- MTP header is fake: writes `"--"` id (should be `"PM"`), size field wrong, per-track lastStep
  zeroed for tracks 2..N.
- Filename convention mismatch: auto-loader expects `pattern_%02d.mtp` (1-based) but exporter writes
  `pattern_%03d.mtp` (0-based) → exported projects won't reload.
- Reverse FX map only 14 commands; hardcoded instrument `−2` offset; MT export is a fixed 2096-byte
  metadata-only file with hardcoded delay/reverb (ignores Renoise song values).
- No CRC on MT export.

**Missing entirely:** clipboard ↔ pattern; MIDI mappings; keybindings (commented out); real 8/12-track
awareness (`TRACK_COUNTS` declared but unused); working track-mapping dialog.

---

## PLAN (phased, each phase testable)

### Phase 0 — Dry-run oracle (no Renoise, no device)
Build `tracker-lib` (Node) as a **ground-truth oracle**. Node script to: (a) create known patterns/
projects → write real `.mtp`/`.mt` fixtures; (b) read back files Paketti writes and assert validity.
Plus a pure-Lua round-trip (read→write→re-read, byte-compare). This lets us validate byte fidelity
**without a physical device**, because tracker-lib *is* the official format implementation.

### Phase 1 — Import correctness (Polyend → Renoise)
Fix BPM offset (0x1C0), project-name version-gate, note-cut fidelity, confirm pattern base-size/
track-count. Validate against oracle-generated fixtures.

### Phase 2 — Faithful MTP export (Renoise → Polyend pattern)
Rewrite the writer: real `"PM"` header, correct 2+12 gap, correct per-step FX byte order, correct
lastStep, correct size + CRC. Round-trip: Paketti-written `.mtp` must parse cleanly in tracker-lib
AND re-import into Paketti identically.

### Phase 3 — Faithful project.mt export
Adopt the official 2324-byte template approach (patch absolute offsets: tempo@0x1C0 from Renoise BPM,
names, playlist, delay/reverb from actual send tracks). Reconcile filename convention so exported
projects reload. patternsMetadata already fine.

### Phase 4 — Clipboard ⇄ pattern
"Export Renoise selection/clipboard → .mtp" and "Import .mtp → paste at cursor". Abstract the export
to accept a line-range/buffer, not just a whole `song.pattern(i)`.

### Phase 5 — Full FX bidirectional coverage
Expand reverse FX map to all musically-mappable effects with correct scaling (Tempo 4–200↔8–400,
Swing, Slice +1, Panning ±50, Micro-tune ±99, Tune ±24, etc.). Document the unmappable set
(Chance/Random/LFO/MIDI-CC) as lossy.

### Phase 6 — Wiring + docs
Menu entries (un-bury from Xperimental/WIP if desired), keybindings (3-part!), MIDI mappings (run
`.spine/check.py`), CHANGESLOG, update the polyend-tracker skill (fix the wrong size + tempo numbers).

---

## PROGRESS (2026-06-25)
- ✅ **Phase 0 — oracle**: `tracker-lib` built; durable validator in `Research/polyend-roundtrip-tests/`.
- ✅ **Phase 1 — import BPM/name** (commit `3b42aa6f`): tempo 0x80→0x1C0 (proven on real 140/170/130
  device files), project-name version-gating. Verified by luajit harness on real files.
- ✅ **Phase 2 — faithful MTP export** (commit `c530fb24`): `"KS"` id, lastStep on all tracks, correct
  size + CRC. Exported header BYTE-IDENTICAL to real device; parses in official tracker-lib.
- ⏳ **Phase 1 leftover**: note-cut fidelity (121→OFF collapse) — needs live Renoise.
- ⏳ **Phase 3 — project.mt export**: adopt the 2324-byte official template, write tempo @ 0x1C0 from
  Renoise BPM, names/playlist; reconcile filename convention (real device = `pattern_%02d.mtp`, 1-based).
- ⏳ **Phase 4 — clipboard ⇄ pattern**, **Phase 5 — full FX + instrument map + long-pattern split**,
  **Phase 6 — wiring (menus/keys/MIDI) + docs + skill-spec corrections**.

Ground truth confirmed: real device pattern id = `"KS"`; 16-track pattern = 12336 bytes; tempo @ 0x1C0
matches folder-labelled BPMs; export header byte-identical to device.

## Open decisions for the user
1. **Sequencing / priority** — import-correctness first, export-faithfulness first, or clipboard first?
2. **Ground truth** — can you drop a real Polyend project folder (a `project.mt` + a few
   `pattern_XX.mtp` + `patternsMetadata`) somewhere so I can validate against TRUE device bytes, not
   just the official template/oracle? Confirms the exact on-device filename convention too.
3. **Scope of "any pattern"** — patterns up to 128 steps map 1:1; Renoise patterns >128 lines must be
   split/truncated. OK to split into multiple Polyend patterns?
