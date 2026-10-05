# Catch native sample loading: proposed design

Status: proposal only. No automatic import watcher was added. The implemented Sample Playback Quality menus change settings only when invoked. Source basis: the complete SimpleInterpolation 1.0.2 main.lua and Paketti's current loader preferences; live Renoise event ordering has not been verified for this design.

## What we want to catch

An optional default for interpolation and oversampling should reach audio loaded through Renoise's browser, Finder drag/drop, native recording, and replacement of an existing sample. Paketti already applies `pakettiLoaderInterpolation` and `pakettiLoaderOverSampling` in its own loading/recording/generation paths. A native watcher fills the paths outside those helpers.

The difficult part is distinguishing a new raw audio import from opening a song, loading an instrument with deliberately saved settings, duplicating a sample, slicing, undo/redo, rendering, or another tool creating audio. The detector must explain which events it handles and what it leaves ambiguous. A setting equal to Renoise's default does not establish its provenance.

## How SimpleInterpolation tries to do it

It watches the song instrument list, each instrument's sample list, and each sample's buffer and name observables. On document release it detaches the observers; on a new document it attaches again. Sample-list changes rebuild that instrument's subscriptions; instrument-list changes rebuild all subscriptions.

For each watched sample it remembers whether audio exists and its name. A buffer event that changes an empty slot into a populated slot immediately applies defaults. A populated buffer replacement applies if its name has changed; otherwise it marks the sample pending. A subsequent name notification applies if pending. The idle callback clears pending flags, limiting that association to a short event window.

Empty inserted sample slots teach it a supposed Renoise baseline, initially Cubic and oversampling off. The selected interpolation default is applied only if the sample still equals that baseline. The oversampling preference can only force on, and only when the baseline is off. Disabled defaults leave existing samples untouched.

## Where that can fail

| Case | Weakness in the inspected code | Better treatment |
| --- | --- | --- |
| Populated sample inserted before observers attach | The watcher records it as already populated, without applying defaults | Record list insertion as a candidate, but do not classify every insertion as raw audio |
| Replacement file has the same sample name | Buffer replacement alone stays pending; no name change means no application | Classify replacement independently of names if event evidence permits |
| Explicit Cubic in an imported instrument | Looks identical to a Renoise default | Preserve instrument imports; never infer authorship solely from setting equality |
| Duplication or another tool creates a buffer | Empty-to-populated transition resembles native import | Cooperating Paketti paths need explicit operation markers; other tools remain ambiguous |
| Edited empty slot used to learn baseline | Learns a user/tool setting as Renoise's default | Verify baseline in a controlled experiment; do not treat arbitrary slots as authoritative |
| Buffer and name notifications arrive in a different order | Idle reset may clear pending state too early | Capture event traces and coalesce based on observed behavior |
| A write fails | pcall result is ignored, but status may report success | Count changed/skipped/failed targets and retain reasons |
| Song opening or undo/redo reconstructs samples | Generic notifications may resemble imports | Trace document lifecycle and undo behavior before defining exclusions |

The preservation claim should be “preserves cases we can identify,” not “always preserves saved settings.” With these observables alone, perfect classification may be impossible.

## Recommended architecture

Start with an event recorder, not a setting writer. Keep one registry per song, one entry per instrument, and one per sample object. Record event kind, order, previous/current audio presence, sample name, interpolation, oversampling, and whether a known Paketti operation is running. Keep logs bounded; never poll sample audio or hash entire buffers.

Attach on the current document and new-document notifications. Detach all observers while the old document is still valid. Coalesce notifications into candidates and resolve them from an idle callback, checking that the sample still belongs to the active song. Reconcile only the changed instrument where possible rather than rebuilding the entire song's watchers. Prevent duplicate notifiers and bound candidate lifetime. Sample indices can shift; use object identity rather than indices alone.

Separate detection from policy. Detection produces a reason such as `empty slot received audio`, `sample inserted populated`, or `existing buffer replaced`. Policy decides whether that evidence is sufficient under the user's selected coverage mode. Keep native-import defaults independently disabled by default, with interpolation “Leave unchanged” plus four modes and oversampling “Leave unchanged / On / Off.” Reuse the existing loader preference values only through an explicit “Use Paketti loader settings” option; do not silently turn those preferences into song-wide rules.

Known Paketti loaders, renderers and duplicators can provide operation markers so the watcher leaves their deliberate settings alone. Markers should have nesting and guaranteed cleanup after errors. They only establish provenance for participating code; they cannot identify actions by arbitrary other tools.

Begin with a conservative policy: watch empty-to-populated transitions outside document initialization and marked operations. Explain that instrument import, recording and duplication can still have overlapping event shapes until traces prove separability. Ambiguous candidates should remain unchanged and appear in a diagnostic log. Offer a deliberate “Apply defaults to newly added samples” action for reviewable candidates rather than silently guessing.

## Experiments required before enabling automatic writes

For every case below, record the events first and compare resulting settings with the pre-operation values. The tests must include interpolation both matching and differing from Renoise's default, oversampling on/off, and duplicate or unchanged names.

| Operation | Acceptance condition |
| --- | --- |
| Browser load into an empty slot | One candidate, correct sample, one application |
| Drag WAV onto Sample Editor and Sample List | Correct classification for both empty and occupied targets |
| Replace audio with a differently named file | One application without losing other deliberate sample settings |
| Replace audio with the same filename/name | Detection does not depend solely on renaming |
| Record into an empty or occupied sample | Defaults apply after completion, never midway through recording |
| Load XRNI with saved settings, including Cubic | All saved interpolation/oversampling choices survive |
| Open XRNS with many instruments | Existing song settings survive; initialization causes no edits |
| Duplicate and slice a sample | Copied/inherited settings survive |
| Paketti loader, renderer and generator | Explicit settings survive; no double application |
| Edit/process an existing buffer | Existing settings survive |
| Undo and redo an import | Undo restores both audio and settings; watcher does not fight restoration |
| Delete sample/instrument with a queued candidate | No stale-object access or edits to the shifted index |
| Close/open documents and reload the tool repeatedly | No duplicate callbacks, leaked observers or old-song writes |
| Failed/read-only target setter | Failure is visible and success counts stay honest |

Verify the actual buffer observable behavior for same-size in-place replacement and recording: a notification is not guaranteed merely because audio changed. If Renoise exposes no event distinguishing two cases, document the limitation instead of claiming complete native coverage.

## Undo and rollout

Observer-driven preference writes may form a separate undo step or interact badly with the native import's undo step. Verify this experimentally; do not assume `describe_undo` merges asynchronous edits into the import. Coalescing improves event stability but may change undo grouping.

Ship diagnostic mode first, then opt-in conservative application only after the trace matrix supports it. Keep a clear disable switch, a bounded reason log, and a manual scope action as the fallback. Existing checked menus remain useful regardless of whether reliable automatic classification proves possible.

Related: [source comparison](../notes/simple-interpolation-comparison.md), [manual-control report card](../features/sample-playback-quality.feature).
