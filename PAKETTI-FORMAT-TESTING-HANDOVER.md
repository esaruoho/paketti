# Paketti — Foreign Sampler Import: what still needs real-file testing

**Date:** 2026-09-16
**Scope:** the two format batches shipped this session — Korg/Reason/Roland (commit `58650ed9`) and Akai (commit `10693429`).
**Purpose:** a checklist of which formats are proven vs which still need a real file dropped on them, where to find test files, and what a "pass" looks like.

---

## TL;DR status

| Format | Ext | Parser | Type | Status |
|--------|-----|--------|------|--------|
| Akai MPC1000 Program | `.pgm` | PakettiAkaiPrograms | instrument | ✅ **VERIFIED** (4 files: 16 & 32 pads, audio+keyzones OK) |
| Akai MPC2000 Program | `.pgm` | PakettiAkaiPrograms | instrument | ⬜ untested (need an MPC2000-authored .pgm) |
| Akai S1000 Program | `.p` | PakettiAkaiPrograms | instrument | ⬜ untested |
| Akai S1000 Sample | `.s` | PakettiAkaiS1000 | sample | ⬜ untested |
| Akai S900/S950 Sample | `.s` | PakettiAkaiS900 | sample | ⬜ untested |
| Akai S3000 Sample | `.s` | PakettiAkaiS3000 | sample | ⬜ untested |
| Akai MPC2000 Sample | `.snd` | PakettiAkaiMPC2000 | sample | ⬜ untested |
| Akai S5000/6000/Z4/Z8 Program | `.akp` | PakettiAKAI | instrument | ⬜ untested |
| Korg Triton Sample | `.ksf` | PakettiKorg | sample | ⬜ untested |
| Korg Triton Multisample | `.kmp` | PakettiKorg | instrument | ⬜ untested |
| Korg Triton Perf. Script | `.ksc` | PakettiKorg | instrument | ⬜ untested |
| Reason NN-XT Patch | `.sxt` | PakettiReasonNNXT | instrument | ⬜ untested |
| Roland MV-8000/8800 Patch | `.mv0` | PakettiRolandMV8000 | instrument | ⬜ untested |

**Every export path is also untested** (each Akai parser has export functions; SFZ/etc. are separate).

---

## Priority order for testing (highest value first)

1. **`.s` Akai samples (S1000 / S900 / S3000).** This is the interesting one: all three share the `.s` extension, and dropping a `.s` file runs `importS1000Sample`, which sniffs the header (`detect_akai_s_format` in `PakettiAkaiS1000.lua`) and routes to the right parser. **The auto-detect is the single most important thing to verify** — get one file of each generation and confirm each is detected correctly. If a file mis-detects, that function is where to fix it.
2. **`.snd` MPC2000 sample** and **`.akp` S5000/6000 program** — common formats, no coverage yet.
3. **`.pgm` authored on a real MPC2000** (not MPC1000) — the MPC2000 branch (`import_mpc2000_pgm` / `load_mpc2000_samples`) has never run on real data; only the MPC1000 branch is proven.
4. **`.p` S1000 program** — keygroup/sample-mapping parser, untested.
5. **Korg `.kmp`/`.ksf`/`.ksc`** — ported fresh from Bealby; `.kmp` pulls many `.ksf` + a keymap, `.ksc` chains `.kmp` files.
6. **Reason `.sxt`** and **Roland `.mv0`** — also fresh ports; `.sxt` is partial (samples+keyzones only), `.mv0` is samples-only.

---

## Where to find test files

- **Akai `.pgm`/`.snd`/`.p`** — the "MPC2000/MPC1000 sample CD" ISO dumps floating around; also plenty on the free MPC-forums and archive.org "Akai MPC" collections. You already have MPC1000 `.pgm` in `~/Music/samples/AKAII/digitaae/`.
- **Akai `.s` (S1000/S900/S3000)** — archive.org has "Akai S1000 library" and "Akai S3000 CD" images; the AKAI `.s` files sit inside those disk images. S900 files are rarer — look for S900/S950 factory-disk dumps.
- **Akai `.akp`** — S5000/S6000 factory libraries; `.akp` + a `Samples/` folder of WAVs.
- **Korg `.kmp`/`.ksf`/`.ksc`** — Triton/Trinity factory-sound dumps; a `.KSC` script beside a folder of `.KMP` + `.KSF`.
- **Reason `.sxt`** — any Reason NN-XT patch refill; `.sxt` + referenced WAV/AIFF.
- **Roland `.mv0`** — MV-8000/MV-8800 project/patch exports.
- **Martin Bealby's original tool** (`~/Library/Mobile Documents/com~apple~CloudDocs/Renoise/Tools/com.mxb.FileFormats.xrnx/`) has example `.lua` only — **no binary test files** — so it can't be used as a corpus.

---

## How to test each one

Two ways; both need Renoise running with the current Paketti build loaded.

**A. Disk browser (the real user path).** In Renoise's disk browser, navigate to the file and double-click / drag it in. This fires the import *hook*. Confirm the instrument/sample appears with audio.

**B. Headless via PakettiMCP** (`http://localhost:19714/mcp`, `paketti_eval`) — call the global directly, e.g.:
- `importS1000Sample("/path/x.s")` (auto-detects S900/S1000/S3000)
- `importS900Sample(...)`, `importS3000Sample(...)` to force a parser
- `importMPC2000Sample("/path/x.snd")`
- `importAkaiProgram("/path/x.pgm")` or `("/path/x.p")`
- `importAKPFile("/path/x.akp")`
- `PakettiKorgKMPImport("/path/x.kmp")`, `PakettiKorgKSCImport("/path/x.ksc")`
- `PakettiReasonNNXTImport("/path/x.sxt")`, `PakettiRolandMV8000Import("/path/x.mv0")`

Then read back and assert (per the skill's "call the real global, don't re-inline" rule):
```lua
local ins = renoise.song().selected_instrument      -- or scan for the newest non-empty
for i=1,#ins.samples do
  local s=ins.samples[i]; local b=s.sample_buffer; local m=s.sample_mapping
  print(i, s.name, b.has_sample_data and b.number_of_frames or 0,
        b.has_sample_data and b.sample_rate or 0,
        m.base_note, m.note_range[1], m.note_range[2])
end
```

**If new code doesn't seem to run:** bring Renoise to the foreground for ~45s (triggers `_AUTO_RELOAD_DEBUG`), then re-probe with `type(rawget(_G,"importS1000Sample"))=="function"`. Never call `PakettiMCPReloadTools()` (wedges the MCP socket).

---

## What "pass" looks like

- Sample slots have **real audio** (`has_sample_data==true`, plausible `number_of_frames`, correct `sample_rate`) — not zero frames, not noise.
- Sample **names** come through readable (Akai AKAII encoding decoded, not garbage).
- **Keyzones** are sane: for multisamples/programs each sample maps to a sensible `note_range` and `base_note`; for a single sample, full range.
- No Renoise error dialog, no status like "corrupt file", and the tool's other background features still work afterward (a thrown error inside a ProcessSlicer can disable all Paketti notifiers until a Renoise restart — see skill rule 25).

## Known gotchas found while testing MPC1000 `.pgm`

- **`importAkaiProgram` creates its OWN instrument** — do not pre-insert an empty slot before calling it, or you leave a stray empty instrument behind.
- **Loop-forward vs reverse PGM variants load identical audio** — MPC per-pad playback flags (reverse / loop mode) are NOT translated; the referenced samples load as-is. Honoring those flags on import would be a follow-up.
- **Spaced folder names** ("LOOPFORWARD    P") work fine.

## Failure triage

- Wrong `.s` parser chosen → fix `detect_akai_s_format` in `PakettiAkaiS1000.lua`.
- Garbled names → check the AKAII→ASCII decoder in the relevant parser (`akaii_to_ascii` / `akaii_to_string`).
- Truncated/short files crashing → the readers should nil-guard; the fresh Korg/Reason/Roland ports do, the older Akai files mostly do (rules 20/21).
- Read `~/Library/Logs/Renoise.log` for load-time or parse errors rather than guessing.

## Definition of done for this testing pass

- [ ] One real file of every `⬜` row above imported and eyeballed (audio + names + keyzones)
- [ ] `.s` auto-detect confirmed correct for S900, S1000 and S3000 separately
- [ ] MPC2000-authored `.pgm` confirmed (distinct from the proven MPC1000 branch)
- [ ] Any format that fails: file an issue with the sample file attached, or fix the parser + re-verify
- [ ] Update `AKAI-IMPORT-HANDOFF.md` / project memory with the new verified/failed status
