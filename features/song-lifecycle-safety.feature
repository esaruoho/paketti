Feature: Song-lifecycle safety for canvas dialogs and song observers
Context: Global

  # ============================================================================
  # KNOWLEDGEBASE ENTRY — "This crash happened" (2026-06-09)
  # ============================================================================
  #
  # THE CRASH (verbatim class, recurs across tools)
  # -----------------------------------------------
  # Renoise SIGSEGV (V3.5.4) while New Song / Load Song was creating a document,
  # with a canvas tool (HyperEdit / ParameterEditor / 8120) left open. Backtrace:
  #
  #     TWeakRefOwner::SOnWeakReferencableDying   <- 💥 crash
  #     TDocumentNode::~TDocumentNode
  #     TPattern::~TPattern
  #     TPatternPool::~TPatternPool
  #     TRenoiseSong::~TRenoiseSong               <- the OLD song is being freed
  #     TRenoiseApp::OnSetNewSong
  #     TApplication::LoadTemplateDocument / CreateNewDocument
  #
  # WHY IT HAPPENS (simply put)
  # ---------------------------
  # Every Renoise song object (pattern, track, device, parameter) is a
  # "weak-referenceable" C++ node. When the old song is destroyed, each dying
  # node walks a list of everyone still pointing at it and tells them to let go
  # (SOnWeakReferencableDying). If a Paketti tool LEFT an observer attached, or a
  # canvas still reading song data, that tool is a STALE pointer in the list —
  # walking it dereferences freed memory -> SIGSEGV. The specific node that
  # crashes (a TPattern) is incidental; it is just the first node in the
  # destruction order whose weak-ref list still contains the dangling Lua hook.
  #
  # THE ROOT RULE — two lifecycle hooks, and the difference is the whole bug
  # ------------------------------------------------------------------------
  #   • app_release_document_observable  fires BEFORE the old song is freed.
  #     renoise.song() still returns the OLD song -> observers detach cleanly.
  #     THIS IS THE ONLY SAFE PLACE to drop song hooks and close song-bound canvases.
  #   • app_new_document_observable      fires AFTER the new song exists.
  #     renoise.song() returns the NEW song -> too late: the old song is already
  #     dying, and remove_notifier() can't even find the old song's observable.
  #
  # STATUS OF THE THREE CANVAS TOOLS (as of 2026-06-09 — all three now fixed)
  # -------------------------------------------------------------------------
  #   • PakettiEightOneTwenty.lua  — FIXED (commit eb12d7b): registers
  #     app_release_document_observable, closes dialog+canvas, detaches all
  #     observers/timers before the song dies.  @hw-verified
  #   • PakettiHyperEdit.lua       — FIXED (2026-06-09): registers a guarded
  #     app_release_document_observable on dialog open that calls the existing
  #     idempotent PakettiHyperEditCleanup() (detaches transport.playing /
  #     selected_track_index / track.devices observers + playhead timer + mouse
  #     monitor) and closes the dialog, before the old song is freed. The
  #     observer is also removed inside PakettiHyperEditCleanup().  @built @untested-in-renoise
  #   • PakettiCanvasExperiments.lua — FIXED (2026-06-09): adds
  #     PakettiCanvasExperimentsHandleReleaseDocument (registered once at load,
  #     persistent because the global auto-open observer outlives the dialog)
  #     which removes the global device observer and runs the idempotent
  #     PakettiCanvasExperimentsCleanup() before the old song dies. The existing
  #     app_new_document_observable handler still reinstalls on the new song.  @built @untested-in-renoise
  #
  # THE FIX PATTERN (port of the 8120 seatbelt)
  # -------------------------------------------
  # In each song-bound canvas tool, on dialog open, register a guarded
  # app_release_document_observable handler that: closes the canvas + dialog,
  # nils the canvas/ui refs, and removes every notifier from the CURRENT (old)
  # song's observables. Make teardown idempotent (has_notifier-guarded) so it is
  # safe to run twice (dialog-close path + song-release path).
  #
  # WATCH: app_release_document_observable PakettiHyperEditCreateDialog PakettiHyperEditRemoveObservers PakettiCanvasExperimentsCreateDialog
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-09  direct-commit  touched: app_release_document_observable

  Scenario: 8120 survives New Song with its canvas open
    Given the Groovebox 8120 dialog and canvas are open
    When the user triggers New Song
    Then 8120 detaches its observers and closes on app_release_document_observable
    And Renoise frees the old song without a SIGSEGV

  Scenario: HyperEdit must survive New Song / Load Song with its canvas open
    Given the HyperEdit dialog and canvas are open with song observers attached
    When the user triggers New Song or Load Song
    Then HyperEdit must detach transport/track/device observers and close on app_release_document_observable
    And Renoise must free the old song without a SIGSEGV in TWeakRefOwner::SOnWeakReferencableDying

  Scenario: ParameterEditor must survive New Song / Load Song with its canvas open
    Given the ParameterEditor (CanvasExperiments) dialog is open observing the selected device
    When the user triggers New Song or Load Song
    Then ParameterEditor must detach its observers from the OLD song on app_release_document_observable
    And it must not rely solely on app_new_document_observable, which fires too late to detach cleanly
