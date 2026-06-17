# Paketti — invalid-scope keyboard shortcuts (resolved)

**987 keyboard shortcuts were registered under scopes Renoise 3.5 does NOT accept as keybinding categories.** Per the Renoise API such a binding is *listed and mappable in the keyboard-prefs pane but never invoked* when its key is pressed. All 987 are now resolved at the single registration choke point (`proxy_add_keybinding` in `main.lua`):

| Invalid scope | Count | Resolution |
|---|--:|---|
| `Sample Mappings:` | 485 | **Re-scoped to `Sample Keyzones:`** — the real keybinding category. Now fire. The valid `Sample Mappings` *menu* entries are untouched (only keybindings are rewritten). |
| `Sample Navigator:` | 501 | **Dropped** — `Sample Navigator` is a menu context with no keybinding-scope equivalent. Every one has a twin under `Instrument Box` / `Global`, so nothing is lost. |
| `DSP Device:` | 1 | **Typo fixed at source** (`PakettiPresetPlusPlus.lua:1164` → `DSP Chain:`). Now fires. |

The 16 valid Renoise 3.5 keybinding scopes (keyboard-prefs category dropdown):
`Global · Automation · Disk Browser · DSP Chain · Instrument Box · Mixer · Pattern Editor · Pattern Matrix · Pattern Sequencer · Phrase Editor · Phrase Map · Phrase Script Editor · Sample Editor · Sample FX Mixer · Sample Keyzones · Sample Modulation Matrix`

Mechanism in `main.lua`: `PAKETTI_KB_SCOPE_REMAP` rewrites a misnamed scope to its real keybinding category (`Sample Mappings` → `Sample Keyzones`); anything still invalid after that is dropped and collected in `PakettiDeadKeybindings`. Because only keybindings pass through `proxy_add_keybinding`, menu entries under the same context names keep working.

## Re-scoped `Sample Mappings:` → `Sample Keyzones:` (now working)

```
Sample Mappings:Paketti:Set All Samples in Selected Instrument to Beginning Half Loop   ->   Sample Keyzones:Paketti:Set All Samples in Selected Instrument to Beginning Half Loop
Sample Mappings:Paketti:Set All Samples in Selected Instrument to End-Half Loop   ->   Sample Keyzones:Paketti:Set All Samples in Selected Instrument to End-Half Loop
Sample Mappings:Paketti:Set All Samples in Selected Instrument to Full Loop   ->   Sample Keyzones:Paketti:Set All Samples in Selected Instrument to Full Loop
Sample Mappings:Paketti:Set Selected Instrument Transpose (+1)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+1)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+10)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+10)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+100)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+100)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+101)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+101)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+102)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+102)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+103)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+103)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+104)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+104)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+105)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+105)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+106)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+106)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+107)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+107)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+108)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+108)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+109)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+109)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+11)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+11)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+110)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+110)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+111)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+111)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+112)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+112)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+113)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+113)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+114)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+114)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+115)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+115)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+116)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+116)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+117)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+117)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+118)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+118)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+119)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+119)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+12)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+12)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+120)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+120)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+13)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+13)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+14)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+14)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+15)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+15)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+16)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+16)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+17)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+17)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+18)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+18)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+19)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+19)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+2)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+2)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+20)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+20)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+21)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+21)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+22)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+22)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+23)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+23)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+24)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+24)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+25)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+25)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+26)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+26)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+27)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+27)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+28)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+28)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+29)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+29)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+3)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+3)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+30)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+30)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+31)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+31)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+32)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+32)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+33)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+33)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+34)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+34)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+35)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+35)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+36)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+36)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+37)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+37)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+38)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+38)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+39)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+39)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+4)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+4)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+40)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+40)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+41)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+41)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+42)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+42)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+43)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+43)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+44)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+44)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+45)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+45)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+46)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+46)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+47)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+47)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+48)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+48)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+49)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+49)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+5)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+5)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+50)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+50)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+51)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+51)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+52)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+52)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+53)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+53)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+54)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+54)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+55)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+55)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+56)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+56)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+57)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+57)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+58)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+58)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+59)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+59)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+6)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+6)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+60)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+60)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+61)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+61)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+62)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+62)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+63)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+63)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+64)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+64)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+65)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+65)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+66)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+66)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+67)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+67)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+68)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+68)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+69)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+69)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+7)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+7)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+70)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+70)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+71)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+71)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+72)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+72)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+73)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+73)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+74)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+74)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+75)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+75)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+76)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+76)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+77)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+77)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+78)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+78)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+79)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+79)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+8)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+8)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+80)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+80)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+81)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+81)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+82)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+82)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+83)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+83)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+84)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+84)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+85)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+85)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+86)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+86)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+87)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+87)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+88)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+88)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+89)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+89)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+9)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+9)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+90)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+90)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+91)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+91)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+92)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+92)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+93)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+93)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+94)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+94)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+95)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+95)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+96)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+96)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+97)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+97)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+98)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+98)
Sample Mappings:Paketti:Set Selected Instrument Transpose (+99)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (+99)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-1)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-1)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-10)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-10)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-100)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-100)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-101)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-101)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-102)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-102)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-103)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-103)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-104)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-104)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-105)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-105)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-106)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-106)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-107)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-107)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-108)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-108)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-109)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-109)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-11)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-11)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-110)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-110)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-111)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-111)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-112)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-112)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-113)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-113)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-114)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-114)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-115)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-115)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-116)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-116)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-117)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-117)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-118)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-118)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-119)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-119)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-12)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-12)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-120)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-120)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-13)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-13)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-14)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-14)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-15)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-15)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-16)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-16)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-17)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-17)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-18)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-18)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-19)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-19)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-2)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-2)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-20)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-20)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-21)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-21)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-22)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-22)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-23)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-23)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-24)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-24)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-25)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-25)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-26)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-26)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-27)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-27)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-28)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-28)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-29)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-29)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-3)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-3)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-30)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-30)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-31)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-31)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-32)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-32)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-33)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-33)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-34)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-34)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-35)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-35)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-36)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-36)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-37)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-37)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-38)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-38)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-39)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-39)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-4)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-4)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-40)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-40)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-41)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-41)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-42)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-42)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-43)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-43)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-44)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-44)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-45)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-45)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-46)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-46)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-47)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-47)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-48)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-48)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-49)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-49)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-5)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-5)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-50)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-50)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-51)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-51)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-52)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-52)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-53)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-53)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-54)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-54)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-55)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-55)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-56)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-56)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-57)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-57)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-58)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-58)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-59)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-59)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-6)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-6)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-60)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-60)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-61)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-61)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-62)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-62)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-63)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-63)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-64)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-64)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-65)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-65)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-66)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-66)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-67)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-67)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-68)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-68)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-69)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-69)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-7)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-7)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-70)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-70)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-71)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-71)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-72)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-72)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-73)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-73)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-74)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-74)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-75)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-75)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-76)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-76)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-77)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-77)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-78)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-78)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-79)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-79)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-8)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-8)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-80)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-80)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-81)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-81)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-82)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-82)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-83)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-83)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-84)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-84)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-85)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-85)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-86)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-86)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-87)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-87)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-88)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-88)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-89)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-89)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-9)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-9)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-90)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-90)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-91)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-91)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-92)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-92)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-93)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-93)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-94)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-94)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-95)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-95)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-96)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-96)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-97)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-97)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-98)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-98)
Sample Mappings:Paketti:Set Selected Instrument Transpose (-99)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose (-99)
Sample Mappings:Paketti:Set Selected Instrument Transpose to +1   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +1
Sample Mappings:Paketti:Set Selected Instrument Transpose to +10   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +10
Sample Mappings:Paketti:Set Selected Instrument Transpose to +100   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +100
Sample Mappings:Paketti:Set Selected Instrument Transpose to +101   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +101
Sample Mappings:Paketti:Set Selected Instrument Transpose to +102   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +102
Sample Mappings:Paketti:Set Selected Instrument Transpose to +103   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +103
Sample Mappings:Paketti:Set Selected Instrument Transpose to +104   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +104
Sample Mappings:Paketti:Set Selected Instrument Transpose to +105   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +105
Sample Mappings:Paketti:Set Selected Instrument Transpose to +106   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +106
Sample Mappings:Paketti:Set Selected Instrument Transpose to +107   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +107
Sample Mappings:Paketti:Set Selected Instrument Transpose to +108   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +108
Sample Mappings:Paketti:Set Selected Instrument Transpose to +109   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +109
Sample Mappings:Paketti:Set Selected Instrument Transpose to +11   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +11
Sample Mappings:Paketti:Set Selected Instrument Transpose to +110   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +110
Sample Mappings:Paketti:Set Selected Instrument Transpose to +111   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +111
Sample Mappings:Paketti:Set Selected Instrument Transpose to +112   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +112
Sample Mappings:Paketti:Set Selected Instrument Transpose to +113   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +113
Sample Mappings:Paketti:Set Selected Instrument Transpose to +114   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +114
Sample Mappings:Paketti:Set Selected Instrument Transpose to +115   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +115
Sample Mappings:Paketti:Set Selected Instrument Transpose to +116   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +116
Sample Mappings:Paketti:Set Selected Instrument Transpose to +117   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +117
Sample Mappings:Paketti:Set Selected Instrument Transpose to +118   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +118
Sample Mappings:Paketti:Set Selected Instrument Transpose to +119   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +119
Sample Mappings:Paketti:Set Selected Instrument Transpose to +12   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +12
Sample Mappings:Paketti:Set Selected Instrument Transpose to +120   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +120
Sample Mappings:Paketti:Set Selected Instrument Transpose to +13   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +13
Sample Mappings:Paketti:Set Selected Instrument Transpose to +14   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +14
Sample Mappings:Paketti:Set Selected Instrument Transpose to +15   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +15
Sample Mappings:Paketti:Set Selected Instrument Transpose to +16   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +16
Sample Mappings:Paketti:Set Selected Instrument Transpose to +17   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +17
Sample Mappings:Paketti:Set Selected Instrument Transpose to +18   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +18
Sample Mappings:Paketti:Set Selected Instrument Transpose to +19   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +19
Sample Mappings:Paketti:Set Selected Instrument Transpose to +2   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +2
Sample Mappings:Paketti:Set Selected Instrument Transpose to +20   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +20
Sample Mappings:Paketti:Set Selected Instrument Transpose to +21   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +21
Sample Mappings:Paketti:Set Selected Instrument Transpose to +22   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +22
Sample Mappings:Paketti:Set Selected Instrument Transpose to +23   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +23
Sample Mappings:Paketti:Set Selected Instrument Transpose to +24   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +24
Sample Mappings:Paketti:Set Selected Instrument Transpose to +25   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +25
Sample Mappings:Paketti:Set Selected Instrument Transpose to +26   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +26
Sample Mappings:Paketti:Set Selected Instrument Transpose to +27   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +27
Sample Mappings:Paketti:Set Selected Instrument Transpose to +28   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +28
Sample Mappings:Paketti:Set Selected Instrument Transpose to +29   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +29
Sample Mappings:Paketti:Set Selected Instrument Transpose to +3   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +3
Sample Mappings:Paketti:Set Selected Instrument Transpose to +30   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +30
Sample Mappings:Paketti:Set Selected Instrument Transpose to +31   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +31
Sample Mappings:Paketti:Set Selected Instrument Transpose to +32   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +32
Sample Mappings:Paketti:Set Selected Instrument Transpose to +33   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +33
Sample Mappings:Paketti:Set Selected Instrument Transpose to +34   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +34
Sample Mappings:Paketti:Set Selected Instrument Transpose to +35   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +35
Sample Mappings:Paketti:Set Selected Instrument Transpose to +36   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +36
Sample Mappings:Paketti:Set Selected Instrument Transpose to +37   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +37
Sample Mappings:Paketti:Set Selected Instrument Transpose to +38   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +38
Sample Mappings:Paketti:Set Selected Instrument Transpose to +39   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +39
Sample Mappings:Paketti:Set Selected Instrument Transpose to +4   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +4
Sample Mappings:Paketti:Set Selected Instrument Transpose to +40   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +40
Sample Mappings:Paketti:Set Selected Instrument Transpose to +41   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +41
Sample Mappings:Paketti:Set Selected Instrument Transpose to +42   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +42
Sample Mappings:Paketti:Set Selected Instrument Transpose to +43   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +43
Sample Mappings:Paketti:Set Selected Instrument Transpose to +44   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +44
Sample Mappings:Paketti:Set Selected Instrument Transpose to +45   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +45
Sample Mappings:Paketti:Set Selected Instrument Transpose to +46   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +46
Sample Mappings:Paketti:Set Selected Instrument Transpose to +47   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +47
Sample Mappings:Paketti:Set Selected Instrument Transpose to +48   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +48
Sample Mappings:Paketti:Set Selected Instrument Transpose to +49   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +49
Sample Mappings:Paketti:Set Selected Instrument Transpose to +5   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +5
Sample Mappings:Paketti:Set Selected Instrument Transpose to +50   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +50
Sample Mappings:Paketti:Set Selected Instrument Transpose to +51   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +51
Sample Mappings:Paketti:Set Selected Instrument Transpose to +52   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +52
Sample Mappings:Paketti:Set Selected Instrument Transpose to +53   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +53
Sample Mappings:Paketti:Set Selected Instrument Transpose to +54   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +54
Sample Mappings:Paketti:Set Selected Instrument Transpose to +55   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +55
Sample Mappings:Paketti:Set Selected Instrument Transpose to +56   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +56
Sample Mappings:Paketti:Set Selected Instrument Transpose to +57   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +57
Sample Mappings:Paketti:Set Selected Instrument Transpose to +58   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +58
Sample Mappings:Paketti:Set Selected Instrument Transpose to +59   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +59
Sample Mappings:Paketti:Set Selected Instrument Transpose to +6   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +6
Sample Mappings:Paketti:Set Selected Instrument Transpose to +60   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +60
Sample Mappings:Paketti:Set Selected Instrument Transpose to +61   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +61
Sample Mappings:Paketti:Set Selected Instrument Transpose to +62   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +62
Sample Mappings:Paketti:Set Selected Instrument Transpose to +63   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +63
Sample Mappings:Paketti:Set Selected Instrument Transpose to +64   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +64
Sample Mappings:Paketti:Set Selected Instrument Transpose to +65   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +65
Sample Mappings:Paketti:Set Selected Instrument Transpose to +66   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +66
Sample Mappings:Paketti:Set Selected Instrument Transpose to +67   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +67
Sample Mappings:Paketti:Set Selected Instrument Transpose to +68   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +68
Sample Mappings:Paketti:Set Selected Instrument Transpose to +69   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +69
Sample Mappings:Paketti:Set Selected Instrument Transpose to +7   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +7
Sample Mappings:Paketti:Set Selected Instrument Transpose to +70   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +70
Sample Mappings:Paketti:Set Selected Instrument Transpose to +71   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +71
Sample Mappings:Paketti:Set Selected Instrument Transpose to +72   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +72
Sample Mappings:Paketti:Set Selected Instrument Transpose to +73   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +73
Sample Mappings:Paketti:Set Selected Instrument Transpose to +74   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +74
Sample Mappings:Paketti:Set Selected Instrument Transpose to +75   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +75
Sample Mappings:Paketti:Set Selected Instrument Transpose to +76   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +76
Sample Mappings:Paketti:Set Selected Instrument Transpose to +77   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +77
Sample Mappings:Paketti:Set Selected Instrument Transpose to +78   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +78
Sample Mappings:Paketti:Set Selected Instrument Transpose to +79   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +79
Sample Mappings:Paketti:Set Selected Instrument Transpose to +8   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +8
Sample Mappings:Paketti:Set Selected Instrument Transpose to +80   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +80
Sample Mappings:Paketti:Set Selected Instrument Transpose to +81   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +81
Sample Mappings:Paketti:Set Selected Instrument Transpose to +82   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +82
Sample Mappings:Paketti:Set Selected Instrument Transpose to +83   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +83
Sample Mappings:Paketti:Set Selected Instrument Transpose to +84   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +84
Sample Mappings:Paketti:Set Selected Instrument Transpose to +85   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +85
Sample Mappings:Paketti:Set Selected Instrument Transpose to +86   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +86
Sample Mappings:Paketti:Set Selected Instrument Transpose to +87   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +87
Sample Mappings:Paketti:Set Selected Instrument Transpose to +88   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +88
Sample Mappings:Paketti:Set Selected Instrument Transpose to +89   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +89
Sample Mappings:Paketti:Set Selected Instrument Transpose to +9   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +9
Sample Mappings:Paketti:Set Selected Instrument Transpose to +90   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +90
Sample Mappings:Paketti:Set Selected Instrument Transpose to +91   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +91
Sample Mappings:Paketti:Set Selected Instrument Transpose to +92   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +92
Sample Mappings:Paketti:Set Selected Instrument Transpose to +93   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +93
Sample Mappings:Paketti:Set Selected Instrument Transpose to +94   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +94
Sample Mappings:Paketti:Set Selected Instrument Transpose to +95   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +95
Sample Mappings:Paketti:Set Selected Instrument Transpose to +96   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +96
Sample Mappings:Paketti:Set Selected Instrument Transpose to +97   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +97
Sample Mappings:Paketti:Set Selected Instrument Transpose to +98   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +98
Sample Mappings:Paketti:Set Selected Instrument Transpose to +99   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to +99
Sample Mappings:Paketti:Set Selected Instrument Transpose to -1   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -1
Sample Mappings:Paketti:Set Selected Instrument Transpose to -10   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -10
Sample Mappings:Paketti:Set Selected Instrument Transpose to -100   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -100
Sample Mappings:Paketti:Set Selected Instrument Transpose to -101   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -101
Sample Mappings:Paketti:Set Selected Instrument Transpose to -102   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -102
Sample Mappings:Paketti:Set Selected Instrument Transpose to -103   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -103
Sample Mappings:Paketti:Set Selected Instrument Transpose to -104   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -104
Sample Mappings:Paketti:Set Selected Instrument Transpose to -105   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -105
Sample Mappings:Paketti:Set Selected Instrument Transpose to -106   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -106
Sample Mappings:Paketti:Set Selected Instrument Transpose to -107   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -107
Sample Mappings:Paketti:Set Selected Instrument Transpose to -108   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -108
Sample Mappings:Paketti:Set Selected Instrument Transpose to -109   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -109
Sample Mappings:Paketti:Set Selected Instrument Transpose to -11   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -11
Sample Mappings:Paketti:Set Selected Instrument Transpose to -110   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -110
Sample Mappings:Paketti:Set Selected Instrument Transpose to -111   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -111
Sample Mappings:Paketti:Set Selected Instrument Transpose to -112   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -112
Sample Mappings:Paketti:Set Selected Instrument Transpose to -113   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -113
Sample Mappings:Paketti:Set Selected Instrument Transpose to -114   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -114
Sample Mappings:Paketti:Set Selected Instrument Transpose to -115   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -115
Sample Mappings:Paketti:Set Selected Instrument Transpose to -116   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -116
Sample Mappings:Paketti:Set Selected Instrument Transpose to -117   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -117
Sample Mappings:Paketti:Set Selected Instrument Transpose to -118   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -118
Sample Mappings:Paketti:Set Selected Instrument Transpose to -119   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -119
Sample Mappings:Paketti:Set Selected Instrument Transpose to -12   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -12
Sample Mappings:Paketti:Set Selected Instrument Transpose to -120   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -120
Sample Mappings:Paketti:Set Selected Instrument Transpose to -13   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -13
Sample Mappings:Paketti:Set Selected Instrument Transpose to -14   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -14
Sample Mappings:Paketti:Set Selected Instrument Transpose to -15   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -15
Sample Mappings:Paketti:Set Selected Instrument Transpose to -16   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -16
Sample Mappings:Paketti:Set Selected Instrument Transpose to -17   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -17
Sample Mappings:Paketti:Set Selected Instrument Transpose to -18   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -18
Sample Mappings:Paketti:Set Selected Instrument Transpose to -19   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -19
Sample Mappings:Paketti:Set Selected Instrument Transpose to -2   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -2
Sample Mappings:Paketti:Set Selected Instrument Transpose to -20   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -20
Sample Mappings:Paketti:Set Selected Instrument Transpose to -21   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -21
Sample Mappings:Paketti:Set Selected Instrument Transpose to -22   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -22
Sample Mappings:Paketti:Set Selected Instrument Transpose to -23   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -23
Sample Mappings:Paketti:Set Selected Instrument Transpose to -24   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -24
Sample Mappings:Paketti:Set Selected Instrument Transpose to -25   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -25
Sample Mappings:Paketti:Set Selected Instrument Transpose to -26   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -26
Sample Mappings:Paketti:Set Selected Instrument Transpose to -27   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -27
Sample Mappings:Paketti:Set Selected Instrument Transpose to -28   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -28
Sample Mappings:Paketti:Set Selected Instrument Transpose to -29   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -29
Sample Mappings:Paketti:Set Selected Instrument Transpose to -3   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -3
Sample Mappings:Paketti:Set Selected Instrument Transpose to -30   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -30
Sample Mappings:Paketti:Set Selected Instrument Transpose to -31   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -31
Sample Mappings:Paketti:Set Selected Instrument Transpose to -32   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -32
Sample Mappings:Paketti:Set Selected Instrument Transpose to -33   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -33
Sample Mappings:Paketti:Set Selected Instrument Transpose to -34   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -34
Sample Mappings:Paketti:Set Selected Instrument Transpose to -35   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -35
Sample Mappings:Paketti:Set Selected Instrument Transpose to -36   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -36
Sample Mappings:Paketti:Set Selected Instrument Transpose to -37   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -37
Sample Mappings:Paketti:Set Selected Instrument Transpose to -38   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -38
Sample Mappings:Paketti:Set Selected Instrument Transpose to -39   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -39
Sample Mappings:Paketti:Set Selected Instrument Transpose to -4   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -4
Sample Mappings:Paketti:Set Selected Instrument Transpose to -40   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -40
Sample Mappings:Paketti:Set Selected Instrument Transpose to -41   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -41
Sample Mappings:Paketti:Set Selected Instrument Transpose to -42   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -42
Sample Mappings:Paketti:Set Selected Instrument Transpose to -43   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -43
Sample Mappings:Paketti:Set Selected Instrument Transpose to -44   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -44
Sample Mappings:Paketti:Set Selected Instrument Transpose to -45   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -45
Sample Mappings:Paketti:Set Selected Instrument Transpose to -46   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -46
Sample Mappings:Paketti:Set Selected Instrument Transpose to -47   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -47
Sample Mappings:Paketti:Set Selected Instrument Transpose to -48   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -48
Sample Mappings:Paketti:Set Selected Instrument Transpose to -49   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -49
Sample Mappings:Paketti:Set Selected Instrument Transpose to -5   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -5
Sample Mappings:Paketti:Set Selected Instrument Transpose to -50   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -50
Sample Mappings:Paketti:Set Selected Instrument Transpose to -51   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -51
Sample Mappings:Paketti:Set Selected Instrument Transpose to -52   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -52
Sample Mappings:Paketti:Set Selected Instrument Transpose to -53   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -53
Sample Mappings:Paketti:Set Selected Instrument Transpose to -54   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -54
Sample Mappings:Paketti:Set Selected Instrument Transpose to -55   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -55
Sample Mappings:Paketti:Set Selected Instrument Transpose to -56   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -56
Sample Mappings:Paketti:Set Selected Instrument Transpose to -57   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -57
Sample Mappings:Paketti:Set Selected Instrument Transpose to -58   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -58
Sample Mappings:Paketti:Set Selected Instrument Transpose to -59   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -59
Sample Mappings:Paketti:Set Selected Instrument Transpose to -6   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -6
Sample Mappings:Paketti:Set Selected Instrument Transpose to -60   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -60
Sample Mappings:Paketti:Set Selected Instrument Transpose to -61   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -61
Sample Mappings:Paketti:Set Selected Instrument Transpose to -62   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -62
Sample Mappings:Paketti:Set Selected Instrument Transpose to -63   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -63
Sample Mappings:Paketti:Set Selected Instrument Transpose to -64   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -64
Sample Mappings:Paketti:Set Selected Instrument Transpose to -65   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -65
Sample Mappings:Paketti:Set Selected Instrument Transpose to -66   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -66
Sample Mappings:Paketti:Set Selected Instrument Transpose to -67   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -67
Sample Mappings:Paketti:Set Selected Instrument Transpose to -68   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -68
Sample Mappings:Paketti:Set Selected Instrument Transpose to -69   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -69
Sample Mappings:Paketti:Set Selected Instrument Transpose to -7   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -7
Sample Mappings:Paketti:Set Selected Instrument Transpose to -70   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -70
Sample Mappings:Paketti:Set Selected Instrument Transpose to -71   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -71
Sample Mappings:Paketti:Set Selected Instrument Transpose to -72   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -72
Sample Mappings:Paketti:Set Selected Instrument Transpose to -73   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -73
Sample Mappings:Paketti:Set Selected Instrument Transpose to -74   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -74
Sample Mappings:Paketti:Set Selected Instrument Transpose to -75   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -75
Sample Mappings:Paketti:Set Selected Instrument Transpose to -76   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -76
Sample Mappings:Paketti:Set Selected Instrument Transpose to -77   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -77
Sample Mappings:Paketti:Set Selected Instrument Transpose to -78   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -78
Sample Mappings:Paketti:Set Selected Instrument Transpose to -79   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -79
Sample Mappings:Paketti:Set Selected Instrument Transpose to -8   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -8
Sample Mappings:Paketti:Set Selected Instrument Transpose to -80   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -80
Sample Mappings:Paketti:Set Selected Instrument Transpose to -81   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -81
Sample Mappings:Paketti:Set Selected Instrument Transpose to -82   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -82
Sample Mappings:Paketti:Set Selected Instrument Transpose to -83   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -83
Sample Mappings:Paketti:Set Selected Instrument Transpose to -84   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -84
Sample Mappings:Paketti:Set Selected Instrument Transpose to -85   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -85
Sample Mappings:Paketti:Set Selected Instrument Transpose to -86   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -86
Sample Mappings:Paketti:Set Selected Instrument Transpose to -87   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -87
Sample Mappings:Paketti:Set Selected Instrument Transpose to -88   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -88
Sample Mappings:Paketti:Set Selected Instrument Transpose to -89   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -89
Sample Mappings:Paketti:Set Selected Instrument Transpose to -9   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -9
Sample Mappings:Paketti:Set Selected Instrument Transpose to -90   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -90
Sample Mappings:Paketti:Set Selected Instrument Transpose to -91   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -91
Sample Mappings:Paketti:Set Selected Instrument Transpose to -92   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -92
Sample Mappings:Paketti:Set Selected Instrument Transpose to -93   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -93
Sample Mappings:Paketti:Set Selected Instrument Transpose to -94   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -94
Sample Mappings:Paketti:Set Selected Instrument Transpose to -95   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -95
Sample Mappings:Paketti:Set Selected Instrument Transpose to -96   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -96
Sample Mappings:Paketti:Set Selected Instrument Transpose to -97   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -97
Sample Mappings:Paketti:Set Selected Instrument Transpose to -98   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -98
Sample Mappings:Paketti:Set Selected Instrument Transpose to -99   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to -99
Sample Mappings:Paketti:Set Selected Instrument Transpose to 0   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to 0
Sample Mappings:Paketti:Set Selected Instrument Transpose to 0 (Reset)   ->   Sample Keyzones:Paketti:Set Selected Instrument Transpose to 0 (Reset)
```

## Dropped — `Sample Navigator:` (no keybinding equivalent; twin under Instrument Box / Global)

```
Sample Navigator:Paketti:Move Slice End Left by 10
Sample Navigator:Paketti:Move Slice End Left by 100
Sample Navigator:Paketti:Move Slice End Left by 300
Sample Navigator:Paketti:Move Slice End Left by 500
Sample Navigator:Paketti:Move Slice End Right by 10
Sample Navigator:Paketti:Move Slice End Right by 100
Sample Navigator:Paketti:Move Slice End Right by 300
Sample Navigator:Paketti:Move Slice End Right by 500
Sample Navigator:Paketti:Move Slice Start Left by 10
Sample Navigator:Paketti:Move Slice Start Left by 100
Sample Navigator:Paketti:Move Slice Start Left by 300
Sample Navigator:Paketti:Move Slice Start Left by 500
Sample Navigator:Paketti:Move Slice Start Right by 10
Sample Navigator:Paketti:Move Slice Start Right by 100
Sample Navigator:Paketti:Move Slice Start Right by 300
Sample Navigator:Paketti:Move Slice Start Right by 500
Sample Navigator:Paketti:Set All Samples in Selected Instrument to Beginning Half Loop
Sample Navigator:Paketti:Set All Samples in Selected Instrument to End-Half Loop
Sample Navigator:Paketti:Set All Samples in Selected Instrument to Full Loop
Sample Navigator:Paketti:Set Selected Instrument Transpose (+1)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+10)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+100)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+101)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+102)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+103)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+104)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+105)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+106)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+107)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+108)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+109)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+11)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+110)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+111)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+112)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+113)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+114)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+115)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+116)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+117)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+118)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+119)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+12)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+120)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+13)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+14)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+15)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+16)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+17)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+18)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+19)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+2)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+20)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+21)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+22)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+23)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+24)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+25)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+26)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+27)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+28)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+29)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+3)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+30)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+31)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+32)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+33)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+34)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+35)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+36)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+37)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+38)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+39)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+4)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+40)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+41)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+42)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+43)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+44)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+45)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+46)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+47)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+48)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+49)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+5)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+50)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+51)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+52)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+53)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+54)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+55)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+56)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+57)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+58)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+59)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+6)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+60)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+61)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+62)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+63)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+64)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+65)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+66)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+67)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+68)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+69)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+7)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+70)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+71)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+72)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+73)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+74)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+75)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+76)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+77)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+78)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+79)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+8)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+80)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+81)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+82)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+83)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+84)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+85)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+86)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+87)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+88)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+89)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+9)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+90)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+91)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+92)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+93)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+94)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+95)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+96)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+97)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+98)
Sample Navigator:Paketti:Set Selected Instrument Transpose (+99)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-1)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-10)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-100)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-101)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-102)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-103)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-104)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-105)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-106)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-107)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-108)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-109)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-11)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-110)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-111)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-112)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-113)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-114)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-115)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-116)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-117)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-118)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-119)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-12)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-120)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-13)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-14)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-15)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-16)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-17)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-18)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-19)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-2)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-20)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-21)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-22)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-23)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-24)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-25)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-26)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-27)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-28)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-29)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-3)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-30)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-31)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-32)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-33)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-34)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-35)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-36)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-37)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-38)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-39)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-4)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-40)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-41)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-42)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-43)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-44)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-45)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-46)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-47)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-48)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-49)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-5)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-50)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-51)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-52)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-53)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-54)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-55)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-56)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-57)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-58)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-59)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-6)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-60)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-61)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-62)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-63)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-64)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-65)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-66)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-67)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-68)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-69)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-7)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-70)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-71)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-72)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-73)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-74)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-75)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-76)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-77)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-78)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-79)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-8)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-80)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-81)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-82)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-83)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-84)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-85)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-86)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-87)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-88)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-89)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-9)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-90)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-91)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-92)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-93)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-94)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-95)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-96)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-97)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-98)
Sample Navigator:Paketti:Set Selected Instrument Transpose (-99)
Sample Navigator:Paketti:Set Selected Instrument Transpose to +1
Sample Navigator:Paketti:Set Selected Instrument Transpose to +10
Sample Navigator:Paketti:Set Selected Instrument Transpose to +100
Sample Navigator:Paketti:Set Selected Instrument Transpose to +101
Sample Navigator:Paketti:Set Selected Instrument Transpose to +102
Sample Navigator:Paketti:Set Selected Instrument Transpose to +103
Sample Navigator:Paketti:Set Selected Instrument Transpose to +104
Sample Navigator:Paketti:Set Selected Instrument Transpose to +105
Sample Navigator:Paketti:Set Selected Instrument Transpose to +106
Sample Navigator:Paketti:Set Selected Instrument Transpose to +107
Sample Navigator:Paketti:Set Selected Instrument Transpose to +108
Sample Navigator:Paketti:Set Selected Instrument Transpose to +109
Sample Navigator:Paketti:Set Selected Instrument Transpose to +11
Sample Navigator:Paketti:Set Selected Instrument Transpose to +110
Sample Navigator:Paketti:Set Selected Instrument Transpose to +111
Sample Navigator:Paketti:Set Selected Instrument Transpose to +112
Sample Navigator:Paketti:Set Selected Instrument Transpose to +113
Sample Navigator:Paketti:Set Selected Instrument Transpose to +114
Sample Navigator:Paketti:Set Selected Instrument Transpose to +115
Sample Navigator:Paketti:Set Selected Instrument Transpose to +116
Sample Navigator:Paketti:Set Selected Instrument Transpose to +117
Sample Navigator:Paketti:Set Selected Instrument Transpose to +118
Sample Navigator:Paketti:Set Selected Instrument Transpose to +119
Sample Navigator:Paketti:Set Selected Instrument Transpose to +12
Sample Navigator:Paketti:Set Selected Instrument Transpose to +120
Sample Navigator:Paketti:Set Selected Instrument Transpose to +13
Sample Navigator:Paketti:Set Selected Instrument Transpose to +14
Sample Navigator:Paketti:Set Selected Instrument Transpose to +15
Sample Navigator:Paketti:Set Selected Instrument Transpose to +16
Sample Navigator:Paketti:Set Selected Instrument Transpose to +17
Sample Navigator:Paketti:Set Selected Instrument Transpose to +18
Sample Navigator:Paketti:Set Selected Instrument Transpose to +19
Sample Navigator:Paketti:Set Selected Instrument Transpose to +2
Sample Navigator:Paketti:Set Selected Instrument Transpose to +20
Sample Navigator:Paketti:Set Selected Instrument Transpose to +21
Sample Navigator:Paketti:Set Selected Instrument Transpose to +22
Sample Navigator:Paketti:Set Selected Instrument Transpose to +23
Sample Navigator:Paketti:Set Selected Instrument Transpose to +24
Sample Navigator:Paketti:Set Selected Instrument Transpose to +25
Sample Navigator:Paketti:Set Selected Instrument Transpose to +26
Sample Navigator:Paketti:Set Selected Instrument Transpose to +27
Sample Navigator:Paketti:Set Selected Instrument Transpose to +28
Sample Navigator:Paketti:Set Selected Instrument Transpose to +29
Sample Navigator:Paketti:Set Selected Instrument Transpose to +3
Sample Navigator:Paketti:Set Selected Instrument Transpose to +30
Sample Navigator:Paketti:Set Selected Instrument Transpose to +31
Sample Navigator:Paketti:Set Selected Instrument Transpose to +32
Sample Navigator:Paketti:Set Selected Instrument Transpose to +33
Sample Navigator:Paketti:Set Selected Instrument Transpose to +34
Sample Navigator:Paketti:Set Selected Instrument Transpose to +35
Sample Navigator:Paketti:Set Selected Instrument Transpose to +36
Sample Navigator:Paketti:Set Selected Instrument Transpose to +37
Sample Navigator:Paketti:Set Selected Instrument Transpose to +38
Sample Navigator:Paketti:Set Selected Instrument Transpose to +39
Sample Navigator:Paketti:Set Selected Instrument Transpose to +4
Sample Navigator:Paketti:Set Selected Instrument Transpose to +40
Sample Navigator:Paketti:Set Selected Instrument Transpose to +41
Sample Navigator:Paketti:Set Selected Instrument Transpose to +42
Sample Navigator:Paketti:Set Selected Instrument Transpose to +43
Sample Navigator:Paketti:Set Selected Instrument Transpose to +44
Sample Navigator:Paketti:Set Selected Instrument Transpose to +45
Sample Navigator:Paketti:Set Selected Instrument Transpose to +46
Sample Navigator:Paketti:Set Selected Instrument Transpose to +47
Sample Navigator:Paketti:Set Selected Instrument Transpose to +48
Sample Navigator:Paketti:Set Selected Instrument Transpose to +49
Sample Navigator:Paketti:Set Selected Instrument Transpose to +5
Sample Navigator:Paketti:Set Selected Instrument Transpose to +50
Sample Navigator:Paketti:Set Selected Instrument Transpose to +51
Sample Navigator:Paketti:Set Selected Instrument Transpose to +52
Sample Navigator:Paketti:Set Selected Instrument Transpose to +53
Sample Navigator:Paketti:Set Selected Instrument Transpose to +54
Sample Navigator:Paketti:Set Selected Instrument Transpose to +55
Sample Navigator:Paketti:Set Selected Instrument Transpose to +56
Sample Navigator:Paketti:Set Selected Instrument Transpose to +57
Sample Navigator:Paketti:Set Selected Instrument Transpose to +58
Sample Navigator:Paketti:Set Selected Instrument Transpose to +59
Sample Navigator:Paketti:Set Selected Instrument Transpose to +6
Sample Navigator:Paketti:Set Selected Instrument Transpose to +60
Sample Navigator:Paketti:Set Selected Instrument Transpose to +61
Sample Navigator:Paketti:Set Selected Instrument Transpose to +62
Sample Navigator:Paketti:Set Selected Instrument Transpose to +63
Sample Navigator:Paketti:Set Selected Instrument Transpose to +64
Sample Navigator:Paketti:Set Selected Instrument Transpose to +65
Sample Navigator:Paketti:Set Selected Instrument Transpose to +66
Sample Navigator:Paketti:Set Selected Instrument Transpose to +67
Sample Navigator:Paketti:Set Selected Instrument Transpose to +68
Sample Navigator:Paketti:Set Selected Instrument Transpose to +69
Sample Navigator:Paketti:Set Selected Instrument Transpose to +7
Sample Navigator:Paketti:Set Selected Instrument Transpose to +70
Sample Navigator:Paketti:Set Selected Instrument Transpose to +71
Sample Navigator:Paketti:Set Selected Instrument Transpose to +72
Sample Navigator:Paketti:Set Selected Instrument Transpose to +73
Sample Navigator:Paketti:Set Selected Instrument Transpose to +74
Sample Navigator:Paketti:Set Selected Instrument Transpose to +75
Sample Navigator:Paketti:Set Selected Instrument Transpose to +76
Sample Navigator:Paketti:Set Selected Instrument Transpose to +77
Sample Navigator:Paketti:Set Selected Instrument Transpose to +78
Sample Navigator:Paketti:Set Selected Instrument Transpose to +79
Sample Navigator:Paketti:Set Selected Instrument Transpose to +8
Sample Navigator:Paketti:Set Selected Instrument Transpose to +80
Sample Navigator:Paketti:Set Selected Instrument Transpose to +81
Sample Navigator:Paketti:Set Selected Instrument Transpose to +82
Sample Navigator:Paketti:Set Selected Instrument Transpose to +83
Sample Navigator:Paketti:Set Selected Instrument Transpose to +84
Sample Navigator:Paketti:Set Selected Instrument Transpose to +85
Sample Navigator:Paketti:Set Selected Instrument Transpose to +86
Sample Navigator:Paketti:Set Selected Instrument Transpose to +87
Sample Navigator:Paketti:Set Selected Instrument Transpose to +88
Sample Navigator:Paketti:Set Selected Instrument Transpose to +89
Sample Navigator:Paketti:Set Selected Instrument Transpose to +9
Sample Navigator:Paketti:Set Selected Instrument Transpose to +90
Sample Navigator:Paketti:Set Selected Instrument Transpose to +91
Sample Navigator:Paketti:Set Selected Instrument Transpose to +92
Sample Navigator:Paketti:Set Selected Instrument Transpose to +93
Sample Navigator:Paketti:Set Selected Instrument Transpose to +94
Sample Navigator:Paketti:Set Selected Instrument Transpose to +95
Sample Navigator:Paketti:Set Selected Instrument Transpose to +96
Sample Navigator:Paketti:Set Selected Instrument Transpose to +97
Sample Navigator:Paketti:Set Selected Instrument Transpose to +98
Sample Navigator:Paketti:Set Selected Instrument Transpose to +99
Sample Navigator:Paketti:Set Selected Instrument Transpose to -1
Sample Navigator:Paketti:Set Selected Instrument Transpose to -10
Sample Navigator:Paketti:Set Selected Instrument Transpose to -100
Sample Navigator:Paketti:Set Selected Instrument Transpose to -101
Sample Navigator:Paketti:Set Selected Instrument Transpose to -102
Sample Navigator:Paketti:Set Selected Instrument Transpose to -103
Sample Navigator:Paketti:Set Selected Instrument Transpose to -104
Sample Navigator:Paketti:Set Selected Instrument Transpose to -105
Sample Navigator:Paketti:Set Selected Instrument Transpose to -106
Sample Navigator:Paketti:Set Selected Instrument Transpose to -107
Sample Navigator:Paketti:Set Selected Instrument Transpose to -108
Sample Navigator:Paketti:Set Selected Instrument Transpose to -109
Sample Navigator:Paketti:Set Selected Instrument Transpose to -11
Sample Navigator:Paketti:Set Selected Instrument Transpose to -110
Sample Navigator:Paketti:Set Selected Instrument Transpose to -111
Sample Navigator:Paketti:Set Selected Instrument Transpose to -112
Sample Navigator:Paketti:Set Selected Instrument Transpose to -113
Sample Navigator:Paketti:Set Selected Instrument Transpose to -114
Sample Navigator:Paketti:Set Selected Instrument Transpose to -115
Sample Navigator:Paketti:Set Selected Instrument Transpose to -116
Sample Navigator:Paketti:Set Selected Instrument Transpose to -117
Sample Navigator:Paketti:Set Selected Instrument Transpose to -118
Sample Navigator:Paketti:Set Selected Instrument Transpose to -119
Sample Navigator:Paketti:Set Selected Instrument Transpose to -12
Sample Navigator:Paketti:Set Selected Instrument Transpose to -120
Sample Navigator:Paketti:Set Selected Instrument Transpose to -13
Sample Navigator:Paketti:Set Selected Instrument Transpose to -14
Sample Navigator:Paketti:Set Selected Instrument Transpose to -15
Sample Navigator:Paketti:Set Selected Instrument Transpose to -16
Sample Navigator:Paketti:Set Selected Instrument Transpose to -17
Sample Navigator:Paketti:Set Selected Instrument Transpose to -18
Sample Navigator:Paketti:Set Selected Instrument Transpose to -19
Sample Navigator:Paketti:Set Selected Instrument Transpose to -2
Sample Navigator:Paketti:Set Selected Instrument Transpose to -20
Sample Navigator:Paketti:Set Selected Instrument Transpose to -21
Sample Navigator:Paketti:Set Selected Instrument Transpose to -22
Sample Navigator:Paketti:Set Selected Instrument Transpose to -23
Sample Navigator:Paketti:Set Selected Instrument Transpose to -24
Sample Navigator:Paketti:Set Selected Instrument Transpose to -25
Sample Navigator:Paketti:Set Selected Instrument Transpose to -26
Sample Navigator:Paketti:Set Selected Instrument Transpose to -27
Sample Navigator:Paketti:Set Selected Instrument Transpose to -28
Sample Navigator:Paketti:Set Selected Instrument Transpose to -29
Sample Navigator:Paketti:Set Selected Instrument Transpose to -3
Sample Navigator:Paketti:Set Selected Instrument Transpose to -30
Sample Navigator:Paketti:Set Selected Instrument Transpose to -31
Sample Navigator:Paketti:Set Selected Instrument Transpose to -32
Sample Navigator:Paketti:Set Selected Instrument Transpose to -33
Sample Navigator:Paketti:Set Selected Instrument Transpose to -34
Sample Navigator:Paketti:Set Selected Instrument Transpose to -35
Sample Navigator:Paketti:Set Selected Instrument Transpose to -36
Sample Navigator:Paketti:Set Selected Instrument Transpose to -37
Sample Navigator:Paketti:Set Selected Instrument Transpose to -38
Sample Navigator:Paketti:Set Selected Instrument Transpose to -39
Sample Navigator:Paketti:Set Selected Instrument Transpose to -4
Sample Navigator:Paketti:Set Selected Instrument Transpose to -40
Sample Navigator:Paketti:Set Selected Instrument Transpose to -41
Sample Navigator:Paketti:Set Selected Instrument Transpose to -42
Sample Navigator:Paketti:Set Selected Instrument Transpose to -43
Sample Navigator:Paketti:Set Selected Instrument Transpose to -44
Sample Navigator:Paketti:Set Selected Instrument Transpose to -45
Sample Navigator:Paketti:Set Selected Instrument Transpose to -46
Sample Navigator:Paketti:Set Selected Instrument Transpose to -47
Sample Navigator:Paketti:Set Selected Instrument Transpose to -48
Sample Navigator:Paketti:Set Selected Instrument Transpose to -49
Sample Navigator:Paketti:Set Selected Instrument Transpose to -5
Sample Navigator:Paketti:Set Selected Instrument Transpose to -50
Sample Navigator:Paketti:Set Selected Instrument Transpose to -51
Sample Navigator:Paketti:Set Selected Instrument Transpose to -52
Sample Navigator:Paketti:Set Selected Instrument Transpose to -53
Sample Navigator:Paketti:Set Selected Instrument Transpose to -54
Sample Navigator:Paketti:Set Selected Instrument Transpose to -55
Sample Navigator:Paketti:Set Selected Instrument Transpose to -56
Sample Navigator:Paketti:Set Selected Instrument Transpose to -57
Sample Navigator:Paketti:Set Selected Instrument Transpose to -58
Sample Navigator:Paketti:Set Selected Instrument Transpose to -59
Sample Navigator:Paketti:Set Selected Instrument Transpose to -6
Sample Navigator:Paketti:Set Selected Instrument Transpose to -60
Sample Navigator:Paketti:Set Selected Instrument Transpose to -61
Sample Navigator:Paketti:Set Selected Instrument Transpose to -62
Sample Navigator:Paketti:Set Selected Instrument Transpose to -63
Sample Navigator:Paketti:Set Selected Instrument Transpose to -64
Sample Navigator:Paketti:Set Selected Instrument Transpose to -65
Sample Navigator:Paketti:Set Selected Instrument Transpose to -66
Sample Navigator:Paketti:Set Selected Instrument Transpose to -67
Sample Navigator:Paketti:Set Selected Instrument Transpose to -68
Sample Navigator:Paketti:Set Selected Instrument Transpose to -69
Sample Navigator:Paketti:Set Selected Instrument Transpose to -7
Sample Navigator:Paketti:Set Selected Instrument Transpose to -70
Sample Navigator:Paketti:Set Selected Instrument Transpose to -71
Sample Navigator:Paketti:Set Selected Instrument Transpose to -72
Sample Navigator:Paketti:Set Selected Instrument Transpose to -73
Sample Navigator:Paketti:Set Selected Instrument Transpose to -74
Sample Navigator:Paketti:Set Selected Instrument Transpose to -75
Sample Navigator:Paketti:Set Selected Instrument Transpose to -76
Sample Navigator:Paketti:Set Selected Instrument Transpose to -77
Sample Navigator:Paketti:Set Selected Instrument Transpose to -78
Sample Navigator:Paketti:Set Selected Instrument Transpose to -79
Sample Navigator:Paketti:Set Selected Instrument Transpose to -8
Sample Navigator:Paketti:Set Selected Instrument Transpose to -80
Sample Navigator:Paketti:Set Selected Instrument Transpose to -81
Sample Navigator:Paketti:Set Selected Instrument Transpose to -82
Sample Navigator:Paketti:Set Selected Instrument Transpose to -83
Sample Navigator:Paketti:Set Selected Instrument Transpose to -84
Sample Navigator:Paketti:Set Selected Instrument Transpose to -85
Sample Navigator:Paketti:Set Selected Instrument Transpose to -86
Sample Navigator:Paketti:Set Selected Instrument Transpose to -87
Sample Navigator:Paketti:Set Selected Instrument Transpose to -88
Sample Navigator:Paketti:Set Selected Instrument Transpose to -89
Sample Navigator:Paketti:Set Selected Instrument Transpose to -9
Sample Navigator:Paketti:Set Selected Instrument Transpose to -90
Sample Navigator:Paketti:Set Selected Instrument Transpose to -91
Sample Navigator:Paketti:Set Selected Instrument Transpose to -92
Sample Navigator:Paketti:Set Selected Instrument Transpose to -93
Sample Navigator:Paketti:Set Selected Instrument Transpose to -94
Sample Navigator:Paketti:Set Selected Instrument Transpose to -95
Sample Navigator:Paketti:Set Selected Instrument Transpose to -96
Sample Navigator:Paketti:Set Selected Instrument Transpose to -97
Sample Navigator:Paketti:Set Selected Instrument Transpose to -98
Sample Navigator:Paketti:Set Selected Instrument Transpose to -99
Sample Navigator:Paketti:Set Selected Instrument Transpose to 0
Sample Navigator:Paketti:Set Selected Instrument Transpose to 0 (Reset)
```

## Typo-fixed — `DSP Device:` → `DSP Chain:`

```
DSP Device:Paketti:Hipass (Preset++)
```

## How this stays true

`.spine/build.py` (the GitHub Action) re-runs the harness on every push. Any new binding under an invalid scope that has no remap entry is dropped and reappears in the dropped list above. Keep keybinding scopes to the 16 valid categories.
