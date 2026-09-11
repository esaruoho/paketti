# Report Card — Groovebox 8120 fills 8 instrument slots with the Paketti Default Instrument on empty-song open

> Source: `features/groovebox-8120-default-instrument-slots.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @built × 3

**Scenarios: 3**


---


## 1. Opening 8120 on an empty song fills all 8 slots with the default instrument

`@built @untested-in-renoise`


- Given the song is empty (a single empty instrument, no samples or plugin)
- And the pakettiEightOneTwentyAutoFillDefaultSlots preference is ON
- When the user opens Groovebox 8120
- Then the Paketti Default Instrument is loaded into instrument slots 1 through 8 (rows 01-08)
- And the slots are ready to be used


## 2. Opening 8120 on a song that already has instruments leaves them untouched

`@built @untested-in-renoise`


- Given the song already contains instruments (not the empty fresh-song state)
- When the user opens Groovebox 8120
- Then the existing instruments are not overwritten
- And the auto-fill does not run


## 3. New Song never triggers the auto-fill

`@built @untested-in-renoise`


- Given a song is loaded or created while 8120 is closed
- When a New Song is created in Renoise
- Then no instruments are armed or replaced by 8120
- And the auto-fill happens only when 8120 is next opened on an empty song

