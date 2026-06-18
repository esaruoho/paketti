# Plugins/Devices — reconsidered (my "these don't matter" was wrong)

I earlier waved away most of the Plugins/Devices group as "console dumps / dialogs,
skip." That was lazy thinking: **a MIDI button that opens a panel, a loader, or an info
dialog is perfectly valid in a hardware workflow** — that's the whole point of a controller.
Here's the honest per-item verdict.

## I wrongly dismissed these as "not actions" — they ARE real actions
| Item | What it actually does | Verdict |
|---|---|---|
| Randomize Selected Instrument Plugin Parameters | randomizes the plugin's params | ✅ clear sound-design gesture |
| Import Selected Sample to Selected Convolver | loads the sample into the Convolver IR | ✅ real one-shot action |
| Switch Plugin AutoSuspend Off | toggles plugin auto-suspend | ✅ real toggle |
| ∿ Squiggly Sinewave to Clipboard... | generates a sinewave onto the clipboard | ✅ real generate action |

## Dialog / loader openers — valid on a button (your point, and you're right)
A button that *opens* the panel is a legit hardware shortcut. I was wrong to skip these.
| Item | What it opens |
|---|---|
| Load Devices... | the device loader |
| Load Plugins... | the plugin loader |
| Configure Plugin Slots... | the plugin-slots config |
| Show Effect Details Dialog... | effect info panel |
| Show Plugin Details Dialog... | plugin info panel |
| Dump VST/VST3/AU/LADSPA/DSSI/Native Effects to Dialog... | a browsable dump dialog |

## Console / inspector dumps — the only genuinely dev-leaning ones
These print to the **scripting terminal** (developer console), so a knob is less obviously
useful — but mapping them is still harmless, and handy if you debug live. Not "doesn't
matter," just lower priority.
| Item |
|---|
| Dump VST/VST3/AU/Native Effects (Console) |
| Inspect Plugin (Console) |
| Inspect Selected Device (Console) |
| List Available AU Effects (Console) |
| List Available AU Plugins (Console) |
| List Available VST Effects (Console) |
| List Available VST Plugins (Console) |

## The correction
The right rule isn't "dialogs don't matter" — it's **"can a button meaningfully invoke
this?"** For opening panels/loaders/info and for the four real actions, the answer is yes.
Only the seven console-dumps are arguably dev-only, and even those are fine to map.

**Proposal:** map all 17 (4 actions + 6 dialog-openers + 7 console). Or, if you want to
keep the controller list lean, map the 10 non-console ones and leave the 7 console dumps.
Your call — but I won't pretend the dialog-openers "don't matter" again.
