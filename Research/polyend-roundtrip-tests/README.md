# Polyend ⇄ Renoise round-trip tests

Oracle-based verification for Paketti's Polyend Tracker pattern/project conversion
(`PakettiPolyendPatternData.lua`). The **oracle** is Polyend's own official TypeScript
library `tracker-lib` — the same code the Polyend web editors (tracker-mtp-editor /
tracker-pti-editor) use — so a file Paketti writes that this library accepts is, by
definition, format-correct.

## Looping harness (recommended)
```bash
python3 loop-roundtrip.py
```
Generates many synthetic patterns (8/12/16 tracks, lengths 1–128, notes, note-offs,
FX), drives Paketti's REAL `export_pattern_to_mtp` (sliced live from the source via
luajit + a Renoise stub), re-reads with Paketti's REAL `read_pattern_file`, and
validates each file against **two** oracles:
- the authoritative official Polyend reference parser `patternRead.py` (all track counts), and
- Sandroid's `tracker-lib` (perfect for 16-track).

### Known `tracker-lib` bug found via this harness (worth reporting upstream)
`tracker-lib` `src/types/patterns.ts:261` sets `UNUSED_SIZE: 10`, but the real
unused block is **12 bytes** (`<ff4B>` = 2×float32 + 4×uint8, per the official
`patternRead.py`). So `detectTrackCount` computes 8-track=6182 / 12-track=9258
instead of the correct **6184 / 9260**, can't match correct 8/12-track files,
falls back to 16, then overruns and throws. Its *writer* uses the correct 28-byte
base, so tracker-lib writes 8/12-track files its own reader can't parse. 16-track
(Tracker Mini / Tracker+) is unaffected. Paketti matches the authoritative reference.

## One-time setup
```bash
cd ~/work/tracker-lib && npm install && npm run build
```

## Validate `.mtp` files against the official library
```bash
cd ~/work/paketti/Research/polyend-roundtrip-tests
node validate-mtp.mjs                 # bundled Paketti-export sample + real device files
node validate-mtp.mjs path/to/file.mtp
```
`ALL PASS` means the official Polyend parser accepts the file exactly like a real device file.

## Ground truth (verified against real device files + the decoded official project template)
- **`.mtp` pattern:** id=`"KS"`, type=2, fwVersion=1.9.1.1, fileStructureVersion=5.5.5.5,
  size field = total file size. 28-byte base (14 header + 2 padding + 12 unused) + 769 bytes/track
  (1 lastStep byte + 128 steps × 6) + 4 CRC. **lastStep written on ALL tracks.** CRC = 0 (device
  never computes it). 16-track total = 28 + 769·16 + 4 = **12336 bytes**.
- **`project.mt`:** globalTempo = **float32 @ 0x1C0** (NOT 0x80 — that's always 0.0); playlist[255] @ 0x10;
  project name version-gated (fsVersion major >16 → 0x810, >15 → 0x80C, else 0x600); track names
  @ 0x428 (8×21 bytes) and @ 0x603 (8×8 bytes); delay @ 0x11A.., reverb floats @ 0x418...
- **Real device pattern id is `"KS"`**, not the `"PM"` that tracker-lib *writes* (it accepts both).

## Real ground-truth corpus
`~/Music/samples/PTI/` — real device projects incl. tempo-labelled folders
("…140bpm", "…170bpm") used to confirm the tempo offset, plus `sandroid_testproject/`,
`blank baby/`, and the `MT/` demos.

`sample-paketti-export.mtp` here is a Paketti-written 16-track pattern; its header is
byte-identical to a real device pattern header and it passes the oracle.
