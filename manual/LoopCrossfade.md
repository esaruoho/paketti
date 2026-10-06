# Loop Crossfade

Open **Sample Editor → Paketti → Process → Loop Crossfade...**, or **Tools → Paketti → Samples → Loop Crossfade...**.

Select the portion you want to loop, choose settings and press **Crossfade Sample**. The selection becomes a forward loop. With no meaningful selection, the command uses the sample's existing forward loop. Choose **Existing loop** to ignore the selection. Full-buffer and single-frame selections count as no selection.

The command destructively blends audio immediately before the loop into its tail. It preserves sample length, the pre-loop source and all audio outside that tail. The last loop frame becomes the original frame immediately before the loop start, retaining their natural transition. You need at least two frames of pre-loop audio. Native sample Undo is available; error messages indicate when a partially applied edit may need Undo.

**Linear** suits correlated/phase-aligned audio. **Equal Power** avoids the energy dip often heard with weakly correlated audio, but can increase correlated peaks. If the calculated blend exceeds [-1,1], it is skipped before writing; lower sample gain or choose Linear. No automatic normalization or clipping is applied.

**Auto** uses the shorter of the loop length and the available pre-loop audio. It can change the entire loop. Choose **Frames** or **Milliseconds** for a shorter explicit fade; the length is rounded to whole frames and capped safely. A fade below two frames is skipped. Settings persist while the tool is loaded.

**Crossfade Instrument** processes every eligible sample. With a selection, **Same frames** copies its frame positions; **Same time** translates those positions for each sample rate. Without a selection, each sample uses its own loop, including when the selected sample is empty. Empty samples, read-only slice aliases, unsuitable loop modes/ranges and insufficient pre-loop audio are skipped with counts and reasons. Existing backward/ping-pong loops are skipped; selection-created loops use forward mode.

Bindable Sample Editor shortcuts: **Loop Crossfade Dialog...**, **Loop Crossfade Sample**, **Loop Crossfade Instrument**. The two processing actions also have MIDI trigger mappings. Direct processing uses the current dialog settings (defaults: Equal Power, Auto, selection-or-existing-loop, same frames). Repeated key events are ignored. Reapplying processes the already edited tail; Undo before comparing alternate settings.

The older **Crossfade Loop** shortcut retains its selection-end-derived fade-length gesture, now using the selected sample, a bounded Linear blend and no added silence fades. **Cross-fade Loop Edges (Fixed End)** remains a separate mirror/edge-fade effect with corrected end indexing. **Cross-fade Sample w/ Fade-In/Out** remains the whole-sample forward/reverse blend.

Workflow credit: Phaos SimpleXfade and afta8 xfade pow. The new implementation is independently written. Logic and registration were verified with mocks; listening, displayed controls and native Undo still need verification in Renoise.
