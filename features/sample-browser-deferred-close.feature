# WHAT THIS CARD SPAWNS:
# codespace: PakettiLoadSampleBrowser.lua and tests/sample-browser-deferred-close.lua
# thinkspace: sample-browser-deferred-close.session.md
# areaspace: browser confirmation/cancellation scheduling; preserve preview and target selection
# SESSION: sample-browser-deferred-close.session.md
# RESULT: Local working-tree change; no commit, push or PR.
# Files: PakettiLoadSampleBrowser.lua, tests/sample-browser-deferred-close.lua, PLAN.md, this card and session.
# WATCH: plsb_defer_action plsb_cancel_pending_action plsb_close_now plsb_confirm_now plsb_load_path plsb_load_folder_now plsb_key_handler PakettiLoadSampleBrowserToggle
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: plsb_load_path
#   2026-10-03  direct-commit  touched: plsb_close_now plsb_load_path
#   2026-10-02  direct-commit  touched: plsb_load_path
#   2026-10-02  direct-commit  touched: plsb_defer_action plsb_close_now plsb_load_path
#   2026-10-02  direct-commit  touched: plsb_defer_action plsb_close_now plsb_confirm_now plsb_load_path plsb_load_folder_now
#   2026-10-02  direct-commit  touched: plsb_defer_action plsb_cancel_pending_action plsb_close_now plsb_confirm_now PakettiLoadSampleBrowserToggle

Feature: Load samples and close the browser after keyboard dispatch returns
  @sim-verified @runtime-untested
  Scenario: Forward octave controls and the opening shortcut
    # cite: PakettiLoadSampleBrowser.lua plsb_key_handler
    # cite: tests/sample-browser-deferred-close.lua
    Given the browser is focused and no action is pending
    When octave keys or Cmd-CapsLock are pressed
    Then unhandled keys are forwarded to Renoise
    And the global toggle binding queues deferred confirmation

  @sim-verified @runtime-untested
  Scenario: Import a selected folder with Shift-Enter
    # cite: PakettiLoadSampleBrowser.lua plsb_load_folder_now, plsb_load_path
    # cite: tests/sample-browser-deferred-close.lua
    Given a folder entry is selected
    When Shift-Enter is pressed
    Then directly contained loadable files are imported alphabetically into separate instruments after dispatch
    And the dialog closes after importing
    And an empty folder leaves the dialog open

  @sim-verified @runtime-untested
  Scenario: Defer confirmation and cancellation
    # cite: PakettiLoadSampleBrowser.lua plsb_defer_action, plsb_confirm_now, plsb_close_now
    # cite: tests/sample-browser-deferred-close.lua
    Given the browser is visible
    When the toggle shortcut, Return or Escape requests a load or close
    Then loading and window closure happen in a one-shot 50 ms timer
    And the Pattern Editor switch happens after deferred confirmation

  @sim-verified @runtime-untested
  Scenario: Ignore duplicate requests and stale windows
    # cite: PakettiLoadSampleBrowser.lua plsb_key_handler, PakettiLoadSampleBrowserToggle, plsb_on_document_release
    Given a browser action is pending
    When another shortcut or navigation event arrives
    Then no second action is queued and the selection stays fixed
    And keybinding repeats do not reopen a closed dialog
    And releasing the song cancels pending work
    And an externally closed dialog does not load a sample

  @stock
  Scenario: Preserve sample target selection
    # cite: PakettiLoadSampleBrowser.lua plsb_confirm_now
    Given a selected sample file
    When deferred confirmation runs
    Then the existing scratch cleanup and empty-target selection rules apply
