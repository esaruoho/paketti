# Report Card — Menu registration skips exact duplicates

> Source: `features/menu-registration-duplicates.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti maintainer, I want exact duplicate menu registrations to be detected before Renoise sees them, So that one duplicate path cannot abort Paketti startup.

**Grades:** @code-verified × 3 · @runtime-untested × 3 · @shipped × 3

**Scenarios: 3**


---


## 1. Duplicate pending menu names are skipped during sorted flush

`@shipped @code-verified @runtime-untested`


- Given boot-time menu entries have been queued for sorted registration
- When two pending entries have the same exact Renoise menu name
- Then the first one is registered
- And the later duplicate is skipped with a console message naming the duplicate path
- And Paketti startup continues instead of raising Renoise's invalid menu entry error

<sub>cite: Paketti0G01_Loader.lua PakettiFlushMenuEntries</sub>


## 2. Existing menu entries are not registered again

`@shipped @code-verified @runtime-untested`


- Given a menu entry already exists in Renoise before the flush reaches a pending row
- When the pending row has the same exact name
- Then the pending row is skipped before calling add_menu_entry

<sub>cite: Paketti0G01_Loader.lua PakettiFlushMenuEntries</sub>


## 3. Pattern/Phrase Init Preferences keeps one Preferences path

`@shipped @code-verified @runtime-untested`


- Given the Main Menu:Tools context is enabled
- When PakettiMenuConfig.lua registers Pattern/Phrase Init Preferences entries
- Then the Preferences path appears only once
- And the separate Pattern Editor and Phrases menu paths remain available

<sub>cite: PakettiMenuConfig.lua Main Menu:Tools:Paketti:!Preferences:Paketti Pattern / Phrase Init Preferences...</sub>

