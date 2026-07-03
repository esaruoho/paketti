# Akai format test harness

Goal: prove — with real ground-truth files, not self-consistency — whether Paketti's
Akai import/export actually works. Independent parsers + roundtrip drivers, laddered
by confidence (see `akai-proof-plan.md`).

## HEADLINE FINDING (2026-07-03): the Akai code is not loaded at all

Before any format could be "proven", testing surfaced the real reason we have zero
proof Akai works: **it is disabled dead code.**

- `main.lua` has **no** `timed_require` for any Akai file. The only reference is a
  commented-out `--timed_require("PakettiAKAI")` at main.lua:1391.
- There are **two dead generations** on disk, neither loaded:
  - `PakettiAKAI.lua` — old monolith (34,964 bytes), require commented out.
  - `PakettiAkaiFormats/MPC2000/S1000/S3000/S900/Programs.lua` — newer split
    (3,018 lines, matched `parse_*`/`create_*` pairs), never required.
- Every Akai menu entry in the **loaded** `PakettiMenuConfig.lua` is also commented out.
- At runtime every Akai function (`importMPC1000Program`, `exportS1000Sample`, …) is
  `nil`. The menus never register; nothing is callable.

You cannot prove what never loads. Step 0 of "prove Akai" is **wire it in** (pick ONE
generation to avoid duplicate-registration crashes — the split files collide with the
monolith on the AKP entries).

## What testing DID prove

1. **The split code loads cleanly.** Force-`dofile`-ing all six split files into a live
   Renoise succeeds: no syntax errors, no missing-dependency errors, no duplicate
   registration crash. It was simply never switched on.

2. **MPC1000 PGM import genuinely works on real data.** Against
   `~/Music/samples/AKAII/digitaae/808/808.PGM` (a real MPC1000 program), Paketti's
   `importMPC1000Program` created an instrument with **16/16 samples loaded with audio
   data**, names matching the independent parser exactly. (Paketti loads per pad, so a
   sample mapped to two pads — `808CYMBL` — loads twice: 16 pad-references, 15 unique
   names. Legit, not a bug; a dedupe-and-remap is a possible improvement.)

3. **Independent format decode is correct.** `mpc1000_pgm.py` (written from the public
   MPC1000 PGM layout, NOT from Paketti's Lua) parses all four real `.PGM` files and
   every referenced sample name resolves to an actual `.wav` in the same folder:
   - `808/808.PGM` (v1.00) → 15 samples, all present ✅
   - `808REverse.PGM`, `808fowarnd.PGM` (v6.00) → 15 each, all present ✅
   - `SlicedAmen.PGM` → 1 sample, present ✅

## Test data

`~/Music/samples/AKAII/digitaae/` — 4 MPC1000 `.PGM` programs + 46 `.WAV` samples.
This exercises the **MPC1000 PGM** path only. The other formats (S1000/S3000/S900 raw
samples, MPC2000 `.SND`, S1000 program) still need their own ground-truth files or
export→import roundtrips.

## Files

- `akai-proof-plan.md` — the proof ladder (Tier 1 roundtrip → Tier 4 hardware), cost
  vs. confidence, and what each tier needs.
- `mpc1000_pgm.py` — independent MPC1000 PGM parser + folder cross-check.
  Run: `python3 mpc1000_pgm.py <file.PGM> [...]` (exit 1 on any FAIL).

## Next steps to actually prove the stack

1. Decide which Akai generation to resurrect (recommend the split files) and wire ONE in.
2. Per format, add an `export*(path)` override (as done for IFF/OT/PTI) so roundtrips can
   run headlessly.
3. Roundtrip driver per format: create/load a known sample → export → re-import → assert
   frames/rate/loop/audio-correlation.
4. Independent byte-validators for S1000/S3000/S900/`.SND` (like `mpc1000_pgm.py`).
5. Only after Tier 2/3 pass do we say a format "works". Hardware (Tier 4) is the only
   thing that proves "loads on the sampler".
