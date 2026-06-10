Feature: Groovebox 8120 Record button records into a Pakettified instrument
Context: Global

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # Built 2026-06-09. Pressing an 8120 row's Record button now loads a fresh
  # Paketti Default Instrument chassis into that row's instrument slot before
  # recording, so the recorded take lands inside a Pakettified instrument
  # (pitch-bend modulation + *Instr. Macros), not a bare instrument.
  #
  # INNARDS (PakettiEightOneTwenty.lua):
  #   • PakettiEightOneTwentyRowRecordToggle(row_index) — phase 0 (Record press):
  #     selects the row's instrument slot (ii) and calls
  #     pakettiPreferencesDefaultInstrumentLoader() (PakettiSamples.lua:372,
  #     load_instrument into the selected slot + PakettiApplyLoaderModulationSettings)
  #     BEFORE starting Renoise sample recording. A fresh chassis each press.
  #   • PakettiEightOneTwentyFinalizeRecordedSample(row_index, target) — phase 1
  #     (Record press again): maps the recorded take 00-7F and points it at the
  #     chassis modulation set (sample.modulation_set_index = 1 when
  #     instrument.sample_modulation_sets > 0) so the take is Pakettified.
  #
  # DESIGN DECISION (confirmed with Esa 2026-06-09): "fresh chassis each time" —
  # every Record press loads a clean Paketti Default Instrument into the slot
  # (replacing a prior take). One row = one sound, clean take each time.
  #
  # WATCH: PakettiEightOneTwentyRowRecordToggle PakettiEightOneTwentyFinalizeRecordedSample pakettiPreferencesDefaultInstrumentLoader
  # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#   2026-06-10  direct-commit  touched: pakettiPreferencesDefaultInstrumentLoader
#   2026-06-09  direct-commit  touched: pakettiPreferencesDefaultInstrumentLoader

  Scenario: Record press loads a Paketti Default Instrument then starts recording
    Given the Groovebox 8120 dialog is open
    And a row's instrument slot is selected
    When the user presses Record on that row
    Then the Paketti Default Instrument is loaded into that row's instrument slot
    And sample recording starts immediately
    # @built @untested-in-renoise

  Scenario: Second Record press injects the sample into the Paketti chassis
    Given recording is in progress on a row whose slot holds the Paketti Default Instrument
    When the user presses Record again
    Then recording stops
    And the recorded sample is mapped 00-7F as the row's primary sample
    And the recorded sample is pointed at the instrument's modulation set (Pakettified)
    # @built @untested-in-renoise
