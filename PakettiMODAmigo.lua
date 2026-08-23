--[[============================================================================
PakettiMODAmigo.lua — ProTracker .MOD straight into the Amigo Sampler

Two flavours, both built on PakettiMODParser.lua and the Amigo plumbing in
PakettiAmigo.lua:

  PakettiMODSamplesToAmigo()    one Amigo instrument per .MOD sample.
                                A 31-sample module gives 31 Amigos.

  PakettiMODWavetableToAmigo()  every .MOD sample concatenated head to tail
                                into ONE sample with a slice marker at each
                                join, loaded into ONE Amigo. A 31-sample
                                module gives 1 Amigo holding 31 slices.

--------------------------------------------------------------------------------
WHY THESE REUSE PakettiAmigoBuildChain
--------------------------------------------------------------------------------
The wavetable flavour needs variable-length samples welded together at one
common sample rate, with markers at the joins. PakettiAmigoBuildChain already
does exactly that, inside a ProcessSlicer, honouring PakettiAmigoMaxSlices.
PakettiWavetablerCombineSamplesIntoWavetable is NOT the right tool here: it
takes its frame count from the first sample and assumes every sample is the
same length, which holds for AKWF single cycles and never for .MOD samples.

--------------------------------------------------------------------------------
AMIGO'S 64-SLICE CEILING
--------------------------------------------------------------------------------
Amigo holds slice0..slice63. A .MOD carries at most 31 samples, so neither
flavour can ever reach the ceiling - but the cap is passed through rather than
assumed, so the count is still reported honestly if it ever does bite.

Temp WAVs are stamped 44100 Hz to match load_samples_from_mod(); the samples
are pitched by keyzone anyway. The batch .WAV exporter in PakettiMODLoader.lua
is the one that cares about the real Amiga rate.
============================================================================]]--

--------------------------------------------------------------------------------
-- shared helpers
--------------------------------------------------------------------------------

-- Prompts for a .mod when no path is supplied, then reads and parses it.
-- Returns the parsed module table, or nil after showing why not.
local function paketti_mod_amigo_open(label, mod_file)
  if not mod_file or mod_file == "" then
    mod_file = renoise.app():prompt_for_filename_to_read({ "*.mod", "mod." }, "Load .MOD file")
  end
  if not mod_file or mod_file == "" then
    renoise.app():show_status(label .. ": no .MOD selected.")
    return nil
  end

  local data, read_err = PakettiMODParser.read_file(mod_file)
  if not data then
    renoise.app():show_status(label .. ": cannot open .MOD - " .. tostring(read_err))
    return nil
  end

  local mod, parse_err = PakettiMODParser.parse(data)
  if not mod then
    renoise.app():show_status(label .. ": not a valid .MOD - " .. tostring(parse_err))
    return nil
  end
  if #mod.samples == 0 then
    renoise.app():show_status(label .. ": this .MOD holds no sample data.")
    return nil
  end
  return mod
end

--------------------------------------------------------------------------------
-- one Amigo per .MOD sample
--
-- Each sample gets a throwaway Renoise instrument, because
-- PakettiAmigoSendInstrumentToAmigo is what writes the WAV into
-- ~/Paketti Amigo Samples and points Amigo's `pathname` at it. The throwaway
-- is deleted straight afterwards, leaving exactly one Amigo per sample - the
-- WAV on disk is what Amigo plays, so the Renoise side costs nothing to drop.
--------------------------------------------------------------------------------

function PakettiMODSamplesToAmigo(mod_file)
  local label = "Load .MOD Samples to Amigo"
  local mod = paketti_mod_amigo_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local slicer, dialog, vb

  slicer = ProcessSlicer(function()
    local song = renoise.song()
    local made, failed = 0, {}

    for position, info in ipairs(mod.samples) do
      if vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = string.format("Amigo %d/%d: %s",
          position, #mod.samples, info.name)
      end

      local index = song.selected_instrument_index + 1
      if not safeInsertInstrumentAt(song, index) then
        failed[#failed + 1] = string.format("%02d (could not insert instrument)", info.index)
      else
        song.selected_instrument_index = index
        pakettiPreferencesDefaultInstrumentLoader()
        local ins = song.instruments[index]
        ins.macros_visible = true
        ins.sample_modulation_sets[1].name = "Pitchbend"

        local loaded, name_or_err = PakettiMODApplySampleToSlot(ins, 1, info)
        if not loaded then
          song:delete_instrument_at(index)
          failed[#failed + 1] = string.format("%02d (%s)", info.index, tostring(name_or_err))
        else
          ins.name = name_or_err
          song.selected_sample_index = 1
          local ok, send_err, count, dropped, amigo_index =
            PakettiAmigoSendInstrumentToAmigo(index)
          -- the throwaway has done its job either way: Amigo plays the wav that
          -- PakettiAmigoSendInstrumentToAmigo wrote into ~/Paketti Amigo Samples
          song:delete_instrument_at(index)
          if ok then
            song.selected_instrument_index = amigo_index - 1
            made = made + 1
          else
            failed[#failed + 1] = string.format("%02d %s (%s)",
              info.index, name_or_err, tostring(send_err))
          end
        end
      end
      coroutine.yield()
    end

    local message = string.format("%s: %d of %d samples from %s are now Amigos",
      label, made, #mod.samples, mod.format)
    if #failed > 0 then message = message .. " - skipped " .. table.concat(failed, ", ") end
    renoise.app():show_status(message)
    print("PakettiMODAmigo: " .. message)

    PakettiRestoreNewSampleMonitoring(monitoring)
    if dialog and dialog.visible then dialog:close() end
  end)

  dialog, vb = slicer:create_dialog("Loading .MOD samples into Amigo...")
  slicer:start()
end

--------------------------------------------------------------------------------
-- every .MOD sample chained into ONE Amigo, one slice each
--------------------------------------------------------------------------------

-- Loads every .MOD sample into a single instrument, one sample slot each.
-- Returns the instrument index, or nil.
local function paketti_mod_amigo_scratch_kit(mod, name)
  local song = renoise.song()
  local index = song.selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, index) then return nil end
  song.selected_instrument_index = index
  pakettiPreferencesDefaultInstrumentLoader()

  local ins = song.instruments[index]
  ins.name = name
  ins.macros_visible = true
  ins.sample_modulation_sets[1].name = "Pitchbend"

  local slot = 0
  for _, info in ipairs(mod.samples) do
    slot = slot + 1
    local loaded = PakettiMODApplySampleToSlot(ins, slot, info)
    if not loaded then
      ins:delete_sample_at(slot)
      slot = slot - 1
    end
  end

  if slot == 0 then
    song:delete_instrument_at(index)
    return nil
  end
  -- the Paketti template can leave placeholder slots past what we filled
  while #ins.samples > slot do ins:delete_sample_at(#ins.samples) end
  return index
end

function PakettiMODWavetableToAmigo(mod_file)
  local label = "Load .MOD as Wavetable to Amigo"
  local mod = paketti_mod_amigo_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local kit_name = pakettiFSPath.sanitize_filename(mod.title, "MOD Wavetable")

  -- Amigo's loop / loopstart / pingpong / reverse / sampleend are ONE set for
  -- the whole plugin instance. slice0..slice63 are positions and nothing else -
  -- there is no per-slice loop to write, and a single global loop across a
  -- chain would just loop over slice boundaries. So a looped module sample
  -- loses its loop here. Count them and say so, rather than dropping it
  -- quietly, so the per-sample command can be used instead.
  local looping = 0
  for _, info in ipairs(mod.samples) do
    if info.loop_length and info.loop_length > 5 then looping = looping + 1 end
  end

  local scratch = paketti_mod_amigo_scratch_kit(mod, kit_name)
  if not scratch then
    renoise.app():show_status(label .. ": nothing loaded.")
    PakettiRestoreNewSampleMonitoring(monitoring)
    return
  end

  PakettiAmigoBuildChain(scratch, PakettiAmigoMaxSlices, function(chain_index, chained, dropped)
    local song = renoise.song()
    song.instruments[chain_index].name = kit_name
    song.instruments[chain_index].samples[1].name = kit_name

    local ok, send_err, count, past, amigo_index =
      PakettiAmigoSendInstrumentToAmigo(chain_index)
    if not ok then
      song:delete_instrument_at(scratch)
      renoise.app():show_status(label .. ": " .. tostring(send_err) ..
        " - the sliced instrument was kept.")
      PakettiRestoreNewSampleMonitoring(monitoring)
      return
    end

    -- leave one instrument standing: the Amigo. The chain sits directly before
    -- it and the scratch kit before that, so delete high index first.
    song:delete_instrument_at(chain_index)
    song:delete_instrument_at(scratch)
    song.selected_instrument_index = amigo_index - 2

    local message = string.format("%s: %d samples from %s chained, %d Amigo slices",
      label, chained, mod.format, count)
    if dropped > 0 then
      message = message .. string.format(" (%d past Amigo's %d were left out)",
        dropped, PakettiAmigoMaxSlices)
    end
    if looping > 0 then
      message = message .. string.format(
        " - %d had loops, which Amigo cannot hold per slice; use Load .MOD Samples to Amigo for those",
        looping)
    end
    renoise.app():show_status(message)
    print("PakettiMODAmigo: " .. message)
    PakettiRestoreNewSampleMonitoring(monitoring)
  end)
end

--------------------------------------------------------------------------------
-- registrations
--------------------------------------------------------------------------------

local paketti_mod_amigo_entries = {
  { label = "Load .MOD Samples to Amigo",
    invoke = function() PakettiMODSamplesToAmigo(nil) end },
  { label = "Load .MOD as Wavetable to Amigo",
    invoke = function() PakettiMODWavetableToAmigo(nil) end },
}

local paketti_mod_amigo_bases = {
  "Main Menu:File:Paketti Import:",
  "Main Menu:Tools:Paketti:Instruments:File Formats:",
  "Main Menu:Tools:Paketti:Instruments:Amigo:",
  "Instrument Box:Paketti:Load:",
  "Sample Editor:Paketti:Load:",
  "Sample Navigator:Paketti:",
  "Disk Browser Files:Paketti:Import/Export:",
}

for _, entry in ipairs(paketti_mod_amigo_entries) do
  for _, base in ipairs(paketti_mod_amigo_bases) do
    PakettiAddMenuEntry{name = base .. entry.label, invoke = entry.invoke}
  end
  renoise.tool():add_keybinding{name = "Global:Paketti:" .. entry.label,
    invoke = entry.invoke}
  renoise.tool():add_midi_mapping{name = "Paketti:" .. entry.label,
    invoke = function(message) if message:is_trigger() then entry.invoke() end end}
end
