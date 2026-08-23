# Paketti Copilot Instructions

Paketti is a GPL-3.0 Renoise workflow tool. It is an interpreted Lua 5.1
application: `main.lua` loads feature modules into Renoise, where they register
menus, keybindings, MIDI mappings, import hooks, and dialogs.

## Repository and validation commands

- Sync before inspecting code: `git fetch origin && git pull origin master`.
  This checkout is under iCloud Drive; if a working-tree file reads as empty,
  inspect its committed version with `git show HEAD:path/to/file`.
- There is no compile step or general unit-test runner. CI's primary load-safety
  check is:

  ```bash
  python3 .spine/check.py
  ```

  It requires `luajit` or `lua`, runs real registration code through
  `.spine/harness.lua`, and rejects duplicate keybindings/MIDI mappings,
  load-time registration errors, and strict-global hazards.
- For a focused syntax check of one edited Lua module:

  ```bash
  luac5.1 -p PakettiFeature.lua
  ```

- The repository's focused live integration test is the PakettiLull test:

  ```bash
  bash .spine/lull_test.sh
  ```

  It requires Renoise with PakettiMCP listening at `localhost:19714`.
- Package creation is handled by `.github/workflows/main.yml`: it validates,
  then produces API 6 and legacy API 5 `.xrnx` archives. Do not hand-build an
  archive unless the packaging workflow itself is being changed.

## Architecture and load order

- `main.lua` is the composition root. It loads `PakettiCompat` first, then
  `Paketti0G01_Loader`, then the feature modules with `timed_require`. Modules
  share globals, so load order is functional: add new modules to `main.lua`
  only after their dependencies, and keep extensions after the engines they
  mutate.
- `Paketti0G01_Loader.lua` owns the global `preferences` document, the 0G01
  command system, and `PakettiAddMenuEntry{}`. Use that wrapper for menus;
  `PakettiMainMenuEntries.lua` and `PakettiMenuConfig.lua` organize their
  presentation, while `PakettiKeyBindings.lua` and `KeyBindings/` provide
  keyboard presets.
- `PakettiCompat.lua` centralizes Renoise-version feature flags and safe API
  wrappers. Paketti ships an API 6 build and an API 5-compatible build, so use
  its `PAKETTI_HAS_*` flags and `pakettiSafe*` helpers rather than adding
  scattered version checks.
- Most `Paketti*.lua` files are feature modules. The shared systems are more
  important than their filenames: automation curves expose
  `PakettiAutomationCurvesShapes` and
  `PakettiAutomationCurvesWriteToLFOCustom`; curve packs add shapes to that
  registry instead of writing another LFO injector. Slicing features reuse
  zero-crossing and beat-detection helpers. Canvas dialogs share
  `PakettiCanvasFont.lua`.
- `.spine/harness.lua` is a mocked Renoise runtime used by `.spine/check.py`
  and documentation generators. It is the source of truth for registration
  validation; do not replace it with text-only registration scans.

## Paketti-specific conventions

- Search the existing modules before designing a feature. Confirm an owning
  module is actually loaded by a live `timed_require` in `main.lua`; a file on
  disk is not necessarily shipped functionality.
- Keep Lua 5.1 compatible: never use `goto` or labels. Never call
  `renoise.song()` at module load time; module scope should define helpers and
  registrations only.
- Define invoked functions before their registration blocks. Keep
  `add_menu_entry`, `add_keybinding`, `add_midi_mapping`, import-hook, and
  timer registrations at the bottom of the module. Local helpers must appear
  above every call site because Lua resolves locals lexically.
- Register menus with `PakettiAddMenuEntry{}`. Keybinding names have exactly
  three colon-separated parts (`scope:topic:name`); menu paths may have deeper
  nesting. MIDI mapping and keybinding names must be unique repository-wide:
  search for the exact name before adding one and run `.spine/check.py`.
- Add preferences to the `renoise.Document.create("ScriptingToolPreferences")`
  declaration in `Paketti0G01_Loader.lua`. After changing a preference value,
  call `preferences:save_as("preferences.xml")`; dynamic `add_property()` does
  not persist it.
- A dialog may use static ViewBuilder IDs only when it constructs a fresh
  `renoise.ViewBuilder()` each time it opens. Otherwise generate per-dialog IDs
  to avoid duplicate-ID errors on reopening.
- Treat Renoise API properties as version- and device-specific. Reuse
  compatibility helpers or probe optional properties with `pcall`; do not
  assume AHDSR and LFO devices expose the same fields.
- Binary import/export code must guard failed `io.open` calls and missing bytes
  from `string.byte`. Sample-buffer frame indexes are 1-based.
- Every shipped code change also updates `manual/CHANGESLOG.md` above the
  newest dated entry, including full menu, keybinding, and MIDI mapping names.
  Stage explicit paths only, then commit and push to `master`.

For the fuller operational history and Renoise-specific edge cases, read
`CLAUDE.md` before modifying Lua code.
