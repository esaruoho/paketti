# WHAT THIS CARD SPAWNS:
# codespace: SampleBrain/Logger.lua, jobs/JobRunner.lua, matching/Matcher.lua, render/Renderer.lua, ui/MainDialog.lua, tests/test_logging.lua
# thinkspace: samplebrain-diagnostics.session.md and transcript bundle
# areaspace: SampleBrain diagnostics and cooperative candidate search; preserve match ordering and DSP math
# SESSION: samplebrain-diagnostics.session.md
# RESULT: Worktree changes; no commit, push or PR. Files: above, .gitignore, PLAN.md, card/session/bundle, INDEX.md and generated views.
# WATCH: Logger JobRunner checkpoint Renderer
# RESULT-LOG >>
#   2026-10-13  direct-commit  touched: Renderer
#   2026-10-13  direct-commit  touched: JobRunner
#   2026-10-13  direct-commit  touched: Logger JobRunner checkpoint
Feature: Diagnose SampleBrain jobs from a persistent local log
  @code-verified @runtime-untested
  Scenario: Preserve the last checkpoint and job outcome
    # cite: SampleBrain/Logger.lua Logger.write; SampleBrain/jobs/JobRunner.lua idle_handler JobRunner.yield; SampleBrain/tests/test_logging.lua
    Given SampleBrain has a writable bundle folder
    When a job yields, finishes, fails or is cancelled
    Then SampleBrain/samplebrain.log contains timestamped flushed diagnostics
    And failures include the coroutine traceback
    And completion and cancellation remove the idle notifier

  @built @runtime-untested
  Scenario: Expose work inside a target block
    # cite: SampleBrain/matching/Matcher.lua checkpoint search_basic search_reversed search_synaptic; SampleBrain/render/Renderer.lua Renderer.render
    Given a target block needs a long candidate search
    When matching proceeds
    Then cooperative checkpoints identify the target, channel and candidate count
    And the log includes settings, block timings, chosen indices, distances and render stage boundaries

  @code-verified @runtime-untested
  Scenario: Preserve matching and rendering results
    # cite: SampleBrain/tests/test_dsp.lua; SampleBrain/tests/test_oracle.lua
    Given the existing DSP and oracle suites
    When run using LuaJIT after the diagnostics change
    Then both suites pass
