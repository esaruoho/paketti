# NetDrive 2logic Watcher Session

## How to get back

- Date: 2026-09-22 16:52:59 EEST (+0300)
- Transcript path: unavailable from this Codex runtime
- Session ID: unavailable from this Codex runtime
- Resume command: unavailable because the session ID is not exposed here
- Source bundle: unavailable; this card records the faithful working summary below instead of a fabricated transcript link

## Request

Esa asked for the “meat of the matter”: define a folder that is caught when a new recorded file appears there, and have Renoise load that file through Paketti. The concrete folder named in the request was `/private/tmp/netdrive/2logic`.

## Decisions

- The watcher belongs in `PakettiSamples.lua`, because that file already owns the Paketti sample-loading behavior and loader-setting application.
- Preferences belong in `Paketti0G01_Loader.lua`, because it declares the root `ScriptingToolPreferences` document.
- The default folder is exactly `/private/tmp/netdrive/2logic`, but a menu command can change it.
- The watcher ignores files that were already present when it starts, so toggling it on does not import the whole folder.
- New files are not loaded immediately. They must keep the same size and mtime for the configured stability delay, defaulting to one second, so partially written recordings are not grabbed mid-write.
- Each new file is loaded into a fresh Paketti instrument after the current selection, using the default XRNI and existing loader settings.

## Work Performed

- Added `pakettiNetDriveWatcherEnabled`, `pakettiNetDriveWatcherFolder`, and `pakettiNetDriveWatcherStableSeconds` preferences.
- Added `PakettiNetDriveWatcher*` functions for scanning, stability debounce, loading, start/stop/toggle, and folder selection.
- Added a Global keybinding, MIDI trigger mapping, and Tools menu entries for toggling and configuring the watcher.
- Added a report-card back-link in the watcher code.

## Verification

- Ran `luac -p PakettiSamples.lua Paketti0G01_Loader.lua`.
- The check passed.

## Honesty Notes

- This is code-verified, not runtime-verified inside Renoise.
- Live verification still needs Renoise running, the watcher toggled on, and a real audio file dropped or recorded into `/private/tmp/netdrive/2logic`.
