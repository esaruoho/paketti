# Readable Transcript: TX16W Cyclone-Compatible IMG Boot Sectors

This file summarizes the work-driving transcript for the bundled raw JSONL at `features/tx16w-cyclone-images.transcript.jsonl`.

Session ID: `01a06d45-1f53-7e32-9027-2e2af770518a`

Original transcript path: `file:///Users/esaruoho/.codex/sessions/2026/09/04/rollout-2026-09-04T19-34-01-01a06d45-1f53-7e32-9027-2e2af770518a.jsonl`

## Key Turns

- Esa reported that Joshua says Paketti's Yamaha TX16W/Typhoon `.img` exports do not work.
- Codex searched the repo for existing `.img` files and found none.
- Codex inspected `PakettiTyphoon.lua`, `typhoon-tx16w-format.txt`, and the PakettiMCP bridge.
- PakettiMCP did not answer on `localhost:19714`, so live Renoise/Cyclone validation could not run from this shell.
- Codex downloaded Sonic Charge's `YAMAHA SYNTH ZONE.zip`, containing known-good Cyclone images `PROPHET5.img` and `SYMPHONI.img`.
- Codex compared their BPB/FAT12 geometry against Paketti and found the geometry matched.
- Codex identified the boot-sector identity as the likely incompatibility: known-good Cyclone images use OEM `Y LM T8W` and a short DOS BPB, while Paketti used OEM `PAKETTI ` and an extended BPB.
- Codex patched `PakettiTyphoonBuildDiskImage` to emit the Cyclone-compatible short BPB identity and updated the format notes and report-card triad.
- Esa tested the exported image in Cyclone and provided a screenshot showing `Item requires another OS version`.
- Codex compared known-good and Paketti `VInf` stamps and found that known-good Cyclone images share invariant creator bytes `b4 a8 f8 28 a8 c6 d1 86`, while Paketti used arbitrary synthetic stamp bytes and hash-like ids.
- Codex patched `PakettiTyphoonNewStamp` and `PakettiTyphoonNewWaveId`, then used PakettiMCP to create and export `/Users/esaruoho/Downloads/tx16w/vinf-fixed/PAKETT_DISK1.img`.
