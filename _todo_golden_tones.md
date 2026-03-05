# Golden Tones / Microtonal Tools for Paketti

## Source
DavidQuantumGravity (Discord), 2026-03-05

## Status: ALL PHASES COMPLETE

Commits: `138658c`, `2aac153`

---

## What Was Built

### Tuning Presets (27 total)
- 12-TET (Standard/Reset)
- **Golden Pythagorean (13-note)** — phi-stacked
- **36-EDO** — bridge between 12-TET and golden
- **Solfeggio** — 9 sacred frequencies as ratios
- **Colundi** — Aleksi Perala's frequency system
- Pythagorean (pure fifths), Just Intonation (5-limit)
- Werckmeister III, Kirnberger III, Quarter-Comma Meantone
- **Pi-Harmonic, Euler (e)-Harmonic, Silver Ratio, Sqrt(2)-Harmonic** — sacred geometry tunings
- N-EDO: 5, 7, 10, 15, 17, 19, 22, 24, 31, 41, 48, 53, 72

### Wavetable Generators (5)
- Golden Shimmer — 12 positions, phi-detuned golden partials
- Golden Beating — morph from unison to golden sixth
- Spectral Morph — JI triad to Golden triad across 12 positions
- Tuning History — Pythagorean through Golden as 12-position wavetable
- Sacred Geometry — 12 irrational constants as harmonic generators (phi, pi, e, sqrt2, silver, sqrt3, sqrt5, phi^2, ln2, phi/pi, e/phi, pi*phi)

### Instrument Generators (3)
- Golden Drone Pad — 7 drones with golden partials + amplitude modulation, 4sec, looped
- Golden Binaural Beats — 12 stereo notes with phi-ratio binaural beating (meditation)
- Full Colundi (128 freq) — all 128 Colundi frequencies across audible spectrum

### Composition Tools (4)
- Golden Chord Library — 6 chord types (Major, Minor, Power, Sixth, Sus, Stacked 3rds), insert dialog
- Golden Ratio Tempo/Rhythm — BPM*phi, BPM/phi, golden pattern lengths, golden delay values
- Golden Arpeggio Phrases — 6 phrase presets using golden scale degrees
- Tuning Comparison A/B — duplicate instrument, apply two tunings, switch to compare

### PCMWriter Waveforms (9 new)
- golden_sine, golden_additive, golden_fm, golden_ring, solfeggio_chord
- pi_harmonic, e_harmonic, silver_ratio, sqrt2_tritone

### Scala Support
- Load .scl files via native API
- Export any preset as .scl

### Registration
- Menu entries in Main Menu + Instrument Box (20 entries each)
- 12 keybindings (Global:Paketti)
- 8 MIDI mappings

---

## Remaining Ideas (not critical, nice-to-have)

### MTS-ESP Master Mode
- Broadcast Paketti's tuning to external plugins
- Needs investigation: does Renoise expose MTS-ESP master API?

### Export Tuned Samples for Hardware
- Bake microtonal tuning into WAV/PTI for Polyend, Digitakt, Octatrack
- Hardware has no custom tuning, so bake it into the samples
- Integrate with existing PakettiPolyendSuite, PakettiOTExport

### Canvas Visualization
- 36-TET interval circle (gold = golden, blue = 12-TET)
- Overtone series comparison display
- Click to audition intervals

### Tuning-Aware Note Input Mode
- Show scale degree names instead of standard note names when microtonal tuning is active
- Integrate with PakettiTuningDisplay auto-input mechanism

### Bundled Scala Files
- Pre-generate .scl files for all built-in tunings
- Ship in tunings/ folder alongside existing 19edo.txt

## References
- Dan Winter — golden ratio brainwave research
- Pythagorean comma and tuning theory
- Colundi Sequence — Aleksi Perala / Ovuca
- Solfeggio frequencies — ancient/sacred tuning
- 36-TET microtonal theory
- Renoise API: renoise.InstrumentTriggerOptions
