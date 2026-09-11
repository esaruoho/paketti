# Pure Gherkin test extracted from features/issue-followup-utilities.feature
# (report-card banner stripped; inline # cite: traceability kept)
# Regenerate: python3 print-card.py features/issue-followup-utilities.feature

Feature: Issue follow-up utilities
  As a Paketti user, I want small workflow gaps closed, So that delay editing, automation editing, menu visibility, and eSpeak batch output behave predictably.

  @shipped @code-verified @runtime-untested
  Scenario: Phrase delay nudging makes delay columns visible
    # cite: PakettiPhraseEditor.lua PakettiPhraseEditorNudgeWithDelay and PakettiPhraseEditorNudgeByDelay — reveal phrase and selected sequencer-track delay columns
    Given a phrase delay nudge is invoked for a selected phrase or cell
    When Paketti applies the nudge
    Then the phrase delay column is visible
    And the selected sequencer track delay column is visible when applicable

  @shipped @code-verified @runtime-untested
  Scenario: Reverse selected automation
    # cite: PakettiAutomationCurves.lua PakettiAutomationCurvesReverseSelection — mirrors selected automation point times and preserves outside points
    # cite: PakettiMenuConfig.lua Track Automation reverse entry — exposes the action from the configured menu
    Given an automation envelope exists with a selected range or a full-pattern fallback
    When the user invokes Reverse Selected Automation
    Then points inside the range are mirrored in time with their values preserved
    And points outside the range remain unchanged

  @shipped @code-verified @runtime-untested
  Scenario: eSpeak can be hidden through Paketti Menu Config
    # cite: Paketti0G01_Loader.lua eSpeak preference and category — adds the eSpeak visibility toggle
    # cite: PakettiMenuConfig.lua eSpeak menu gate — registers eSpeak menu entries only when enabled
    Given the eSpeak category is disabled in Paketti Menu Config
    When Renoise registers Paketti menus
    Then Paketti does not register the eSpeak menu entries

  @shipped @code-verified @runtime-untested
  Scenario: Generate one eSpeak output per text line
    # cite: PakettieSpeak.lua PakettieSpeakGenerateLines — serializes rendering and sample loading for each non-empty line
    Given the eSpeak dialog contains multiple non-empty lines
    When the user chooses Generate Instruments per Line
    Then Paketti creates one instrument and sample for each line
    When the user chooses Generate Drum Kit per Line
    Then Paketti creates one instrument with one-key samples mapped from C-2 upward
