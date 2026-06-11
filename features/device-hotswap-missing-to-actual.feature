Feature: Device hotswap — missing plugins → actually-installed equivalents
Context: Mixer

  # WHAT THIS SPAWNS / RESULT
  # -------------------------
  # STATUS: @designed (the IDEA — not built yet). This card is the seed.
  #
  # THE PROBLEM. You open a Renoise song made on a Windows PC. It references VST
  # effects/instruments that don't exist on this Mac. Renoise shows them as
  # missing/greyed — the song plays wrong or not at all. Today the only fix is
  # manual: delete each dead device, find an equivalent, and re-dial every knob
  # by hand from memory.
  #
  # THE IDEA. Make Paketti do the swap automatically:
  #   1. SCAN a batch of .xrns and report which plugins/VSTi/VSTfx/AU each song
  #      needs, and which of those are NOT installed on THIS machine.
  #   2. For each missing device, look up a "legacy -> actual" mapping (e.g.
  #      "ValhallaRoom VST" -> "ValhallaRoom AU", "Massive VST" -> "Massive AU")
  #      to find an installed equivalent.
  #   3. HOTSWAP: delete the dead device, insert the equivalent in the same chain
  #      slot, then INJECT the old device's parameters from the song's song.xml
  #      by MATCHING PARAMETER NAMES. If the VST and the AU both expose the same
  #      named parameters (or both expose 8 params in the same order), the dialed
  #      sound carries across the platform boundary intact.
  #
  # WHY IT'S GOLD: a Windows VST song becomes a Mac AU song with the SAME settings,
  # automatically. Cross-platform project portability that Renoise itself can't do.
  #
  # CODESPACE (what this would own / cite):
  #   • NEW: PakettiDeviceHotswap.lua — the scanner, the mapping registry, the swap+inject engine.
  #   • REUSES PakettiXRNSProbe.lua — already decrypts the JUCE ioz/LZF/plist .xrns
  #     container in pure Lua and can surface the embedded song.xml + device list.
  #   • REUSES available_device_infos / available_plugin_infos — to know what IS installed
  #     (seen in PakettiLoadDevices.lua, PakettiLoadPlugins.lua, PakettiCompat.lua).
  #   • REUSES device chain ops — insert_device_at / delete_device_at / active_preset_data
  #     and device.parameters[i] (name/value) for the inject step.
  #
  # AREASPACE (boundary): operates on track/sample-FX DEVICE CHAINS and on .xrns
  # FILES on disk. It does NOT touch pattern/note data, sample audio, or the MCP
  # bridge. The .xrns dissection is the ONLY overlap with the (separate) MCP/Claude
  # bridges card — they share no code.

  # =====================================================================
  # PART A — Batch scan: what's missing across a folder of songs
  # =====================================================================

  @designed
  Scenario: Scan a folder of .xrns and report missing devices per song
    Given a folder containing many .xrns files
    When the user runs "Device Hotswap: Scan Folder for Missing Devices"
    Then each .xrns is dissected (via the XRNS probe path) for its referenced
         VST / VSTi / AU / native device identifiers
    And each identifier is checked against this machine's available_device_infos
        and available_plugin_infos
    And a report lists, per song, which devices are PRESENT vs MISSING

  @designed
  Scenario: Scan the currently-open song only
    Given a song is loaded that references an uninstalled VST effect
    When the user runs "Device Hotswap: Scan Current Song"
    Then the report flags that device as missing
    And proposes an installed equivalent if the legacy->actual map has one

  # =====================================================================
  # PART B — The legacy -> actual mapping registry
  # =====================================================================

  @designed
  Scenario: A curated "this legacy -> this actual" map drives the swap
    Given a registry of mappings, each: { from = "<missing device id>",
          to = "<installed device id>", param_map = optional name->name table }
    When a missing device matches a "from" entry
    Then its "to" device is chosen as the swap target
    And the optional param_map renames parameters whose names differ between
        the VST and the AU (e.g. "Mix" on the VST -> "Dry/Wet" on the AU)

  @designed
  Scenario: User adds a mapping from an unresolved missing device
    Given the scan found a missing device with no mapping
    When the user picks an installed device as its equivalent and saves it
    Then a new legacy->actual entry is written to the registry (persisted in
         preferences) and reused on every future song

  @designed
  Scenario: Auto-suggest a mapping when names obviously match
    Given a missing "FooReverb VST" and an installed "FooReverb (AU)"
    When the scan runs
    Then the engine proposes the match automatically (fuzzy name match),
         pending one-click user confirmation — never a silent swap

  # =====================================================================
  # PART C — The hotswap + parameter injection
  # =====================================================================

  @designed
  Scenario: Hotswap a missing device and carry its settings across by name
    Given a track whose chain has a missing VST effect at slot N
    And the song.xml holds that VST's saved parameter name/value pairs
    And the legacy->actual map points it at an installed AU equivalent
    When the user runs "Device Hotswap: Swap & Inject Current Track"
    Then the dead device is removed from slot N
    And the AU equivalent is inserted at slot N (same position in the chain)
    And for each saved parameter, the value is written to the AU parameter with
        the matching name (via param_map if names differ)
    And parameters with no name match are reported as unmapped (not guessed)

  @designed
  Scenario: Positional fallback when both expose the same parameter count
    Given a missing device and its target both expose exactly 8 parameters
    And no reliable name match exists between them
    When the user opts into positional injection
    Then saved parameter i is written to target parameter i, 1..8
    And the user is warned this is positional (order-based), not name-based

  @designed
  Scenario: Batch hotswap across a whole song
    Given a song with several missing devices that all have mappings
    When the user runs "Device Hotswap: Swap & Inject Whole Song"
    Then every mapped missing device is swapped and injected in one undoable step
    And any unmapped missing devices are left in place and listed for follow-up

  # =====================================================================
  # PART D — Safety
  # =====================================================================

  @designed
  Scenario: Never destroy the original on an ambiguous swap
    Given a missing device whose mapping or parameter match is uncertain
    When a swap is attempted
    Then the engine requires explicit confirmation before deleting anything
    And offers to keep the dead device (muted/bypassed) alongside the new one
        so nothing is lost if the swap sounds wrong

  # OPEN QUESTIONS (for the build phase)
  # ------------------------------------
  #   • Where does Renoise store a VST's saved parameters in song.xml — named
  #     <Parameter> nodes, or an opaque base64 chunk? (Named = injectable;
  #     opaque = only the positional fallback works.) Confirm via XRNS probe.
  #   • Can active_preset_data round-trip an AU preset, or must we set
  #     device.parameters[i].value one by one? Test both.
  #   • Identity keys: match on plugin display name, on the VST/AU unique id, or
  #     both? Windows VST id vs Mac AU id will differ — the map bridges them.
