# Report Card — Groovebox 8120 Record button records into a Pakettified instrument

> Source: `features/groovebox-8120-record-pakettified-instrument.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 2

**Scenarios: 2**


---


## 1. Record press loads a Paketti Default Instrument then starts recording

`@built @untested-in-renoise`


- Given the Groovebox 8120 dialog is open
- And a row's instrument slot is selected
- When the user presses Record on that row
- Then the Paketti Default Instrument is loaded into that row's instrument slot
- And sample recording starts immediately


## 2. Second Record press injects the sample into the Paketti chassis

`@built @untested-in-renoise`


- Given recording is in progress on a row whose slot holds the Paketti Default Instrument
- When the user presses Record again
- Then recording stops
- And the recorded sample is mapped 00-7F as the row's primary sample
- And the recorded sample is pointed at the instrument's modulation set (Pakettified)

