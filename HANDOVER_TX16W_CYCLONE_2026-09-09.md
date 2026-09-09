# TX16W / Cyclone — RESOLVED 2026-09-09

The 120-sample drumkit loads and plays in Cyclone. Confirmed by Esa: no
warnings, disk 1 asks for disk 2 by name, and every pad triggers its own sample
from C1 to B9 (Cyclone's note naming).

**Read `typhoon-tx16w-format.txt` before touching any of this.** It now carries
every finding below with the measurement behind it.

## The seven faults, in the order they were found

| # | Fault | Evidence |
|---|---|---|
| 1 | Wave reference names turned `_` into a space | 0 of 859 corpus references contain a space; 273 contain `_`. 49 of 120 references named a wave on no disk. |
| 2 | No `.X01` setup shipped | Only `.X01` ever names a diskette (78 refs); all 538 `.O*` and 417 `.P*` use `0xFF`. |
| 3 | Voice/performance references said "disk unknown" | With `0xFF` Cyclone can only say `Missing wave X`; with a label it says `(from LABEL)`. |
| 4 | Waves had no `INST`/`MARK` and a free length | 38/38 corpus drum waves carry both and are an exact multiple of 64 frames. Ours: 8/120 and 4/120. Caused "wave length / loop adjusted" + "data after loop will not be loaded". |
| 5 | Disk label had an `_`; image filename ≠ label | All 18 corpus images have an alphanumeric label; 17 live in a file named after it. |
| 6 | 40 waves crammed into one group as split points | 538 of 538 non-empty corpus groups hold exactly ONE wave on ONE key. No corpus group uses a second split point. This is what made one sample span a stretch of keyboard. |
| 7 | `voice_key = key + 1` | The key number IS the MIDI note number. Every pad sounded a semitone high. |

Plus: performance entry `Parm` byte 6 was 0, a value that appears in none of the
417 corpus entries (it is 1, 2, 3 or 5); volume was 96 where all 417 use 108.

## The two mistakes in method, which cost more than any of the bugs

1. **The manual was never read.** `Typhoon2000/Typhoon User's Manual.pdf` sat in
   the example-files folder the whole time and answers the central question
   directly. §4.3.1: `Missing wave X (from DISK)` is **the request, not an
   error** — the operator switches diskettes while it is displayed and presses
   ENTER, and "the query is automatically withdrawn if the correct item is
   found". Days were spent treating a working prompt as a failure.

2. **The corpus was read as prescriptive where it is only descriptive.** The
   library disks are melodic instruments; they never need key 0, and their
   companion disks are supplementary rather than half a kit. Both facts were
   turned into rules — "keys are one-based", "make every disk standalone" — and
   the second one destroyed the working automatic disk fetch, which then got
   reinstated. Measure the corpus, but check the manual for intent.

## How to verify a build

```
lua  tests/tx16w_export_regression.lua <export-folder>   # 656 checks
python3 tests/tx16w_corpus_diff.py <folder>/DISK1.img    # diff vs a real Yamaha disk
```

The Lua test encodes our own reading of the format and has passed on a broken
export before. The corpus diff is the non-circular one. Its reference corpus is
`~/Downloads/tx16w/tx16w_typhoon_example_files/sd/cyclone-format/`; set
`TX16W_REFERENCE` if it moves.

## Loading a multi-disk kit

Load disk 1, select the `.P01`. At `Missing wave X (from LABEL)`, swap to that
image **while the prompt is showing**, then press ENTER (`More`). Not `Skip`.
