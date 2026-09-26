# Normalize Selected Channel Session

## How to get back

- Transcript path: not bundled in this worktree session yet
- Session ID: unavailable from the active tool context
- Resume command: unavailable until the transcript ID is identified
- Date: 2026-09-26
- Note: session file created during live implementation; click-back can be backfilled by content search for `normalize-selected-channel`.

## User Request

Esa reported that Paketti Normalize Sample did not truly respect right-channel-only sample-editor selection. With a loud left channel and quiet right channel, selecting only the right channel and normalizing still raised the right channel only as far as the loud left channel allowed.

## Implementation Notes

I traced the Normalize Sample menu/keybinding path to `normalize_selected_sample_ultra_fast()` in `PakettiProcess.lua`. The older slice-aware normalizer already had selected-channel logic, but the ultra-fast path and its large-sample streaming fallback found one peak across all channels and wrote all channels.

I added `paketti_selected_sample_channels(buffer)`, which maps `buffer.selected_channel` to concrete channel numbers: left only, right only, or every channel. The ultra-fast and streaming normalizers now use that selected channel list for peak detection, gain application, progress denominators, logging, and status text.

For the reported case, the right channel's own peak now determines the gain, and only the right channel is written. The loud left channel no longer caps the right channel's normalization.

## Verification

- Code inspection confirms both `normalize_selected_sample_ultra_fast_coroutine()` and `normalize_selected_sample_streaming_coroutine()` iterate `channels_to_normalize` for peak detection and gain writes.
- Runtime verification in Renoise was not performed from this shell session.

## Follow-up Request and Fix

Esa then reported that neither user-facing normalize command reliably obeyed the full Sample Editor selection: `Normalize Sample` ignored the selected frame range, and `Normalize Selected Sample or Slice` normalized the whole sample instead of the selected channel and range.

The frame-range resolver now treats Renoise's empty `{0, 0}` selection as no selection, clamps valid bounds to the buffer, and falls back to the full sample only when no valid selection exists. The fast and streaming normalizers scan and write only those bounds. The selected sample/slice normalizer now scans and writes only the selected channels as well as its already-resolved sample or slice range. Unselected channels and frames are not rewritten.

Verification in this follow-up: not yet run. Renoise runtime behavior remains unverified in this shell session.
