# Report Card — Song-lifecycle safety for canvas dialogs and song observers

> Source: `features/song-lifecycle-safety.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 2 · @hw-verified × 1

**Scenarios: 3**


---


## 1. 8120 survives New Song with its canvas open

`@hw-verified`


- Given the Groovebox 8120 dialog and canvas are open
- When the user triggers New Song
- Then 8120 detaches its observers and closes on app_release_document_observable
- And Renoise frees the old song without a SIGSEGV


## 2. HyperEdit must survive New Song / Load Song with its canvas open

`@built @untested-in-renoise`


- Given the HyperEdit dialog and canvas are open with song observers attached
- When the user triggers New Song or Load Song
- Then HyperEdit must detach transport/track/device observers and close on app_release_document_observable
- And Renoise must free the old song without a SIGSEGV in TWeakRefOwner::SOnWeakReferencableDying


## 3. ParameterEditor must survive New Song / Load Song with its canvas open

`@built @untested-in-renoise`


- Given the ParameterEditor (CanvasExperiments) dialog is open observing the selected device
- When the user triggers New Song or Load Song
- Then ParameterEditor must detach its observers from the OLD song on app_release_document_observable
- And it must not rely solely on app_new_document_observable, which fires too late to detach cleanly

