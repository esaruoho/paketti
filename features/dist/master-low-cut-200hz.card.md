# Report Card — Master Low-Cut 200Hz punch toggle

> Source: `features/master-low-cut-200hz.feature` · printable rendering · regenerate with `python3 print-card.py`

**Intent:** Context: Global

**Grades:** @hw-verified × 3

**Scenarios: 3**


---


## 1. Punch in the low-cut

`@hw-verified`


- Given the song is playing
- When the user triggers "Paketti:Master Low-Cut 200Hz Toggle"
- Then a Digital Filter high-pass at ~200Hz is added to the master track
- And everything below 200Hz is filtered out


## 2. Punch it off

`@hw-verified`


- Given the master low-cut is active
- When the user triggers "Paketti:Master Low-Cut 200Hz Toggle"
- Then the tagged high-pass device is removed and the low end returns


## 3. Momentary hold

`@hw-verified`


- Given the song is playing
- When the user holds a button mapped to "Paketti:Master Low-Cut 200Hz Hold"
- Then the high-pass is active while held and removed on release

