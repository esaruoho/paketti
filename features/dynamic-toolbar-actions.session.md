# Dynamic Macro Toolbar action safety session

## How to get back

- Transcript path: unavailable from the current Codex runtime; no local conversation JSONL path was exposed in this session.
- Session ID: unavailable from the current Codex runtime; not fabricated.
- Resume command: unavailable without the session ID.
- Date: 2026-09-25, local project timezone Europe/Helsinki.

## Request

Esa attached a Renoise stack-trace screenshot and asked to fix the issue. The traceback pointed at `PakettiDynamicMacroToolbar.lua:73` while executing a toolbar action named `show_euclid_dialog`.

Later, Esa attached a screenshot of the Dynamic Macro Toolbar and asked for a dropdown bar that selects between saved Dynamic Macro "10 chunk presets" / slot banks from a `DynamicMacro` folder inside Paketti.

## Diagnosis

`PakettiDynamicMacroToolbar.lua` stores Dialog-of-Dialogs actions as either function references or string names. For string names it used `_G[func_ref]`. In this tool's strict-global environment, reading an undeclared global through `_G` can invoke the strict global guard and raise `variable 'show_euclid_dialog' is not declared`, so the toolbar crashed before it could show its existing friendly "Function not found" status.

The specific action came from `PakettiMainMenuEntries.lua`, where the Dialog-of-Dialogs registry advertised `"Euclidean Fill"` as `"show_euclid_dialog"`. The helper lives in `PakettiGroovebox8ch960samp.lua` and is a Groovebox canvas sub-dialog: it depends on Groovebox selection state (`require_selection()`), so it is not a meaningful standalone Dialog-of-Dialogs action.

## Change

- `PakettiDynamicMacroToolbar.lua`: changed string action lookup from `_G[func_ref]` to `rawget(_G, func_ref)`, preserving valid global dispatch while bypassing strict-global `__index` crashes for missing names.
- `PakettiMainMenuEntries.lua`: removes `"Euclidean Fill"` from the standalone Dialog-of-Dialogs action list; it remains reachable from the Groovebox 8ch960samp UI where the required selection context exists.
- Added back-links from changed Lua files to `features/dynamic-toolbar-actions.feature`.
- `PakettiDynamicMacroToolbar.lua`: made `DynamicMacro/` the canonical preset folder, while keeping `DynamicMacroToolbar_Presets/` readable as a legacy fallback.
- `PakettiDynamicMacroToolbar.lua`: added a top-row preset popup. Selecting a preset immediately loads its ten line-based slot assignments into `PakettiDMTSlot01` through `PakettiDMTSlot10` and refreshes the button labels.
- `PakettiDynamicMacroToolbar.lua`: switched preset discovery from shell `ls` parsing to Renoise `os.filenames`, preserving exact paths and avoiding macOS full-path listing bugs.

## Verification

- Ran `luac -p PakettiDynamicMacroToolbar.lua PakettiMainMenuEntries.lua PakettiGroovebox8ch960samp.lua`; edited dispatch/registry/provider files parse.
- Ran `git diff --check -- PakettiDynamicMacroToolbar.lua PakettiMainMenuEntries.lua`; no whitespace errors.
- Confirmed `Euclidean Fill` is no longer present in `PakettiMainMenuEntries.lua`; `show_euclid_dialog` remains declared in `PakettiGroovebox8ch960samp.lua` for the Groovebox UI.
- Ran `luac -p PakettiDynamicMacroToolbar.lua`; the updated toolbar parses.

## Honest limits

This was code-verified from the shell. I did not runtime-click the Dynamic Macro Toolbar inside Renoise from this session, so the card marks the scenarios `@runtime-untested`.
