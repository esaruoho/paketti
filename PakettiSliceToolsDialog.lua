-- PakettiSliceToolsDialog.lua
-- Consolidated Slice Tools dialog — a single hub for all slice-related operations.
-- Each button calls an existing global function; no code is duplicated.

local dialog = nil

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

  local content = vb:column{
    margin=4,
    spacing=4,

    -- Section 1: Equal Slicing (Wipe & Slice)
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Equal Slicing (Wipe & Slice)", font="bold", style="strong"},
      vb:row{
        vb:button{text="2", width=sw, notifier=function() slicerough(2) end},
        vb:button{text="4", width=sw, notifier=function() slicerough(4) end},
        vb:button{text="8", width=sw, notifier=function() slicerough(8) end},
        vb:button{text="16", width=sw, notifier=function() slicerough(16) end},
      },
      vb:row{
        vb:button{text="32", width=sw, notifier=function() slicerough(32) end},
        vb:button{text="64", width=sw, notifier=function() slicerough(64) end},
        vb:button{text="128", width=sw, notifier=function() slicerough(128) end},
        vb:button{text="256", width=sw, notifier=function() slicerough(256) end},
      },
      vb:row{
        vb:button{text="Wipe Slices", width=bw, notifier=function() wipeslices() end},
        vb:button{text="Double Slices", width=bw, notifier=function() doubleslices() end},
      },
      vb:row{
        vb:button{text="Halve Slices", width=bw, notifier=function() halveslices() end},
        vb:button{text="From Selection", width=bw, notifier=function() pakettiSlicesFromSelection() end},
      },
    },

    -- Section 2: Zero-Crossing Slicing
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Zero-Crossing Slicing", font="bold", style="strong"},
      vb:row{
        vb:button{text="2", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(2, true, 1.0) end},
        vb:button{text="4", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(4, true, 1.0) end},
        vb:button{text="8", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(8, true, 1.0) end},
        vb:button{text="16", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(16, true, 1.0) end},
      },
      vb:row{
        vb:button{text="32", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(32, true, 1.0) end},
        vb:button{text="64", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(64, true, 1.0) end},
        vb:button{text="128", width=sw, notifier=function() PakettiZeroCrossingsWipeSlice(128, true, 1.0) end},
      },
      vb:row{
        vb:button{text="Randomize Slices", width=bw, notifier=function() PakettiZeroCrossingsRandomizeSlices(15, true, 1.0) end},
        vb:button{text="Random Distributed", width=bw, notifier=function() PakettiZeroCrossingsRandomDistributedSlices(8, 32, true, 1.0) end},
      },
    },

    -- Section 3: Advanced Slicing (dialog launchers)
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Advanced Slicing", font="bold", style="strong"},
      vb:button{text="BPM-Based Slicer...", width=fw, notifier=function() showBPMBasedSliceDialog() end},
      vb:button{text="Curved Slice Creator...", width=fw, notifier=function() PakettiCurvedSliceCreator() end},
      vb:button{text="SliceSafely...", width=fw, notifier=function() SliceSafelyDialog() end},
      vb:button{text="SlicePro Config...", width=fw, notifier=function() SliceProApplyOrConfig() end},
      vb:button{text="Real-Time Slice Monitor", width=fw, notifier=function() pakettiRealtimeSliceToggle() end},
    },

    -- Section 4: All Slices Loop Mode
    vb:column{
      style="group",
      margin=4,
      vb:text{text="All Slices Loop Mode", font="bold", style="strong"},
      vb:row{
        vb:button{text="Off", width=bw, notifier=function() pakettiSetAllSlicesToLoopOff() end},
        vb:button{text="Forward", width=bw, notifier=function() pakettiSetAllSlicesToForwardLoop() end},
      },
      vb:row{
        vb:button{text="Reverse", width=bw, notifier=function() pakettiSetAllSlicesToReverseLoop() end},
        vb:button{text="PingPong", width=bw, notifier=function() pakettiSetAllSlicesToPingPongLoop() end},
      },
      vb:row{
        vb:button{text="Full Loop", width=bw, notifier=function() pakettiSetAllSlicesToFullLoop() end},
        vb:button{text="End Half", width=bw, notifier=function() pakettiSetAllSlicesToEndHalfLoop() end},
      },
    },

    -- Section 5: Slices to Pattern
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Slices to Pattern", font="bold", style="strong"},
      vb:button{text="Wipe&Slice&Write", width=fw, notifier=function() WipeSliceAndWrite() end},
      vb:row{
        vb:button{text="To Pattern (1st Row)", width=bw, notifier=function() pakettiSlicesToPattern(true) end},
        vb:button{text="To Pattern (Cur Row)", width=bw, notifier=function() pakettiSlicesToPattern(false) end},
      },
      vb:row{
        vb:button{text="Evenly (1st Row)", width=bw, notifier=function() pakettiSlicesToPatternEvenly(true) end},
        vb:button{text="Evenly (Cur Row)", width=bw, notifier=function() pakettiSlicesToPatternEvenly(false) end},
      },
      vb:button{text="Beatsync Only", width=fw, notifier=function() pakettiSlicesToPatternBeatsyncOnly() end},
      vb:button{text="Pattern Seq Dialog...", width=fw, notifier=function() showSliceToPatternSequencerInterface() end},
      vb:row{
        vb:button{text="Random Distribution", width=bw, notifier=function() PakettiRandomSliceDistribution() end},
        vb:button{text="Equal Distribution", width=bw, notifier=function() PakettiEqualSliceDistribution() end},
      },
      vb:button{text="Create Seq Patterns", width=fw, notifier=function() createPatternSequencerPatternsBasedOnSliceCount() end},
    },

    -- Section 6: Slices to Phrase
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Slices to Phrase", font="bold", style="strong"},
      vb:row{
        vb:button{text="With Trigger", width=bw, notifier=function() pakettiSlicesToPhrase(true) end},
        vb:button{text="Phrase Only", width=bw, notifier=function() pakettiSlicesToPhrase(false) end},
      },
      vb:button{text="Template from Slices", width=fw, notifier=function() PakettiPhraseTemplateFromSlices() end},
      vb:button{text="To Phrase Bank", width=fw, notifier=function() PakettiSlicesToPhraseBank({}) end},
      vb:button{text="Auto-Slice & Phrase", width=fw, notifier=function() PakettiAutoSliceAndPhraseCreate({}) end},
    },

    -- Section 7: Slice Marker Management
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Slice Marker Management", font="bold", style="strong"},
      vb:row{
        vb:button{text="Delete in Selection", width=bw, notifier=function() pakettiDeleteSliceMarkersInSelection() end},
        vb:button{text="Analyze Markers", width=bw, notifier=function() analyze_slice_markers() end},
      },
      vb:row{
        vb:button{text="Pick Up Slices", width=bw, notifier=function() PakettiPickupSlices() end},
        vb:button{text="Apply (Relative)", width=bw, notifier=function() PakettiApplySlicesBasedOnSampleRate() end},
      },
    },

    -- Section 8: DrumChain / Conversion
    vb:column{
      style="group",
      margin=4,
      vb:text{text="DrumChain / Conversion", font="bold", style="strong"},
      vb:row{
        vb:button{text="DrumChain (Current)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChain(false) end},
        vb:button{text="DrumChain (Normalized)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChain(true) end},
      },
      vb:row{
        vb:button{text="DrumChain (Randomize)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end},
        vb:button{text="DrumChain (Rand+Norm)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end},
      },
      vb:row{
        vb:button{text="DrumChain from XRNI...", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end},
        vb:button{text="DrumChain XRNI (Norm)", width=bw, notifier=function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end},
      },
      vb:row{
        vb:button{text="Isolate to Instrument", width=bw, notifier=function() PakettiIsolateSlicesToInstrument() end},
        vb:button{text="Isolate to Instruments", width=bw, notifier=function() PakettiIsolateSlices() end},
      },
    },

    -- Section 9: Beatsync
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Beatsync", font="bold", style="strong"},
      vb:row{
        vb:button{text="Double All", width=bw, notifier=function() doubleBeatsyncLinesAll() end},
        vb:button{text="Halve All", width=bw, notifier=function() halveBeatsyncLinesAll() end},
      },
      vb:row{
        vb:button{text="Double Selected", width=bw, notifier=function() doubleBeatsyncLinesSelected() end},
        vb:button{text="Halve Selected", width=bw, notifier=function() halveBeatsyncLinesSelected() end},
      },
      vb:button{text="Beatsync from Selection", width=fw, notifier=function() BeatsyncFromSelection() end},
      vb:button{text="Beatsync to Pitch", width=fw, notifier=function() convert_beatsync_to_pitch() end},
    },

    -- Section 10: Specialized Tools (launchers)
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Specialized Tools", font="bold", style="strong"},
      vb:button{text="Slice Step Sequencer...", width=fw, notifier=function() PakettiSliceStepCreateDialog() end},
      vb:row{
        vb:button{text="Manual Slicer (Longest)", width=bw, notifier=function() paketti_manual_slicer() end},
        vb:button{text="Manual Slicer (Shortest)", width=bw, notifier=function() paketti_manual_slicer_shortest() end},
      },
      vb:button{text="Stem Slicer...", width=fw, notifier=function() pakettiStemSlicerDialog() end},
      vb:button{text="Video Slicer...", width=fw, notifier=function() PakettiVideoSlicerShowDialog() end},
      vb:button{text="Sample FX Chain Slicer", width=fw, notifier=function() PakettiSampleRangePrepareNewInstrument() end},
      vb:button{text="New Instr from Selection", width=fw, notifier=function() create_new_instrument_from_selection_with_slices() end},
    },

    -- Section 11: Oldschool Gap Fill
    vb:column{
      style="group",
      margin=4,
      vb:text{text="Oldschool Gap Fill", font="bold", style="strong"},
      vb:button{text="Detect Gaps", width=fw, notifier=function() pakettiOldschoolSlicePitchDetectGaps() end},
      vb:button{text="Fill All (Reversed)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGaps() end},
      vb:button{text="Fill All (Copied)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGapsCopied() end},
      vb:button{text="Fill All (PingPong)", width=fw, notifier=function() pakettiOldschoolSlicePitchFillAllGapsPingPong() end},
      vb:button{text="Oldschool Workflow", width=fw, notifier=function() pakettiOldschoolSlicePitchWorkflow(false, false) end},
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )

  dialog = renoise.app():show_custom_dialog("Paketti Slice Tools", content, keyhandler)
end

-- Menu entries
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Slice Tools:Slice Tools Dialog...", invoke=function() PakettiSliceToolsDialog() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Slice Tools:Slice Tools Dialog...", invoke=function() PakettiSliceToolsDialog() end}

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Slice Tools Dialog", invoke=function() PakettiSliceToolsDialog() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Slice Tools Dialog", invoke=function() PakettiSliceToolsDialog() end}

-- MIDI mapping
renoise.tool():add_midi_mapping{name="Paketti:Slice Tools Dialog", invoke=function(message) if message:is_trigger() then PakettiSliceToolsDialog() end end}
