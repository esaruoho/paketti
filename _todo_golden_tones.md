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

## Build Plan — Status

### Phase 1: Tuning Presets [DONE — commit 138658c]
23 tuning presets in dialog with scale info display. Apply to selected instrument or all instruments.
Presets: Golden Pythagorean (13-note), 36-EDO, Solfeggio, Colundi, Pythagorean, Just Intonation, Werckmeister III, Kirnberger III, Quarter-Comma Meantone, 13 N-EDO variants (5–72), Reset to 12-TET.
Menu entries in Main Menu + Instrument Box. Keybindings + MIDI mappings for quick-apply.

### Phase 2: Golden Waveforms in PCMWriter [DONE — commit 138658c]
5 new waveforms: golden_sine, golden_additive, golden_fm, golden_ring, solfeggio_chord.
All available in PCMWriter waveform popup. Shape parameter controls partial count / mod depth.

### Phase 3: Shimmering Wavetable Generator [DONE — commit 138658c]
- Golden Shimmer Wavetable: 12 positions, phi-detuned golden partials
- Golden Beating Wavetable: 12 positions, morph from unison to golden sixth
Menu entries + dialog buttons.

### Phase 4: Scala File Export [DONE — commit 138658c]
"Export as Scala (.scl)..." button in dialog. Generates proper Scala format with cent values.
(Bundled .scl files in tunings/ folder: not yet done — could pre-generate on first run)

### Phase 5: Golden Chord Library + Pattern Tools [TODO]
- Golden triads (root + golden third + golden fifth)
- Map to 36-TET keyboard positions
- Insert chords into pattern editor
- Audition from dialog

### Phase 6: Reharmonization Tool [TODO]
- Analyze chord progression in pattern
- Find golden triads between consecutive chords in 36-TET
- Suggest and insert passing chords

### Phase 7: Canvas Visualization [TODO]
- 36-TET interval circle (gold = golden scale, blue = 12-TET)
- Click to audition
- Overtone comparison display

---

## Future Ideas / Theories

### Drone Generator
- Generate a multi-sample instrument where each sample is a long drone at a specific golden scale degree
- Layer 2-3 golden interval drones → instant meditation pad
- Could use PCMWriter's golden_additive waveform as the source, rendered at different lengths (1-10 seconds)
- Add slow LFO modulation on volume/filter for organic movement

### Binaural Beat Integration
- Dan Winter's research: golden ratio brainwaves → bliss
- Generate stereo samples where left/right channels differ by golden-ratio Hz
- E.g., left = 200 Hz, right = 200 * phi = 323.6 Hz → binaural beat at golden interval
- Could create a "Golden Binaural" instrument with notes across the spectrum
- Combine with Renoise's stereo panning for spatial effect

### Phrase-Based Microtonal Arpeggios
- Generate instrument phrases that arpeggiate through golden scale degrees
- Since tuning is per-instrument, phrases play in the correct tuning automatically
- Create phrase presets: golden triad arpeggio, golden scale run, golden pentatonic
- Integrate with Paketti's existing PakettiArpeggiator.lua

### Spectral Morphing Between Tuning Systems
- Wavetable where position 1 = Just Intonation chord, position 12 = Golden chord
- Smoothly morph between consonance and "irrational beauty"
- Could also morph: Pythagorean → Werckmeister → 12-TET → Golden (history of tuning as a wavetable!)

### 36-TET Pattern Editor Helper
- When 36-TET tuning is active, show a reference overlay or status bar hint
- Map: which Renoise keys correspond to which 36-TET degrees
- Since Renoise keyboard = 12 notes/octave, 36-TET needs 3 octaves of keyboard = 1 octave of pitch
- Helper could color-code: standard 12-TET notes vs golden-only notes vs shared

### MTS-ESP Master Mode
- Renoise currently supports MTS-ESP *client* mode (receive tuning from external)
- Could we make Paketti broadcast tuning as MTS-ESP *master*?
- This would let Renoise control tuning of external synth plugins in other DAWs
- Investigate: does Renoise expose MTS-ESP master API, or only client?

### Golden Ratio Tempo / Rhythm
- Apply phi not just to pitch but to time
- Golden-ratio tempo relationships: e.g., polyrhythm where one layer is at BPM and another at BPM * phi
- LPB manipulation: set different LPB values that relate by phi
- Pattern length in phi ratio: 64 lines vs 39 lines (64/phi ≈ 39.5) playing simultaneously
- Delay column values at golden-ratio subdivisions of a beat

### Tuning Comparison A/B
- Play the same pattern with two different tunings side by side
- Duplicate instrument, apply tuning A to one and tuning B to the other
- Quick-switch button: "Compare: Golden vs Just" or "Compare: 36-EDO vs 12-TET"
- Helps users hear the difference

### Overtone Series Visualization (Canvas)
- Given a root note and tuning system, draw the first 16 overtones
- Show which overtones align with scale degrees (consonance) vs miss (dissonance)
- Compare: standard harmonic series vs golden partials
- Interactive: click an overtone to hear it

### Colundi Deep Integration
- The Colundi sequence has 128 frequencies spanning 11 octaves
- Map ALL 128 frequencies to a multi-sample instrument (one per keyzone)
- Each sample is a sine wave at the exact Colundi frequency
- Full keyboard = full Colundi sequence, playable
- Could also generate Colundi-tuned versions of AKWF waveforms

### Export Tuned Samples for Hardware
- Render tuned single-cycle waveforms as WAV files at exact microtonal pitches
- Export sets for: Polyend Tracker (PTI with tuning baked in), Digitakt, Octatrack
- Hardware samplers don't have custom tuning → bake the tuning into the samples themselves
- Integrate with existing Paketti export code (PakettiPolyendSuite, PakettiDigitakt, PakettiOTExport)

### Sacred Geometry Waveforms
- Waveforms derived from sacred geometry ratios (not just phi)
- Pi-harmonic: partials at pi, pi^2, pi^3...
- e-harmonic: partials at e, e^2, e^3...
- sqrt(2)-harmonic: the tritone ratio as a generator
- Silver ratio ((1+sqrt(2))/1 ≈ 2.414) — "silver Pythagorean scale"
- Compare: how do different irrational generators sound?

### Tuning-Aware Note Input Mode
- When a microtonal tuning is active, show the correct scale degree name instead of standard note names
- E.g., in Golden Pythagorean: instead of C-4, show "G.Pyth 0" or "φ0"
- Could use PakettiTuningDisplay.lua's auto-input mechanism adapted for the new system
- Write tuning degree info to sample effect column for visual reference

---

## References
- Dan Winter — golden ratio brainwave research
- Pythagorean comma and tuning theory
- Colundi Sequence — Aleksi Perala / Ovuca
- Solfeggio frequencies — ancient/sacred tuning
- 36-TET microtonal theory
- Renoise API: renoise.InstrumentTriggerOptions
- Scala tuning file format: https://www.huygens-fokker.org/scala/scl_format.html
