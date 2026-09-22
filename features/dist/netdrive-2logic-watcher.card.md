# Report Card — NetDrive 2logic watcher

> Source: `features/netdrive-2logic-watcher.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user recording audio into a known handoff folder, I want Paketti to notice new files under /private/tmp/netdrive/2logic, So that Renoise can load each completed take without a manual file picker.

**Grades:** @code-verified × 4 · @runtime-untested × 4 · @shipped × 4 · @stock × 1

**Scenarios: 5**


---


## 1. Watch the default 2logic folder

`@shipped @code-verified @runtime-untested`


- Given the NetDrive watcher has no custom folder configured
- When the watcher starts
- Then it watches /private/tmp/netdrive/2logic

<sub>cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherFolder (~line 251) — defaults the watch path to /private/tmp/netdrive/2logic · PakettiSamples.lua PakettiNetDriveWatcherGetFolder (~line 3919) — reads the configured folder with the same default fallback</sub>


## 2. Ignore existing files and load only new stable arrivals

`@shipped @code-verified @runtime-untested`


- Given the watch folder already contains audio files before the watcher starts
- When the watcher begins polling
- Then those existing files are marked known
- And only later audio files that remain stable for the configured delay are loaded

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4085) — snapshots existing files as known when the watcher starts · PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4037) — waits for unchanged size and mtime before loading</sub>


## 3. Load each arrival as a fresh Paketti instrument

`@shipped @code-verified @runtime-untested`


- Given a new audio file appears in the watch folder
- When the file is stable and loadable by Renoise
- Then Paketti inserts a new instrument after the current instrument
- And it loads the file into sample slot 1
- And it names the sample and instrument from the audio filename

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherLoadFile (~line 3988) — inserts a new instrument, applies the default XRNI, loads the sample, and applies loader settings</sub>


## 4. Expose manual control for the watcher

`@shipped @code-verified @runtime-untested`


- Given Paketti has loaded its sample tools
- When the user wants to control the NetDrive watcher
- Then the watcher can be toggled from a Global keybinding, MIDI trigger mapping, and Tools menu entry
- And the watched folder can be changed from a Tools menu entry

<sub>cite: PakettiSamples.lua keybinding and menu registrations (~line 4165) — toggle, MIDI mapping, menu entry, and folder selector</sub>


## 5. Existing sample loaders remain separate

`@stock`


- Given the user invokes an existing random sample loader
- When that loader prompts for or receives a folder
- Then the NetDrive watcher state is not required for that manual workflow

<sub>cite: PakettiSamples.lua loadRandomSample (~line 4829) — existing manual random-folder loader</sub>

