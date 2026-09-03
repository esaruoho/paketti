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

- [x] Let Music Mouse hide the pattern drag bars {#musicmouse-hide-pattern}
  by: codex
  from: agent

- [x] Stop Music Mouse pattern playback from stuttering on sound keys and mouse moves {#musicmouse-pattern-stutter}
  by: codex
  from: agent

- [x] Keep Music Mouse transpose keys and visuals in sync {#musicmouse-transpose-visuals}
  by: codex
  from: agent

- [x] Stop transpose keys from sounding while Music Mouse is muted {#musicmouse-muted-transpose}
  by: codex
  from: agent

- [x] Make Music Mouse Plink speak with pitch {#musicmouse-plink-pitch}
  by: codex
  from: agent

- [x] Restore right Shift recording and clarify transpose interval {#musicmouse-rightshift-interval}
  by: codex
  from: agent

- [x] Keep Music Mouse strike shape changes silent {#musicmouse-silent-strike-shape}
  by: codex
  from: agent

## Export SoundFont samples as WAVs {#sf2-wav-export}
tech: PakettiSF2Loader.lua sample header extraction, Renoise SampleBuffer WAV save
files: [PakettiSF2Loader.lua]

- [x] Batch-export every SF2 sample in a folder as named WAV files {#sf2-folder-wav-export}
  by: codex
  from: agent

## Keep command labels readable {#command-labels}
tech: shortcut hint display names, autocomplete command labels
files: [main.lua, PakettiAutocomplete.lua, PakettiShortcutHints.lua]

- [~] Hide internal prefixes from visible menu and autocomplete labels {#hide-internal-command-prefixes}
  by: codex
  from: agent

## Record device toggles as automation {#device-toggle-automation}
tech: PakettiRequests.lua Device Control NN actions, device Active parameter envelopes and x000/x001 pattern commands
files: [PakettiRequests.lua, features/device-toggle-automation.feature, features/device-toggle-automation.session.md, features/device-toggle-automation.transcript.md, features/device-toggle-automation.transcript.jsonl]

- [x] Write Enable/Disable Nth device actions into automation when Edit Mode is on {#device-toggle-active-envelope}
  by: codex
  from: github issue #593

## Turn selections into reversed instrument copies {#selection-reversed-instrument}
tech: PakettiSamples.lua reverse duplicate helper, Pattern Editor selection instrument retargeting
files: [PakettiSamples.lua, PakettiMenuConfig.lua, features/selection-reversed-instrument.feature, features/selection-reversed-instrument.session.md, features/selection-reversed-instrument.transcript.md, features/selection-reversed-instrument.transcript.jsonl]

- [x] Duplicate the selected instrument in reverse and retarget selected notes {#selection-reversed-instrument-shortcut}
  by: codex
  from: github issue #808

## Trade instruments with Ableton Live {#ableton}
tech: PakettiDeflate.lua pure-Lua inflate/gzip, PakettiAbleton.lua XML reader+writer, hooks in PakettiImport.lua
files: [PakettiDeflate.lua, PakettiAbleton.lua, PakettiImport.lua]
links: [fileformats]

- [x] Read and write gzip without shell tools or binaries {#deflate}
  by: claude
  from: agent
- [x] Open Ableton Simpler, Drum Rack, Live Set and Live Clip presets {#ableton-import}
  by: claude
  from: agent
- [x] Turn a Live sliced Drum Rack into one Renoise sample with slice markers {#ableton-sliced-rack}
  by: claude
  from: agent
- [x] Say plainly when a preset's audio is Live-Pack encrypted {#ableton-encrypted-audio}
  by: claude
  from: agent
- [x] Find samples that have moved, using the shared library roots {#ableton-relocate}
  by: claude
  from: agent
- [x] Save an instrument as a Simpler or Drum Rack that Live 12 opens {#ableton-export}
  by: claude
  from: agent
- [ ] Import the audio clips in a Live Set that has no sampler device {#ableton-audio-clips}
  from: agent
- [x] Send a looping sample out to Live {#ableton-export-loops}
  tech: Simpler loops live in Player/LoopModulators, which Live refuses from a written preset; Sampler loops live in MultiSamplePart/SustainLoop and are accepted, so a looping sample exports as a MultiSampler
  by: claude
  from: agent
- [x] Carry loops on single-sample Drum Rack pads {#ableton-simpler-pad-loops}
  tech: solved by writing a looping pad as a MultiSampler with SustainLoop instead of a Simpler; the LoopModulators shape Live accepts is still unknown and would only be needed to keep the Simpler waveform view on a looping pad
  by: claude
  from: agent

## decisions

- Ableton FileRef is resolved through RelativePathType, not the absolute Path: 1 means
  relative to the preset file, 5 a Live Pack, 6 the User Library, 7 Live's own resources,
  and every audio reference is Type="2". Writing the wrong root makes Live open the preset
  with its structure intact and every sample marked Missing, which is how it first failed.
- Paketti writes gzip using DEFLATE "stored" blocks. Every conforming reader must accept
  them, so Paketti needs a decompressor but never a compressor — the largest piece of the
  work disappears and the output is still byte-for-byte legal gzip.
- Renoise decodes and encodes the audio, so porting a container format is container and
  metadata only. That is the structural advantage over a standalone converter, which has
  to carry its own codecs.

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
- The Pattern drag-bar editor should have its own persisted hide flag, independent from Hide Details, so users can keep the controls visible while hiding only the contour editor.
- Music Mouse should treat a selected non-Music-Mouse sample as protected: sound keys warn instead of regenerating or retriggering it, and active contour playback should adopt mouse-position changes on the clock instead of adding immediate off-grid strikes.
- Music Mouse transpose shortcuts must update both the audible notes and the visual readout/canvas; on ISO/Finnish layouts Shift-< should be treated as the upward transpose gesture even if Renoise reports the key name as `<`.
- Music Mouse transpose shortcuts should update the grid state silently when Music Mouse is frozen, keyjazzing, sound-disabled, or mouse-muted; they must not re-trigger the cursor chord from a muted mode.
- Music Mouse Plink should keep its fast percussive decay character but use a longer generated strike, so it reads as a short pitched system sound instead of a pitchless thud.
- Music Mouse Record-to-Pattern stays on right Shift; standalone left Shift must not trigger playback and must leave Shift combos like Shift-< usable. The standalone trigger-this-grid-entry gesture moves from left Shift to standalone Option/Alt.
- Music Mouse `interval` means transpose step size for z/x/<, not a live pattern-playback interval; the UI should name it accordingly.
- Music Mouse Strike controls are sound-design/render controls, not performance gestures: Plink/Bell/Gong, Length, Decay, and Bell/Sustain should render/update the instrument silently; i/o/p and standalone Option/Alt trigger the selected grid entry.
- SF2 folder WAV export should operate on SF2 sample headers directly, saving one WAV per extracted mono sample or stereo pair as `SF2name-SF2Number-SampleName.wav`, without creating permanent Renoise instruments.

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

- [x] Export the song's instruments as one multitimbral performance {#p01-export}
  by: claude
  from: agent
- [x] Put the right disk name on every reference so the sampler asks for the correct floppy {#disk-names}
  by: claude
  from: agent
- [x] Export a whole song as a single setup file {#x01-export}
  by: claude
  from: agent

## Make exported voices sound like the Renoise instrument {#tx16w-voice-params}
tech: map the 64-byte Grop Parm block; AEG from AHDSR, key scaling, one-shot, pan
files: [PakettiTyphoon.lua]
links: [tx16w-modmatrix, tx16w-velocity]

- [x] Work out the 64-byte group parameter layout {#parm-layout}
  by: claude
  from: agent
  note: decoded 0-3 range, 4-6 pitch, 13 filter, 18 output, 22-27 AEG.
  Mode/poly not found - the one-shot AEG covers it, as TR_808 does.
- [x] Carry Renoise envelopes and volume into the exported voice {#aeg-mapping}
  by: claude
  from: agent
- [x] Pick the filter model per export instead of always inheriting one {#filter-choice}
  by: claude
  from: roadmap
- [x] Use one-shot and fixed key scaling for unpitched drums {#drum-defaults}
  by: claude
  from: agent
- [x] Name exported waves after the General MIDI drum on each key {#gm-drum-names}
  by: claude
  from: roadmap

## Draw your own TX16W filter {#tx16w-filter-tables}
tech: .T## writer, LM8953 header, 11x11 grid of 16-tap 12-bit signed FIR kernels
files: [PakettiTyphoon.lua]
links: [tx16w-voice-params]

- [x] Write a filter table the sampler accepts {#t-table-writer}
  by: claude
  from: agent
- [ ] Design filter curves on a canvas and export them {#filter-canvas}
  from: roadmap

## Stop the export surprising people {#tx16w-export-safety}
tech: RAM budget from uncompressed frames, manifest writer, disk labelling
files: [PakettiTyphoon.lua]
needs: [tx16w-export]

- [x] Warn before export when a kit will not fit the sampler's RAM {#ram-check}
  by: claude
  from: roadmap
- [x] Write a text list of what landed on which disk {#disk-manifest}
  by: claude
  from: roadmap

## Bake the controller setup into exported voices {#tx16w-modmatrix}
tech: 8 Mod chunks per group, source/destination tables from the manual
files: [PakettiTyphoon.lua]
needs: [tx16w-voice-params]

- [x] Write the modulation routing into the voice instead of typing it on the sampler {#mod-matrix-write}
  by: claude
  from: roadmap
- [x] Choose which controller drives which destination at export time {#cc-mapping-ui}
  by: claude
  from: roadmap

## Export velocity-layered kits {#tx16w-velocity}
tech: one Grop per velocity layer with stacked Min/Max, splits within each
files: [PakettiTyphoon.lua]
needs: [tx16w-voice-params]

- [x] Turn Renoise velocity layers into TX16W groups {#velocity-groups}
  by: claude
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

## Give every shared helper exactly one definition {#one-definition-per-helper}
tech: dedupe global `function` names across the tree; shared helpers hoisted into main.lua; static gate in .spine/check.py
files: [main.lua, .spine/check.py]

- [x] Put the master-track, sample-editor and pattern-matrix helpers in one place {#tracker-helpers-centralized}
  by: codex
  from: agent

- [x] Make the dialog close key work in every Paketti dialog again {#eq30-keyhandler-clobber}
  by: claude
  from: agent

- [x] Stop Reset Slice Counter from erroring {#reset-slice-counter-prefs}
  by: claude
  from: agent

- [x] Make the Slice Step row shift buttons actually change the pattern {#slicestep-shift-writes}
  by: claude
  from: agent

- [x] Give the remaining sixteen doubled-up helpers a single definition each {#dedupe-remaining-globals}
  by: claude
  from: agent

- [x] Fail the build when a duplicate global function name is added {#duplicate-global-gate}
  by: claude
  from: agent

## decisions

- A helper used by more than one file lives in main.lua's shared-helper block, defined
  once, above every timed_require. A helper used by one file stays in that file.
- Duplicate global function names are a build failure, not a style issue: Lua has no
  duplicate-definition error, so the last file to load silently wins and every earlier
  body becomes unreachable. Two shipped bugs came from exactly this.
- Deliberate duplicates (API-version fallback stubs, forward declarations, vendored
  third-party code, unloaded dev scripts) go in `_DUP_ALLOWED` in .spine/check.py with a
  written reason, never silenced any other way.
- A shared ViewBuilder helper takes `vb` as an argument. Reading a module-level `vb`
  global means whichever file loaded last donates its ViewBuilder to everyone else.
