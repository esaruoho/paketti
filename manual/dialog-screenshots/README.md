# Paketti dialog screenshots

148 clean window-cropped PNGs (one per dialog), named `NNN_<Dialog Name>.png`.

- **Gallery:** `../DIALOG-GALLERY.md`
- **Manifest for bots:** `manifest.json` maps `"Dialog Name" -> path`, so PakettiAskBot can look up and attach the right screenshot.

## How they were made
1. PakettiMCP `paketti_eval` opens each Dialog-of-Dialogs entry in turn.
2. A compiled Swift `CGWindowListCopyWindowInfo` helper finds the new dialog's window ID.
3. `screencapture -x -o -l<id>` grabs just that window (cropped, no desktop).
4. `pngquant` compresses (~4x).

File-picker dialogs (20) are skipped (their native sheet blocks an unattended run); capture those on-demand. ~17 inline/canvas dialogs need follow-up.
