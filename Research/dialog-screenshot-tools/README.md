# Clean dialog-screenshot batch tooling

Captures each Paketti dialog as a clean, window-cropped PNG (no desktop), via PakettiMCP.

1. `winlist.swift` / `winall.swift` — `swiftc -O` these; CGWindowListCopyWindowInfo lists
   Renoise dialog windows + IDs (no Accessibility needed).
2. `batch_clean.py <safe_dialogs.json>` — opens each Dialog-of-Dialogs entry via PakettiMCP
   `paketti_eval`, finds the NEW dialog window (before/after diff), `screencapture -x -o -l<id>`
   captures just that window, toggles it closed.
3. `recapture.py <missed.json>` — retries misses with a longer wait.
4. Output -> ~/Downloads/paketti-dialogs-clean ; then pngquant or keep lossless, copy to
   manual/dialog-screenshots/, regenerate manual/DIALOG-GALLERY.md + manifest.json.

Known limits: file-picker dialogs (native sheet blocks unattended runs) are pre-skipped;
a few dialogs that need specific song/device state, or don't open a standalone window,
need on-demand capture. Result: 155 of ~165 captured cleanly.
