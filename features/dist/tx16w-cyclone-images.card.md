# Report Card — TX16W IMG exports use Cyclone-compatible item identity

> Source: `features/tx16w-cyclone-images.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want exported Yamaha TX16W IMG disks to present the same disk and item identity as known-good Cyclone images, So that Typhoon/Cyclone sees the disk contents as loadable Typhoon items.

**Grades:** @built × 13 · @code-verified × 12 · @runtime-untested × 1 · @runtime-verified × 13 · @shipped × 13 · @stock × 1

**Scenarios: 15**


---


## 1. Exported IMG uses the Typhoon/Cyclone short BPB identity

`@shipped @built @code-verified @runtime-verified`


- Given Paketti builds a 720K TX16W disk image
- When the boot sector is written
- Then bytes 3 through 10 identify the disk as "Y LM T8W"
- And byte 38 remains 0x00 instead of the extended-BPB signature 0x29

<sub>cite: PakettiTyphoon.lua PakettiTyphoonBuildDiskImage (~line 754) - writes jump EB 28 90, OEM "Y LM T8W", short BPB fields, no extended BPB signature ; commit worktree</sub>


## 2. Exported Typhoon items use the observed creator signature

`@shipped @built @code-verified @runtime-verified`


- Given Paketti creates a voice, setup, performance, or wave VInf stamp
- When the stamp is written into a Typhoon item
- Then the first 8 bytes are b4 a8 f8 28 a8 c6 d1 86
- And the last 4 bytes identify the exported disk set

<sub>cite: PakettiTyphoon.lua PakettiTyphoonNewStamp (~line 67) - writes the invariant 8-byte Typhoon creator signature seen in known-good Cyclone images ; commit worktree</sub>


## 3. Exported Typhoon item ids avoid arbitrary hash values

`@shipped @built @code-verified @runtime-verified`


- Given a Paketti export creates multiple related voice and wave objects
- When each object receives its 4-byte VInf id
- Then the ids are ordered Typhoon-like object ids rather than low/random hash values

<sub>cite: PakettiTyphoon.lua PakettiTyphoonNewWaveId (~line 75) - emits descending Typhoon-like object ids near the stamp's trailing setup id ; commit worktree</sub>


## 4. Exported IMG keeps the known-good 720K floppy geometry

`@shipped @built @code-verified @runtime-verified`


- Given a TX16W image is built from files that fit on one disk
- When Paketti writes the filesystem
- Then the image remains 737280 bytes
- And the BPB reports 512 bytes per sector, 2 sectors per cluster, 2 FATs, 112 root entries, 1440 sectors, media byte 0xF9, 3 sectors per FAT, 9 sectors per track, and 2 heads

<sub>cite: PakettiTyphoon.lua PAKETTI_TYPHOON_* constants and PakettiTyphoonBuildDiskImage (~line 712) - keeps 80/2/9 FAT12 geometry and 737280-byte output ; commit worktree</sub>


## 5. File placement and root-directory labels still use the existing FAT writer

`@stock`


- Given a list of Typhoon voice and wave files
- When Paketti packs them into the IMG
- Then the root directory still stores the volume label and one 8.3 entry per file
- And file data is still written in 1024-byte FAT12 clusters

<sub>cite: PakettiTyphoon.lua PakettiTyphoonBuildDiskImage (~line 767) - FAT allocation, root entries, and data area writer are unchanged by the boot-sector fix ; commit worktree</sub>


## 6. Cyclone loads a VInf-fixed Paketti-exported disk through Typhoon Load*

`@shipped @runtime-verified`


- Given Cyclone is loaded in Renoise and PakettiMCP is reachable
- When `/Users/esaruoho/Downloads/tx16w/vinf-fixed/PAKETT_DISK1.img` is inserted and Typhoon runs System Setup, Utility, Load*, Go
- Then Cyclone loads the Paketti-exported disk instead of rejecting the item as requiring another OS version

<sub>cite: user runtime test on 2026-09-04 - Esa reported "IT LOADED!" after testing the VInf-fixed export in Cyclone ; commit worktree</sub>


## 7. A 120-pad drumkit uses bounded voices in one performance

`@built @code-verified @runtime-untested`


- Given a drumkit contains 120 mapped samples
- When Paketti exports the kit to TX16W images
- Then the kit has three voices with no more than 40 splits each
- And the P01 references all three voices on MIDI channels 1 and 10
- And the loose output contains the P01 as well as every O01

<sub>cite: PakettiTyphoon.lua partition_voice_groups and typhoon_export_process (~line 1200) - caps voices at 40 splits and emits all voice references in the P01 ; worktree</sub>


## 8. RX2 break slices export as an audible Cyclone proof image

`@shipped @built @runtime-verified`


- Given Paketti decodes `/Users/esaruoho/Downloads/NLB BREAKS/RS - Funkey Bazzard.rx2`
- When the first 24 visible RX2 slices are mapped as one-shot samples from C-2 upward
- And the selected instrument is exported to Yamaha TX16W IMG
- Then `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISK1.img` contains one voice and 24 wave items
- And the image passes `fsck_msdos -n`
- And the matching Renoise preview render `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FUNK_PROOF.wav` has non-silent audio

<sub>cite: PakettiRX2Decode.lua PakettiRX2DecodeFile (~line 273) - decoded `RS - Funkey Bazzard.rx2`; PakettiTyphoon.lua PakettiTyphoonExportDrumkit (~line 1270) - exported `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISK1.img` ; commit worktree</sub>


## 9. Drum-pad exports preserve each slice's chromatic root

`@shipped @built @code-verified @runtime-verified`


- Given a drumkit maps one one-shot sample per MIDI key
- When Paketti exports each sample as a Typhoon `.C01` wave
- Then the wave `INST` base note matches that sample's trigger key
- And the wave `INST` note bounds stay `0..127`
- And the voice `Splt` keys still advance one key per sample
- And Cyclone retains the intended chromatic pitch relationship between slices

<sub>cite: PakettiTyphoon.lua typhoon_export_wave_notes (~line 994) - per-sample key wins over the kit default for DWVW/AIFF INST root metadata, while wide wave bounds remain for one-shot pad mapping ; commit worktree</sub>


## 10. Drumkit exports include a loadable performance

`@shipped @built @code-verified @runtime-verified`


- Given Paketti exports a drumkit as a Typhoon image set
- When the export finishes
- Then disk 1 contains the kit `.O01` and matching `.P01`
- And the `.P01` references the exact voice id and assigns MIDI channel 10

<sub>cite: PakettiTyphoon.lua typhoon_export_process (~line 1205) - emits a linked `.P01` with the kit voice on MIDI channel 10 and program 0 ; commit worktree</sub>


## 11. A 120-sample kit spanning two disks loads and plays in Cyclone

`@shipped @built @code-verified @runtime-verified`


- Given a 120-sample drumkit that does not fit on one 720K disk
- When Paketti exports it and the user loads disk 1 in Cyclone
- Then no "wave length / loop adjusted" warning appears
- And the sampler asks for disk 2 BY NAME, as "Missing wave X (from LABEL)"
- And swapping to disk 2 at that prompt resolves the remaining waves
- And every pad triggers its own sample across the keyboard

<sub>cite: PakettiTyphoon.lua typhoon_export_process - chained layout: voices, performance and .X01 setup on disk 1, waves packed across the set, every wave reference naming the disk it landed on ; commit 29f11f72 98d80040</sub>


## 12. Each wave sits in its own group covering the keys it owns

`@shipped @built @code-verified @runtime-verified`


- Given an instrument with many samples on consecutive keys
- When Paketti builds the Typhoon voice
- Then each sample gets its own group covering exactly its one key
- And a single sample mapped across the keyboard instead gets ONE group spanning the whole board
- And no group uses a second split point

<sub>cite: PakettiTyphoon.lua build_key_groups - one Grop per split, spanning from its own key to just below the next split's ; commit 7483dc42 aa493f55</sub>


## 13. Every wave carries the loop metadata Typhoon expects

`@shipped @built @code-verified @runtime-verified`


- Given a one-shot sample of an arbitrary length
- When Paketti encodes it as a Typhoon `.C01` wave
- Then the frame count is a multiple of 64
- And the wave carries INST and MARK
- And the loop markers sit at the very end so no data follows the loop
- And Typhoon reports neither "wave length / loop adjusted" nor "data after loop will not be loaded"

<sub>cite: PakettiDWVW.lua PakettiDWVWBuildFile - always emits INST and MARK, pads a non-looping wave to a multiple of 64 frames ; commit aab3dd17</sub>


## 14. A disk can be found by the name a reference gives it

`@shipped @built @code-verified @runtime-verified`


- Given a kit that spans more than one disk
- When Paketti writes the images
- Then each volume label contains only letters and digits
- And each image file is named after its own volume label
- And a wave reference names the label of the disk that wave is on

<sub>cite: PakettiTyphoon.lua typhoon_export_process - labels stripped to letters and digits, image file named after the label ; commit 98d80040</sub>


## 15. The first drum slice starts at the requested base key

`@shipped @built @code-verified @runtime-verified`


- Given a drumkit's first sample is mapped to a given Renoise key
- When Paketti builds the Typhoon voice
- Then the Typhoon key equals the MIDI note number, with no offset added
- And a kit laid out from Renoise C-0 occupies Typhoon keys 0..119
- And following slices remain addressable at consecutive keys

<sub>cite: PakettiTyphoon.lua build_voice_groups (~line 1108) - group lower key supplies the first Typhoon Splt key because the first Splt has no Parm chunk ; commit worktree</sub>

