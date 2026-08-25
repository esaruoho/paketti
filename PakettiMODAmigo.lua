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

local function paketti_mod_apply_chain_loader_settings(ins, samp)
  if not ins or not samp then return end
  ins.macros_visible = true
  if ins.sample_modulation_sets and ins.sample_modulation_sets[1] then
    ins.sample_modulation_sets[1].name = "Pitchbend"
  end
  if preferences then
    if preferences.pakettiLoaderInterpolation then
      samp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    end
    if preferences.pakettiLoaderOverSampling then
      samp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    end
    if preferences.pakettiLoaderAutofade then
      samp.autofade = preferences.pakettiLoaderAutofade.value
    end
    if preferences.pakettiLoaderAutoseek then
      samp.autoseek = preferences.pakettiLoaderAutoseek.value
    end
    if preferences.pakettiLoaderOneshot then
      samp.oneshot = preferences.pakettiLoaderOneshot.value
    end
    if preferences.pakettiLoaderNNA then
      samp.new_note_action = preferences.pakettiLoaderNNA.value
    end
    if preferences.pakettiLoaderLoopExit then
      samp.loop_release = preferences.pakettiLoaderLoopExit.value
    end
  end
end

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

function PakettiMODCreateSlicedWavetable(mod_file, options)
  options = options or {}
  local label = options.label or "Load .MOD as Sliced Wavetable"
  local mod = paketti_mod_amigo_open(label, mod_file)
  if not mod then return end

  local monitoring = PakettiTemporarilyDisableNewSampleMonitoring()
  local kit_name = pakettiFSPath.sanitize_filename(mod.title, "MOD Wavetable")
  local send_to_amigo = options.send_to_amigo or false
  local keep_chain = options.keep_chain ~= false
  local song = renoise.song()

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

  local pcm_chunks = {}
  local starts = {}
  local position = 1
  for _, info in ipairs(mod.samples) do
    if info.data and #info.data > 0 then
      starts[#starts + 1] = position
      pcm_chunks[#pcm_chunks + 1] = info.data
      position = position + #info.data
    end
  end

  local pcm = table.concat(pcm_chunks)
  if pcm == "" then
    renoise.app():show_status(label .. ": nothing loaded.")
    PakettiRestoreNewSampleMonitoring(monitoring)
    return
  end

  local chain_index = song.selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, chain_index) then
    renoise.app():show_status(label .. ": could not insert sliced wavetable instrument.")
    PakettiRestoreNewSampleMonitoring(monitoring)
    return
  end

  song.selected_instrument_index = chain_index
  pakettiPreferencesDefaultInstrumentLoader()

  local chain_name = options.chain_name or (kit_name .. " Sliced Wavetable")
  local instrument = song.instruments[chain_index]
  instrument.name = chain_name
  instrument:insert_sample_at(1)
  song.selected_sample_index = 1

  local sample = instrument.samples[1]
  sample.name = chain_name
  sample.sample_buffer:create_sample_data(44100, 16, 1, #pcm)
  sample.sample_buffer:prepare_sample_data_changes()

  local flipped = PakettiMODParser.sign_flip(pcm)
  for frame = 1, #flipped do
    local value = ((flipped:byte(frame) or 0) / 255) * 2.0 - 1.0
    sample.sample_buffer:set_sample_data(1, frame, value)
  end
  sample.sample_buffer:finalize_sample_data_changes()

  for i = 2, #starts do
    if starts[i] > 1 and starts[i] < #pcm then
      sample:insert_slice_marker(starts[i])
    end
  end

  paketti_mod_apply_chain_loader_settings(instrument, sample)
  sample.loop_mode = renoise.Sample.LOOP_MODE_OFF

  local count = #starts
  local dropped = 0
  local amigo_index

  if send_to_amigo then
    local ok, err, amigo_count, past, index =
      PakettiAmigoSendInstrumentToAmigo(chain_index)
    if not ok then
      renoise.app():show_status(label .. ": " .. tostring(err) ..
        " - the sliced Renoise wavetable was kept.")
      PakettiRestoreNewSampleMonitoring(monitoring)
      return
    end
    count = amigo_count
    dropped = past or 0
    amigo_index = index
  end

  if send_to_amigo and not keep_chain then
    song:delete_instrument_at(chain_index)
  end

  if send_to_amigo then
    if keep_chain then
      song.selected_instrument_index = (options.select == "amigo") and amigo_index or chain_index
    else
      song.selected_instrument_index = chain_index
    end
  else
    song.selected_instrument_index = chain_index
  end

  local message
  if send_to_amigo then
    message = string.format("%s: %d samples from %s chained, %d Amigo slices",
      label, #starts, mod.format, count)
    if keep_chain then message = message .. " - sliced Renoise wavetable kept" end
  else
    message = string.format("%s: %d samples from %s chained into a sliced Renoise wavetable",
      label, #starts, mod.format)
  end
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
end

function PakettiMODWavetableToAmigo(mod_file, keep_chain)
  PakettiMODCreateSlicedWavetable(mod_file, {
    label = "Load .MOD as Wavetable to Amigo",
    send_to_amigo = true,
    keep_chain = keep_chain,
    select = keep_chain and "chain" or "amigo"
  })
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
