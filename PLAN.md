## Keep Music Mouse shortcuts honest {#musicmouse-shortcuts}
tech: PakettiMusicMouse.lua keyhandler modifier filtering, Paketti0G01_Loader.lua preferences schema
files: [PakettiMusicMouse.lua, Paketti0G01_Loader.lua]

- [x] Stop modified function keys from triggering Music Mouse treatments {#ignore-modified-fkeys}
  by: codex
  from: agent

- [x] Make Music Mouse tempo sync state legible {#explain-musicmouse-tempo}
  by: codex
  from: agent

- [x] Make single-note playback stop hidden arpeggio voices {#single-note-arp-voices}
  by: codex
  from: agent

- [x] Stabilize synced Line timing during grid changes {#synced-line-grid-timing}
  by: codex
  from: agent

- [x] Let Music Mouse choose arpeggio note rate {#musicmouse-arp-note-rate}
  by: codex
  from: agent

- [x] Make Music Mouse rate control visible and compact {#musicmouse-rate-ui}
  by: codex
  from: agent

- [x] Prototype phrase-backed Music Mouse arpeggiation {#musicmouse-phrase-arp-prototype}
  by: codex
  from: agent

- [x] Keep the Phrase Arp checkbox actionable from every treatment {#musicmouse-phrase-arp-checkbox}
  by: codex
  from: agent

- [x] Let the phrase clock run in Line mode {#musicmouse-phrase-line}
  by: codex
  from: agent

- [x] Keep phrase Scatter changes on the phrase clock {#musicmouse-phrase-scatter}
  by: codex
  from: agent

- [x] Stop stale phrase playback when Music Mouse starts in Chord mode {#musicmouse-phrase-lifecycle}
  by: codex
  from: agent

- [x] Release a phrase trigger that was already held before reload {#musicmouse-phrase-held-release}
  by: codex
  from: agent

- [x] Remove Paketti's stale phrase mapping before Chord playback {#musicmouse-phrase-mapping-cleanup}
  by: codex
  from: agent

- [x] Disable phrase playback completely in Chord mode {#musicmouse-phrase-off}
  by: codex
  from: agent

- [x] Use Renoise's actual phrase-off constant {#musicmouse-phrase-off-constant}
  by: codex
  from: agent

- [x] Apply Strum spacing inside the live phrase {#musicmouse-phrase-strum-spacing}
  by: codex
  from: agent

- [x] Respect freeze mode and add ping-pong arpeggio directions {#musicmouse-arp-pingpong}
  by: codex
  from: agent

## decisions

- Music Mouse F1-F4 treatment shortcuts should only react to bare function keys; modified function keys belong to Renoise/macOS/global shortcuts unless explicitly mapped by Music Mouse.
- Music Mouse Sync overrides Tempo 1 and Tempo 2; the UI should disable ignored free-run controls and expose the effective arpeggio rate so users can see whether playback is synced to Renoise lines or free-running.
- Music Mouse Single note should filter every live and write treatment, including Chord, Arpeggiate, Line, Strum, Improvise, arpeggio stamping, and Record to Row, so hidden grid voices are not still audible or written.
- Music Mouse Sync can only phase-lock when Renoise transport is playing; when stopped it should say it is free-running at the song line duration, because there is no moving playhead line to lock against.
- Music Mouse Arpeggiate and Line should use explicit musical note rates; at LPB 4, 1/16 means one Renoise row, 1/8 means every two rows, 1/32 means two hits per row.
- Music Mouse tempo status should be short enough not to widen the dialog; rate selection needs its own visible row instead of being hidden in the Treatment row.
- Phrase-backed Music Mouse arpeggiation is an opt-in Paketti prototype: it owns a reusable `Paketti Music Mouse Live Arp` phrase, rewrites its notes and length from the current grid, and triggers it through a reserved low phrase-keymap note so Renoise provides the playback clock.
- The Phrase Arp checkbox must remain enabled because enabling it is what switches Music Mouse into Arpeggiate mode and resolves the Strum conflict.
- Phrase-backed playback should support both Arpeggiate and Line; Line keeps its ascending sequence while Arpeggiate retains its selected direction.
- Phrase playback must not rewrite the phrase from its timer callback; Scatter order changes only when its source state changes, so Renoise can provide a stable phrase clock.
- Closing, reloading, or re-opening Music Mouse in Chord mode must restore phrase playback so an old Paketti phrase cannot leak into normal notes.
- Startup cleanup must send note-off to the reserved Paketti phrase trigger before changing the instrument phrase mode.
- Startup cleanup must remove only the mapping attached to Paketti's owned live-arpeggio phrase, so Chord mode cannot retrigger it.
- Chord mode must set the instrument phrase playback mode to `PHRASES_OFF`; Selective mode is still capable of launching phrases.
- Phrase Strum should encode `strum_ms` as phrase delay-column offsets while keeping the phrase loop interval musical and rate-controlled.
- Changing Strum spacing must immediately rewrite an active Phrase Arp phrase.
- Freeze mode must block phrase re-strikes, and arpeggio direction must offer ascending/descending ping-pong cycles.

## Read TX16W floppies back into Renoise {#tx16w-import}
tech: FAT12 reader over 720K .img, .O01 voice parser, rebuild instrument with key mapping
files: [PakettiTyphoon.lua, PakettiDWVW.lua]
links: [tx16w-export, tx16w-voice-params]

- [x] Open a 720K disk image and load everything on it {#img-import}
  by: claude
  from: agent
- [x] Rebuild an instrument from a .O01 voice, key mapping and all {#o01-import}
  by: claude
  from: agent
- [x] Drag a .img or .O01 onto Renoise and have it load {#tx16w-import-hooks}
  by: claude
  from: agent

## Send whole Renoise songs to the TX16W {#tx16w-performance}
tech: FORM TYPP writer, Entr/PChg chunks, FORM TYPS setup writer
files: [PakettiTyphoon.lua]
needs: [tx16w-export]

- [ ] Export the song's instruments as one multitimbral performance {#p01-export}
  from: agent
- [x] Put the right disk name on every reference so the sampler asks for the correct floppy {#disk-names}
  by: claude
  from: agent
- [ ] Export a whole song as a single setup file {#x01-export}
  from: agent

## Make exported voices sound like the Renoise instrument {#tx16w-voice-params}
tech: map the 64-byte Grop Parm block; AEG from AHDSR, key scaling, one-shot, pan
files: [PakettiTyphoon.lua]
links: [tx16w-modmatrix, tx16w-velocity]

- [ ] Work out the 64-byte group parameter layout {#parm-layout}
  from: agent
- [ ] Carry Renoise envelopes and volume into the exported voice {#aeg-mapping}
  from: agent
- [ ] Pick the filter model per export instead of always inheriting one {#filter-choice}
  from: roadmap
- [ ] Use one-shot and fixed key scaling for unpitched drums {#drum-defaults}
  from: agent

## Draw your own TX16W filter {#tx16w-filter-tables}
tech: .T## writer, LM8953 header, 11x11 grid of 16-tap 12-bit signed FIR kernels
files: [PakettiTyphoon.lua]
links: [tx16w-voice-params]

- [ ] Write a filter table the sampler accepts {#t-table-writer}
  from: agent
- [ ] Design filter curves on a canvas and export them {#filter-canvas}
  from: roadmap

## Stop the export surprising people {#tx16w-export-safety}
tech: RAM budget from uncompressed frames, manifest writer, disk labelling
files: [PakettiTyphoon.lua]
needs: [tx16w-export]

- [ ] Warn before export when a kit will not fit the sampler's RAM {#ram-check}
  from: roadmap
- [ ] Write a text list of what landed on which disk {#disk-manifest}
  from: roadmap

## Bake the controller setup into exported voices {#tx16w-modmatrix}
tech: 8 Mod chunks per group, source/destination tables from the manual
files: [PakettiTyphoon.lua]
needs: [tx16w-voice-params]

- [ ] Write the modulation routing into the voice instead of typing it on the sampler {#mod-matrix-write}
  from: roadmap
- [ ] Choose which controller drives which destination at export time {#cc-mapping-ui}
  from: roadmap

## Export velocity-layered kits {#tx16w-velocity}
tech: one Grop per velocity layer with stacked Min/Max, splits within each
files: [PakettiTyphoon.lua]
needs: [tx16w-voice-params]

- [ ] Turn Renoise velocity layers into TX16W groups {#velocity-groups}
  from: roadmap

## decisions

- Velocity layers are GROUPS, not splits. Each group carries its own key range
  and its own velocity range (>Min/>Max); splits only subdivide a group by key.
  So Joshua's question "does the Voice format support velocity zones at the
  format level" is answered yes, and the implementation is N groups with
  overlapping key ranges and stacked velocity ranges.
- Trim exported waves at the loop end. The TX16W has no loop end, so not
  trimming makes the sampler play a longer loop than Renoise does. Lossless.
- Budget RAM against uncompressed frames, not file size. DWVW shrinks the disk
  copy only; the sampler holds the decoded audio.
- The 8-byte trailer on every Wave/Voic/Perf reference is a disk name. Writing
  the real volume label is what makes the sampler prompt for a named floppy.
