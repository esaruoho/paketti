# Study: "A phrase per slice, each phrase assigned a sample, all phrases keymapped"

Feasibility + design study for the two-part request:

1. **Create a phrase for each slice and assign a sample for each phrase**
2. **Automatically map every phrase on the keyboard in keymap mode**

Written 2026-07-27. Part 2 shipped the same day (`ddb2d8e6`); this document is about
what Part 1 actually requires, what Paketti already has, and what is wrong with it today.

---

## 1. Status of the two halves

### Part 2 — already done

`PakettiPhraseMapOnePerKey()` and `PakettiPhraseMapSpreadAcrossKeyboard()` in
`PakettiPhraseWorkflow.lua` do exactly this: wipe existing phrase mappings, re-insert
them strictly low-to-high (Renoise forbids overlap and keeps mappings sorted by note),
and set `phrase_playback_mode = renoise.Instrument.PHRASES_PLAY_KEYMAP`.

So Part 1 does **not** need to solve keymapping. It only needs to create the phrases;
Part 1 then chains into Part 2. That is the whole architectural point of this study —
**one composable pipeline, not one monolith.**

### Part 1 — three existing attempts, all subtly wrong

| Function | File:line | What it does | Problem |
|---|---|---|---|
| `PakettiSlicesToPhraseBank(options)` | `PakettiPhraseWorkflow.lua:8416` | one phrase per slice, 4 lines each, `note_value = i` | assumes slices start at C-0; mis-sets the sample column |
| `PakettiRenderCreatePhrasesFromSlices()` | `PakettiPhraseWorkflow.lua:8031` | same, phrase length divided from pattern length | same two problems |
| `PakettiAutoSliceAndPhraseCreate(options)` | `PakettiPhraseWorkflow.lua:8471` | beat-detect → `slicerough()` → the above | inherits both |

Neither maps the phrases to keys, and neither sets `phrase_playback_mode`. So today the
user still has to do the whole keyboard-mapping job by hand — which is precisely the
complaint.

---

## 2. The key API fact everyone gets wrong

From the Renoise phrase API, `renoise.InstrumentPhrase`:

> General remarks: Phrases do use `renoise.PatternLine` objects just like the pattern
> tracks do. **When the instrument column is enabled and used, not instruments, but
> samples are addressed/triggered in phrases.**

Inside a phrase the instrument column is a **sample selector**, not an instrument
selector. A phrase always belongs to one instrument; there is no way for it to play a
different instrument, so Renoise reuses that column to pick a sample.

**This is the mechanism the request is asking for.** "Assign a sample for each phrase"
= set `note_column.instrument_value = sample_index - 1` (0-based) in that phrase.

### The bug this reveals in existing code

`instrument_value` is currently set to `song.selected_instrument_index - 1` in at least
a dozen phrase-writing sites:

```
PakettiPhraseWorkflow.lua:3478, 3543, 3581, 3587, 8053, 8076, 8461  (and more)
PakettiPhraseGenerator.lua:1317, 1322
```

with a comment at `PakettiPhraseGenerator.lua:1317` spelling out the misconception
verbatim: *"-1 because Renoise uses 0-based indexing for instrument_value"*. The
indexing is right; the **meaning** is wrong. Writing instrument index 8 into a phrase
note column does not say "play instrument 8", it says "play **sample** 9 of my own
instrument".

Practical impact today is probably mild — these phrases leave
`instrument_column_visible = false`, and on a one-sample instrument sample 9 does not
exist, so Renoise most likely falls back to the keymap. But it is wrong in principle
and it becomes actively wrong the moment the instrument has several samples, which is
exactly the sliced-instrument case this feature targets.

**Needs live confirmation:** whether a hidden instrument column in a phrase is still
honoured during playback (in pattern tracks, hidden column data *does* play). If it is
honoured, those existing sites are live bugs on any multi-sample instrument, and this
study's fix list grows. Verify before touching them.

---

## 3. Three ways to make a phrase play one specific slice

### Option A — note-based, via the slice keymap (what the existing code attempts)

A sliced instrument auto-keymaps each slice to one key. So a phrase can just play the
note that triggers the slice.

The existing code hardcodes `note_value = slice_index`, i.e. it assumes slice 1 is at
C-0. **Do not assume this.** `PakettiOldschoolSlicePitch.lua` already established the
correct, robust way — read the trigger note off the mapping:

```lua
local slice_note = instrument:sample_mapping(1, sample_index).note_range[1]
```

(`PakettiOldschoolSlicePitch.lua:1350, 1461, 1683` — `1` is `LAYER_NOTE_ON`.)
This survives any keymap layout, transposed slice sets, and Renoise version differences.

- **Pros:** no sample column needed; matches how a human would play the instrument.
- **Cons:** depends on the keymap staying put. If the user later re-keymaps or the
  instrument is un-sliced, every phrase points at the wrong sound.

### Option B — sample column (what the request literally asks for)

```lua
phrase.instrument_column_visible = true
local col = phrase:line(1):note_column(1)
col.note_value = base_note                    -- pitch you want it played at
col.instrument_value = sample_index - 1       -- THE slice, addressed directly
```

- **Pros:** explicit, keymap-independent, visible in the phrase editor, and is the
  literal reading of "assign a sample for each phrase". Survives re-keymapping.
- **Cons:** needs a sensible `note_value` (use the slice's own
  `sample_mapping.base_note` so it plays at its natural pitch).

### Option C — sample offset, no slices at all

Play the full sample with a `0Sxx` sample-offset command in the effect column, so each
phrase enters the same sample at a different point. `PakettiRearrangeTrackFromSlices()`
already uses this method for tracks.

- **Pros:** works on unsliced samples; no slice count limit.
- **Cons:** 256-step offset resolution only; not what "assign a sample" asks for.
  Out of scope here, worth keeping as a separate command.

### Recommendation

**Do both A and B, in that order, in the same note column.** They are not exclusive:
set `note_value` from the slice's mapping (A) *and* `instrument_value` to the slice's
sample index (B). The result plays correctly whether or not Renoise consults the
instrument column, is self-documenting in the phrase editor, and degrades gracefully.
Cost is two extra lines.

---

## 4. Proposed implementation

One new function, composing with the keymapper shipped in `ddb2d8e6`.

```lua
-- Create one phrase per slice, each phrase addressing its own slice sample,
-- then optionally lay every phrase out across the keyboard in keymap mode.
function PakettiPhrasePerSlice(options)
  options = options or {}
  local include_full_sample = options.include_full_sample ~= false  -- default true
  local phrase_length       = options.phrase_length or 16
  local keymap_after        = options.keymap_after ~= false         -- default true

  local instrument = <selected instrument, guarded>

  -- Count slices by SAMPLE COUNT, never by slice_markers arithmetic:
  -- samples[1] is the full sample, samples[2..n] are the slices. This sidesteps the
  -- "slice_count vs slice_count+1 playable regions" confusion in the existing code.
  local first_index = include_full_sample and 1 or 2
  if #instrument.samples < 2 then <"no slices in this instrument"> end

  for sample_index = first_index, #instrument.samples do
    local phrase = instrument:insert_phrase_at(#instrument.phrases + 1)
    phrase.number_of_lines = phrase_length
    phrase.lpb  = renoise.song().transport.lpb
    phrase.name = (sample_index == 1) and "Full Sample"
                  or string.format("Slice %02d", sample_index - 1)
    phrase.looping = false            -- one-shot: a key press should fire it once
    phrase.instrument_column_visible = true

    local mapping = instrument:sample_mapping(1, sample_index)
    local col = phrase:line(1):note_column(1)
    col.note_value       = mapping.base_note        -- natural pitch (Option A)
    col.instrument_value = sample_index - 1         -- THE slice (Option B)
  end

  if keymap_after then
    PakettiPhraseMapOnePerKey()                     -- reuse, do not reimplement
  end
end
```

### Why these defaults

- `include_full_sample = true` — matches the existing `PakettiSlicesToPhraseBank`
  behaviour ("Full Sample" first), and it is useful to have the unsliced original on
  the first key.
- `phrase_length = 16` — a slice needs room to ring out and to have beats added around
  it. The existing code's 4 lines is too tight to be musically useful, and
  `PakettiRenderCreatePhrasesFromSlices`'s `pattern_length / slice_count` produces
  1-line phrases on a 32-slice break. Configurable.
- `looping = false` — "c-4 shoots phrase1" is a one-shot gesture.
- `keymap_after = true` — the whole point. This is the pipeline.

### Registration surface

Following the pattern of the phrase keymapper already shipped:

- Keybinding `Global:Paketti:Create Phrase Per Slice` (3 colon-parts — house rule 1)
- Keybinding `Global:Paketti:Create Phrase Per Slice + Keymap`
- MIDI mappings with the same names under `Paketti:`
- Menus under `Main Menu:Tools:Paketti:Phrases:`, plus `Sample Editor:Paketti:`
  (where you are when you slice) and `Instrument Box:Paketti:`
- Run `python3 .spine/check.py` before committing — house rule 9.

### What to do about the three existing functions

Do **not** add a fourth parallel implementation. Concretely:

1. Fix the slice-note assumption in `PakettiSlicesToPhraseBank` and
   `PakettiRenderCreatePhrasesFromSlices` to read `sample_mapping(1, n).note_range[1]`.
2. Fix `instrument_value` in both to be the sample index, not the instrument index.
3. Have both delegate to `PakettiPhrasePerSlice` with the options that reproduce their
   current shape, so there is one code path.
4. Leave `PakettiAutoSliceAndPhraseCreate`'s beat-detect → `slicerough()` front end
   alone; it just calls into the fixed path.

---

## 5. Limits and edge cases

| Constraint | Value | Consequence |
|---|---|---|
| Phrase mappings per instrument | max 119 single-key (documented) | a 128-slice break cannot be fully keymapped; map the first 119 and say so |
| Keyboard range | notes 0-119, C-4 = 48 | `MapPhrasesOnePerKey` already slides the block down to fit |
| Phrase lines | `MAX_NUMBER_OF_LINES = 512` | not a practical limit here |
| Sliced instrument mappings | `sample_mapping.read_only == true` | **read** slice mappings freely; never try to write them |
| `#samples` on a sliced instrument | 1 full + N slices | count from `#instrument.samples`, not `#slice_markers` |
| Phrase count cap per instrument | **unverified** | check before claiming a slice ceiling |

Renoise makes slice sample mappings read-only, which is fine — this feature only ever
*reads* them (to learn each slice's trigger note and base note) and writes *phrase*
mappings, which are a separate, writable thing.

---

## 6. Open questions needing live verification

Cannot be answered from the API docs alone; all need a real sliced instrument in front
of Renoise. Listed in the order they should be checked:

1. Is a **hidden** phrase instrument column still honoured at playback? Determines
   whether the dozen existing `instrument_value` sites are live bugs or merely dead
   wrong. (Test: one phrase, two samples, hidden column, listen.)
2. Does `instrument_value = n - 1` in a phrase actually select sample `n`, and what
   happens when `n` exceeds the sample count — silence, fallback to keymap, or error?
3. Is there a phrase-count cap per instrument, and what does `insert_phrase_at` do at
   the ceiling — return nil, or throw?
4. On a sliced instrument, does `sample_mapping(1, 1)` (the full sample) have a usable
   `base_note`, or is the full sample unmapped once slices exist?
5. Does `delete_phrase_mapping_at()` ever remove the phrase itself? Already guarded
   defensively in the shipped keymapper, but confirming it would let the guard go.

Questions 1 and 2 decide the whole Option A / Option B recommendation above, so check
those first. The recommendation to do **both** is deliberately chosen to be correct
either way, so implementation is not blocked on the answers.

---

## 7. Effort estimate

- `PakettiPhrasePerSlice` + registrations: **~90 lines**, reusing the shipped keymapper.
- Fixing and de-duplicating the three existing functions: **~40 lines net removal**.
- The `instrument_value` sweep across `PakettiPhraseWorkflow.lua` and
  `PakettiPhraseGenerator.lua`: ~12 sites, mechanical, but **gated on question 1**.

The feature itself is small. The valuable part of this study is that the sample-column
semantics were being got wrong repeatedly, and that Part 2 already exists so Part 1
should compose with it rather than grow its own keymapping code.
