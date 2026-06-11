# REPORT CARD — 2026-06-11 session: 8120 fixes, automation discoverability, menu-config consolidation, prefs layout
#
# WHAT THIS CARD SPAWNS
#   Codespace : PakettiEightOneTwenty.lua (Kit loader, step-repeat, Canvas View),
#               PakettiRequests.lua (automation menu/keybinding registration),
#               Paketti0G01_Loader.lua (Menu Configuration dialog, Paketti Toggler
#               dialog, Preferences "Pattern Editor" section).
#   Thinkspace : 2026-06-11-ui-fixes-and-menu-config.session.md (the spawning chat).
#   Areaspace  : Groovebox 8120 UI + the tool-wide menu/keybinding/preferences
#               registration & configuration surface. Does NOT touch the
#               registration GATE itself (PakettiShouldRegisterMenuEntry) or the
#               canonical category list's contents — only how dialogs present them.
#
# GRADE LEGEND (honest, per report-card doctrine)
#   @built            — code written, luac -p syntax-clean, committed + pushed to master.
#   @logic-verified   — correctness argued by hand (math / data-flow).
#   @runtime-verified — observed working in a live Renoise instance by the user
#                       (Esa confirmed all 8 done, 2026-06-11, after the carding turn).
#
# All eight units are @built + pushed AND @runtime-verified. The remaining items in
# "LEFT ON THE TABLE" are deferred design choices / known limitations, not defects.

Feature: Groovebox 8120 Kit loader status column alignment
  # cite: PakettiEightOneTwenty.lua PakettiEightOneTwentyKitCatLabel + loadSequentialKitAll status lines | commit f20dc24
  @built @runtime-verified
  Scenario: Per-part status lines align the "Loading/Queued" column
    Given the Kit loader shows "Part N/8 [Category]: Loading ..." for 8 categories
    And category names vary in width (Kick=4 .. Rimshot=7)
    When a status line is built
    Then the "[name]" field is space-padded to the widest category name
    And every line's text after the bracket starts at the same column
    # CAVEAT: assumes Renoise's bold UI text is monospaced (screenshot strongly
    # suggests it is). If proportional, char-count padding is not pixel-perfect.

Feature: Groovebox 8120 step-repeat fills the final pattern row
  # cite: PakettiEightOneTwenty.lua note-trigger writer (~2251) + phrase-trigger writer (~8204) | commit 6594dfc
  @built @logic-verified @runtime-verified
  Scenario: Trailing partial block is written when steps do not divide pattern length
    Given a 64-row pattern and a row step count of 3
    And full_repeats = floor(64/3) = 21 complete blocks cover lines 1..63
    When the writer finishes the full blocks
    Then the remainder (64 - 21*3 = 1 line) is filled from the block's leading steps
    And the last pattern row (Lua line 64 / display row 63) receives its trigger

Feature: Wipe/Clear All Automation discoverable from the Automation List
  # cite: PakettiRequests.lua delete_automation registration loop (~10246) | commit 656f65a
  @built @runtime-verified
  Scenario: Track Automation List + lane expose the wipe/clear commands
    Given delete_automation(all_tracks, whole_song) already exists
    When the Track Automation List or Track Automation lane is right-clicked
    Then "Wipe All Automation in Track/All Tracks on Current Pattern/Whole Song" appear
    And "Clear All Automation in Current Track" / "...for All Patterns" appear as synonyms
    And Global keybindings exist for the Clear variants

Feature: Paketti Toggler lists every menu category, alphabetically
  # cite: Paketti0G01_Loader.lua PakettiTogglerDialog generated-checkbox block | commit d920bb8 (later superseded — see next)
  @built @runtime-verified
  Scenario: Generated from the canonical list instead of a hardcoded subset
    Given the canonical list has 24 categories incl. TrackAutomationList
    When the Toggler dialog is built
    Then a checkbox is generated for every category, sorted by label
    # NOTE: this scenario was superseded by commit 4675249 (grid removed entirely).

Feature: Groovebox 8120 Canvas View survives a step-mode downshift
  # cite: PakettiEightOneTwenty.lua cv_read_row_steps clamp | commit c9dbddb
  @built @logic-verified @runtime-verified
  Scenario: A lane's step count above the active MAX_STEPS no longer crashes the view
    Given a lane set to 32 steps while MAX_STEPS is now 16
    When the Canvas View builds the per-lane step valuebox (max = MAX_STEPS)
    Then cv_read_row_steps clamps the read into [1, MAX_STEPS]
    And the valuebox receives a valid initial value (no "invalid value ... [1-16]")
    And the lane's real 32 is preserved (classic box max=512) until changed in-canvas

Feature: Paketti Toggler drops the duplicated menu-category grid
  # cite: Paketti0G01_Loader.lua PakettiTogglerDialog menu-categories section replaced by a link | commit 4675249
  @built @runtime-verified
  Scenario: Per-context menu toggles live only in Menu Configuration now
    Given Menu Configuration owns the per-context menu on/off
    When the Toggler dialog is built
    Then the duplicate category grid is gone
    And a "Open Paketti Menu Configuration..." button replaces it
    And the Toggler keeps counts, master Menu/Key/MIDI toggles, and Import Hooks

Feature: Paketti Menu Configuration shows per-category entry counts + bulk toggles
  # cite: Paketti0G01_Loader.lua PakettiCountMenuEntriesByCategory + pakettiMenuConfigDialog | commit 0f506fd
  @built @runtime-verified
  Scenario: Each category checkbox shows its source-counted entry total
    Given every Paketti .lua source is scanned once (memoized)
    And both add_menu_entry and PakettiAddMenuEntry calls are counted
    When the Menu Configuration dialog opens
    Then each checkbox reads "<Category> (<N>)" and a header gives the grand total
    And "Enable All Menus (N)" / "Disable All Menus (N)" flip every category + refresh
    # CAVEAT: entries with a concatenated name (no literal name="...") are not
    # attributable to a context and fall into an internal __uncategorized bucket.

Feature: Preferences "Pattern Editor" section shows all eight settings
  # cite: Paketti0G01_Loader.lua dialog_content column-1 Pattern Editor rows (~1661) | commit f9472bd
  @built @runtime-verified
  Scenario: No setting is clipped by the fixed first-column width
    Given the section lives in column 1 (width=column1_width=430)
    And a 3-text+checkbox row (~544px) overflows and is clipped
    When the 8 settings are laid out two-per-row (~356px each)
    Then Trigger on Input and SBx Pattern Loop Follow render fully
    And every checkbox fits within the 430px column

# ============================================================================
# RESULT (what shipped) — all direct-push to master, no PRs
# ============================================================================
#   f20dc24  Kit loader: pad [category] field so status columns align
#   6594dfc  8120: fill trailing partial block on step-repeat
#   656f65a  Automation: expose Wipe/Clear from Track Automation List + lane
#   d920bb8  Paketti Toggler: generate category checkboxes from canonical list
#   c9dbddb  8120 Canvas View: clamp per-lane step count to active MAX_STEPS
#   4675249  Paketti Toggler: remove duplicated menu-category grid; link across
#   0f506fd  Menu Configuration: per-category counts + Enable/Disable All Menus
#   f9472bd  Preferences: Pattern Editor section to 2-per-row
#   cc0f5ab  Menu Config: tally counts at the registration gate (counts
#            concatenated/loop names, live per boot, frozen post-flush) +
#            rename Paketti Toggler -> Paketti Deactivator (incl. keybinding presets)
#   Files: PakettiEightOneTwenty.lua, PakettiRequests.lua, Paketti0G01_Loader.lua,
#          PakettiMainMenuEntries.lua, PakettiImport.lua, KeyBindings/*.xml,
#          manual/CHANGESLOG.md (entry per change). Card commits: f.. + cc0f5ab + b5765cb.
#   Verification performed: luac -p syntax-clean on every edit; hand-math on the
#   step-repeat remainder; git push confirmed; AND live Renoise confirmation by the
#   user — Esa confirmed all 8 done on 2026-06-11.
#
# ============================================================================
# LEFT ON THE TABLE (unfinished / deferred / unverified)
# ============================================================================
#   1. RUNTIME VERIFICATION — DONE. Esa confirmed all 8 working in a live Renoise
#      on 2026-06-11. Every scenario is now @runtime-verified.
#   2. Kit loader monospace-font assumption — CONFIRMED OK by the runtime check
#      (alignment looks correct in Renoise). No fixed-width-column fallback needed.
#   3. Menu Config per-category counts — DONE (commit cc0f5ab). Counting moved from
#      a source-text scan to a startup tally at the registration gate
#      (PakettiShouldRegisterMenuEntry), which sees each entry once with a resolved
#      name — so concatenated (name=var.."...") and for-loop-generated entries are
#      now counted against their real context. Frozen after the boot flush.
#   4. Keybindings and MIDI Mappings remain MASTER-ONLY (all-or-nothing). No
#      per-context granularity mirroring the menu side. Larger build if wanted.
#   5. Literal "Delete" synonym NOT added as separate automation menu entries
#      (only Wipe + Clear shipped). Changelog mentions Delete; menu does not.
#   6. PakettiAddMenuEntry alphabetical sort means the new "Clear..." automation
#      entries do NOT sit adjacent to the "Wipe..." ones in the right-click menu.
#   7. Paketti Toggler RENAMED to "Paketti Deactivator" (commit cc0f5ab) — window
#      title, header, menu entry, keybinding, main-menu button, keybinding presets.
#      Still NOT lifted into Main Menu -> Options next to Menu Configuration.
#   8. PRE-EXISTING, UNTOUCHED: PakettiEightOneTwenty.lua:9594 diagnostic "Only 200
#      active local variables can exist" — luac -p compiles the file fine, so not
#      currently breaking, but flagged. Not investigated this session.
