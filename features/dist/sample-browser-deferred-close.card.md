# Report Card — Load samples and close the browser after keyboard dispatch returns

> Source: `features/sample-browser-deferred-close.feature` · printable rendering · regenerate with `python3 print-card.py`

**Grades:** @runtime-untested × 4 · @sim-verified × 4 · @stock × 1

**Scenarios: 5**


---


## 1. Forward octave controls and the opening shortcut

`@sim-verified @runtime-untested`


- Given the browser is focused and no action is pending
- When octave keys or Cmd-CapsLock are pressed
- Then unhandled keys are forwarded to Renoise
- And the global toggle binding queues deferred confirmation

<sub>cite: PakettiLoadSampleBrowser.lua plsb_key_handler · tests/sample-browser-deferred-close.lua</sub>


## 2. Import a selected folder with Shift-Enter

`@sim-verified @runtime-untested`


- Given a folder entry is selected
- When Shift-Enter is pressed
- Then directly contained loadable files are imported alphabetically into separate instruments after dispatch
- And the dialog closes after importing
- And an empty folder leaves the dialog open

<sub>cite: PakettiLoadSampleBrowser.lua plsb_load_folder_now, plsb_load_path · tests/sample-browser-deferred-close.lua</sub>


## 3. Defer confirmation and cancellation

`@sim-verified @runtime-untested`


- Given the browser is visible
- When the toggle shortcut, Return or Escape requests a load or close
- Then loading and window closure happen in a one-shot 50 ms timer
- And the Pattern Editor switch happens after deferred confirmation

<sub>cite: PakettiLoadSampleBrowser.lua plsb_defer_action, plsb_confirm_now, plsb_close_now · tests/sample-browser-deferred-close.lua</sub>


## 4. Ignore duplicate requests and stale windows

`@sim-verified @runtime-untested`


- Given a browser action is pending
- When another shortcut or navigation event arrives
- Then no second action is queued and the selection stays fixed
- And keybinding repeats do not reopen a closed dialog
- And releasing the song cancels pending work
- And an externally closed dialog does not load a sample

<sub>cite: PakettiLoadSampleBrowser.lua plsb_key_handler, PakettiLoadSampleBrowserToggle, plsb_on_document_release</sub>


## 5. Preserve sample target selection

`@stock`


- Given a selected sample file
- When deferred confirmation runs
- Then the existing scratch cleanup and empty-target selection rules apply

<sub>cite: PakettiLoadSampleBrowser.lua plsb_confirm_now</sub>

