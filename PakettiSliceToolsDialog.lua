-- PakettiSliceToolsDialog.lua
-- Consolidated Slice Tools dialog — a single hub for all slice-related operations.
-- Each button calls an existing global function; no code is duplicated.
-- Sections are collapsible via checkboxes, with state persisted in preferences.

local dialog = nil

-- Helper: create a collapsible section with a checkbox header
local function collapsible_section(vb, pref_key, title, build_content)
  local section_column = vb:column{
    style="group",
    margin=4,
  }

  local content_column = vb:column{}
  if preferences[pref_key].value then
    build_content(content_column)
  end

  section_column:add_child(vb:row{
    vb:checkbox{
      value=preferences[pref_key].value,
      notifier=function(value)
        preferences[pref_key].value = value
        preferences:save_as("preferences.xml")
        -- Reopen dialog to reflect change
        if dialog and dialog.visible then
          dialog:close()
          dialog = nil
          PakettiSliceToolsDialog()
        end
      end
    },
    vb:text{text=title, font="bold", style="strong"},
  })

  if preferences[pref_key].value then
    section_column:add_child(content_column)
  end

  return section_column
end

function PakettiSliceToolsDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local sw = 45   -- numeric slice count button width
  local bw = 160  -- half-row button width
  local fw = 325  -- full-row button width
  local cw = 340  -- column width (fits fw + group margin; pin all three columns to this)

  -- Three-column layout, source order preserved:
  --   Column 1: Equal Slicing, Zero-Crossing Slicing, Advanced Slicing, All Slices Loop Mode
  --   Column 2: Slices to Pattern, Slices to Phrase, Slice Marker Management
  --   Column 3: DrumChain / Conversion, Beatsync, Specialized Tools, Oldschool Gap Fill
  local col1 = vb:column{width=cw, spacing=4,
    -- Section 1: Equal Slicing (Wipe & Slice)
    collapsible_section(vb, "pakettiSliceToolsShowEqualSlicing", "Equal Slicing (Wipe & Slice)", function(col)
      col:add_child(vb:row{
        vb:button{text="2", width=sw, notifier=function() slicerough(2) end},
        vb:button{text="4", width=sw, notifier=function() slicerough(4) end},
        vb:button{text="8", width=sw, notifier=function() slicerough(8) end},
        vb:button{text="16", width=sw, notifier=function() slicerough(16) end},
      })
      col:add_child(vb:row{
        vb:button{text="32", width=sw, notifier=function() slicerough(32) end},
        vb:button{text="64", width=sw, notifier=function() slicerough(64) end},
        vb:button{text="128", width=sw, notifier=function() slicerough(128) end},
        vb:button{text="256", width=sw, notifier=function() slicerough(256) end},
      })
      col:add_child(vb:row{
        vb:button{text="Wipe Slices", width=bw, notifier=function() wipeslices() end},
        vb:button{text="Double Slices", width=bw, notifier=function() doubleslices() end},
      })
      col:add_child(vb:row{
        vb:button{text="Halve Slices", width=bw, notifier=function() halveslices() end},
        vb:button{text="From Selection", width=bw, notifier=function() pakettiSlicesFromSelection() end},
      })
    end),

    -- Section 2: Zero-Crossing Slicing
    collapsible_section(vb, "pakettiSliceToolsShowZeroCrossing", "Zero-Crossing Slicing", function(col)
      col:add_child(vb:row{
        vb:button{text="2", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(2, true, 1.0) end},
        vb:button{text="4", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(4, true, 1.0) end},
        vb:button{text="8", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(8, true, 1.0) end},
        vb:button{text="16", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(16, true, 1.0) end},
      })
      col:add_child(vb:row{
        vb:button{text="32", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(32, true, 1.0) end},
        vb:button{text="64", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(64, true, 1.0) end},
        vb:button{text="128", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(128, true, 1.0) end},
      })
      col:add_child(vb:row{
        vb:button{text="Randomize Slices", width=bw, notifier=function() PakettiZeroCrossingsRandomizeSlices(15, true, 1.0) end},
        vb:button{text="Random Distributed", width=bw, notifier=function() PakettiZeroCrossingsRandomDistributedSlices(8, 32, true, 1.0) end},
      })
    end),

    -- Section 3: Advanced Slicing (dialog launchers)
    collapsible_section(vb, "pakettiSliceToolsShowAdvanced", "Advanced Slicing", function(col)
      col:add_child(vb:button{text="BPM-Based Slicer...", width=fw, notifier=function() showBPMBasedSliceDialog() end})
      col:add_child(vb:button{text="Curved Slice Creator...", width=fw, notifier=function() PakettiCurvedSliceCreator() end})
      col:add_child(vb:button{text="SliceSafely...", width=fw, notifier=function() SliceSafelyDialog() end})
      col:add_child(vb:button{text="SlicePro Config...", width=fw, notifier=function() SliceProApplyOrConfig() end})
      col:add_child(vb:button{text="Real-Time Slice Monitor", width=fw, notifier=function() pakettiRealtimeSliceToggle() end})
    end),

    -- Section 4: All Slices Loop Mode
    collapsible_section(vb, "pakettiSliceToolsShowLoopMode", "All Slices Loop Mode", function(col)
      col:add_child(vb:row{
        vb:button{text="Off", width=bw, notifier=function() pakettiSetAllSlicesToLoopOff() end},
        vb:button{text="Forward", width=bw, notifier=function() pakettiSetAllSlicesToForwardLoop() end},
      })
      col:add_child(vb:row{
        vb:button{text="Reverse", width=bw, notifier=function() pakettiSetAllSlicesToReverseLoop() end},
        vb:button{text="PingPong", width=bw, notifier=function() pakettiSetAllSlicesToPingPongLoop() end},
      })
      col:add_child(vb:row{
        vb:button{text="Full Loop", width=bw, notifier=function() pakettiSetAllSlicesToFullLoop() end},
        vb:button{text="End Half", width=bw, notifier=function() pakettiSetAllSlicesToEndHalfLoop() end},
      })
    end),

  }

  local col2 = vb:column{width=cw, spacing=4,
    -- Section 5: Slices to Pattern
    collapsible_section(vb, "pakettiSliceToolsShowToPattern", "Slices to Pattern", function(col)
      col:add_child(vb:button{text="Wipe&Slice&Write", width=fw, notifier=function() WipeSliceAndWrite() end})
      col:add_child(vb:row{
        vb:button{text="To Pattern (1st Row)", width=bw, notifier=function() pakettiSlicesToPattern(true) end},
        vb:button{text="To Pattern (Cur Row)", width=bw, notifier=function() pakettiSlicesToPattern(false) end},
      })
      col:add_child(vb:row{
        vb:button{text="Evenly (1st Row)", width=bw, notifier=function() pakettiSlicesToPatternEvenly(true) end},
        vb:button{text="Evenly (Cur Row)", width=bw, notifier=function() pakettiSlicesToPatternEvenly(false) end},
      })
      col:add_child(vb:button{text="Beatsync Only", width=fw, notifier=function() pakettiSlicesToPatternBeatsyncOnly() end})
      col:add_child(vb:button{text="Pattern Seq Dialog...", width=fw, notifier=function() showSliceToPatternSequencerInterface() end})
      col:add_child(vb:row{
        vb:button{text="Random Distribution", width=bw, notifier=function() PakettiRandomSliceDistribution() end},
        vb:button{text="Equal Distribution", width=bw, notifier=function() PakettiEqualSliceDistribution() end},
      })
      col:add_child(vb:button{text="Create Seq Patterns", width=fw, notifier=function() createPatternSequencerPatternsBasedOnSliceCount() end})
    end),

    -- Section 6: Slices to Phrase
    collapsible_section(vb, "pakettiSliceToolsShowToPhrase", "Slices to Phrase", function(col)
      col:add_child(vb:row{
        vb:button{text="With Trigger", width=bw, notifier=function() pakettiSlicesToPhrase(true) end},
        vb:button{text="Phrase Only", width=bw, notifier=function() pakettiSlicesToPhrase(false) end},
      })
      col:add_child(vb:button{text="Template from Slices", width=fw, notifier=function() PakettiPhraseTemplateFromSlices() end})
      col:add_child(vb:button{text="To Phrase Bank", width=fw, notifier=function() PakettiSlicesToPhraseBank({}) end})
      col:add_child(vb:button{text="Auto-Slice & Phrase", width=fw, notifier=function() PakettiAutoSliceAndPhraseCreate({}) end})
    end),

    -- Section 7: Slice Marker Management
    collapsible_section(vb, "pakettiSliceToolsShowMarkerMgmt", "Slice Marker Management", function(col)
      col:add_child(vb:row{
        vb:button{text="Delete in Selection", width=bw, notifier=function() pakettiDeleteSliceMarkersInSelection() end},
        vb:button{text="Analyze Markers", width=bw, notifier=function() analyze_slice_markers() end},
      })
      col:add_child(vb:row{
        vb:button{text="Pick Up Slices", width=bw, notifier=function() PakettiPickupSlices() end},
        vb:button{text="Apply (Relative)", width=bw, notifier=function() PakettiApplySlicesBasedOnSampleRate() end},
      })
    end),

  }

  local col3 = vb:column{width=cw, spacing=4,
    -- Section 8: DrumChain / Conversion
    collapsible_section(vb, "pakettiSliceToolsShowDrumChain", "DrumChain / Conversion", function(col)
      col:add_child(vb:row{
        vb:button{text="DrumChain (Current)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChain(false) end},
        vb:button{text="DrumChain (Normalized)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChain(true) end},
      })
      col:add_child(vb:row{
        vb:button{text="DrumChain (Randomize)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end},
        vb:button{text="DrumChain (Rand+Norm)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end},
      })
      col:add_child(vb:row{
        vb:button{text="DrumChain from XRNI...", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end},
        vb:button{text="DrumChain XRNI (Norm)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end},
      })
      col:add_child(vb:row{
        vb:button{text="Isolate to Instrument", width=bw, notifier=function() PakettiIsolateSlicesToInstrument() end},
        vb:button{text="Isolate to Instruments", width=bw, notifier=function() PakettiIsolateSlices() end},
      })
    end),

    -- Section 9: Beatsync
    collapsible_section(vb, "pakettiSliceToolsShowBeatsync", "Beatsync", function(col)
      col:add_child(vb:row{
        vb:button{text="Double All", width=bw, notifier=function() doubleBeatsyncLinesAll() end},
        vb:button{text="Halve All", width=bw, notifier=function() halveBeatsyncLinesAll() end},
      })
      col:add_child(vb:row{
        vb:button{text="Double Selected", width=bw, notifier=function() doubleBeatsyncLinesSelected() end},
        vb:button{text="Halve Selected", width=bw, notifier=function() halveBeatsyncLinesSelected() end},
      })
      col:add_child(vb:button{text="Beatsync from Selection", width=fw, notifier=function() BeatsyncFromSelection() end})
      col:add_child(vb:button{text="Beatsync to Pitch", width=fw, notifier=function() convert_beatsync_to_pitch() end})
    end),

    -- Section 10: Specialized Tools (launchers)
    collapsible_section(vb, "pakettiSliceToolsShowSpecialized", "Specialized Tools", function(col)
      col:add_child(vb:button{text="Slice Step Sequencer...", width=fw, notifier=function() PakettiSliceStepCreateDialog() end})
      col:add_child(vb:row{
        vb:button{text="Manual Slicer (Longest)", width=bw, notifier=function() paketti_manual_slicer() end},
        vb:button{text="Manual Slicer (Shortest)", width=bw, notifier=function() paketti_manual_slicer_shortest() end},
      })
      col:add_child(vb:button{text="Stem Slicer...", width=fw, notifier=function() pakettiStemSlicerDialog() end})
      col:add_child(vb:button{text="Video Slicer...", width=fw, notifier=function() PakettiVideoSlicerShowDialog() end})
      col:add_child(vb:button{text="Sample FX Chain Slicer", width=fw, notifier=function() PakettiSampleRangePrepareNewInstrument() end})
      col:add_child(vb:button{text="New Instr from Selection", width=fw, notifier=function() create_new_instrument_from_selection_with_slices() end})
    end),

    -- Section 11: Oldschool Gap Fill
    collapsible_section(vb, "pakettiSliceToolsShowGapFill", "Oldschool Gap Fill", function(col)
      col:add_child(vb:button{text="Detect Gaps", width=fw, notifier=function() pakettiOldschoolSlicePitchDetectGaps() end})
      col:add_child(vb:button{text="Fill All (Reversed)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGaps() end})
      col:add_child(vb:button{text="Fill All (Copied)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGapsCopied() end})
      col:add_child(vb:button{text="Fill All (PingPong)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGapsPingPong() end})
      col:add_child(vb:button{text="Oldschool Workflow", width=fw, notifier=function() pakettiOldschoolSlicePitchWorkflow(false, false) end})
    end),
  }

  local content = vb:row{
    margin=4,
    spacing=8,
    col1,
    col2,
    col3,
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )

  dialog = renoise.app():show_custom_dialog("Paketti Slice Tools", content, keyhandler)
end

-- Menu entries
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Slice Tools:Slice Tools Dialog...", invoke=function() PakettiSliceToolsDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Slice Tools:Slice Tools Dialog...", invoke=function() PakettiSliceToolsDialog() end}

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Slice Tools Dialog", invoke=function() PakettiSliceToolsDialog() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Slice Tools Dialog", invoke=function() PakettiSliceToolsDialog() end}

-- MIDI mapping
renoise.tool():add_midi_mapping{name="Paketti:Slice Tools Dialog", invoke=function(message) if message:is_trigger() then PakettiSliceToolsDialog() end end}
