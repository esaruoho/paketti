# Typhoon OS / Yamaha TX16W — file format reference

Typhoon is by Magnus Lidström (later Sonic Charge), who also invented DWVW.
Typhoon 2000 is freeware and final; there will be no further versions.

Everything here is either measured against real files or marked as unknown.
Nothing is guessed silently. **None of it has been tested on a real TX16W.**

## The corpus this was derived from

- The official NuEdge distribution: `Typhoon 2000.imz` (a ZIP holding a raw
  720K image), the 74-page user's manual, and the release notes. Its system
  disk carries 8 voices, 17 waves, 5 performances, 1 setup, 17 filter tables.
- **Ten libraries present in *both* formats** — Yamaha originals and Typhoon
  conversions of the same sounds made on real hardware. 220 Yamaha waves. This
  pairing is what makes the `.W##` decode verifiable rather than plausible.
- A 1006-file survey of real `.C01` libraries.
- `TR_808.O01`, a third-party voice, which is the only non-NuEdge voice here
  and so the only independent check on the voice format.

## MS-DOS extensions (manual table 4.4)

| Type | Extension | Paketti support |
|------|-----------|-----------------|
| Setup (whole machine state) | `.X##` | import + export |
| Performance (multi-timbral) | `.P##` | import + export |
| Voice (instrument) | `.O##` | import + export |
| Wave (DWVW audio) | `.C##` | import + export |
| Filter table | `.T##` | export |
| AIFF (uncompressed) | `.A##` | none |
| Yamaha OS waves | `.W##` | import |
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
   0..15    "LM8953" + 10 NUL        (the TX16W's filter chip)
  16..3887  121 kernels × 32 bytes   = an 11 × 11 grid
3888..3897  axis 1 name, 10 bytes, space padded  ("freq")
3898..3907  axis 2 name, 10 bytes, space padded  ("reson" / "level" / "slope")
3908..4095  188 bytes; zero in LOWPASS.T17, while the sixteen older tables
            repeat the two axis names again at 4064
```

**Verified**: feeding a factory table's own kernels and axis names back through
Paketti's writer reproduces `LOWPASS.T17` byte for byte, all 4096 of them.

Each 16-word kernel is **one gain word followed by 15 FIR taps**, all
big-endian:

```
word 0     gain / scale
word 1-15  filter taps, 12-bit signed two's complement
```

The split is decisive rather than inferred: across all 17 factory tables,
**every one of the 30,855 taps in words 1–15 fits in 12-bit signed** (max
magnitude 1822), while word 0 reaches 14,334 — far outside that range. Word 0
also clusters into bands at roughly 1025–1041, 6133–6139, 10203–10227 and
14294–14334, i.e. a small exponent in the high bits over a normalised mantissa,
which is what a gain field looks like. `LOWPASS.T17`, the table Typhoon 2000
added, is the exception that stays in 150–2047.

The 11 × 11 grid is the manual's filter matrix: both axes run 0–100 in steps of
10, which is why the manual says only multiples of 10 are allowed on the static
axis. Row and column 10 duplicate row/column 9 (clamped endpoint), and DC gain
varies smoothly across the grid, confirming the row stride of 11.

Axis name pairs seen: `freq`/`level` (Q filters), `freq`/`slope` (slope
filters), `freq`/`reson` (LOWPASS.T17, new in Typhoon 2000).

Typhoon supports 20 filter tables; the stock disk ships 17.

## `.W##` — the stock Yamaha OS wave, decoded

What a TX16W disk holds before anyone installs Typhoon. Decoded 2026-08-31 from
**220 files across ten Yamaha-format library disks**.

```
 0..5    "LM8953"      the same magic the filter tables carry
 6..15   zero
16..21   not identified
22       0x49 = looped, 0xC9 = not looped   (only these two values appear)
23       NOT the sample rate, despite what the published struct says
24..26   attack length, 17-bit little endian, bit 16 = byte 26 bit 0
29 bit 0 loop length bit 16
29 bits 1-7  SAMPLE RATE index:  40 = 33310 Hz   41 = 33333 Hz
                                 73 = 44175 Hz  127 = 49966 Hz
27..28   loop length, low 16 bits
30..31   not identified
32..     audio, 12-bit signed, two samples per three bytes:
           sample 1 = (b0 << 4) | (b1 & 0x0F)
           sample 2 = (b2 << 4) | (b1 >> 4)
```

**Total frames = attack + loop, and the loop begins where the attack ends.** The
format encodes the machine's own rule directly: a loop always runs to the end of
the wave, so a wave *is* an attack followed by a repeating tail.

### How each part was established

- **Length.** File sizes are all padded to 512 bytes, so no field matches a size
  directly. Brute-forcing every 2- and 3-byte field at every offset, in both
  byte orders, against "does this many samples fit with less than one sector of
  padding" found nothing — until pairs were tried, and `field@24 + field@27` at
  1.5 bytes per sample fit 200 of 220 immediately. With the 17-bit mask it fits
  all 220.
- **Packing.** Decided by smoothness, the mean absolute difference between
  consecutive samples. A pure sine scores 125 and white noise 1365. The wrong
  nibble layouts all scored ~1100 — noise. The correct one gives a **median of
  90 across all 220 files**, with only 3 above 400, and peak amplitudes filling
  the 12-bit range (median 2040 of 2048).
- **Loop.** Loop start lands exactly one sample after the attack ends and loop
  end on the final frame, for every file. `GTB1.W27` is a guitar B1: its loop is
  268 frames, which at 33333 Hz is 124 Hz — B2, matching both its filename and
  its measured pitch. The loop is one period long.
- **Rate — settled, and it is not byte 23.** The published struct (the one in
  SoX and repeated widely) puts the rate at byte 23 with values 1/2/3 for
  33.3/50/16.7 kHz. On real factory disks byte 23 takes **79 distinct values and
  only 27% of files are in that range**, so it is something else.

  The archive contained the same ten libraries in *both* formats — Yamaha
  originals and Typhoon conversions made on real hardware — and a Typhoon wave
  states its rate outright in its AIFF header. Pairing them gives ground truth
  for 219 waves, and the rate maps **one-to-one with the top 7 bits of byte 29**,
  with no exceptions:

  | `byte29 >> 1` | rate | files |
  |---|---|---|
  | 40 | 33310 Hz | 166 |
  | 41 | 33333 Hz | 49 |
  | 73 | 44175 Hz | 3 |
  | 127 | 49966 Hz | 1 |

  Byte 29 therefore does double duty: bit 0 is the loop length's bit 16, bits
  1–7 are the rate. **33310 rather than 33333 is not a typo** — it is what the
  machine actually ran at and what its own conversions record.

  Only four values are observed, so this is a lookup rather than a formula;
  unknown values fall back to 33310.

### Validated against the machine's own conversions

Pairing every Yamaha wave with the Typhoon conversion of the same sound:

```
frames      218/218
sample rate 218/218
loop end    218/218
loop start  217/218
```

The single loop-start difference is `PIC-E4`, off by 13 frames, which looks
like a loop someone adjusted by hand during conversion.

Typhoon writes a loop even on waves the Yamaha header marks non-looping, at
exactly the attack boundary. Paketti reports the loop points either way and
only follows the flag for whether looping is *on*, so the loop stays available
without being imposed.

### Still unidentified

Bytes 16–21, 23, 30–31, and the upper bits of 26. Byte 26's upper bits
read 3 on 216 of 220 files, so they are a format marker rather than data. Three
files decode above the smoothness threshold; they may be genuinely noisy
content (the corpus includes cymbals and effects) rather than misparsed.

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
byte 46     polyphony: 0 = poly on, 1 = poly off (mono)          [strong]
byte 47     glide time; location strong, scale unknown, left 0   [partial]
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

### The Mode page: two of four fields found

Manual section 4.6.8 gives each group a `>Poly` flag (on/off), a `>Mode` of
Normal / Oneshot / Glide / Release, and a `>Glide` time in milliseconds.

**byte 46 = polyphony, 0 = poly on, 1 = poly off.** Reads 0 on all 35 groups of
the eight factory voices *and* the third-party `TR_808.O01`, and 1 on all four
groups of `UNISON.O01` — the one voice the release notes describe as "a
monophonic analog type of lead sound". Nothing else in the corpus is
monophonic, and nothing else has this bit set.

**byte 47 = glide time**, location strong, unit unknown. Reads 110 on UNISON's
groups and 0 on all 35 others. UNISON is the only voice with portamento (its
release notes say XCTL2 controls the portamento time). The manual's field runs
0–9999 ms, so 110 is clearly scaled rather than milliseconds — possibly ~40 ms
per step, which would put UNISON near 4.4 s. **Paketti writes 0 here and does
not offer the control**, because guessing the scale would produce a glide of
unpredictable length.

**The Mode enum itself is still not located.** What was tried:

1. **Set difference on drums.** For every byte 4–63, compare the values across
   `DRUMKIT.O01`'s 20 groups against the 15 sustained groups elsewhere. No byte
   separates them.
2. **Candidate elimination by range.** A four-value enum shows 0–3 or 1–4.
   Every byte with a small enough value set is better explained by something
   else, or splits the drum groups against each other.
3. **Byte 30** looked promising — `ANA_STRS` 0, `UNISON` 2, which fits 0-based
   Normal and Glide exactly. But every other voice reads 255, which is not a
   valid mode, so it is something else.

**The likely reason it cannot be found: no voice in the corpus uses Oneshot.**
The Typhoon demo drum kit is built from sine and noise with heavy envelope and
modulation work rather than one-shot playback, and `TR_808.O01` gets its
behaviour from an envelope that never releases (`0,0,127,127,127,127`). If the
corpus only contains Normal and Glide, a drums-versus-sustained comparison was
never going to reveal the field.

**What would settle it.** One voice saved twice on a real TX16W — once Mode =
Normal, once Mode = Oneshot with a known glide time — identical otherwise.
Diffing those two files locates the enum and the glide scale immediately.

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

## What Paketti does today

`PakettiDWVW.lua` — the DWVW codec, import hooks, single-sample export, folder
batch convert, band-limited resampling.
`PakettiTyphoon.lua` — voice/performance/setup reading and writing, the FAT12
image builder and reader, disk packing, kit and song export, the filter table
writer, and MIDI sample dump.

**Export** — instrument to `.C01` waves + `.O01` voice + 720K images +
manifest; whole song to `.X01` setup + `.P01` performance + voices + waves;
velocity layers as groups; GM drum naming; filter, envelope and output choice;
monophonic flag; modulation table; RAM check before writing; `.T18` filter
tables; MIDI sample dump, open loop and paced.

**Import** — 720K disk images in both Typhoon and Yamaha format; `.C01` waves;
`.O01` voices with key mapping; `.W##` Yamaha waves; `.P01` performances (the
MIDI channel lands in the instrument name); `.X01` setups. Drag and drop for
`.img` `.ima` `.C##` `.O##` `.P##` `.X##` `.W##`, either case.

**Verified** — all 1006 real `.C01` files parse, 1002 re-encode bit-identically
and the other 4 decode identically. Built images mount natively with every file
byte-identical. `.W##` checked against Typhoon's own conversions: 218/218 on
frames, rate and loop end.

## Open questions

Each of these says what would actually settle it, because most need the machine.

### Q1 — the Mode enum *(highest value)*

Poly (byte 46) and glide time (byte 47) are found; the Normal / Oneshot /
Glide / Release enum is not. See the Mode page section above for everything
tried. The likely reason it cannot be found in this corpus: **no voice here
uses Oneshot**, so a drums-versus-sustained comparison was never going to
reveal it.

*Settles it:* one voice saved twice on a real TX16W, once `Mode=Normal` and
once `Mode=Oneshot`, identical otherwise. Diff the two files.

### Q2 — the glide time scale

Byte 47 reads 110 on UNISON and 0 on all 35 other groups. The manual's field is
0–9999 ms, so 110 is scaled — possibly ~40 ms per step. Paketti writes 0 rather
than guess.

*Settles it:* two saves, `Glide = 1000 ms` and `Glide = 5000 ms`.

### Q3 — the rest of the group parameter block

Bytes 7–12, 14–17, 19–21, 28–45, 48–63. Known to be in there: LFO1 and LFO2
(shape, rate, amplitude), ENV1 and ENV2 (seven values each, negative levels
allowed), key scaling (11 curves), velocity sensitivity, the filter's dynamic
axis and its two origins, individual outputs, stereo pan (−50..50).

*Settles it:* one voice saved repeatedly with a single parameter changed each
time. Ten saves would probably map most of the block.

### Q4 — `.W##` header bytes 16–21, 23, 30–31 and the upper bits of 26

Byte 26's upper bits read 3 on 216 of 220 files, so a format marker. Byte 23 is
not the rate but is clearly *something* — 79 distinct values. Bytes 16–21 are
called `dummy_aeg` in the published struct and do vary.

*Settles it:* the same sound sampled twice in Yamaha format with one AEG
setting changed.

### Q5 — is the `.W##` rate a lookup or a formula?

Only four index values are observed (40, 41, 73, 127). No linear or divider
formula fits. A lookup covers the corpus but will fail on an unseen rate.

*Settles it:* `.W##` files recorded at 16 kHz and 25 kHz, which this corpus
lacks entirely.

### Q6 — `.A##`, plain AIFF on a floppy

Typhoon reads uncompressed AIFF straight off a disk. Never exercised. Probably
trivial, but it would be a useful fallback if DWVW ever misbehaved on real
hardware.

### Q7 — the Yamaha OS `.F01` / `.S01` / `.U01` / `.V01` files *(partly decoded)*

Every Yamaha-format disk carries exactly one of each, at fixed sizes: `.F01`
and `.S01` are 1536 bytes, `.U01` 5120, `.V01` 15360. All four begin with the
same `LM8953` magic as the waves and filter tables; `.S01`, `.U01` and `.V01`
follow it with the ASCII version string `"0200"`.

**What is solid.**

`.S01` is the **wave directory**. 16-byte records: an 8-character wave name,
then 8 bytes holding a 3-byte memory address and a 4-byte length. The length is
**frames + 64** — verified exactly against all five waves of the ceramic flute
disk (58326/58262, 34875/34811, 67137/67073, 31751/31687, 22405/22341). The
addresses descend as waves are allocated from the top of memory, at roughly two
bytes per sample. There is **no key mapping here**.

`.U01` is the **performance bank**, with 20-character names
("Ceramic Flute WX", "Breath XFade", "Ceramic Suspense").

`.V01` holds two banks. The **voice bank** starts at offset 138 with 32 records
of 146 bytes: a 12-character name at +12, then four-byte entries from +24 of
the form `[timbre index, bottom key, top key, 0]`, terminated by
`00 FF FF 00`. These key ranges are certainly real — they tile the keyboard
without overlapping (46–76, 77–85, 86–97, 98–104, 105–109, 110–126 on the
violin disk). After the voice bank comes a **timbre bank** whose records carry
the referenced wave's name in plain ASCII.

`.F01` is the **filter bank** — its bytes are full of 0x63, 0x32 and 0x1E
(99, 50, 30), which are filter parameter values in the manual's 0–99 range.

**What is not solid, and why this is not implemented.**

The timbre record size does not hold up: measuring the stride between wave
names gives 56 bytes on the ceramic flute disk and 53 on the violin disk, and
at a fixed +36 offset the violin names decode truncated. So either the records
are variable length or the bank does not start where assumed. Consequently the
**timbre index base is also unresolved** — neither 0- nor 1-based produces a
musically sensible order on the flute disk, which is itself a sign the record
model is still wrong rather than a sign about the base.

Until the timbre record is pinned down, importing these would attach samples to
the wrong keys, which is worse than importing them as loose samples. Paketti
reads the `.W##` waves from these disks and ignores the other four files.

*Settles it:* work out the timbre record layout, most cheaply by finding the
bank's true start offset (search for the first wave name and walk backwards to
a record boundary that gives a consistent stride across several disks).

### Q8 — does any of this work on hardware?

Nothing has touched a real TX16W. Highest risk first:

1. **Generated filter tables** — structurally verified byte for byte, never
   heard by anyone.
2. **Very large kits** — 42 splits is the most any factory voice uses; we
   happily write 120.
3. **The 12-byte creator stamp**, generated fresh. Only 667 of 1174 real waves
   shared their voice's stamp, so it reads as informational rather than load
   bearing — but that is an inference.
4. **MIDI sample dump**, sent open loop and never received by a machine.
