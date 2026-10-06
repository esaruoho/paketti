# WIKI PAGE / REPORT CARD: Destructive forward-loop crossfade
# WHAT THIS CARD SPAWNS:
# codespace: PakettiLoopCrossfade.lua, legacy callers, tests/loop-crossfade.lua
# thinkspace: loop-crossfade.session.md; manual/CrossfadeComparison.md
# areaspace: sample-buffer loop tail processing; retain whole-sample reverse blend.
# SESSION: loop-crossfade.session.md
# RESULT: Local working-tree implementation; no commit, push or PR.
# Files: PakettiLoopCrossfade.lua, main.lua, PakettiProcess.lua, PakettiExperimental_Verify.lua,
# tests/loop-crossfade.lua, manual/LoopCrossfade.md, manual/CrossfadeComparison.md,
# PLAN.md, features/loop-crossfade.*, features/INDEX.md and generated card views.
# WATCH: PakettiLoopCrossfadeSample PakettiLoopCrossfadeApply PakettiLoopCrossfadeDialog crossfade_loop crossfade_loop_edges_fixed_end crossfade_with_fades
# RESULT-LOG >>
#   2026-10-06  direct-commit  touched: PakettiLoopCrossfadeSample PakettiLoopCrossfadeApply PakettiLoopCrossfadeDialog crossfade_loop crossfade_loop_edges_fixed_end crossfade_with_fades
Feature: Blend pre-loop audio into the tail without silence dips
  @sim-verified @runtime-untested
  Scenario: Linear and Equal Power preserve the original wrap transition
    # cite: PakettiLoopCrossfade.lua PakettiLoopCrossfadeSample
    Given editable mono or stereo audio with a forward loop and pre-loop frames
    When I apply Auto or a bounded frame or millisecond fade
    Then only the loop tail is modified using non-overlapping source frames
    And the final loop frame equals the original frame before loop start
    And an Equal Power blend exceeding headroom is rejected before writing

  @sim-verified @runtime-untested
  Scenario: Process selections or individual loops across an instrument
    # cite: PakettiLoopCrossfade.lua PakettiLoopCrossfadeApply
    Given a selected range or samples with their own forward loops
    When I crossfade the sample or instrument
    Then a selection creates forward loop markers using frame or time alignment
    And no selection uses each sample's existing forward loop
    And empty or read-only buffers and unsuitable ranges are skipped with reasons

  @sim-verified @runtime-untested
  Scenario: Clean up write failures and report marker failures honestly
    # cite: PakettiLoopCrossfade.lua PakettiLoopCrossfadeSample
    Given a successfully prepared buffer
    When a write fails
    Then the buffer is finalized and the status indicates possible partial changes
    And a loop-marker failure is reported rather than counted as success

  @sim-verified @runtime-untested
  Scenario: Fix legacy targets and end-frame indexing
    # cite: PakettiExperimental_Verify.lua crossfade_loop
    # cite: PakettiProcess.lua crossfade_loop_edges_fixed_end
    Given the selected sample differs from instrument sample one
    When I invoke the legacy experimental crossfade
    Then the selected sample is processed without disabling sample monitoring
    Given a fixed-end loop ending on the final sample frame
    When I apply its edge fades
    Then no write exceeds the buffer and the loop end is faded to zero

  @sim-verified @runtime-untested
  Scenario: Configure curves and lengths without accidental repeat processing
    # cite: PakettiLoopCrossfade.lua PakettiLoopCrossfadeDialog
    Given the dialog and registered sample or instrument shortcuts
    When I choose an explicit length mode
    Then its value control becomes active
    And repeated key events and non-trigger MIDI messages do not process audio

  @sim-verified @runtime-untested
  Scenario: Preserve the creative whole-sample reverse blend
    # cite: PakettiProcess.lua crossfade_with_fades
    Given the existing whole-sample forward/reverse averaging command
    When it is invoked on editable audio
    Then its averaging and six-frame edge envelope remain the same
    And read-only slices are rejected and write errors finalize prepared changes
