# Report Card — NetDrive 2logic watcher

> Source: `features/netdrive-2logic-watcher.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user recording audio into a known handoff folder, I want Paketti to notice new files under /private/tmp/netdrive/2logic, So that Renoise can load each completed take without a manual file picker.

**Grades:** @code-verified × 11 · @runtime-untested × 11 · @shipped × 11 · @stock × 1

**Scenarios: 12**


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

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherVolumeMounted (~line 3977) — proves the /Volumes mount root before touching the configured child folder · PakettiSamples.lua PakettiNetDriveWatcherTick (~line 4140) — backs off for disconnected or failed folder scans · PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4349) — starts in paused/offline mode when the configured /Volumes mount is absent</sub>


## 6. Accept a readable NetDrive folder only after the mount root exists

`@shipped @code-verified @runtime-untested`


- Given the configured watch folder is /Volumes/netdrive/2logic
- And the /Volumes/netdrive mount root exists
- And the 2logic folder exists and is readable
- When Renoise's /Volumes listing does not report the netdrive mount exactly
- Then the watcher still treats the configured folder as available
- And it proceeds to scan the folder for loadable audio files
- But if /Volumes/netdrive is absent, the watcher does not probe /Volumes/netdrive/2logic

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherPathExists (~line 3968) — safely checks existence behind pcall before using fallback paths · PakettiSamples.lua PakettiNetDriveWatcherVolumeMounted (~line 3977) — treats trailing-slash mount names as mounted, then falls back via /Volumes/netdrive before /Volumes/netdrive/2logic · preferences.xml pakettiNetDriveWatcherFolder (~line 1140) — stores Esa's /Volumes/netdrive/2logic folder selection</sub>


## 7. Load each arrival as a fresh Paketti instrument

`@shipped @code-verified @runtime-untested`


- Given a new audio file appears in the watch folder
- When the file is stable and loadable by Renoise
- Then Paketti inserts a new instrument after the current instrument
- And it loads the file into sample slot 1
- And it sets the loaded sample loop mode to Forward Loop after applying loader settings, which is Renoise's enabled loop state
- And it enables Autoseek regardless of the general loader preference
- And it names the sample and instrument from the audio filename

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherLoadFile (~line 4121) — inserts a new instrument, loads the sample, applies loader settings, then forces Forward Loop and Autoseek</sub>


## 8. Every file load goes through a ProcessSlicer so the UI never freezes

`@shipped @code-verified @runtime-untested`


- Given one or more new files become eligible to load (a single take or a whole burst at once)
- When the watcher loads them
- Then each file is loaded inside a ProcessSlicer coroutine that yields between files
- And a progress dialog shows the filename and how many remain, and can be cancelled
- And the poll timer does not start a second load pass while a load is running
- And cancelling abandons the rest of the queue rather than force-loading it
- And if the watched volume drops out mid-load, the drain stops before statting or loading off the dead mount
- And it does not hang the app_idle callback long enough to trip Renoise's "tool became unresponsive" watchdog
- And control returns to the poll tick's offline backoff, which resumes the remaining files when the volume comes back

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherEnqueue (~line 4302) — every eligible file is queued, never loaded inline · PakettiSamples.lua PakettiNetDriveWatcherProcessQueue (~line 4226) — one coroutine drains the queue, yielding between files, with a cancelable progress dialog · PakettiSamples.lua PakettiNetDriveWatcher.loading guard (~line 4228) — the poll timer never starts a second load pass while one runs</sub>


## 9. A durable load-after cutoff persists so restarts do not start from scratch

`@shipped @code-verified @runtime-untested`


- Given the watcher has a persisted load-after cutoff
- When the watcher starts or scans
- Then no file modified strictly before the cutoff is ever loaded
- And each successfully loaded file advances the cutoff to its modification time and saves preferences.xml
- And restarting Renoise resumes from the stored cutoff instead of reloading or re-baselining everything
- And the first time a folder is watched the cutoff defaults to now, so the folder's existing history is not ingested
- And the user can reset the cutoff to now, or clear it to make every file in the folder eligible

<sub>cite: Paketti0G01_Loader.lua pakettiNetDriveWatcherLoadAfter (~line 255) — epoch cutoff persisted in preferences.xml · PakettiSamples.lua PakettiNetDriveWatcherBeforeCutoff (~line 4214) — files modified before the cutoff are never loaded · PakettiSamples.lua PakettiNetDriveWatcherAdvanceLoadAfter (~line 4205) — the cutoff advances to each loaded file's mtime and is saved · PakettiSamples.lua PakettiNetDriveWatcherStart (~line 4567) — first watch of a folder sets the cutoff to now; later runs resume from the stored cutoff · PakettiSamples.lua menu + keybinding (~line 4722) — "Set NetDrive Load-After Cutoff to Now" and "Clear ... (Load All)"</sub>


## 10. Create an adjacent sequencer trigger track for each loaded arrival

`@shipped @code-verified @runtime-untested`


- Given a new audio file has loaded from the watch folder
- When Paketti creates the playback trigger
- Then it inserts a new sequencer track directly after the current sequencer-track anchor
- And it never uses a group, master, or send track as the trigger track
- And row 1 of the current pattern contains C-4 for the loaded instrument
- And effect column 1 on that row contains 0G01

<sub>cite: PakettiSamples.lua PakettiNetDriveWatcherCreateTriggerTrack (~line 4014) — inserts the new track beside the current sequencer track and writes C-4 + 0G01 · PakettiSamples.lua PakettiNetDriveWatcherFindSequencerTrack (~line 3993) — resolves non-sequencer selections to a real sequencer-track anchor</sub>


## 11. Expose manual control for the watcher

`@shipped @code-verified @runtime-untested`


- Given Paketti has loaded its sample tools
- When the user wants to control the NetDrive watcher
- Then the watcher can be toggled from a Global keybinding, MIDI trigger mapping, and Tools menu entry
- And the watched folder can be changed from a Tools menu entry

<sub>cite: PakettiSamples.lua keybinding and menu registrations (~line 4165) — toggle, MIDI mapping, menu entry, and folder selector</sub>


## 12. Existing sample loaders remain separate

`@stock`


- Given the user invokes an existing random sample loader
- When that loader prompts for or receives a folder
- Then the NetDrive watcher state is not required for that manual workflow

<sub>cite: PakettiSamples.lua loadRandomSample (~line 4829) — existing manual random-folder loader</sub>

