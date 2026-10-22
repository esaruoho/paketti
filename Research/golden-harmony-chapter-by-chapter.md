# Music Theory of Golden Harmony — chapter-by-chapter, vs Paketti golden tunings

**Source:** David Chester, *Music Theory of Golden Harmony*, first edition (draft), 2026 (738 pp, 45 chapters in ten parts). Read from the text layer of `~/Downloads/Music_Theory_of_Golden_Harmony.pdf`.

**Paketti ground truth:** `PakettiMicrotonalTunings.lua` (read from the git blob at HEAD, 106,997 bytes). Golden material lives in: `generate_golden_pythagorean` (l.30), `generate_n_edo` (l.57, 36-EDO preset l.622), the Lange phi scales (l.264–421), golden wavetables (l.864+), `get_golden_chords` (l.1975), `insert_golden_chord` (l.1991), golden tempo/rhythm, and golden arpeggio phrases. Companion report card: `features/golden-chord-corrections.feature`.

**How to read this file:** per chapter — **What it establishes** (David's content) and **Where Paketti is** (what we already have, what matches, what's missing). A running scorecard is at the end.

**Legend for the Paketti verdict:** ✅ have it · 🟡 partial / approximate · ❌ not built · ➖ foundational theory, no golden-specific Paketti feature expected.

---

## Front matter — the golden premise

**What it establishes.** The book's seed: φ = (1+√5)/2 ≈ 1.618 is the "most irrational" number (continued fraction all 1s; Hurwitz's √5 bound). Its best rational approximations are consecutive Fibonacci ratios — 2/1, 3/2, 5/3, 8/5, 13/8, 21/13 — i.e. the octave, fifth, major sixth, minor sixth climbing a "Fibonacci staircase" toward φ as a **sixth of 833.09 cents** ("the golden sixth"). Inverted in the octave it is 2/φ ≈ 1.236 = **366.91 cents**, "the golden third" — between a minor and major third. The whole system is tuned in **36-ET** (three notes per semitone; `^`/`v` mark a third of a semitone up/down). So φ and its Fibonacci neighbours round to the same 36-ET notes.

**Where Paketti is.** `PHI` constant (l.13) and `generate_golden_pythagorean` already stack φ into a 13-note scale; 36-EDO is a first-class preset (l.622). The golden third 2/φ = 366.91 c and golden sixth φ = 833.09 c are exactly the numbers `get_golden_chords` uses. So the *premise* is fully represented. ✅

---

## PART I — Sound and number (ch. 1–4)

Each chapter pairs standard acoustics with a boxed "Φ GOLDEN MIRROR" that threads the golden idea through. Nothing here is a Paketti *feature gap* — it's the physics the golden system rests on — but ch. 2–3 define the objects Paketti's golden **wavetable generators** are built from, so they matter for fidelity.

### Ch 1 — What a sound is ➖
**Establishes.** Frequency/pitch/amplitude; hearing is logarithmic (equal ratios = equal intervals); octave = 2:1; cents = 1200·log₂(r); 36-ET uses steps of 1/3 of a MIDI semitone (33.33 c), `^`/`v` = ±1/3 semitone. Golden mirror: φ = 833.09 c (wide minor sixth), 2/φ = 366.91 c (the golden third), grid = 36-ET.
**Where Paketti is.** All the arithmetic (`ratio_to_cents`, 33.33-c steps) is already in the module; `generate_n_edo(36)` *is* this grid. Foundational — no gap. ✅ for the primitives.

### Ch 2 — The harmonic series ➖→🟡
**Establishes.** Partials, timbre = spectrum, Fourier. **Key golden object:** the *golden spectrum* has partials at **2^m·φ^n** = 1, 1.618, 2, 2.618, 3.236, 4, 4.236… — closed under ×2 and ×φ. Fibonacci ratios (2/1,3/2,5/3,8/5,13/8,21/13…) are the harmonic-series intervals climbing toward φ but never reaching it.
**Where Paketti is.** This is exactly what `generate_golden_shimmering_wavetable` (l.864) and `generate_golden_beating_wavetable` (l.895) build — partials in φ proportions (`PHI ^ p`, l.877). 🟡 **To verify:** whether Paketti's golden wavetable partials are literally the 2^m·φ^n set David specifies, or a looser φ-power stack. Worth an exact-match check (see scorecard).

### Ch 3 — Consonance and dissonance ➖ (the thesis-critical chapter)
**Establishes.** Roughness (Plomp–Levelt/Sethares critical-band model), harmonicity/virtual pitch, harmonic entropy. **The pivotal claim — the "timbre flip":** on *harmonic* tones the golden triad measures rougher than major/minor/aug (so C major is the deepest rest); on *golden-spectrum* tones the order reverses and the golden triad is the **smoothest** chord. Golden third sits at entropy 27th percentile (between the two thirds it averages); golden fifth 733.82 c at 69th; golden sixth 833.09 c at 65th. Golden triad's instability is concentrated in its fifth.
**Where Paketti is.** Paketti has *no* roughness/entropy model and doesn't need one — but this chapter is the *reason* the golden wavetables exist: they're the "laboratory timbre" on which golden chords become consonant. **Implication for us:** the golden chord library and the golden wavetables are meant to be used *together* (play golden chords on golden-spectrum instruments). Paketti ships both but nothing *links* them or documents the pairing. 🟡 opportunity: a one-click "golden chord on a golden-spectrum instrument" path.

### Ch 4 — Intervals as ratios ➖
**Establishes.** Just intonation, prime limits (3/5/7-limit), the ratio lattice / Tonnetz, commas (syntonic 81/80, Pythagorean, etc.). Golden mirror: φ is irrational so golden intervals are **off the ratio lattice entirely**, but the golden world has its *own* commas — the **golden comma** φ¹³/2⁹ = 30.17 c (13 golden sixths vs 9 octaves), and the **8.75 c comma that 36-ET tempers out** (36 golden sixths vs 25 octaves).
**Where Paketti is.** `generate_golden_pythagorean` is literally "stack φ 13 times," so the golden comma is implicit in it. Paketti exposes the 13-note golden Pythagorean scale and 36-EDO but does **not** surface/label these commas anywhere. ➖ (theory; not a feature gap, but a possible teaching display in the tuning dialog).

**Part I verdict.** Everything foundational is already present as arithmetic/primitives. The one actionable thread: confirm the golden-spectrum wavetables use David's exact 2^m·φ^n partial set, and consider linking them to the golden chord library, since ch. 3 says the chords only become *consonant* on that timbre.

---

## PART II — Tuning: from Pythagoras to Bach (ch. 5–8)

This is the **structural heart** for Paketti, because David builds the golden system by *literal analogy* to this part: stack a generator, fold into the octave, read off well-formed scales. Chapter 5 is explicitly mirrored by ch. 23, and ch. 6 by ch. 23/36.

### Ch 5 — Pythagorean tuning 🟡 (the golden chain)
**Establishes.** Stack the fifth (3/2), fold into octaves → 7-note then 12-note scales; the chain never closes; limma (90.22 c) / apotome (113.69 c); the Pythagorean comma (23.46 c). **Golden mirror:** stack the **golden sixth φ** instead of the fifth → the *golden chain*. Chain distance 3 = a semitone (99.27 c), 9 ≈ minor third, 12 ≈ major third. 13 golden sixths overshoot 9 octaves by the **golden comma φ¹³/2⁹ = 30.17 c**. So **13 is "the golden twelve."**
**Where Paketti is.** `generate_golden_pythagorean` (l.30–54) is *exactly this*: `r = PHI^n` folded into the octave, 13 notes → "Golden Pythagorean (13-note)." ✅ The 13-note golden chain is built and shipped. 🟡 what's missing: Paketti doesn't *name/expose* the golden apotome (99.27 c), golden limma (69.10 c), or golden comma (30.17 c) anywhere — they're implicit in the scale but not surfaced.

### Ch 6 — Well-formed scales 🟡→❌ (the big gap)
**Establishes.** Three-gap theorem, Stern–Brocot tree, MOS/well-formed scales. The fifth's path gives sizes 5 (pentatonic), 7 (diatonic), 12 (chromatic), 17… **Golden mirror:** the golden sixth's Stern–Brocot path is 1/2, 2/3, 3/4, 5/7, 7/10, 9/13, 16/23, 25/36 → **well-formed golden scales have 2, 3, 4, 7, 10, 13, 23, 36 notes.** Named: **golden7 = the golden diatonic** (C C♯ vE vF ^G ^A♭ B in 36-ET, steps 3-8-3-8-3-8-3 sixth-steps); **golden13 = the golden chromatic**; golden10 = golden "decatonic"; golden4/golden5 the golden pentatonic family. golden7 has seven modes, like the diatonic.
**Where Paketti is.** ❌ **This is the clearest missing feature.** Paketti ships **golden13** (the golden Pythagorean 13-note) and **36-EDO**, but has **no golden7 (golden diatonic), golden10, or golden4/5** as named scale presets. These are the golden analog of "major scale / pentatonic" — arguably the single most musically useful golden object for a tracker user, and they're *derivable from the φ-chain Paketti already generates* (take 7 or 10 consecutive links instead of 13). **High-value, low-cost addition.**

### Ch 7 — Temperament ✅ (36-ET justified)
**Establishes.** Meantone, well temperament, equal temperament; 19/31/53-ET. **Golden mirror — the load-bearing justification:** 13-ET closes the golden chain (like 12-ET closes fifths) but its golden sixth is 2.32 c flat and it does **not** contain 12-ET. **36-ET** closes at the smaller 8.75-c "36-comma," its golden sixth (25 steps) is within 0.24 c, and because 36 = 3×12 it **contains 12-ET exactly**. *"No other small tuning does both. That is why the golden system lives in 36-ET."* Also introduces the "Well-Tempered Golden Clavier" (a tour through all 36 keys).
**Where Paketti is.** ✅ Paketti's choice of **36-EDO** as *the* golden grid (preset l.622, and `insert_golden_chord` forces 36-EDO tuning) is now fully vindicated by the book. The prior research note worried 36-EDO insertion was speculative; ch.7 confirms 36-ET is the canonically correct home. The 13-ET alternative Paketti does *not* ship — correctly, per David's own reasoning.

### Ch 8 — Circle of fifths and keys ✅(theory)
**Establishes.** Z₁₂, circle of fifths as orbit of 7, key signatures, key distance, relative/parallel. **Golden mirror (important):** in Z₃₆ the golden sixth = 25 steps, coprime to 36, so the **golden chain is a 36-tone row** visiting every pitch class. Units of Z₃₆ include golden third (11), **bronze third (13)**, golden sixth (25). **And the key identity:** the golden triad sits exactly between parallel major and minor — **Cg = (C + Cm + Caug)/3**, third = 11 sixth-steps (2/3 of the way minor→major), fifth = 22 (1/3 of the way P5→aug). Golden modal mixture C–Cg–Cm; golden Picardy.
**Where Paketti is.** ✅ **This confirms Paketti's central chord is correct.** `get_golden_chords` l.1982 "Golden Major (David, 36-EDO)" = steps **[0, 11, 22]** — precisely David's Cg = (major+minor+aug)/3. The prior research note's critique #1 (that the old "Golden Major" used φ at the top, the wrong chord) has since been **fixed** in the code. ❌ not built: the golden modal-mixture / golden-Picardy *progressions* (C–Cg–Cm etc.), the bronze third (13), silver13.

**Part II verdict.** The golden *chain* and its home tuning (36-EDO) are correctly built and now textbook-justified; the **David golden-major chord [0,11,22] is confirmed correct**. The one substantial gap is the **well-formed golden scale family (golden4/5/7/10)** — especially **golden7, the golden diatonic** — which Paketti does not expose but could generate trivially from the φ-chain it already has.

---

## PART III — Harmony (ch. 9–12)

This part defines the whole golden **chord and progression vocabulary**. Paketti has a golden *chord* library (static insertion); it has **no progression/cadence engine**, which is where almost all of this part's golden content lives.

### Ch 9 — Chords ✅(chords) / ❌(full set)
**Establishes.** Triads, inversions/voicing, seventh chords, chord space & evenness, symmetric chords. **Golden content:** golden triad Cg = C vE ^G = average of major/minor/aug = **[0,11,22]**; golden **six-four** vCg = vC ^E♭ G; golden **seventh** Cg7 = C vE ^G B = **[0,11,22,33]** (33 steps = 12-ET major seventh, exact 8/φ³ is 0.73 c sharper); the **equal-third line** Tn={0,n,2n}: diminished(9), **silver(10)**, golden(11), augmented(12), **bronze(13)**; golden/bronze are *more even* than major/minor (ε=0.471).
**Where Paketti is.** `get_golden_chords` (l.1975) ships: Golden Major [0,11,22] ✅, Golden Minor (reflected), Golden Power (just the golden fifth), Golden Sixth [0,11,22,**25**] (adds the golden sixth on top — a 6th chord, *not* the book's seventh), Golden Sus, Golden Stacked 3rds. ❌ **Missing vs the book:** the **golden seventh [0,11,22,33]**, the **silver [0,10,20]** and **bronze [0,13,26]** triads, the golden six-four voicing, the diminished [0,9,18]/augmented [0,12,24] members of the equal-third line as a labeled set. These are all trivial additions in 36-EDO steps and would complete David's chord taxonomy.

### Ch 10 — Function ❌ (golden cadences)
**Establishes.** Tonic/subdominant/dominant function, cadences. **Golden content:** each Western cadence has a golden counterpart — golden **authentic** G–vE♭T13/G–vCg/G–C (the golden six-four), golden **plagal** F–vFg/F–C ("golden plagal glow"), golden **deceptive** G–vA♭g–A♭g–Am. The leading tone rises through sixth-steps B→^B→vC→C.
**Where Paketti is.** ❌ None of these cadence progressions exist in Paketti. The golden chord library inserts *single* chords; there is no notion of a golden cadence or function.

### Ch 11 — Progressions ❌ (golden circle, ii–V–I, mixture)
**Establishes.** Circle-of-fifths progressions, pop axis, Andalusian, ii–V–I, modal mixture. **Golden content:** the **golden circle** — stepping a golden triad's root by a golden third (11 steps) walks through all 36 golden triads keeping two notes, one voice moving a semitone (the golden analog of falling fifths); golden ii–V–I (Dm–Dg–vGg/D–G–vE♭T13/G–vCg/G–C); **golden modal mixture** C–Cg–Cm; the **golden Picardy** Cm–C(^m3)–Cg–C (third climbs 9→10→11→12).
**Where Paketti is.** ❌ No progression engine at all. The golden circle, golden ii–V–I, golden modal mixture and golden Picardy are the most musically compelling golden-*harmony* features in the book and are entirely unbuilt. (The prior research note already flagged "a progression engine" as the key next step — the book now gives the exact progressions to implement.)

### Ch 12 — Tension and resolution ❌ (passing chords)
**Establishes.** Dissonance treatment, suspensions, passing chords, chromatic mediants. **Golden content:** golden **passing chords** — every chromatic-mediant pair has exactly one strict golden passing chord, with a bronze partner (C→E passes Eg; C→A♭ passes Cg; etc.). "Golden harmony is native to Romantic mediant harmony." The two-system split (strict/natural path) is previewed here.
**Where Paketti is.** ❌ Not built. This is the heart of David's "golden passing harmony" — inserting a golden chord between two Western chords — and Paketti has nothing that inserts a *connecting* golden chord between two given triads.

**Part III verdict.** Paketti has the *nouns* (golden chords, partially) but none of the *verbs* (cadences, progressions, passing-chord insertion). The chord library should gain the golden seventh and silver/bronze triads; the big prize is a **golden passing-chord / progression engine** driven by the theorems in Part VII.

---

## PART IV — Line, dialogue and time (ch. 13–17)

Melody, voice leading, counterpoint, rhythm/form, timbre/orchestration. The golden content is mostly **golden7-based melody and golden call-and-response** — forward references to Part VII ch.30.

### Ch 13 — Melody / Ch 14 — Voice leading / Ch 15 — Counterpoint ❌
**Golden content.** Melodies in **golden7** (steps 3 and 8 sixth-steps = 100 c and 266.67 c — a mix of semitones and near-thirds); golden motif transforms (diatonic inversion within golden7); golden **canon** (follower a golden third/fifth above, sounding golden triads when simultaneous — three keys sharing no note); golden **call-and-response** between a harmonic-timbre voice and a golden-spectrum voice in golden7.
**Where Paketti is.** 🟡 Paketti has **golden arpeggio phrases** (l.2209, six fixed templates) — a melodic golden feature — but they round to semitone offsets and are not golden7-scale-aware, and there's no motif-transform or canon tooling. golden7 melody needs the golden7 scale (the Part II gap) first.

### Ch 16 — Rhythm and form / Ch 17 — Timbre and orchestration 🟡
**Golden content.** Ch 17's golden mirror ties back to the **timbre flip** and golden-spectrum instruments (spectralism with golden spectra; a held golden chord beats at φ-ratio rates). Ch 16 is where **golden-ratio rhythm/tempo** would belong.
**Where Paketti is.** ✅ Paketti has a **Golden Ratio Tempo/Rhythm** feature (the section right after the chord library) and golden **wavetables** (shimmer/beating) that are exactly the golden-spectrum timbres ch.17 calls for. 🟡 Again: the wavetables and the chords aren't linked, and the φ-beating ("golden triad beats form a golden triad in rhythm," ch.3/26) isn't surfaced.

**Part IV verdict.** Paketti's golden arpeggios and golden tempo/rhythm partly cover this, and the golden wavetables are the right timbre — but nothing is golden7-aware and nothing connects timbre↔chord↔rhythm.

---

## PART V — Beyond tonality: chromaticism and the twelve tones (ch. 18–22)

Chromatic harmony, symmetry/modes of limited transposition, pitch-class set theory, twelve-tone music, modern/microtonal pioneers. The golden mirrors carry all of this into **Z₃₆ set theory and serialism** — a large, entirely theoretical frontier.

### Ch 18–21 — Chromatic harmony, symmetry, set theory, twelve-tone ❌
**Golden content.** 36-ET "whole-tone" scales (steps of 2 or 4 sixth-steps — 18-note and 9-note scales 12-ET can't play); golden scales have **no limited transposition** (36 distinct transpositions); Z₃₆ set theory (golden triad = {0,11,22}, inversionally symmetric under I₂₂); the multiplier **M₁₁** that maps the tight cluster {0,1,2} onto the golden triad {0,11,22} (the golden analog of M₇); golden **18-entry interval vector**; golden **serialism** — the golden chain itself is a **36-tone row** with all-equal intervals (0,25,14,3,28,…), the opposite extreme to the all-interval 36-row.
**Where Paketti is.** ❌ None of the Z₃₆ set-theory / serial machinery exists in Paketti, nor the 9-note (133.33 c) and 18-note 36-ET "whole-tone" scales. These are research-grade and probably low priority for a tracker, but the **M₁₁ "cluster→golden-triad" transform** and the **golden 36-tone row** are striking, concrete, easily-coded novelties if ever wanted.

### Ch 22 — Modern classical / microtonal pioneers ➖
**Golden content.** Busoni's sixth-tones = exactly 36-ET; golden spectralism; situates the golden system among Partch/Carrillo/Wyschnegradsky etc.
**Where Paketti is.** ➖ Historical context; no feature implication beyond "36-EDO is the sixth-tone grid," which Paketti already has.

**Part V verdict.** A large theoretical surface (Z₃₆ sets/rows) that Paketti doesn't touch and mostly needn't, with two cheap, eye-catching exceptions: the **M₁₁ cluster→golden transform** and the **golden 36-tone row** as a phrase/row generator.

---

## PART VI — THE GOLDEN TONAL SYSTEM (ch. 23–26) — the core

This is the heart of the book and the direct subject of Paketti's golden features. Read in full. Verdict up front: **Paketti has the two load-bearing pieces right — 36-EDO as the home tuning, and the golden triad [0,11,22] — and is missing most of the rest of the explicit system (the scale family, three of the four canonical chords, and the golden-spectrum timbre done David's way).**

### Ch 23 — The golden ratio and the golden chain ✅golden13 / ❌rest of family
**Establishes.** φ, Fibonacci, φⁿ = Fₙφ + Fₙ₋₁. The four named golden intervals: **golden sixth φ = 833.09 c = 25 steps**, **golden third 2/φ = 366.91 c = 11**, **golden fifth 4/φ² = 733.82 c = 22**, **golden seventh 8/φ³ = 1100.73 c = 33**. The golden chain (stack φ, fold); golden apotome (99.27 c = 3 steps), golden limma (69.10 c = 2), golden comma (30.17 c = 1). Well-formed golden scales: **golden4** (C vE ^G ^A♭), **golden7** (golden diatonic, C C♯ vE vF ^G ^A♭ B, steps 3-8-3-8-3-8-3), **golden13** (golden chromatic, steps 3 3 2 …, ten apotomes + three limmas), golden10, golden23, golden36. **silver13** = layer-mirror of golden13 (home chord = silver triad), *not* a chain. Every 3 consecutive chain notes = a golden triad.
**Where Paketti is.** `generate_golden_pythagorean` (l.30) builds 13 consecutive φ-chain links folded+sorted = **golden13** (up to window rotation). ✅ So Paketti's "Golden Pythagorean (13-note)" *is* David's golden chromatic scale. The Lange phi scales (Phi-7, Phi-9, Lange-36, Phi power series) are **different, non-David systems** (Christian Lange's φ-tuning) — fine to keep but they are not this book's golden system. ❌ **Missing the rest of the MOS family: golden4, golden7 (the golden diatonic — the single highest-value gap), golden10, golden23, golden36, and silver13.** All are trivially generated by taking N consecutive φ-chain links (N ∈ {4,7,10,23,36}) or by the layer-mirror.

### Ch 24 — 36-ET ✅ (Paketti's grid vindicated)
**Establishes.** 36-ET = sixth-steps (33.33 c); three 12-ET layers; **ups/downs notation** (Kite Giedraitis: ^/v prefixes); why 36 (25/36 is a convergent of log₂φ; golden sixth within 0.24 c; contains 12-ET exactly; closes the chain). 13-ET rejected (no Western intervals). Key system: **72 Western keys + 72 golden scales = 144 tonal fields** (the "Well-Tempered Golden Clavier").
**Where Paketti is.** ✅ 36-EDO is a first-class Paketti preset and the tuning `insert_golden_chord` applies. Now fully textbook-justified. ❌ Paketti does not use ups/downs (^/v) note naming anywhere — it works in raw 36-EDO step offsets. Not a defect, but adopting ^/v labels in the golden chord dialog would make inserted notes legible as David names them.

### Ch 25 — Golden chords ✅triad / ❌seventh, silver, bronze, averaging
**Establishes.** The **four canonical chords**: golden triad **Cg = [0,11,22]**, golden seventh **Cg7 = [0,11,22,33]**, silver **Cs = [0,10,20]**, bronze **CT13 = [0,13,26]**. The **averaging principle**: Cg = (major+minor+aug)/3; **silver = (major+minor+dim)/3** — so **silver, not any "golden minor," is the dark twin of golden**. Full 16-chord averaging table. The **equal-third line** T8/dim(9)/silver(10)/golden(11)/aug(12)/bronze(13). Layer theorem (golden triad = one note per layer). Chord naming: `Cg`, `Cg7`, `Cs`, `CT13`, alterations `C(v3,^5)=Cg`, slash `vCg/G`.
**Where Paketti is.** `get_golden_chords` (l.1975):
| Paketti chord | steps | vs book |
|---|---|---|
| Golden Major (David, 36-EDO) | [0,11,22] | ✅ = **Cg** exactly |
| Golden Stacked 3rds | [0,11,22] (exact ratios) | ✅ = Cg (duplicate of above, exact) |
| Golden Minor (Reflected) | [0, 1200−733.82, 1200−366.91] = [0,~14,~25] | ❌ **not a David chord**; the book's dark twin is **silver [0,10,20]** |
| Golden Power | [0,22] | 🟡 dyad (the golden fifth); fine |
| Golden Sixth | [0,11,22,25] | 🟡 adds golden **sixth** on top; book's 4-note chord is the **seventh [0,11,22,33]** |
| Golden Sus | [0, ~, 22] | 🟡 not a book chord |
❌ **Missing the golden seventh [0,11,22,33], silver [0,10,20], bronze [0,13,26]**, and the T8/dim/aug members as a labeled equal-third family. ❌ The **averaging principle** (and its 16-chord table) isn't exposed — yet it's the most intuitive way to *explain* why these chords sound the way they do, and it generates every chord mechanically. **Recommendation:** replace/augment the chord list to David's canonical set {Golden triad, Golden seventh, Silver, Bronze} + the equal-third line, and relabel "Golden Minor" → it should be **Silver**.

### Ch 26 — Consonance in the golden world 🟡 (the timbre, done differently)
**Establishes.** Roughness/entropy measurements; **golden-spectrum timbre = partials at 2^m·φ^n** (1, 1.618, 2, 2.618, 3.236, 4, 4.236, …); the **timbre flip** (golden triad is roughest-but-dim on harmonic tones, *smoothest* on golden tones); combination tones that land back on the chain; **golden beats** (a golden chord's beat rates are themselves in golden ratios — f₀φ⁻⁶ × {1, 2/φ, 4/φ²}). The golden-spectrum tone is the "laboratory" where golden chords become home.
**Where Paketti is.** 🟡 Paketti's golden **shimmer/beating wavetables** (l.864/895) are the right *idea* (the golden-spectrum timbre ch.26 requires) but use **partials at pure φ^p** (1, 1.618, 2.618, 4.236, 6.854, …), **not** David's **2^m·φ^n lattice** (which interleaves the octave multiples 2, 3.236, …). Consequence: Paketti's spectrum is self-matching under ×φ but **not under ×2**, so octaves don't fuse and the timbre-flip won't be as clean as David's. **Fix is small:** generate partials as the sorted set {2^m·φ^n} instead of {φ^p}. Also: the golden-beats result (φ-ratio beat rates) and combination-tone self-similarity are striking facts Paketti's tempo/rhythm feature could exploit, but doesn't.

**Part VI verdict.** Two pillars correct (36-EDO, golden triad). The actionable core gaps, in priority order: (1) **golden7 scale** (the golden diatonic) + the rest of the MOS family; (2) **golden seventh / silver / bronze** chords to complete David's taxonomy, and relabel "Golden Minor"→silver; (3) fix the **golden wavetable partials to 2^m·φ^n**; (4) optionally surface the **averaging principle** as the generator/explainer.

---

## PART VII — GOLDEN HARMONY IN PRACTICE (ch. 27–33)

This is David's actual *grammar* — how golden chords connect Western ones, and how golden homes move. **Paketti implements none of it.** The prior research note's "next implementation: a progression engine" is exactly this part, and the book now specifies the algorithms.

### Ch 27 — System 1: the strict path ❌
**Establishes.** Splitting the semitone into three sixth-steps; the **uniform path** (every voice moves in equal parts); the **four-path theorem** (288 strict paths through golden chords; 240 with tertian endpoints; 12 types up to transposition); the **quality theorem** (a strict golden passing chord exists between two triads exactly when they're two neo-Riemannian moves apart — same quality, a third or fifth apart); **"never twice"** (a strict path never has two golden chords in a row; the non-golden partner is **bronze** in 168 paths, **silver** in 72); worked golden six-four.
**Where Paketti is.** ❌ This is a complete **golden passing-chord engine** specification — given two Western triads, compute the golden chord(s) between them. Paketti has nothing like it. This is the single biggest *feature* the book unlocks.

### Ch 28 — System 2: the natural path ❌
**Establishes.** Uneven splits (whole steps split unevenly); the **golden escalator** (I→ii, ii→iii, IV→V, V→vi turning golden); the half-step theorem. 46 chord pairs get two golden chords under System 2.
**Where Paketti is.** ❌ Not built.

### Ch 29 — Golden cadences and progressions ❌
**Establishes.** Golden **authentic** cadence (the golden six-four G–vE♭T13/G–vCg/G–C), golden **plagal glow** (F–vFg/F–C), golden **deceptive** (G–vA♭g–A♭g–Am), **mediant gold**, the **golden staircase** and **golden Andalusian**, golden **modal mixture** (C–Cg–Cm) and golden **Picardy** (Cm–C(^m3)–Cg–C, third climbing 9→10→11→12).
**Where Paketti is.** ❌ Not built. These are concrete, nameable progressions ready to become "insert golden cadence" commands.

### Ch 30 — Golden melody and counterpoint 🟡
**Establishes.** Melody in golden7/golden13; **golden motif transforms** (diatonic inversion within golden7); golden **counterpoint** and **call-and-response** between a harmonic voice and a golden-spectrum voice.
**Where Paketti is.** 🟡 Paketti's **golden arpeggio phrases** (6 templates) are the only melodic golden feature; they aren't golden7-aware. Needs the golden7 scale first (Part II/VI gap).

### Ch 31 — The golden home ❌ (the most novel compositional idea)
**Establishes.** Treating a golden triad as *home*: **the golden circle** (step root by a golden third = walk all 36 golden triads, keeping two notes, moving one voice a semitone — golden analog of falling fifths); **breathing** (Cg→Cg7→vEg, add a note then drop the root to slide along the circle); **planing** (move a golden triad by sixth-steps); **rational visitation** (leave the golden home for a Western chord as "release," then return); the Well-Tempered Golden Clavier (tour of all 144 fields).
**Where Paketti is.** ❌ Not built. The **golden circle** (36 golden triads, two common tones each) is a striking, very implementable generator — the golden counterpart of a circle-of-fifths chord tool.

### Ch 32 — Modulation in 36-ET / Ch 33 — Chromaticism in 36-ET ❌
**Establishes.** Changing layers; **golden pivot chords** (one golden chord belongs to two worlds); keys a silver third apart share three golden pivots. Ch33: Z₃₆ structure, the **M₁₁ transform** (cluster {0,1,2}→golden triad {0,11,22}), symmetric 36-ET scales (9-note, 18-note), golden serialism, golden spectralism.
**Where Paketti is.** ❌ None of the modulation/serial machinery exists.

**Part VII verdict.** This whole part is an unbuilt opportunity. If Paketti were to grow its golden harmony, the order of payoff is: **golden passing-chord insertion (ch27 quality theorem)** → **named golden cadences (ch29)** → **the golden circle chord-walker (ch31)**.

---

## PART VIII — GOLDEN HARMONY BEYOND PASSING (ch. 34–39) ❌

**Establishes.** Ch34 modulation by golden intervals (the comma pump "thirteen steps to ^C," the golden circle as modulation engine, a map of the 36-ET keys). Ch35 golden pivot chords / golden projection of a triad (C→Cg) / neo-Riemannian through the golden lens. Ch36 **golden scales and modes** — the seven modes of golden7, the **golden decatonic** (golden10) and its modes, harmonizing golden melodies. Ch37 blending — golden planing as three-key polytonality, the golden **Neapolitan**, golden sequences (a "golden Giant Steps"), bridge scales. Ch38 hybrid scales — golden inflections of the major scale, **centroid scales**, golden colour chords. Ch39 elastic harmony — golden appoggiatura/suspension/neighbour chords, **reharmonizing a melody with golden chords**.
**Where Paketti is.** ❌ Essentially unbuilt. Two notes: (a) ch36's modes of golden7/golden10 again depend on having those scales (the Part II/VI gap); (b) Paketti's module header advertises **"reharmonization"** and **"spectral morphing"** functions — ch38–39's golden reharmonization and colour chords are the theory those features could be pointed at, if they aren't already golden-aware (worth a follow-up grep if reharmonization work is ever resumed).

**Part VIII verdict.** A large compositional surface, all downstream of the Part VI/VII primitives. Not worth building until the golden scales + passing engine exist.

---

## PART IX — MIND, HISTORY AND SPECULATION (ch. 40–41) ➖/🟡

**Establishes.** Ch40: **binaural beats & entrainment**, the golden-ratio EEG hypothesis, quasi-periodicity/KAM theory (why φ-ratio tones never fall into a common period), the "bliss conjecture," and how one would test it — explicitly labeled hypothesis, not result. Ch41: history of the evolving ear (organum → thirds → sevenths → "a next color").
**Where Paketti is.** 🟡 Paketti's module header lists **"binaural beats"** and **"drones"** as existing features — exactly the territory of ch40, and the golden-beats arithmetic from ch26 (beat rates in φ ratios) is the kind of thing a Paketti binaural/drone generator could tune to. ➖ Ch41 is pure context. No build implication beyond "the golden sixth is David's candidate 'next color.'"

**Part IX verdict.** Speculative; the only Paketti touch-point is that its existing binaural-beat/drone features could be made φ-beat-aware per ch26/ch40.

---

## PART X — MAKING IT (ch. 42–45) — David's toolchain vs Paketti/Renoise

This part is the most interesting *architectural* comparison, because it's where David's tooling (**SongMap**) and Paketti/Renoise do the **same job by different means**.

### Ch 42 — Music as text: SongMap 🟡 (direct analog to a tracker)
**Establishes.** **SongMap** is a plain-text song format (`songmap: 0.2`, `tempo`, `key: "C major"`, `tuning: 36edo`, chords, instrument assignments) compiled to audio by a fixed additive engine. **Golden notation in SongMap**: ASCII ups/downs (`^c4`, `ve8`), chord roots (`^C`, `vEb`), chords (`Cg`, `Cg7`, `Cs`, `CT13`, `C(v3,^5)`, `vCg/G`), keys (`key: vE golden13`). **Passing placeholders `~` (strict) and `~g` (natural)** — you write two chords with `~` between them and the engine fills the golden passing chord(s) via the Part VII theorems. Voiced styles.
**Where Paketti is.** 🟡 Renoise's pattern editor *is* a text-like step grid, and Paketti already writes 36-EDO note offsets into it (`insert_golden_chord`). The deep idea Paketti lacks is the **`~` passing placeholder** — "put a golden chord between these two" — which is exactly the Part VII engine surfaced as a one-token authoring gesture. A Paketti "insert golden passing chord between selected chords" command is the tracker-native version of SongMap's `~`.

### Ch 43 — Synthesis from scratch 🟡
**Establishes.** Additive synthesis; clean stable tones; **designing golden timbres** (partials at 2^m·φ^n); mixing for clarity.
**Where Paketti is.** 🟡 Paketti's golden wavetable generators *are* additive golden-timbre synthesis — the right category. The fidelity gap (φ^p vs 2^m·φ^n, see ch26) is the one concrete correction ch43 implies.

### Ch 44 — Seeing music ✅(capability match)
**Establishes.** Staff notation with ups/downs; **piano rolls in 36-ET**; circles and chord spaces; tablature and animation.
**Where Paketti is.** ✅ This is Paketti's strength: the Canvas UI system (19+ drawn interfaces, piano-roll-like views, the 36-dot circle would be a natural canvas). If golden features grow, Paketti is unusually well-equipped to *visualize* 36-ET (the golden circle, the equal-third line, the layer colours) — something SongMap does statically and Paketti could do live.

### Ch 45 — AI as a collaborator ➖
**Establishes.** Workflow; **"verifying instead of trusting"**; what a machine cannot judge. (Notably aligned with this repo's own CLAUDE.md anti-completion-framing rules.)
**Where Paketti is.** ➖ Process chapter; no feature implication.

**Part X verdict.** SongMap and Paketti are solving the same problem (author 36-ET golden music) from opposite ends — text-compiler vs live tracker. Paketti already has the grid, the tuning, and far better *visualization*; what it lacks from SongMap is the **`~` passing-chord placeholder** (= the Part VII engine) and the **canonical golden timbre**.

---

## SCORECARD — where Paketti is, against the whole book

| Golden object (David) | In book | In Paketti now | Verdict |
|---|---|---|---|
| 36-EDO as the golden grid | ch7/24 | ✅ preset + applied on chord insert | ✅ correct & now justified |
| Golden sixth/third/fifth (833/367/734 c) | ch23 | ✅ used in chord math | ✅ |
| Golden chain / golden13 (golden chromatic) | ch23 | ✅ "Golden Pythagorean (13-note)" | ✅ |
| **golden7 (the golden diatonic)** | ch23/36 | ❌ | ❌ **top gap** |
| golden4 / golden10 / golden23 / golden36 | ch23 | ❌ | ❌ |
| silver13 (layer mirror) | ch23 | ❌ | ❌ |
| **Golden triad [0,11,22]** | ch25 | ✅ "Golden Major (David, 36-EDO)" | ✅ correct |
| **Golden seventh [0,11,22,33]** | ch25 | ❌ (has [0,11,22,25] "sixth") | ❌ |
| **Silver triad [0,10,20]** (the true dark twin) | ch25 | ❌ (has invented "Golden Minor") | ❌ + mislabel |
| **Bronze triad [0,13,26]** | ch25 | ❌ | ❌ |
| Equal-third line (dim/silver/golden/aug/bronze) | ch9/25 | ❌ (triad only) | ❌ |
| Averaging principle (16-chord generator) | ch25 | ❌ | ❌ |
| Golden-spectrum timbre = 2^m·φ^n | ch2/26/43 | 🟡 wavetable uses φ^p | 🟡 fidelity fix |
| Golden beats (φ-ratio beat rates) | ch26 | ❌ (has generic binaural/drones) | 🟡 opportunity |
| Golden passing-chord engine (four-path/quality thm) | ch27–28 | ❌ | ❌ **biggest feature** |
| Golden cadences (authentic/plagal/deceptive/Picardy) | ch29 | ❌ | ❌ |
| Golden circle (36-triad walker) | ch31 | ❌ | ❌ high-value |
| Golden modulation / pivot chords | ch32/34/35 | ❌ | ❌ |
| golden7 modes / decatonic / reharmonization | ch36/38/39 | 🟡 header advertises "reharmonization" | ❌ not golden-aware |
| ups/downs (^/v) notation | ch24 | ❌ (raw step offsets) | ➖ cosmetic |
| `~` passing placeholder (author gesture) | ch42 | ❌ | ❌ |
| 36-ET visualization (piano roll, golden circle) | ch44 | ✅ Canvas system can do it | ✅ latent strength |
| Golden arpeggios / golden tempo-rhythm | ch16/30 | ✅ both exist | 🟡 not golden7/φ-beat-aware |

### Bottom line for Esa
- **What's solid and confirmed by the book:** 36-EDO is the right home tuning, and the **golden triad [0,11,22] is exactly David's Cg**. The earlier research-note worries about those two are resolved — they're correct. The "Golden Pythagorean (13-note)" scale **is** David's golden chromatic (golden13).
- **What's wrong or non-canonical and cheap to fix:** "Golden Minor (Reflected)" should be the **Silver triad [0,10,20]**; add the **golden seventh [0,11,22,33]** and **bronze [0,13,26]**; the golden wavetable should use **2^m·φ^n** partials, not φ^p.
- **What's genuinely missing (new features, in payoff order):** (1) the **golden7 scale** and the MOS family; (2) a **golden passing-chord / cadence engine** (ch27/29 — the thing SongMap exposes as `~`); (3) the **golden circle** chord-walker (ch31).
- **Where Paketti already beats SongMap:** live **visualization** (Canvas) and being a real tracker. The golden system could be shown live (36-dot circle, layer colours, equal-third line) in a way the book can only draw statically.

