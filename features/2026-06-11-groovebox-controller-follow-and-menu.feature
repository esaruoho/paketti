# REPORT CARD — 2026-06-11/12 session: Groovebox 8120 controller declutter, Auto-Samplify casing, per-controller follow
#
# WHAT THIS CARD SPAWNS
#   Codespace : PakettiEightOneTwenty.lua (MidiController menu paths, APC/MidiMix
#               follow-page engine, per-controller follow setters/accessors, the
#               "Ctrl Follow:" dialog checkboxes), Paketti0G01_Loader.lua (the three
#               pakettiGroovebox8120Follow{APC,MidiMix,LPD8} preferences),
#               PakettiMenuConfig.lua + PakettiAutoSamplify.lua (Auto-Samplify text),
#               PakettiTriggerOnInput.lua (Debug menu fold).
#   Thinkspace : 2026-06-11-groovebox-controller-follow-and-menu.session.md (spawning chat).
#   Areaspace  : Groovebox 8120 AKAI controller surface (APC Key 25 / MidiMix / LPD8)
#               + the Tools:Paketti menu layout for controller debug entries. Does
#               NOT touch the shared step engine (Get/ToggleStepState/Yxx), the
#               pattern read/write, or the Renoise transport follow_player.
#
# GRADE LEGEND (honest, per report-card doctrine)
#   @built            — code written, luac -p syntax-clean, committed + pushed to master.
#   @logic-verified   — correctness argued by hand (data-flow / arithmetic).
#   @hw-verified      — confirmed working with the physical controller in Renoise.
#   @hw-untested      — NOT yet tried on the physical controller (the honest state of
#                       everything follow-related this session — I have no hardware).
#   @superseded       — shipped, then replaced by a later unit in the same session.
#
# HEADLINE: the menu/text units are @built (+ the user saw the menus while we worked,
# but no explicit in-Renoise sign-off was given). ALL follow-related behaviour is
# @built + @logic-verified but @hw-untested — needs an APC Key 25 + MidiMix at 32
# steps to confirm. See "LEFT ON THE TABLE" at the foot.

Feature: AKAI controller debug/demo entries moved out of the Groovebox menu
  # cite: PakettiEightOneTwenty.lua (29 PakettiAddMenuEntry paths) + PakettiTriggerOnInput.lua:~288 | commit 2196666
  @built
  Scenario: Controller debug entries live under !Preferences:Debug:MidiControllers
    Given the Groovebox menu was polluted with APC/MidiMix/LPD8 probe/demo/lights entries
    When the tool registers its menus
    Then all 29 of them appear under Main Menu:Tools:Paketti:!Preferences:Debug:MidiControllers
    And the Groovebox menu keeps only its real features (Sequential Load/Kit/Canvas/etc.)
    And "Trigger Sample Manual Test" moves from Tools:Paketti:Debug to !Preferences:Debug

  Scenario: The three Auto-Start toggles live only under Options
    Given the Auto-Start AKAI entries were dual-registered (Options + Groovebox)
    When the tool registers its menus
    Then only the Main Menu:Options copies remain (the Groovebox duplicates are removed)

Feature: KeyBindings preset + MIDI-mapping presets committed
  # cite: KeyBindings/2025_07_10_PakettiKeyBindings.xml + 3 new *.xrnm | commit 09e135c
  @built
  Scenario: The user's controller mapping work is in the repo
    Given the working tree held an edited keybinding preset and 3 untracked MIDI maps
    When committed and pushed
    Then MidiMix+MPKMini3 and the two APCKEY25 mapping presets are tracked (cd.txt left out, later deleted)

Feature: "Auto-samplify" capitalised to "Auto-Samplify"
  # cite: PakettiMenuConfig.lua:~3515-3516 + PakettiAutoSamplify.lua:~1545 | commit b4a229b
  @built @logic-verified
  Scenario: Menu entries and status text read "Auto-Samplify"
    Given two Main Menu:Options toggles and one status string said "Auto-samplify"
    When the text is corrected
    Then all three read "Auto-Samplify"
    And the internal preference keys (pakettiAutoSamplify*) are left unchanged (no persistence break)

Feature: APC Key 25 follow-page restores 16+16 layout at 32 steps
  # cite: PakettiEightOneTwenty.lua paketti_apc_seq_zone + paketti_apc_seq_refresh + paketti_apc_paged | commits b3f29c5, 7d3dd71
  @built @logic-verified @hw-untested
  Scenario: APC follow on at 32 steps shows 16 steps + 16 probability and pages
    Given the 8120 is in 32-step mode and the APC sequencer is armed
    When the APC follow checkbox is on
    Then the APC shows 16 steps + 16 probability for the current page (not all 32 steps)
    And the page snaps to the playhead during playback (page 0 = 1..16, page 1 = 17..32)

  Scenario: APC left non-rotating shows every step
    Given 32-step mode and the APC follow checkbox off
    Then all 32 steps fill the top four pad rows and the grid never pages

Feature: MidiMix follow-page windows its 16 LEDs over 32 steps
  # cite: PakettiEightOneTwenty.lua paketti_midimix_redraw_all_leds + idle handler + page math | commits b3f29c5, 7d3dd71
  @built @logic-verified @hw-untested
  Scenario: MidiMix follow on at 32 steps keeps the playhead visible
    Given the 8120 is in 32-step mode, the MidiMix bridge is open, transport playing
    When the MidiMix follow checkbox is on
    Then the 16 LEDs page between steps 1-16 and 17-32 to track the playhead
    And a button press toggles the correct global step for the current page

Feature: Follow is PER-CONTROLLER and independent (final design)
  # cite: PakettiEightOneTwenty.lua paketti_{apc,midimix,lpd8}_follow_enabled + ...SetFollow + 3 dialog checkboxes; Paketti0G01_Loader.lua 3 prefs | commit 7d3dd71
  @built @logic-verified @hw-untested
  Scenario: Three independent persisted toggles, one per controller
    Given the 8120 dialog is open
    When the user ticks the MidiMix follow checkbox but leaves the APC one off
    Then pakettiGroovebox8120FollowMidiMix is saved true and ...FollowAPC stays false
    And each controller's Toggle-Follow keybinding/MIDI/menu toggles only itself
    And arming a controller reads its own saved preference (follows-or-not headlessly)

Feature: The global single-master "Ctrl Follow" checkbox (intermediate, replaced)
  # cite: pakettiGroovebox8120Follow + PakettiEightOneTwentySetControllerFollow | commit a31d111
  @superseded
  Scenario: A single master toggle drove all three controllers
    Given an earlier turn shipped one checkbox + one preference for all controllers
    When the user asked for per-controller control instead
    Then commit 7d3dd71 replaced it with three independent toggles (this code no longer exists)

# RESULT
#   Feature commits (first-parent, master, direct-push, no PRs):
#     2196666  Groovebox menu declutter (29 entries moved, Auto-Start dups dropped, Debug fold)
#     09e135c  KeyBindings preset + 3 MIDI-mapping presets
#     b4a229b  Auto-samplify -> Auto-Samplify
#     b3f29c5  APC + MidiMix follow-page (32-step)
#     a31d111  Ctrl Follow checkbox (global master)            [@superseded]
#     5f48ea9  feature cards for the global-master follow      [@superseded by 7d3dd71 card edits]
#     7d3dd71  per-controller follow rework (final)
#   Card-authoring commit: this file.
#   Verification: luac -p clean on every edited .lua; keybinding names checked = 3 colon-parts.
#                 NO hardware verification of follow performed this session.
#
# LEFT ON THE TABLE (undone — deferred / needs the user, not defects)
#   1. HARDWARE VERIFICATION of all follow behaviour at 32 steps with a real APC Key
#      25 + MidiMix (and LPD8): paging tracks the playhead, per-controller checkboxes
#      are independent, saved prefs apply headlessly after restart, button-press maps
#      to the right global step per page. Until then every follow scenario is
#      @hw-untested. (Bump to @hw-verified once you confirm, or report what breaks.)
#   2. APC manual Next/Previous Page only shows its effect while that controller's
#      follow/paged layout is active; with follow off the APC stays all-32. Intended,
#      but unverified on hardware.
#   3. Dialog width: three checkboxes + labels were added to the already-busy top
#      control row. Not visually checked in a running Renoise — may need wrapping.
#   4. cd.txt (a stray grep dump) was deleted; nothing else outstanding in the tree.
