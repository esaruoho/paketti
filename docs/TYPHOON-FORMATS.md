# Typhoon OS / Yamaha TX16W — file format reference

Reverse-engineered 2026-08-29 from the official NuEdge Development distribution
(`Typhoon 2000.imz`, `Typhoon User's Manual.pdf`, `Typhoon 2000.pdf`), plus a
1006-file survey of real TX16W `.C01` libraries.

Typhoon is by Magnus Lidström (later Sonic Charge), who also invented DWVW.
Typhoon 2000 is freeware and final; there will be no further versions.

## MS-DOS extensions (manual table 4.4)

| Type | Extension | Paketti support |
|------|-----------|-----------------|
| Setup (whole machine state) | `.X##` | none |
| Performance (multi-timbral) | `.P##` | none |
| Voice (instrument) | `.O##` | import + export |
| Wave (DWVW audio) | `.C##` | import + export |
| Filter table | `.T##` | decoded, not implemented |
| AIFF (uncompressed) | `.A##` | none |
| Yamaha OS waves | `.W##` | none |
| System files | `.SYS` | n/a |

`##` distinguishes items with equal names, it is not a sequence number.

Typhoon reads plain **`.A##` AIFF** off the floppy directly — DWVW is a space
optimisation (30–50% saving), not a requirement.

## Disk

Ordinary 720K DOS FAT12: 80 tracks × 2 heads × 9 sectors × 512 B = 737,280 B.
2 sectors/cluster, 112 root entries, 3 sectors/FAT, media descriptor 0xF9.
713 KB usable on a fresh format, which matches the manual's stated figure.

The Typhoon system disk uses OEM ID `Y LM T8W` and marks every file read-only
(attr 0x01), system files hidden+read-only (0x05).

**The volume label matters.** Typhoon remembers which named diskette an item
came from and prompts for it by name when a dependency is missing. Multi-disk
sets should carry distinct labels.

**Note:** Typhoon reads regular DOS-formatted floppies. The stock Yamaha OS
does not — it needs MSX-DOS.

## The IFF item family

All three item types are big-endian IFF, and share a reference-chunk shape.

```
FORM <size> TYPV     .O## voice
FORM <size> TYPP     .P## performance
FORM <size> TYPS     .X## setup
```

### Reference chunks — `Wave` / `Voic` / `Perf`, always 20 bytes

```
 8 bytes  item name, space/NUL padded, may contain spaces ("808 BD 1")
 4 bytes  item id
 8 bytes  DISK NAME the item lives on, or 8 × 0xFF for "unknown"
```

The trailing 8 bytes are the diskette name, not padding. Real third-party
voices do write 0xFF there, so "unknown" is legal — but writing the true label
lets Typhoon prompt for the right disk instead of searching.

Item ids look like a 3-byte per-session value with a 1-byte counter in front:
`FAIRLITE.O01` is id `0c09f4dc` and references wave id `0b09f4dc`.

### `.O##` voice — `FORM TYPV`

```
VInf  16   12-byte creator stamp + 4-byte item id
Grop  ..   one per group
  Parm  64   the group's parameters (see below)
  Mod   6    × 8, the modulation table
  Splt  ..   one per split
    Parm  2    first key of the split; absent on the first split
    Wave  20   reference chunk
```

### `.P##` performance — `FORM TYPP`

```
VInf  16
Parm  4    performance globals (observed 00 ff 04 0a on every demo file)
Entr  48   one per entry
  Parm  12   byte 0 = MIDI channel, 0-based (0xFF = any)
             byte 1 = transpose
             bytes 2-3 = volume (0x0060 = 96 in every demo)
             rest not yet identified
  Voic  20   reference chunk
PChg  38   one per program change mapping
  Parm  2    byte 0 = program number
  Voic  20   reference chunk
```

Confirmed against `MULTI.P01`: ANA_STRS on ch 1, UNISON ch 2, DRUMKIT ch 10
appear as channel bytes 0x00 / 0x01 / 0x09, and the four program changes
documented in the release notes (PCH 000–003) appear as 0x00–0x03.

### `.X##` setup — `FORM TYPS`

```
VInf  16
Parm  56   system settings; carries the setup name and current disk name
Perf  20   × n   \
Voic  20   × n    > flat list of everything in memory
Wave  20   × n   /
```

## `.T##` filter table — fully decoded

4096 bytes exactly:

```
   0..15    "LM8953" + 10 NUL       (the TX16W's filter chip)
  16..3887  121 kernels × 32 bytes  = an 11 × 11 grid
3888..3903  two 8-char axis names, e.g. "freq    " "  reson "
3904..4095  192 bytes, zero on LOWPASS.T17
```

Each kernel is **16 taps of 12-bit signed big-endian** coefficients. The 11 × 11
grid is the manual's filter matrix: both axes run 0–100 in steps of 10, which is
why the manual says only multiples of 10 are allowed on the static axis. Row and
column 10 duplicate row/column 9 (clamped endpoint).

DC gain across the grid varies smoothly, confirming the row stride of 11.

Axis name pairs seen: `freq`/`level` (Q filters), `freq`/`slope` (slope
filters), `freq`/`reson` (LOWPASS.T17, new in Typhoon 2000).

Typhoon supports 20 filter tables; the stock disk ships 17.

## Hardware constraints that affect export

**Maximum wave length: 262016 sample points.** Stated outright in the Typhoon
2000 notes, and exactly the longest sample in the 1006-file library survey. The
v1.0 manual quotes the raw sample memory as 262144; use the smaller figure.
Roughly 8 s at 33333 Hz, 5 s at 50000 Hz.

**Four sample rates, all divisions of one 50 kHz clock:**
50000, 33333 (÷1.5), 25000 (÷2), 16666 (÷3). The manual labels these 50k / 33k /
25k / 16k, and notes 16k "consumes 16666 sample points per second". Stereo is
only offered at 33k.

**Loops have no end point.** The loop is always the stretch between the loop
point and the end of the wave. Setting a loop in Typhoon discards everything
past it — the manual warns "Any sound beyond the end of the new loop is lost!"
Exports must trim at the loop end to reproduce what the source plays.

**Names are 8 uppercase characters.** Item names may contain spaces; DOS
filenames may not. Typhoon 2000 displays spaces as underscores.

**Groups and splits.** A voice holds groups; each group has one key range, one
velocity range, and either a single wave or a run of splits. Splits are defined
by their *first key* only — consecutive, and the first split has no split point.
The largest split count in the surveyed corpus is 42.

## Group parameters (`Parm`, 64 bytes) — bytes 0–3 decoded

```
byte  0     bottom key         0-127                        [proven]
byte  1     top key            0-127                        [proven]
byte  2     minimum velocity   0-127                        [proven]
byte  3     maximum velocity   0-127                        [proven]
byte  4     pitch, semitones (signed)                       [strong]
byte  5     pitch, cents (signed)                           [strong]
byte  6     pitch, octaves (signed)                         [strong]
byte 13     filter table, 0 = none, 1-20 = a .T## table     [strong]
byte 18     output: 0 none, 1 left, 2 right, 3 mono, 4 stereo  [proven]
byte 22-27  AEG: attack, decay1, level1, decay2, level2, release [likely]
```

Evidence for each, beyond bytes 0–3 below:

- **byte 4** — ESQ1BELL's third group has split points 12 keys lower than the
  other two and reads 12, compensating exactly.
- **byte 5** — UNISON's four groups read −1, +4, −4, +2. That symmetric spread
  is what makes it a unison patch; the release notes describe the fat sound as
  coming from detuning.
- **byte 6** — 3 on every voice built from single-cycle waves (ESQ1BELL,
  UNISON, FAIRLITE), 0 on the sampled ones (DRUMKIT, ICE_RAIN, NOISEWAV).
- **byte 13** — values seen are 0, 1, 2, 4, 5, 9, all valid table numbers.
  ANA_STRS reads 0, and the Typhoon 2000 notes tell you to "try assigning the
  new filter table 17:LOWPASS" to it — i.e. it ships with none.
- **byte 18** — ANA_STRS and NOISEWAV read 1 then 2 across the group pairs the
  notes describe as left and right; FAIRLITE, "a single powerful stereophonic
  wave", reads 4; DRUMKIT and TR_808 read 3.
- **bytes 22–27** — gives ESQ1BELL a bell curve (0, 63, 98, 127, 32, 36),
  FAIRLITE a flat sustain (0, 0, 127, 127, 127, 38), and the third-party
  TR_808 exactly 0, 0, 127, 127, 127, 127: the envelope that lets a drum sample
  play out untouched. Marked *likely* rather than proven because no single
  factory value contradicts an alternative offset by one.

**Not found: the Mode page** (Normal / One-shot / Glide / Release, and poly
on/off). No byte separates DRUMKIT's 20 one-shot groups from the 15 sustained
groups. In practice the one-shot AEG above achieves the same thing, which is
what TR_808 does.

Confirmed across all 36 groups in the factory voices (the eight on the Typhoon
2000 system disk plus `TR_808.O01`): every one satisfies
`low <= high <= 127` on both pairs. The decisive check is that exactly one voice
has a velocity range other than 0–127 — `NOISEWAV.O01`, two groups at 90–127 —
and the Typhoon release notes describe the NEW_AGE performance as one where
"NOISEWAV only plays at higher key velocities."

**This is why velocity layers are groups.** A split carries only a first key; the
velocity range lives on the group. A velocity-layered instrument is therefore N
groups with overlapping key ranges and stacked velocity ranges.

Bytes 4–6 look like pitch (byte 5 varies as a small signed value across the four
detuned groups of `UNISON.O01`, which is exactly what a unison patch does, and
byte 4 carries large signed values on the tuned `DRUMKIT` groups), and byte 9 is
0x60 = 96 on every group surveyed, consistent with a volume default. None of
that is confirmed, so the exporter leaves bytes 4–63 at the values taken from a
known-good factory voice.

## Group parameters — what the pages mean (from the manual)

13 parameter pages per group:

1. **Range** — bottom key, top key, min velocity, max velocity
2. **Waves** — wave reference, or split points
3. **Pitch** — octaves, semitones, cents, key scaling (11 curves: inverse ×4/×2/
   ×1/÷2/÷4, fixed, normal ÷4/÷2/×1/×2/×4). Percussion should use *fixed*.
4. **Volume** — volume, velocity sensitivity %, max velocity
5. **Filter** — filter table, dynamic axis, dynamic origin, fixed origin
6. **Output** — None / Left / Right / Mono / Stereo (+pan −50..50), individual outs
7. **AEG** — Attack, Decay1, Level1, Decay2, Level2, Release
8. **Mode** — poly on/off; Normal / Oneshot / Glide (portamento ms) / Release
9. **Mod Tbl** — 8 entries, each source + destination + amount + freeze
10–11. **LFO1/LFO2** — shape, rate, amplitude
12–13. **ENV1/ENV2** — L0,T1,L1,T2,L2,T3,L3; levels may be negative

**Modulation sources** (1–15): Vel, Vel/R, Key, Key/R, Wheel, PBend, PB/H,
XCtl1, XCtl2, Press, Extern, LFO1, LFO2, ENV1, ENV2.

**Modulation destinations** (1–13): Pitch, Volume, Filter, Pan, Attack, AEG/T,
Glide, LFO1/A, LFO2/A, LFO1/R, LFO2/R, ENV1, ENV2.

### The `Mod` chunk — decoded

Six bytes, eight per group:

```
byte 0  source index, 0-based       (0-14, the 15 sources above)
byte 1  destination index, 0-based  (0-12, the 13 destinations above)
byte 2  freeze flag (>Frz): hold the source's value from key-down
byte 3  always 0x0F in all 288 chunks surveyed
byte 4  amount; SEMITONES when the destination is Pitch
byte 5  amount, low part; CENTS when the destination is Pitch
```

The 0-based reading is settled by the first entry of nearly every factory voice
being source 5 / destination 0 = **pitch bend to pitch shifter** — which is also
the only modulation the Typhoon import routine converts from the Yamaha OS. All
288 chunks satisfy byte 0 ≤ 14 and byte 1 ≤ 9. The split amount matches the
manual's own mod-table illustration, which shows a pitch entry as `>Sm=17,
>Ct=22`.

**There are no arbitrary per-voice MIDI CC sources.** External controller 1 and 2
are the only free CC slots, and which CC each listens to is set globally in
System Setup → X-Cntls (stored in the `.X##` setup, not the voice). So "CC74 to
cutoff" is: point XCtl1 at CC 74 once on the machine, then route source 7 to
destination 2 in every voice.

**A group has only one modulatable filter axis**, picked as `>D-Axis`. Cutoff and
resonance cannot both be modulated on the same group.

## Current Paketti implementation

`PakettiDWVW.lua` — the DWVW codec, import hook (`.C01`–`.C99` both cases),
single-sample export, folder batch convert.
`PakettiTyphoon.lua` — `.O01` voice building, FAT12 720K image builder, disk
packing, drumkit export.

Verified: all 1006 real `.C01` files parse; 1002 re-encode bit-identically and
the other 4 decode identically. Built images mount natively on macOS with every
file byte-identical.

Not verified on real hardware. Two known unknowns: 42 splits is the largest any
factory voice uses, so a 120-split voice is beyond corpus precedent; and the
12-byte creator stamp is generated fresh, which reads as informational (only
667 of 1174 real waves shared their voice's stamp).
