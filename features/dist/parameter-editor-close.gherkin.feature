# Pure Gherkin test extracted from features/parameter-editor-close.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/parameter-editor-close.feature

Feature: Close the unfocused parameter editor
  @sim-verified @runtime-verified
  Scenario: Hide editors from Pattern Editor or Global closes the custom dialog
    # cite: PakettiLoaders.lua hide_all_external_editors; PakettiCanvasExperiments.lua PakettiCanvasExperimentsCloseDialog
    Given the Selected Device Parameter Editor is visible but unfocused
    When the existing hide external editors shortcut is invoked
    Then parameter editor automation observers and timers are cleaned up
    And the parameter editor closes without requiring its keyboard focus
    And existing external device editors also close

  @sim-verified @runtime-untested
  Scenario: Repeated hide calls and an unavailable parameter editor remain safe
    # cite: PakettiLoaders.lua hide_all_external_editors; tests/parameter-editor-close.lua
    Given the parameter editor is already closed or its module is unavailable
    When hide external editors is invoked
    Then external device editors still close without a missing-function error
