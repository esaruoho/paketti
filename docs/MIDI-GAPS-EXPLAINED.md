# Paketti — the MIDI gaps, explained and prioritized

*Not every "gap" deserves a MIDI mapping. A dialog or a console-dump has no business on
a knob; a live note-generator absolutely does. This sorts the requested groups by whether
mapping them actually helps a hardware/controller player.*

---

## 🟢 HIGH VALUE — performance actions a controller player genuinely wants

### Write Notes — 29 features, NONE MIDI-mappable (the standout gap)
These **generate notes into the pattern**: Ascending / Descending / Random, each with
Flood, Pro, EditStep, and SubColumn-aware variants. This is *live tracker performance* —
hitting a pad to flood a column with an ascending run, or a random EditStep pattern, is
exactly what hardware is for. 29 compositional actions reachable only by key/menu. **Map
the ~6 roots** (Ascending / Descending / Random × Flood / Pro), and the controller becomes
a note-generation instrument. Biggest single win in the whole tool.

### BPM&LPB — 9 features
Live tempo/resolution moves: **Double LPB, Halve LPB, Double Double LPB, Halve Halve LPB,
Halve BPM & Multiply LPB, Multiply BPM & Halve LPB, Write Current BPM&LPB to Master,
Random BPM**. Doubling/halving LPB mid-take is a performance gesture (half-time/double-time
feel). These belong on buttons. High value, low effort — they're parameterless toggles.

### LFO Write — 8 features
**LFO Write to Effect Column 1** in flavours 0Dxx (delay) / 0Gxx (glide) / 0Rxx (retrig) /
0Sxx (slice/offset) / 0Uxx (slide-up) / 0Yxx (slide-down) / Amount-Only, plus **Single
Parameter Write to Automation**. These stamp an LFO-shaped pattern of effect commands into
the track — modulation-by-performance. A knob/button to drop a 0Uxx LFO sweep live is very
much a hardware gesture. Medium-high value.

### Wipe&Slice — the live ones (4 of 8)
**Double Slices, Halve Slices, Wipe Slices** (and Auto-Slice every 8 beats) are live
slice-manipulation — great on buttons for beat-juggling. *The other four* (Prepare Sample
for Slicing, Whole Hog complete-workflow, Select Beat Range "Verification") are setup/test
steps — leave them on the menu.

### Automation Curves — 10 features
Shape-stamping into an automation selection: **Bottom→Center (Exp), Center→Top (Exp),
Selection Up→Center (Linear), Set to Center**, etc. A button that draws a curve shape onto
the current selection speeds up automation work. Medium value — most useful if you do a lot
of automation drawing.

---

## 🟡 MEDIUM — situationally useful, depends on your workflow

### Octatrack — 20 features (mostly file I/O)
**Export to Octatrack (.WAV+.OT) / (.ot only), Export OctaCycle, Generate .ot Drumkit
(Force Mono / Play to End), Import Octatrack (.ot), Batch Convert RX2→OT / .ot→CUE**, and
several dialogs. These are **file export/import**, not real-time. A one-button "Export to
Octatrack" suits a hardware-centric Octatrack workflow; the Debug/Batch/Import-dialog ones
don't need a knob. Map the 2–3 Export verbs if you live in that workflow; skip the rest.

### 03 Pitch (modulation matrix) — 8 features
These **insert a modulation device into the Pitch slot**: AHDSR, Envelope, Fader, LFO,
Key Tracking, Velocity Tracking, Operand, Stepper. It's sound-design setup, not performance
— but a fast "drop an LFO on pitch" button helps patch-building. Note: **the same 8 repeat
for every mod slot** (04 Cutoff, 06 Drive, …), so this is a pattern decision, not 8 one-offs.
Medium value for sound designers, low for performers.

### Steppers — the edit one (1 of 7)
**Modify PitchStep Steps (Minor Flurry)** is an edit action worth a button. The other six
are **"Show Selected Instrument [Cutoff/Drive/Panning/Pitch/Resonance/Volume] Stepper"** —
they just open a view. View-openers on MIDI are marginal; map them only if you want a
hardware "jump to this stepper" surface.

---

## 🔴 LOW / SKIP — these are NOT real gaps (dialogs, console dumps, pickers)

### Plugins/Devices — 17 features, but only ~1 worth mapping
Almost all are **setup/inspection**: "List Available VST Plugins (Console)", "Dump
VST/AU/Native Effects to Dialog", "Load Plugins…", "Inspect Selected Device (Console)",
"Show Plugin Details Dialog…", "Configure Plugin Slots…". You don't trigger a console dump
from a knob — these correctly stay on the menu. **The one real candidate: "Randomize
Selected Instrument Plugin Parameters"** — that's a sound-design gesture worth a button.
("Switch Plugin AutoSuspend Off" is a maybe.) So Plugins/Devices is *mostly a false gap*.

---

## The honest summary

Of the groups you asked about, the gaps that are **worth filling**:
- **Write Notes (~6 roots)** — the big one; turns a controller into a note generator.
- **BPM&LPB (all 9)** — cheap, parameterless, performance-grade.
- **LFO Write (8)** + **Automation Curves (~10)** — modulation/automation by gesture.
- **Wipe&Slice (3: Double/Halve/Wipe Slices)** — beat-juggling.
- **Octatrack (2–3 Export verbs)** and **03 Pitch+siblings (the LFO/Stepper inserts)** — workflow-dependent.

The gaps that are **not really gaps** (leave on the menu): Plugins/Devices console/dialog
actions, the "Show … Stepper" view-openers, Octatrack debug/batch dialogs. Mapping a dialog
to MIDI just clutters the controller — the absence of MIDI there is correct, not a hole.

*(Counts/lists auto-derived from the spine — `docs/MIDI-GAPS.md` has the raw per-group
data; this file is the human prioritization on top of it.)*
