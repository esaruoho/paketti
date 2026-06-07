Feature: <Short name of the thing Paketti does>
Context: <Renoise context>      # Global | Pattern Editor | Sample Editor | Instrument Box | Mixer | Phrase Editor | Sample Mappings | DSP Device | Main Menu | …

  # HOW THIS WIRES ITSELF INTO THE DREAMGRAPH (zero-token, zero-Claude):
  #
  #   • The `Context:` line above (or the context's name appearing in the Feature: title)
  #     makes this feature `covers` that context node — so it shows up when you ask
  #     `convey graph neighbors "<Context>" both`.
  #   • Any PakettiXxx.lua filename you mention in a step becomes a `references` edge to
  #     that module node.
  #   • Forum requests whose titles share words with the bindings in this context already
  #     `requests`-link to it — so this feature, the code that implements it, and the
  #     8,000 forum posts asking for it all hang on the same context node.
  #
  # Drop this file (renamed) into features/ and either run `convey graph sync ~/work/paketti`
  # once, or leave `convey graph watch ~/work/paketti` running — it re-ingests on save.
  #
  # Write one Scenario per observable behavior. Given = starting state, When = the binding
  # or menu entry the user triggers (use the REAL name so it matches the binding index),
  # Then = the observable result.

  Scenario: <what happens, in a few words>
    Given <the starting state — what's selected / open / loaded>
    When the user triggers "<Context>:Paketti:<exact binding or menu name>"
    Then <the observable result>

  Scenario: <another behavior>
    Given <starting state>
    When the user triggers "<exact name>"
    Then <observable result>
    And <any secondary result>
