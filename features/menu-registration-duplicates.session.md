# Menu Registration Duplicates Session

## How To Get Back

- Transcript path: not available from this Codex harness during the turn
- Session ID: not available from this Codex harness during the turn
- Resume command: not available without the session ID
- Date: 2026-09-25 13:55:58 EEST

## User Request

Esa reported Renoise startup failing with:

```text
std::logic_error: 'invalid menu entry: entry 'Main Menu:Tools:Paketti:!Preferences:Paketti Pattern / Phrase Init Preferences...' was already added.'
stack traceback:
  [C]: in function 'add_menu_entry'
  ...Tools/org.lackluster.Paketti.xrnx/Paketti0G01_Loader.lua:4651: in function 'PakettiFlushMenuEntries'
  main.lua:1760: in main chunk
```

## Diagnosis

The exact menu path was present twice in `PakettiMenuConfig.lua`: once in the `MainMenuTools` preference-controlled area and once later in the Tools Preferences block. Both were queued and then sorted by `PakettiFlushMenuEntries()`, so Renoise rejected the second exact path during `add_menu_entry`.

## Change

The later duplicate `Main Menu:Tools:Paketti:!Preferences:Paketti Pattern / Phrase Init Preferences...` row was removed, leaving the preference-controlled registration as the owner of that exact path.

`PakettiFlushMenuEntries()` now tracks exact pending names while flushing. If a future duplicate reaches the flush, it prints:

```text
PakettiFlushMenuEntries: skipped duplicate menu entry: <name>
```

and continues startup instead of passing the duplicate into Renoise.

## Verification

Ran:

```bash
luac -p Paketti0G01_Loader.lua PakettiMenuConfig.lua
./treemenu
rg -n -F "Main Menu:Tools:Paketti:!Preferences:Paketti Pattern / Phrase Init Preferences..." *.lua
```

Result: touched files parse; `treemenu` regenerated `menu_items.txt`; the exact Preferences path appears once in Lua source.
