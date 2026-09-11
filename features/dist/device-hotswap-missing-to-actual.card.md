# Report Card — Device hotswap — missing plugins → actually-installed equivalents

> Source: `features/device-hotswap-missing-to-actual.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Mixer

**Grades:** @designed × 9

**Scenarios: 9**


---


## 1. Scan a folder of .xrns and report missing devices per song

`@designed`


- Given a folder containing many .xrns files
- When the user runs "Device Hotswap: Scan Folder for Missing Devices"
- Then each .xrns is dissected (via the XRNS probe path) for its referenced
- VST / VSTi / AU / native device identifiers
- And each identifier is checked against this machine's available_device_infos
- and available_plugin_infos
- And a report lists, per song, which devices are PRESENT vs MISSING


## 2. Scan the currently-open song only

`@designed`


- Given a song is loaded that references an uninstalled VST effect
- When the user runs "Device Hotswap: Scan Current Song"
- Then the report flags that device as missing
- And proposes an installed equivalent if the legacy->actual map has one


## 3. A curated "this legacy -> this actual" map drives the swap

`@designed`


- Given a registry of mappings, each: { from = "<missing device id>",
- to = "<installed device id>", param_map = optional name->name table }
- When a missing device matches a "from" entry
- Then its "to" device is chosen as the swap target
- And the optional param_map renames parameters whose names differ between
- the VST and the AU (e.g. "Mix" on the VST -> "Dry/Wet" on the AU)


## 4. User adds a mapping from an unresolved missing device

`@designed`


- Given the scan found a missing device with no mapping
- When the user picks an installed device as its equivalent and saves it
- Then a new legacy->actual entry is written to the registry (persisted in
- preferences) and reused on every future song


## 5. Auto-suggest a mapping when names obviously match

`@designed`


- Given a missing "FooReverb VST" and an installed "FooReverb (AU)"
- When the scan runs
- Then the engine proposes the match automatically (fuzzy name match),
- pending one-click user confirmation — never a silent swap


## 6. Hotswap a missing device and carry its settings across by name

`@designed`


- Given a track whose chain has a missing VST effect at slot N
- And the song.xml holds that VST's saved parameter name/value pairs
- And the legacy->actual map points it at an installed AU equivalent
- When the user runs "Device Hotswap: Swap & Inject Current Track"
- Then the dead device is removed from slot N
- And the AU equivalent is inserted at slot N (same position in the chain)
- And for each saved parameter, the value is written to the AU parameter with
- the matching name (via param_map if names differ)
- And parameters with no name match are reported as unmapped (not guessed)


## 7. Positional fallback when both expose the same parameter count

`@designed`


- Given a missing device and its target both expose exactly 8 parameters
- And no reliable name match exists between them
- When the user opts into positional injection
- Then saved parameter i is written to target parameter i, 1..8
- And the user is warned this is positional (order-based), not name-based


## 8. Batch hotswap across a whole song

`@designed`


- Given a song with several missing devices that all have mappings
- When the user runs "Device Hotswap: Swap & Inject Whole Song"
- Then every mapped missing device is swapped and injected in one undoable step
- And any unmapped missing devices are left in place and listed for follow-up


## 9. Never destroy the original on an ambiguous swap

`@designed`


- Given a missing device whose mapping or parameter match is uncertain
- When a swap is attempted
- Then the engine requires explicit confirmation before deleting anything
- And offers to keep the dead device (muted/bypassed) alongside the new one
- so nothing is lost if the swap sounds wrong

