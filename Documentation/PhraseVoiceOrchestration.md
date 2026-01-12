# Phrase Voice Orchestration System

## What It Does

The Phrase Voice Orchestration system transforms Renoise's phrase playback from a **single-phrase-at-a-time** model into a **multi-voice groove-box** style system. Think of it like an MPC, Elektron Digitakt, or Ableton's clip launching - but for Renoise phrases.

### Core Concept

Normally in Renoise, triggering a new phrase **replaces** the currently playing one. With Voice Orchestration:

- **Multiple phrases play simultaneously** from the same instrument
- **Phase-locked switching** ensures new phrases start in groove-correct positions (no rhythmic drift)
- **Sloppy triggering is forgiven** - triggers are quantized to musical boundaries

---

## How to Access It

### 1. Performance Hub Dialog

**Menu**: `Tools > Paketti > PhraseGrid > Show Performance Hub`

**Keybinding**: `Global:Paketti:PhraseGrid Performance Hub`

The Performance Hub shows:
- **Voice Orchestration section** with 16 trigger buttons (P01-P16)
- Active voice count display
- Output mode toggle (Track/Column)
- Phase Lock checkbox
- Quantization settings
- Additive mode controls

### 2. Keybindings

Assign these in Renoise Preferences > Keys:

| Function | Keybinding Name |
|----------|-----------------|
| Spawn Phrase 01-16 | `PhraseVoice Spawn Phrase 01` ... `16` |
| Toggle Phrase 01-16 | `PhraseVoice Toggle Phrase 01` ... `16` |
| Smart Spawn (auto-detects mode) | `PhraseVoice Smart Spawn 01` ... `16` |
| Kill All Voices | `PhraseVoice Kill All` |
| Toggle Phase Lock | `PhraseVoice Toggle Phase Lock` |
| Toggle Output Mode | `PhraseVoice Toggle Output Mode` |
| Toggle Additive Mode | `PhraseVoice Toggle Additive Mode` |
| Spawn Selected Phrase | `PhraseVoice Spawn Selected Phrase` |
| Spawn Kick/Snare/HiHat Phrases | `PhraseVoice Spawn Kick Phrases` etc. |
| Toggle Debug Mode | `PhraseVoice Toggle Debug Mode` |

### 3. MIDI Mappings

All voice controls are available as MIDI triggers for hardware controller integration. Find them under `Paketti:PhraseVoice...` in the MIDI mapping dialog.

---

## Two Operating Modes

### Editor Mode (Immediate)

- For **editing, experimentation, sound design**
- Phrases spawn **immediately** when triggered
- No quantization delay
- Phase-locked to current beat position

### Switcher Mode (Quantized)

- For **live performance**
- Phrases spawn at **next quantization boundary** (line/beat/bar)
- Sloppy triggering is groove-safe
- Perfect for jamming

The system auto-detects which mode to use based on whether you're in the Phrase Editor or not.

---

## Output Modes

### Track Mode

Each voice gets its own dedicated track:
- Tracks are auto-created with prefix `PhraseVoice_`
- Up to 8 concurrent voices (configurable)
- Clean separation for mixing

### Column Mode

Multiple voices share the same track using different note columns:
- Up to 12 voices per track
- More compact arrangement
- Uses current selected track

---

## Key Features

### Phase-Locked Playback

When you trigger a phrase mid-song, it calculates where that phrase **would have been** if it had been playing from the start. The phrase begins at that position using the Sxx offset command. This means:
- No rhythmic drift
- Groove continuity preserved
- Phrases stay musically aligned

### Voice States

Save and recall combinations of active voices:
- **Save**: Capture current voice configuration to a state slot (1-32)
- **Recall**: Instantly restore a multi-voice configuration
- **Additive Mode**: Recall adds voices without killing existing ones

### Modular Phrase Construction

Name your phrases with patterns like "Kick", "Snare", "HiHat", then use:
- `PhraseVoice Spawn Kick Phrases` - spawns all phrases with "kick" in name
- Build drum patterns from separate phrase layers
- MPC-style pad triggering workflow

### Visual Feedback

In the Performance Hub:
- `[01]` = Active voice playing
- `*01*` = Voice scheduled (pending quantization)
- `P01` = Inactive

### Pattern Write Safety

The system includes protection against overwriting existing pattern data:
- Automatically finds empty lines within quantization window
- Tries alternate columns if current is occupied
- Warns before overwriting when necessary

### Fade-Out Support

Optional smooth voice stopping:
- Enable via `PhraseVoice Toggle Fade Out` or preferences
- Injects volume fade before note-off
- Prevents abrupt cutoffs

---

## Benefits

| Benefit | Description |
|---------|-------------|
| **Live Performance** | Layer phrases in real-time like a groovebox |
| **Groove Safety** | Sloppy triggering doesn't break timing |
| **Modular Drums** | Separate kick/snare/hat as independent phrases |
| **Sound Design** | Layer multiple phrase variations for textures |
| **State Recall** | Instantly switch between complex phrase combinations |
| **Hardware Control** | Full MIDI mapping for controllers |
| **No Hacks** | Uses native Renoise engine capabilities |

---

## Quick Start Example

1. Create an instrument with multiple phrases (e.g., P01=Kick, P02=Snare, P03=HiHat)
2. Open Performance Hub (`Tools > Paketti > PhraseGrid > Show Performance Hub`)
3. Start playback
4. Click `P01` - kick phrase starts playing
5. Click `P02` - snare phrase **layers on top** (not replacing!)
6. Click `P03` - now all three play together
7. Click `[01]` again - kills just the kick, snare+hat continue
8. Click "Save Voices" to store this configuration
9. Click "Kill All" then recall the state to restore instantly

---

## Preferences

The following preferences are saved between sessions:

| Preference | Description | Default |
|------------|-------------|---------|
| Output Mode | Track or Column | Track |
| Max Voices | Maximum concurrent voices (track mode) | 8 |
| Max Columns | Maximum voices per track (column mode) | 12 |
| Phase Lock Enabled | Enable phase-locked starts | true |
| Operation Mode | Editor or Switcher | Switcher |
| Preserve Existing Notes | Don't overwrite pattern data | true |
| Fade Out Enabled | Fade voices on stop | false |
| Additive Mode | Don't clear on state recall | false |
| Debug Enabled | Enable debug logging | false |

---

## Technical Details

### How Phase-Locking Works

The system calculates the global song position and determines where a phrase would be in its loop cycle:

```
global_line = (sum of all previous pattern lengths) + current_line
phase_offset = (global_line % phrase_length) + 1
```

This offset is written as an Sxx command when the phrase trigger note is injected.

### Voice Data Model

Each active voice tracks:
- Instrument and phrase index
- Track and column assignment
- Start position (song line and phrase line)
- Phase lock and looping state
- Estimated current playhead position

### Idle Processing

A background notifier handles:
- Processing pending voices at quantization boundaries
- Updating voice playhead estimates
- Cleaning up finished non-looping voices
- Validating voice pool on pattern changes
- Updating UI displays

---

## Troubleshooting

### Voices not spawning?
- Check that the instrument has phrases
- Verify available tracks/columns haven't reached maximum
- Enable Debug Mode to see detailed logging in the terminal

### Phase offset seems wrong?
- Ensure Phase Lock is enabled
- Check that transport is playing (phase is calculated from playback position)
- Verify phrase LPB matches song LPB for accurate sync

### UI not updating?
- Close and reopen the Performance Hub dialog
- The UI updates when playback line changes

---

## Related Features

- **PhraseGrid States**: Save/recall phrase configurations across multiple instruments
- **8120 Step Sequencer**: Integrates with voice orchestration for beat-synced triggers
- **Phrase Transport**: Visual playhead tracking in Phrase Editor
- **Quick Flicks**: Pattern generation that can output to phrases

