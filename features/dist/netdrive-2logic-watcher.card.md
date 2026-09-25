# Report Card — NetDrive 2logic watcher

> Source: `features/netdrive-2logic-watcher.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user recording audio into a known handoff folder, I want Paketti to notice new files under /private/tmp/netdrive/2logic, So that Renoise can load each completed take without a manual file picker.

**Grades:** @code-verified × 8 · @runtime-untested × 8 · @shipped × 8 · @stock × 1

**Scenarios: 9**


---


## 1. Keep the global default off while allowing Esa's local preference to arm it

`@shipped @code-verified @runtime-untested`


- Given Paketti is installed on a new machine with no saved preference
- When preferences are initialized
- Then the NetDrive watcher is off by default
- And Esa's local saved preference can still turn it on

<sub>cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherEnabled (~line 250) — default schema is off for new installs · preferences.xml pakettiNetDriveWatcherEnabled (~line 3054) — Esa's local tool preferences arm the watcher</sub>


## 2. Watch the default 2logic folder when armed

`@shipped @code-verified @runtime-untested`


- Given the NetDrive watcher has no custom folder configured
- When the watcher starts
- Then it watches /private/tmp/netdrive/2logic

<sub>cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherFolder (~line 251) — defaults the watch path to /private/tmp/netdrive/2logic · PakettiSamples.lua PakettiNetDriveWatcherGetFolder (~line 3919) — reads the configured folder with the same default fallback</sub>


## 3. Ignore old existing files and load changed file signatures

`@shipped @code-verified @runtime-untested`


- Given the watch folder already contains audio files before the watcher starts
- When the watcher begins polling
- Then old existing files are marked known
- And the newest file is loaded once if its size/mtime signature has not already been loaded
- And placeholder-known files written after the watcher started are queued instead of silently baselined
- And later new or overwritten audio files that remain stable for the configured delay are loaded

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4207) — snapshots old existing file signatures and leaves the newest unseen signature eligible · PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4085) — waits for unchanged size and mtime before loading new or rewritten signatures · PakettiSamples.lua known_at_startup handling (~line 4195) — baselines genuinely old placeholder files but queues files written after watcher start</sub>


## 4. Poll at the selected interval and prioritize newest takes

`@shipped @code-verified @runtime-untested`


- Given the watch folder contains thousands of older known files
- When a new take appears near the newest end of the folder's sorted filenames
- Then the watcher stats that newest-looking file before the rotating old-file sweep
- And the user can choose a poll interval of 0.5, 1, 5, or 10 seconds from Paketti Preferences
- And changing the preference refreshes the running watcher timer immediately

<sub>cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherPollSeconds (~line 253) — default schema polls once per second · Paketti0G01_Loader.lua pakettiPreferences Sync Folder Poll (~line 1634) — exposes 0.5, 1, 5, and 10 second choices · PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4135) — stats newest-looking known filenames before the older-file sweep · PakettiSamples.lua PakettiNetDriveWatcherRefreshTimer (~line 4364) — reapplies the selected timer interval while the watcher is running</sub>


## 5. Pause safely when the watched volume disconnects

`@shipped @code-verified @runtime-untested`


- Given the watched folder is on a /Volumes mount
- When that volume disconnects while Automatically Sync Folder to Samples is enabled
- Then the watcher pauses and reports the folder as unavailable
- And it retries on a slow 10-second backoff instead of touching the dead mount every poll tick
- And the Paketti script remains armed so the watcher can resume when the volume returns

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherVolumeMounted (~line 3967) — checks /Volumes for the mount name before touching the watched path · PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4140) — backs off for disconnected or failed folder scans · PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4349) — starts in paused/offline mode when the configured /Volumes mount is absent</sub>


## 6. Load each arrival as a fresh Paketti instrument

`@shipped @code-verified @runtime-untested`


- Given a new audio file appears in the watch folder
- When the file is stable and loadable by Renoise
- Then Paketti inserts a new instrument after the current instrument
- And it loads the file into sample slot 1
- And it names the sample and instrument from the audio filename

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherLoadFile (~line 3988) — inserts a new instrument, applies the default XRNI, loads the sample, and applies loader settings</sub>


## 7. Create an adjacent sequencer trigger track for each loaded arrival

`@shipped @code-verified @runtime-untested`


- Given a new audio file has loaded from the watch folder
- When Paketti creates the playback trigger
- Then it inserts a new sequencer track directly after the current sequencer-track anchor
- And it never uses a group, master, or send track as the trigger track
- And row 1 of the current pattern contains C-4 for the loaded instrument
- And effect column 1 on that row contains 0G01

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherCreateTriggerTrack (~line 4014) — inserts the new track beside the current sequencer track and writes C-4 + 0G01 · PakettiSamples.lua PakettiNetDriveWatcherFindSequencerTrack (~line 3993) — resolves non-sequencer selections to a real sequencer-track anchor</sub>


## 8. Expose manual control for the watcher

`@shipped @code-verified @runtime-untested`


- Given Paketti has loaded its sample tools
- When the user wants to control the NetDrive watcher
- Then the watcher can be toggled from a Global keybinding, MIDI trigger mapping, and Tools menu entry
- And the watched folder can be changed from a Tools menu entry

<sub>cite: PakettiSamples.lua keybinding and menu registrations (~line 4165) — toggle, MIDI mapping, menu entry, and folder selector</sub>


## 9. Existing sample loaders remain separate

`@stock`


- Given the user invokes an existing random sample loader
- When that loader prompts for or receives a folder
- Then the NetDrive watcher state is not required for that manual workflow

<sub>cite: PakettiSamples.lua loadRandomSample (~line 4829) — existing manual random-folder loader</sub>

