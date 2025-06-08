--- Instrument Box Config
if preferences.pakettiMenuConfig.InstrumentBox then
  print ("Instrument Box Menus Are Enabled")
end

--- Sample Editor Config
if preferences.pakettiMenuConfig.SampleEditor then
  print ("Sample Editor Menus Are Enabled")
end

--- Sample Navigator Config
if preferences.pakettiMenuConfig.SampleNavigator then
  print ("Sample Navigator Menus Are Enabled")
end

--- Sample Keyzone Config
if preferences.pakettiMenuConfig.SampleKeyzone then
  print ("Sample Keyzone Menus Are Enabled")
end

--- Mixer Config
if preferences.pakettiMenuConfig.Mixer then
  print ("Mixer Menus Are Enabled")
end

--- Pattern Editor Config
if preferences.pakettiMenuConfig.PatternEditor then
  print ("Pattern Editor Menus Are Enabled")
end

--- Main Menu Tools Config
if preferences.pakettiMenuConfig.MainMenuTools then
  print ("Main Menu Tools Menus Are Enabled")
end

--- Main Menu View Config
if preferences.pakettiMenuConfig.MainMenuView then

renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumnsSelectedTrack() end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Uncollapse All Tracks",invoke=function() Uncollapser() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Collapse All Tracks",invoke=function() Collapser() end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Visible Columns..:Hide All Effect Columns",invoke=function() HideAllEffectColumns() end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Toggle All Columns",invoke=function() toggleColumns(true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Toggle All Columns (No Sample Effects)",invoke=function() toggleColumns(false) end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Toggle Visible Column (Volume) Globally",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Toggle Visible Column (Panning) Globally",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Toggle Visible Column (Delay) Globally",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Toggle Visible Column (Sample Effects) Globally",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Set Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Set Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Set Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Set Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="--Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti..:Visible Columns..:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}


  print ("Main Menu View Menus Are Enabled")
end

--- Main Menu File Config
if preferences.pakettiMenuConfig.MainMenuFile then
  print ("Main Menu File Menus Are Enabled")
  renoise.tool():add_menu_entry{name="Main Menu:File:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Save (Paketti Track Dater & Titler)...",invoke=pakettiTitlerDialog}
renoise.tool():add_menu_entry{name="Main Menu:File:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
renoise.tool():add_menu_entry{name="--Main Menu:File:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
renoise.tool():add_menu_entry{name="--Main Menu:File:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="--Main Menu:File:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
renoise.tool():add_menu_entry{name="Main Menu:File:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
renoise.tool():add_menu_entry{name="--Main Menu:File:Delete Unused Instruments...",invoke=deleteUnusedInstruments}
renoise.tool():add_menu_entry{name="Main Menu:File:Delete Unused Samples...",invoke=deleteUnusedSamples}

--- File -> Paketti
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Load Most Recently Saved Song",invoke=function() loadRecentlySavedSong() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Delete Unused Samples...",invoke=deleteUnusedSamples}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Paketti New Song Dialog...",invoke=function() pakettiImpulseTrackerNewSongDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Paketti Track Dater & Titler...",invoke=pakettiTitlerDialog}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Save Song with Timestamp",invoke=function() save_with_new_timestamp() end}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti..:Save All Samples to Folder...",invoke = saveAllSamplesToFolder}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti..:Largest Samples Dialog...",invoke = pakettiShowLargestSamplesDialog}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti..:Save Unused Samples (.WAV&.XRNI)...",invoke=saveUnusedSamples}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti..:Save Unused Instruments (.XRNI)...",invoke=saveUnusedInstruments}
renoise.tool():add_menu_entry{name="--Main Menu:File:Paketti..:Delete Unused Instruments...",invoke=deleteUnusedInstruments}

end

--- Pattern Matrix Config
if preferences.pakettiMenuConfig.PatternMatrix then
  -- Gadgets

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Paketti Action Selector Dialog...",invoke = pakettiActionSelectorDialog}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Value Interpolation Looper Dialog...",invoke = pakettiVolumeInterpolationLooper}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Paketti Sequencer Settings Dialog...",invoke = pakettiSequencerSettingsDialog}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Fuzzy Search Track Dialog...",invoke = pakettiFuzzySearchTrackDialog}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti Gadgets..:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}


renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Toggle Automatically Open Selected Track Device Editors On/Off",invoke = PakettiAutomaticallyOpenSelectedTrackDeviceExternalEditorsToggleAutoMode}

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Insert Stereo -> Mono device to End of ALL DSP Chains",invoke=function() insertMonoToAllTracksEnd() end}

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Selection in Pattern Matrix to Group",invoke=function() SelectionInPatternMatrixToGroup() end}

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Pattern Matrix Selection Expand",invoke=PatternMatrixExpand }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Pattern Matrix Selection Shrink",invoke=PatternMatrixShrink }

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Wipe All Automation in Track on Current Pattern",invoke=function() delete_automation(false, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Wipe All Automation in All Tracks on Current Pattern",invoke=function() delete_automation(true, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Wipe All Automation in Track on Whole Song",invoke=function() delete_automation(false, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Wipe All Automation in All Tracks on Whole Song",invoke=function() delete_automation(true, true) end}

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Multiply BPM & Halve LPB",invoke=function() multiply_bpm_halve_lpb() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Halve BPM & Multiply LPB",invoke=function() halve_bpm_multiply_lpb() end}


renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Automation Curves..:Center to Top (Exp) for Pattern Matrix Selection",invoke=automation_center_to_top_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Top to Center (Exp) for Pattern Matrix Selection",invoke=automation_top_to_center_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Center to Bottom (Exp) for Pattern Matrix Selection",invoke=automation_center_to_bottom_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Center (Exp) for Pattern Matrix Selection",invoke=automation_bottom_to_center_exp }

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Center to Top (Lin) for Pattern Matrix Selection",invoke=automation_center_to_top_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Top to Center (Lin) for Pattern Matrix Selection",invoke=automation_top_to_center_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Center to Bottom (Lin) for Pattern Matrix Selection",invoke=automation_center_to_bottom_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Center (Lin) for Pattern Matrix Selection",invoke=automation_bottom_to_center_lin }

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Switch to Automation",invoke=function() showAutomation() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Bypass EFX (Write to Pattern)",invoke=function() effectbypasspattern()  end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Enable EFX (Write to Pattern)",invoke=function() effectenablepattern() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Bypass All Devices on Channel",invoke=function() effectbypass() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Enable All Devices on Channel",invoke=function() effectenable() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Play at 75% Speed (Song BPM)",invoke=function() playat75() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Play at 100% Speed (Song BPM)",invoke=function() returnbackto100()  end}


renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone Sequence (With Automation)",invoke=function() clone_sequence_with_automation_only() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone Pattern (Without Automation)",invoke=function() clone_pattern_without_automation() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Clone and Expand Pattern to LPB*2",invoke=function() cloneAndExpandPatternToLPBDouble()end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone and Shrink Pattern to LPB/2",invoke=function() cloneAndShrinkPatternToLPBHalve()end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Duplicate Pattern Above & Clear Muted",invoke=function() duplicate_pattern_and_clear_muted_above() end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Duplicate Pattern Below & Clear Muted",invoke=function() duplicate_pattern_and_clear_muted() end}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Duplicate Track and Instrument",invoke=function() duplicateTrackAndInstrument() end}



renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 12 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 12 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 12 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,12) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 12 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Record..:Paketti Overdub 01 (Metronome/Line Input)",invoke=function() recordtocurrenttrack(true, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 01 (Metronome/No Line Input)",invoke=function() recordtocurrenttrack(true, false,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 01 (No Metronome/Line Input)",invoke=function() recordtocurrenttrack(false, true,1) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Record..:Paketti Overdub 01 (No Metronome/No Line Input)",invoke=function() recordtocurrenttrack(false, false,12) end}

renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Top to Top",
invoke=function() apply_constant_automation_top_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Bottom",
invoke=function() apply_constant_automation_bottom_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Up (Exp)",
invoke=function() apply_exponential_automation_curveUP() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Up (Linear)",
invoke=function() apply_selection_up_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Down (Exp)",
invoke=function() apply_exponential_automation_curveDOWN() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Down (Linear)",
invoke=function() apply_selection_down_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Center to Top (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Center to Bottom (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Top to Center (Exp)",
invoke=function() apply_exponential_automation_curve_top_to_center() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Center (Exp)",
invoke=function() apply_exponential_automation_curve_bottom_to_center() end})

renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Automation Curves..:Automation Ramp Up (Exp) for Pattern Matrix Selection",invoke=automation_ramp_up_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Automation Ramp Down (Exp) for Pattern Matrix Selection",invoke=automation_ramp_down_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Automation Ramp Up (Lin) for Pattern Matrix Selection",invoke=automation_ramp_up_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Curves..:Automation Ramp Down (Lin) for Pattern Matrix Selection",invoke=automation_ramp_down_lin }





print ("Pattern Matrix Menus Are Enabled")
end

--- Pattern Sequencer Config
if preferences.pakettiMenuConfig.PatternSequencer then
  print ("Pattern Sequencer Menus Are Enabled")
end

--- Phrase Editor Config
if preferences.pakettiMenuConfig.PhraseEditor then
  print ("Phrase Editor Menus Are Enabled")
end

--- Paketti Gadgets Config
if preferences.pakettiMenuConfig.PakettiGadgets then
  print ("Paketti Gadgets Menus Are Enabled")
end

--- Track DSP Device Config
if preferences.pakettiMenuConfig.TrackDSPDevice then
  print ("Track DSP Device Menus Are Enabled")
end

--- Automation Config
if preferences.pakettiMenuConfig.Automation then
  print ("Automation Menus Are Enabled")
end

--- Disk Browser Files Config
if preferences.pakettiMenuConfig.DiskBrowserFiles then
  print ("Disk Browser Files Menus Are Enabled")
end 

--- 