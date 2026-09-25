# NetDrive 2logic Watcher Session

## How to get back

- Date: 2026-09-22 16:52:59 EEST (+0300)
- Transcript path: unavailable from this Codex runtime
- Session ID: unavailable from this Codex runtime
- Resume command: unavailable because the session ID is not exposed here
- Source bundle: unavailable; this card records the faithful working summary below instead of a fabricated transcript link

## Request

Esa asked for the “meat of the matter”: define a folder that is caught when a new recorded file appears there, and have Renoise load that file through Paketti. The concrete folder named in the request was `/private/tmp/netdrive/2logic`.

On 2026-09-23 at 23:18 EEST, Esa asked for one additional behavior on the “Automatically Sync Folder to Samples Toggle”: when a new sample appears in the sync folder, Paketti should create a new sequencer track beside the current track and write a `C-4` trigger plus `0G01` to row 1 of the current pattern for the loaded sample.

On 2026-09-24 at 15:13 EEST, Esa asked how often the watcher polls because a just-written sample took about 10 seconds to appear. After seeing that the old background overwrite sweep only statted 5 known files per 1-second tick, he asked for a Paketti Preferences control with 0.5, 1, 5, and 10 second choices, and challenged the watcher to pick the newest file first instead of walking thousands of older files in order.

Later on 2026-09-24 at 15:19 EEST, Esa reported the sharper failure: he disk-wrote a file and Paketti did not catch it until he toggled Automatically Sync Folder to Samples off and on again. That identified the real bug: files marked with the lazy `known_at_startup` placeholder were being statted for the first time, converted to a real known signature, and not loaded. Restarting the watcher worked because startup's newest-file path left the latest changed signature eligible.

At 15:22 EEST, Esa disconnected the NetDrive and Renoise showed the scripting watchdog dialog for `main.lua` being busy/unresponsive. That exposed a second safety issue: `pcall` can catch Lua errors from `os.filenames` and `io.stat`, but it cannot stop a disconnected network filesystem call from blocking Renoise's scripting thread. The watcher needs to avoid touching the dead mount in the first place when `/Volumes/<name>` is absent, and it needs to back off rather than retrying a dead path at the fast poll interval.

## Decisions

- The watcher belongs in `PakettiSamples.lua`, because that file already owns the Paketti sample-loading behavior and loader-setting application.
- Preferences belong in `Paketti0G01_Loader.lua`, because it declares the root `ScriptingToolPreferences` document.
- The default folder is exactly `/private/tmp/netdrive/2logic`, but a menu command can change it.
- The watcher ignores files that were already present when it starts, so toggling it on does not import the whole folder.
- New files are not loaded immediately. They must keep the same size and mtime for the configured stability delay, defaulting to one second, so partially written recordings are not grabbed mid-write.
- The poll interval is separate from the stability delay. It defaults to one second and is selectable from Paketti Preferences as 0.5, 1, 5, or 10 seconds.
- The watcher still keeps a small rotating sweep for old-file overwrites, but each tick now checks the newest-looking known filenames first so fresh sequential takes are not trapped behind thousands of stale files.
- A lazy startup placeholder is only silently baselined when its `mtime` is older than the watcher start time. If a placeholder-known file was written after the watcher started, it goes through the normal pending/stable/load path.
- `/Volumes/...` watcher paths are preflighted by checking the local `/Volumes` listing for the mount name before touching the watched folder. If the volume is absent or a scan fails, the watcher stays armed but pauses on a 10-second offline backoff.
- Each new file is loaded into a fresh Paketti instrument after the current selection, using the default XRNI and existing loader settings.
- Each newly loaded file also gets a trigger track. The trigger track must be a sequencer track, not a group, master, or send track.
- If the current selection is not a sequencer track, the watcher anchors beside the nearest earlier sequencer track, falling back to the first sequencer track.
- The trigger is always written to row 1 of the current pattern, with visible note/effect columns ensured before writing.

## Work Performed

- Added `pakettiNetDriveWatcherEnabled`, `pakettiNetDriveWatcherFolder`, and `pakettiNetDriveWatcherStableSeconds` preferences.
- Added `pakettiNetDriveWatcherPollSeconds` and a Paketti Preferences popup for 0.5, 1, 5, and 10 second folder polling.
- Added `PakettiNetDriveWatcher*` functions for scanning, stability debounce, loading, start/stop/toggle, and folder selection.
- Added newest-first known-file statting before the low-cost rotating old-file sweep.
- Added `PakettiNetDriveWatcherRefreshTimer` so changing the poll interval retimes a running watcher immediately.
- Fixed the `known_at_startup` swallow bug: changed placeholder-known files are now queued when their file mtime indicates they were written after the watcher started.
- Added `/Volumes` mount preflight, offline status, and 10-second retry backoff so disconnecting the watched volume does not keep hammering a dead network path from Renoise's UI thread.
- Added a Global keybinding, MIDI trigger mapping, and Tools menu entries for toggling and configuring the watcher.
- Added a report-card back-link in the watcher code.
- Added `PakettiNetDriveWatcherFindSequencerTrack` and `PakettiNetDriveWatcherCreateTriggerTrack` so a stable sync-folder arrival creates an adjacent sequencer track and writes `C-4` plus `0G01` for the loaded instrument.

## Verification

- Ran `luac -p PakettiSamples.lua`.
- Ran `luac -p Paketti0G01_Loader.lua`.
- The check passed.

## Honesty Notes

- This is code-verified, not runtime-verified inside Renoise.
- Live verification still needs Renoise running, the watcher toggled on, and a real audio file dropped or recorded into `/private/tmp/netdrive/2logic`.
