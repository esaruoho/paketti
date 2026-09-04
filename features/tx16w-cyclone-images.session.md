# TX16W Cyclone Images Session

## How To Get Back

- Transcript path: `file:///Users/esaruoho/.codex/sessions/2026/09/04/rollout-2026-09-04T19-34-01-01a06d45-1f53-7e32-9027-2e2af770518a.jsonl`
- Bundled raw transcript: `features/tx16w-cyclone-images.transcript.jsonl`
- Readable transcript: `features/tx16w-cyclone-images.transcript.md`
- Session ID: `01a06d45-1f53-7e32-9027-2e2af770518a`
- Resume command: `codex --resume 01a06d45-1f53-7e32-9027-2e2af770518a`
- Session started: `2026-09-04 19:34:01 +0300 EEST`
- Card written: `2026-09-04 19:38:54 +0300 EEST`
- Identified by content: `CODEX_SESSION_ID` exposed the session id, then the matching JSONL was found under `/Users/esaruoho/.codex/sessions/2026/09/04/`.

## Request

Esa reported that Joshua says the Yamaha TX16W/Typhoon `.img` files exported by Paketti do not work. Esa also said Cyclone is installed in Renoise and asked whether there are `.img` files available to test, because a Paketti-created image should be transformable into something Cyclone can load.

## Investigation

No tracked `.img` files were found inside the Paketti tool repo. PakettiMCP is present in the repo and documents `http://localhost:19714/mcp`, but `curl` to `/health` and `tools/list` timed out from this shell, so live Renoise/Cyclone validation was not available during this pass.

External known-good test material was downloaded from the Sonic Charge forum: `YAMAHA SYNTH ZONE.zip`, which contains `PROPHET5.img` and `SYMPHONI.img`. Both images are exactly 737,280 bytes and use the same core FAT12 geometry as Paketti: 512-byte sectors, 2 sectors per cluster, 1 reserved sector, 2 FATs, 112 root entries, 1440 total sectors, media byte `0xF9`, 3 sectors per FAT, 9 sectors per track, and 2 heads.

The meaningful mismatch was the boot sector identity. Known-good Cyclone images use jump `EB 28 90`, OEM id `Y LM T8W`, and a short DOS 3.x BPB with no extended boot signature at byte 38. Paketti used jump `EB 3C 90`, OEM id `PAKETTI `, and an extended BPB with signature `0x29`, boot-sector volume label, and `FAT12` filesystem type string. The repo's own format note already identified the OEM/header shape as the plausible compatibility risk.

## Second Diagnosis

`PakettiTyphoonBuildDiskImage` now emits the Typhoon/Cyclone-compatible short BPB identity: `EB 28 90`, OEM `Y LM T8W`, the same 720K geometry fields, no extended BPB signature, no boot-sector label, and no boot-sector `FAT12` string. The filesystem writer, FAT allocation, root directory entries, volume label entry, and data-area layout were left alone.

Esa then tested `PAKETT_DISK1.img` in Cyclone and provided a screenshot showing Typhoon's LCD message: `Item requires another OS version`. That proves Cyclone got past raw image insertion and far enough into the item loader to reject the Typhoon item metadata.

The next comparison found that both known-good Cyclone images share an invariant first 8 bytes in every `VInf` stamp: `b4 a8 f8 28 a8 c6 d1 86`. Paketti had generated a fully synthetic 12-byte stamp, for example `28 79 34 a4 6e e6 34 6e 9d 47 af 75`. Paketti also generated arbitrary hashed 4-byte item ids, including low values like `0f d5 08 f8`, while known-good voice and wave ids are ordered Typhoon-like values near the disk/set id.

## What Changed

`PakettiTyphoonNewStamp` now keeps the observed Typhoon creator signature as the first 8 bytes and uses a per-export trailing 4-byte disk/set id.

`PakettiTyphoonNewWaveId` now emits descending Typhoon-like object ids near the stamp's trailing id rather than arbitrary hashes.

`typhoon-tx16w-format.txt` was updated to describe the boot-sector and VInf export shape and to keep the verification boundary clear: static image/header/item comparison is done; live Cyclone and hardware loading are still unverified for the VInf-fixed export.

## Verification

- Found no local tracked `.img` files in the repo.
- Downloaded and inspected two known-good Cyclone images from Sonic Charge.
- Confirmed the known-good BPB geometry matches Paketti's geometry constants.
- Confirmed the compatibility mismatch was in the boot-sector template, not the FAT geometry.
- Created a four-sample drumkit through PakettiMCP and exported `/Users/esaruoho/Downloads/tx16w/PAKETT_DISK1.img`.
- Esa tested that image in Cyclone and got `Item requires another OS version`.
- Patched the live VInf generator through PakettiMCP, created another four-sample drumkit, and exported `/Users/esaruoho/Downloads/tx16w/vinf-fixed/PAKETT_DISK1.img`.
- Confirmed the VInf-fixed image uses the known-good creator signature and still passes `fsck_msdos -n`.
- Esa tested the VInf-fixed export in Cyclone and reported: `IT LOADED!`.

## RX2 Proof Export

Esa then asked for proof via RX2-to-IMG material so the result could be heard as a funky kit rather than only tested as a synthetic drumkit.

Candidate RX2/REX files were inspected through PakettiMCP using `PakettiRX2ReadInfo`. `/Users/esaruoho/Downloads/NLB BREAKS/RS - Funkey Bazzard.rx2` was selected because it is mono, 24 visible slices, 151,232 frames, 44.1 kHz, 3.429 seconds, and approximately 139.983 BPM.

Through PakettiMCP, Paketti decoded the RX2 with `PakettiRX2DecodeFile`, created a new Renoise instrument named `RX2 FUNK PROOF`, mapped the first 24 visible slices from C-2 upward, wrote a 32-line trigger pattern at 140 BPM, and exported the selected instrument with `PakettiTyphoonExportDrumkit`.

Output files:

- `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISK1.img`
- `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISKS.txt`
- `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FUNK_PROOF.wav`
- Loose Typhoon items under `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/files/`

Verification:

- `RX2_FU_DISK1.img` passes `fsck_msdos -n`.
- The image boot sector starts `EB 28 90 59 20 4C 4D 20 54 38 57`, matching the Typhoon/Cyclone-compatible short BPB identity.
- All 24 wave items and the voice use the observed `VInf` creator signature `b4 a8 f8 28 a8 c6 d1 86`.
- The rendered WAV preview is 3.428571 seconds at 44.1 kHz 16-bit stereo, with peak level about `-7.54 dBFS` and RMS about `-22.37 dBFS`, so it is not a silent render.

## RX2 Pitch Fix

Esa reported that the RX2 drumkit loaded, but later pads played chromatically higher: the kick was at the right pitch, the next sample played one semitone higher, and so on.

The cause was that Paketti copied each Renoise sample's trigger key into the DWVW/AIFF `INST` base note. In the original RX2 proof export, `FBZ01.C01` through `FBZ24.C01` carried base notes `36..59`. Cyclone therefore had both an advancing split key and an advancing wave root, producing audible upward transposition.

`PakettiTyphoon.lua` now uses `typhoon_export_wave_notes` during export. For one-shot drum pads, single-key mappings, and sequential drumkit exports, the wave root is calibrated one octave below the export base key and the wave note bounds stay wide while the voice split key advances. Wider pitched multisample ranges still preserve the Renoise sample root and bounds.

An immediate fixed-pitch proof image was regenerated through PakettiMCP by setting the already-created RX2 proof instrument's sample roots to C-2 before using the current live exporter:

- `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof-fixed/RX2_FU_DISK1.img`
- `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof-fixed/RX2_FU_DISKS.txt`
- Loose items under `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof-fixed/files/`

Verification:

- The fixed image passes `fsck_msdos -n`.
- The fixed image contains one voice and 24 waves.
- Old proof wave roots were `36..59`.
- Fixed proof wave roots are all `36`.
- Fixed proof voice split keys still advance through the pads, with split points `37..60`, so the keyboard mapping remains one slice per key.

Esa then reported that the chromatic lift was gone, but the whole kit sounded at least one octave too low. The second correction treats Typhoon/Cyclone's neutral drum-pad root as one octave below the pad trigger key: a C-2 based kit should export wave roots as `24`, not `36`. Drum-pad wave note bounds are also widened to `0..127`, matching the shape seen in known-good Cyclone wave files, because the `.O01` split map owns the actual pad range.
