# Report Card — Disk Browser refresh nudge

> Source: `features/disk-browser-refresh.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want a command that nudges Renoise's Disk Browser to reload its listing, So that newly-created or changed files can appear without manually cycling browser categories.

**Grades:** @code-verified × 2 · @runtime-untested × 2 · @shipped × 2 · @stock × 1

**Scenarios: 3**


---


## 1. Refresh command nudges the Disk Browser category away and back

`@shipped @code-verified @runtime-untested`


- Given Renoise exposes ApplicationWindow.disk_browser_category
- When the user triggers PakettiRefreshDiskBrowser
- Then Paketti makes the Disk Browser visible
- And temporarily changes to the next Disk Browser category
- And restores the original category after 100 ms
- And reports "Disk Browser refreshed" in the Renoise status bar

<sub>cite: Paketti35.lua PakettiRefreshDiskBrowser (line 751) — switches to the adjacent category and restores the original after a one-shot timer</sub>


## 2. Refresh command is reachable from shortcuts and menus

`@shipped @code-verified @runtime-untested`


- Given Paketti's V3.5 Disk Browser commands are loaded
- When the user opens keybindings or Paketti's Disk Browser menus
- Then Refresh Disk Browser is available beside the existing category controls

<sub>cite: Paketti35.lua Refresh Disk Browser keybinding (line 846) — registers the Global:Paketti keybinding · PakettiMenuConfig.lua Refresh Disk Browser menu entries (lines 1666, 1678) — exposes Disk Browser and Main Menu entries</sub>


## 3. Existing Disk Browser category controls keep their behaviour

`@stock`


- Given the user triggers Cycle Disk Browser Category or Set to Songs/Instruments/Samples/Other
- When Paketti handles the command
- Then Paketti still changes disk_browser_category directly through the existing functions

<sub>cite: Paketti35.lua DiskBrowserCategoryCycler and SetDiskBrowserCategory (lines 731, 740) — pre-existing category controls remain unchanged</sub>

