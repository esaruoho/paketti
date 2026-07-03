# What it takes to prove even 1/10th of the Akai stack

## The stack (7 export capabilities, all with a matched reader)

| Format | Writer (local) | Reader (local) | Import (global) | Export (global) |
|---|---|---|---|---|
| MPC2000 SND | `create_mpc2000_snd` | `parse_mpc2000_snd` | `importMPC2000Sample` | `exportMPC2000Sample` |
| S1000 sample | `create_s1000_sample` | `parse_s1000_sample` | `importS1000Sample` | `exportS1000Sample` |
| S3000 sample | `create_s3000_sample` | `parse_s3000_sample` | `importS3000Sample` | `exportS3000Sample` |
| S900 sample | `create_s900_sample` | `parse_s900_sample` | `importS900Sample` | `exportS900Sample` |
| S1000 program | — | `parse_s1000_program` | `importS1000Program` | `exportS1000Program` |
| MPC1000/2000 pgm | — | `import_mpcXXXX_pgm` | `importMPCProgram` | `exportMPC1000/2000Program` |
| Generic dispatch | — | `importAnyAkaiSample` | — | `exportCurrentSampleAsAkai` |

**The one fact that decides everything:** every sample format is a *self-paired* reader+writer.
So a Paketti-writes → Paketti-reads roundtrip only proves the pair AGREES WITH ITSELF. It does
**not** prove the bytes are spec-valid, and it does **not** prove a real Akai/MPC accepts them.
A bug shared by both halves passes a roundtrip silently. This is the trap to avoid claiming past.

## The proof ladder — cost vs. what it actually buys

### Tier 1 — In-tool roundtrip (self-consistency)   ~40% confidence
NEED:
- Path-override on ONE exporter (`exportS1000Sample(path)`) — the 5-line refactor already used
  for IFF/OT/PTI (skip the prompt when a path is supplied).
- A driver (MCP eval): load a known sample (sine + a set loop + known frame count/rate) →
  export → re-import → assert: frames match exactly, sample-rate preserved, mono-mix correct,
  loop points preserved, audio correlation ≥ 0.999 (16-bit quantization tolerance).
CATCHES: truncation, endianness, header/data offset off-by-one, channel bugs, normalization.
MISSES: bugs shared by reader+writer; whether hardware accepts it.
COST: ~20 min/format. Runs entirely in-tool, zero external deps (after a tool reload).

### Tier 2 — Independent byte-level spec validator   ~75% confidence
NEED:
- The published format spec. These exist and are well-known:
  - S1000/S3000: Akai disk/sample format (150-byte header, 16-bit signed LE PCM @ byte 151,
    AKAII 12-char name, loop structs) — documented in the S1000/S3000 SysEx+Disk format refs.
  - MPC2000 `.SND`: fully documented (fixed header, 16-bit LE, level/tune/loop fields).
- A validator in Python (NOT Paketti's parser — an independent one) asserting each field at its
  documented offset: magic/version, header size, `num_sample_words == actual PCM length`,
  sample-rate flag semantics, name encoding, loop layout.
CATCHES: shared reader/writer bugs, spec violations hardware would reject.
MISSES: undocumented hardware quirks.
COST: ~1–2 h/format (write the validator once, reuse structure across the four sample formats).

### Tier 3 — Cross-tool interop (external ground truth)   ~90% confidence
NEED one of:
- A known-good Akai reader to open our file and confirm identical audio: **Chicken Systems
  Translator**, **Extreme Sample Converter**, **awave studio**, or open-source **akaitools**
  (Dijkstra) / **libakai**.
- OR reference files: convert a WAV to `.s1000`/`.snd` with known-good software and diff our
  output field-for-field against it.
COST: find/install a tool (may not exist for every format); ~half a day.

### Tier 4 — Real hardware   100% confidence
NEED: an actual S1000 / S3000 / S950 / MPC2000 + a transfer path (SCSI2SD, Gotek/HxC floppy
emu, CF card). Load it, hear it play. This is the ONLY thing that proves the user's real claim
("it loads on my sampler").

## Recommendation for the "1/10th" bar

Target **MPC2000 `.SND`** (simplest format, best-documented spec, import+export in one file).
Do **Tier 1 + Tier 2** on it:
1. Add `exportMPC2000Sample(path)` override.
2. In-tool roundtrip driver (frames/rate/loop/audio-correlation asserts).
3. Independent Python `.SND` byte-validator against the published spec.

That yields a defensible statement: *"MPC2000 SND export produces spec-valid files that survive
a full roundtrip"* — roughly one of the ~seven capabilities proven to a real bar = ~1/10th of
the stack, honestly. It is NOT "works on hardware" — only Tier 3/4 earns that, and we should
never say it until we run one of them.

## What I can start immediately (this session)
- Tier 1 harness: the `exportMPC2000Sample(path)` override + the roundtrip eval driver.
- Tier 2: the independent Python `.SND` validator (runs on any produced file, no Renoise).
- Partial-now: I can build an independent Python `.SND` *writer*, emit a reference file, and
  test Paketti's `importMPC2000Sample` against it RIGHT NOW (tests the reader half against an
  outside implementation) — no reload needed for the import direction.
Blocked-until-reload: running the edited exporter live (MCP bypasses `_AUTO_RELOAD_DEBUG`).
