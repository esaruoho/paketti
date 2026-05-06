# Paketti Note Release Gate

**Play your effects like an instrument. Hold a key — the effect opens. Release the key — the effect closes, and the tail plays out.**

---

## Why this exists

Renoise has Signal Follower, which gates effects from audio level. That works for sustained sounds. It does not work for percussive gestures.

Concrete example: you want a snare hit to feed a delay, the delay tail to keep building while you hold a key on your MIDI keyboard, and the moment you release the key the delay should stop receiving new audio — but the existing tail should play out naturally.

Signal Follower can't do that. The snare is a transient, not a sustain; there's no audio signal to follow while you're holding the key. You need a **gesture**, not a level.

The Note Release Gate turns your MIDI keyboard into that gesture. A held key opens an effect's input. A released key closes it. Everything else — attack, release, velocity feel, beat-synced timing — is on top of that.

---

## What it actually does

For each "target" you set up, the gate watches your MIDI input and changes a parameter on a device:

- **Note ON** → parameter ramps to its **on** value (typically 1.0, fully open)
- **Note OFF** → parameter ramps to its **off** value (typically 0.0, fully closed)

The smartest default is to target a `#Send` device's `Amount` parameter. That way:

- Your audio source (snare, vocal, synth) is permanently routed *through* a Send device on its track
- The Send goes to a Send track that holds the actual delay/reverb/filter/whatever
- When the gate is closed, no audio enters the Send — but the destination effect on the Send track keeps running, so its tail decays naturally
- When the gate opens, audio flows in and the effect starts processing again

That's the snare-into-delay example, working.

---

## Setting it up — the 60-second version

1. Insert a `#Send` device on the track you want to gate. Route it to a Send track that has your effect (delay, reverb, etc).
   - Paketti has menu shortcuts under `Main Menu:Tools:Paketti:Preset++` to create wired-up Send tracks in one click.
2. Select the `#Send` device.
3. **`Main Menu:Tools:Paketti:Note Release Gate:Add Selected Device as Target`**
   - The gate auto-detects the `#Send` and targets its `Amount` parameter with on=1.0 / off=0.0. The amount is set to 0.0 immediately, so the gate is closed by default.
4. Open the dialog: **`Main Menu:Tools:Paketti:Note Release Gate:Show Dialog...`**
5. Pick your MIDI input device.
6. Click **Start**.
7. Hold a key on your MIDI keyboard. The Send opens, your snare feeds the delay.
8. Release the key. The Send closes, no more snare hits feed the delay, but the tail plays out.

That's the whole thing. Everything below is how to make it more musical.

---

## Performance controls (per target)

Each target row in the dialog has these knobs:

### Note range (lo / hi)
The keys that trigger this target. Default: full keyboard (C-0 to B-9). Set a range so different keys gate different effects — `C-3..B-3` opens the delay, `C-4..B-4` opens the filter, etc.

### Channel
Default `Inherit` (uses the global channel filter). Override if you want a specific MIDI channel to drive this target. Useful when you have multiple MIDI controllers or want to split keyboard zones.

### On / Off values
The parameter values at gate-open and gate-closed. For a `#Send`'s Amount, default is on=1.0 / off=0.0 (full / silent). For other parameters you can set anything — e.g., gate a filter cutoff between 0.2 and 0.8 to swing it open as you hold.

### Attack / Release (ms)
How long the parameter takes to ramp up on note-on and ramp down on note-off. 0 ms = instant.

- **Short attack (5–20 ms)**: snappy gate, almost a switch
- **Medium attack (50–200 ms)**: opens the effect like a fader sweep — softens the hit
- **Long release (300–1000 ms)**: gate closes slowly, gradual fade-out feel
- Long attack with short release: build-up swell, sudden choke

### Velocity → on
When checked, the **how hard you played the note** scales the on value. Soft keys open the gate less; hard hits open it fully. Lets you play dynamics into your gating: tap quietly for a hint of delay, slam for the full wash.

### Quant(lines)
Beat-quantized release. Default 0 = release fires the moment you let go.

When > 0, the release is held until the next pattern line where `(line - 1) % N == 0`. With LPB=4 and quant=4, every release snaps to the next downbeat. Critical for tight live performance — you stop fighting the metronome to release exactly on time.

If you re-trigger the same target before the pending release fires, the release is canceled and the gate stays open. (No clicks from a release that almost fired.)

If you stop transport while a release is pending, it fires immediately (so the device doesn't get stuck open).

---

## Modes (global)

These are in the **Modes** section of the dialog and apply to the whole gate.

### Latch
Default: momentary. Hold = open, release = close.

When latch is on: each note-on **toggles** between open and closed. Tap a key once → gate opens. Tap again → closes. Note-offs are ignored. Good for hands-free effect arming during a long passage.

### Write parameter automation while gating
When on, every gate event also writes an automation point on that parameter in the current pattern. If you're recording a take, the gestures you played are baked into the song.

When off, the gate only changes the parameter live — nothing is written. Good for jamming without committing.

Sample FX Chain targets never write automation (Renoise doesn't expose pattern automation lanes for chain devices).

### Pattern scanner
When on, the gate also reads notes and OFFs from the pattern itself while transport plays. So if you've written a sequence of notes on the same track as a target, the gate fires from the pattern as well as from your live MIDI.

A live MIDI hold always wins over the pattern. If you're holding a key, the pattern can't force the target closed mid-hold.

### Auto-start on song load
When on, the gate starts listening automatically when you open a song that has saved targets.

### Sustain pedal (CC 64)
When on, your sustain pedal becomes a **master gate switch**. Pedal down opens every target that matches the channel filter. Pedal up closes them all. Independent of what your hands are doing — you can hold/release individual targets with note keys *and* slam everything open or shut with your foot.

---

## Targets are per-song

Each Renoise song carries its own list of targets, keyed by the song's filename. Open a different song → its own target list loads. You don't accidentally fire gates against the wrong devices in the wrong song.

A single global "Auto-start on song load" pref still applies — opens the gate on whatever song you load, against *that song's* targets.

If you're working on an unsaved song, targets sit in a temporary `[unsaved]` bucket until you save the song.

---

## Sample FX Chain targets

Same idea, different scope.

Every Renoise instrument has its own **Sample FX Chain** — a per-instrument effect chain. You can put a `#Send` inside a sample chain and gate it the same way: the gating travels with the instrument across songs.

Setup:
1. Select your instrument.
2. Open its Sample FX Chain.
3. Insert a `#Send` device in the chain. Route it to a Send track.
4. Select that `#Send`.
5. **`Main Menu:Tools:Paketti:Note Release Gate:Add Selected Sample FX Chain Device as Target`**

Now your snare instrument carries its own gated delay routing, regardless of which track plays it.

Note: parameter automation is not written for Sample FX Chain targets (Renoise limitation). Live gestures still work.

---

## Identity is name-based

If you re-arrange devices on a track — insert a new device at position 2, swap the order of two effects — the gate doesn't lose its targets. It snapshots the device's display name and the parameter name when you add the target. On every fire, if the indexed slot doesn't match the snapshot, the gate searches the device list for a name match and re-binds.

Practical effect: you can move things around in your project without breaking your gating setup.

---

## A few performance recipes

### "Held-key delay throw"
- Snare track with a `#Send` to a delay send track
- Target: send `Amount`, on=1.0 / off=0.0
- Attack 5 ms, Release 0 ms (snappy in, instant cut on release)
- Hold a key during a fill → delay throws appear; release before the next downbeat → tail decays clean

### "Velocity-driven reverb wash"
- Vocal track with a `#Send` to a reverb send track
- Target: send `Amount`, on=1.0 / off=0.0, **velocity → on** ON
- Attack 100 ms, Release 800 ms
- Soft key = whisper of reverb. Hard key = full wash. Long release lets reverb breathe.

### "Beat-synced filter sweep"
- Synth track with a Filter device
- Target: filter cutoff, on=0.7 / off=0.2, **quant=4** (LPB=4)
- Attack 50 ms, Release 100 ms
- Hold = filter opens. Release = filter waits for the next downbeat to close. Tight against the groove without you fighting it.

### "Foot-pedal wide-open mode"
- Multiple effect targets across multiple tracks
- Sustain pedal (CC 64) ON
- Pedal down → every gate opens at once. Pedal up → everything snaps shut. One-foot dramatic transitions.

### "Pattern-driven during a take, live during overdubs"
- Pattern scanner ON, automation writing ON
- Write notes/OFFs in the pattern to drive the gates during normal playback
- During overdubs, hold your MIDI keyboard — your live gestures override the pattern, and the gestures get written to automation as you play

---

## Menu / keyboard reference

All under `Main Menu:Tools:Paketti:Note Release Gate:`

| Action | What it does |
|---|---|
| Show Dialog... | Opens the configuration window |
| Add Selected Device as Target | Adds whatever device is selected on the current track |
| Add Selected Sample FX Chain Device as Target | Adds a device from the selected instrument's Sample FX Chain |
| Remove Targets For Current Track | Wipes all targets on the currently selected track |
| Clear All Targets | Wipes everything (asks for confirmation in dialog) |
| List Targets | Pop-up listing what's set up |
| Start | Begin listening on the configured MIDI input |
| Stop | Stop, release everything to off, clear pending |
| Toggle Start/Stop | One-key panic / re-arm |
| Toggle Latch Mode | Momentary ↔ latch |
| Toggle Automation Writing | Live-only ↔ baked into pattern |
| Toggle Pattern Scanner | Live-only ↔ pattern-driven |
| Toggle Sustain Pedal (CC 64) | Foot-pedal master gate on/off |

All of the above are also available as keybindings under `Global:Paketti:Note Release Gate ...`. Bind whatever you reach for live.

There are MIDI mappings too: `Paketti:Note Release Gate Toggle Start/Stop`, `Paketti:Note Release Gate Toggle Latch Mode`, `Paketti:Note Release Gate Show Dialog`. Map these to your controller's free buttons for foot-free arming.

---

## Troubleshooting

**"I added a target but nothing happens when I play."**
- The gate isn't started. Open the dialog and click **Start**, or hit your bound `Toggle Start/Stop` key.
- Wrong MIDI channel. Check the global channel filter and the per-target channel.
- Your key is outside the target's note range.

**"The effect cuts dead instantly when I release. I want a tail."**
- You've targeted the wrong thing. If you targeted the effect device's bypass (`is_active`), the device gets switched off and its tail vanishes. Target a `#Send`'s `Amount` instead — the destination effect keeps running and its tail decays naturally.

**"The gate fights the pattern."**
- Pattern scanner is on. If you don't want the pattern to drive the gate, toggle it off.
- Or you do want the pattern to drive the gate but didn't write OFFs in the pattern. Renoise's note-off recording behavior depends on instrument NNA settings; if OFFs aren't appearing where you expect, set the instrument's NNA mode to `Cut`.

**"Releases don't land on the beat."**
- Set per-target `quant(lines)`. With LPB=4 and quant=4, releases snap to the next downbeat.

**"My target says UNRESOLVED in the dialog."**
- The device's display name has been changed since you added the target, or the device has been deleted. Either rename it back to the snapshot name (shown in the dialog row) or remove and re-add the target.

**"Gate stops working after I save the song with a new name."**
- Targets are keyed by filename. "Save As" creates a new bucket. Open the dialog, re-add your targets in the new song. (Or copy the targets across via the underlying preferences file if you're a power user.)

---

## What this is, in one sentence

A Renoise tool that turns held MIDI keys, sustain pedals, and pattern note-offs into smooth, beat-synced, velocity-aware envelopes over any device parameter on any track or instrument's Sample FX Chain — so your effects can be played gesturally instead of either sitting static or being chased by the audio level.
