# Report Card — Issue follow-up utilities

> Source: `features/issue-followup-utilities.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** As a Paketti user, I want small workflow gaps closed, So that delay editing, automation editing, menu visibility, and eSpeak batch output behave predictably.

**Grades:** @code-verified × 4 · @runtime-untested × 4 · @shipped × 4

**Scenarios: 4**


---


## 1. Phrase delay nudging makes delay columns visible

`@shipped @code-verified @runtime-untested`


- Given a phrase delay nudge is invoked for a selected phrase or cell
- When Paketti applies the nudge
- Then the phrase delay column is visible
- And the selected sequencer track delay column is visible when applicable

<sub>cite: PakettiPhraseEditor.lua PakettiPhraseEditorNudgeWithDelay and PakettiPhraseEditorNudgeByDelay — reveal phrase and selected sequencer-track delay columns</sub>


## 2. Reverse selected automation

`@shipped @code-verified @runtime-untested`


- Given an automation envelope exists with a selected range or a full-pattern fallback
- When the user invokes Reverse Selected Automation
- Then points inside the range are mirrored in time with their values preserved
- And points outside the range remain unchanged

<sub>cite: PakettiAutomationCurves.lua PakettiAutomationCurvesReverseSelection — mirrors selected automation point times and preserves outside points · PakettiMenuConfig.lua Track Automation reverse entry — exposes the action from the configured menu</sub>


## 3. eSpeak can be hidden through Paketti Menu Config

`@shipped @code-verified @runtime-untested`


- Given the eSpeak category is disabled in Paketti Menu Config
- When Renoise registers Paketti menus
- Then Paketti does not register the eSpeak menu entries

<sub>cite: Paketti0G01_Loader.lua eSpeak preference and category — adds the eSpeak visibility toggle · PakettiMenuConfig.lua eSpeak menu gate — registers eSpeak menu entries only when enabled</sub>


## 4. Generate one eSpeak output per text line

`@shipped @code-verified @runtime-untested`


- Given the eSpeak dialog contains multiple non-empty lines
- When the user chooses Generate Instruments per Line
- Then Paketti creates one instrument and sample for each line
- When the user chooses Generate Drum Kit per Line
- Then Paketti creates one instrument with one-key samples mapped from C-2 upward

<sub>cite: PakettieSpeak.lua PakettieSpeakGenerateLines — serializes rendering and sample loading for each non-empty line</sub>

