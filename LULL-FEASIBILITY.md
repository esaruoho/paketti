# "Lull" / selection-volume — feasibility assessment

*Question from the Discord: offset the **volume** of selected notes (like the existing
transpose offset), and/or Esa's richer "Lull a segment" idea. Verdict: **fully feasible,
three ways, ~80–90% of the building blocks already exist in Paketti.** This is a UX-design
decision, not a feasibility risk.*

---

## The verified facts (API + existing Paketti)

- **`renoise.song().selection_in_pattern`** gives the selection rectangle (start/end track,
  line, column). **Paketti already walks it** — `PakettiTransposer(steps, selection)` in
  `PakettiControls.lua:252` iterates tracks→lines→note_columns over exactly this.
- **`NoteColumn.volume_value` is read/write** (used all over Paketti). Range: **0–127 =
  quiet→full, 255 = empty/default**; >0x80 = volume-column FX. So per-note volume is directly
  settable.
- **`instrument.volume` is read/write**, range **0 → +6 dB** (`math.db2lin(6)`). The "Lull
  duplicate" approach hangs off this.
- **`track.postfx_volume` / `prefx_volume`** are automatable `DeviceParameter` faders — the
  Renoise analog of ImpulseTracker's "channel volume."
- **Instrument-duplicate-on-selection already exists**: `DuplicateSpecificNotesToNewTrack(
  note_type, "duplicate"/"selected"/"original")` (`PakettiChordsPlus.lua:885`).
- **The revert path already exists**: `SetInstrument()` = "ALT-S Set Selection to Instrument"
  (`PakettiImpulseTracker.lua:1465`).

---

## Three buildable approaches

### 1. Volume-column offset on selection — *the literal ask* (≈trivial)
What tinnitus/tagbody actually asked: "offset the volume of all selected notes," exactly
like Alt+F1/F2 transpose. **Clone `PakettiTransposer`, write `volume_value` instead of
`note_value`** (if empty→treat as full, add delta, clamp 0–127). ~25 lines.
- ⌨️ ±1/±10 keybindings **and** a relative MIDI knob ("twist to reduce").
- ✅ Instrument-agnostic — **handles drumtracks with 35 instruments automatically** (every
  selected note's volume gets offset). Works across multiple tracks/columns at once.
- ⚠️ Destructive to the volume column (revert = offset back); per-note cap is full volume.
- **90% built. This is the one to ship first** — it IS the request.

### 2. "Lull" instrument duplicate — *Esa's idea* (reversible, knob-relative)
Duplicate the instrument, remap the selection's `instrument_value` to the duplicate, set the
duplicate's `instrument.volume` relatively (knob), revert via the existing `SetInstrument()`.
- ✅ Reversible, non-destructive to notes, "this segment is visibly different," can go up to
  +6 dB.
- 🧩 Needs the **dedup logic** Esa flagged — tag the dupe (e.g. name `… (Lull)`), and before
  duplicating, check if the selection already points at a `(Lull)` instrument → reuse it.
- ⚠️ **Multi-instrument drumtracks are the hard case** — a selection using N instruments
  would need N duplicates + remaps. For drums, approach 1 or 3 is cleaner.
- Building blocks exist; this is the most *new* logic of the three.

### 3. Track-volume automation over the segment — *closest to IT channel-volume; best for drums*
Write automation points on `track.postfx_volume` for the selected line-range; revert =
delete those points. Paketti already has heavy automation-writing infrastructure
(`PakettiAutomation`, the automation curves).
- ✅ **One move lulls the ENTIRE track output (all 35 instruments) for the segment** —
  directly answers Esa's drumtrack case.
- ✅ Fully reversible (delete automation), knob-friendly, touches no notes/instruments.
- ⚠️ Affects the whole track, not a sub-set of columns.

---

## Esa's "does Renoise have a global track channel volume like ImpulseTracker?"
**Yes — `track.prefx_volume` / `postfx_volume` IS the channel-volume fader**, and it's
automatable. There's no per-row "channel volume column," but you get the same result three
ways: the per-note **volume column** (approach 1), or **track-volume automation** over the
row-range (approach 3). The volume column = per-note channel volume; the track fader =
channel volume; segment-level = automation.

---

## Recommendation
- **Ship approach 1 now** (`Selection Volume Offset −/+`, keybindings + relative MIDI knob).
  It's the literal ask and nearly built (the transpose harness is the template).
- **Offer approach 3 as "Lull"** for the whole-channel / drumtrack case (track-volume
  automation over the selection) — cleanest, most reversible, handles 35-instrument tracks.
- **Approach 2 as an optional power-user mode** for single-instrument, instrument-level
  control with the dedup tagging.

### Open *design* questions (none are feasibility blockers)
1. Knob = **relative** offset (recommended, matches transpose + "twist a knob") vs absolute?
2. Approach 1: clamp/handle empty cells how? (empty → treat as full before subtracting).
3. "Lull" = single-instrument duplicate (approach 2) or whole-track automation (approach 3)?
   — drumtrack answer points at 3.
4. Should the offset also cover **panning / delay / sample-fx** columns (Esa asked)?
   `panning_value` / `delay_value` are the same shape — same code generalizes to all four.
