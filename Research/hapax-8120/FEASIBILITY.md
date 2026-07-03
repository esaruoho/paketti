# Squarp Hapax → Groovebox 8120 — Feasibility Study

**Date:** 2026-07-03
**Question:** Can we give the Hapax the same 8120 controller integration that the APC Key 25, LPD8, and Akai MidiMix have — pads trigger/toggle steps AND the 8120 lights the controller's steps back?
**Source:** Squarp Hapax official manual (159 pp, hapaxOS), read page-by-page.

---

## Verdict

| # | Capability the APC/LPD8/MidiMix integration needs | Hapax |
|---|---|---|
| **A. READ pad presses** on the computer | **YES** — pads send notes out through the active track's USB DEVICE output |
| **B. WRITE LED feedback** (light the steps from Renoise) | **NO** — undocumented; no SysEx exists in the entire manual, no note-on→LED listener |
| **C. READ encoders / transport** | **PARTIAL** — 8 encoders assignable to CCs (yes); transport only as MIDI clock/start-stop, not per-button |

**Full parity is NOT feasible.** The one feature that *defines* the APC/LPD8/MidiMix integrations — the host painting step state back onto the controller's LEDs — has no documented counterpart on the Hapax. The Hapax is a **sequencer**, not a control surface: hapaxOS owns the pad lighting entirely.

**A read-only "Hapax plays the 8120" path IS feasible** (pad notes in + 8 encoder CCs in + clock sync), but that is a fundamentally different, lesser thing than the two-way grid.

---

## Why B fails (the make-or-break)

Every 8120 controller integration is the same shape (in `PakettiEightOneTwenty.lua`):

1. name-match the MIDI in/out ports
2. a `note ↔ step` map
3. `set_led(step, on)` → `midi_out:send({0x90, note, velocity})` — **velocity sets the pad color**
4. `on_midi(msg)` → incoming pad Note On toggles that step
5. paging (16 physical pads windowed over 32 steps)

Steps 3 is the load-bearing assumption: **the controller lights its pads when it receives a Note On** (the Akai/Novation convention). The APC (velocity = red/green/yellow), the LPD8 (RGB), and the MidiMix (mute/rec-arm LEDs) all obey it.

The Hapax does **not** document any such behavior:

- **Zero** occurrences of "SysEx" / "System Exclusive" in 159 pages.
- Every LED/color reference is internal firmware state — active-track white pad (p11/p14), mute/solo highlighting, scheduled-pattern blink, the `PALETTE` HSL RGB colors set *on the device* with encoders (p136, p142–143), `LED BRIGHTNESS`, `SCREENSAVER (NO PADS)` (p140–141).
- No "note-on → light pad X color Y" listener anywhere.

So there is nothing to send. Per the docs, the only way to change what a Hapax pad shows is to change the Hapax's own internal state, on the device.

## What IS there (the read path)

- **USB-MIDI:** dedicated USB DEVICE port ("usually a computer", p27–28); appears as **16 in + 16 out virtual cables** (p124, §10.3). Exact CoreMIDI port name strings are **not documented** — empirical.
- **Pads out:** in Live mode the pads send notes out the track's output port, settable to USB DEVICE (p11, §1.4; p29, §2.1). But it's musical-keyboard behavior (scale/octave/layout/track dependent), **not** a fixed pad→note grid map like an APC.
- **Encoders:** the **Assign** submode (`2ND + fill`) remaps the 8 encoders to any MIDI message — "Perfect for using Hapax as a midi controller" (p25, §1.22). Only 8 (vs the MidiMix's ~24).
- **Clock:** sync in and out over USB (p130–132). Note Squarp recommends CV/audio sync, not USB MIDI clock, for tightest DAW lock (p148–149).

---

## Recommendation

1. **Do not promise the "light up the steps" feature.** The manual says it can't be done, and there's no SysEx to reverse-engineer. Setting that expectation now avoids disappointment.
2. **Run the empirical probe on Josh's hardware anyway** — it's the only way to be 100% sure there's no *undocumented* LED listener, and it simultaneously harvests the two things we'd need for the read path: (a) the real CoreMIDI port names, (b) the actual pad/encoder note+CC map.
3. **If (and only if) the probe shows nothing lights:** the realistic Hapax integration is a **one-way "Hapax → 8120" mode** — pads/encoders drive 8120 step toggles + row focus, no LED return. Worth doing only if Josh actually wants to *play* the 8120 from the Hapax; it will never "glow" like the APC.

## The probe (already built — ships in `PakettiEightOneTwenty.lua`)

Menu: **Tools ▸ Paketti ▸ !Preferences ▸ Debug ▸ MidiControllers ▸ Hapax Probe — Open / Test grid LEDs / Close**
Keybindings: `Global:Paketti:Paketti Groovebox 8120 Hapax Probe Open` / `Close` / `Test LEDs`.

- **Open** — prints the full MIDI in/out inventory + every Hapax-matched port name to the terminal, opens the first matched input; every pad press / encoder turn prints a decoded `HAPAX IN: NoteOn ch=… data1=… data2=…` line. This gives us the port names + the pad/encoder map.
- **Test grid LEDs** — the empirical answer to B: blasts Note On (all 128 notes ch1), then Note 36 across all 16 channels, then CC 0..119 ch1, while Josh watches the grid. Per the manual, **expect nothing to light**. If anything does, we note which pad + which pass and reassess.
- **Close** — sends note-offs across the range (in case anything lit) and closes the ports.

### Test protocol for Josh
1. Hapax USB DEVICE → Mac. Reload Paketti.
2. Run **Hapax Probe — Open**. Read the terminal: copy the matched port names.
3. Press a few pads / turn the 8 encoders. Copy the `HAPAX IN:` lines — that's the map.
4. Run **Hapax Probe — Test grid LEDs**. Watch the grid. Report: did **any** pad/step light? (Expected: no.)
5. Run **Hapax Probe — Close**.

Send me the terminal dump + the "did anything light?" answer and I'll tell you exactly what a Hapax mode could and couldn't do.
