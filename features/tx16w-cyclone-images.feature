# =============================================================================
# WIKI PAGE / REPORT CARD: TX16W IMG exports use Cyclone-compatible item identity
#
# WHAT THIS CARD SPAWNS:
#   codespace  - PakettiTyphoon.lua disk-image writer, VInf generator, and typhoon-tx16w-format.txt notes
#   thinkspace - tx16w-cyclone-images.session.md (the conversation that produced it)
#   areaspace  - OWNS: 720K FAT12 boot-sector and Typhoon VInf identity compatibility for exported TX16W IMG data disks
#                MUST NOT TOUCH: DWVW encoding, voice mapping, performance/setup parsing, or Renoise import reconstruction
#
# Report-card legend (grade tags, weakest -> strongest):
#   @designed @built @code-verified @build-verified @sim-verified
#   @runtime-verified @hw-verified   |   @untested @runtime-untested
#   @hw-untested @todo @partial   |   @stock (pre-existing, not ours)
#
# Innards linked back to this card (grep "tx16w-cyclone-images"):
#   PakettiTyphoon.lua - PakettiTyphoonBuildDiskImage emits the 720K FAT12 IMG header
#   PakettiTyphoon.lua - PakettiTyphoonNewStamp and PakettiTyphoonNewWaveId emit Typhoon-like VInf identity
#   typhoon-tx16w-format.txt - documents the compatible boot-sector and VInf shape plus verification boundary
#
# Commit log:   worktree  Cyclone-compatible TX16W IMG boot-sector and VInf identity fix
# SESSION:      tx16w-cyclone-images.session.md
# RESULT:       Feature delivery worktree (direct local edit, no PR); card worktree
#
# WATCH: PakettiTyphoonBuildDiskImage PakettiTyphoonNewStamp PakettiTyphoonNewWaveId typhoon_export_wave_notes
#
# RESULT-LOG >> (auto-maintained by the report-card hooks - newest below)
#   2026-09-05  direct-commit  touched: PakettiTyphoonNewWaveId
#   2026-09-04  direct-commit  touched: typhoon_export_wave_notes
# =============================================================================

Feature: TX16W IMG exports use Cyclone-compatible item identity
  As a Paketti user, I want exported Yamaha TX16W IMG disks to present the same disk and item identity as known-good Cyclone images, So that Typhoon/Cyclone sees the disk contents as loadable Typhoon items.

  @shipped @built @code-verified @runtime-verified
  Scenario: Exported IMG uses the Typhoon/Cyclone short BPB identity
    # cite: PakettiTyphoon.lua PakettiTyphoonBuildDiskImage (~line 754) - writes jump EB 28 90, OEM "Y LM T8W", short BPB fields, no extended BPB signature ; commit worktree
    Given Paketti builds a 720K TX16W disk image
    When the boot sector is written
    Then bytes 3 through 10 identify the disk as "Y LM T8W"
    And byte 38 remains 0x00 instead of the extended-BPB signature 0x29

  @shipped @built @code-verified @runtime-verified
  Scenario: Exported Typhoon items use the observed creator signature
    # cite: PakettiTyphoon.lua PakettiTyphoonNewStamp (~line 67) - writes the invariant 8-byte Typhoon creator signature seen in known-good Cyclone images ; commit worktree
    Given Paketti creates a voice, setup, performance, or wave VInf stamp
    When the stamp is written into a Typhoon item
    Then the first 8 bytes are b4 a8 f8 28 a8 c6 d1 86
    And the last 4 bytes identify the exported disk set

  @shipped @built @code-verified @runtime-verified
  Scenario: Exported Typhoon item ids avoid arbitrary hash values
    # cite: PakettiTyphoon.lua PakettiTyphoonNewWaveId (~line 75) - emits descending Typhoon-like object ids near the stamp's trailing setup id ; commit worktree
    Given a Paketti export creates multiple related voice and wave objects
    When each object receives its 4-byte VInf id
    Then the ids are ordered Typhoon-like object ids rather than low/random hash values

  @shipped @built @code-verified @runtime-verified
  Scenario: Exported IMG keeps the known-good 720K floppy geometry
    # cite: PakettiTyphoon.lua PAKETTI_TYPHOON_* constants and PakettiTyphoonBuildDiskImage (~line 712) - keeps 80/2/9 FAT12 geometry and 737280-byte output ; commit worktree
    Given a TX16W image is built from files that fit on one disk
    When Paketti writes the filesystem
    Then the image remains 737280 bytes
    And the BPB reports 512 bytes per sector, 2 sectors per cluster, 2 FATs, 112 root entries, 1440 sectors, media byte 0xF9, 3 sectors per FAT, 9 sectors per track, and 2 heads

  @stock
  Scenario: File placement and root-directory labels still use the existing FAT writer
    # cite: PakettiTyphoon.lua PakettiTyphoonBuildDiskImage (~line 767) - FAT allocation, root entries, and data area writer are unchanged by the boot-sector fix ; commit worktree
    Given a list of Typhoon voice and wave files
    When Paketti packs them into the IMG
    Then the root directory still stores the volume label and one 8.3 entry per file
    And file data is still written in 1024-byte FAT12 clusters

  @shipped @runtime-verified
  Scenario: Cyclone loads a VInf-fixed Paketti-exported disk through Typhoon Load*
    # cite: user runtime test on 2026-09-04 - Esa reported "IT LOADED!" after testing the VInf-fixed export in Cyclone ; commit worktree
    Given Cyclone is loaded in Renoise and PakettiMCP is reachable
    When `/Users/esaruoho/Downloads/tx16w/vinf-fixed/PAKETT_DISK1.img` is inserted and Typhoon runs System Setup, Utility, Load*, Go
    Then Cyclone loads the Paketti-exported disk instead of rejecting the item as requiring another OS version

  @shipped @built @runtime-verified
  Scenario: RX2 break slices export as an audible Cyclone proof image
    # cite: PakettiRX2Decode.lua PakettiRX2DecodeFile (~line 273) - decoded `RS - Funkey Bazzard.rx2`; PakettiTyphoon.lua PakettiTyphoonExportDrumkit (~line 1270) - exported `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISK1.img` ; commit worktree
    Given Paketti decodes `/Users/esaruoho/Downloads/NLB BREAKS/RS - Funkey Bazzard.rx2`
    When the first 24 visible RX2 slices are mapped as one-shot samples from C-2 upward
    And the selected instrument is exported to Yamaha TX16W IMG
    Then `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FU_DISK1.img` contains one voice and 24 wave items
    And the image passes `fsck_msdos -n`
    And the matching Renoise preview render `/Users/esaruoho/Downloads/tx16w/rx2-funk-proof/RX2_FUNK_PROOF.wav` has non-silent audio

  @shipped @built @code-verified @runtime-verified
  Scenario: Drum-pad exports preserve each slice's chromatic root
    # cite: PakettiTyphoon.lua typhoon_export_wave_notes (~line 994) - per-sample key wins over the kit default for DWVW/AIFF INST root metadata, while wide wave bounds remain for one-shot pad mapping ; commit worktree
    Given a drumkit maps one one-shot sample per MIDI key
    When Paketti exports each sample as a Typhoon `.C01` wave
    Then the wave `INST` base note matches that sample's trigger key
    And the wave `INST` note bounds stay `0..127`
    And the voice `Splt` keys still advance one key per sample
    And Cyclone retains the intended chromatic pitch relationship between slices

  @shipped @built @code-verified @runtime-verified
  Scenario: Drumkit exports include a loadable performance
    # cite: PakettiTyphoon.lua typhoon_export_process (~line 1205) - emits a linked `.P01` with the kit voice on MIDI channel 10 and program 0 ; commit worktree
    Given Paketti exports a drumkit as a Typhoon image set
    When the export finishes
    Then disk 1 contains the kit `.O01` and matching `.P01`
    And the `.P01` references the exact voice id and assigns MIDI channel 10
