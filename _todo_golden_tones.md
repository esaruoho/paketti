# Golden Tones / Microtonal Tools for Paketti

## Source
DavidQuantumGravity (Discord), 2026-03-05

## The Idea

Music theory based on the golden ratio (phi = (1+sqrt(5))/2 ≈ 1.618):

- **Pythagorean scale** uses the most *rational* intervals (2/1, 3/2)
- **Golden ratio** is the most *irrational* number — in theory should sound "worst"
- But Dan Winter's research suggests golden-ratio brainwaves activate bliss states
- Question: could irrational harmony induce meditative/bliss states?

### Golden Pythagorean Scale (13 notes)
- Built from 2/1 (octave) and phi (the "golden sixth")
- Inverting phi about the octave gives the "golden third"
- phi^13 ≈ power of 2 (similar to how (3/2)^12 ≈ power of 2 in standard tuning)
- Result: a 13-note scale

### 36-TET as Practical Framework
- The golden third ≈ 2/3 major third + 1/3 minor third
- This approximation fits well in 36 equal temperament (36 notes per octave)
- 36-TET contains three sets of 12-TET *plus* the golden Pythagorean approximation
- Not just weird microtonal music — extends Western harmony with mathematical constraints

### Golden Triads
- Golden major chord = stacked golden major thirds (sounds better than diminished)
- Golden fifth is more "angelic" than a tritone
- Overtones are maximally chaotic → best used as **passing chords**
- Standard major chords = most consonant overtones → most stable

### Reharmonization Algorithm
- Take known Western chord progressions with stepwise motion
- Find golden triads that sit *between* consecutive chords in 36-TET
- Insert golden triads as passing chords
- Provides a few exploration possibilities without being overwhelming

---

## KEY DISCOVERY: Renoise Has Native Custom Tuning Support!

`renoise.InstrumentTriggerOptions.tuning` accepts an array of pitch ratios for **any number of notes per octave**.

```lua
instrument.trigger_options.tuning = { ... ratios ... }
instrument.trigger_options.tuning_name = "My Tuning"
instrument.trigger_options:load_tuning("file.scl")  -- Scala files
```

Also supports **MTS-ESP** (`mts_esp_tuning = true`).

---

## Build Plan

### Phase 1: Tuning Presets [STATUS: building]
Apply tuning systems to selected instrument via dialog with popup selector:
- **Golden Pythagorean** (13-note) — phi-stacked ratios reduced to one octave
- **36-TET** — 36 equal divisions, bridge between 12-TET and golden
- **Solfeggio** — 9 sacred frequencies as ratios (174/174, 285/174, ..., 963/174)
- **Colundi** — Aleksi Perala's 128-frequency system as ratios
- **N-EDO** — arbitrary equal divisions (user picks N: 5, 7, 10, 12, 15, 17, 19, 22, 24, 31, 36, 41, 48, 53, 72)
- **Werckmeister III** — historical well-temperament (already in API docs as example)
- **Pythagorean** — pure 3/2 fifths stacked
- **Just Intonation** — pure ratios (small whole number fractions)
- **Reset to 12-TET** — empty table

### Phase 2: Golden Waveforms in PCMWriter
Add new waveform types to PCMWriter's generator:
- **Golden sine** — fundamental + partials at phi-ratio frequencies
- **Golden additive** — additive synthesis with phi-spaced partials (1, phi, phi^2, phi^3...)
- **Phi-FM** — FM synthesis where modulator = phi * carrier

### Phase 3: Shimmering Wavetable Generator
Create wavetable instruments with detuned positions:
- Same waveform at N positions, each detuned by golden-ratio cents
- When cycling through positions → beating/shimmering effect
- Also: golden harmonic wavetable (each position adds more phi-partials)
- Uses existing PCMWriter wavetable export (12 positions max)

### Phase 4: Scala File Bundling
- Generate .scl files for all built-in tunings
- Ship in Paketti's bundle (tunings/ folder)
- "Export Current Tuning as Scala" button in dialog

### Phase 5: Golden Chord Library + Pattern Tools
- Golden triads (root + golden third + golden fifth)
- Map to 36-TET keyboard positions
- Insert chords into pattern editor
- Audition from dialog

### Phase 6: Reharmonization Tool
- Analyze chord progression in pattern
- Find golden triads between consecutive chords in 36-TET
- Suggest and insert passing chords

### Phase 7: Canvas Visualization
- 36-TET interval circle (gold = golden scale, blue = 12-TET)
- Click to audition
- Overtone comparison display

---

## References
- Dan Winter — golden ratio brainwave research
- Pythagorean comma and tuning theory
- Colundi Sequence — Aleksi Perala / Ovuca
- Solfeggio frequencies — ancient/sacred tuning
- 36-TET microtonal theory
- Renoise API: renoise.InstrumentTriggerOptions
