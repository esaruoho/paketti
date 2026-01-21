-- PakettiMetaSynth.lua
-- Instrument Architecture Generator for Paketti
-- Builds complex synthesis architectures using Renoise's sampler, FX chains, and modulation system

-- ============================================================================
-- SECTION 1: DATA MODEL AND VALIDATION
-- ============================================================================

-- Global architecture storage
PakettiMetaSynthCurrentArchitecture = nil

-- AKWF file list cache for performance
PakettiMetaSynthAKWFCache = nil

-- AKWF samples organized by family (populated on first use)
PakettiMetaSynthAKWFFamilyCache = nil

-- Last used folder path for sample loading
PakettiMetaSynthLastFolderPath = nil

-- ============================================================================
-- CROSSFADE CURVE TYPES
-- Available curve types for all frame/morphing levels (uniform across system)
-- ============================================================================
METASYNTH_CROSSFADE_CURVES = {"linear", "equal_power", "s_curve", "stepped", "spectral", "vector"}
METASYNTH_CROSSFADE_CURVE_NAMES = {"Linear", "Equal Power", "S-Curve", "Stepped", "Spectral", "Vector"}

-- Helper function to get random crossfade curve
function PakettiMetaSynthGetRandomCrossfadeCurve()
  return METASYNTH_CROSSFADE_CURVES[math.random(1, #METASYNTH_CROSSFADE_CURVES)]
end

-- ============================================================================
-- FX ARCHETYPES
-- Named FX character presets that group devices by musical purpose
-- Used for rule-based FX selection with user-controllable intent
-- ============================================================================
METASYNTH_FX_ARCHETYPES = {
  clean = {
    name = "Clean",
    description = "Transparent, pristine sound",
    devices = {
      { name = "EQ 10", enabled = true, weight = 1.0 },
      { name = "Compressor", enabled = true, weight = 1.0 },
      { name = "DC Offset", enabled = true, weight = 0.5 }
    },
    weight = 1.0
  },
  character = {
    name = "Character",
    description = "Adds color and personality",
    devices = {
      { name = "Analog Filter", enabled = true, weight = 1.0 },
      { name = "Distortion", enabled = true, weight = 0.8 },
      { name = "Lofimat 2", enabled = true, weight = 0.6 },
      { name = "Cabinet Simulator", enabled = true, weight = 0.7 }
    },
    weight = 1.0
  },
  movement = {
    name = "Movement",
    description = "Motion and modulation",
    devices = {
      { name = "Chorus", enabled = true, weight = 1.0 },
      { name = "Flanger", enabled = true, weight = 0.8 },
      { name = "Phaser", enabled = true, weight = 0.8 },
      { name = "Tremolo", enabled = true, weight = 0.7 },
      { name = "Vibrato", enabled = true, weight = 0.6 }
    },
    weight = 1.0
  },
  spatial = {
    name = "Spatial",
    description = "Depth and space",
    devices = {
      { name = "Reverb", enabled = true, weight = 1.0 },
      { name = "mpReverb 2", enabled = true, weight = 0.8 },
      { name = "Convolver", enabled = true, weight = 0.5 },
      { name = "Stereo Expander", enabled = true, weight = 0.7 }
    },
    weight = 1.0
  },
  aggressive = {
    name = "Aggressive",
    description = "Hard-hitting and intense",
    devices = {
      { name = "Distortion", enabled = true, weight = 1.0 },
      { name = "Cabinet Simulator", enabled = true, weight = 0.8 },
      { name = "Exciter", enabled = true, weight = 0.7 },
      { name = "Maximizer", enabled = true, weight = 0.9 }
    },
    weight = 1.0
  }
}

-- List of archetype keys for UI dropdowns
METASYNTH_FX_ARCHETYPE_KEYS = {"clean", "character", "movement", "spatial", "aggressive"}
METASYNTH_FX_ARCHETYPE_NAMES = {"Clean", "Character", "Movement", "Spatial", "Aggressive"}

-- Helper function: Get FX devices from enabled archetypes (supports new per-device format)
-- enabled_archetypes: table of archetype keys, e.g. {"clean", "character"}
-- count: number of devices to select
-- architecture: optional architecture for checking constraints and fx_device_overrides
-- Returns: table of device names randomly selected from the enabled archetypes
function PakettiMetaSynthGetFXFromArchetypes(enabled_archetypes, count, architecture)
  if not enabled_archetypes or #enabled_archetypes == 0 then
    return {}
  end
  
  -- Get constraints and overrides from architecture
  local constraints = architecture and architecture.constraints or {}
  local overrides = architecture and architecture.fx_device_overrides or {}
  
  -- Build a map of constraint device toggles
  local constraint_map = {
    ["Reverb"] = constraints.allow_reverb,
    ["mpReverb 2"] = constraints.allow_reverb,
    ["Chorus"] = constraints.allow_chorus,
    ["Phaser"] = constraints.allow_phaser,
    ["Flanger"] = constraints.allow_flanger,
    ["Distortion"] = constraints.allow_distortion,
    ["Analog Filter"] = constraints.allow_filter,
    ["Digital Filter"] = constraints.allow_filter,
    ["EQ 10"] = constraints.allow_eq,
    ["Compressor"] = constraints.allow_compressor,
    ["Maximizer"] = constraints.allow_maximizer,
    ["Convolver"] = constraints.allow_convolver,
    ["Cabinet Simulator"] = constraints.allow_cabinet,
    ["Lofimat 2"] = constraints.allow_lofimat,
    ["Exciter"] = constraints.allow_exciter,
    ["Stereo Expander"] = constraints.allow_stereo_expander,
    ["Tremolo"] = constraints.allow_tremolo,
    ["Vibrato"] = constraints.allow_vibrato,
  }
  
  -- Check if device is forbidden by constraints
  local forbidden = constraints.forbidden_devices or {}
  local function is_forbidden(device_name)
    for _, forbidden_name in ipairs(forbidden) do
      if device_name == forbidden_name then
        return true
      end
    end
    return false
  end
  
  -- Collect all devices from enabled archetypes with weights
  local available_devices = {}  -- { { name = "...", weight = 1.0 }, ... }
  for _, archetype_key in ipairs(enabled_archetypes) do
    local archetype = METASYNTH_FX_ARCHETYPES[archetype_key]
    if archetype and archetype.devices then
      for _, device_entry in ipairs(archetype.devices) do
        -- Handle both old format (string) and new format (table)
        local device_name, device_enabled, device_weight
        if type(device_entry) == "string" then
          -- Old format: just a device name string
          device_name = device_entry
          device_enabled = true
          device_weight = 1.0
        else
          -- New format: { name = "...", enabled = true, weight = 1.0 }
          device_name = device_entry.name
          device_enabled = device_entry.enabled ~= false
          device_weight = device_entry.weight or 1.0
        end
        
        -- Check if device is enabled at archetype level
        if not device_enabled then
          -- Skip disabled devices
        -- Check override
        elseif overrides[device_name] then
          local override = overrides[device_name]
          if override.enabled ~= false then
            -- Apply override weight
            local weight = override.weight or device_weight
            -- Add device with weight if not already in list
            local found = false
            for _, existing in ipairs(available_devices) do
              if existing.name == device_name then
                found = true
                -- Update weight to higher value
                if weight > existing.weight then
                  existing.weight = weight
                end
                break
              end
            end
            if not found then
              table.insert(available_devices, { name = device_name, weight = weight })
            end
          end
        -- Check constraints
        elseif constraint_map[device_name] == false then
          -- Device disabled by constraint
        elseif is_forbidden(device_name) then
          -- Device in forbidden list
        else
          -- Add device if not already in list
          local found = false
          for _, existing in ipairs(available_devices) do
            if existing.name == device_name then
              found = true
              break
            end
          end
          if not found then
            table.insert(available_devices, { name = device_name, weight = device_weight })
          end
        end
      end
    end
  end
  
  if #available_devices == 0 then
    return {}
  end
  
  -- Weighted random selection of 'count' devices
  local selected = {}
  count = math.min(count, #available_devices)
  
  for i = 1, count do
    -- Calculate total weight
    local total_weight = 0
    for _, device in ipairs(available_devices) do
      total_weight = total_weight + device.weight
    end
    
    if total_weight <= 0 then
      break
    end
    
    -- Pick random device by weight
    local rand = math.random() * total_weight
    local cumulative = 0
    local selected_idx = 1
    for idx, device in ipairs(available_devices) do
      cumulative = cumulative + device.weight
      if rand <= cumulative then
        selected_idx = idx
        break
      end
    end
    
    -- Add selected device and remove from pool
    table.insert(selected, available_devices[selected_idx].name)
    table.remove(available_devices, selected_idx)
  end
  
  return selected
end

-- Helper function: Get archetype names from keys for UI
function PakettiMetaSynthGetArchetypeNamesFromKeys(keys)
  local names = {}
  for _, key in ipairs(keys) do
    local archetype = METASYNTH_FX_ARCHETYPES[key]
    if archetype then
      table.insert(names, archetype.name)
    end
  end
  return names
end

-- ============================================================================
-- MODULATION CHARACTER PRESETS
-- Quick-select presets for modulation behavior (envelope shape + LFO)
-- Provides musical intent without needing full profile knowledge
-- ============================================================================
METASYNTH_MODULATION_CHARACTERS = {
  { 
    key = "pluck_short", 
    name = "Short Pluck", 
    description = "Quick attack, fast decay",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.1 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.15, release = 0.1 },
      velocity_volume = 0.8
    }
  },
  { 
    key = "soft_pad", 
    name = "Soft Pad", 
    description = "Slow attack, long sustain",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.5, hold = 0.0, decay = 0.3, sustain = 0.8, release = 0.8 },
      filter_ahdsr = { attack = 0.6, hold = 0.0, decay = 0.4, sustain = 0.6, release = 0.7 },
      velocity_volume = 0.3
    }
  },
  { 
    key = "long_evolving", 
    name = "Long Evolving", 
    description = "Slow movement over time",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.5, sustain = 0.7, release = 1.0 },
      filter_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.8, sustain = 0.5, release = 1.0 },
      filter_lfo = { frequency = 0.1, amount = 0.15 },
      velocity_volume = 0.2
    }
  },
  { 
    key = "percussive", 
    name = "Percussive Hit", 
    description = "Instant attack, no sustain",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
      velocity_volume = 0.9
    }
  },
  { 
    key = "swell", 
    name = "Swell", 
    description = "Long attack building up",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.5 },
      filter_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.0, sustain = 0.8, release = 0.4 },
      velocity_volume = 0.4
    }
  },
  { 
    key = "gated", 
    name = "Gated", 
    description = "Short sustain, rhythmic",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.6, release = 0.05 },
      velocity_volume = 0.7
    }
  },
  { 
    key = "tremolo", 
    name = "Tremolo", 
    description = "Volume LFO modulation",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.1, sustain = 0.8, release = 0.2 },
      volume_lfo = { frequency = 0.5, amount = 0.3 },
      velocity_volume = 0.5
    }
  },
  { 
    key = "vibrato_slow", 
    name = "Vibrato (Slow)", 
    description = "Slow pitch wobble",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.1, sustain = 0.85, release = 0.25 },
      pitch_lfo = { frequency = 0.3, amount = 0.02 },
      velocity_volume = 0.5
    }
  },
  { 
    key = "vibrato_fast", 
    name = "Vibrato (Fast)", 
    description = "Fast pitch wobble",
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.1, sustain = 0.85, release = 0.25 },
      pitch_lfo = { frequency = 0.7, amount = 0.025 },
      velocity_volume = 0.5
    }
  }
}

-- List of modulation character names for UI dropdown
METASYNTH_MODULATION_CHARACTER_NAMES = {}
for _, char in ipairs(METASYNTH_MODULATION_CHARACTERS) do
  table.insert(METASYNTH_MODULATION_CHARACTER_NAMES, char.name)
end
-- Add "None" option at the beginning
table.insert(METASYNTH_MODULATION_CHARACTER_NAMES, 1, "(Default)")

-- Helper function: Get modulation character by key
function PakettiMetaSynthGetModulationCharacter(key)
  for _, char in ipairs(METASYNTH_MODULATION_CHARACTERS) do
    if char.key == key then
      return char
    end
  end
  return nil
end

-- Helper function: Apply modulation character to architecture
function PakettiMetaSynthApplyModulationCharacter(architecture, character_key)
  local character = PakettiMetaSynthGetModulationCharacter(character_key)
  if character and character.modulation then
    -- Set custom modulation in the architecture's modulation layer
    architecture.modulation_layer = architecture.modulation_layer or {}
    architecture.modulation_layer.custom_modulation = character.modulation
    print(string.format("PakettiMetaSynth: Applied modulation character '%s'", character.name))
    return true
  end
  return false
end

-- Helper function: Clear modulation character (use profile default)
function PakettiMetaSynthClearModulationCharacter(architecture)
  if architecture.modulation_layer then
    architecture.modulation_layer.custom_modulation = nil
    print("PakettiMetaSynth: Cleared custom modulation (using profile default)")
  end
end

-- ============================================================================
-- LFO PHASE MODES
-- Control LFO phase/retrigger behavior for more musical modulation
-- ============================================================================
METASYNTH_LFO_PHASE_MODES = {
  "free",      -- Free-running (default) - LFO runs continuously
  "retrigger", -- Reset on note - phase resets to 0 on each note
  "random"     -- Random start phase - randomize phase per note
}
METASYNTH_LFO_PHASE_MODE_NAMES = {"Free", "Retrigger", "Random"}

-- ============================================================================
-- AKWF WAVEFORM FAMILIES
-- Maps family names to AKWF folder name patterns for profile-driven sample selection
-- Each family groups related waveform types for musical coherence
-- ============================================================================
PakettiMetaSynthAKWFWaveformFamilies = {
  -- Basic/General waveforms (numeric folders)
  basic = {
    patterns = {"AKWF_0"},  -- Matches AKWF_0001, AKWF_0002, etc.
    description = "General purpose waveforms"
  },
  
  -- Saw waveforms - good for bass, leads
  saw = {
    patterns = {"AKWF_bw_saw", "AKWF_saw", "AKWF_rsaw", "AKWF_sawbright", "AKWF_sawgap", "AKWF_sawmod", "AKWF_sawrounded"},
    description = "Sawtooth and saw-based waveforms"
  },
  
  -- Square waveforms - good for bass, chiptune, hollow sounds
  square = {
    patterns = {"AKWF_bw_sqr", "AKWF_sqr", "AKWF_bw_square", "AKWF_squaresynth"},
    description = "Square and pulse waveforms"
  },
  
  -- Triangle waveforms - soft, mellow
  triangle = {
    patterns = {"AKWF_bw_tri", "AKWF_tri", "AKWF_triangle"},
    description = "Triangle and soft waveforms"
  },
  
  -- Sine/harmonic waveforms - pure, sub bass
  sine = {
    patterns = {"AKWF_sin", "AKWF_sinharm", "AKWF_sinefold"},
    description = "Sine and pure harmonic waveforms"
  },
  
  -- Organ waveforms - keys, organs
  organ = {
    patterns = {"AKWF_eorgan", "AKWF_organ", "AKWF_hvoice"},
    description = "Electric and pipe organ waveforms"
  },
  
  -- Piano/EP waveforms - keys, electric piano
  piano = {
    patterns = {"AKWF_epiano", "AKWF_piano", "AKWF_eguitar"},
    description = "Piano and electric piano waveforms"
  },
  
  -- String waveforms - pads, orchestral
  strings = {
    patterns = {"AKWF_violin", "AKWF_cello", "AKWF_viol", "AKWF_string", "AKWF_bowed"},
    description = "Bowed string instrument waveforms"
  },
  
  -- Wind/Flute waveforms - leads, airy sounds
  flute = {
    patterns = {"AKWF_flute", "AKWF_oboe", "AKWF_clarinet", "AKWF_wood", "AKWF_blow", "AKWF_breath"},
    description = "Woodwind and airy waveforms"
  },
  
  -- Brass waveforms - horns, brass
  brass = {
    patterns = {"AKWF_brass", "AKWF_trombone", "AKWF_trumpet", "AKWF_horn"},
    description = "Brass instrument waveforms"
  },
  
  -- Distorted/aggressive waveforms
  distorted = {
    patterns = {"AKWF_distorted", "AKWF_fmsynth", "AKWF_bitreduced", "AKWF_gapsaw", "AKWF_gapsqr"},
    description = "Distorted and aggressive waveforms"
  },
  
  -- Chiptune/8-bit waveforms
  chiptune = {
    patterns = {"AKWF_oscchip", "AKWF_vgame", "AKWF_c64", "AKWF_blip", "AKWF_snippet"},
    description = "Retro and chiptune waveforms"
  },
  
  -- Complex/experimental waveforms
  complex = {
    patterns = {"AKWF_granular", "AKWF_raw", "AKWF_stereo", "AKWF_spectral", "AKWF_linear"},
    description = "Complex and experimental waveforms"
  },
  
  -- Harmonic/overtone waveforms
  harmonic = {
    patterns = {"AKWF_harmonic", "AKWF_overtone", "AKWF_symetric", "AKWF_perfect"},
    description = "Harmonic series and overtone waveforms"
  },
  
  -- Voice/formant waveforms
  voice = {
    patterns = {"AKWF_hvoice", "AKWF_vox", "AKWF_formant", "AKWF_vowel"},
    description = "Voice and formant waveforms"
  },
  
  -- Noise/texture waveforms
  noise = {
    patterns = {"AKWF_noise", "AKWF_nes_noise"},
    description = "Noise and texture waveforms"
  },
  
  -- Pulse waveforms
  pulse = {
    patterns = {"AKWF_bw_pulse", "AKWF_pulse"},
    description = "Pulse width waveforms"
  },
}

-- ============================================================================
-- PROFILE GENERATION PRESETS
-- Building blocks for systematic profile generation (200+ profiles)
-- ============================================================================

-- AXIS 1: ENVELOPE CHARACTER PRESETS
METASYNTH_ENVELOPE_PRESETS = {
  ultra_tight = { attack = 0.0, hold = 0.0, decay = 0.05, sustain = 0.0, release = 0.05 },
  tight = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.1 },
  snappy = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.3, release = 0.15 },
  punchy = { attack = 0.0, hold = 0.02, decay = 0.25, sustain = 0.4, release = 0.2 },
  medium = { attack = 0.05, hold = 0.0, decay = 0.3, sustain = 0.5, release = 0.3 },
  soft = { attack = 0.1, hold = 0.0, decay = 0.4, sustain = 0.6, release = 0.4 },
  slow = { attack = 0.3, hold = 0.0, decay = 0.5, sustain = 0.7, release = 0.6 },
  very_slow = { attack = 0.7, hold = 0.0, decay = 0.8, sustain = 0.8, release = 1.0 },
  sustain = { attack = 0.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.2 },
  organ = { attack = 0.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.05 },
  swell = { attack = 0.5, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.5 },
  reverse = { attack = 1.0, hold = 0.0, decay = 0.0, sustain = 0.8, release = 0.3 },
}

-- AXIS 2: FILTER CHARACTER PRESETS
METASYNTH_FILTER_PRESETS = {
  none = { cutoff = nil, resonance = nil, ahdsr = nil, keytrack = 0.0 },
  full_open = { cutoff = 1.0, resonance = 0.0, ahdsr = nil, keytrack = 0.0 },
  bright = { cutoff = 0.85, resonance = 0.1, ahdsr = nil, keytrack = 0.3 },
  warm = { cutoff = 0.55, resonance = 0.2, ahdsr = nil, keytrack = 0.4 },
  dark = { cutoff = 0.3, resonance = 0.15, ahdsr = nil, keytrack = 0.5 },
  muted = { cutoff = 0.2, resonance = 0.1, ahdsr = nil, keytrack = 0.3 },
  sweep_fast = { cutoff = 0.35, resonance = 0.35, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.2, release = 0.1 }, keytrack = 0.4 },
  sweep_medium = { cutoff = 0.4, resonance = 0.3, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.3, release = 0.2 }, keytrack = 0.4 },
  sweep_slow = { cutoff = 0.45, resonance = 0.25, ahdsr = { attack = 0.1, hold = 0.0, decay = 0.5, sustain = 0.4, release = 0.4 }, keytrack = 0.5 },
  resonant = { cutoff = 0.4, resonance = 0.6, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.3, release = 0.15 }, keytrack = 0.5 },
  acid = { cutoff = 0.25, resonance = 0.8, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.12, sustain = 0.1, release = 0.08 }, keytrack = 0.6 },
  aggressive = { cutoff = 0.2, resonance = 0.75, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 }, keytrack = 0.5 },
  formant = { cutoff = 0.5, resonance = 0.5, ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.5, release = 0.3 }, keytrack = 0.7 },
}

-- AXIS 3: WIDTH/STEREO PRESETS
METASYNTH_WIDTH_PRESETS = {
  mono = { unison_range = {1, 1}, detune_range = {0, 0}, pan_spread_range = {0.0, 0.0} },
  narrow = { unison_range = {1, 2}, detune_range = {0, 8}, pan_spread_range = {0.0, 0.2} },
  medium = { unison_range = {2, 3}, detune_range = {5, 15}, pan_spread_range = {0.2, 0.5} },
  wide = { unison_range = {3, 4}, detune_range = {8, 20}, pan_spread_range = {0.5, 0.8} },
  ultra_wide = { unison_range = {4, 6}, detune_range = {12, 30}, pan_spread_range = {0.7, 1.0} },
  supersaw = { unison_range = {5, 7}, detune_range = {15, 35}, pan_spread_range = {0.8, 1.0} },
}

-- AXIS 4: COMPLEXITY PRESETS
METASYNTH_COMPLEXITY_PRESETS = {
  minimal = { frame_count_range = {1, 1}, sample_count_range = {1, 1}, fx_count_range = {0, 0}, group_frame_enabled = false },
  simple = { frame_count_range = {1, 2}, sample_count_range = {1, 2}, fx_count_range = {0, 1}, group_frame_enabled = false },
  medium = { frame_count_range = {2, 3}, sample_count_range = {1, 2}, fx_count_range = {1, 2}, group_frame_enabled = false },
  complex = { frame_count_range = {3, 4}, sample_count_range = {2, 3}, fx_count_range = {2, 3}, group_frame_enabled = false },
  dense = { frame_count_range = {4, 6}, sample_count_range = {2, 4}, fx_count_range = {2, 4}, group_frame_enabled = true },
  wavetable = { frame_count_range = {4, 8}, sample_count_range = {1, 1}, fx_count_range = {1, 2}, group_frame_enabled = true },
}

-- AXIS 5: FX TENDENCIES PRESETS
METASYNTH_FX_TENDENCY_PRESETS = {
  clean = { frame = {}, group = {}, global = {} },
  warm = { frame = {"Analog Filter"}, group = {}, global = {"EQ 10"} },
  saturated = { frame = {"Distortion"}, group = {}, global = {"EQ 10", "Compressor"} },
  heavily_saturated = { frame = {"Distortion", "Cabinet Simulator"}, group = {"Exciter"}, global = {"EQ 10", "Compressor"} },
  spatial = { frame = {}, group = {}, global = {"Reverb", "mpReverb 2"} },
  spatial_delay = { frame = {}, group = {}, global = {"Delay", "Reverb"} },
  movement = { frame = {"Chorus", "Flanger"}, group = {}, global = {} },
  phaser = { frame = {"Phaser"}, group = {}, global = {} },
  lofi = { frame = {"Lofimat 2"}, group = {}, global = {} },
  aggressive = { frame = {"Distortion", "Analog Filter"}, group = {"Exciter"}, global = {"Compressor"} },
  cinematic = { frame = {}, group = {"Stereo Expander"}, global = {"Reverb", "mpReverb 2", "EQ 10"} },
  vintage = { frame = {"Analog Filter", "Chorus"}, group = {}, global = {"Compressor", "EQ 10"} },
}

-- AXIS 6: MOVEMENT/MODULATION PRESETS
METASYNTH_MOVEMENT_PRESETS = {
  static = { morph_enabled = false, crossfade_enabled = false, volume_lfo = nil, pitch_lfo = nil, filter_lfo = nil },
  subtle_vibrato = { morph_enabled = false, crossfade_enabled = false, volume_lfo = nil, pitch_lfo = { frequency = 0.4, amount = 0.15, mode = 1 }, filter_lfo = nil },
  vibrato = { morph_enabled = false, crossfade_enabled = false, volume_lfo = nil, pitch_lfo = { frequency = 0.5, amount = 0.25, mode = 1 }, filter_lfo = nil },
  tremolo = { morph_enabled = false, crossfade_enabled = false, volume_lfo = { frequency = 0.4, amount = 0.3, mode = 1 }, pitch_lfo = nil, filter_lfo = nil },
  filter_wobble = { morph_enabled = false, crossfade_enabled = false, volume_lfo = nil, pitch_lfo = nil, filter_lfo = { frequency = 0.3, amount = 0.4, mode = 1 } },
  filter_slow = { morph_enabled = false, crossfade_enabled = false, volume_lfo = nil, pitch_lfo = nil, filter_lfo = { frequency = 0.15, amount = 0.3, mode = 1 } },
  morphing = { morph_enabled = true, morph_speed = "medium", crossfade_enabled = false, volume_lfo = nil, pitch_lfo = nil, filter_lfo = nil },
  morphing_slow = { morph_enabled = true, morph_speed = "slow", crossfade_enabled = false, volume_lfo = nil, pitch_lfo = nil, filter_lfo = nil },
  crossfade = { morph_enabled = false, crossfade_enabled = true, scan_speed = "medium", volume_lfo = nil, pitch_lfo = nil, filter_lfo = nil },
  evolving = { morph_enabled = true, morph_speed = "slow", crossfade_enabled = true, scan_speed = "slow", volume_lfo = nil, pitch_lfo = nil, filter_lfo = { frequency = 0.1, amount = 0.2, mode = 1 } },
  full_motion = { morph_enabled = true, morph_speed = "medium", crossfade_enabled = true, scan_speed = "medium", volume_lfo = { frequency = 0.2, amount = 0.15, mode = 1 }, pitch_lfo = { frequency = 0.35, amount = 0.1, mode = 1 }, filter_lfo = { frequency = 0.25, amount = 0.25, mode = 1 } },
}

-- AXIS 7: VELOCITY/DYNAMICS PRESETS
METASYNTH_DYNAMICS_PRESETS = {
  none = { velocity_volume = 0.0, velocity_filter = 0.0 },
  subtle = { velocity_volume = 0.3, velocity_filter = 0.2 },
  moderate = { velocity_volume = 0.5, velocity_filter = 0.4 },
  expressive = { velocity_volume = 0.7, velocity_filter = 0.6 },
  full = { velocity_volume = 1.0, velocity_filter = 0.8 },
  filter_only = { velocity_volume = 0.2, velocity_filter = 0.7 },
}

-- ============================================================================
-- PROFILE BUILDER FUNCTION
-- Combines presets to generate complete profile definitions
-- ============================================================================

function PakettiMetaSynthBuildProfile(config)
  local envelope = METASYNTH_ENVELOPE_PRESETS[config.envelope or "medium"]
  local filter = METASYNTH_FILTER_PRESETS[config.filter or "none"]
  local width = METASYNTH_WIDTH_PRESETS[config.width or "narrow"]
  local complexity = METASYNTH_COMPLEXITY_PRESETS[config.complexity or "simple"]
  local fx = METASYNTH_FX_TENDENCY_PRESETS[config.fx or "clean"]
  local movement = METASYNTH_MOVEMENT_PRESETS[config.movement or "static"]
  local dynamics = METASYNTH_DYNAMICS_PRESETS[config.dynamics or "moderate"]
  
  local profile = {
    name = config.name or "Unnamed Profile",
    description = config.description or "",
    family = config.family or "misc",
    
    -- LAYER 1: Oscillator rules
    oscillator = {
      unison_range = width.unison_range,
      frame_count_range = complexity.frame_count_range,
      detune_range = width.detune_range,
      pan_spread_range = width.pan_spread_range,
      sample_count_range = complexity.sample_count_range,
    },
    
    -- LAYER 2: Frame rules
    frame = {
      morph_enabled = movement.morph_enabled or false,
      morph_speed = movement.morph_speed or "none",
      fx_tendencies = fx.frame or {},
      fx_count_range = complexity.fx_count_range,
    },
    
    -- LAYER 3: Oscillator Modulation rules (SEPARATE layer)
    modulation = {
      enabled = true,
      volume_ahdsr = envelope,
      filter_ahdsr = filter.ahdsr,
      pitch_ahdsr = config.pitch_ahdsr,
      volume_lfo = movement.volume_lfo,
      pitch_lfo = movement.pitch_lfo,
      filter_lfo = movement.filter_lfo,
      velocity_volume = dynamics.velocity_volume,
      velocity_filter = dynamics.velocity_filter,
      filter_keytrack = filter.keytrack or 0.0,
      filter_cutoff = filter.cutoff,
      filter_resonance = filter.resonance,
    },
    
    -- LAYER 4: Oscillator Groups (summing, organization, oscillator group FX, wavetable/vector control)
    oscillator_groups = {
      crossfade_enabled = movement.crossfade_enabled or false,
      scan_speed = movement.scan_speed,
      lfo_rate_preset = config.lfo_rate or "medium",
      -- Oscillator group FX (per-group FX)
      osc_group_fx_enabled = #(fx.group or {}) > 0 or config.group_fx_enabled or false,
      osc_group_fx_tendencies = fx.group or {},
      osc_group_fx_count_range = {0, 2},
      -- Wavetable/vector control
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    -- LAYER 5: Group Frames
    group_frame = {
      enabled = complexity.group_frame_enabled or false,
      frame_count_range = complexity.group_frame_enabled and {2, 4} or {1, 1},
      morph_enabled = complexity.group_frame_enabled and movement.morph_enabled or false,
      morph_speed = complexity.group_frame_enabled and movement.morph_speed or "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    -- LAYER 6: Total Group FX (FX after all groups summed - Stack Master FX)
    total_group_fx = {
      enabled = #(fx.global or {}) > 0 or config.global_fx_enabled or false,
      tendencies = fx.global or {},
      count_range = {0, 2},
    },
    
    -- LAYER 7: Total Group Frames / Vector Layer (frame morphing at total summed groups level)
    total_group_frames = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    -- LAYER 8: Global FX rules
    global_fx = {
      enabled = #(fx.global or {}) > 0 or config.global_fx_enabled,
      tendencies = fx.global or {},
      reverb_size = config.reverb_size,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = config.source or "akwf",
      waveform_families = config.waveforms or {"basic"},
      avoid_families = config.avoid_waveforms or {},
    },
  }
  
  return profile
end

-- ============================================================================
-- MULTI-LAYER PROFILES - Musical intent projected across all architectural layers
-- 
-- A Global Profile (Pluck, Pad, Bass, Lead, etc.) defines MUSICAL INTENT.
-- That same profile is then projected downward into each architectural layer,
-- where every section consumes the subset of rules that apply to it.
--
-- 8-LAYER STRUCTURE (Canonical MetaSynth Template):
--   1. oscillator:        Wave types, unison tendencies, frame usage
--   2. frame:             Oscillator Frames - spectral variation of individual oscillators
--   3. modulation:        Oscillator Modulation - polyphonic modulation per oscillator (SEPARATE layer)
--   4. oscillator_groups: Oscillator Groups - summing, organization, oscillator group FX, wavetable/vector control
--   5. group_frame:       Group Frames - meta-wavetable at group level (default OFF)
--   6. total_group_fx:    Total Group FX - FX applied after all groups summed (Stack Master FX)
--   7. total_group_frames: Total Group Frames / Vector Layer - frame morphing at total summed groups level
--   8. global_fx:         Global FX - final instrument polish and mix translation
--   9. sample_selection:  AKWF waveform families and source preferences (metadata layer)
--
-- OVERRIDE CHAIN: oscillator > group > architecture.global_profile > "default"
-- MODULATION can be overridden independently via architecture.modulation_layer
-- All layers default to the same profile (coherent instrument)
-- Any layer can override with a different profile (hybrid sounds)
-- ============================================================================

PakettiMetaSynthProfiles = {
  -- ========================================================================
  -- NEUTRAL family - Raw/experimental starting points
  -- ========================================================================
  neutral_flat = {
    name = "Neutral (Flat)",
    description = "Raw oscillator, flat sustain, sound design starting point",
    family = "neutral",
    
    -- LAYER 1: Oscillator rules
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {0, 10},
      pan_spread_range = {0.0, 0.3},
      sample_count_range = {1, 2},
    },
    
    -- LAYER 2: Frame rules
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 1},
    },
    
    -- LAYER 3: Oscillator Modulation rules (SEPARATE layer)
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.1 },
      filter_ahdsr = nil,
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.2,
      velocity_filter = 0.0,
      filter_keytrack = 0.0,
      filter_cutoff = nil,
      filter_resonance = nil,
    },
    
    -- LAYER 4: Oscillator Groups (summing, organization, oscillator group FX, wavetable/vector control)
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = "medium",
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 1},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    -- LAYER 5: Group Frames (meta-wavetable at group level)
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    -- LAYER 6: Total Group FX (FX after all groups summed - Stack Master FX)
    total_group_fx = {
      enabled = false,
      tendencies = {},
      count_range = {0, 1},
    },
    
    -- LAYER 7: Total Group Frames / Vector Layer (frame morphing at total summed groups level)
    total_group_frames = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    -- LAYER 8: Global FX rules
    global_fx = {
      enabled = false,
      tendencies = {},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"basic"},
      avoid_families = {},
    },
  },
  
  neutral_none = {
    name = "Neutral (No Envelope)",
    description = "Bypass envelope, raw oscillator behavior",
    family = "neutral",
    
    oscillator = {
      unison_range = {1, 1},
      frame_count_range = {1, 1},
      detune_range = {0, 0},
      pan_spread_range = {0.0, 0.0},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    modulation = {
      enabled = false,
      volume_ahdsr = nil,
      filter_ahdsr = nil,
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.0,
      velocity_filter = 0.0,
      filter_keytrack = 0.0,
      filter_cutoff = nil,
      filter_resonance = nil,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = false,
      tendencies = {},
      count_range = {0, 0},
    },
    
    total_group_frames = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    global_fx = {
      enabled = false,
      tendencies = {},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"basic"},
      avoid_families = {},
    },
  },
  
  -- ========================================================================
  -- BASS family - Solid low-end sounds
  -- ========================================================================
  bass_tight = {
    name = "Bass (Tight)",
    description = "Mono basses, acid-style, precise low-end",
    family = "bass",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {3, 12},
      pan_spread_range = {0.0, 0.2},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.7, release = 0.1 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.4, release = 0.1 },
      pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.03, sustain = 0.0, release = 0.02, amount = -0.03 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.6,
      velocity_filter = 0.5,
      filter_keytrack = 0.4,
      filter_cutoff = 0.45,
      filter_resonance = 0.35,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor", "EQ 5"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  bass_sustain = {
    name = "Bass (Sustain)",
    description = "Sub bass, held notes, minimal articulation",
    family = "bass",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 1},
      detune_range = {0, 8},
      pan_spread_range = {0.0, 0.1},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {0, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.05, sustain = 1.0, release = 0.2 },
      filter_ahdsr = nil,
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.3,
      velocity_filter = 0.0,
      filter_keytrack = 0.6,
      filter_cutoff = 0.3,
      filter_resonance = 0.1,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  bass_filter = {
    name = "Bass (Filter-Driven)",
    description = "Acid bass, aggressive filter envelope, resonance sweep",
    family = "bass",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {5, 15},
      pan_spread_range = {0.0, 0.2},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.85, release = 0.12 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.35, sustain = 0.25, release = 0.15 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.7,
      filter_keytrack = 0.5,
      filter_cutoff = 0.55,
      filter_resonance = 0.55,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Distortion", "Saturator"},
      count_range = {1, 3},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor", "EQ 5"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  bass_wide = {
    name = "Bass (Wide/Slow)",
    description = "Reese bass, slow movement, wide stereo",
    family = "bass",
    
    oscillator = {
      unison_range = {2, 4},
      frame_count_range = {1, 2},
      detune_range = {10, 25},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Phaser"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.2, sustain = 0.9, release = 0.25 },
      filter_ahdsr = { attack = 0.3, hold = 0.0, decay = 0.5, sustain = 0.5, release = 0.3 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = { frequency = 0.3, amount = 0.15 },
      velocity_volume = 0.4,
      velocity_filter = 0.3,
      filter_keytrack = 0.3,
      filter_cutoff = 0.5,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus", "Phaser"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor", "Stereo Expander"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  bass_dynamic = {
    name = "Bass (Dynamic)",
    description = "FM bass, velocity-sensitive, punchy",
    family = "bass",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {3, 10},
      pan_spread_range = {0.0, 0.2},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.12, sustain = 0.75, release = 0.1 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.5, release = 0.1 },
      pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.02, sustain = 0.0, release = 0.01, amount = -0.05 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.8,
      velocity_filter = 0.6,
      filter_keytrack = 0.4,
      filter_cutoff = 0.6,
      filter_resonance = 0.3,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor", "EQ 5"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  -- ========================================================================
  -- PLUCK family - Short, percussive attacks
  -- ========================================================================
  pluck_short = {
    name = "Pluck (Short)",
    description = "Plucks, mallets, short hits",
    family = "pluck",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {3, 12},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.08 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.15, release = 0.08 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.8,
      velocity_filter = 0.6,
      filter_keytrack = 0.3,
      filter_cutoff = 0.7,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "triangle", "piano"},
      avoid_families = {"complex"},
    },
  },
  
  pluck_natural = {
    name = "Pluck (Natural)",
    description = "Harp/guitar, slightly longer decay, natural release",
    family = "pluck",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {2, 8},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.0, release = 0.2 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.5, sustain = 0.2, release = 0.25 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.4,
      filter_cutoff = 0.65,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "triangle", "piano"},
      avoid_families = {"complex"},
    },
  },
  
  pluck_percussive = {
    name = "Pluck (Percussive)",
    description = "Very fast, mallet-like",
    family = "pluck",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 1},
      detune_range = {2, 8},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
      pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.02, sustain = 0.0, release = 0.01, amount = -0.08 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.9,
      velocity_filter = 0.7,
      filter_keytrack = 0.2,
      filter_cutoff = 0.8,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "triangle", "piano"},
      avoid_families = {"complex"},
    },
  },
  
  pluck_soft = {
    name = "Pluck (Soft)",
    description = "Kalimba, gentler attack, softer filter",
    family = "pluck",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {2, 8},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {0, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.5, sustain = 0.0, release = 0.3 },
      filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.6, sustain = 0.25, release = 0.35 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.4,
      filter_keytrack = 0.5,
      filter_cutoff = 0.5,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "triangle", "piano"},
      avoid_families = {"complex"},
    },
  },
  
  -- ========================================================================
  -- LEAD family - Expressive, melodic sounds
  -- ========================================================================
  lead_expressive = {
    name = "Lead (Expressive)",
    description = "Solo mono lead, vibrato, expression-driven",
    family = "lead",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 3},
      detune_range = {5, 20},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "medium",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.1, sustain = 0.8, release = 0.15 },
      filter_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.2, sustain = 0.6, release = 0.15 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.02 },
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.5,
      filter_cutoff = 0.65,
      filter_resonance = 0.3,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Distortion", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  lead_smooth = {
    name = "Lead (Smooth)",
    description = "Polyphonic lead, softer, more legato",
    family = "lead",
    
    oscillator = {
      unison_range = {2, 4},
      frame_count_range = {2, 3},
      detune_range = {8, 20},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.08, hold = 0.0, decay = 0.15, sustain = 0.85, release = 0.25 },
      filter_ahdsr = { attack = 0.1, hold = 0.0, decay = 0.3, sustain = 0.6, release = 0.25 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 4.5, amount = 0.015 },
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.4,
      filter_keytrack = 0.4,
      filter_cutoff = 0.55,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus", "Phaser"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  lead_classic = {
    name = "Lead (Classic)",
    description = "Square lead, classic mono synth sound",
    family = "lead",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {5, 15},
      pan_spread_range = {0.1, 0.3},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.75, release = 0.12 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.5, release = 0.12 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.5, amount = 0.025 },
      filter_lfo = nil,
      velocity_volume = 0.6,
      velocity_filter = 0.5,
      filter_keytrack = 0.6,
      filter_cutoff = 0.7,
      filter_resonance = 0.35,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Distortion"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  lead_wide = {
    name = "Lead (Wide)",
    description = "Supersaw lead, huge stereo width, modern trance",
    family = "lead",
    
    oscillator = {
      unison_range = {4, 7},
      frame_count_range = {1, 2},
      detune_range = {15, 35},
      pan_spread_range = {0.6, 1.0},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.08, sustain = 0.9, release = 0.2 },
      filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.2, sustain = 0.7, release = 0.2 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.4,
      velocity_filter = 0.3,
      filter_keytrack = 0.5,
      filter_cutoff = 0.75,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus", "Stereo Expander"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay", "Stereo Expander"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  lead_glide = {
    name = "Lead (Glide)",
    description = "Portamento lead, smooth pitch slides",
    family = "lead",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 2},
      detune_range = {5, 15},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "medium",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.03, hold = 0.0, decay = 0.12, sustain = 0.8, release = 0.18 },
      filter_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.25, sustain = 0.55, release = 0.2 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.02 },
      filter_lfo = nil,
      velocity_volume = 0.6,
      velocity_filter = 0.5,
      filter_keytrack = 0.5,
      filter_cutoff = 0.6,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  -- ========================================================================
  -- PAD family - Long, sustained, evolving sounds
  -- ========================================================================
  pad_slow = {
    name = "Pad (Slow)",
    description = "Classic pad, slow attack and release",
    family = "pad",
    
    oscillator = {
      unison_range = {2, 5},
      frame_count_range = {2, 4},
      detune_range = {8, 25},
      pan_spread_range = {0.4, 0.8},
      sample_count_range = {1, 3},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus", "Phaser"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.5, hold = 0.0, decay = 0.3, sustain = 0.85, release = 0.8 },
      filter_ahdsr = { attack = 0.8, hold = 0.0, decay = 0.5, sustain = 0.6, release = 0.8 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = { frequency = 0.3, amount = 0.1 },
      velocity_volume = 0.3,
      velocity_filter = 0.2,
      filter_keytrack = 0.4,
      filter_cutoff = 0.5,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Phaser", "Analog Filter"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "harmonic", "complex", "sine"},
      avoid_families = {"chiptune"},
    },
  },
  
  pad_evolving = {
    name = "Pad (Evolving)",
    description = "Ambient pad, slow movement, drifting",
    family = "pad",
    
    oscillator = {
      unison_range = {3, 6},
      frame_count_range = {3, 5},
      detune_range = {10, 30},
      pan_spread_range = {0.5, 1.0},
      sample_count_range = {2, 4},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus", "Phaser", "Flanger"},
      fx_count_range = {2, 3},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.5, sustain = 0.8, release = 1.5 },
      filter_ahdsr = { attack = 1.5, hold = 0.0, decay = 1.0, sustain = 0.5, release = 1.5 },
      pitch_ahdsr = nil,
      volume_lfo = { frequency = 0.15, amount = 0.08 },
      pitch_lfo = nil,
      filter_lfo = { frequency = 0.2, amount = 0.15 },
      velocity_volume = 0.2,
      velocity_filter = 0.15,
      filter_keytrack = 0.3,
      filter_cutoff = 0.45,
      filter_resonance = 0.1,
    },
    
    -- pad_evolving has GROUP FRAMES ENABLED for meta-wavetable behavior
    group_frame = {
      enabled = true,
      frame_count_range = {2, 4},
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Phaser", "Flanger"},
      fx_count_range = {1, 2},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Phaser", "Flanger", "Analog Filter"},
      count_range = {2, 3},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "harmonic", "complex", "sine"},
      avoid_families = {"chiptune"},
    },
  },
  
  pad_ensemble = {
    name = "Pad (Ensemble)",
    description = "String pad, warm, orchestral feel",
    family = "pad",
    
    oscillator = {
      unison_range = {3, 5},
      frame_count_range = {2, 4},
      detune_range = {8, 20},
      pan_spread_range = {0.4, 0.7},
      sample_count_range = {2, 3},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.4, hold = 0.0, decay = 0.2, sustain = 0.9, release = 0.6 },
      filter_ahdsr = { attack = 0.5, hold = 0.0, decay = 0.4, sustain = 0.7, release = 0.6 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 4.5, amount = 0.008 },
      filter_lfo = nil,
      velocity_volume = 0.4,
      velocity_filter = 0.3,
      filter_keytrack = 0.5,
      filter_cutoff = 0.55,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Analog Filter", "EQ 5"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "EQ 5"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "harmonic", "complex", "sine"},
      avoid_families = {"chiptune"},
    },
  },
  
  pad_formant = {
    name = "Pad (Formant)",
    description = "Choir/vocal pad, formant-like character",
    family = "pad",
    
    oscillator = {
      unison_range = {2, 4},
      frame_count_range = {3, 5},
      detune_range = {5, 15},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {2, 4},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter", "Comb Filter"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.3, hold = 0.0, decay = 0.25, sustain = 0.85, release = 0.5 },
      filter_ahdsr = { attack = 0.4, hold = 0.0, decay = 0.4, sustain = 0.65, release = 0.5 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.01 },
      filter_lfo = { frequency = 0.4, amount = 0.12 },
      velocity_volume = 0.35,
      velocity_filter = 0.3,
      filter_keytrack = 0.6,
      filter_cutoff = 0.5,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Analog Filter", "Comb Filter"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "harmonic", "complex", "voice"},
      avoid_families = {"chiptune"},
    },
  },
  
  -- ========================================================================
  -- KEYS family - Piano, organ, electric piano sounds
  -- ========================================================================
  keys_dynamic = {
    name = "Keys (Dynamic)",
    description = "Electric piano, Rhodes-like, velocity-sensitive",
    family = "keys",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {2, 8},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.5, release = 0.25 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.4, release = 0.25 },
      pitch_ahdsr = nil,
      volume_lfo = { frequency = 5.0, amount = 0.03 },
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.8,
      velocity_filter = 0.6,
      filter_keytrack = 0.6,
      filter_cutoff = 0.65,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Analog Filter", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Compressor"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"piano", "organ", "harmonic"},
      avoid_families = {"distorted"},
    },
  },
  
  keys_sustain = {
    name = "Keys (Organ)",
    description = "Organ, full sustain, drawbar-style",
    family = "keys",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {0, 5},
      pan_spread_range = {0.1, 0.3},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Chorus", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.05 },
      filter_ahdsr = nil,
      pitch_ahdsr = nil,
      volume_lfo = { frequency = 6.0, amount = 0.05 },
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.3,
      velocity_filter = 0.0,
      filter_keytrack = 0.0,
      filter_cutoff = nil,
      filter_resonance = nil,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Distortion", "Cabinet Simulator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "EQ 5"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"piano", "organ", "harmonic"},
      avoid_families = {"distorted"},
    },
  },
  
  keys_velocity = {
    name = "Keys (Velocity)",
    description = "Piano-like, highly velocity-sensitive",
    family = "keys",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {1, 5},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {0, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.8, sustain = 0.0, release = 0.4 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 1.0, sustain = 0.3, release = 0.4 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.9,
      velocity_filter = 0.7,
      filter_keytrack = 0.7,
      filter_cutoff = 0.7,
      filter_resonance = 0.1,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Compressor", "EQ 5"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Compressor"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"piano", "organ", "harmonic"},
      avoid_families = {"distorted"},
    },
  },
  
  -- ========================================================================
  -- ARP family - Short, rhythmic, sequencer-friendly sounds
  -- ========================================================================
  arp_tight = {
    name = "Arp (Tight)",
    description = "Fast arpeggio, very short, punchy",
    family = "arp",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 1},
      detune_range = {3, 10},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.05, sustain = 0.0, release = 0.03 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.06, sustain = 0.0, release = 0.03 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.3,
      filter_cutoff = 0.75,
      filter_resonance = 0.3,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Gate"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Delay", "Reverb"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "chiptune"},
      avoid_families = {"complex", "strings"},
    },
  },
  
  arp_gated = {
    name = "Arp (Gated)",
    description = "Gated arpeggio, rhythmic chopping",
    family = "arp",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 1},
      detune_range = {3, 10},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter", "Gate"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.6, release = 0.05 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.5, release = 0.05 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.6,
      velocity_filter = 0.4,
      filter_keytrack = 0.3,
      filter_cutoff = 0.7,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Gate", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Delay", "Reverb"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "chiptune"},
      avoid_families = {"complex", "strings"},
    },
  },
  
  arp_rhythmic = {
    name = "Arp (Rhythmic)",
    description = "One-note sequence, rhythmic pattern potential",
    family = "arp",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {5, 12},
      pan_spread_range = {0.3, 0.5},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.3, release = 0.08 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.4, release = 0.08 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.4,
      filter_cutoff = 0.65,
      filter_resonance = 0.3,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Gate"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Delay", "Reverb"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "chiptune"},
      avoid_families = {"complex", "strings"},
    },
  },
  
  -- ========================================================================
  -- FX family - Sound effects, risers, impacts
  -- ========================================================================
  fx_envelope = {
    name = "FX (Envelope)",
    description = "Risers, sweeps, long envelope-driven FX",
    family = "fx",
    
    oscillator = {
      unison_range = {2, 5},
      frame_count_range = {2, 4},
      detune_range = {10, 30},
      pan_spread_range = {0.5, 1.0},
      sample_count_range = {2, 4},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Phaser", "Flanger", "Distortion"},
      fx_count_range = {2, 4},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 2.0, hold = 0.5, decay = 1.0, sustain = 0.5, release = 1.5 },
      filter_ahdsr = { attack = 3.0, hold = 0.0, decay = 1.5, sustain = 0.3, release = 1.5 },
      pitch_ahdsr = { attack = 2.5, hold = 0.0, decay = 0.5, sustain = 0.8, release = 0.5, amount = 0.2 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = { frequency = 0.2, amount = 0.2 },
      velocity_volume = 0.2,
      velocity_filter = 0.15,
      filter_keytrack = 0.2,
      filter_cutoff = 0.3,
      filter_resonance = 0.3,
    },
    
    -- fx_envelope has GROUP FRAMES ENABLED for evolving FX
    group_frame = {
      enabled = true,
      frame_count_range = {2, 4},
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Phaser", "Flanger"},
      fx_count_range = {1, 2},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Phaser", "Flanger", "Analog Filter", "Distortion"},
      count_range = {2, 4},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"complex", "distorted"},
      avoid_families = {"basic"},
    },
  },
  
  fx_percussive = {
    name = "FX (Percussive)",
    description = "Impacts, hits, one-shot FX",
    family = "fx",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 2},
      detune_range = {5, 20},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Distortion", "Analog Filter"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.0, release = 0.2 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.0, release = 0.2 },
      pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.1, amount = -0.3 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.8,
      velocity_filter = 0.6,
      filter_keytrack = 0.2,
      filter_cutoff = 0.8,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Distortion", "Analog Filter", "Saturator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"complex", "distorted", "noise"},
      avoid_families = {"basic"},
    },
  },
  
  fx_sustain = {
    name = "FX (Drone)",
    description = "Drones, sustained atmospheric FX",
    family = "fx",
    
    oscillator = {
      unison_range = {3, 6},
      frame_count_range = {3, 5},
      detune_range = {15, 40},
      pan_spread_range = {0.6, 1.0},
      sample_count_range = {2, 4},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Phaser", "Flanger", "Chorus"},
      fx_count_range = {2, 4},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 1.5, hold = 0.0, decay = 0.5, sustain = 0.9, release = 2.0 },
      filter_ahdsr = { attack = 2.0, hold = 0.0, decay = 1.0, sustain = 0.6, release = 2.0 },
      pitch_ahdsr = nil,
      volume_lfo = { frequency = 0.1, amount = 0.1 },
      pitch_lfo = { frequency = 0.05, amount = 0.005 },
      filter_lfo = { frequency = 0.15, amount = 0.15 },
      velocity_volume = 0.15,
      velocity_filter = 0.1,
      filter_keytrack = 0.2,
      filter_cutoff = 0.4,
      filter_resonance = 0.2,
    },
    
    -- fx_sustain has GROUP FRAMES ENABLED for evolving drones
    group_frame = {
      enabled = true,
      frame_count_range = {2, 3},
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Phaser", "Flanger", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Phaser", "Flanger", "Chorus", "Analog Filter"},
      count_range = {2, 4},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"complex", "distorted", "harmonic"},
      avoid_families = {"basic"},
    },
  },
  
  -- ========================================================================
  -- ORCHESTRAL family - Strings, brass, woodwinds
  -- ========================================================================
  strings = {
    name = "Strings",
    description = "Orchestral strings, expressive, legato",
    family = "orchestral",
    
    oscillator = {
      unison_range = {2, 4},
      frame_count_range = {2, 4},
      detune_range = {5, 15},
      pan_spread_range = {0.3, 0.6},
      sample_count_range = {2, 3},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.25, hold = 0.0, decay = 0.15, sustain = 0.9, release = 0.4 },
      filter_ahdsr = { attack = 0.3, hold = 0.0, decay = 0.2, sustain = 0.75, release = 0.4 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.01 },
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.4,
      filter_keytrack = 0.5,
      filter_cutoff = 0.6,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Analog Filter", "EQ 5"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "EQ 5"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "brass", "flute"},
      avoid_families = {"chiptune"},
    },
  },
  
  brass = {
    name = "Brass",
    description = "Brass section, punchy attack, bright filter",
    family = "orchestral",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 2},
      detune_range = {3, 10},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "medium",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.08, hold = 0.0, decay = 0.12, sustain = 0.85, release = 0.2 },
      filter_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.15, sustain = 0.7, release = 0.2 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.012 },
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.6,
      filter_keytrack = 0.5,
      filter_cutoff = 0.7,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator", "EQ 5"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "EQ 5"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "brass", "flute"},
      avoid_families = {"chiptune"},
    },
  },
  
  -- ========================================================================
  -- BELL family - Metallic, bell-like, FM sounds
  -- ========================================================================
  bell = {
    name = "Bell",
    description = "Metallic bell, FM-like, bright harmonics",
    family = "bell",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {2, 8},
      pan_spread_range = {0.3, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter"},
      fx_count_range = {0, 1},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 1.5, sustain = 0.0, release = 0.8 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 2.0, sustain = 0.2, release = 0.8 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.6,
      filter_cutoff = 0.8,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"harmonic", "sine"},
      avoid_families = {},
    },
  },
  
  -- ========================================================================
  -- LEGACY profiles - Kept for backward compatibility
  -- ========================================================================
  default = {
    name = "Default",
    description = "Balanced default, general purpose",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 3},
      detune_range = {5, 20},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "medium",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.2, sustain = 0.7, release = 0.3 },
      filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.3, sustain = 0.5, release = 0.3 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.3,
      filter_keytrack = 0.4,
      filter_cutoff = 0.6,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"basic", "saw"},
      avoid_families = {},
    },
  },
  
  pluck = {
    name = "Pluck (Legacy)",
    description = "Legacy pluck profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {3, 12},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.0, release = 0.15 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.2, release = 0.15 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.3,
      filter_cutoff = 0.65,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "triangle", "piano"},
      avoid_families = {"complex"},
    },
  },
  
  bass = {
    name = "Bass (Legacy)",
    description = "Legacy bass profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {3, 12},
      pan_spread_range = {0.0, 0.2},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.8, release = 0.12 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.25, sustain = 0.4, release = 0.12 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.4,
      filter_keytrack = 0.5,
      filter_cutoff = 0.5,
      filter_resonance = 0.3,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Compressor", "EQ 5"},
      reverb_size = nil,
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "sine"},
      avoid_families = {"chiptune", "flute"},
    },
  },
  
  pad = {
    name = "Pad (Legacy)",
    description = "Legacy pad profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {2, 5},
      frame_count_range = {2, 4},
      detune_range = {8, 25},
      pan_spread_range = {0.4, 0.8},
      sample_count_range = {1, 3},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "slow",
      fx_tendencies = {"Analog Filter", "Chorus", "Phaser"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "slow",
      lfo_rate_preset = "slow",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.4, hold = 0.0, decay = 0.3, sustain = 0.85, release = 0.7 },
      filter_ahdsr = { attack = 0.6, hold = 0.0, decay = 0.5, sustain = 0.6, release = 0.7 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = { frequency = 0.3, amount = 0.1 },
      velocity_volume = 0.3,
      velocity_filter = 0.2,
      filter_keytrack = 0.4,
      filter_cutoff = 0.5,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Phaser", "Analog Filter"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "large",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"strings", "harmonic", "complex", "sine"},
      avoid_families = {"chiptune"},
    },
  },
  
  lead = {
    name = "Lead (Legacy)",
    description = "Legacy lead profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 3},
      detune_range = {5, 20},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "medium",
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.12, sustain = 0.8, release = 0.15 },
      filter_ahdsr = { attack = 0.03, hold = 0.0, decay = 0.2, sustain = 0.55, release = 0.15 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = { frequency = 5.0, amount = 0.02 },
      filter_lfo = nil,
      velocity_volume = 0.6,
      velocity_filter = 0.5,
      filter_keytrack = 0.5,
      filter_cutoff = 0.65,
      filter_resonance = 0.25,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Distortion", "Chorus"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Delay"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square", "distorted"},
      avoid_families = {"strings"},
    },
  },
  
  organ = {
    name = "Organ (Legacy)",
    description = "Legacy organ profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {0, 5},
      pan_spread_range = {0.1, 0.3},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {"Chorus", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.05 },
      filter_ahdsr = nil,
      pitch_ahdsr = nil,
      volume_lfo = { frequency = 6.0, amount = 0.05 },
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.3,
      velocity_filter = 0.0,
      filter_keytrack = 0.0,
      filter_cutoff = nil,
      filter_resonance = nil,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Distortion", "Cabinet Simulator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "EQ 5"},
      reverb_size = "medium",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"organ", "harmonic"},
      avoid_families = {},
    },
  },
  
  keys = {
    name = "Keys (Legacy)",
    description = "Legacy keys profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 2},
      detune_range = {2, 8},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 2},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.35, sustain = 0.5, release = 0.25 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.45, sustain = 0.4, release = 0.25 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.7,
      velocity_filter = 0.5,
      filter_keytrack = 0.5,
      filter_cutoff = 0.6,
      filter_resonance = 0.2,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Chorus", "Analog Filter", "Compressor"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb", "Compressor"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"piano", "organ", "harmonic"},
      avoid_families = {"distorted"},
    },
  },
  
  percussive = {
    name = "Percussive (Legacy)",
    description = "Legacy percussive profile",
    family = "legacy",
    
    oscillator = {
      unison_range = {1, 2},
      frame_count_range = {1, 1},
      detune_range = {2, 8},
      pan_spread_range = {0.2, 0.4},
      sample_count_range = {1, 1},
    },
    
    frame = {
      morph_enabled = false,
      morph_speed = "fast",
      fx_tendencies = {"Analog Filter", "Distortion"},
      fx_count_range = {1, 2},
    },
    
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
      filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.12, sustain = 0.0, release = 0.05 },
      pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.05, sustain = 0.0, release = 0.02, amount = -0.1 },
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.9,
      velocity_filter = 0.7,
      filter_keytrack = 0.2,
      filter_cutoff = 0.75,
      filter_resonance = 0.15,
    },
    
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = nil,
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 0},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Saturator"},
      count_range = {1, 2},
    },
    
    global_fx = {
      enabled = true,
      tendencies = {"Reverb"},
      reverb_size = "small",
    },
    
    -- LAYER 8: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"saw", "square"},
      avoid_families = {},
    },
  },
  
  -- ========================================================================
  -- GENERATED PROFILES - Category A: Keys & Piano (25 profiles)
  -- ========================================================================
  keys_piano_spectral_sine = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Spectral (Sine)", family = "keys",
    description = "Spectral illusion piano using sine-derived waveforms",
    envelope = "snappy", filter = "warm", width = "narrow", complexity = "medium",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"sine", "harmonic"}, lfo_rate = "medium"
  }),
  keys_piano_spectral_additive = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Spectral (Additive)", family = "keys",
    description = "Piano using additive harmonic sets",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "medium",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"harmonic"}, lfo_rate = "medium"
  }),
  keys_piano_bright = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Bright/Pop", family = "keys",
    description = "Bright pop piano illusion",
    envelope = "tight", filter = "bright", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"piano", "harmonic"}, lfo_rate = "medium"
  }),
  keys_piano_soft = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Soft/Felt", family = "keys",
    description = "Soft felt piano with warm character",
    envelope = "soft", filter = "warm", width = "narrow", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"piano", "sine"}, lfo_rate = "slow"
  }),
  keys_piano_lofi = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Lo-Fi/Detuned", family = "keys",
    description = "Lo-fi detuned piano character",
    envelope = "medium", filter = "dark", width = "medium", complexity = "simple",
    fx = "lofi", movement = "static", dynamics = "moderate",
    waveforms = {"piano"}, lfo_rate = "slow"
  }),
  keys_piano_cinematic = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Cinematic", family = "keys",
    description = "Long decay cinematic piano",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "static", dynamics = "expressive",
    waveforms = {"piano", "harmonic"}, lfo_rate = "slow"
  }),
  keys_piano_prepared = PakettiMetaSynthBuildProfile({
    name = "Acoustic Piano - Prepared/Inharmonic", family = "keys",
    description = "Prepared piano with inharmonic character",
    envelope = "snappy", filter = "resonant", width = "medium", complexity = "complex",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"complex", "distorted"}, lfo_rate = "medium"
  }),
  keys_upright = PakettiMetaSynthBuildProfile({
    name = "Upright Piano - Narrow Spectrum", family = "keys",
    description = "Upright piano narrow spectrum illusion",
    envelope = "snappy", filter = "warm", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"piano"}, lfo_rate = "medium"
  }),
  keys_toy_piano = PakettiMetaSynthBuildProfile({
    name = "Toy Piano - Formant Weighted", family = "keys",
    description = "Toy piano with formant-weighted cycles",
    envelope = "tight", filter = "bright", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"sine", "harmonic"}, lfo_rate = "fast"
  }),
  keys_hybrid_synth = PakettiMetaSynthBuildProfile({
    name = "Hybrid Piano-Synth", family = "keys",
    description = "Piano-synth hybrid sound",
    envelope = "snappy", filter = "sweep_medium", width = "medium", complexity = "medium",
    fx = "movement", movement = "subtle_vibrato", dynamics = "expressive",
    waveforms = {"piano", "saw"}, lfo_rate = "medium"
  }),
  keys_ep_sine = PakettiMetaSynthBuildProfile({
    name = "Electric Piano - Sine/Triangle Core", family = "keys",
    description = "EP with sine/triangle core",
    envelope = "snappy", filter = "warm", width = "narrow", complexity = "simple",
    fx = "movement", movement = "tremolo", dynamics = "expressive",
    waveforms = {"sine", "triangle"}, lfo_rate = "medium"
  }),
  keys_ep_fm = PakettiMetaSynthBuildProfile({
    name = "Electric Piano - FM Inspired", family = "keys",
    description = "FM-style harmonic cycles EP",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "medium",
    fx = "clean", movement = "tremolo", dynamics = "full",
    waveforms = {"harmonic", "sine"}, lfo_rate = "medium"
  }),
  keys_ep_bell = PakettiMetaSynthBuildProfile({
    name = "Electric Piano - Bell Weighted", family = "keys",
    description = "Bell-weighted cycles EP",
    envelope = "tight", filter = "bright", width = "narrow", complexity = "simple",
    fx = "spatial", movement = "tremolo", dynamics = "expressive",
    waveforms = {"sine", "harmonic"}, lfo_rate = "medium"
  }),
  keys_ep_digital = PakettiMetaSynthBuildProfile({
    name = "Electric Piano - Digital/DX Style", family = "keys",
    description = "DX-style digital EP",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "medium",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"sine", "harmonic"}, lfo_rate = "fast"
  }),
  keys_ep_warm = PakettiMetaSynthBuildProfile({
    name = "Electric Piano - Warm Analog", family = "keys",
    description = "Warm analog EP illusion",
    envelope = "medium", filter = "warm", width = "medium", complexity = "simple",
    fx = "vintage", movement = "subtle_vibrato", dynamics = "expressive",
    waveforms = {"triangle", "sine"}, lfo_rate = "slow"
  }),
  keys_analog_saw = PakettiMetaSynthBuildProfile({
    name = "Analog Keys - Saw Based", family = "keys",
    description = "Saw-based analog keys",
    envelope = "medium", filter = "sweep_medium", width = "medium", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  keys_analog_square = PakettiMetaSynthBuildProfile({
    name = "Analog Keys - Square Based", family = "keys",
    description = "Square-based analog keys",
    envelope = "medium", filter = "warm", width = "narrow", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "moderate",
    waveforms = {"square"}, lfo_rate = "medium"
  }),
  keys_analog_triangle = PakettiMetaSynthBuildProfile({
    name = "Analog Keys - Triangle Based", family = "keys",
    description = "Triangle-based analog keys",
    envelope = "medium", filter = "bright", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"triangle"}, lfo_rate = "medium"
  }),
  keys_analog_mixed = PakettiMetaSynthBuildProfile({
    name = "Analog Keys - Mixed Waveforms", family = "keys",
    description = "Mixed basic waveform keys",
    envelope = "medium", filter = "warm", width = "medium", complexity = "medium",
    fx = "warm", movement = "subtle_vibrato", dynamics = "moderate",
    waveforms = {"saw", "square", "triangle"}, lfo_rate = "medium"
  }),
  keys_vintage_synth = PakettiMetaSynthBuildProfile({
    name = "Vintage Synth Keys", family = "keys",
    description = "Vintage synth key sound",
    envelope = "medium", filter = "sweep_slow", width = "medium", complexity = "medium",
    fx = "vintage", movement = "subtle_vibrato", dynamics = "expressive",
    waveforms = {"saw", "pulse"}, lfo_rate = "slow"
  }),
  keys_digital_complex = PakettiMetaSynthBuildProfile({
    name = "Digital Keys - Complex Spectral", family = "keys",
    description = "Complex spectral cycles digital keys",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "complex",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"complex", "harmonic"}, lfo_rate = "medium"
  }),
  keys_soft = PakettiMetaSynthBuildProfile({
    name = "Soft Keys - Low Harmonic", family = "keys",
    description = "Low harmonic density soft keys",
    envelope = "soft", filter = "dark", width = "narrow", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "subtle",
    waveforms = {"sine", "triangle"}, lfo_rate = "slow"
  }),
  keys_hard_percussive = PakettiMetaSynthBuildProfile({
    name = "Hard/Percussive Keys", family = "keys",
    description = "High transient emphasis percussive keys",
    envelope = "tight", filter = "bright", width = "narrow", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"saw", "square"}, lfo_rate = "fast"
  }),
  keys_plucked = PakettiMetaSynthBuildProfile({
    name = "Plucked Keys - Short Envelope", family = "keys",
    description = "Short envelope plucked key illusion",
    envelope = "tight", filter = "sweep_fast", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "expressive",
    waveforms = {"piano", "harmonic"}, lfo_rate = "medium"
  }),
  keys_pad_hybrid = PakettiMetaSynthBuildProfile({
    name = "Key-Pad Hybrid", family = "keys",
    description = "Keys blended with pad character",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "spatial", movement = "morphing_slow", dynamics = "moderate",
    waveforms = {"piano", "saw"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category B: Mallets, Bells & Struck Tones (14 profiles)
  -- ========================================================================
  mallet_sine = PakettiMetaSynthBuildProfile({
    name = "Mallets - Sine Dominant", family = "bell",
    description = "Sine-dominant mallet sound",
    envelope = "tight", filter = "bright", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "expressive",
    waveforms = {"sine"}, lfo_rate = "fast"
  }),
  mallet_triangle = PakettiMetaSynthBuildProfile({
    name = "Mallets - Triangle Dominant", family = "bell",
    description = "Triangle-dominant mallet sound",
    envelope = "tight", filter = "bright", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "expressive",
    waveforms = {"triangle"}, lfo_rate = "fast"
  }),
  mallet_inharmonic = PakettiMetaSynthBuildProfile({
    name = "Mallets - Inharmonic Additive", family = "bell",
    description = "Inharmonic additive cycles mallet",
    envelope = "tight", filter = "resonant", width = "narrow", complexity = "medium",
    fx = "spatial", movement = "static", dynamics = "full",
    waveforms = {"complex", "harmonic"}, lfo_rate = "fast"
  }),
  mallet_fm = PakettiMetaSynthBuildProfile({
    name = "Mallets - FM Inspired", family = "bell",
    description = "FM-inspired single cycles mallet",
    envelope = "ultra_tight", filter = "bright", width = "mono", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"sine", "harmonic"}, lfo_rate = "fast"
  }),
  mallet_wooden = PakettiMetaSynthBuildProfile({
    name = "Wooden Mallet Illusion", family = "bell",
    description = "Wooden mallet illusion",
    envelope = "tight", filter = "warm", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"triangle", "sine"}, lfo_rate = "fast"
  }),
  mallet_metallic = PakettiMetaSynthBuildProfile({
    name = "Metallic Mallet Illusion", family = "bell",
    description = "Metallic mallet illusion",
    envelope = "tight", filter = "resonant", width = "narrow", complexity = "medium",
    fx = "spatial", movement = "static", dynamics = "full",
    waveforms = {"harmonic", "complex"}, lfo_rate = "fast"
  }),
  bell_pure_sine = PakettiMetaSynthBuildProfile({
    name = "Bells - Pure Sine Stack", family = "bell",
    description = "Pure sine stack bell illusion",
    envelope = "snappy", filter = "full_open", width = "narrow", complexity = "medium",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"sine"}, lfo_rate = "slow"
  }),
  bell_inharmonic = PakettiMetaSynthBuildProfile({
    name = "Bells - Inharmonic Spectral", family = "bell",
    description = "Inharmonic spectral cycles bell",
    envelope = "snappy", filter = "bright", width = "medium", complexity = "complex",
    fx = "cinematic", movement = "static", dynamics = "full",
    waveforms = {"complex", "harmonic"}, lfo_rate = "slow"
  }),
  bell_glassy = PakettiMetaSynthBuildProfile({
    name = "Bells - Glassy High Harmonic", family = "bell",
    description = "Glassy high-harmonic cycles bell",
    envelope = "tight", filter = "full_open", width = "narrow", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"sine", "harmonic"}, lfo_rate = "medium"
  }),
  bell_digital_fm = PakettiMetaSynthBuildProfile({
    name = "Bells - Digital/FM", family = "bell",
    description = "Digital FM bells",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "medium",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"sine", "harmonic"}, lfo_rate = "medium"
  }),
  bell_gamelan = PakettiMetaSynthBuildProfile({
    name = "Bells - Gamelan Inspired", family = "bell",
    description = "Gamelan-inspired bell",
    envelope = "snappy", filter = "resonant", width = "medium", complexity = "complex",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"complex"}, lfo_rate = "slow"
  }),
  bell_cinematic = PakettiMetaSynthBuildProfile({
    name = "Bells - Cinematic Long Tail", family = "bell",
    description = "Cinematic long-tail bell",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "static", dynamics = "moderate",
    waveforms = {"sine", "harmonic"}, lfo_rate = "slow"
  }),
  music_box = PakettiMetaSynthBuildProfile({
    name = "Music Box Cycles", family = "bell",
    description = "Music box character",
    envelope = "tight", filter = "bright", width = "mono", complexity = "minimal",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"sine"}, lfo_rate = "fast"
  }),
  toy_clockwork = PakettiMetaSynthBuildProfile({
    name = "Toy/Clockwork Cycles", family = "bell",
    description = "Toy and clockwork character",
    envelope = "ultra_tight", filter = "bright", width = "mono", complexity = "simple",
    fx = "lofi", movement = "static", dynamics = "moderate",
    waveforms = {"sine", "square"}, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category C: Pads (17 profiles)
  -- ========================================================================
  pad_analog_saw = PakettiMetaSynthBuildProfile({
    name = "Analog Pad - Saw Based", family = "pad",
    description = "Saw-based analog pad",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "spatial", movement = "filter_slow", dynamics = "subtle",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  pad_analog_square = PakettiMetaSynthBuildProfile({
    name = "Analog Pad - Square Based", family = "pad",
    description = "Square-based analog pad",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "spatial", movement = "filter_slow", dynamics = "subtle",
    waveforms = {"square"}, lfo_rate = "slow"
  }),
  pad_analog_triangle = PakettiMetaSynthBuildProfile({
    name = "Analog Pad - Triangle Based", family = "pad",
    description = "Triangle-based analog pad",
    envelope = "slow", filter = "bright", width = "medium", complexity = "simple",
    fx = "spatial", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"triangle"}, lfo_rate = "slow"
  }),
  pad_analog_mixed = PakettiMetaSynthBuildProfile({
    name = "Analog Pad - Mixed Cycles", family = "pad",
    description = "Mixed basic cycles analog pad",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "spatial", movement = "evolving", dynamics = "subtle",
    waveforms = {"saw", "square", "triangle"}, lfo_rate = "slow"
  }),
  pad_warm = PakettiMetaSynthBuildProfile({
    name = "Warm Pad - Low Harmonic", family = "pad",
    description = "Low harmonic density warm pad",
    envelope = "very_slow", filter = "dark", width = "wide", complexity = "simple",
    fx = "cinematic", movement = "filter_slow", dynamics = "none",
    waveforms = {"triangle", "sine"}, lfo_rate = "slow"
  }),
  pad_dark = PakettiMetaSynthBuildProfile({
    name = "Dark Pad - Filtered Spectral", family = "pad",
    description = "Filtered spectral cycles dark pad",
    envelope = "very_slow", filter = "muted", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "morphing_slow", dynamics = "none",
    waveforms = {"saw", "complex"}, lfo_rate = "slow"
  }),
  pad_bright = PakettiMetaSynthBuildProfile({
    name = "Bright Pad - High Harmonic", family = "pad",
    description = "High harmonic emphasis bright pad",
    envelope = "slow", filter = "bright", width = "wide", complexity = "medium",
    fx = "spatial", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"saw", "harmonic"}, lfo_rate = "slow"
  }),
  pad_digital = PakettiMetaSynthBuildProfile({
    name = "Digital Pad - Complex Cycles", family = "pad",
    description = "Complex cycles digital pad",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "complex",
    fx = "spatial", movement = "morphing_slow", dynamics = "subtle",
    waveforms = {"complex", "harmonic"}, lfo_rate = "slow"
  }),
  pad_motion = PakettiMetaSynthBuildProfile({
    name = "Motion Pad - Frame Spectral Shift", family = "pad",
    description = "Frame-based spectral shift motion pad",
    envelope = "very_slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "movement", movement = "evolving", dynamics = "subtle",
    waveforms = {"saw", "complex"}, lfo_rate = "slow"
  }),
  pad_evolving_multi = PakettiMetaSynthBuildProfile({
    name = "Evolving Pad - Multi-Frame", family = "pad",
    description = "Multi-frame oscillator + group frames evolving pad",
    envelope = "very_slow", filter = "sweep_slow", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "full_motion", dynamics = "subtle",
    waveforms = {"saw", "complex", "harmonic"}, lfo_rate = "slow"
  }),
  pad_static = PakettiMetaSynthBuildProfile({
    name = "Static Pad", family = "pad",
    description = "Static unchanging pad",
    envelope = "slow", filter = "warm", width = "wide", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "none",
    waveforms = {"saw", "triangle"}, lfo_rate = "slow"
  }),
  pad_ambient = PakettiMetaSynthBuildProfile({
    name = "Ambient Pad", family = "pad",
    description = "Ambient atmospheric pad",
    envelope = "very_slow", filter = "dark", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "morphing_slow", dynamics = "none",
    waveforms = {"sine", "complex"}, reverb_size = "large", lfo_rate = "slow"
  }),
  pad_cinematic = PakettiMetaSynthBuildProfile({
    name = "Cinematic Pad", family = "pad",
    description = "Cinematic atmospheric pad",
    envelope = "very_slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"complex", "strings"}, reverb_size = "large", lfo_rate = "slow"
  }),
  pad_air = PakettiMetaSynthBuildProfile({
    name = "Air Pad - Noise Infused", family = "pad",
    description = "Noise-infused cycles air pad",
    envelope = "very_slow", filter = "dark", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "static", dynamics = "none",
    waveforms = {"noise", "sine"}, lfo_rate = "slow"
  }),
  pad_choir = PakettiMetaSynthBuildProfile({
    name = "Choir-Like Pad - Formant", family = "pad",
    description = "Formant cycles choir-like pad",
    envelope = "slow", filter = "formant", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"voice"}, lfo_rate = "slow"
  }),
  pad_detuned = PakettiMetaSynthBuildProfile({
    name = "Detuned Pad", family = "pad",
    description = "Heavily detuned pad",
    envelope = "slow", filter = "warm", width = "supersaw", complexity = "medium",
    fx = "spatial", movement = "filter_slow", dynamics = "subtle",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  pad_wide_stereo = PakettiMetaSynthBuildProfile({
    name = "Wide Stereo Pad", family = "pad",
    description = "Ultra-wide stereo pad",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"saw", "triangle"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category D: Drones & Atmospheres (10 profiles)
  -- ========================================================================
  drone_static_harmonic = PakettiMetaSynthBuildProfile({
    name = "Static Harmonic Drone", family = "drone",
    description = "Static harmonic drone",
    envelope = "sustain", filter = "warm", width = "wide", complexity = "simple",
    fx = "cinematic", movement = "static", dynamics = "none",
    waveforms = {"harmonic", "sine"}, lfo_rate = "slow"
  }),
  drone_evolving = PakettiMetaSynthBuildProfile({
    name = "Slowly Evolving Drone", family = "drone",
    description = "Slowly evolving harmonic drone",
    envelope = "sustain", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "none",
    waveforms = {"complex", "harmonic"}, lfo_rate = "slow"
  }),
  drone_noise = PakettiMetaSynthBuildProfile({
    name = "Noise-Weighted Drone", family = "drone",
    description = "Noise-weighted texture drone",
    envelope = "sustain", filter = "dark", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "filter_slow", dynamics = "none",
    waveforms = {"noise", "complex"}, lfo_rate = "slow"
  }),
  drone_sub = PakettiMetaSynthBuildProfile({
    name = "Sub-Harmonic Drone", family = "drone",
    description = "Sub-harmonic frequency drone",
    envelope = "sustain", filter = "muted", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "none",
    waveforms = {"sine"}, lfo_rate = "slow"
  }),
  atmosphere_cinematic = PakettiMetaSynthBuildProfile({
    name = "Cinematic Atmosphere", family = "drone",
    description = "Cinematic atmospheric texture",
    envelope = "very_slow", filter = "sweep_slow", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "full_motion", dynamics = "none",
    waveforms = {"complex", "strings"}, reverb_size = "large", lfo_rate = "slow"
  }),
  atmosphere_scifi = PakettiMetaSynthBuildProfile({
    name = "Sci-Fi Atmosphere", family = "drone",
    description = "Science fiction atmospheric texture",
    envelope = "sustain", filter = "resonant", width = "ultra_wide", complexity = "complex",
    fx = "movement", movement = "evolving", dynamics = "none",
    waveforms = {"complex", "distorted"}, lfo_rate = "slow"
  }),
  atmosphere_dark_ambient = PakettiMetaSynthBuildProfile({
    name = "Dark Ambient Bed", family = "drone",
    description = "Dark ambient background bed",
    envelope = "sustain", filter = "muted", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "morphing_slow", dynamics = "none",
    waveforms = {"complex", "noise"}, reverb_size = "large", lfo_rate = "slow"
  }),
  atmosphere_industrial = PakettiMetaSynthBuildProfile({
    name = "Industrial Spectral Bed", family = "drone",
    description = "Industrial spectral background",
    envelope = "sustain", filter = "aggressive", width = "wide", complexity = "complex",
    fx = "aggressive", movement = "filter_wobble", dynamics = "none",
    waveforms = {"distorted", "noise"}, lfo_rate = "medium"
  }),
  atmosphere_tonal = PakettiMetaSynthBuildProfile({
    name = "Tonal Background Bed", family = "drone",
    description = "Tonal background bed texture",
    envelope = "sustain", filter = "warm", width = "wide", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "none",
    waveforms = {"sine", "triangle"}, lfo_rate = "slow"
  }),
  atmosphere_dissonant = PakettiMetaSynthBuildProfile({
    name = "Dissonant Spectral Field", family = "drone",
    description = "Dissonant spectral field texture",
    envelope = "sustain", filter = "resonant", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "evolving", dynamics = "none",
    waveforms = {"complex"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category E: Leads - Saw Family (10 profiles)
  -- ========================================================================
  lead_saw_mono = PakettiMetaSynthBuildProfile({
    name = "Saw Lead - Mono", family = "lead",
    description = "Mono saw lead",
    envelope = "snappy", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "warm", movement = "vibrato", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  lead_saw_poly = PakettiMetaSynthBuildProfile({
    name = "Saw Lead - Poly", family = "lead",
    description = "Polyphonic saw lead",
    envelope = "medium", filter = "sweep_medium", width = "medium", complexity = "simple",
    fx = "warm", movement = "subtle_vibrato", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  lead_supersaw = PakettiMetaSynthBuildProfile({
    name = "Supersaw Lead - Unison", family = "lead",
    description = "Unison single cycles supersaw lead",
    envelope = "medium", filter = "bright", width = "supersaw", complexity = "medium",
    fx = "spatial", movement = "subtle_vibrato", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  lead_saw_soft = PakettiMetaSynthBuildProfile({
    name = "Soft Saw Lead", family = "lead",
    description = "Soft saw lead",
    envelope = "soft", filter = "warm", width = "medium", complexity = "simple",
    fx = "warm", movement = "vibrato", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  lead_saw_bright = PakettiMetaSynthBuildProfile({
    name = "Bright Saw Lead", family = "lead",
    description = "Bright saw lead",
    envelope = "snappy", filter = "bright", width = "medium", complexity = "simple",
    fx = "clean", movement = "vibrato", dynamics = "full",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  lead_saw_detuned = PakettiMetaSynthBuildProfile({
    name = "Detuned Saw Lead", family = "lead",
    description = "Detuned saw lead",
    envelope = "medium", filter = "sweep_medium", width = "wide", complexity = "medium",
    fx = "movement", movement = "vibrato", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  lead_saw_vintage = PakettiMetaSynthBuildProfile({
    name = "Vintage Analog Saw Lead", family = "lead",
    description = "Vintage analog saw lead",
    envelope = "medium", filter = "sweep_slow", width = "narrow", complexity = "simple",
    fx = "vintage", movement = "vibrato", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  lead_saw_digital = PakettiMetaSynthBuildProfile({
    name = "Digital Saw Lead", family = "lead",
    description = "Digital saw lead",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  lead_trance = PakettiMetaSynthBuildProfile({
    name = "Trance Lead", family = "lead",
    description = "Classic trance lead",
    envelope = "snappy", filter = "sweep_fast", width = "wide", complexity = "medium",
    fx = "spatial_delay", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  lead_edm_festival = PakettiMetaSynthBuildProfile({
    name = "EDM Festival Lead", family = "lead",
    description = "Big EDM festival lead",
    envelope = "tight", filter = "bright", width = "supersaw", complexity = "medium",
    fx = "heavily_saturated", movement = "static", dynamics = "full",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category F: Leads - Square/Pulse Family (8 profiles)
  -- ========================================================================
  lead_square = PakettiMetaSynthBuildProfile({
    name = "Square Lead", family = "lead",
    description = "Classic square lead",
    envelope = "snappy", filter = "sweep_medium", width = "narrow", complexity = "simple",
    fx = "warm", movement = "vibrato", dynamics = "expressive",
    waveforms = {"square"}, lfo_rate = "medium"
  }),
  lead_pulse = PakettiMetaSynthBuildProfile({
    name = "Pulse Lead", family = "lead",
    description = "Pulse wave lead",
    envelope = "snappy", filter = "sweep_medium", width = "narrow", complexity = "simple",
    fx = "warm", movement = "vibrato", dynamics = "expressive",
    waveforms = {"pulse"}, lfo_rate = "medium"
  }),
  lead_pwm = PakettiMetaSynthBuildProfile({
    name = "PWM-Style Illusion Lead", family = "lead",
    description = "Frame-based PWM illusion lead",
    envelope = "medium", filter = "warm", width = "medium", complexity = "complex",
    fx = "movement", movement = "morphing", dynamics = "moderate",
    waveforms = {"pulse", "square"}, lfo_rate = "medium"
  }),
  lead_hollow_square = PakettiMetaSynthBuildProfile({
    name = "Hollow Square Lead", family = "lead",
    description = "Hollow square lead",
    envelope = "medium", filter = "dark", width = "narrow", complexity = "simple",
    fx = "warm", movement = "vibrato", dynamics = "moderate",
    waveforms = {"square"}, lfo_rate = "slow"
  }),
  lead_retro_game = PakettiMetaSynthBuildProfile({
    name = "Retro Game Lead", family = "lead",
    description = "Retro game style lead",
    envelope = "tight", filter = "bright", width = "mono", complexity = "minimal",
    fx = "clean", movement = "vibrato", dynamics = "moderate",
    waveforms = {"square", "chiptune"}, lfo_rate = "fast"
  }),
  lead_chiptune = PakettiMetaSynthBuildProfile({
    name = "Chiptune Lead", family = "lead",
    description = "8-bit chiptune lead",
    envelope = "tight", filter = "full_open", width = "mono", complexity = "minimal",
    fx = "lofi", movement = "vibrato", dynamics = "moderate",
    waveforms = {"chiptune", "square"}, lfo_rate = "fast"
  }),
  lead_analog_square = PakettiMetaSynthBuildProfile({
    name = "Analog Square Lead", family = "lead",
    description = "Analog square lead",
    envelope = "medium", filter = "sweep_slow", width = "narrow", complexity = "simple",
    fx = "vintage", movement = "vibrato", dynamics = "expressive",
    waveforms = {"square"}, lfo_rate = "slow"
  }),
  lead_digital_square = PakettiMetaSynthBuildProfile({
    name = "Digital Square Lead", family = "lead",
    description = "Digital square lead",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"square"}, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category G: Leads - Sine/Triangle Family (6 profiles)
  -- ========================================================================
  lead_sine = PakettiMetaSynthBuildProfile({
    name = "Sine Lead", family = "lead",
    description = "Pure sine lead",
    envelope = "medium", filter = "none", width = "mono", complexity = "minimal",
    fx = "spatial", movement = "vibrato", dynamics = "expressive",
    waveforms = {"sine"}, lfo_rate = "medium"
  }),
  lead_triangle = PakettiMetaSynthBuildProfile({
    name = "Triangle Lead", family = "lead",
    description = "Triangle wave lead",
    envelope = "medium", filter = "none", width = "mono", complexity = "minimal",
    fx = "clean", movement = "vibrato", dynamics = "expressive",
    waveforms = {"triangle"}, lfo_rate = "medium"
  }),
  lead_soft_expressive = PakettiMetaSynthBuildProfile({
    name = "Soft Expressive Lead", family = "lead",
    description = "Soft expressive sine/triangle lead",
    envelope = "soft", filter = "warm", width = "narrow", complexity = "simple",
    fx = "spatial", movement = "vibrato", dynamics = "full",
    waveforms = {"sine", "triangle"}, lfo_rate = "slow"
  }),
  lead_whistle = PakettiMetaSynthBuildProfile({
    name = "Whistle-Style Lead", family = "lead",
    description = "Whistle-style sine lead",
    envelope = "medium", filter = "bright", width = "mono", complexity = "minimal",
    fx = "spatial", movement = "vibrato", dynamics = "expressive",
    waveforms = {"sine"}, lfo_rate = "medium"
  }),
  lead_minimal = PakettiMetaSynthBuildProfile({
    name = "Minimal Lead", family = "lead",
    description = "Minimal sine/triangle lead",
    envelope = "snappy", filter = "none", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"sine", "triangle"}, lfo_rate = "medium"
  }),
  lead_ambient = PakettiMetaSynthBuildProfile({
    name = "Ambient Lead", family = "lead",
    description = "Ambient atmospheric lead",
    envelope = "slow", filter = "warm", width = "medium", complexity = "simple",
    fx = "cinematic", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"sine", "triangle"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category H: Leads - Complex/Aggressive (7 profiles)
  -- ========================================================================
  lead_hybrid = PakettiMetaSynthBuildProfile({
    name = "Hybrid Lead", family = "lead",
    description = "Hybrid multi-waveform lead",
    envelope = "snappy", filter = "sweep_medium", width = "wide", complexity = "complex",
    fx = "saturated", movement = "vibrato", dynamics = "expressive",
    waveforms = {"saw", "square", "complex"}, lfo_rate = "medium"
  }),
  lead_digital_aggressive = PakettiMetaSynthBuildProfile({
    name = "Digital Aggressive Lead", family = "lead",
    description = "Aggressive digital lead",
    envelope = "tight", filter = "aggressive", width = "medium", complexity = "medium",
    fx = "aggressive", movement = "static", dynamics = "full",
    waveforms = {"distorted", "complex"}, lfo_rate = "fast"
  }),
  lead_fm_inspired = PakettiMetaSynthBuildProfile({
    name = "FM-Inspired Lead", family = "lead",
    description = "FM-style single cycle lead",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "medium",
    fx = "clean", movement = "vibrato", dynamics = "full",
    waveforms = {"harmonic", "sine"}, lfo_rate = "medium"
  }),
  lead_acid = PakettiMetaSynthBuildProfile({
    name = "Acid Lead", family = "lead",
    description = "303-style acid lead",
    envelope = "snappy", filter = "acid", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"saw", "square"}, lfo_rate = "fast"
  }),
  lead_distorted = PakettiMetaSynthBuildProfile({
    name = "Distorted Lead", family = "lead",
    description = "Heavily distorted lead",
    envelope = "medium", filter = "aggressive", width = "medium", complexity = "simple",
    fx = "heavily_saturated", movement = "vibrato", dynamics = "full",
    waveforms = {"distorted", "saw"}, lfo_rate = "medium"
  }),
  lead_neuro = PakettiMetaSynthBuildProfile({
    name = "Neuro Lead", family = "lead",
    description = "Neurofunk-style lead",
    envelope = "tight", filter = "aggressive", width = "wide", complexity = "complex",
    fx = "aggressive", movement = "filter_wobble", dynamics = "full",
    waveforms = {"distorted", "complex"}, lfo_rate = "fast"
  }),
  lead_dubstep = PakettiMetaSynthBuildProfile({
    name = "Dubstep Lead", family = "lead",
    description = "Dubstep-style lead",
    envelope = "tight", filter = "resonant", width = "wide", complexity = "medium",
    fx = "aggressive", movement = "filter_wobble", dynamics = "full",
    waveforms = {"saw", "distorted"}, lfo_rate = "medium"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category I: Vocal, Formant & Organic (7 profiles)
  -- ========================================================================
  vocal_pad_vowel = PakettiMetaSynthBuildProfile({
    name = "Vocal Pad - Vowel Cycles", family = "vocal",
    description = "Vowel cycles vocal pad",
    envelope = "slow", filter = "formant", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "morphing_slow", dynamics = "subtle",
    waveforms = {"voice"}, lfo_rate = "slow"
  }),
  vocal_lead_formant = PakettiMetaSynthBuildProfile({
    name = "Vocal Lead - Formant Cycles", family = "vocal",
    description = "Formant cycles vocal lead",
    envelope = "medium", filter = "formant", width = "narrow", complexity = "medium",
    fx = "spatial", movement = "vibrato", dynamics = "expressive",
    waveforms = {"voice"}, lfo_rate = "medium"
  }),
  vocal_choir = PakettiMetaSynthBuildProfile({
    name = "Choir Illusion - Multi-Formant", family = "vocal",
    description = "Multi-formant sets choir illusion",
    envelope = "slow", filter = "formant", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"voice"}, lfo_rate = "slow"
  }),
  vocal_talking = PakettiMetaSynthBuildProfile({
    name = "Talking Synth", family = "vocal",
    description = "Talking synth character",
    envelope = "snappy", filter = "formant", width = "narrow", complexity = "medium",
    fx = "movement", movement = "morphing", dynamics = "expressive",
    waveforms = {"voice"}, lfo_rate = "medium"
  }),
  vocal_breath = PakettiMetaSynthBuildProfile({
    name = "Breath/Air Synth", family = "vocal",
    description = "Breath and air synth",
    envelope = "slow", filter = "dark", width = "wide", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "none",
    waveforms = {"noise", "flute"}, lfo_rate = "slow"
  }),
  vocal_whisper = PakettiMetaSynthBuildProfile({
    name = "Whisper Pad", family = "vocal",
    description = "Whisper pad texture",
    envelope = "very_slow", filter = "muted", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "filter_slow", dynamics = "none",
    waveforms = {"noise", "voice"}, lfo_rate = "slow"
  }),
  vocal_organic = PakettiMetaSynthBuildProfile({
    name = "Organic Motion Texture", family = "vocal",
    description = "Organic motion texture",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"voice", "strings"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category J: Basses - Sub & Clean (7 profiles)
  -- ========================================================================
  bass_sub_sine = PakettiMetaSynthBuildProfile({
    name = "Sub Bass - Sine", family = "bass",
    description = "Pure sine sub bass",
    envelope = "sustain", filter = "muted", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"sine"}, lfo_rate = "slow"
  }),
  bass_sub_triangle = PakettiMetaSynthBuildProfile({
    name = "Sub Bass - Triangle", family = "bass",
    description = "Triangle sub bass",
    envelope = "sustain", filter = "muted", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"triangle"}, lfo_rate = "slow"
  }),
  bass_clean = PakettiMetaSynthBuildProfile({
    name = "Clean Bass - Low Harmonic", family = "bass",
    description = "Low harmonic clean bass",
    envelope = "snappy", filter = "warm", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "moderate",
    waveforms = {"triangle", "sine"}, lfo_rate = "medium"
  }),
  bass_mono = PakettiMetaSynthBuildProfile({
    name = "Mono Bass", family = "bass",
    description = "Classic mono bass",
    envelope = "snappy", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  bass_analog_sub = PakettiMetaSynthBuildProfile({
    name = "Analog Sub", family = "bass",
    description = "Analog-style sub bass",
    envelope = "medium", filter = "dark", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "moderate",
    waveforms = {"sine", "triangle"}, lfo_rate = "slow"
  }),
  bass_digital_sub = PakettiMetaSynthBuildProfile({
    name = "Digital Sub", family = "bass",
    description = "Digital sub bass",
    envelope = "snappy", filter = "muted", width = "mono", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"sine"}, lfo_rate = "medium"
  }),
  bass_808 = PakettiMetaSynthBuildProfile({
    name = "808-Style Bass", family = "bass",
    description = "808-style sine + saturation illusion bass",
    envelope = "punchy", filter = "warm", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"sine"}, pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 }, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category K: Basses - Saw/Square (8 profiles)
  -- ========================================================================
  bass_saw = PakettiMetaSynthBuildProfile({
    name = "Saw Bass", family = "bass",
    description = "Classic saw bass",
    envelope = "snappy", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  bass_square = PakettiMetaSynthBuildProfile({
    name = "Square Bass", family = "bass",
    description = "Classic square bass",
    envelope = "snappy", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"square"}, lfo_rate = "medium"
  }),
  bass_detuned = PakettiMetaSynthBuildProfile({
    name = "Detuned Bass", family = "bass",
    description = "Detuned unison bass",
    envelope = "snappy", filter = "sweep_medium", width = "medium", complexity = "medium",
    fx = "saturated", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  bass_reese = PakettiMetaSynthBuildProfile({
    name = "Reese Bass", family = "bass",
    description = "Classic Reese bass",
    envelope = "medium", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "saturated", movement = "filter_slow", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  bass_acid = PakettiMetaSynthBuildProfile({
    name = "Acid Bass", family = "bass",
    description = "303-style acid bass",
    envelope = "tight", filter = "acid", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"saw", "square"}, lfo_rate = "fast"
  }),
  bass_vintage = PakettiMetaSynthBuildProfile({
    name = "Vintage Bass", family = "bass",
    description = "Vintage analog bass",
    envelope = "snappy", filter = "sweep_slow", width = "mono", complexity = "simple",
    fx = "vintage", movement = "static", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  bass_techno = PakettiMetaSynthBuildProfile({
    name = "Techno Bass", family = "bass",
    description = "Techno-style bass",
    envelope = "tight", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  bass_house = PakettiMetaSynthBuildProfile({
    name = "House Bass", family = "bass",
    description = "House music bass",
    envelope = "snappy", filter = "sweep_medium", width = "narrow", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "moderate",
    waveforms = {"saw", "square"}, lfo_rate = "medium"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category L: Basses - Complex/Modern (9 profiles)
  -- ========================================================================
  bass_wobble = PakettiMetaSynthBuildProfile({
    name = "Wobble Bass", family = "bass",
    description = "LFO wobble bass",
    envelope = "sustain", filter = "resonant", width = "mono", complexity = "simple",
    fx = "saturated", movement = "filter_wobble", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  bass_growl = PakettiMetaSynthBuildProfile({
    name = "Growl Bass", family = "bass",
    description = "Growling bass",
    envelope = "medium", filter = "aggressive", width = "medium", complexity = "complex",
    fx = "aggressive", movement = "filter_wobble", dynamics = "full",
    waveforms = {"distorted", "saw"}, lfo_rate = "medium"
  }),
  bass_fm = PakettiMetaSynthBuildProfile({
    name = "FM Bass", family = "bass",
    description = "FM-style bass",
    envelope = "snappy", filter = "sweep_fast", width = "mono", complexity = "medium",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"harmonic", "sine"}, lfo_rate = "fast"
  }),
  bass_talking = PakettiMetaSynthBuildProfile({
    name = "Talking Bass", family = "bass",
    description = "Formant talking bass",
    envelope = "snappy", filter = "formant", width = "mono", complexity = "medium",
    fx = "movement", movement = "morphing", dynamics = "expressive",
    waveforms = {"voice", "saw"}, lfo_rate = "medium"
  }),
  bass_distorted = PakettiMetaSynthBuildProfile({
    name = "Distorted Bass", family = "bass",
    description = "Heavily distorted bass",
    envelope = "snappy", filter = "aggressive", width = "narrow", complexity = "simple",
    fx = "heavily_saturated", movement = "static", dynamics = "full",
    waveforms = {"distorted", "saw"}, lfo_rate = "medium"
  }),
  bass_neuro = PakettiMetaSynthBuildProfile({
    name = "Neuro Bass", family = "bass",
    description = "Neurofunk bass",
    envelope = "tight", filter = "aggressive", width = "wide", complexity = "complex",
    fx = "aggressive", movement = "filter_wobble", dynamics = "full",
    waveforms = {"distorted", "complex"}, lfo_rate = "fast"
  }),
  bass_dubstep = PakettiMetaSynthBuildProfile({
    name = "Dubstep Bass", family = "bass",
    description = "Dubstep-style bass",
    envelope = "sustain", filter = "resonant", width = "medium", complexity = "medium",
    fx = "aggressive", movement = "filter_wobble", dynamics = "full",
    waveforms = {"saw", "distorted"}, lfo_rate = "medium"
  }),
  bass_trap = PakettiMetaSynthBuildProfile({
    name = "Trap Bass", family = "bass",
    description = "Trap-style 808 bass",
    envelope = "punchy", filter = "warm", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"sine"}, pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.08 }, lfo_rate = "fast"
  }),
  bass_drill = PakettiMetaSynthBuildProfile({
    name = "Drill Bass", family = "bass",
    description = "UK Drill-style bass",
    envelope = "punchy", filter = "dark", width = "mono", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"sine"}, pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.1 }, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category M: Plucks (7 profiles)
  -- ========================================================================
  pluck_soft_gentle = PakettiMetaSynthBuildProfile({
    name = "Soft Pluck", family = "pluck",
    description = "Gentle soft pluck",
    envelope = "snappy", filter = "warm", width = "narrow", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"triangle", "sine"}, lfo_rate = "medium"
  }),
  pluck_hard = PakettiMetaSynthBuildProfile({
    name = "Hard Pluck", family = "pluck",
    description = "Hard attack pluck",
    envelope = "tight", filter = "bright", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"saw", "harmonic"}, lfo_rate = "fast"
  }),
  pluck_digital = PakettiMetaSynthBuildProfile({
    name = "Digital Pluck", family = "pluck",
    description = "Digital character pluck",
    envelope = "tight", filter = "sweep_fast", width = "narrow", complexity = "medium",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"harmonic", "complex"}, lfo_rate = "fast"
  }),
  pluck_analog = PakettiMetaSynthBuildProfile({
    name = "Analog Pluck", family = "pluck",
    description = "Analog-style pluck",
    envelope = "snappy", filter = "sweep_medium", width = "narrow", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"saw"}, lfo_rate = "medium"
  }),
  pluck_fm = PakettiMetaSynthBuildProfile({
    name = "FM Pluck", family = "pluck",
    description = "FM-style pluck",
    envelope = "tight", filter = "bright", width = "mono", complexity = "medium",
    fx = "spatial", movement = "static", dynamics = "full",
    waveforms = {"harmonic", "sine"}, lfo_rate = "fast"
  }),
  pluck_bell = PakettiMetaSynthBuildProfile({
    name = "Bell Pluck", family = "pluck",
    description = "Bell-like pluck",
    envelope = "snappy", filter = "bright", width = "narrow", complexity = "simple",
    fx = "spatial", movement = "static", dynamics = "expressive",
    waveforms = {"sine", "harmonic"}, lfo_rate = "medium"
  }),
  pluck_short_perc = PakettiMetaSynthBuildProfile({
    name = "Short Percussive Pluck", family = "pluck",
    description = "Very short percussive pluck",
    envelope = "ultra_tight", filter = "sweep_fast", width = "mono", complexity = "minimal",
    fx = "clean", movement = "static", dynamics = "full",
    waveforms = {"saw", "triangle"}, lfo_rate = "fast"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category N: Arps & Sequenced (7 profiles)
  -- ========================================================================
  arp_synth = PakettiMetaSynthBuildProfile({
    name = "Synth Arp", family = "arp",
    description = "Classic synth arp",
    envelope = "tight", filter = "sweep_fast", width = "narrow", complexity = "simple",
    fx = "spatial_delay", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  arp_pluck = PakettiMetaSynthBuildProfile({
    name = "Pluck Arp", family = "arp",
    description = "Pluck-style arp",
    envelope = "tight", filter = "bright", width = "narrow", complexity = "simple",
    fx = "spatial_delay", movement = "static", dynamics = "expressive",
    waveforms = {"harmonic", "saw"}, lfo_rate = "fast"
  }),
  arp_poly = PakettiMetaSynthBuildProfile({
    name = "Polyphonic Arp", family = "arp",
    description = "Polyphonic arp sound",
    envelope = "snappy", filter = "sweep_medium", width = "medium", complexity = "medium",
    fx = "spatial_delay", movement = "static", dynamics = "moderate",
    waveforms = {"saw", "square"}, lfo_rate = "fast"
  }),
  arp_mono = PakettiMetaSynthBuildProfile({
    name = "Monophonic Arp", family = "arp",
    description = "Monophonic arp sound",
    envelope = "tight", filter = "sweep_fast", width = "mono", complexity = "simple",
    fx = "spatial_delay", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  arp_rhythmic = PakettiMetaSynthBuildProfile({
    name = "Rhythmic Sequence", family = "arp",
    description = "Rhythmic sequence sound",
    envelope = "ultra_tight", filter = "sweep_fast", width = "narrow", complexity = "simple",
    fx = "clean", movement = "static", dynamics = "moderate",
    waveforms = {"saw", "square"}, lfo_rate = "fast"
  }),
  arp_gated = PakettiMetaSynthBuildProfile({
    name = "Gated Synth", family = "arp",
    description = "Gated synth sequence",
    envelope = "ultra_tight", filter = "bright", width = "medium", complexity = "simple",
    fx = "spatial_delay", movement = "static", dynamics = "moderate",
    waveforms = {"saw"}, lfo_rate = "fast"
  }),
  arp_pulsing = PakettiMetaSynthBuildProfile({
    name = "Pulsing Pad", family = "arp",
    description = "Pulsing pad sequence",
    envelope = "snappy", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "spatial", movement = "tremolo", dynamics = "subtle",
    waveforms = {"saw", "triangle"}, lfo_rate = "medium"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category O: Synth Strings (8 profiles)
  -- ========================================================================
  strings_synth_saw = PakettiMetaSynthBuildProfile({
    name = "Synth Strings - Saw Based", family = "strings",
    description = "Saw-based synth strings",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"saw"}, lfo_rate = "slow"
  }),
  strings_synth_square = PakettiMetaSynthBuildProfile({
    name = "Synth Strings - Square Based", family = "strings",
    description = "Square-based synth strings",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "subtle_vibrato", dynamics = "subtle",
    waveforms = {"square"}, lfo_rate = "slow"
  }),
  strings_synth_mixed = PakettiMetaSynthBuildProfile({
    name = "Synth Strings - Mixed Cycles", family = "strings",
    description = "Mixed basic cycles synth strings",
    envelope = "slow", filter = "sweep_slow", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "vibrato", dynamics = "subtle",
    waveforms = {"saw", "square", "strings"}, lfo_rate = "slow"
  }),
  strings_warm_pad = PakettiMetaSynthBuildProfile({
    name = "Warm String Pad", family = "strings",
    description = "Warm string pad",
    envelope = "slow", filter = "warm", width = "ultra_wide", complexity = "medium",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"strings", "saw"}, lfo_rate = "slow"
  }),
  strings_ensemble = PakettiMetaSynthBuildProfile({
    name = "Ensemble String Illusion", family = "strings",
    description = "Ensemble string illusion",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "vibrato", dynamics = "expressive",
    waveforms = {"strings"}, lfo_rate = "slow"
  }),
  strings_cinematic = PakettiMetaSynthBuildProfile({
    name = "Cinematic String Bed", family = "strings",
    description = "Cinematic string bed",
    envelope = "very_slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"strings"}, reverb_size = "large", lfo_rate = "slow"
  }),
  strings_motion = PakettiMetaSynthBuildProfile({
    name = "Motion Strings", family = "strings",
    description = "Motion strings with movement",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "movement", movement = "full_motion", dynamics = "subtle",
    waveforms = {"strings", "saw"}, lfo_rate = "slow"
  }),
  strings_vintage_machine = PakettiMetaSynthBuildProfile({
    name = "Vintage String Machine", family = "strings",
    description = "Vintage string machine illusion",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "vintage", movement = "vibrato", dynamics = "subtle",
    waveforms = {"saw", "strings"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category P: Synth Brass (7 profiles)
  -- ========================================================================
  brass_synth_saw = PakettiMetaSynthBuildProfile({
    name = "Synth Brass - Saw Based", family = "brass",
    description = "Saw-based synth brass",
    envelope = "medium", filter = "sweep_medium", width = "medium", complexity = "simple",
    fx = "warm", movement = "subtle_vibrato", dynamics = "expressive",
    waveforms = {"saw", "brass"}, lfo_rate = "medium"
  }),
  brass_synth_square = PakettiMetaSynthBuildProfile({
    name = "Synth Brass - Square Based", family = "brass",
    description = "Square-based synth brass",
    envelope = "medium", filter = "sweep_medium", width = "medium", complexity = "simple",
    fx = "warm", movement = "subtle_vibrato", dynamics = "expressive",
    waveforms = {"square", "brass"}, lfo_rate = "medium"
  }),
  brass_soft_pad = PakettiMetaSynthBuildProfile({
    name = "Soft Brass Pad", family = "brass",
    description = "Soft brass pad",
    envelope = "slow", filter = "warm", width = "wide", complexity = "medium",
    fx = "spatial", movement = "subtle_vibrato", dynamics = "moderate",
    waveforms = {"brass", "saw"}, lfo_rate = "slow"
  }),
  brass_stab = PakettiMetaSynthBuildProfile({
    name = "Stab Brass", family = "brass",
    description = "Brass stab",
    envelope = "tight", filter = "sweep_fast", width = "medium", complexity = "simple",
    fx = "saturated", movement = "static", dynamics = "full",
    waveforms = {"saw", "brass"}, lfo_rate = "fast"
  }),
  brass_funk = PakettiMetaSynthBuildProfile({
    name = "Funk Brass", family = "brass",
    description = "Funky brass stab",
    envelope = "snappy", filter = "sweep_medium", width = "medium", complexity = "simple",
    fx = "warm", movement = "static", dynamics = "expressive",
    waveforms = {"saw", "brass"}, lfo_rate = "medium"
  }),
  brass_cinematic = PakettiMetaSynthBuildProfile({
    name = "Cinematic Brass Hits", family = "brass",
    description = "Cinematic brass hits",
    envelope = "medium", filter = "sweep_medium", width = "wide", complexity = "medium",
    fx = "cinematic", movement = "subtle_vibrato", dynamics = "full",
    waveforms = {"brass"}, reverb_size = "medium", lfo_rate = "medium"
  }),
  brass_hybrid = PakettiMetaSynthBuildProfile({
    name = "Hybrid Brass", family = "brass",
    description = "Hybrid synth/brass",
    envelope = "medium", filter = "sweep_medium", width = "wide", complexity = "medium",
    fx = "saturated", movement = "vibrato", dynamics = "expressive",
    waveforms = {"brass", "saw", "square"}, lfo_rate = "medium"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category Q: FX & Sound Design (8 profiles)
  -- ========================================================================
  fx_riser = PakettiMetaSynthBuildProfile({
    name = "Riser", family = "fx",
    description = "Rising tension FX",
    envelope = "reverse", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "none",
    waveforms = {"noise", "saw"}, lfo_rate = "slow"
  }),
  fx_downlifter = PakettiMetaSynthBuildProfile({
    name = "Downlifter", family = "fx",
    description = "Falling tension FX",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "complex",
    fx = "cinematic", movement = "evolving", dynamics = "none",
    waveforms = {"noise", "saw"}, lfo_rate = "slow"
  }),
  fx_impact = PakettiMetaSynthBuildProfile({
    name = "Impact", family = "fx",
    description = "Impact hit FX",
    envelope = "ultra_tight", filter = "resonant", width = "ultra_wide", complexity = "medium",
    fx = "heavily_saturated", movement = "static", dynamics = "full",
    waveforms = {"noise", "sine"}, lfo_rate = "fast"
  }),
  fx_sweep = PakettiMetaSynthBuildProfile({
    name = "Sweep", family = "fx",
    description = "Filter sweep FX",
    envelope = "sustain", filter = "sweep_slow", width = "wide", complexity = "simple",
    fx = "movement", movement = "filter_slow", dynamics = "none",
    waveforms = {"noise", "saw"}, lfo_rate = "slow"
  }),
  fx_whoosh = PakettiMetaSynthBuildProfile({
    name = "Whoosh", family = "fx",
    description = "Whoosh transition FX",
    envelope = "snappy", filter = "sweep_fast", width = "ultra_wide", complexity = "medium",
    fx = "spatial", movement = "static", dynamics = "none",
    waveforms = {"noise"}, lfo_rate = "fast"
  }),
  fx_glitch = PakettiMetaSynthBuildProfile({
    name = "Glitch FX", family = "fx",
    description = "Glitchy digital FX",
    envelope = "ultra_tight", filter = "aggressive", width = "wide", complexity = "complex",
    fx = "lofi", movement = "filter_wobble", dynamics = "full",
    waveforms = {"distorted", "chiptune"}, lfo_rate = "fast"
  }),
  fx_noise = PakettiMetaSynthBuildProfile({
    name = "Noise FX", family = "fx",
    description = "Noise texture FX",
    envelope = "sustain", filter = "sweep_slow", width = "ultra_wide", complexity = "simple",
    fx = "spatial", movement = "filter_slow", dynamics = "none",
    waveforms = {"noise"}, lfo_rate = "slow"
  }),
  fx_tonal = PakettiMetaSynthBuildProfile({
    name = "Tonal FX", family = "fx",
    description = "Tonal texture FX",
    envelope = "slow", filter = "resonant", width = "wide", complexity = "medium",
    fx = "movement", movement = "evolving", dynamics = "none",
    waveforms = {"complex", "harmonic"}, lfo_rate = "slow"
  }),
  
  -- ========================================================================
  -- GENERATED PROFILES - Category R: Meta & Experimental (7 profiles)
  -- ========================================================================
  meta_vector = PakettiMetaSynthBuildProfile({
    name = "Vector Synth Texture", family = "experimental",
    description = "Vector synthesis texture",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "dense",
    fx = "movement", movement = "full_motion", dynamics = "subtle",
    waveforms = {"complex", "harmonic", "saw"}, lfo_rate = "slow"
  }),
  meta_wavetable = PakettiMetaSynthBuildProfile({
    name = "Meta-Wavetable Instrument", family = "experimental",
    description = "Multi-level frame morph instrument",
    envelope = "medium", filter = "sweep_medium", width = "wide", complexity = "dense",
    fx = "spatial", movement = "evolving", dynamics = "moderate",
    waveforms = {"complex"}, lfo_rate = "medium"
  }),
  meta_frame_morph = PakettiMetaSynthBuildProfile({
    name = "Multi-Level Frame Morph", family = "experimental",
    description = "Multi-level frame morphing instrument",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "full_motion", dynamics = "subtle",
    waveforms = {"complex", "harmonic"}, lfo_rate = "slow"
  }),
  meta_frame_of_frames = PakettiMetaSynthBuildProfile({
    name = "Frame-of-Frames Instrument", family = "experimental",
    description = "Nested frame architecture instrument",
    envelope = "slow", filter = "sweep_slow", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "evolving", dynamics = "subtle",
    waveforms = {"complex"}, lfo_rate = "slow"
  }),
  meta_self_modulating = PakettiMetaSynthBuildProfile({
    name = "Self-Modulating Spectral", family = "experimental",
    description = "Self-modulating spectral system",
    envelope = "sustain", filter = "resonant", width = "ultra_wide", complexity = "dense",
    fx = "movement", movement = "full_motion", dynamics = "none",
    waveforms = {"complex", "harmonic"}, lfo_rate = "medium"
  }),
  meta_genre_cross = PakettiMetaSynthBuildProfile({
    name = "Genre-Cross Hybrid", family = "experimental",
    description = "Genre-crossing hybrid instrument",
    envelope = "medium", filter = "sweep_medium", width = "wide", complexity = "complex",
    fx = "saturated", movement = "morphing", dynamics = "expressive",
    waveforms = {"saw", "complex", "strings"}, lfo_rate = "medium"
  }),
  meta_impossible = PakettiMetaSynthBuildProfile({
    name = "Impossible Instrument", family = "experimental",
    description = "MetaSynth-only impossible instrument",
    envelope = "reverse", filter = "formant", width = "ultra_wide", complexity = "dense",
    fx = "cinematic", movement = "full_motion", dynamics = "expressive",
    waveforms = {"complex", "voice", "noise"}, lfo_rate = "slow"
  }),
}

-- ============================================================================
-- BACKWARD COMPATIBILITY: Map old modulation profile access to new structure
-- This allows existing code to access modulation data from the new structure
-- ============================================================================
PakettiMetaSynthModulationProfiles = setmetatable({}, {
  __index = function(t, key)
    local profile = PakettiMetaSynthProfiles[key]
    if profile and profile.modulation then
      return profile.modulation
    end
    return nil
  end
})

-- Note: The old flat modulation profile structure has been migrated to the new
-- multi-layer PakettiMetaSynthProfiles structure above. The modulation data is
-- now accessed via profile.modulation (separate layer). The PakettiMetaSynthModulationProfiles
-- metatable provides backward compatibility for existing code.

-- Legacy reference table (not used, preserved for documentation)
PakettiMetaSynthOldModulationProfiles_DEPRECATED = {
  -- ========================================================================
  -- NEUTRAL family - Raw/experimental starting points
  -- ========================================================================
  neutral_flat = {
    name = "Neutral (Flat)",
    description = "Raw oscillator, flat sustain, sound design starting point",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.1 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.2,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  neutral_none = {
    name = "Neutral (No Envelope)",
    description = "Bypass envelope, raw oscillator behavior",
    volume_ahdsr = nil,
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.0,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  
  -- ========================================================================
  -- BASS family - Solid low-end sounds
  -- ========================================================================
  bass_tight = {
    name = "Bass (Tight)",
    description = "Mono basses, acid-style, precise low-end",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.7, release = 0.1 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.4, release = 0.1 },
    pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.03, sustain = 0.0, release = 0.02, amount = -0.03 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.5,
    filter_keytrack = 0.4,
    filter_cutoff = 0.45,
    filter_resonance = 0.35
  },
  bass_sustain = {
    name = "Bass (Sustain)",
    description = "Sub bass, held notes, minimal articulation",
    volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.05, sustain = 1.0, release = 0.2 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.0,
    filter_keytrack = 0.6,
    filter_cutoff = 0.3,
    filter_resonance = 0.1
  },
  bass_filter = {
    name = "Bass (Filter-Driven)",
    description = "Acid bass, aggressive filter envelope, resonance sweep",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.85, release = 0.12 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.35, sustain = 0.25, release = 0.15 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.7,
    filter_keytrack = 0.5,
    filter_cutoff = 0.55,
    filter_resonance = 0.55
  },
  bass_wide = {
    name = "Bass (Wide/Slow)",
    description = "Reese bass, slow movement, wide stereo",
    volume_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.2, sustain = 0.9, release = 0.25 },
    filter_ahdsr = { attack = 0.3, hold = 0.0, decay = 0.5, sustain = 0.5, release = 0.3 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = { frequency = 0.3, amount = 0.15 },
    velocity_volume = 0.4,
    velocity_filter = 0.3,
    filter_keytrack = 0.3,
    filter_cutoff = 0.5,
    filter_resonance = 0.25
  },
  bass_dynamic = {
    name = "Bass (Dynamic)",
    description = "FM bass, velocity-sensitive, punchy",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.12, sustain = 0.75, release = 0.1 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.5, release = 0.1 },
    pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.02, sustain = 0.0, release = 0.01, amount = -0.05 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.8,
    velocity_filter = 0.6,
    filter_keytrack = 0.4,
    filter_cutoff = 0.6,
    filter_resonance = 0.3
  },
  
  -- ========================================================================
  -- PLUCK family - Short, percussive attacks
  -- ========================================================================
  pluck_short = {
    name = "Pluck (Short)",
    description = "Plucks, mallets, short hits",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.08 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.15, release = 0.08 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.8,
    velocity_filter = 0.6,
    filter_keytrack = 0.3,
    filter_cutoff = 0.7,
    filter_resonance = 0.25
  },
  pluck_natural = {
    name = "Pluck (Natural)",
    description = "Harp/guitar, slightly longer decay, natural release",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.0, release = 0.2 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.5, sustain = 0.2, release = 0.25 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.7,
    velocity_filter = 0.5,
    filter_keytrack = 0.4,
    filter_cutoff = 0.65,
    filter_resonance = 0.2
  },
  pluck_percussive = {
    name = "Pluck (Percussive)",
    description = "Very fast, mallet-like",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
    pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.02, sustain = 0.0, release = 0.01, amount = -0.08 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.9,
    velocity_filter = 0.7,
    filter_keytrack = 0.2,
    filter_cutoff = 0.8,
    filter_resonance = 0.15
  },
  pluck_soft = {
    name = "Pluck (Soft)",
    description = "Kalimba, gentler attack, softer filter",
    volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.5, sustain = 0.0, release = 0.3 },
    filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.6, sustain = 0.25, release = 0.35 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.4,
    filter_keytrack = 0.5,
    filter_cutoff = 0.5,
    filter_resonance = 0.15
  },
  
  -- ========================================================================
  -- LEAD family - Expressive, melodic sounds
  -- ========================================================================
  lead_expressive = {
    name = "Lead (Expressive)",
    description = "Classic synth leads, melodic expression, vibrato",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.7, release = 0.2 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.35, sustain = 0.5, release = 0.2 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.025 },
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.5,
    filter_keytrack = 0.3,
    filter_cutoff = 0.65,
    filter_resonance = 0.3
  },
  lead_smooth = {
    name = "Lead (Smooth)",
    description = "Poly leads, longer attack/release",
    volume_ahdsr = { attack = 0.03, hold = 0.0, decay = 0.25, sustain = 0.75, release = 0.3 },
    filter_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.3, sustain = 0.6, release = 0.25 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 4.5, amount = 0.02 },
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.4,
    filter_keytrack = 0.35,
    filter_cutoff = 0.6,
    filter_resonance = 0.25
  },
  lead_classic = {
    name = "Lead (Classic)",
    description = "Square-wave style, moderate envelopes",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.8, release = 0.15 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.25, sustain = 0.55, release = 0.15 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.5, amount = 0.02 },
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.4,
    filter_keytrack = 0.3,
    filter_cutoff = 0.7,
    filter_resonance = 0.35
  },
  lead_wide = {
    name = "Lead (Wide)",
    description = "Supersaw-optimized, slow filter, unison-heavy",
    volume_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.2, sustain = 0.85, release = 0.35 },
    filter_ahdsr = { attack = 0.1, hold = 0.0, decay = 0.4, sustain = 0.6, release = 0.3 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = { frequency = 0.15, amount = 0.1 },
    velocity_volume = 0.4,
    velocity_filter = 0.3,
    filter_keytrack = 0.25,
    filter_cutoff = 0.55,
    filter_resonance = 0.2
  },
  lead_glide = {
    name = "Lead (Glide)",
    description = "Portamento-friendly, legato-style",
    volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.15, sustain = 0.9, release = 0.2 },
    filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.2, sustain = 0.65, release = 0.15 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.015 },
    filter_lfo = nil,
    velocity_volume = 0.4,
    velocity_filter = 0.35,
    filter_keytrack = 0.4,
    filter_cutoff = 0.6,
    filter_resonance = 0.3
  },
  
  -- ========================================================================
  -- PAD family - Slow, evolving sounds
  -- ========================================================================
  pad_slow = {
    name = "Pad (Slow)",
    description = "Atmospheric pads, ambient layers",
    volume_ahdsr = { attack = 0.8, hold = 0.0, decay = 0.5, sustain = 0.75, release = 1.5 },
    filter_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.4, sustain = 0.6, release = 1.2 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.2,
    filter_keytrack = 0.2,
    filter_cutoff = 0.55,
    filter_resonance = 0.15
  },
  pad_evolving = {
    name = "Pad (Evolving)",
    description = "Long-form soundscapes, LFO-based filter movement",
    volume_ahdsr = { attack = 0.6, hold = 0.0, decay = 0.4, sustain = 0.8, release = 1.8 },
    filter_ahdsr = { attack = 0.8, hold = 0.0, decay = 0.5, sustain = 0.55, release = 1.5 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = { frequency = 0.15, amount = 0.2 },
    velocity_volume = 0.25,
    velocity_filter = 0.15,
    filter_keytrack = 0.25,
    filter_cutoff = 0.5,
    filter_resonance = 0.2
  },
  pad_ensemble = {
    name = "Pad (Ensemble)",
    description = "String pad, gentle vibrato",
    volume_ahdsr = { attack = 0.5, hold = 0.0, decay = 0.3, sustain = 0.85, release = 1.0 },
    filter_ahdsr = { attack = 0.6, hold = 0.0, decay = 0.35, sustain = 0.6, release = 0.8 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 4.5, amount = 0.015 },
    filter_lfo = nil,
    velocity_volume = 0.35,
    velocity_filter = 0.25,
    filter_keytrack = 0.3,
    filter_cutoff = 0.6,
    filter_resonance = 0.15
  },
  pad_formant = {
    name = "Pad (Formant-Friendly)",
    description = "Choir/vocal pad, minimal filter for formant clarity",
    volume_ahdsr = { attack = 0.7, hold = 0.0, decay = 0.4, sustain = 0.8, release = 1.3 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.01 },
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  
  -- ========================================================================
  -- KEYS family - Piano/organ/EP sounds
  -- ========================================================================
  keys_dynamic = {
    name = "Keys (Dynamic)",
    description = "EPs, synth keys, performance-oriented",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.35, sustain = 0.6, release = 0.25 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.45, release = 0.25 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.75,
    velocity_filter = 0.6,
    filter_keytrack = 0.4,
    filter_cutoff = 0.7,
    filter_resonance = 0.2
  },
  keys_sustain = {
    name = "Keys (Sustain)",
    description = "Organ-like, flat sustain, quick release",
    volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.06 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  keys_velocity = {
    name = "Keys (Velocity-Shaped)",
    description = "Piano-like, heavy velocity shaping",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.5, sustain = 0.5, release = 0.35 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.6, sustain = 0.35, release = 0.3 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.9,
    velocity_filter = 0.75,
    filter_keytrack = 0.5,
    filter_cutoff = 0.65,
    filter_resonance = 0.15
  },
  
  -- ========================================================================
  -- ARP family - Gated, rhythmic sounds
  -- ========================================================================
  arp_tight = {
    name = "Arp (Tight)",
    description = "Very fast attack, short decay, zero sustain",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.06, sustain = 0.0, release = 0.03 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.03 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.4,
    filter_keytrack = 0.3,
    filter_cutoff = 0.75,
    filter_resonance = 0.2
  },
  arp_gated = {
    name = "Arp (Gated)",
    description = "Similar to tight but with slight hold",
    volume_ahdsr = { attack = 0.0, hold = 0.02, decay = 0.08, sustain = 0.0, release = 0.04 },
    filter_ahdsr = { attack = 0.0, hold = 0.01, decay = 0.1, sustain = 0.1, release = 0.04 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.4,
    velocity_filter = 0.35,
    filter_keytrack = 0.25,
    filter_cutoff = 0.7,
    filter_resonance = 0.25
  },
  arp_rhythmic = {
    name = "Arp (Rhythmic)",
    description = "One-note sequence optimized, tracker-friendly",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.12, sustain = 0.15, release = 0.05 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.5,
    filter_keytrack = 0.35,
    filter_cutoff = 0.65,
    filter_resonance = 0.3
  },
  
  -- ========================================================================
  -- FX family - Special effects
  -- ========================================================================
  fx_envelope = {
    name = "FX (Envelope-Driven)",
    description = "Risers, transitions, long ramps",
    volume_ahdsr = { attack = 2.0, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.5 },
    filter_ahdsr = { attack = 2.5, hold = 0.0, decay = 0.0, sustain = 0.85, release = 0.4 },
    pitch_ahdsr = { attack = 2.0, hold = 0.0, decay = 0.0, sustain = 0.6, release = 0.3, amount = 0.15 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.2,
    velocity_filter = 0.15,
    filter_keytrack = 0.1,
    filter_cutoff = 0.25,
    filter_resonance = 0.4
  },
  fx_percussive = {
    name = "FX (Percussive)",
    description = "Impacts, fast transient",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.0, release = 0.4 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.25, sustain = 0.0, release = 0.3 },
    pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.15, sustain = 0.0, release = 0.1, amount = -0.25 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.7,
    velocity_filter = 0.5,
    filter_keytrack = 0.15,
    filter_cutoff = 0.8,
    filter_resonance = 0.25
  },
  fx_sustain = {
    name = "FX (Sustain)",
    description = "Drones, flat envelope",
    volume_ahdsr = { attack = 0.3, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.8 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = { frequency = 0.1, amount = 0.15 },
    velocity_volume = 0.15,
    velocity_filter = 0.1,
    filter_keytrack = 0.0,
    filter_cutoff = 0.5,
    filter_resonance = 0.2
  },
  
  -- ========================================================================
  -- ORCHESTRAL family - Strings, brass, etc.
  -- ========================================================================
  strings = {
    name = "Strings",
    description = "Orchestral strings",
    volume_ahdsr = { attack = 0.4, hold = 0.0, decay = 0.3, sustain = 0.85, release = 0.6 },
    filter_ahdsr = { attack = 0.5, hold = 0.0, decay = 0.2, sustain = 0.6, release = 0.5 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.02 },
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.35,
    filter_keytrack = 0.3,
    filter_cutoff = 0.65,
    filter_resonance = 0.15
  },
  brass = {
    name = "Brass",
    description = "Bold attack, bold brass",
    volume_ahdsr = { attack = 0.08, hold = 0.0, decay = 0.2, sustain = 0.75, release = 0.2 },
    filter_ahdsr = { attack = 0.05, hold = 0.0, decay = 0.3, sustain = 0.5, release = 0.15 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.015 },
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.5,
    filter_keytrack = 0.35,
    filter_cutoff = 0.7,
    filter_resonance = 0.3
  },
  
  -- ========================================================================
  -- BELL family - Long decay sounds
  -- ========================================================================
  bell = {
    name = "Bell",
    description = "Long decay, bell-like",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 1.5, sustain = 0.0, release = 2.0 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.8, sustain = 0.2, release = 1.5 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.4,
    filter_keytrack = 0.4,
    filter_cutoff = 0.85,
    filter_resonance = 0.15
  },
  
  -- ========================================================================
  -- LEGACY profiles (kept for backward compatibility)
  -- ========================================================================
  default = {
    name = "Default",
    description = "Generic starting point",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.5, sustain = 0.8, release = 0.3 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  pluck = {
    name = "Pluck",
    description = "Short, percussive (legacy)",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.0, release = 0.1 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.2, release = 0.1 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.7,
    velocity_filter = 0.5,
    filter_keytrack = 0.3,
    filter_cutoff = 0.7,
    filter_resonance = 0.3
  },
  bass = {
    name = "Bass",
    description = "Solid low end (legacy)",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.9, release = 0.15 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.2, sustain = 0.5, release = 0.1 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.5,
    velocity_filter = 0.4,
    filter_keytrack = 0.4,
    filter_cutoff = 0.5,
    filter_resonance = 0.35
  },
  pad = {
    name = "Pad",
    description = "Slow, evolving (legacy)",
    volume_ahdsr = { attack = 0.8, hold = 0.0, decay = 0.5, sustain = 0.7, release = 1.5 },
    filter_ahdsr = { attack = 1.0, hold = 0.0, decay = 0.3, sustain = 0.6, release = 1.0 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.2,
    filter_keytrack = 0.2,
    filter_cutoff = 0.6,
    filter_resonance = 0.2
  },
  lead = {
    name = "Lead",
    description = "Expressive lead (legacy)",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.3, sustain = 0.7, release = 0.2 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.5, release = 0.2 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = { frequency = 5.0, amount = 0.03 },
    filter_lfo = nil,
    velocity_volume = 0.6,
    velocity_filter = 0.5,
    filter_keytrack = 0.3,
    filter_cutoff = 0.65,
    filter_resonance = 0.3
  },
  organ = {
    name = "Organ",
    description = "Flat sustain (legacy)",
    volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.0, sustain = 1.0, release = 0.05 },
    filter_ahdsr = nil,
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.3,
    velocity_filter = 0.0,
    filter_keytrack = 0.0,
    filter_cutoff = nil,
    filter_resonance = nil
  },
  keys = {
    name = "Keys",
    description = "Piano-like (legacy)",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.4, sustain = 0.6, release = 0.3 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.5, sustain = 0.4, release = 0.25 },
    pitch_ahdsr = nil,
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.7,
    velocity_filter = 0.5,
    filter_keytrack = 0.4,
    filter_cutoff = 0.75,
    filter_resonance = 0.2
  },
  percussive = {
    name = "Percussive",
    description = "Drum-like (legacy)",
    volume_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.08, sustain = 0.0, release = 0.05 },
    filter_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.1, sustain = 0.0, release = 0.05 },
    pitch_ahdsr = { attack = 0.0, hold = 0.0, decay = 0.05, sustain = 0.0, release = 0.02, amount = -0.15 },
    volume_lfo = nil,
    pitch_lfo = nil,
    filter_lfo = nil,
    velocity_volume = 0.8,
    velocity_filter = 0.6,
    filter_keytrack = 0.2,
    filter_cutoff = 0.8,
    filter_resonance = 0.2
  }
}

-- ============================================================================
-- SOUND CATEGORIES - High-level category to profile mapping
-- Users select a Sound Category, which maps to an appropriate Modulation Profile
-- ============================================================================

PakettiMetaSynthSoundCategories = {
  -- ========================================================================
  -- A. KEYS & PIANO (25 categories)
  -- ========================================================================
  { name = "Acoustic Piano - Spectral (Sine)", profile = "keys_piano_spectral_sine", family = "keys" },
  { name = "Acoustic Piano - Spectral (Additive)", profile = "keys_piano_spectral_additive", family = "keys" },
  { name = "Acoustic Piano - Bright/Pop", profile = "keys_piano_bright", family = "keys" },
  { name = "Acoustic Piano - Soft/Felt", profile = "keys_piano_soft", family = "keys" },
  { name = "Acoustic Piano - Lo-Fi", profile = "keys_piano_lofi", family = "keys" },
  { name = "Acoustic Piano - Cinematic", profile = "keys_piano_cinematic", family = "keys" },
  { name = "Acoustic Piano - Prepared", profile = "keys_piano_prepared", family = "keys" },
  { name = "Upright Piano", profile = "keys_upright", family = "keys" },
  { name = "Toy Piano", profile = "keys_toy_piano", family = "keys" },
  { name = "Hybrid Piano-Synth", profile = "keys_hybrid_synth", family = "keys" },
  { name = "Electric Piano - Sine Core", profile = "keys_ep_sine", family = "keys" },
  { name = "Electric Piano - FM", profile = "keys_ep_fm", family = "keys" },
  { name = "Electric Piano - Bell", profile = "keys_ep_bell", family = "keys" },
  { name = "Electric Piano - DX Digital", profile = "keys_ep_digital", family = "keys" },
  { name = "Electric Piano - Warm Analog", profile = "keys_ep_warm", family = "keys" },
  { name = "Analog Keys - Saw", profile = "keys_analog_saw", family = "keys" },
  { name = "Analog Keys - Square", profile = "keys_analog_square", family = "keys" },
  { name = "Analog Keys - Triangle", profile = "keys_analog_triangle", family = "keys" },
  { name = "Analog Keys - Mixed", profile = "keys_analog_mixed", family = "keys" },
  { name = "Vintage Synth Keys", profile = "keys_vintage_synth", family = "keys" },
  { name = "Digital Keys - Complex", profile = "keys_digital_complex", family = "keys" },
  { name = "Soft Keys", profile = "keys_soft", family = "keys" },
  { name = "Hard/Percussive Keys", profile = "keys_hard_percussive", family = "keys" },
  { name = "Plucked Keys", profile = "keys_plucked", family = "keys" },
  { name = "Key-Pad Hybrid", profile = "keys_pad_hybrid", family = "keys" },
  
  -- ========================================================================
  -- B. MALLETS, BELLS & STRUCK TONES (14 categories)
  -- ========================================================================
  { name = "Mallets - Sine", profile = "mallet_sine", family = "bell" },
  { name = "Mallets - Triangle", profile = "mallet_triangle", family = "bell" },
  { name = "Mallets - Inharmonic", profile = "mallet_inharmonic", family = "bell" },
  { name = "Mallets - FM", profile = "mallet_fm", family = "bell" },
  { name = "Wooden Mallet", profile = "mallet_wooden", family = "bell" },
  { name = "Metallic Mallet", profile = "mallet_metallic", family = "bell" },
  { name = "Bells - Pure Sine", profile = "bell_pure_sine", family = "bell" },
  { name = "Bells - Inharmonic", profile = "bell_inharmonic", family = "bell" },
  { name = "Bells - Glassy", profile = "bell_glassy", family = "bell" },
  { name = "Bells - Digital/FM", profile = "bell_digital_fm", family = "bell" },
  { name = "Bells - Gamelan", profile = "bell_gamelan", family = "bell" },
  { name = "Bells - Cinematic", profile = "bell_cinematic", family = "bell" },
  { name = "Music Box", profile = "music_box", family = "bell" },
  { name = "Toy/Clockwork", profile = "toy_clockwork", family = "bell" },
  
  -- ========================================================================
  -- C. PADS (17 categories)
  -- ========================================================================
  { name = "Analog Pad - Saw", profile = "pad_analog_saw", family = "pad" },
  { name = "Analog Pad - Square", profile = "pad_analog_square", family = "pad" },
  { name = "Analog Pad - Triangle", profile = "pad_analog_triangle", family = "pad" },
  { name = "Analog Pad - Mixed", profile = "pad_analog_mixed", family = "pad" },
  { name = "Warm Pad", profile = "pad_warm", family = "pad" },
  { name = "Dark Pad", profile = "pad_dark", family = "pad" },
  { name = "Bright Pad", profile = "pad_bright", family = "pad" },
  { name = "Digital Pad", profile = "pad_digital", family = "pad" },
  { name = "Motion Pad", profile = "pad_motion", family = "pad" },
  { name = "Evolving Pad - Multi-Frame", profile = "pad_evolving_multi", family = "pad" },
  { name = "Static Pad", profile = "pad_static", family = "pad" },
  { name = "Ambient Pad", profile = "pad_ambient", family = "pad" },
  { name = "Cinematic Pad", profile = "pad_cinematic", family = "pad" },
  { name = "Air Pad", profile = "pad_air", family = "pad" },
  { name = "Choir-Like Pad", profile = "pad_choir", family = "pad" },
  { name = "Detuned Pad", profile = "pad_detuned", family = "pad" },
  { name = "Wide Stereo Pad", profile = "pad_wide_stereo", family = "pad" },
  
  -- ========================================================================
  -- D. DRONES & ATMOSPHERES (10 categories)
  -- ========================================================================
  { name = "Static Harmonic Drone", profile = "drone_static_harmonic", family = "drone" },
  { name = "Evolving Drone", profile = "drone_evolving", family = "drone" },
  { name = "Noise Drone", profile = "drone_noise", family = "drone" },
  { name = "Sub Drone", profile = "drone_sub", family = "drone" },
  { name = "Cinematic Atmosphere", profile = "atmosphere_cinematic", family = "drone" },
  { name = "Sci-Fi Atmosphere", profile = "atmosphere_scifi", family = "drone" },
  { name = "Dark Ambient Bed", profile = "atmosphere_dark_ambient", family = "drone" },
  { name = "Industrial Bed", profile = "atmosphere_industrial", family = "drone" },
  { name = "Tonal Background", profile = "atmosphere_tonal", family = "drone" },
  { name = "Dissonant Field", profile = "atmosphere_dissonant", family = "drone" },
  
  -- ========================================================================
  -- E. LEADS - SAW FAMILY (10 categories)
  -- ========================================================================
  { name = "Saw Lead - Mono", profile = "lead_saw_mono", family = "lead" },
  { name = "Saw Lead - Poly", profile = "lead_saw_poly", family = "lead" },
  { name = "Supersaw Lead", profile = "lead_supersaw", family = "lead" },
  { name = "Soft Saw Lead", profile = "lead_saw_soft", family = "lead" },
  { name = "Bright Saw Lead", profile = "lead_saw_bright", family = "lead" },
  { name = "Detuned Saw Lead", profile = "lead_saw_detuned", family = "lead" },
  { name = "Vintage Saw Lead", profile = "lead_saw_vintage", family = "lead" },
  { name = "Digital Saw Lead", profile = "lead_saw_digital", family = "lead" },
  { name = "Trance Lead", profile = "lead_trance", family = "lead" },
  { name = "EDM Festival Lead", profile = "lead_edm_festival", family = "lead" },
  
  -- ========================================================================
  -- F. LEADS - SQUARE/PULSE FAMILY (8 categories)
  -- ========================================================================
  { name = "Square Lead", profile = "lead_square", family = "lead" },
  { name = "Pulse Lead", profile = "lead_pulse", family = "lead" },
  { name = "PWM Lead", profile = "lead_pwm", family = "lead" },
  { name = "Hollow Square Lead", profile = "lead_hollow_square", family = "lead" },
  { name = "Retro Game Lead", profile = "lead_retro_game", family = "lead" },
  { name = "Chiptune Lead", profile = "lead_chiptune", family = "lead" },
  { name = "Analog Square Lead", profile = "lead_analog_square", family = "lead" },
  { name = "Digital Square Lead", profile = "lead_digital_square", family = "lead" },
  
  -- ========================================================================
  -- G. LEADS - SINE/TRIANGLE FAMILY (6 categories)
  -- ========================================================================
  { name = "Sine Lead", profile = "lead_sine", family = "lead" },
  { name = "Triangle Lead", profile = "lead_triangle", family = "lead" },
  { name = "Soft Expressive Lead", profile = "lead_soft_expressive", family = "lead" },
  { name = "Whistle Lead", profile = "lead_whistle", family = "lead" },
  { name = "Minimal Lead", profile = "lead_minimal", family = "lead" },
  { name = "Ambient Lead", profile = "lead_ambient", family = "lead" },
  
  -- ========================================================================
  -- H. LEADS - COMPLEX/AGGRESSIVE (7 categories)
  -- ========================================================================
  { name = "Hybrid Lead", profile = "lead_hybrid", family = "lead" },
  { name = "Digital Aggressive Lead", profile = "lead_digital_aggressive", family = "lead" },
  { name = "FM Lead", profile = "lead_fm_inspired", family = "lead" },
  { name = "Acid Lead", profile = "lead_acid", family = "lead" },
  { name = "Distorted Lead", profile = "lead_distorted", family = "lead" },
  { name = "Neuro Lead", profile = "lead_neuro", family = "lead" },
  { name = "Dubstep Lead", profile = "lead_dubstep", family = "lead" },
  
  -- ========================================================================
  -- I. VOCAL, FORMANT & ORGANIC (7 categories)
  -- ========================================================================
  { name = "Vocal Pad - Vowel", profile = "vocal_pad_vowel", family = "vocal" },
  { name = "Vocal Lead - Formant", profile = "vocal_lead_formant", family = "vocal" },
  { name = "Choir Illusion", profile = "vocal_choir", family = "vocal" },
  { name = "Talking Synth", profile = "vocal_talking", family = "vocal" },
  { name = "Breath/Air Synth", profile = "vocal_breath", family = "vocal" },
  { name = "Whisper Pad", profile = "vocal_whisper", family = "vocal" },
  { name = "Organic Motion", profile = "vocal_organic", family = "vocal" },
  
  -- ========================================================================
  -- J. BASSES - SUB & CLEAN (7 categories)
  -- ========================================================================
  { name = "Sub Bass - Sine", profile = "bass_sub_sine", family = "bass" },
  { name = "Sub Bass - Triangle", profile = "bass_sub_triangle", family = "bass" },
  { name = "Clean Bass", profile = "bass_clean", family = "bass" },
  { name = "Mono Bass", profile = "bass_mono", family = "bass" },
  { name = "Analog Sub", profile = "bass_analog_sub", family = "bass" },
  { name = "Digital Sub", profile = "bass_digital_sub", family = "bass" },
  { name = "808 Bass", profile = "bass_808", family = "bass" },
  
  -- ========================================================================
  -- K. BASSES - SAW/SQUARE (8 categories)
  -- ========================================================================
  { name = "Saw Bass", profile = "bass_saw", family = "bass" },
  { name = "Square Bass", profile = "bass_square", family = "bass" },
  { name = "Detuned Bass", profile = "bass_detuned", family = "bass" },
  { name = "Reese Bass", profile = "bass_reese", family = "bass" },
  { name = "Acid Bass", profile = "bass_acid", family = "bass" },
  { name = "Vintage Bass", profile = "bass_vintage", family = "bass" },
  { name = "Techno Bass", profile = "bass_techno", family = "bass" },
  { name = "House Bass", profile = "bass_house", family = "bass" },
  
  -- ========================================================================
  -- L. BASSES - COMPLEX/MODERN (9 categories)
  -- ========================================================================
  { name = "Wobble Bass", profile = "bass_wobble", family = "bass" },
  { name = "Growl Bass", profile = "bass_growl", family = "bass" },
  { name = "FM Bass", profile = "bass_fm", family = "bass" },
  { name = "Talking Bass", profile = "bass_talking", family = "bass" },
  { name = "Distorted Bass", profile = "bass_distorted", family = "bass" },
  { name = "Neuro Bass", profile = "bass_neuro", family = "bass" },
  { name = "Dubstep Bass", profile = "bass_dubstep", family = "bass" },
  { name = "Trap Bass", profile = "bass_trap", family = "bass" },
  { name = "Drill Bass", profile = "bass_drill", family = "bass" },
  
  -- ========================================================================
  -- M. PLUCKS (7 categories)
  -- ========================================================================
  { name = "Soft Pluck", profile = "pluck_soft_gentle", family = "pluck" },
  { name = "Hard Pluck", profile = "pluck_hard", family = "pluck" },
  { name = "Digital Pluck", profile = "pluck_digital", family = "pluck" },
  { name = "Analog Pluck", profile = "pluck_analog", family = "pluck" },
  { name = "FM Pluck", profile = "pluck_fm", family = "pluck" },
  { name = "Bell Pluck", profile = "pluck_bell", family = "pluck" },
  { name = "Short Percussive Pluck", profile = "pluck_short_perc", family = "pluck" },
  
  -- ========================================================================
  -- N. ARPS & SEQUENCED (7 categories)
  -- ========================================================================
  { name = "Synth Arp", profile = "arp_synth", family = "arp" },
  { name = "Pluck Arp", profile = "arp_pluck", family = "arp" },
  { name = "Polyphonic Arp", profile = "arp_poly", family = "arp" },
  { name = "Monophonic Arp", profile = "arp_mono", family = "arp" },
  { name = "Rhythmic Sequence", profile = "arp_rhythmic", family = "arp" },
  { name = "Gated Synth", profile = "arp_gated", family = "arp" },
  { name = "Pulsing Pad", profile = "arp_pulsing", family = "arp" },
  
  -- ========================================================================
  -- O. SYNTH STRINGS (8 categories)
  -- ========================================================================
  { name = "Synth Strings - Saw", profile = "strings_synth_saw", family = "strings" },
  { name = "Synth Strings - Square", profile = "strings_synth_square", family = "strings" },
  { name = "Synth Strings - Mixed", profile = "strings_synth_mixed", family = "strings" },
  { name = "Warm String Pad", profile = "strings_warm_pad", family = "strings" },
  { name = "Ensemble Strings", profile = "strings_ensemble", family = "strings" },
  { name = "Cinematic Strings", profile = "strings_cinematic", family = "strings" },
  { name = "Motion Strings", profile = "strings_motion", family = "strings" },
  { name = "Vintage String Machine", profile = "strings_vintage_machine", family = "strings" },
  
  -- ========================================================================
  -- P. SYNTH BRASS (7 categories)
  -- ========================================================================
  { name = "Synth Brass - Saw", profile = "brass_synth_saw", family = "brass" },
  { name = "Synth Brass - Square", profile = "brass_synth_square", family = "brass" },
  { name = "Soft Brass Pad", profile = "brass_soft_pad", family = "brass" },
  { name = "Stab Brass", profile = "brass_stab", family = "brass" },
  { name = "Funk Brass", profile = "brass_funk", family = "brass" },
  { name = "Cinematic Brass", profile = "brass_cinematic", family = "brass" },
  { name = "Hybrid Brass", profile = "brass_hybrid", family = "brass" },
  
  -- ========================================================================
  -- Q. FX & SOUND DESIGN (8 categories)
  -- ========================================================================
  { name = "Riser", profile = "fx_riser", family = "fx" },
  { name = "Downlifter", profile = "fx_downlifter", family = "fx" },
  { name = "Impact", profile = "fx_impact", family = "fx" },
  { name = "Sweep", profile = "fx_sweep", family = "fx" },
  { name = "Whoosh", profile = "fx_whoosh", family = "fx" },
  { name = "Glitch FX", profile = "fx_glitch", family = "fx" },
  { name = "Noise FX", profile = "fx_noise", family = "fx" },
  { name = "Tonal FX", profile = "fx_tonal", family = "fx" },
  
  -- ========================================================================
  -- R. META & EXPERIMENTAL (7 categories)
  -- ========================================================================
  { name = "Vector Synth", profile = "meta_vector", family = "experimental" },
  { name = "Meta-Wavetable", profile = "meta_wavetable", family = "experimental" },
  { name = "Multi-Level Frame Morph", profile = "meta_frame_morph", family = "experimental" },
  { name = "Frame-of-Frames", profile = "meta_frame_of_frames", family = "experimental" },
  { name = "Self-Modulating Spectral", profile = "meta_self_modulating", family = "experimental" },
  { name = "Genre-Cross Hybrid", profile = "meta_genre_cross", family = "experimental" },
  { name = "Impossible Instrument", profile = "meta_impossible", family = "experimental" },
  
  -- ========================================================================
  -- LEGACY CATEGORIES (kept for backward compatibility)
  -- ========================================================================
  { name = "[Legacy] Mono Bass", profile = "bass_tight", family = "bass" },
  { name = "[Legacy] Sub Bass", profile = "bass_sustain", family = "bass" },
  { name = "[Legacy] Acid Bass", profile = "bass_filter", family = "bass" },
  { name = "[Legacy] Reese Bass", profile = "bass_wide", family = "bass" },
  { name = "[Legacy] FM Bass", profile = "bass_dynamic", family = "bass" },
  { name = "[Legacy] Pluck", profile = "pluck_short", family = "pluck" },
  { name = "[Legacy] Harp/Guitar", profile = "pluck_natural", family = "pluck" },
  { name = "[Legacy] Mallet", profile = "pluck_percussive", family = "pluck" },
  { name = "[Legacy] Kalimba", profile = "pluck_soft", family = "pluck" },
  { name = "[Legacy] Lead (Mono)", profile = "lead_expressive", family = "lead" },
  { name = "[Legacy] Lead (Poly)", profile = "lead_smooth", family = "lead" },
  { name = "[Legacy] Square Lead", profile = "lead_classic", family = "lead" },
  { name = "[Legacy] Supersaw Lead", profile = "lead_wide", family = "lead" },
  { name = "[Legacy] Portamento Lead", profile = "lead_glide", family = "lead" },
  { name = "[Legacy] Pad", profile = "pad_slow", family = "pad" },
  { name = "[Legacy] Ambient Pad", profile = "pad_evolving", family = "pad" },
  { name = "[Legacy] String Pad", profile = "pad_ensemble", family = "pad" },
  { name = "[Legacy] Choir/Vocal Pad", profile = "pad_formant", family = "pad" },
  { name = "[Legacy] Keys/EP", profile = "keys_dynamic", family = "keys" },
  { name = "[Legacy] Organ", profile = "keys_sustain", family = "keys" },
  { name = "[Legacy] Piano-like", profile = "keys_velocity", family = "keys" },
  { name = "[Legacy] Arp", profile = "arp_tight", family = "arp" },
  { name = "[Legacy] Sequenced", profile = "arp_gated", family = "arp" },
  { name = "[Legacy] One-Note Sequence", profile = "arp_rhythmic", family = "arp" },
  { name = "[Legacy] FX/Risers", profile = "fx_envelope", family = "fx" },
  { name = "[Legacy] FX/Impacts", profile = "fx_percussive", family = "fx" },
  { name = "[Legacy] FX/Drones", profile = "fx_sustain", family = "fx" },
  { name = "[Legacy] Experimental", profile = "neutral_flat", family = "neutral" },
  { name = "[Legacy] Raw Oscillator", profile = "neutral_none", family = "neutral" }
}

-- Profile names list for UI dropdowns and randomization
PakettiMetaSynthModulationProfileNames = {
  -- Neutral
  "neutral_flat", "neutral_none",
  -- Bass (Original)
  "bass_tight", "bass_sustain", "bass_filter", "bass_wide", "bass_dynamic",
  -- Pluck (Original)
  "pluck_short", "pluck_natural", "pluck_percussive", "pluck_soft",
  -- Lead (Original)
  "lead_expressive", "lead_smooth", "lead_classic", "lead_wide", "lead_glide",
  -- Pad (Original)
  "pad_slow", "pad_evolving", "pad_ensemble", "pad_formant",
  -- Keys (Original)
  "keys_dynamic", "keys_sustain", "keys_velocity",
  -- Arp (Original)
  "arp_tight", "arp_gated", "arp_rhythmic",
  -- FX (Original)
  "fx_envelope", "fx_percussive", "fx_sustain",
  -- Orchestral
  "strings", "brass",
  -- Bell
  "bell",
  -- Legacy (kept for compatibility)
  "default", "pluck", "bass", "pad", "lead", "organ", "keys", "percussive",
  
  -- ========================================================================
  -- GENERATED PROFILES (172 new profiles)
  -- ========================================================================
  
  -- Category A: Keys & Piano (25)
  "keys_piano_spectral_sine", "keys_piano_spectral_additive", "keys_piano_bright",
  "keys_piano_soft", "keys_piano_lofi", "keys_piano_cinematic", "keys_piano_prepared",
  "keys_upright", "keys_toy_piano", "keys_hybrid_synth", "keys_ep_sine", "keys_ep_fm",
  "keys_ep_bell", "keys_ep_digital", "keys_ep_warm", "keys_analog_saw", "keys_analog_square",
  "keys_analog_triangle", "keys_analog_mixed", "keys_vintage_synth", "keys_digital_complex",
  "keys_soft", "keys_hard_percussive", "keys_plucked", "keys_pad_hybrid",
  
  -- Category B: Mallets/Bells (14)
  "mallet_sine", "mallet_triangle", "mallet_inharmonic", "mallet_fm", "mallet_wooden",
  "mallet_metallic", "bell_pure_sine", "bell_inharmonic", "bell_glassy", "bell_digital_fm",
  "bell_gamelan", "bell_cinematic", "music_box", "toy_clockwork",
  
  -- Category C: Pads (17)
  "pad_analog_saw", "pad_analog_square", "pad_analog_triangle", "pad_analog_mixed",
  "pad_warm", "pad_dark", "pad_bright", "pad_digital", "pad_motion", "pad_evolving_multi",
  "pad_static", "pad_ambient", "pad_cinematic", "pad_air", "pad_choir", "pad_detuned",
  "pad_wide_stereo",
  
  -- Category D: Drones/Atmospheres (10)
  "drone_static_harmonic", "drone_evolving", "drone_noise", "drone_sub",
  "atmosphere_cinematic", "atmosphere_scifi", "atmosphere_dark_ambient",
  "atmosphere_industrial", "atmosphere_tonal", "atmosphere_dissonant",
  
  -- Category E: Leads - Saw (10)
  "lead_saw_mono", "lead_saw_poly", "lead_supersaw", "lead_saw_soft", "lead_saw_bright",
  "lead_saw_detuned", "lead_saw_vintage", "lead_saw_digital", "lead_trance", "lead_edm_festival",
  
  -- Category F: Leads - Square/Pulse (8)
  "lead_square", "lead_pulse", "lead_pwm", "lead_hollow_square", "lead_retro_game",
  "lead_chiptune", "lead_analog_square", "lead_digital_square",
  
  -- Category G: Leads - Sine/Triangle (6)
  "lead_sine", "lead_triangle", "lead_soft_expressive", "lead_whistle", "lead_minimal",
  "lead_ambient",
  
  -- Category H: Leads - Complex/Aggressive (7)
  "lead_hybrid", "lead_digital_aggressive", "lead_fm_inspired", "lead_acid",
  "lead_distorted", "lead_neuro", "lead_dubstep",
  
  -- Category I: Vocal/Formant (7)
  "vocal_pad_vowel", "vocal_lead_formant", "vocal_choir", "vocal_talking",
  "vocal_breath", "vocal_whisper", "vocal_organic",
  
  -- Category J: Basses - Sub/Clean (7)
  "bass_sub_sine", "bass_sub_triangle", "bass_clean", "bass_mono",
  "bass_analog_sub", "bass_digital_sub", "bass_808",
  
  -- Category K: Basses - Saw/Square (8)
  "bass_saw", "bass_square", "bass_detuned", "bass_reese", "bass_acid",
  "bass_vintage", "bass_techno", "bass_house",
  
  -- Category L: Basses - Complex/Modern (9)
  "bass_wobble", "bass_growl", "bass_fm", "bass_talking", "bass_distorted",
  "bass_neuro", "bass_dubstep", "bass_trap", "bass_drill",
  
  -- Category M: Plucks (7)
  "pluck_soft_gentle", "pluck_hard", "pluck_digital", "pluck_analog", "pluck_fm",
  "pluck_bell", "pluck_short_perc",
  
  -- Category N: Arps/Sequenced (7)
  "arp_synth", "arp_pluck", "arp_poly", "arp_mono", "arp_rhythmic", "arp_gated", "arp_pulsing",
  
  -- Category O: Synth Strings (8)
  "strings_synth_saw", "strings_synth_square", "strings_synth_mixed", "strings_warm_pad",
  "strings_ensemble", "strings_cinematic", "strings_motion", "strings_vintage_machine",
  
  -- Category P: Synth Brass (7)
  "brass_synth_saw", "brass_synth_square", "brass_soft_pad", "brass_stab", "brass_funk",
  "brass_cinematic", "brass_hybrid",
  
  -- Category Q: FX/Sound Design (8)
  "fx_riser", "fx_downlifter", "fx_impact", "fx_sweep", "fx_whoosh", "fx_glitch",
  "fx_noise", "fx_tonal",
  
  -- Category R: Meta/Experimental (7)
  "meta_vector", "meta_wavetable", "meta_frame_morph", "meta_frame_of_frames",
  "meta_self_modulating", "meta_genre_cross", "meta_impossible"
}

-- Sound Category names for UI dropdown
PakettiMetaSynthSoundCategoryNames = {}
for i, cat in ipairs(PakettiMetaSynthSoundCategories) do
  PakettiMetaSynthSoundCategoryNames[i] = cat.name
end

-- Profile names list for group-level profile selector dropdowns
-- Returns list of profile keys and display items for UI
PakettiMetaSynthProfileNamesList = {}
PakettiMetaSynthProfileDisplayList = {"Inherit Global"}  -- First item is always "Inherit"
for _, profile_name in ipairs(PakettiMetaSynthModulationProfileNames) do
  local profile = PakettiMetaSynthProfiles[profile_name]
  if profile then
    table.insert(PakettiMetaSynthProfileNamesList, profile_name)
    table.insert(PakettiMetaSynthProfileDisplayList, profile.name or profile_name)
  end
end

-- ============================================================================
-- LAYER-FILTERED PROFILE LISTS
-- Per the Profile Architecture Proposal: profiles should only appear in
-- dropdowns for layers where they are enabled. This avoids confusing UX
-- where profiles appear but do nothing for that layer.
-- ============================================================================

-- Helper: Get profiles filtered by layer enabled state
-- layer_key: the profile layer to check (e.g., "group_frame", "total_group_fx", "oscillator_groups")
-- enabled_check: function(layer_data) -> boolean, or nil to check layer.enabled
function PakettiMetaSynthGetFilteredProfiles(layer_key, enabled_check)
  local names = {}
  local display = {"Inherit Global"}
  
  for _, profile_name in ipairs(PakettiMetaSynthModulationProfileNames) do
    local profile = PakettiMetaSynthProfiles[profile_name]
    if profile then
      local layer_data = profile[layer_key]
      local is_enabled = true
      
      if layer_data then
        if enabled_check then
          is_enabled = enabled_check(layer_data)
        elseif layer_data.enabled ~= nil then
          is_enabled = layer_data.enabled
        end
      end
      
      if is_enabled then
        table.insert(names, profile_name)
        table.insert(display, profile.name or profile_name)
      end
    end
  end
  
  return names, display
end

-- GROUP FRAMES: Only show profiles where group_frame.enabled = true
PakettiMetaSynthGroupFrameProfileNames, PakettiMetaSynthGroupFrameProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("group_frame", function(layer)
    return layer.enabled == true
  end)

-- TOTAL GROUP FX: Only show profiles where total_group_fx.enabled ~= false (default enabled)
PakettiMetaSynthTotalGroupFXProfileNames, PakettiMetaSynthTotalGroupFXProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("total_group_fx", function(layer)
    return layer.enabled ~= false
  end)

-- FRAME MORPH: Only show profiles where frame.morph_enabled = true
PakettiMetaSynthFrameMorphProfileNames, PakettiMetaSynthFrameMorphProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("frame", function(layer)
    return layer.morph_enabled == true
  end)

-- OSCILLATOR GROUPS: Only show profiles where oscillator_groups.crossfade_enabled = true
PakettiMetaSynthOscillatorGroupsProfileNames, PakettiMetaSynthOscillatorGroupsProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("oscillator_groups", function(layer)
    return layer.crossfade_enabled == true
  end)

-- GROUP CROSSFADE: Only show profiles where group_frame.enabled = true
PakettiMetaSynthGroupCrossfadeProfileNames, PakettiMetaSynthGroupCrossfadeProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("group_frame", function(layer)
    return layer.enabled == true
  end)

-- GROUP FX: Only show profiles where oscillator_groups.group_master_fx_enabled = true
PakettiMetaSynthGroupFXProfileNames, PakettiMetaSynthGroupFXProfileDisplay = 
  PakettiMetaSynthGetFilteredProfiles("oscillator_groups", function(layer)
    return layer.group_master_fx_enabled == true
  end)

-- MODULATION: Only show profiles where modulation.enabled ~= false (default enabled)
PakettiMetaSynthModulationProfileFilteredNames, PakettiMetaSynthModulationProfileFilteredDisplay = 
  PakettiMetaSynthGetFilteredProfiles("modulation", function(layer)
    return layer.enabled ~= false
  end)

-- GLOBAL FX: Only show profiles where global_fx.enabled = true
PakettiMetaSynthGlobalFXFilteredNames, PakettiMetaSynthGlobalFXFilteredDisplay = 
  PakettiMetaSynthGetFilteredProfiles("global_fx", function(layer)
    return layer.enabled == true
  end)

-- Helper function: Find profile index in a filtered list by profile key
function PakettiMetaSynthFindProfileIndex(profile_key, names_list)
  if not profile_key then return 1 end  -- Return "Inherit Global" index
  for i, name in ipairs(names_list) do
    if name == profile_key then
      return i + 1  -- +1 because "Inherit Global" is at index 1
    end
  end
  return 1  -- Default to "Inherit Global" if not found in filtered list
end

-- Helper function: Get profile key from filtered list by index
function PakettiMetaSynthGetProfileKey(index, names_list)
  if index == 1 then return nil end  -- "Inherit Global" means no override
  return names_list[index - 1]  -- -1 because "Inherit Global" is at index 1
end

-- ============================================================================
-- FX PROFILES - Separate FX character that can be applied independently
-- These profiles define ONLY FX tendencies, allowing you to apply
-- the FX character of one sound type to a different structure.
-- Example: Apply "lead bright" FX to a bass structure
-- ============================================================================
PakettiMetaSynthFXProfiles = {
  fx_none = {
    name = "None / Bypass",
    description = "No FX processing",
    frame_fx = {},
    group_fx = {},  -- Oscillator group FX (per-group)
    total_group_fx = {},  -- Total Group FX (Stack Master)
    global_fx = {},
  },
  fx_bass_heavy = {
    name = "Bass Heavy",
    description = "Sub-focused processing with saturation",
    frame_fx = {"Analog Filter", "Distortion"},
    total_group_fx = {"Analog Filter", "Saturator", "Compressor"},
    global_fx = {"EQ 5", "Maximizer"},
  },
  fx_bass_clean = {
    name = "Bass Clean",
    description = "Clean low-end with subtle compression",
    frame_fx = {"Analog Filter"},
    total_group_fx = {"EQ 5", "Compressor"},
    global_fx = {"EQ 5"},
  },
  fx_lead_bright = {
    name = "Lead Bright",
    description = "Cutting, present lead character",
    frame_fx = {"Analog Filter", "Distortion", "Chorus"},
    total_group_fx = {"Saturator", "EQ 5"},
    global_fx = {"Reverb", "Delay"},
  },
  fx_lead_smooth = {
    name = "Lead Smooth",
    description = "Warm, rounded lead character",
    frame_fx = {"Analog Filter", "Chorus"},
    total_group_fx = {"Saturator", "Chorus"},
    global_fx = {"Reverb", "EQ 5"},
  },
  fx_pad_ambient = {
    name = "Pad Ambient",
    description = "Spacious, evolving atmosphere",
    frame_fx = {"Chorus", "Phaser", "Analog Filter"},
    total_group_fx = {"Chorus", "Flanger"},
    global_fx = {"Reverb", "Delay", "EQ 5"},
  },
  fx_pad_warm = {
    name = "Pad Warm",
    description = "Warm, enveloping pad character",
    frame_fx = {"Analog Filter", "Chorus"},
    total_group_fx = {"Chorus", "Saturator"},
    global_fx = {"Reverb", "EQ 5"},
  },
  fx_pluck_bright = {
    name = "Pluck Bright",
    description = "Crisp, percussive transients",
    frame_fx = {"Analog Filter", "Distortion"},
    total_group_fx = {"Saturator", "EQ 5"},
    global_fx = {"Reverb", "Delay"},
  },
  fx_keys_vintage = {
    name = "Keys Vintage",
    description = "Classic electric piano character",
    frame_fx = {"Chorus", "Phaser"},
    total_group_fx = {"Saturator", "Chorus"},
    global_fx = {"Reverb", "EQ 5"},
  },
  fx_experimental = {
    name = "Experimental",
    description = "Heavy modulation and distortion",
    frame_fx = {"Ring Mod", "Distortion", "Phaser"},
    total_group_fx = {"Flanger", "Distortion", "Filter 3"},
    global_fx = {"Reverb", "Delay"},
  },
  fx_clean = {
    name = "Clean / Minimal",
    description = "Minimal processing, transparent",
    frame_fx = {},
    total_group_fx = {"EQ 5"},
    global_fx = {"EQ 5"},
  },
}

-- FX Profile names list for dropdowns
PakettiMetaSynthFXProfileNamesList = {
  "fx_none", "fx_bass_heavy", "fx_bass_clean", "fx_lead_bright", "fx_lead_smooth",
  "fx_pad_ambient", "fx_pad_warm", "fx_pluck_bright", "fx_keys_vintage",
  "fx_experimental", "fx_clean"
}

-- FX Profile display names for UI dropdowns
PakettiMetaSynthFXProfileDisplayList = {"Use Sound Profile"}  -- First item uses sound profile's FX
for _, fx_name in ipairs(PakettiMetaSynthFXProfileNamesList) do
  local fx_profile = PakettiMetaSynthFXProfiles[fx_name]
  if fx_profile then
    table.insert(PakettiMetaSynthFXProfileDisplayList, fx_profile.name)
  end
end

-- ============================================================================
-- FX CATEGORY AND DEVICE LISTS FOR DROPDOWNS
-- Used for consistent FX selection at all FX-capable stages
-- ============================================================================

-- FX Categories (archetypes) for dropdown selection
PakettiMetaSynthFXCategoryList = {
  "Inherit Profile",  -- First item inherits from profile
  "Clean",            -- Subtle, transparent processing
  "Character",        -- Coloration, saturation, warmth
  "Movement",         -- Modulation, time-based movement
  "Spatial",          -- Reverb, delay, stereo imaging
  "Aggressive"        -- Distortion, heavy processing
}

-- FX Devices available in Renoise (native devices)
PakettiMetaSynthFXDeviceList = {
  "Analog Filter",
  "Bus Compressor",
  "Cabinet Simulator",
  "Chorus 2",
  "Comb Filter",
  "Compressor",
  "Convolver",
  "DC Offset",
  "Delay",
  "Distortion",
  "EQ 10",
  "EQ 5",
  "Exciter",
  "Filter 3",
  "Flanger 2",
  "Formula",
  "Gain",
  "Gate 2",
  "Gapper",
  "Line In",
  "LofiMat 2",
  "Maximizer",
  "Mixer EQ",
  "mpReverb 2",
  "Multitap Delay",
  "Phaser 2",
  "Repeater",
  "Reverb",
  "Ringmod",
  "Signal Follower",
  "Stutter",
  "Stereo Expander",
  "Tremolo",
  "Vibrato"
}

-- FX Devices display list with "None" option
PakettiMetaSynthFXDeviceDisplayList = {"None"}
for _, device in ipairs(PakettiMetaSynthFXDeviceList) do
  table.insert(PakettiMetaSynthFXDeviceDisplayList, device)
end

-- Modulation source list for dropdown
PakettiMetaSynthModulationSourceList = {
  "None",
  "Velocity",
  "Key Tracking",
  "Mod Wheel",
  "Aftertouch",
  "Pitch Bend",
  "LFO",
  "Random"
}

-- Modulation target list for dropdown
PakettiMetaSynthModulationTargetList = {
  "None",
  "Volume",
  "Pitch",
  "Pan",
  "Filter Cutoff",
  "Filter Resonance",
  "Detune"
}

-- Default architecture template
function PakettiMetaSynthCreateDefaultArchitecture()
  return {
    name = "New MetaSynth Instrument",
    -- GLOBAL PROFILE: Master profile applied to ALL layers unless overridden
    -- This defines the musical intent (Pluck, Pad, Bass, Lead, etc.)
    -- Each layer consumes the subset of rules that apply to it
    global_profile = "default",
    
    -- ================================================================
    -- FX PROFILE OVERRIDE: Apply FX character independently from sound profile
    -- nil = use the sound profile's FX tendencies
    -- Set to an FX profile name to override FX at all levels
    -- ================================================================
    fx_profile_override = nil,
    
    -- ================================================================
    -- MODULATION LAYER (NEW): Separate layer with independent profile override
    -- Allows modulation to be controlled independently from other layers
    -- ================================================================
    modulation_layer = {
      -- Profile override for modulation only (nil = use global_profile's modulation)
      profile_override = nil,
      -- Optional: custom modulation settings that bypass profile entirely
      -- When set, these values override the profile's modulation settings
      custom_modulation = nil,
      -- Global tempo sync: when true, all AHDSR and LFO devices will be tempo-synced
      -- This allows envelope times to be in beat divisions instead of milliseconds
      tempo_synced = false,
    },
    
    -- ================================================================
    -- CONSTRAINTS: Override profile defaults for randomization bounds
    -- These settings constrain what randomization can do
    -- ================================================================
    constraints = {
      -- Parameter ranges (override profile defaults during randomization)
      group_count_range = {1, 2},
      oscillator_count_range = {1, 3},
      unison_range = {1, 4},
      frame_count_range = {1, 4},
      fx_count_range = {0, 4},
      
      -- Feature toggles (allow/forbid specific features)
      allow_group_frames = true,
      allow_vector = true,
      allow_group_scan = true,
      allow_global_fx_frames = true,
      allow_global_fx_scan = true,
      allow_global_fx_vector = true,
      allow_stepper = true,
      allow_arp = true,
      
      -- FX device toggles (allow/forbid specific FX devices)
      allow_reverb = true,
      allow_chorus = true,
      allow_phaser = true,
      allow_flanger = true,
      allow_distortion = true,
      allow_filter = true,
      allow_eq = true,
      allow_compressor = true,
      allow_maximizer = true,
      allow_convolver = true,
      allow_cabinet = true,
      allow_lofimat = true,
      allow_exciter = true,
      allow_stereo_expander = true,
      allow_tremolo = true,
      allow_vibrato = true,
      
      -- FX device blacklist (more specific control)
      forbidden_devices = {},  -- e.g., {"Convolver", "mpReverb 2"}
    },
    
    -- ================================================================
    -- FX DEVICE OVERRIDES: Per-device enable/weight settings
    -- Allows fine-grained control over FX selection probability
    -- ================================================================
    fx_device_overrides = {},  -- e.g., { ["Reverb"] = { enabled = true, weight = 1.0 } }
    
    oscillator_groups = {
      {
        name = "Group A",
        crossfade_mode = "linear",
        -- Group-level crossfade settings (wavetable scanning between oscillators)
        group_crossfade_enabled = false,
        group_crossfade_curve = "equal_power",
        -- Group LFO rate settings
        group_lfo_rate_mode = "preset",  -- "free", "tempo_sync", "preset"
        group_lfo_rate_free = 0.5,       -- Hz when mode = "free"
        group_lfo_rate_sync = "1 bar",   -- Beat division when mode = "tempo_sync"
        group_lfo_rate_preset = "medium", -- "slow", "medium", "fast" when mode = "preset"
        -- LAYER 4: Oscillator Groups FX (FX applied to summed oscillators per group)
        -- This is Level 4 FX option - FX added to each oscillator group after summing
        group_master_fx_enabled = false,
        group_master_fx_mode = "random",
        group_master_fx_count = 3,
        group_master_fx_types = {},
        group_master_fx_category = nil,  -- FX Category for group summing FX
        -- FX Archetype selection (rule-based FX by musical character)
        group_fx_archetypes = {"character"},  -- Enabled archetypes: clean, character, movement, spatial, aggressive
        
        -- ================================================================
        -- GROUP FRAMES (NEW): Meta-wavetable at group level
        -- Allows the entire group to morph between different "snapshots"
        -- Default OFF - advanced feature for evolving/ambient sounds
        -- ================================================================
        group_frames_enabled = false,       -- Default OFF for most profiles
        group_frame_count = 1,              -- 1-8 frames at group level
        group_frame_morph_enabled = false,  -- Whether to morph between group frames
        group_frame_morph_speed = "slow",   -- "none", "slow", "medium", "fast"
        group_frame_crossfade_curve = "linear",  -- Curve type for group frame morphing
        group_frame_control_source = "lfo", -- "lfo" or "macro"
        group_frame_lfo_rate_preset = "slow",  -- LFO speed for group frame morphing
        -- Per-group-frame FX (optional processing per group frame)
        group_frame_fx_enabled = false,
        group_frame_fx_tendencies = {},
        group_frame_fx_count = 1,
        group_frame_fx_category = nil,  -- FX Category for group frame FX
        group_frame_fx_mode = "random", -- "random" or "selective"
        
        -- PROFILE OVERRIDE at GROUP level (nil = inherit from global_profile)
        -- When set, this group uses a different profile than the global one
        profile_override = nil,
        -- FX PROFILE OVERRIDE at GROUP level (nil = inherit from architecture)
        -- Allows applying different FX character to specific groups
        fx_profile_override = nil,
        -- GROUP FRAME PROFILE OVERRIDE (nil = inherit from group/global_profile)
        -- Only profiles with group_frame.enabled = true appear in dropdown
        group_frame_profile_override = nil,
        -- OSCILLATOR GROUP FX PROFILE OVERRIDE (nil = inherit from group/global_profile)
        -- Only profiles with oscillator_groups.osc_group_fx_enabled ~= false appear in dropdown
        group_fx_profile_override = nil,
        -- GROUP CROSSFADE PROFILE OVERRIDE (nil = inherit from group/global_profile)
        -- Only profiles with group.crossfade_enabled = true appear in dropdown
        group_crossfade_profile_override = nil,
        -- DEPRECATED: modulation_profile - use profile_override instead
        -- Kept for backward compatibility, will be migrated to profile_override
        modulation_profile = nil,
        oscillators = {
          {
            name = "Osc 1",
            sample_count = 1,
            unison_voices = 1,
            frame_count = 1,
            sample_source = "akwf",
            sample_folder = nil,
            detune_spread = 10,
            pan_spread = 0.8,
            -- Oscillator FX settings (processing after frame morphing, before group morphing)
            osc_fx_enabled = false,
            osc_fx_mode = "random",
            osc_fx_count = 2,
            osc_fx_types = {},
            -- PROFILE OVERRIDE at OSCILLATOR level (nil = inherit from group/global)
            -- When set, this specific oscillator uses a different profile
            profile_override = nil,
            -- DEPRECATED: modulation_profile - use profile_override instead
            modulation_profile = nil,
            -- Per-oscillator modulation routing (Renoise-native sources)
            modulation_routing = {
              velocity_to_volume = 0.5,
              velocity_to_filter = 0.0,
              velocity_to_pitch = 0.0,
              keytrack_to_filter = 0.0,
              modwheel_to_filter = 0.0,
              modwheel_to_volume = 0.0,
              aftertouch_to_filter = 0.0,
              aftertouch_to_pitch = 0.0,
              pitchbend_range = 2,
              random_to_pitch = 0.0,
              random_to_pan = 0.0
            },
            -- FX Category override for this oscillator's frame FX
            osc_fx_category = nil,
            osc_fx_devices = {}
          }
        }
      }
    },
    crossfade = {
      curve_type = "equal_power",
      control_source = "lfo",  -- LFO mode works; macro mode not fully implemented
      macro_index = 1,
      -- Frame LFO rate settings
      lfo_rate_mode = "preset",    -- "free", "tempo_sync", "preset"
      lfo_rate_free = 0.5,         -- Hz when mode = "free"
      lfo_rate_sync = "1/4",       -- Beat division when mode = "tempo_sync"
      lfo_rate_preset = "medium"   -- "slow", "medium", "fast" when mode = "preset"
    },
    fx_randomization = {
      enabled = false,
      device_pool = {"Analog Filter", "Chorus 2"},
      param_randomization = 0.3
    },
    modulation = {
      random_phase_offsets = true,
      lfo_rate_range = {0.1, 2.0},
      envelope_attack_range = {0.0, 0.5}
    },
    -- LAYER 6: Total Group FX (FX applied after all groups summed)
    -- This is Level 6 FX option - FX added to the total summed groups (Stack Master)
    stack_master_fx_enabled = false,
    stack_master_fx_mode = "random",
    stack_master_fx_count = 3,
    stack_master_fx_types = {},
    stack_master_fx_category = nil,  -- FX Category for Total Group FX
    -- FX Archetype selection for Stack Master (rule-based FX by musical character)
    stack_master_fx_archetypes = {"clean", "spatial"},  -- Enabled archetypes
    -- Master routing mode: "output_routing" (chain property) or "send_device" (#Send devices)
    master_routing_mode = "output_routing",
    
    -- ================================================================
    -- INTER-GROUP SCAN: Wavetable/Vector synthesis across groups
    -- Morphs between groups at the Stack Master level
    -- Default OFF - enable for inter-group wavetable/vector behavior
    -- ================================================================
    group_scan_enabled = false,             -- Default OFF
    group_scan_curve = "equal_power",       -- "linear", "equal_power", "s_curve", "stepped", "spectral", "vector"
    group_scan_speed = "slow",              -- "slow", "medium", "fast"
    group_scan_control_source = "lfo",      -- "lfo", "macro"
    group_scan_lfo_rate_preset = "slow",    -- LFO speed preset
    group_scan_macro_index = 6,             -- Macro index for manual control
    
    -- ================================================================
    -- VECTOR SYNTHESIS: XY pad control for 4-group morphing
    -- Enables joystick-style blending between 4 corners (groups)
    -- Default OFF - requires exactly 4 groups to function
    -- ================================================================
    vector_enabled = false,                 -- Default OFF
    vector_mode = "xy",                     -- "xy" (4 groups) or "linear" (2+ groups)
    vector_x_source = "macro",              -- "macro", "lfo", "envelope"
    vector_y_source = "macro",              -- "macro", "lfo", "envelope"
    vector_x_macro = 7,                     -- X axis macro (1-8)
    vector_y_macro = 8,                     -- Y axis macro (1-8)
    vector_x_lfo_speed = "slow",            -- LFO speed if using LFO
    vector_y_lfo_speed = "medium",          -- LFO speed if using LFO
    
    -- ================================================================
    -- VECTOR ENVELOPE PATH (PHASE 3 - DATA MODEL ONLY)
    -- Animated XY movement over time - not yet implemented in generation
    -- ================================================================
    vector_envelope = {
      enabled = false,                      -- Not yet implemented
      points = {                            -- XY path points with time
        {x = 0.5, y = 0.5, time = 0},       -- Start at center
        {x = 0.5, y = 0.5, time = 1}        -- End at center
      },
      loop = false,                         -- Loop the envelope path
      duration = 4.0,                       -- Total duration in seconds
    },
    
    -- ================================================================
    -- GLOBAL MODULATION (PHASE 3 - DATA MODEL ONLY)
    -- Shared modulation sources across all groups - not yet implemented
    -- ================================================================
    global_modulation = {
      enabled = false,                      -- Not yet implemented
      lfo1 = {
        enabled = false,
        frequency = 0.5,                    -- Hz
        shape = "sine",                     -- "sine", "triangle", "square", "saw"
        targets = {},                       -- e.g. {"group_a_gain", "group_b_filter"}
      },
      lfo2 = {
        enabled = false,
        frequency = 0.25,
        shape = "triangle",
        targets = {},
      },
      envelope = {
        enabled = false,
        attack = 0.1,
        decay = 0.2,
        sustain = 0.7,
        release = 0.5,
        targets = {},
      },
    },
    
    -- ================================================================
    -- GLOBAL FX FRAMES (NEW): Frame scanning at the final output stage
    -- Similar to Group Frames but for the Stack Master level
    -- Default OFF - advanced feature for evolving final polish
    -- ================================================================
    global_fx_frames_enabled = false,       -- Default OFF
    global_fx_frame_count = 1,              -- 1-8 frames at global level
    global_fx_frame_morph_enabled = false,  -- Whether to morph between frames
    global_fx_frame_morph_speed = "slow",   -- "none", "slow", "medium", "fast"
    global_fx_frame_crossfade_curve = "equal_power",  -- Curve type
    global_fx_frame_control_source = "lfo", -- "lfo" or "macro"
    global_fx_frame_lfo_rate_preset = "slow", -- LFO speed
    -- Per-global-frame FX (optional processing per frame)
    global_fx_frame_fx_enabled = false,
    global_fx_frame_fx_tendencies = {},
    global_fx_frame_fx_count = 1,
    global_fx_frame_fx_category = nil,  -- FX Category for Total Group Frame FX
    
    -- ================================================================
    -- TOTAL GROUP FRAMES SCAN: Sequential wavetable-style scanning across Total Group Frames
    -- Works with any frame count >= 2
    -- Default OFF
    -- ================================================================
    global_fx_scan_enabled = false,
    global_fx_scan_curve = "equal_power",       -- All 6 curve types supported
    global_fx_scan_control_source = "lfo",      -- "lfo" or "macro"
    global_fx_scan_lfo_rate_preset = "slow",    -- LFO speed preset
    
    -- ================================================================
    -- TOTAL GROUP FRAMES VECTOR: XY-based morphing between 4 Total Group Frames
    -- Requires exactly 4 frames (corners of XY space)
    -- Default OFF
    -- ================================================================
    global_fx_vector_enabled = false,
    global_fx_vector_x_source = "lfo",          -- "lfo" or "macro"
    global_fx_vector_y_source = "lfo",          -- "lfo" or "macro"
    global_fx_vector_x_lfo_rate = 0.25,         -- X-axis LFO frequency
    global_fx_vector_y_lfo_rate = 0.15,         -- Y-axis LFO frequency
    
    -- ================================================================
    -- GROUP FRAME VECTOR: XY-based morphing between 4 Group Frames
    -- Requires exactly 4 group frames (corners of XY space)
    -- Default OFF - per-group setting
    -- ================================================================
    group_frame_vector_enabled = false,
    group_frame_vector_x_source = "lfo",        -- "lfo" or "macro"
    group_frame_vector_y_source = "lfo",        -- "lfo" or "macro"
    group_frame_vector_x_lfo_rate = 0.2,        -- X-axis LFO frequency
    group_frame_vector_y_lfo_rate = 0.12,       -- Y-axis LFO frequency
    
    -- ================================================================
    -- SPECTRAL MORPH MACRO: Macro-controllable spectral morphing intensity
    -- Controls how pronounced the spectral crossfade effect is
    -- Default OFF
    -- ================================================================
    spectral_morph_enabled = false,
    spectral_morph_macro_index = 5,             -- Which macro (1-8) controls intensity
    spectral_morph_intensity = 0.5,             -- Base intensity (0.0 to 1.0)
    
    -- ================================================================
    -- FINAL OUTPUT STAGE (True Output - Master EQ, Limiter, Output Shaping)
    -- This is the LAST stage before instrument output
    -- Always present when enabled - handles polish and protection
    -- ================================================================
    final_output_enabled = false,               -- Enable final output processing
    final_output_master_eq_enabled = true,      -- Master EQ for tonal shaping
    final_output_master_eq_low_shelf = 0.0,     -- Low shelf gain (-12 to +12 dB)
    final_output_master_eq_high_shelf = 0.0,    -- High shelf gain (-12 to +12 dB)
    final_output_master_eq_presence = 0.0,      -- Presence boost (2-5kHz)
    final_output_limiter_enabled = true,        -- Output limiter/protection
    final_output_limiter_ceiling = -0.3,        -- Ceiling in dB
    final_output_limiter_release = 100,         -- Release in ms
    final_output_saturation_enabled = false,    -- Subtle saturation/warmth
    final_output_saturation_amount = 0.1,       -- Saturation intensity
    final_output_width_enabled = false,         -- Stereo width control
    final_output_width_amount = 1.0             -- Width (0.0 = mono, 1.0 = normal, 2.0 = wide)
  }
end

-- Calculate total sample count across the entire architecture
function PakettiMetaSynthCalculateTotalSamples(architecture)
  local total = 0
  for _, group in ipairs(architecture.oscillator_groups) do
    for _, osc in ipairs(group.oscillators) do
      total = total + (osc.sample_count * osc.unison_voices)
    end
  end
  return total
end

-- Calculate total FX chains needed
function PakettiMetaSynthCalculateTotalFXChains(architecture)
  local total = 0
  for _, group in ipairs(architecture.oscillator_groups) do
    for _, osc in ipairs(group.oscillators) do
      -- Each frame needs its own FX chain
      total = total + osc.frame_count
      -- Add 1 chain per oscillator when Oscillator FX is enabled
      if osc.osc_fx_enabled then
        total = total + 1
      end
    end
    -- Add 1 chain per group when Group Master FX is enabled
    if group.group_master_fx_enabled then
      total = total + 1
    end
  end
  -- Add 1 chain for Stack Master FX when enabled
  if architecture.stack_master_fx_enabled then
    total = total + 1
  end
  return total
end

-- Validate architecture against Renoise limits
function PakettiMetaSynthValidateArchitecture(architecture)
  local errors = {}
  local warnings = {}
  
  local total_samples = PakettiMetaSynthCalculateTotalSamples(architecture)
  local total_fx_chains = PakettiMetaSynthCalculateTotalFXChains(architecture)
  
  -- Hard limit: 12 samples per note
  if total_samples > 12 then
    table.insert(errors, string.format("Total samples (%d) exceeds Renoise limit of 12 samples per note", total_samples))
  end
  
  -- Soft limit: warn if approaching limit
  if total_samples > 8 and total_samples <= 12 then
    table.insert(warnings, string.format("Total samples (%d) is approaching the 12-sample limit", total_samples))
  end
  
  -- FX chain limit (256 max)
  if total_fx_chains > 256 then
    table.insert(errors, string.format("Total FX chains (%d) exceeds Renoise limit of 256", total_fx_chains))
  end
  
  -- Validate each oscillator group
  for gi, group in ipairs(architecture.oscillator_groups) do
    if #group.oscillators == 0 then
      table.insert(errors, string.format("Group '%s' has no oscillators", group.name))
    end
    
    -- Validate Group Master FX settings
    if group.group_master_fx_enabled then
      if group.group_master_fx_count < 1 or group.group_master_fx_count > 5 then
        table.insert(errors, string.format("Group '%s' master FX count must be 1-5", group.name))
      end
      if group.group_master_fx_mode == "selective" and #group.group_master_fx_types == 0 then
        table.insert(warnings, string.format("Group '%s' has selective FX mode but no FX types selected", group.name))
      end
    end
    
    for oi, osc in ipairs(group.oscillators) do
      if osc.sample_count < 1 or osc.sample_count > 12 then
        table.insert(errors, string.format("Oscillator '%s' sample_count must be 1-12", osc.name))
      end
      if osc.unison_voices < 1 or osc.unison_voices > 8 then
        table.insert(errors, string.format("Oscillator '%s' unison_voices must be 1-8", osc.name))
      end
      if osc.frame_count < 1 or osc.frame_count > 16 then
        table.insert(errors, string.format("Oscillator '%s' frame_count must be 1-16", osc.name))
      end
      
      -- Validate Oscillator FX settings
      if osc.osc_fx_enabled then
        if osc.osc_fx_count < 1 or osc.osc_fx_count > 5 then
          table.insert(errors, string.format("Oscillator '%s' FX count must be 1-5", osc.name))
        end
        if osc.osc_fx_mode ~= "random" and osc.osc_fx_mode ~= "selective" then
          table.insert(errors, string.format("Oscillator '%s' FX mode must be 'random' or 'selective'", osc.name))
        end
        if osc.osc_fx_mode == "selective" and (not osc.osc_fx_types or #osc.osc_fx_types == 0) then
          table.insert(warnings, string.format("Oscillator '%s' has selective FX mode but no FX types selected", osc.name))
        end
      end
    end
  end
  
  -- Validate Stack Master FX settings
  if architecture.stack_master_fx_enabled then
    if architecture.stack_master_fx_count < 1 or architecture.stack_master_fx_count > 5 then
      table.insert(errors, "Stack Master FX count must be 1-5")
    end
    if architecture.stack_master_fx_mode == "selective" and #architecture.stack_master_fx_types == 0 then
      table.insert(warnings, "Stack Master FX has selective mode but no FX types selected")
    end
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
    total_samples = total_samples,
    total_fx_chains = total_fx_chains
  }
end

-- ============================================================================
-- SECTION 2: FX CHAIN BUILDER
-- ============================================================================

-- Available native devices for FX randomization (safe, CPU-friendly choices)
PakettiMetaSynthSafeFXDevices = {
  "Analog Filter",
  "Chorus 2",
  "Comb Filter 2",
  "Delay",
  "Digital Filter",
  "Distortion 2",
  "EQ 5",
  "Flanger 2",
  "Gainer",
  "LofiMat 2",
  "Phaser 2",
  "RingMod 2",
  "Stereo Expander"
}

-- Heavy devices (excluded by default for CPU-aware mode)
PakettiMetaSynthHeavyFXDevices = {
  "Convolver",
  "mpReverb 2",
  "Reverb",
  "Cabinet Simulator"
}

-- Create a new FX chain in the instrument
function PakettiMetaSynthCreateFXChain(instrument, chain_name)
  local chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(chain_index)
  local chain = instrument.sample_device_chains[chain_index]
  chain.name = chain_name
  PakettiMetaSynthAddDCOffset(chain)
  return chain, chain_index
end

-- Add DC Offset device (Automatic mode) to a chain right after Mixer
function PakettiMetaSynthAddDCOffset(chain)
  local success, err = pcall(function()
    chain:insert_device_at("Audio/Effects/Native/DC Offset", 2)
  end)
  if success then
    local device = chain.devices[2]
    device.parameters[2].value = 1  -- Automatic mode
    device.display_name = "DC Offset"
  end
end

-- Insert a native device into an FX chain
function PakettiMetaSynthInsertDevice(chain, device_name, position)
  position = position or (#chain.devices + 1)
  local device_path = "Audio/Effects/Native/" .. device_name
  
  local success, err = pcall(function()
    chain:insert_device_at(device_path, position)
  end)
  
  if success then
    return chain.devices[position]
  else
    print("PakettiMetaSynth: Failed to insert device '" .. device_name .. "': " .. tostring(err))
    return nil
  end
end

-- Randomize device parameters within safe ranges
function PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
  if not device or not device.parameters then return end
  
  randomization_amount = randomization_amount or 0.3
  
  for i, param in ipairs(device.parameters) do
    -- Skip the first parameter (usually bypass/active)
    if i > 1 and param.value_quantum == 0 then
      -- Continuous parameter - randomize within full range
      local range = param.value_max - param.value_min
      local new_value = param.value_min + math.random() * range * randomization_amount
      -- Ensure we stay within bounds
      new_value = math.max(param.value_min, math.min(param.value_max, new_value))
      param.value = new_value
    end
  end
end

-- Create a Gainer device with specific gain value
function PakettiMetaSynthCreateGainer(chain, gain_value, display_name)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "Gainer", position)
  
  if device then
    device.display_name = display_name or "Frame Gainer"
    -- Gainer parameter 1 is Gain (0.0 = -INF dB, 1.0 = 0 dB, higher = boost)
    device.parameters[1].value = gain_value or 1.0
    -- Gainer parameter 2 is Panning (0.5 = center)
    device.parameters[2].value = 0.5
  end
  
  return device, position
end

-- LFO Rate Presets (in Hz)
PakettiMetaSynthLFORatePresets = {
  slow = 0.1,     -- 10 second cycle
  medium = 0.5,   -- 2 second cycle
  fast = 2.0      -- 0.5 second cycle
}

-- Tempo-sync divisions mapped to LPB-relative values
-- These are based on lines-per-beat and need song tempo to calculate actual Hz
PakettiMetaSynthLFOSyncDivisions = {
  ["1/16"] = 0.25,   -- 1/16 of a beat
  ["1/8"] = 0.5,     -- 1/8 of a beat (half beat)
  ["1/4"] = 1,       -- 1 beat
  ["1/2"] = 2,       -- 2 beats (half bar in 4/4)
  ["1 bar"] = 4,     -- 4 beats (1 bar in 4/4)
  ["2 bars"] = 8,    -- 8 beats (2 bars)
  ["4 bars"] = 16    -- 16 beats (4 bars)
}

-- Calculate LFO frequency from rate settings
-- Returns frequency in Hz (Renoise LFO frequency parameter, 0-1 maps to Hz range)
function PakettiMetaSynthCalculateLFOFrequency(rate_mode, rate_free, rate_sync, rate_preset)
  rate_mode = rate_mode or "preset"
  rate_preset = rate_preset or "medium"
  rate_free = rate_free or 0.5
  rate_sync = rate_sync or "1 bar"
  
  local frequency_hz = 0.5  -- Default
  
  if rate_mode == "free" then
    -- Direct Hz value
    frequency_hz = rate_free
    
  elseif rate_mode == "preset" then
    -- Use preset values
    frequency_hz = PakettiMetaSynthLFORatePresets[rate_preset] or 0.5
    
  elseif rate_mode == "tempo_sync" then
    -- Calculate from song tempo
    local song = renoise.song()
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    
    -- Get beat multiplier for this sync division
    local beat_multiplier = PakettiMetaSynthLFOSyncDivisions[rate_sync] or 4
    
    -- Calculate cycle duration in seconds
    -- beats_per_second = bpm / 60
    -- cycle_duration = beat_multiplier / beats_per_second = beat_multiplier * 60 / bpm
    local cycle_duration = beat_multiplier * 60 / bpm
    
    -- Frequency = 1 / cycle_duration
    frequency_hz = 1 / cycle_duration
  end
  
  -- Clamp to reasonable range (0.01 Hz to 10 Hz)
  frequency_hz = math.max(0.01, math.min(10, frequency_hz))
  
  -- Convert Hz to Renoise LFO frequency parameter (0-1 range, logarithmic)
  -- Renoise LFO frequency: 0 = 0.001 Hz, 1 = ~16 Hz (approximately log scale)
  -- Using approximation: param = log10(hz * 1000) / 4.2
  local param_value = math.log10(frequency_hz * 1000) / 4.2
  param_value = math.max(0, math.min(1, param_value))
  
  return param_value, frequency_hz
end

-- Create an LFO device with custom envelope for crossfade control, routed to a specific destination
-- Now accepts optional lfo_frequency parameter (Renoise param value 0-1)
function PakettiMetaSynthCreateCrossfadeLFO(chain, envelope_points, display_name, dest_device_index, dest_param_index, lfo_frequency)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "*LFO", position)
  
  if device then
    device.display_name = display_name or "Crossfade LFO"
    
    -- Build XML for custom envelope (NO routing in XML - done via parameters)
    local points_xml = {}
    for i, point in ipairs(envelope_points) do
      table.insert(points_xml, string.format('<Point>%d,%.6f,0.0</Point>', point.time, point.value))
    end
    
    -- DEBUG: Print routing info
    print(string.format("DEBUG LFO '%s': chain='%s', LFO position=%d, dest_device_index=%s, dest_param_index=%s",
      display_name or "Crossfade LFO",
      chain.name,
      position,
      tostring(dest_device_index),
      tostring(dest_param_index)))
    
    -- DEBUG: List all devices in chain
    print(string.format("DEBUG LFO '%s': Chain devices:", display_name))
    for di = 1, #chain.devices do
      local d = chain.devices[di]
      print(string.format("  Device %d: %s", di, d.display_name or d.name))
    end
    
    -- Use provided frequency or default
    local freq_value = lfo_frequency or 0.9375
    
    -- XML for custom envelope only (routing done via parameters after)
    local lfo_xml = string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.5</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>%.6f</Value>
    </Frequency>
    <Type>
      <Value>0.0</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>%d</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        %s
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]=], freq_value, #envelope_points, table.concat(points_xml, "\n        "))
    
    device.active_preset_data = lfo_xml
    
    -- Set routing via parameters (the correct way!)
    -- parameters[1] = Dest. Track (-1 = "Cur" = current chain)
    -- parameters[2] = Dest. Effect (0-based device index in dropdown)
    -- parameters[3] = Dest. Parameter (0=None, 1=Gain, 2=Panning for Gainer)
    if dest_device_index and dest_param_index then
      local effect_index = dest_device_index - 1  -- Convert 1-based position to 0-based dropdown index
      local param_index = dest_param_index        -- 1 = Gain (no conversion needed)
      
      device.parameters[1].value = -1          -- Current chain ("Cur")
      device.parameters[2].value = effect_index  -- Target device (0-based)
      device.parameters[3].value = param_index   -- Target parameter (1 = Gain)
      
      print(string.format("DEBUG LFO '%s': Set routing params[1]=-1, params[2]=%d (device %d), params[3]=%d (Gain)",
        display_name, effect_index, dest_device_index, param_index))
    end
  end
  
  return device
end

-- Create a Hydra device for multi-target modulation
function PakettiMetaSynthCreateHydra(chain, display_name)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "*Hydra", position)
  
  if device then
    device.display_name = display_name or "Crossfade Hydra"
  end
  
  return device
end

-- Build a complete FX chain with random devices
function PakettiMetaSynthBuildRandomFXChain(chain, device_pool, device_count, randomization_amount)
  device_count = device_count or 2
  randomization_amount = randomization_amount or 0.3
  
  local inserted_devices = {}
  
  for i = 1, device_count do
    local random_device = device_pool[math.random(1, #device_pool)]
    local device = PakettiMetaSynthInsertDevice(chain, random_device)
    
    if device then
      PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
      table.insert(inserted_devices, device)
    end
  end
  
  return inserted_devices
end

-- Selectable FX types for Group Master and Stack Master (glue-appropriate FX)
PakettiMetaSynthSelectableFXTypes = {
  { name = "Filter", device = "Analog Filter" },
  { name = "Analog Filter", device = "Analog Filter" },  -- Profile name mapping
  { name = "Digital Filter", device = "Digital Filter" },
  { name = "EQ", device = "EQ 5" },
  { name = "Saturation", device = "Distortion 2" },
  { name = "Distortion", device = "Distortion 2" },  -- Profile name mapping
  { name = "LoFi", device = "LofiMat 2" },
  { name = "Chorus", device = "Chorus 2" },
  { name = "Phaser", device = "Phaser 2" },
  { name = "Flanger", device = "Flanger 2" },
  { name = "Comb Filter", device = "Comb Filter 2" },
  { name = "Delay", device = "Delay" },
  { name = "Ring Mod", device = "RingMod 2" },
  { name = "Stereo Expander", device = "Stereo Expander" },
  { name = "Exciter", device = "Exciter" }  -- Profile name mapping (if device exists, otherwise will fail gracefully)
}

-- Get list of selectable FX type names (for GUI)
function PakettiMetaSynthGetSelectableFXTypeNames()
  local names = {}
  for _, fx in ipairs(PakettiMetaSynthSelectableFXTypes) do
    table.insert(names, fx.name)
  end
  return names
end

-- Get device name from FX type name
function PakettiMetaSynthGetDeviceForFXType(fx_type_name)
  for _, fx in ipairs(PakettiMetaSynthSelectableFXTypes) do
    if fx.name == fx_type_name then
      return fx.device
    end
  end
  return nil
end

-- Build a specific FX device by type name
function PakettiMetaSynthBuildFXByType(chain, fx_type_name, randomization_amount)
  local device_name = PakettiMetaSynthGetDeviceForFXType(fx_type_name)
  if not device_name then
    print("PakettiMetaSynth: Unknown FX type '" .. tostring(fx_type_name) .. "'")
    return nil
  end
  
  local device = PakettiMetaSynthInsertDevice(chain, device_name)
  if device then
    PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount or 0.3)
  end
  return device
end

-- Build FX devices based on mode (random or selective)
function PakettiMetaSynthBuildMasterFXDevices(chain, mode, device_count, fx_types, randomization_amount, display_prefix)
  randomization_amount = randomization_amount or 0.3
  display_prefix = display_prefix or "Master"
  
  local inserted_devices = {}
  
  if mode == "selective" and fx_types and #fx_types > 0 then
    -- Selective mode: use specified FX types
    for i = 1, device_count do
      -- Cycle through the selected types
      local type_index = ((i - 1) % #fx_types) + 1
      local fx_type_name = fx_types[type_index]
      local device = PakettiMetaSynthBuildFXByType(chain, fx_type_name, randomization_amount)
      if device then
        device.display_name = string.format("%s %s %d", display_prefix, fx_type_name, i)
        table.insert(inserted_devices, device)
      end
    end
  else
    -- Random mode: use the safe FX device pool
    for i = 1, device_count do
      local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
      local device = PakettiMetaSynthInsertDevice(chain, random_device)
      if device then
        PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
        device.display_name = string.format("%s FX %d", display_prefix, i)
        table.insert(inserted_devices, device)
      end
    end
  end
  
  return inserted_devices
end

-- ============================================================================
-- SECTION 3: CROSSFADE CURVE ENGINE
-- ============================================================================

-- Generate linear crossfade curve points (with division by zero protection)
function PakettiMetaSynthGenerateLinearCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- Simple A/B crossfade
      if frame_index == 1 then
        value = 1.0 - position
      else
        value = position
      end
    else
      -- Multi-frame crossfade
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        value = 1.0 - (distance / frame_width)
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate equal power crossfade curve points (with division by zero protection)
function PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- Simple A/B equal power crossfade
      if frame_index == 1 then
        value = math.cos(position * math.pi / 2)
      else
        value = math.sin(position * math.pi / 2)
      end
    else
      -- Multi-frame equal power crossfade
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        local normalized = distance / frame_width
        value = math.cos(normalized * math.pi / 2)
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate S-curve crossfade (smooth transitions) (with division by zero protection)
function PakettiMetaSynthGenerateSCurveCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- S-curve using smoothstep
      local t = position
      local smooth_t = t * t * (3 - 2 * t)
      
      if frame_index == 1 then
        value = 1.0 - smooth_t
      else
        value = smooth_t
      end
    else
      -- Multi-frame S-curve
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        local normalized = distance / frame_width
        local smooth_t = normalized * normalized * (3 - 2 * normalized)
        value = 1.0 - smooth_t
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate stepped/quantized crossfade curve (classic wavetable behavior)
-- Each frame gets full gain during its "slot", hard transitions between frames
function PakettiMetaSynthGenerateSteppedCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  -- Calculate the slot boundaries for this frame
  -- Frame 1 occupies 0.0 to 1/n, Frame 2 occupies 1/n to 2/n, etc.
  local slot_width = 1.0 / total_frames
  local slot_start = (frame_index - 1) * slot_width
  local slot_end = frame_index * slot_width
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    -- Check if current position is within this frame's slot
    if position >= slot_start and position < slot_end then
      value = 1.0
    elseif frame_index == total_frames and position >= slot_start then
      -- Last frame includes the endpoint
      value = 1.0
    else
      value = 0.0
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate spectral-style crossfade curve (Gaussian/bell-curve for smooth harmonic morphing)
-- This creates wider overlap regions and smoother transitions ideal for wavetable morphing
-- The Gaussian shape preserves harmonic content better during crossfades
function PakettiMetaSynthGenerateSpectralCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  -- Gaussian sigma (width) - wider for smoother morphing
  -- A larger sigma means more overlap between frames
  local sigma = 1.0 / (total_frames * 0.7)  -- Wider than linear, narrower than full overlap
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- Simple A/B spectral crossfade with Gaussian blend
      -- Use complementary Gaussian curves
      local center_a = 0.0
      local center_b = 1.0
      local sigma_2frame = 0.35  -- Wider sigma for 2-frame case
      
      if frame_index == 1 then
        -- Gaussian centered at 0, falling off toward 1
        local dist = position - center_a
        value = math.exp(-(dist * dist) / (2 * sigma_2frame * sigma_2frame))
        -- Normalize to ensure crossfade at 0.5 is equal
        value = math.cos(position * math.pi / 2)  -- Fallback to equal power for 2-frame
      else
        -- Gaussian centered at 1, falling off toward 0
        local dist = position - center_b
        value = math.exp(-(dist * dist) / (2 * sigma_2frame * sigma_2frame))
        value = math.sin(position * math.pi / 2)  -- Fallback to equal power for 2-frame
      end
    else
      -- Multi-frame Gaussian crossfade
      -- Each frame has a Gaussian envelope centered at its position
      local frame_center = (frame_index - 1) / (total_frames - 1)
      local distance = math.abs(position - frame_center)
      
      -- Gaussian envelope: e^(-(x^2)/(2*sigma^2))
      -- Adjust sigma based on number of frames for proper overlap
      local adjusted_sigma = sigma * 1.5  -- Increase overlap for spectral smoothness
      
      value = math.exp(-(distance * distance) / (2 * adjusted_sigma * adjusted_sigma))
      
      -- Apply equal power normalization to maintain constant energy
      -- Sum all frame contributions at this position and normalize
      local total_power = 0
      for f = 1, total_frames do
        local f_center = (f - 1) / (total_frames - 1)
        local f_dist = math.abs(position - f_center)
        local f_value = math.exp(-(f_dist * f_dist) / (2 * adjusted_sigma * adjusted_sigma))
        total_power = total_power + f_value * f_value
      end
      
      -- Normalize to maintain constant power (equal power style)
      if total_power > 0 then
        value = value / math.sqrt(total_power)
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate vector-style crossfade curve (4-corner XY blending within frames)
-- This creates bilinear interpolation curves for XY joystick-style control
-- Best suited for exactly 4 frames arranged in a 2x2 grid
function PakettiMetaSynthGenerateVectorCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  -- For non-4 frame cases, fall back to equal power
  if total_frames ~= 4 then
    return PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  end
  
  -- 4-frame vector arrangement:
  -- Frame 1 = Bottom-Left (BL): strong when position near 0
  -- Frame 2 = Bottom-Right (BR): strong when position near 0.33
  -- Frame 3 = Top-Left (TL): strong when position near 0.67
  -- Frame 4 = Top-Right (TR): strong when position near 1.0
  
  -- Map the 1D position to a 2D XY space
  -- Position 0-0.5 sweeps X from 0-1 at Y=0
  -- Position 0.5-1.0 sweeps Y from 0-1 at X varying
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    -- Create a circular/orbital path through XY space
    -- Use sine/cosine to create a smooth path
    local angle = position * math.pi * 2  -- Full circle
    local x = (math.cos(angle) + 1) / 2   -- 0-1 range
    local y = (math.sin(angle) + 1) / 2   -- 0-1 range
    
    -- Equal power version of bilinear interpolation
    local cos_x = math.cos(x * math.pi / 2)
    local sin_x = math.sin(x * math.pi / 2)
    local cos_y = math.cos(y * math.pi / 2)
    local sin_y = math.sin(y * math.pi / 2)
    
    if frame_index == 1 then
      value = cos_x * cos_y      -- Bottom-left
    elseif frame_index == 2 then
      value = sin_x * cos_y      -- Bottom-right
    elseif frame_index == 3 then
      value = cos_x * sin_y      -- Top-left
    else
      value = sin_x * sin_y      -- Top-right
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Master function to generate crossfade curves
function PakettiMetaSynthGenerateCrossfadeCurve(curve_type, num_points, frame_index, total_frames)
  num_points = num_points or 128
  
  if curve_type == "linear" then
    return PakettiMetaSynthGenerateLinearCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "equal_power" then
    return PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "s_curve" then
    return PakettiMetaSynthGenerateSCurveCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "stepped" then
    return PakettiMetaSynthGenerateSteppedCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "spectral" then
    return PakettiMetaSynthGenerateSpectralCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "vector" then
    return PakettiMetaSynthGenerateVectorCrossfade(num_points, frame_index, total_frames)
  else
    -- Default to equal power
    return PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  end
end

-- ============================================================================
-- SECTION 4: SAMPLE FOLDER LOADER
-- ============================================================================

-- Supported audio file extensions
PakettiMetaSynthAudioExtensions = {
  ".wav", ".aiff", ".aif", ".flac", ".ogg", ".mp3"
}

-- Check if a file has a supported audio extension
function PakettiMetaSynthIsSupportedAudioFile(filename)
  local lower_filename = filename:lower()
  for _, ext in ipairs(PakettiMetaSynthAudioExtensions) do
    if lower_filename:sub(-#ext) == ext then
      return true
    end
  end
  return false
end

-- Scan a folder for audio files
function PakettiMetaSynthScanFolder(folder_path)
  local files = {}
  
  -- Use the getfiles function from main.lua if available
  if getfiles then
    local all_files = getfiles(folder_path)
    for _, filepath in ipairs(all_files) do
      if PakettiMetaSynthIsSupportedAudioFile(filepath) then
        table.insert(files, filepath)
      end
    end
  else
    -- Fallback: try to use io.popen (may not work on all platforms)
    local cmd
    if os.platform() == "WINDOWS" then
      cmd = 'dir /b "' .. folder_path .. '"'
    else
      cmd = 'ls "' .. folder_path .. '"'
    end
    
    local handle = io.popen(cmd)
    if handle then
      for line in handle:lines() do
        if PakettiMetaSynthIsSupportedAudioFile(line) then
          local filepath = folder_path .. package.config:sub(1,1) .. line
          table.insert(files, filepath)
        end
      end
      handle:close()
    end
  end
  
  return files
end

-- Get AKWF file list (cached for performance)
function PakettiMetaSynthGetAKWFList()
  -- Return cached list if available
  if PakettiMetaSynthAKWFCache then
    return PakettiMetaSynthAKWFCache
  end
  
  local tool_path = renoise.tool().bundle_path
  local akwf_path = tool_path .. "AKWF/"
  local akwf_list_path = akwf_path .. "akwf.txt"
  
  local akwf_file = io.open(akwf_list_path, "r")
  if not akwf_file then
    print("PakettiMetaSynth: Could not find AKWF sample list at " .. akwf_list_path)
    return {}
  end
  
  local wav_files = {}
  for line in akwf_file:lines() do
    table.insert(wav_files, akwf_path .. line)
  end
  akwf_file:close()
  
  -- Cache the list
  PakettiMetaSynthAKWFCache = wav_files
  
  return wav_files
end

-- Get random samples from AKWF folder (uses cached list)
function PakettiMetaSynthGetRandomAKWFSamples(count)
  local wav_files = PakettiMetaSynthGetAKWFList()
  
  if #wav_files == 0 then
    return {}
  end
  
  -- Random selection
  local selected = {}
  for i = 1, count do
    local random_index = math.random(1, #wav_files)
    table.insert(selected, wav_files[random_index])
  end
  
  return selected
end

-- Build family cache from AKWF list (groups samples by family)
function PakettiMetaSynthBuildFamilyCache()
  if PakettiMetaSynthAKWFFamilyCache then
    return PakettiMetaSynthAKWFFamilyCache
  end
  
  local wav_files = PakettiMetaSynthGetAKWFList()
  if #wav_files == 0 then
    return {}
  end
  
  PakettiMetaSynthAKWFFamilyCache = {}
  
  -- Initialize empty arrays for each family
  for family_name, _ in pairs(PakettiMetaSynthAKWFWaveformFamilies) do
    PakettiMetaSynthAKWFFamilyCache[family_name] = {}
  end
  PakettiMetaSynthAKWFFamilyCache["unmatched"] = {}  -- For samples that don't match any family
  
  -- Categorize each sample by family
  for _, file_path in ipairs(wav_files) do
    -- Extract folder name from path (e.g., "AKWF_bw_saw" from ".../AKWF/AKWF_bw_saw/AKWF_bw_saw_0001.wav")
    local folder_name = file_path:match("AKWF/([^/]+)/")
    if folder_name then
      local matched = false
      
      -- Check against each family's patterns
      for family_name, family_data in pairs(PakettiMetaSynthAKWFWaveformFamilies) do
        for _, pattern in ipairs(family_data.patterns) do
          if folder_name:find(pattern, 1, true) then
            table.insert(PakettiMetaSynthAKWFFamilyCache[family_name], file_path)
            matched = true
            break
          end
        end
        if matched then break end
      end
      
      if not matched then
        table.insert(PakettiMetaSynthAKWFFamilyCache["unmatched"], file_path)
      end
    end
  end
  
  -- Log family counts
  for family_name, samples in pairs(PakettiMetaSynthAKWFFamilyCache) do
    if #samples > 0 then
      print(string.format("PakettiMetaSynth: Family '%s' has %d samples", family_name, #samples))
    end
  end
  
  return PakettiMetaSynthAKWFFamilyCache
end

-- Get AKWF samples filtered by waveform families
-- families: array of family names to include (e.g., {"saw", "square"})
-- count: number of samples to return
-- avoid_families: optional array of families to exclude
function PakettiMetaSynthGetAKWFSamplesByFamily(families, count, avoid_families)
  local family_cache = PakettiMetaSynthBuildFamilyCache()
  avoid_families = avoid_families or {}
  
  -- Build pool of eligible samples
  local pool = {}
  
  -- If no families specified, use all except avoided
  if not families or #families == 0 then
    for family_name, samples in pairs(family_cache) do
      local avoid = false
      for _, avoid_name in ipairs(avoid_families) do
        if family_name == avoid_name then
          avoid = true
          break
        end
      end
      if not avoid then
        for _, sample in ipairs(samples) do
          table.insert(pool, sample)
        end
      end
    end
  else
    -- Use only specified families
    for _, family_name in ipairs(families) do
      local avoid = false
      for _, avoid_name in ipairs(avoid_families) do
        if family_name == avoid_name then
          avoid = true
          break
        end
      end
      
      if not avoid and family_cache[family_name] then
        for _, sample in ipairs(family_cache[family_name]) do
          table.insert(pool, sample)
        end
      end
    end
  end
  
  -- If pool is empty, fall back to all samples
  if #pool == 0 then
    print("PakettiMetaSynth: No samples matched families, falling back to all AKWF samples")
    return PakettiMetaSynthGetRandomAKWFSamples(count)
  end
  
  -- Random selection from pool
  local selected = {}
  for i = 1, count do
    local random_index = math.random(1, #pool)
    table.insert(selected, pool[random_index])
  end
  
  return selected
end

-- Get random samples from a user folder
function PakettiMetaSynthGetRandomSamplesFromFolder(folder_path, count)
  local files = PakettiMetaSynthScanFolder(folder_path)
  
  if #files == 0 then
    return {}
  end
  
  local selected = {}
  for i = 1, count do
    local random_index = math.random(1, #files)
    table.insert(selected, files[random_index])
  end
  
  return selected
end

-- Load a sample file into an instrument sample slot
function PakettiMetaSynthLoadSampleIntoSlot(instrument, sample_index, filepath)
  -- Ensure sample slot exists
  while #instrument.samples < sample_index do
    instrument:insert_sample_at(#instrument.samples + 1)
  end
  
  local sample = instrument.samples[sample_index]
  local success = sample.sample_buffer:load_from(filepath)
  
  if success then
    -- Extract filename for sample name
    local filename = filepath:match("([^/\\]+)$") or "Sample"
    sample.name = filename:gsub("%.[^%.]+$", "")
  end
  
  return success
end

-- ============================================================================
-- SECTION 5: MODULATION BUILDER
-- ============================================================================

-- Create a new modulation set in the instrument
function PakettiMetaSynthCreateModulationSet(instrument, set_name)
  local set_index = #instrument.sample_modulation_sets + 1
  instrument:insert_sample_modulation_set_at(set_index)
  local mod_set = instrument.sample_modulation_sets[set_index]
  mod_set.name = set_name
  return mod_set, set_index
end

-- Add an AHDSR device to a modulation set
-- params can include: attack, hold, decay, sustain, release (0-1 range)
-- Optional: tempo_synced (boolean) - if true, times are beat-synced instead of ms
function PakettiMetaSynthAddAHDSRToModSet(mod_set, target_type, params)
  params = params or {}
  
  -- Get available devices
  local available = mod_set.available_devices
  local ahdsr_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("AHDSR") then
      ahdsr_path = device_path
      break
    end
  end
  
  if not ahdsr_path then
    print("PakettiMetaSynth: AHDSR device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(ahdsr_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Enable tempo sync if requested and device supports it
    if params.tempo_synced then
      if device.tempo_sync_switching_allowed then
        device.tempo_synced = true
        print("PakettiMetaSynth: AHDSR tempo sync enabled")
      else
        print("PakettiMetaSynth: AHDSR device does not support tempo sync switching")
      end
    end
    
    -- Set AHDSR parameters (clamped to 0-1 range as required by Renoise API)
    if params.attack and device.attack then
      device.attack.value = math.min(1, math.max(0, params.attack))
    end
    if params.hold and device.hold then
      device.hold.value = math.min(1, math.max(0, params.hold))
    end
    if params.decay and device.decay then
      device.decay.value = math.min(1, math.max(0, params.decay))
    end
    if params.sustain and device.sustain then
      device.sustain.value = math.min(1, math.max(0, params.sustain))
    end
    if params.release and device.release then
      device.release.value = math.min(1, math.max(0, params.release))
    end
  end
  
  return device
end

-- Add an LFO device to a modulation set
-- params can include: frequency, amount (0-1 range), mode (waveform), phase_mode, phase
-- Optional: tempo_synced (boolean) - if true, frequency is beat-synced instead of Hz
function PakettiMetaSynthAddLFOToModSet(mod_set, target_type, params)
  params = params or {}
  
  local available = mod_set.available_devices
  local lfo_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("LFO") then
      lfo_path = device_path
      break
    end
  end
  
  if not lfo_path then
    print("PakettiMetaSynth: LFO device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(lfo_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Enable tempo sync if requested and device supports it
    if params.tempo_synced then
      if device.tempo_sync_switching_allowed then
        device.tempo_synced = true
        print("PakettiMetaSynth: LFO tempo sync enabled")
      else
        print("PakettiMetaSynth: LFO device does not support tempo sync switching")
      end
    end
    
    -- Clamp frequency and amount to 0-1 range as required by Renoise API
    -- Use pcall to safely check if properties exist
    if params.frequency then
      local has_freq, freq_param = pcall(function() return device.frequency end)
      if has_freq and freq_param then
        freq_param.value = math.min(1, math.max(0, params.frequency))
      end
    end
    if params.amount then
      local has_amp, amp_param = pcall(function() return device.amplitude end)
      if has_amp and amp_param then
        amp_param.value = math.min(1, math.max(0, params.amount))
      end
    end
    
    -- LFO waveform mode (sin, saw, pulse, random)
    if params.mode then
      local has_mode, mode_param = pcall(function() return device.mode end)
      if has_mode and mode_param then
        device.mode = params.mode
      end
    end
    
    -- Handle LFO phase mode (free, retrigger, random)
    -- Phase is a DeviceParameter with range 0-360 (if device supports it)
    -- Use pcall to safely check if phase property exists and can be accessed
    local phase_param = nil
    local has_phase = pcall(function() 
      phase_param = device.phase
      return true
    end)
    
    if has_phase and phase_param then
      local phase_mode = params.phase_mode or "free"
      if phase_mode == "retrigger" then
        -- Reset phase to 0 for consistent note-on behavior
        phase_param.value = 0
      elseif phase_mode == "random" then
        -- Random phase start for each voice/instance
        phase_param.value = math.random() * 360
      elseif params.phase then
        -- Allow explicit phase value if provided (0-360)
        phase_param.value = math.min(360, math.max(0, params.phase))
      end
      -- "free" mode: leave phase at default or don't change it
    end
  end
  
  return device
end

-- Map a macro to a device parameter
function PakettiMetaSynthMapMacroToParameter(instrument, macro_index, parameter)
  if macro_index < 1 or macro_index > 8 then
    print("PakettiMetaSynth: Invalid macro index " .. tostring(macro_index))
    return false
  end
  
  local macro = instrument.macros[macro_index]
  
  -- Note: Direct mapping creation requires using the GUI or XML injection
  -- The API provides read access to mappings but not direct creation
  -- For now, we'll just set up the macro value
  macro.value = 0.5
  
  return true
end

-- Clear all devices from a modulation set
function PakettiMetaSynthClearModulationSet(mod_set)
  -- Remove devices from end to start to avoid index shifting issues
  while #mod_set.devices > 0 do
    mod_set:delete_device_at(#mod_set.devices)
  end
end

-- Apply a modulation profile to a modulation set
-- This clears existing devices and rebuilds from the profile definition
function PakettiMetaSynthApplyModulationProfile(mod_set, profile_name)
  -- Get full multi-layer profile
  local full_profile = PakettiMetaSynthGetProfile(profile_name)
  if not full_profile then
    print("PakettiMetaSynth: Unknown profile '" .. tostring(profile_name) .. "', using default")
    full_profile = PakettiMetaSynthGetProfile("default")
  end
  
  -- Extract modulation rules from top-level modulation layer (new structure)
  local profile = full_profile.modulation
  if not profile then
    -- Fallback: try backward compatibility (old flat structure via metatable)
    profile = PakettiMetaSynthModulationProfiles[profile_name]
    if not profile then
      print("PakettiMetaSynth: No modulation data for profile '" .. tostring(profile_name) .. "'")
      return false
    end
  end
  
  -- Clear existing modulation devices
  PakettiMetaSynthClearModulationSet(mod_set)
  
  -- Handle neutral_none profile - no envelope at all
  if profile_name == "neutral_none" then
    print(string.format("PakettiMetaSynth: Applied neutral profile '%s' (no modulation)", profile_name))
    return true
  end
  
  -- Add Volume AHDSR if defined
  if profile.volume_ahdsr then
    PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, profile.volume_ahdsr)
  end
  
  -- Add Filter AHDSR if defined
  if profile.filter_ahdsr then
    PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, profile.filter_ahdsr)
  end
  
  -- Add Pitch AHDSR if defined
  if profile.pitch_ahdsr then
    local pitch_params = {
      attack = profile.pitch_ahdsr.attack,
      hold = profile.pitch_ahdsr.hold,
      decay = profile.pitch_ahdsr.decay,
      sustain = profile.pitch_ahdsr.sustain,
      release = profile.pitch_ahdsr.release
    }
    local pitch_env = PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, pitch_params)
    -- Set envelope amount if specified
    if pitch_env and profile.pitch_ahdsr.amount then
      if pitch_env.amplitude then
        pitch_env.amplitude.value = math.abs(profile.pitch_ahdsr.amount)
      end
    end
  end
  
  -- Add Velocity device for volume if velocity_volume is significant
  if profile.velocity_volume and profile.velocity_volume > 0.1 then
    PakettiMetaSynthAddVelocityToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, {
      amount = profile.velocity_volume
    })
  end
  
  -- Add Velocity device for filter if velocity_filter is significant
  if profile.velocity_filter and profile.velocity_filter > 0.1 then
    PakettiMetaSynthAddVelocityToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, {
      amount = profile.velocity_filter
    })
  end
  
  -- Add Volume LFO (tremolo) if defined
  if profile.volume_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, profile.volume_lfo)
  end
  
  -- Add Pitch LFO (vibrato) if defined
  if profile.pitch_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, profile.pitch_lfo)
  end
  
  -- Add Filter LFO if defined
  if profile.filter_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, profile.filter_lfo)
  end
  
  -- Set filter type and parameters if filter cutoff or resonance is defined
  if profile.filter_cutoff or profile.filter_resonance then
    -- Enable low-pass filter if cutoff is specified
    if profile.filter_cutoff then
      mod_set.filter_type = "LP Clean"
      -- Set base cutoff value on the modulation set's filter input
      if mod_set.cutoff_input then
        mod_set.cutoff_input.value = profile.filter_cutoff
      end
    end
    -- Set resonance value on the modulation set's resonance input
    if profile.filter_resonance and mod_set.resonance_input then
      mod_set.resonance_input.value = profile.filter_resonance
    end
  end
  
  -- Add Key Tracking device for filter cutoff if keytracking is defined
  if profile.filter_keytrack and profile.filter_keytrack > 0.1 then
    PakettiMetaSynthAddKeyTrackingToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, {
      amount = profile.filter_keytrack
    })
  end
  
  -- Add Volume Stepper if defined
  if profile.volume_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, profile.volume_stepper)
  end
  
  -- Add Filter Stepper if defined
  if profile.filter_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, profile.filter_stepper)
  end
  
  -- Add Pitch Stepper if defined
  if profile.pitch_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, profile.pitch_stepper)
  end
  
  -- Add Arp Pattern if defined
  if profile.arp_pattern and profile.arp_pattern.enabled then
    PakettiMetaSynthAddArpPatternToModSet(mod_set, profile.arp_pattern)
  end
  
  print(string.format("PakettiMetaSynth: Applied modulation profile '%s' (%s)", 
    profile_name, full_profile.description or ""))
  
  return true
end

-- Apply modulation rules directly (bypasses profile lookup)
-- This is used when modulation has been resolved via PakettiMetaSynthResolveModulationProfile
-- Optional third parameter: architecture - if provided, uses architecture.modulation_layer.tempo_synced
function PakettiMetaSynthApplyModulationRules(mod_set, modulation_rules, architecture)
  if not modulation_rules then
    print("PakettiMetaSynth: No modulation rules provided")
    return false
  end
  
  -- Clear existing modulation devices
  PakettiMetaSynthClearModulationSet(mod_set)
  
  -- Use the modulation rules directly (same logic as ApplyModulationProfile)
  local profile = modulation_rules
  
  -- Check for global tempo sync setting from architecture
  local global_tempo_synced = false
  if architecture and architecture.modulation_layer and architecture.modulation_layer.tempo_synced then
    global_tempo_synced = true
  end
  
  -- Helper to merge tempo_synced into params
  local function with_tempo_sync(params)
    if params then
      -- Use profile-specific tempo_synced if set, otherwise use global setting
      if params.tempo_synced == nil and global_tempo_synced then
        local merged = {}
        for k, v in pairs(params) do merged[k] = v end
        merged.tempo_synced = true
        return merged
      end
    end
    return params
  end
  
  -- Add Volume AHDSR if defined
  if profile.volume_ahdsr then
    PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, with_tempo_sync(profile.volume_ahdsr))
  end
  
  -- Add Filter AHDSR if defined
  if profile.filter_ahdsr then
    PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, with_tempo_sync(profile.filter_ahdsr))
  end
  
  -- Add Pitch AHDSR if defined
  if profile.pitch_ahdsr then
    local pitch_params = {
      attack = profile.pitch_ahdsr.attack,
      hold = profile.pitch_ahdsr.hold,
      decay = profile.pitch_ahdsr.decay,
      sustain = profile.pitch_ahdsr.sustain,
      release = profile.pitch_ahdsr.release,
      tempo_synced = profile.pitch_ahdsr.tempo_synced
    }
    local pitch_env = PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, with_tempo_sync(pitch_params))
    -- Note: SampleAhdsrModulationDevice does not have an 'amplitude' property
    -- Pitch envelope intensity is controlled by mod_set.pitch_range instead
  end
  
  -- Add Velocity device for volume if velocity_volume is significant
  if profile.velocity_volume and profile.velocity_volume > 0.1 then
    PakettiMetaSynthAddVelocityToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, {
      amount = profile.velocity_volume
    })
  end
  
  -- Add Velocity device for filter if velocity_filter is significant
  if profile.velocity_filter and profile.velocity_filter > 0.1 then
    PakettiMetaSynthAddVelocityToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, {
      amount = profile.velocity_filter
    })
  end
  
  -- Add Volume LFO (tremolo) if defined (with global tempo sync support)
  if profile.volume_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, with_tempo_sync(profile.volume_lfo))
  end
  
  -- Add Pitch LFO (vibrato) if defined (with global tempo sync support)
  if profile.pitch_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, with_tempo_sync(profile.pitch_lfo))
  end
  
  -- Add Filter LFO if defined (with global tempo sync support)
  if profile.filter_lfo then
    PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, with_tempo_sync(profile.filter_lfo))
  end
  
  -- Set filter type and parameters if filter cutoff or resonance is defined
  if profile.filter_cutoff or profile.filter_resonance then
    if profile.filter_cutoff then
      mod_set.filter_type = "LP Clean"
      if mod_set.cutoff_input then
        mod_set.cutoff_input.value = profile.filter_cutoff
      end
    end
    if profile.filter_resonance and mod_set.resonance_input then
      mod_set.resonance_input.value = profile.filter_resonance
    end
  end
  
  -- Add Key Tracking device for filter if filter_keytrack is significant
  if profile.filter_keytrack and profile.filter_keytrack > 0.1 then
    PakettiMetaSynthAddKeyTrackingToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, {
      amount = profile.filter_keytrack
    })
  end
  
  -- Add Volume Stepper if defined
  if profile.volume_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, profile.volume_stepper)
  end
  
  -- Add Filter Stepper if defined
  if profile.filter_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_CUTOFF, profile.filter_stepper)
  end
  
  -- Add Pitch Stepper if defined
  if profile.pitch_stepper then
    PakettiMetaSynthAddStepperToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, profile.pitch_stepper)
  end
  
  -- Add Arp Pattern if defined
  if profile.arp_pattern and profile.arp_pattern.enabled then
    PakettiMetaSynthAddArpPatternToModSet(mod_set, profile.arp_pattern)
  end
  
  return true
end

-- Add a Velocity device to a modulation set
function PakettiMetaSynthAddVelocityToModSet(mod_set, target_type, params)
  params = params or {}
  
  local available = mod_set.available_devices
  local velocity_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("Velocity") then
      velocity_path = device_path
      break
    end
  end
  
  if not velocity_path then
    print("PakettiMetaSynth: Velocity device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(velocity_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Velocity tracking uses min/max range (0-127)
    -- Convert amount (0-1) to a velocity range
    if params.amount then
      local amount = params.amount
      -- Set min based on amount: higher amount = lower min (more range)
      -- amount 0 = min 127 (no effect), amount 1 = min 0 (full range)
      local min_vel = math.floor(127 * (1 - amount))
      if device.min then
        device.min.value = min_vel
      end
      if device.max then
        device.max.value = 127
      end
    end
  end
  
  return device
end

-- Add a Key Tracking device to a modulation set
function PakettiMetaSynthAddKeyTrackingToModSet(mod_set, target_type, params)
  params = params or {}
  
  local available = mod_set.available_devices
  local keytrack_path = nil
  
  -- Search for Key Tracking device in available devices
  for _, device_path in ipairs(available) do
    if device_path:find("Key Tracking") or device_path:find("KeyTracking") or device_path:find("Key") then
      keytrack_path = device_path
      break
    end
  end
  
  if not keytrack_path then
    print("PakettiMetaSynth: Key Tracking device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(keytrack_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Key tracking uses min/max note range (0-119)
    -- Convert amount (0-1) to a key range
    if params.amount then
      local amount = params.amount
      -- Set min/max based on amount for key tracking range
      -- amount 0 = small range, amount 1 = full keyboard range
      if device.min and device.max then
        -- Center the range around middle C (60)
        local half_range = math.floor(60 * amount)
        device.min.value = math.max(0, 60 - half_range)
        device.max.value = math.min(119, 60 + half_range)
      end
    end
  end
  
  return device
end

-- ============================================================================
-- STEPPER MODULATION
-- Adds step sequencer-style modulation to a modulation set
-- Creates rhythmic, stepped changes to volume/pitch/filter
-- ============================================================================

-- Convert rate string to LFO frequency
function PakettiMetaSynthStepRateToFrequency(rate_str, bpm)
  bpm = bpm or 120  -- Default BPM
  local beats_per_second = bpm / 60
  
  local rate_map = {
    ["1/1"] = beats_per_second / 4,
    ["1/2"] = beats_per_second / 2,
    ["1/4"] = beats_per_second,
    ["1/8"] = beats_per_second * 2,
    ["1/16"] = beats_per_second * 4,
    ["1/32"] = beats_per_second * 8,
    ["1/64"] = beats_per_second * 16,
    ["1/4T"] = beats_per_second * 1.5,
    ["1/8T"] = beats_per_second * 3,
    ["1/16T"] = beats_per_second * 6,
  }
  
  return rate_map[rate_str] or beats_per_second * 4  -- Default to 1/16
end

-- Add a Stepper device to a modulation set
-- params: { steps = {1.0, 0.8, 0.6, 0.4, ...}, rate = "1/16", smooth = false }
function PakettiMetaSynthAddStepperToModSet(mod_set, target_type, params)
  params = params or {}
  local steps = params.steps or {1.0, 0.5, 0.75, 0.25}
  local rate = params.rate or "1/16"
  local smooth = params.smooth or false
  
  -- Renoise doesn't have a native "Stepper" device, but we can use an LFO with custom envelope
  -- Or we create an AHDSR with very short times that acts like a step
  -- For now, we'll use an LFO and generate a stepped custom envelope
  
  local available = mod_set.available_devices
  local lfo_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("LFO") then
      lfo_path = device_path
      break
    end
  end
  
  if not lfo_path then
    print("PakettiMetaSynth: LFO device not found for stepper emulation")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(lfo_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Calculate LFO frequency based on rate and step count
    local bpm = renoise.song().transport.bpm
    local base_freq = PakettiMetaSynthStepRateToFrequency(rate, bpm)
    local step_freq = base_freq / #steps
    
    -- Set LFO to custom mode (mode 5 = Custom in some versions)
    if device.mode then
      -- Try to set to custom/sample-and-hold mode
      device.mode.value = 4  -- Sample & Hold for stepped behavior
    end
    
    -- Set frequency
    if device.frequency then
      device.frequency.value = step_freq
    end
    
    -- Set amplitude based on step range
    local max_step = 0
    local min_step = 1
    for _, v in ipairs(steps) do
      max_step = math.max(max_step, v)
      min_step = math.min(min_step, v)
    end
    
    if device.amplitude then
      device.amplitude.value = (max_step - min_step) * 0.5
    end
    
    if device.offset then
      device.offset.value = (max_step + min_step) * 0.5
    end
    
    print(string.format("PakettiMetaSynth: Added Stepper (LFO-based) with %d steps at %s", #steps, rate))
  end
  
  return device
end

-- ============================================================================
-- ARP PATTERN MODULATION
-- Adds arpeggiator-style pitch modulation patterns
-- Creates musical note sequences through pitch modulation
-- ============================================================================

-- Predefined arp patterns (semitone offsets)
METASYNTH_ARP_PATTERNS = {
  up = {0, 4, 7, 12},           -- Major chord ascending
  down = {12, 7, 4, 0},         -- Major chord descending
  updown = {0, 4, 7, 12, 7, 4}, -- Major chord up-down
  minor_up = {0, 3, 7, 12},     -- Minor chord ascending
  minor_down = {12, 7, 3, 0},   -- Minor chord descending
  octave = {0, 12, 0, 12},      -- Octave bounce
  fifth = {0, 7, 0, 7},         -- Fifth bounce
  random = nil,                  -- Will be generated randomly
  custom = nil                   -- User-defined
}

-- Add an Arp Pattern to a modulation set (pitch modulation)
-- params: { pattern = "up", rate = "1/16", octaves = 1, custom_steps = nil }
function PakettiMetaSynthAddArpPatternToModSet(mod_set, params)
  params = params or {}
  local pattern_name = params.pattern or "up"
  local rate = params.rate or "1/16"
  local octaves = params.octaves or 1
  local custom_steps = params.custom_steps
  
  -- Get pattern steps
  local pattern_steps = METASYNTH_ARP_PATTERNS[pattern_name]
  if pattern_name == "custom" and custom_steps then
    pattern_steps = custom_steps
  elseif pattern_name == "random" then
    -- Generate random pattern
    pattern_steps = {}
    local notes = {0, 3, 4, 5, 7, 9, 11, 12}  -- Scale degrees
    for i = 1, math.random(4, 8) do
      table.insert(pattern_steps, notes[math.random(1, #notes)])
    end
  end
  
  if not pattern_steps then
    pattern_steps = {0, 4, 7, 12}  -- Default to major up
  end
  
  -- Extend pattern for octaves
  if octaves > 1 then
    local extended = {}
    for o = 0, octaves - 1 do
      for _, step in ipairs(pattern_steps) do
        table.insert(extended, step + (o * 12))
      end
    end
    pattern_steps = extended
  end
  
  -- Use LFO targeting pitch with calculated frequency
  local available = mod_set.available_devices
  local lfo_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("LFO") then
      lfo_path = device_path
      break
    end
  end
  
  if not lfo_path then
    print("PakettiMetaSynth: LFO device not found for arp pattern")
    return nil
  end
  
  local target_type = renoise.SampleModulationDevice.TARGET_PITCH
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(lfo_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Calculate frequency based on rate and pattern length
    local bpm = renoise.song().transport.bpm
    local base_freq = PakettiMetaSynthStepRateToFrequency(rate, bpm)
    local pattern_freq = base_freq / #pattern_steps
    
    -- Set to sample-and-hold mode for stepped arp
    if device.mode then
      device.mode.value = 4  -- Sample & Hold
    end
    
    -- Set frequency
    if device.frequency then
      device.frequency.value = pattern_freq
    end
    
    -- Calculate amplitude based on pitch range
    local max_semitones = 0
    for _, v in ipairs(pattern_steps) do
      max_semitones = math.max(max_semitones, math.abs(v))
    end
    
    -- Pitch amplitude: semitones / 128 (Renoise pitch range)
    if device.amplitude then
      device.amplitude.value = max_semitones / 128
    end
    
    print(string.format("PakettiMetaSynth: Added Arp Pattern '%s' (%d steps, %d octaves) at %s",
      pattern_name, #pattern_steps, octaves, rate))
  end
  
  return device
end

-- ============================================================================
-- MULTI-LAYER PROFILE RESOLUTION
-- Resolves the appropriate profile for a specific layer based on override chain
-- Override chain: oscillator > group > architecture.global_profile > "default"
-- ============================================================================

-- Resolve the profile name for a given context
-- Returns the profile name that should be used
function PakettiMetaSynthResolveProfileName(osc, group, architecture)
  -- Override chain: osc.profile_override > osc.modulation_profile (legacy) >
  --                 group.profile_override > group.modulation_profile (legacy) >
  --                 architecture.global_profile > "default"
  if osc then
    if osc.profile_override then return osc.profile_override end
    if osc.modulation_profile then return osc.modulation_profile end
  end
  if group then
    if group.profile_override then return group.profile_override end
    if group.modulation_profile then return group.modulation_profile end
  end
  if architecture and architecture.global_profile then
    return architecture.global_profile
  end
  return "default"
end

-- Get the full profile data for a given profile name
-- Returns the complete multi-layer profile table
function PakettiMetaSynthGetProfile(profile_name)
  local profile = PakettiMetaSynthProfiles[profile_name]
  if not profile then
    print("PakettiMetaSynth: Profile '" .. tostring(profile_name) .. "' not found, using 'default'")
    profile = PakettiMetaSynthProfiles["default"]
  end
  return profile
end

-- Resolve and return profile rules for a specific LAYER
-- layer: "oscillator", "frame", "modulation", "oscillator_groups", "group_frame", "total_group_fx", "total_group_frames", "global_fx", "sample_selection"
-- Returns the layer-specific rules table, or empty table with defaults if missing
function PakettiMetaSynthResolveProfile(layer, osc, group, architecture)
  local profile_name = PakettiMetaSynthResolveProfileName(osc, group, architecture)
  local profile = PakettiMetaSynthGetProfile(profile_name)
  
  if not profile then
    return PakettiMetaSynthGetDefaultLayerRules(layer)
  end
  
  local layer_rules = profile[layer]
  if not layer_rules then
    return PakettiMetaSynthGetDefaultLayerRules(layer)
  end
  
  return layer_rules
end

-- Get default rules for a layer when profile is missing or incomplete
function PakettiMetaSynthGetDefaultLayerRules(layer)
  local defaults = {
    oscillator = {
      unison_range = {1, 3},
      frame_count_range = {1, 3},
      detune_range = {5, 20},
      pan_spread_range = {0.2, 0.5},
      sample_count_range = {1, 2},
    },
    frame = {
      morph_enabled = true,
      morph_speed = "medium",
      fx_tendencies = {"Analog Filter", "Chorus"},
      fx_count_range = {1, 2},
    },
    -- Modulation is now a SEPARATE layer (not nested in group)
    modulation = {
      enabled = true,
      volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.2, sustain = 0.7, release = 0.3 },
      filter_ahdsr = { attack = 0.02, hold = 0.0, decay = 0.3, sustain = 0.5, release = 0.3 },
      pitch_ahdsr = nil,
      volume_lfo = nil,
      pitch_lfo = nil,
      filter_lfo = nil,
      velocity_volume = 0.5,
      velocity_filter = 0.3,
      filter_keytrack = 0.4,
      filter_cutoff = 0.6,
      filter_resonance = 0.2,
    },
    -- Oscillator Groups - summing, organization, oscillator group FX, wavetable/vector control
    oscillator_groups = {
      crossfade_enabled = true,
      scan_speed = "medium",
      lfo_rate_preset = "medium",
      osc_group_fx_enabled = true,
      osc_group_fx_tendencies = {"Analog Filter", "Chorus"},
      osc_group_fx_count_range = {1, 2},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    -- Group frames - meta-wavetable at group level (default OFF)
    group_frame = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    -- Total Group FX - FX after all groups summed (Stack Master FX)
    total_group_fx = {
      enabled = true,
      tendencies = {"Analog Filter", "Chorus"},
      count_range = {1, 2},
    },
    -- Total Group Frames - frame morphing at total summed groups level (default OFF)
    total_group_frames = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    global_fx = {
      enabled = true,
      tendencies = {"Reverb"},
      reverb_size = "medium",
    },
    -- Sample Selection - AKWF family preferences
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"basic", "saw"},
      avoid_families = {},
    },
  }
  
  return defaults[layer] or {}
end

-- ============================================================================
-- FX PROFILE RESOLUTION - Get FX tendencies from FX profile or sound profile
-- Override chain: group.fx_profile_override > architecture.fx_profile_override > sound profile
-- Returns: { frame_fx, group_fx, global_fx } or nil (use sound profile)
-- ============================================================================
function PakettiMetaSynthResolveFXProfile(layer, group, architecture)
  -- layer: "frame", "group" (oscillator group FX), "total_group" (total group FX), "global" - which FX level to resolve
  
  -- Check group-level FX override first
  if group and group.fx_profile_override then
    local fx_profile = PakettiMetaSynthFXProfiles[group.fx_profile_override]
    if fx_profile then
      if layer == "frame" then return fx_profile.frame_fx or {}
      elseif layer == "group" then return fx_profile.group_fx or {}  -- Oscillator group FX (per-group)
      elseif layer == "total_group" then return fx_profile.total_group_fx or {}  -- Total Group FX (Stack Master)
      elseif layer == "global" then return fx_profile.global_fx or {}
      end
    end
  end
  
  -- Check architecture-level FX override
  if architecture and architecture.fx_profile_override then
    local fx_profile = PakettiMetaSynthFXProfiles[architecture.fx_profile_override]
    if fx_profile then
      if layer == "frame" then return fx_profile.frame_fx or {}
      elseif layer == "group" then return fx_profile.group_fx or {}  -- Oscillator group FX (per-group)
      elseif layer == "total_group" then return fx_profile.total_group_fx or {}  -- Total Group FX (Stack Master)
      elseif layer == "global" then return fx_profile.global_fx or {}
      end
    end
  end
  
  -- No FX profile override - return nil to signal "use sound profile"
  return nil
end

-- Get FX tendencies for a specific layer, considering FX profile overrides
-- Falls back to sound profile if no FX override is set
function PakettiMetaSynthGetFXTendencies(layer, osc, group, architecture)
  -- First check if there's an FX profile override
  local fx_tendencies = PakettiMetaSynthResolveFXProfile(layer, group, architecture)
  if fx_tendencies then
    return fx_tendencies
  end
  
  -- Fall back to sound profile's FX tendencies
  if layer == "frame" then
    local frame_rules = PakettiMetaSynthResolveProfile("frame", osc, group, architecture)
    return frame_rules.fx_tendencies or {}
  elseif layer == "group" then
    -- Oscillator group FX (per-group FX)
    local osc_group_rules = PakettiMetaSynthResolveProfile("oscillator_groups", osc, group, architecture)
    return osc_group_rules.osc_group_fx_tendencies or {}
  elseif layer == "total_group" then
    -- Total Group FX (Stack Master FX)
    local total_group_fx_rules = PakettiMetaSynthResolveProfile("total_group_fx", osc, group, architecture)
    return total_group_fx_rules.tendencies or {}
  elseif layer == "global" then
    local global_fx_rules = PakettiMetaSynthResolveProfile("global_fx", osc, group, architecture)
    return global_fx_rules.tendencies or {}
  end
  
  return {}
end

-- ============================================================================
-- MODULATION LAYER RESOLUTION - Independent from other layers
-- Checks architecture.modulation_layer.profile_override first, then falls back
-- to the normal profile resolution chain
-- ============================================================================
function PakettiMetaSynthResolveModulationProfile(osc, group, architecture)
  -- First check if there's a modulation layer override in the architecture
  if architecture and architecture.modulation_layer then
    -- If custom modulation is defined, use it directly
    if architecture.modulation_layer.custom_modulation then
      return architecture.modulation_layer.custom_modulation
    end
    -- If modulation profile override is set, resolve from that profile
    if architecture.modulation_layer.profile_override then
      local mod_profile = PakettiMetaSynthGetProfile(architecture.modulation_layer.profile_override)
      if mod_profile and mod_profile.modulation then
        return mod_profile.modulation
      end
    end
  end
  
  -- Fall back to normal profile resolution chain
  local profile_name = PakettiMetaSynthResolveProfileName(osc, group, architecture)
  local profile = PakettiMetaSynthGetProfile(profile_name)
  
  if profile and profile.modulation then
    return profile.modulation
  end
  
  return PakettiMetaSynthGetDefaultLayerRules("modulation")
end

-- Helper: Get modulation rules (backward compatibility wrapper)
function PakettiMetaSynthResolveModulation(osc, group, architecture)
  return PakettiMetaSynthResolveModulationProfile(osc, group, architecture)
end

-- ============================================================================
-- APPLY PROFILE DEFAULTS TO GROUP
-- Populates group settings from a selected profile's rules
-- Used by "Load Defaults" button in UI
-- ============================================================================
function PakettiMetaSynthApplyProfileDefaultsToGroup(group, profile_name, architecture)
  local profile = PakettiMetaSynthGetProfile(profile_name)
  if not profile then
    print("PakettiMetaSynth: Profile '" .. tostring(profile_name) .. "' not found")
    return false
  end
  
  -- Apply OSCILLATOR GROUPS rules (Layer 4)
  local osc_group_rules = profile.oscillator_groups or {}
  group.group_crossfade_enabled = osc_group_rules.crossfade_enabled or false
  group.group_lfo_rate_preset = osc_group_rules.lfo_rate_preset or "medium"
  
  -- Apply OSCILLATOR GROUP FX rules (per-group FX from Layer 4)
  group.group_master_fx_enabled = osc_group_rules.osc_group_fx_enabled ~= false
  local fx_count_range = osc_group_rules.osc_group_fx_count_range or {1, 2}
  group.group_master_fx_count = math.max(1, math.min(5, math.random(math.max(1, fx_count_range[1]), fx_count_range[2])))
  
  -- Set FX types from tendencies
  group.group_master_fx_types = {}
  local tendencies = osc_group_rules.osc_group_fx_tendencies or {}
  if #tendencies > 0 then
    group.group_master_fx_mode = "selective"
    for i = 1, math.min(group.group_master_fx_count, #tendencies) do
      table.insert(group.group_master_fx_types, tendencies[i])
    end
  else
    group.group_master_fx_mode = "random"
  end
  
  -- Apply wavetable/vector control settings from Layer 4
  architecture.group_scan_enabled = osc_group_rules.wavetable_scan_enabled or false
  architecture.vector_enabled = osc_group_rules.vector_enabled or false
  
  -- Apply GROUP FRAME rules
  local group_frame_rules = profile.group_frame or {}
  group.group_frames_enabled = group_frame_rules.enabled or false
  local frame_count_range = group_frame_rules.frame_count_range or {1, 1}
  group.group_frame_count = math.random(frame_count_range[1], frame_count_range[2])
  group.group_frame_morph_enabled = group_frame_rules.morph_enabled or false
  group.group_frame_morph_speed = group_frame_rules.morph_speed or "none"
  
  -- Apply OSCILLATOR rules to all oscillators in this group
  local osc_rules = profile.oscillator or {}
  local frame_rules = profile.frame or {}
  
  for _, osc in ipairs(group.oscillators) do
    -- Apply oscillator-level defaults
    local unison_range = osc_rules.unison_range or {1, 3}
    osc.unison_voices = math.random(unison_range[1], unison_range[2])
    
    local frame_range = osc_rules.frame_count_range or {1, 3}
    osc.frame_count = math.random(frame_range[1], frame_range[2])
    
    local detune_range = osc_rules.detune_range or {5, 20}
    osc.detune_spread = math.random(detune_range[1], detune_range[2])
    
    local pan_range = osc_rules.pan_spread_range or {0.2, 0.5}
    osc.pan_spread = pan_range[1] + math.random() * (pan_range[2] - pan_range[1])
    
    -- Apply frame FX settings
    osc.osc_fx_enabled = frame_rules.morph_enabled or false
    local fx_count_range = frame_rules.fx_count_range or {1, 2}
    osc.osc_fx_count = math.random(fx_count_range[1], fx_count_range[2])
    -- Clamp to 1-5 when enabled (validation requires 1-5 when enabled)
    if osc.osc_fx_enabled then
      if osc.osc_fx_count < 1 then
        osc.osc_fx_count = 1
      elseif osc.osc_fx_count > 5 then
        osc.osc_fx_count = 5
      end
    end
    osc.osc_fx_types = {}
    local frame_fx = frame_rules.fx_tendencies or {}
    if #frame_fx > 0 then
      osc.osc_fx_mode = "selective"
      for i = 1, math.min(osc.osc_fx_count, #frame_fx) do
        table.insert(osc.osc_fx_types, frame_fx[i])
      end
    else
      osc.osc_fx_mode = "random"
    end
  end
  
  print("PakettiMetaSynth: Applied profile '" .. profile_name .. "' defaults to group")
  return true
end

-- Helper: Get a value within a range from profile rules
function PakettiMetaSynthGetValueInRange(range)
  if not range or type(range) ~= "table" or #range < 2 then
    return 1
  end
  local min_val, max_val = range[1], range[2]
  if min_val == max_val then
    return min_val
  end
  return min_val + math.random() * (max_val - min_val)
end

-- Helper: Get an integer within a range from profile rules
function PakettiMetaSynthGetIntInRange(range)
  if not range or type(range) ~= "table" or #range < 2 then
    return 1
  end
  local min_val, max_val = range[1], range[2]
  return math.random(math.floor(min_val), math.floor(max_val))
end

-- Get a random modulation profile name from the available profiles
function PakettiMetaSynthGetRandomModulationProfile()
  local profile_count = #PakettiMetaSynthModulationProfileNames
  local random_index = math.random(1, profile_count)
  return PakettiMetaSynthModulationProfileNames[random_index]
end

-- Get a contextually appropriate modulation profile based on architecture hints
function PakettiMetaSynthGetProfileForContext(frame_count, is_bass_range, is_percussive)
  -- Weight pools based on context - using new profile names
  local weighted_pool = {}
  
  if is_percussive then
    -- Percussive context: favor short envelopes
    weighted_pool = {
      "pluck_percussive", "pluck_percussive", "pluck_short", 
      "arp_tight", "arp_rhythmic", "fx_percussive", "bell"
    }
  elseif is_bass_range then
    -- Bass range: favor bass profiles
    weighted_pool = {
      "bass_tight", "bass_tight", "bass_sustain", "bass_filter", 
      "bass_wide", "bass_dynamic", "keys_sustain"
    }
  elseif frame_count and frame_count > 2 then
    -- Multiple frames suggest evolving sounds: favor pads and leads
    weighted_pool = {
      "pad_slow", "pad_slow", "pad_evolving", "pad_ensemble",
      "lead_smooth", "lead_wide", "strings"
    }
  else
    -- General pool with balanced weights
    weighted_pool = {
      "pluck_short", "pluck_natural", "pluck_soft",
      "bass_tight", "bass_sustain",
      "pad_slow", "pad_evolving",
      "lead_expressive", "lead_smooth",
      "keys_dynamic", "keys_sustain", "bell", "strings", "brass"
    }
  end
  
  return weighted_pool[math.random(1, #weighted_pool)]
end

-- Get a random sound category
function PakettiMetaSynthGetRandomSoundCategory()
  local category_count = #PakettiMetaSynthSoundCategories
  local random_index = math.random(1, category_count)
  return PakettiMetaSynthSoundCategories[random_index]
end

-- Get profile name from sound category name
function PakettiMetaSynthGetProfileFromCategory(category_name)
  for _, cat in ipairs(PakettiMetaSynthSoundCategories) do
    if cat.name == category_name then
      return cat.profile
    end
  end
  return "default"
end

-- Get sound category index by name
function PakettiMetaSynthGetCategoryIndex(category_name)
  for i, cat in ipairs(PakettiMetaSynthSoundCategories) do
    if cat.name == category_name then
      return i
    end
  end
  return 1
end

-- Get category by profile name
function PakettiMetaSynthGetCategoryByProfile(profile_name)
  for _, cat in ipairs(PakettiMetaSynthSoundCategories) do
    if cat.profile == profile_name then
      return cat
    end
  end
  return nil
end

-- Apply modulation profile to an existing instrument's modulation set by index
function PakettiMetaSynthApplyProfileToInstrument(instrument, mod_set_index, profile_name)
  if not instrument then
    print("PakettiMetaSynth: No instrument provided")
    return false
  end
  
  if mod_set_index < 1 or mod_set_index > #instrument.sample_modulation_sets then
    print("PakettiMetaSynth: Invalid modulation set index " .. tostring(mod_set_index))
    return false
  end
  
  local mod_set = instrument.sample_modulation_sets[mod_set_index]
  return PakettiMetaSynthApplyModulationProfile(mod_set, profile_name)
end

-- Apply modulation profile to all modulation sets in an instrument
function PakettiMetaSynthApplyProfileToAllModSets(instrument, profile_name)
  if not instrument then
    print("PakettiMetaSynth: No instrument provided")
    return false
  end
  
  local count = 0
  for i = 1, #instrument.sample_modulation_sets do
    if PakettiMetaSynthApplyProfileToInstrument(instrument, i, profile_name) then
      count = count + 1
    end
  end
  
  print(string.format("PakettiMetaSynth: Applied profile '%s' to %d modulation sets", profile_name, count))
  return count > 0
end

-- ============================================================================
-- SECTION 6: FRAME-BASED FX ROUTING
-- ============================================================================

-- Assign a sample to a specific FX chain
function PakettiMetaSynthAssignSampleToFXChain(sample, chain_index)
  sample.device_chain_index = chain_index
end

-- Assign a sample to a specific modulation set
function PakettiMetaSynthAssignSampleToModSet(sample, mod_set_index)
  sample.modulation_set_index = mod_set_index
end

-- Build frame-based FX routing for an oscillator
function PakettiMetaSynthBuildFrameRouting(instrument, osc_config, base_chain_index, crossfade_config)
  local chains_created = {}
  local frame_count = osc_config.frame_count
  
  for frame = 1, frame_count do
    local chain_name = string.format("%s Frame %d", osc_config.name, frame)
    local chain, chain_index = PakettiMetaSynthCreateFXChain(instrument, chain_name)
    
    -- Add random FX if enabled
    if osc_config.fx_randomization and osc_config.fx_randomization.enabled then
      PakettiMetaSynthBuildRandomFXChain(
        chain, 
        osc_config.fx_randomization.device_pool or PakettiMetaSynthSafeFXDevices,
        2,
        osc_config.fx_randomization.param_randomization or 0.3
      )
    end
    
    -- Add crossfade gainer at the end
    local crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      crossfade_config.curve_type,
      128,
      frame,
      frame_count
    )
    
    -- Create gainer with initial gain based on frame position
    local initial_gain = crossfade_curve[1].value
    local gainer, gainer_position = PakettiMetaSynthCreateGainer(chain, initial_gain, "Crossfade Gain")
    
    -- DEBUG: Print gainer info
    print(string.format("DEBUG Frame %d: Created Gainer at position %d, chain has %d devices total",
      frame, gainer_position, #chain.devices))
    
    -- If using LFO control, create LFO with crossfade envelope and route to gainer
    local lfo = nil
    if crossfade_config.control_source == "lfo" and frame_count > 1 then
      print(string.format("DEBUG Frame %d: Creating LFO to route to Gainer at position %d, param 1 (Gain)",
        frame, gainer_position))
      
      -- Calculate LFO frequency from rate settings
      local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
        crossfade_config.lfo_rate_mode,
        crossfade_config.lfo_rate_free,
        crossfade_config.lfo_rate_sync,
        crossfade_config.lfo_rate_preset
      )
      
      -- Route LFO to the Gainer's gain parameter (parameter 1)
      lfo = PakettiMetaSynthCreateCrossfadeLFO(
        chain, 
        crossfade_curve, 
        "Frame " .. frame .. " Crossfade",
        gainer_position,  -- Destination device index
        1,                -- Destination parameter index (Gain)
        lfo_freq          -- LFO frequency
      )
    end
    
    table.insert(chains_created, {
      chain = chain,
      chain_index = chain_index,
      frame = frame,
      gainer = gainer,
      gainer_position = gainer_position,
      lfo = lfo,
      crossfade_curve = crossfade_curve
    })
  end
  
  return chains_created
end

-- Build group-level crossfade routing for oscillator-to-oscillator morphing (wavetable scanning)
-- This adds a Group Gainer and Group LFO to each frame chain of an oscillator
function PakettiMetaSynthBuildGroupCrossfadeRouting(chains_created, osc_index, total_oscs, group_config)
  -- Skip if only one oscillator (nothing to crossfade between)
  if total_oscs <= 1 then
    return chains_created
  end
  
  -- Skip if group crossfade is disabled
  if not group_config.group_crossfade_enabled then
    return chains_created
  end
  
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local crossfade_time = group_config.group_crossfade_time or 4.0
  
  -- Generate crossfade curve for this oscillator's position within the group
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    osc_index,
    total_oscs
  )
  
  -- Add Group Gainer and LFO to each frame chain
  for _, chain_info in ipairs(chains_created) do
    local chain = chain_info.chain
    
    -- Create Group Gainer at the end of the chain
    local initial_gain = group_crossfade_curve[1].value
    local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
      chain, 
      initial_gain, 
      string.format("Group XFade Osc %d/%d", osc_index, total_oscs)
    )
    
    -- Create Group LFO with crossfade envelope routed to the Group Gainer
    -- Scale envelope points by crossfade time
    local scaled_curve = {}
    for i, point in ipairs(group_crossfade_curve) do
      table.insert(scaled_curve, {
        time = point.time,
        value = point.value
      })
    end
    
    -- Calculate Group LFO frequency from rate settings
    local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
      group_config.group_lfo_rate_mode,
      group_config.group_lfo_rate_free,
      group_config.group_lfo_rate_sync,
      group_config.group_lfo_rate_preset
    )
    
    local group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
      chain,
      scaled_curve,
      string.format("Group LFO Osc %d", osc_index),
      group_gainer_position,  -- Destination device index
      1,                      -- Destination parameter index (Gain)
      group_lfo_freq          -- LFO frequency
    )
    
    -- Store group crossfade info in chain_info
    chain_info.group_gainer = group_gainer
    chain_info.group_gainer_position = group_gainer_position
    chain_info.group_lfo = group_lfo
    chain_info.group_crossfade_curve = group_crossfade_curve
    chain_info.osc_position = osc_index
    chain_info.total_oscs = total_oscs
  end
  
  return chains_created
end

-- Add group-level crossfade to a single chain (typically the Oscillator FX chain)
-- This is used when Oscillator FX is enabled, so Group Gainer goes on the Osc FX chain instead of every frame chain
function PakettiMetaSynthAddGroupCrossfadeToChain(chain, chain_info, osc_index, total_oscs, group_config)
  -- Skip if only one oscillator (nothing to crossfade between)
  if total_oscs <= 1 then
    return chain_info
  end
  
  -- Skip if group crossfade is disabled
  if not group_config.group_crossfade_enabled then
    return chain_info
  end
  
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local crossfade_time = group_config.group_crossfade_time or 4.0
  
  -- Generate crossfade curve for this oscillator's position within the group
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    osc_index,
    total_oscs
  )
  
  -- Create Group Gainer at the end of the chain
  local initial_gain = group_crossfade_curve[1].value
  local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
    chain, 
    initial_gain, 
    string.format("Group XFade Osc %d/%d", osc_index, total_oscs)
  )
  
  -- Create Group LFO with crossfade envelope routed to the Group Gainer
  local scaled_curve = {}
  for i, point in ipairs(group_crossfade_curve) do
    table.insert(scaled_curve, {
      time = point.time,
      value = point.value
    })
  end
  
  -- Calculate Group LFO frequency from rate settings
  local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    group_config.group_lfo_rate_mode,
    group_config.group_lfo_rate_free,
    group_config.group_lfo_rate_sync,
    group_config.group_lfo_rate_preset
  )
  
  local group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
    chain,
    scaled_curve,
    string.format("Group LFO Osc %d", osc_index),
    group_gainer_position,  -- Destination device index
    1,                      -- Destination parameter index (Gain)
    group_lfo_freq          -- LFO frequency
  )
  
  -- Store group crossfade info in chain_info
  chain_info.group_gainer = group_gainer
  chain_info.group_gainer_position = group_gainer_position
  chain_info.group_lfo = group_lfo
  chain_info.group_crossfade_curve = group_crossfade_curve
  chain_info.osc_position = osc_index
  chain_info.total_oscs = total_oscs
  
  return chain_info
end

-- Helper function to add a #Send device to a chain that routes to a destination chain
-- NOTE: dest_chain_index is 1-based (Lua convention), but #Send Receiver is 0-based
function PakettiMetaSynthAddSendDevice(chain, dest_chain_index, display_name)
  local position = #chain.devices + 1
  local success, err = pcall(function()
    chain:insert_device_at("Audio/Effects/Native/#Send", position)
  end)
  
  if not success then
    print("PakettiMetaSynth: Failed to insert #Send device: " .. tostring(err))
    return nil
  end
  
  local send_device = chain.devices[position]
  if send_device then
    -- Convert 1-based chain index to 0-based Receiver index
    local receiver_index = dest_chain_index - 1
    
    -- Apply Send device configuration via XML
    local send_xml = string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="SendDevice">
    <IsMaximized>true</IsMaximized>
    <SendAmount>
      <Value>1.0</Value>
    </SendAmount>
    <SendPan>
      <Value>0.5</Value>
    </SendPan>
    <DestSendTrack>
      <Value>%d</Value>
    </DestSendTrack>
    <MuteSource>true</MuteSource>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <ApplyPostVolume>true</ApplyPostVolume>
  </DeviceSlot>
</FilterDevicePreset>]=], receiver_index)
    
    send_device.active_preset_data = send_xml
    send_device.display_name = display_name or "#Send"
    send_device.parameters[1].value = 1.0   -- Amount = 100%
    send_device.parameters[2].value = 0.5   -- Panning = center
    send_device.parameters[3].value = receiver_index  -- Receiver = 0-based index
    send_device.parameters[1].show_in_mixer = true
  end
  
  return send_device
end

-- Create Oscillator FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain per oscillator as a summing bus
-- This sits between frame morphing and group morphing in the signal flow
-- Structure: [Osc FX devices (0+)] → [Osc Gainer + LFO added later]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateOscillatorFXChain(instrument, osc_config, randomization_amount)
  -- ALWAYS create the Osc FX chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Oscillator FX chain
  local osc_fx_chain_name = osc_config.name .. " FX"
  local osc_fx_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(osc_fx_chain_index)
  local osc_fx_chain = instrument.sample_device_chains[osc_fx_chain_index]
  osc_fx_chain.name = osc_fx_chain_name
  PakettiMetaSynthAddDCOffset(osc_fx_chain)
  
  -- Add FX devices to the Oscillator FX chain ONLY if FX is enabled
  local osc_fx_devices = {}
  
  if osc_config.osc_fx_enabled then
    local mode = osc_config.osc_fx_mode or "random"
    local device_count = osc_config.osc_fx_count or 2
    local fx_types = osc_config.osc_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(osc_fx_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("OscFX %s %d", fx_type_name, i)
          table.insert(osc_fx_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(osc_fx_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("OscFX %d", i)
          table.insert(osc_fx_devices, device)
        end
      end
    end
  end
  
  print(string.format("PakettiMetaSynth: Created Oscillator FX bus '%s' with %d FX devices", 
    osc_fx_chain_name, #osc_fx_devices))
  
  -- Return the oscillator FX chain info (Osc Gainer added later, routing in Phase 2)
  return {
    chain = osc_fx_chain,
    chain_index = osc_fx_chain_index,
    chain_name = osc_fx_chain_name,
    devices = osc_fx_devices,
    osc_name = osc_config.name
  }
end

-- Create Group Master FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain per group as a summing bus
-- Structure: [Group FX devices (0+)] → [Group Gainer + LFO]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateGroupMasterChain(instrument, group_config, group_name, group_index, total_groups, randomization_amount)
  -- ALWAYS create the Group Master chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Group Master FX chain
  local master_chain_name = group_name .. " Master"
  local master_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(master_chain_index)
  local master_chain = instrument.sample_device_chains[master_chain_index]
  master_chain.name = master_chain_name
  PakettiMetaSynthAddDCOffset(master_chain)
  
  -- Add FX devices to the Group Master chain ONLY if FX is enabled
  local group_master_devices = {}
  
  if group_config.group_master_fx_enabled then
    local mode = group_config.group_master_fx_mode or "random"
    local device_count = group_config.group_master_fx_count or 3
    local fx_types = group_config.group_master_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(master_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("GrpMaster %s %d", fx_type_name, i)
          table.insert(group_master_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(master_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("GrpMaster FX %d", i)
          table.insert(group_master_devices, device)
        end
      end
    end
  end
  
  -- ALWAYS add Group Gainer for group-level morphing/volume control
  -- Generate crossfade curve for this group's position
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    group_index,
    total_groups
  )
  
  -- Create Group Gainer at the end of the chain
  local initial_gain = (total_groups > 1) and group_crossfade_curve[1].value or 1.0
  local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
    master_chain, 
    initial_gain, 
    string.format("Group Gainer %s", group_name)
  )
  
  -- Create Group LFO for group-level morphing (only if multiple groups)
  local group_lfo = nil
  if total_groups > 1 then
    local scaled_curve = {}
    for i, point in ipairs(group_crossfade_curve) do
      table.insert(scaled_curve, {
        time = point.time,
        value = point.value
      })
    end
    
    -- Calculate Group LFO frequency from rate settings
    local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
      group_config.group_lfo_rate_mode,
      group_config.group_lfo_rate_free,
      group_config.group_lfo_rate_sync,
      group_config.group_lfo_rate_preset
    )
    
    group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
      master_chain,
      scaled_curve,
      string.format("Group LFO %s", group_name),
      group_gainer_position,
      1,              -- Gain parameter
      group_lfo_freq  -- LFO frequency
    )
  end
  
  print(string.format("PakettiMetaSynth: Created Group Master bus '%s' with %d FX devices + Gainer", 
    master_chain_name, #group_master_devices))
  
  -- Return the group master chain info (routing in Phase 2)
  return {
    chain = master_chain,
    chain_index = master_chain_index,
    chain_name = master_chain_name,
    devices = group_master_devices,
    group_name = group_name,
    group_gainer = group_gainer,
    group_gainer_position = group_gainer_position,
    group_lfo = group_lfo,
    group_crossfade_curve = group_crossfade_curve
  }
end

-- ============================================================================
-- GROUP FRAME CHAINS
-- Creates multiple "snapshots" of a group that can be morphed between
-- This is the "meta-wavetable at group level" feature
-- Structure per frame: [FX devices (0+)] → [Frame Gainer + Frame LFO]
-- ============================================================================
function PakettiMetaSynthCreateGroupFrameChains(instrument, group_config, group_name, randomization_amount)
  randomization_amount = randomization_amount or 0.3
  
  local frame_count = group_config.group_frame_count or 1
  local morph_enabled = group_config.group_frame_morph_enabled or false
  local morph_speed = group_config.group_frame_morph_speed or "slow"
  local curve_type = group_config.group_frame_crossfade_curve or "equal_power"
  local fx_enabled = group_config.group_frame_fx_enabled or false
  local fx_tendencies = group_config.group_frame_fx_tendencies or {}
  local fx_count = group_config.group_frame_fx_count or 1
  
  -- Calculate LFO frequency for group frame morphing
  local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    "preset",
    0.5,
    "1 bar",
    group_config.group_frame_lfo_rate_preset or morph_speed
  )
  
  local group_frame_chains = {}
  
  for frame_idx = 1, frame_count do
    local frame_chain_name = string.format("%s GrpFrame %d", group_name, frame_idx)
    local frame_chain_index = #instrument.sample_device_chains + 1
    instrument:insert_sample_device_chain_at(frame_chain_index)
    local frame_chain = instrument.sample_device_chains[frame_chain_index]
    frame_chain.name = frame_chain_name
    PakettiMetaSynthAddDCOffset(frame_chain)
    
    -- Add FX devices if enabled
    local frame_devices = {}
    if fx_enabled and fx_count > 0 then
      if #fx_tendencies > 0 then
        -- Use FX tendencies
        for i = 1, fx_count do
          local type_index = ((i - 1) % #fx_tendencies) + 1
          local fx_type_name = fx_tendencies[type_index]
          local device = PakettiMetaSynthBuildFXByType(frame_chain, fx_type_name, randomization_amount)
          if device then
            device.display_name = string.format("GrpFrm%d %s", frame_idx, fx_type_name)
            table.insert(frame_devices, device)
          end
        end
      else
        -- Random FX
        for i = 1, fx_count do
          local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
          local device = PakettiMetaSynthInsertDevice(frame_chain, random_device)
          if device then
            PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
            device.display_name = string.format("GrpFrm%d FX %d", frame_idx, i)
            table.insert(frame_devices, device)
          end
        end
      end
    end
    
    -- Generate crossfade curve for this group frame position
    local frame_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      curve_type,
      128,
      frame_idx,
      frame_count
    )
    
    -- Add Frame Gainer for crossfade control
    local initial_gain = frame_crossfade_curve[1].value
    local frame_gainer, frame_gainer_position = PakettiMetaSynthCreateGainer(
      frame_chain, 
      initial_gain, 
      string.format("GrpFrame %d Gainer", frame_idx)
    )
    
    -- Add Frame LFO if morphing enabled and more than 1 frame
    local frame_lfo = nil
    if morph_enabled and frame_count > 1 then
      -- Scale curve to 0-1 range
      local scaled_curve = {}
      for _, point in ipairs(frame_crossfade_curve) do
        table.insert(scaled_curve, {
          time = point.time,
          value = math.min(1.0, math.max(0.0, point.value))
        })
      end
      
      frame_lfo = PakettiMetaSynthCreateCrossfadeLFO(
        frame_chain,
        scaled_curve,
        string.format("GrpFrame %d LFO", frame_idx),
        frame_gainer_position,
        1,              -- Gain parameter
        lfo_freq
      )
    end
    
    table.insert(group_frame_chains, {
      chain = frame_chain,
      chain_index = frame_chain_index,
      chain_name = frame_chain_name,
      frame_index = frame_idx,
      devices = frame_devices,
      frame_gainer = frame_gainer,
      frame_gainer_position = frame_gainer_position,
      frame_lfo = frame_lfo,
      crossfade_curve = frame_crossfade_curve
    })
    
    print(string.format("PakettiMetaSynth: Created Group Frame chain '%s' with %d FX + Gainer", 
      frame_chain_name, #frame_devices))
  end
  
  return group_frame_chains
end

-- Route Osc FX chains to Group Frame chains (sends from Osc FX to all Group Frames)
function PakettiMetaSynthRouteOscFXToGroupFrames(osc_fx_chains, group_frame_chains)
  if not group_frame_chains or #group_frame_chains == 0 then
    return
  end
  
  for _, osc_fx_info in ipairs(osc_fx_chains) do
    local osc_fx_chain = osc_fx_info.chain
    
    -- Send to all group frame chains
    for _, frame_info in ipairs(group_frame_chains) do
      local send_device = osc_fx_chain:insert_device_at("Audio/Effects/Native/#Send", #osc_fx_chain.devices + 1)
      if send_device then
        send_device.display_name = string.format("→ %s", frame_info.chain_name)
        -- Set send parameters: [1]=Amount, [2]=Panning, [3]=Receiver
        send_device.parameters[1].value = 1.0  -- Amount = 100%
        send_device.parameters[3].value = frame_info.chain_index  -- Receiver = chain index
        -- Mute source is controlled via active_preset_data or other means
      end
    end
  end
end

-- Route Group Frame chains to Group Master
function PakettiMetaSynthRouteGroupFramesToMaster(group_frame_chains, group_master_info)
  if not group_frame_chains or #group_frame_chains == 0 then
    return
  end
  
  for _, frame_info in ipairs(group_frame_chains) do
    local frame_chain = frame_info.chain
    local send_device = frame_chain:insert_device_at("Audio/Effects/Native/#Send", #frame_chain.devices + 1)
    if send_device then
      send_device.display_name = string.format("→ %s", group_master_info.chain_name)
      -- Set send parameters: [1]=Amount, [2]=Panning, [3]=Receiver
      send_device.parameters[1].value = 1.0  -- Amount = 100%
      send_device.parameters[3].value = group_master_info.chain_index  -- Receiver = chain index
    end
  end
end

-- ============================================================================
-- GROUP FRAME VECTOR SYNTHESIS: XY-based morphing between 4 Group Frames
-- Creates 4-corner XY vector morphing at the group frame level
-- Requires exactly 4 group frames (treated as corners: A=bottom-left, B=bottom-right, C=top-left, D=top-right)
-- ============================================================================
function PakettiMetaSynthAddGroupFrameVectorSynthesis(group_frame_chains, group_config, architecture)
  local total_frames = #group_frame_chains
  if total_frames ~= 4 then
    print(string.format("PakettiMetaSynth: Group Frame Vector requires exactly 4 frames (got %d), skipping", total_frames))
    return
  end
  
  -- Check group-level or architecture-level vector settings
  local vector_enabled = group_config.group_frame_vector_enabled or architecture.group_frame_vector_enabled
  if not vector_enabled then
    return
  end
  
  local x_source = group_config.group_frame_vector_x_source or architecture.group_frame_vector_x_source or "lfo"
  local y_source = group_config.group_frame_vector_y_source or architecture.group_frame_vector_y_source or "lfo"
  local x_lfo_rate = group_config.group_frame_vector_x_lfo_rate or architecture.group_frame_vector_x_lfo_rate or 0.2
  local y_lfo_rate = group_config.group_frame_vector_y_lfo_rate or architecture.group_frame_vector_y_lfo_rate or 0.12
  
  local group_name = group_config.name or "Group"
  print(string.format("PakettiMetaSynth: Adding Group Frame Vector Synthesis to '%s' (X: %s, Y: %s)", 
    group_name, x_source, y_source))
  
  -- Frame mapping: 1=A(BL), 2=B(BR), 3=C(TL), 4=D(TR)
  -- Initial position: center (0.5, 0.5) = equal blend of all 4 frames
  local initial_gains = PakettiMetaSynthCalculateVectorGainsEqualPower(0.5, 0.5)
  local gain_values = {initial_gains.group_a, initial_gains.group_b, initial_gains.group_c, initial_gains.group_d}
  local corner_names = {"BL", "BR", "TL", "TR"}
  
  for fi, frame_info in ipairs(group_frame_chains) do
    local chain = frame_info.chain
    
    -- Add Vector Gainer for XY control
    local vector_gainer, vector_gainer_position = PakettiMetaSynthCreateGainer(
      chain,
      gain_values[fi],
      string.format("%s GrpFr Vec %s", group_name:sub(1, 3), corner_names[fi])
    )
    
    frame_info.vector_gainer = vector_gainer
    frame_info.vector_gainer_position = vector_gainer_position
    
    print(string.format("PakettiMetaSynth: Added Group Frame Vector Gainer to '%s' (corner=%s, gain=%.2f)",
      frame_info.chain_name, corner_names[fi], gain_values[fi]))
  end
  
  -- Add X-axis LFO if using LFO control
  if x_source == "lfo" then
    local x_chain = group_frame_chains[1].chain
    local x_lfo = PakettiMetaSynthInsertDevice(x_chain, "Audio/Effects/Native/*LFO")
    if x_lfo then
      x_lfo.display_name = string.format("%s GrpFr Vec X", group_name:sub(1, 3))
      local freq_param = x_lfo:parameter(1)
      if freq_param then
        freq_param.value = x_lfo_rate
      end
      local shape_param = x_lfo:parameter(2)
      if shape_param then
        shape_param.value = 0  -- Sine
      end
      group_frame_chains[1].vector_x_lfo = x_lfo
      print(string.format("PakettiMetaSynth: Added Group Frame Vector X LFO (rate=%.3f)", x_lfo_rate))
    end
  end
  
  -- Add Y-axis LFO if using LFO control
  if y_source == "lfo" then
    local y_chain = group_frame_chains[2].chain
    local y_lfo = PakettiMetaSynthInsertDevice(y_chain, "Audio/Effects/Native/*LFO")
    if y_lfo then
      y_lfo.display_name = string.format("%s GrpFr Vec Y", group_name:sub(1, 3))
      local freq_param = y_lfo:parameter(1)
      if freq_param then
        freq_param.value = y_lfo_rate
      end
      local shape_param = y_lfo:parameter(2)
      if shape_param then
        shape_param.value = 0  -- Sine
      end
      group_frame_chains[2].vector_y_lfo = y_lfo
      print(string.format("PakettiMetaSynth: Added Group Frame Vector Y LFO (rate=%.3f)", y_lfo_rate))
    end
  end
end

-- ============================================================================
-- TOTAL GROUP FRAME CHAINS (Layer 7)
-- Creates multiple "snapshots" of total summed groups that can be morphed between
-- This is frame scanning at the total group level (after Stack Master, before Global FX)
-- Structure per frame: [FX devices (0+)] → [Frame Gainer + Frame LFO]
-- ============================================================================
function PakettiMetaSynthCreateTotalGroupFrameChains(instrument, architecture, randomization_amount)
  randomization_amount = randomization_amount or 0.3
  
  local frame_count = architecture.global_fx_frame_count or 1
  local morph_enabled = architecture.global_fx_frame_morph_enabled or false
  local morph_speed = architecture.global_fx_frame_morph_speed or "slow"
  local curve_type = architecture.global_fx_frame_crossfade_curve or "equal_power"
  local fx_enabled = architecture.global_fx_frame_fx_enabled or false
  local fx_tendencies = architecture.global_fx_frame_fx_tendencies or {}
  local fx_count = architecture.global_fx_frame_fx_count or 1
  
  -- Calculate LFO frequency for global frame morphing
  local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    "preset",
    0.5,
    "1 bar",
    architecture.global_fx_frame_lfo_rate_preset or morph_speed
  )
  
  local total_group_frame_chains = {}
  
  for frame_idx = 1, frame_count do
    local frame_chain_name = string.format("Total Group Frame %d", frame_idx)
    local frame_chain_index = #instrument.sample_device_chains + 1
    instrument:insert_sample_device_chain_at(frame_chain_index)
    local frame_chain = instrument.sample_device_chains[frame_chain_index]
    frame_chain.name = frame_chain_name
    PakettiMetaSynthAddDCOffset(frame_chain)
    
    -- Add FX devices if enabled
    local frame_devices = {}
    if fx_enabled and fx_count > 0 then
      if #fx_tendencies > 0 then
        -- Use FX tendencies
        for i = 1, fx_count do
          local type_index = ((i - 1) % #fx_tendencies) + 1
          local fx_type_name = fx_tendencies[type_index]
          local device = PakettiMetaSynthBuildFXByType(frame_chain, fx_type_name, randomization_amount)
          if device then
            device.display_name = string.format("GlbFrm%d %s", frame_idx, fx_type_name)
            table.insert(frame_devices, device)
          end
        end
      else
        -- Random FX
        for i = 1, fx_count do
          local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
          local device = PakettiMetaSynthInsertDevice(frame_chain, random_device)
          if device then
            PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
            device.display_name = string.format("GlbFrm%d FX %d", frame_idx, i)
            table.insert(frame_devices, device)
          end
        end
      end
    end
    
    -- Generate crossfade curve for this global frame position
    local frame_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      curve_type,
      128,
      frame_idx,
      frame_count
    )
    
    -- Add Frame Gainer for crossfade control
    local initial_gain = frame_crossfade_curve[1].value
    local frame_gainer, frame_gainer_position = PakettiMetaSynthCreateGainer(
      frame_chain, 
      initial_gain, 
      string.format("Total Group Frame %d Gainer", frame_idx)
    )
    
    -- Add Frame LFO if morphing enabled and more than 1 frame
    local frame_lfo = nil
    if morph_enabled and frame_count > 1 then
      -- Scale curve to 0-1 range
      local scaled_curve = {}
      for _, point in ipairs(frame_crossfade_curve) do
        table.insert(scaled_curve, {
          time = point.time,
          value = math.min(1.0, math.max(0.0, point.value))
        })
      end
      
      frame_lfo = PakettiMetaSynthCreateCrossfadeLFO(
        frame_chain,
        scaled_curve,
        string.format("Total Group Frame %d LFO", frame_idx),
        frame_gainer_position,
        1,              -- Gain parameter
        lfo_freq
      )
    end
    
    table.insert(total_group_frame_chains, {
      chain = frame_chain,
      chain_index = frame_chain_index,
      chain_name = frame_chain_name,
      frame_index = frame_idx,
      devices = frame_devices,
      frame_gainer = frame_gainer,
      frame_gainer_position = frame_gainer_position,
      frame_lfo = frame_lfo,
      crossfade_curve = frame_crossfade_curve
    })
    
  print(string.format("PakettiMetaSynth: Created Total Group Frame chain '%s' with %d FX + Gainer", 
    frame_chain_name, #frame_devices))
  end
  
  return total_group_frame_chains
end

-- Route Stack Master to Total Group Frame chains
function PakettiMetaSynthRouteStackedMasterToTotalGroupFrames(stack_master_info, total_group_frame_chains)
  if not total_group_frame_chains or #total_group_frame_chains == 0 then
    return
  end
  
  local stacked_chain = stack_master_info.chain
  
  for _, frame_info in ipairs(total_group_frame_chains) do
    local send_device = stacked_chain:insert_device_at("Audio/Effects/Native/#Send", #stacked_chain.devices + 1)
    if send_device then
      send_device.display_name = string.format("→ %s", frame_info.chain_name)
      -- Set send parameters: [1]=Amount, [2]=Panning, [3]=Receiver
      send_device.parameters[1].value = 1.0  -- Amount = 100%
      send_device.parameters[3].value = frame_info.chain_index  -- Receiver = chain index
    end
  end
end

-- ============================================================================
-- TOTAL GROUP FRAMES WAVETABLE SCAN: Sequential scanning across Total Group Frames
-- Adds Scan Gainers + LFOs to each Total Group Frame chain for wavetable-style morphing
-- Works with any frame count >= 2
-- ============================================================================
function PakettiMetaSynthAddTotalGroupFramesWavetableScan(total_group_frame_chains, architecture)
  local total_frames = #total_group_frame_chains
  if total_frames < 2 then
    print("PakettiMetaSynth: Total Group Frames Scan requires 2+ frames, skipping")
    return
  end
  
  if not architecture.global_fx_scan_enabled then
    return
  end
  
  local curve_type = architecture.global_fx_scan_curve or "equal_power"
  local control_source = architecture.global_fx_scan_control_source or "lfo"
  
  -- Calculate LFO frequency for global FX frame scanning
  local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    "preset",
    0.5,
    "1 bar",
    architecture.global_fx_scan_lfo_rate_preset or "slow"
  )
  
  print(string.format("PakettiMetaSynth: Adding Total Group Frames Scan to %d frames (curve: %s, source: %s)",
    total_frames, curve_type, control_source))
  
  for fi, frame_info in ipairs(total_group_frame_chains) do
    local chain = frame_info.chain
    
    -- Generate crossfade curve for this frame's position
    local frame_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      curve_type,
      128,
      fi,
      total_frames
    )
    
    -- Add Global FX Scan Gainer
    local initial_gain = frame_crossfade_curve[1].value
    local scan_gainer, scan_gainer_position = PakettiMetaSynthCreateGainer(
      chain,
      initial_gain,
      string.format("TGF Scan %d/%d", fi, total_frames)
    )
    
    frame_info.scan_gainer = scan_gainer
    frame_info.scan_gainer_position = scan_gainer_position
    
    -- Add Global FX Scan LFO if using LFO control
    if control_source == "lfo" then
      -- Scale curve to 0-1 range
      local scaled_curve = {}
      for _, point in ipairs(frame_crossfade_curve) do
        table.insert(scaled_curve, {
          time = point.time,
          value = math.min(1.0, math.max(0.0, point.value))
        })
      end
      
      local scan_lfo = PakettiMetaSynthCreateCrossfadeLFO(
        chain,
        scaled_curve,
        string.format("TGF Scan LFO %d", fi),
        scan_gainer_position,
        1,  -- Gain parameter
        lfo_freq
      )
      
      frame_info.scan_lfo = scan_lfo
      print(string.format("PakettiMetaSynth: Added Total Group Frames Scan Gainer + LFO to '%s' (gain=%.2f, freq=%.3f)",
        frame_info.chain_name, initial_gain, lfo_freq))
    else
      -- Macro control - just leave gainer for manual control
      print(string.format("PakettiMetaSynth: Added Total Group Frames Scan Gainer to '%s' (gain=%.2f, macro control)",
        frame_info.chain_name, initial_gain))
    end
  end
end

-- ============================================================================
-- TOTAL GROUP FRAMES VECTOR SYNTHESIS: XY-based morphing between 4 Total Group Frames
-- Creates 4-corner XY vector morphing similar to group-level vector synthesis
-- Requires exactly 4 frames (treated as corners: A=bottom-left, B=bottom-right, C=top-left, D=top-right)
-- ============================================================================
function PakettiMetaSynthAddTotalGroupFramesVectorSynthesis(total_group_frame_chains, architecture)
  local total_frames = #total_group_frame_chains
  if total_frames ~= 4 then
    print(string.format("PakettiMetaSynth: Total Group Frames Vector requires exactly 4 frames (got %d), skipping", total_frames))
    return
  end
  
  if not architecture.global_fx_vector_enabled then
    return
  end
  
  local x_source = architecture.global_fx_vector_x_source or "lfo"
  local y_source = architecture.global_fx_vector_y_source or "lfo"
  local x_lfo_rate = architecture.global_fx_vector_x_lfo_rate or 0.25
  local y_lfo_rate = architecture.global_fx_vector_y_lfo_rate or 0.15
  
  print(string.format("PakettiMetaSynth: Adding Global FX Vector Synthesis (X: %s, Y: %s)", x_source, y_source))
  
  -- Frame mapping: 1=A(BL), 2=B(BR), 3=C(TL), 4=D(TR)
  -- Initial position: center (0.5, 0.5) = equal blend of all 4 frames
  local initial_gains = PakettiMetaSynthCalculateVectorGainsEqualPower(0.5, 0.5)
  local gain_values = {initial_gains.group_a, initial_gains.group_b, initial_gains.group_c, initial_gains.group_d}
  local corner_names = {"BL", "BR", "TL", "TR"}
  
  for fi, frame_info in ipairs(total_group_frame_chains) do
    local chain = frame_info.chain
    
    -- Add Vector Gainer for XY control
    local vector_gainer, vector_gainer_position = PakettiMetaSynthCreateGainer(
      chain,
      gain_values[fi],
      string.format("TGF Vector %s", corner_names[fi])
    )
    
    frame_info.vector_gainer = vector_gainer
    frame_info.vector_gainer_position = vector_gainer_position
    
    print(string.format("PakettiMetaSynth: Added Total Group Frames Vector Gainer to '%s' (corner=%s, gain=%.2f)",
      frame_info.chain_name, corner_names[fi], gain_values[fi]))
  end
  
  -- Add X-axis LFO if using LFO control
  if x_source == "lfo" then
    -- X-axis affects frames horizontally (A/C vs B/D)
    -- Create sine wave LFO that sweeps 0-1 on X axis
    local x_chain = total_group_frame_chains[1].chain  -- Add to first frame chain
    local x_lfo = PakettiMetaSynthInsertDevice(x_chain, "Audio/Effects/Native/*LFO")
    if x_lfo then
      x_lfo.display_name = "TGF Vector X"
      -- Set LFO parameters
      local freq_param = x_lfo:parameter(1)
      if freq_param then
        freq_param.value = x_lfo_rate
      end
      -- Shape: Sine
      local shape_param = x_lfo:parameter(2)
      if shape_param then
        shape_param.value = 0  -- Sine
      end
      total_group_frame_chains[1].vector_x_lfo = x_lfo
      print(string.format("PakettiMetaSynth: Added Total Group Frames Vector X LFO (rate=%.3f)", x_lfo_rate))
    end
  end
  
  -- Add Y-axis LFO if using LFO control
  if y_source == "lfo" then
    -- Y-axis affects frames vertically (A/B vs C/D)
    local y_chain = total_group_frame_chains[2].chain  -- Add to second frame chain
    local y_lfo = PakettiMetaSynthInsertDevice(y_chain, "Audio/Effects/Native/*LFO")
    if y_lfo then
      y_lfo.display_name = "TGF Vector Y"
      -- Set LFO parameters
      local freq_param = y_lfo:parameter(1)
      if freq_param then
        freq_param.value = y_lfo_rate
      end
      -- Shape: Sine
      local shape_param = y_lfo:parameter(2)
      if shape_param then
        shape_param.value = 0  -- Sine
      end
      total_group_frame_chains[2].vector_y_lfo = y_lfo
      print(string.format("PakettiMetaSynth: Added Total Group Frames Vector Y LFO (rate=%.3f)", y_lfo_rate))
    end
  end
end

-- ============================================================================
-- SPECTRAL MORPH MACRO: Adds macro-controllable spectral morphing intensity
-- Creates a *Hydra device that scales the spectral crossfade effect
-- ============================================================================
function PakettiMetaSynthAddSpectralMorphMacro(instrument, architecture)
  if not architecture.spectral_morph_enabled then
    return nil
  end
  
  local macro_index = architecture.spectral_morph_macro_index or 5
  local intensity = architecture.spectral_morph_intensity or 0.5
  
  -- Set up the macro
  if macro_index >= 1 and macro_index <= 8 then
    instrument.macros[macro_index].name = "Spectral Morph"
    instrument.macros[macro_index].value = intensity
    
    print(string.format("PakettiMetaSynth: Configured Spectral Morph Macro %d (intensity=%.2f)", 
      macro_index, intensity))
  end
  
  return macro_index
end

-- ============================================================================
-- FINAL OUTPUT CHAIN: True output stage with Master EQ, Limiter, and Output Shaping
-- This is the LAST processing stage before instrument output
-- Structure: [Master EQ] → [Saturation] → [Width] → [Limiter]
-- ============================================================================
function PakettiMetaSynthCreateFinalOutputChain(instrument, architecture, randomization_amount)
  if not architecture.final_output_enabled then
    return nil
  end
  
  randomization_amount = randomization_amount or 0.3
  
  -- Create the Final Output chain
  local final_chain_name = "Final Output"
  local final_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(final_chain_index)
  local final_chain = instrument.sample_device_chains[final_chain_index]
  final_chain.name = final_chain_name
  
  local final_devices = {}
  
  -- Add DC Offset first
  PakettiMetaSynthAddDCOffset(final_chain)
  
  -- 1. MASTER EQ (Parametric EQ for tonal shaping)
  if architecture.final_output_master_eq_enabled then
    local eq_device = PakettiMetaSynthInsertDevice(final_chain, "Audio/Effects/Native/EQ 10")
    if eq_device then
      eq_device.display_name = "Master EQ"
      
      -- Apply shelf settings if non-zero
      local low_shelf = architecture.final_output_master_eq_low_shelf or 0.0
      local high_shelf = architecture.final_output_master_eq_high_shelf or 0.0
      local presence = architecture.final_output_master_eq_presence or 0.0
      
      -- EQ 10 has 10 bands - use band 1 for low shelf, band 10 for high shelf, band 7 for presence
      -- Band gain parameters are typically at indices 2, 5, 8, 11, 14, 17, 20, 23, 26, 29
      if low_shelf ~= 0.0 then
        local low_param = eq_device:parameter(2)  -- First band gain
        if low_param then
          -- Convert dB to parameter value (0.5 = 0dB, range roughly 0-1)
          low_param.value = 0.5 + (low_shelf / 24.0)
        end
      end
      
      if high_shelf ~= 0.0 then
        local high_param = eq_device:parameter(29)  -- Last band gain
        if high_param then
          high_param.value = 0.5 + (high_shelf / 24.0)
        end
      end
      
      if presence ~= 0.0 then
        local presence_param = eq_device:parameter(20)  -- Band 7 (around 2-5kHz)
        if presence_param then
          presence_param.value = 0.5 + (presence / 24.0)
        end
      end
      
      table.insert(final_devices, eq_device)
      print("PakettiMetaSynth: Added Master EQ to Final Output")
    end
  end
  
  -- 2. SATURATION (Subtle warmth/color)
  if architecture.final_output_saturation_enabled then
    local sat_device = PakettiMetaSynthInsertDevice(final_chain, "Audio/Effects/Native/Distortion")
    if sat_device then
      sat_device.display_name = "Output Warmth"
      
      local sat_amount = architecture.final_output_saturation_amount or 0.1
      -- Set to subtle saturation mode
      local mode_param = sat_device:parameter(1)  -- Distortion mode
      if mode_param then
        mode_param.value = 0  -- Usually soft/tube mode
      end
      
      local drive_param = sat_device:parameter(2)  -- Drive amount
      if drive_param then
        drive_param.value = sat_amount * 0.3  -- Keep it subtle
      end
      
      local wet_param = sat_device:parameter(3)  -- Wet/dry mix
      if wet_param then
        wet_param.value = sat_amount
      end
      
      table.insert(final_devices, sat_device)
      print(string.format("PakettiMetaSynth: Added Output Saturation (amount=%.2f)", sat_amount))
    end
  end
  
  -- 3. STEREO WIDTH (Stereo expander/narrower)
  if architecture.final_output_width_enabled then
    local width_device = PakettiMetaSynthInsertDevice(final_chain, "Audio/Effects/Native/Stereo Expander")
    if width_device then
      width_device.display_name = "Output Width"
      
      local width_amount = architecture.final_output_width_amount or 1.0
      -- Stereo Expander has width parameter
      local width_param = width_device:parameter(1)
      if width_param then
        -- Map 0-2 range to device range
        width_param.value = width_amount * 0.5
      end
      
      table.insert(final_devices, width_device)
      print(string.format("PakettiMetaSynth: Added Output Width (amount=%.2f)", width_amount))
    end
  end
  
  -- 4. LIMITER (Output protection - always last)
  if architecture.final_output_limiter_enabled then
    local limiter_device = PakettiMetaSynthInsertDevice(final_chain, "Audio/Effects/Native/Maximizer")
    if limiter_device then
      limiter_device.display_name = "Output Limiter"
      
      local ceiling = architecture.final_output_limiter_ceiling or -0.3
      local release = architecture.final_output_limiter_release or 100
      
      -- Maximizer parameters
      local ceiling_param = limiter_device:parameter(1)  -- Ceiling/threshold
      if ceiling_param then
        -- Convert dB to parameter value
        ceiling_param.value = 1.0 + (ceiling / 12.0)  -- Rough conversion
      end
      
      local release_param = limiter_device:parameter(2)  -- Release
      if release_param then
        release_param.value = release / 1000.0  -- Convert ms to seconds
      end
      
      table.insert(final_devices, limiter_device)
      print(string.format("PakettiMetaSynth: Added Output Limiter (ceiling=%.1fdB, release=%dms)", 
        ceiling, release))
    end
  end
  
  local final_output_info = {
    chain = final_chain,
    chain_name = final_chain_name,
    chain_index = final_chain_index,
    devices = final_devices
  }
  
  print(string.format("PakettiMetaSynth: Created Final Output chain '%s' with %d devices",
    final_chain_name, #final_devices))
  
  return final_output_info
end

-- Route to Final Output chain (from Total Group Frames or Stack Master)
function PakettiMetaSynthRouteToFinalOutput(source_info, final_output_info)
  if not final_output_info then
    return
  end
  
  local source_chain = source_info.chain
  local send_device = source_chain:insert_device_at("Audio/Effects/Native/#Send", #source_chain.devices + 1)
  if send_device then
    send_device.display_name = string.format("→ %s", final_output_info.chain_name)
    -- Set send parameters: [1]=Amount, [2]=Panning, [3]=Receiver
    send_device.parameters[1].value = 1.0  -- Amount = 100%
    send_device.parameters[3].value = final_output_info.chain_index  -- Receiver = chain index
  end
  
  print(string.format("PakettiMetaSynth: Routed '%s' to Final Output", source_info.chain_name))
end

-- Create Stack Master FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain for the entire instrument as final summing bus
-- Structure: [Stack FX devices (0+)]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateStackedMasterChain(instrument, architecture, randomization_amount)
  -- ALWAYS create the Stack Master chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Stack Master FX chain
  local stacked_chain_name = "Stack Master"
  local stacked_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(stacked_chain_index)
  local stacked_chain = instrument.sample_device_chains[stacked_chain_index]
  stacked_chain.name = stacked_chain_name
  PakettiMetaSynthAddDCOffset(stacked_chain)
  
  -- Add FX devices to the Stack Master chain ONLY if FX is enabled
  local stack_master_devices = {}
  
  if architecture.stack_master_fx_enabled then
    local mode = architecture.stack_master_fx_mode or "random"
    local device_count = architecture.stack_master_fx_count or 3
    local fx_types = architecture.stack_master_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(stacked_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("StackMaster %s %d", fx_type_name, i)
          table.insert(stack_master_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(stacked_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("StackMaster FX %d", i)
          table.insert(stack_master_devices, device)
        end
      end
    end
  end
  
  print(string.format("PakettiMetaSynth: Created Stack Master bus with %d FX devices", #stack_master_devices))
  
  -- Return the stacked master chain info (routing in Phase 2)
  return {
    chain = stacked_chain,
    chain_index = stacked_chain_index,
    chain_name = stacked_chain_name,
    devices = stack_master_devices
  }
end

-- ============================================================================
-- PHASE 2: ROUTING FUNCTIONS (Add sends AFTER all chains are created)
-- ============================================================================

-- Route all frame chains to their Oscillator FX chain using #Send devices
function PakettiMetaSynthRouteFramesToOscFX(frame_chains, osc_fx_info)
  if not osc_fx_info then return end
  
  local dest_chain_index = osc_fx_info.chain_index
  local dest_chain_name = osc_fx_info.chain_name
  
  for _, chain_info in ipairs(frame_chains) do
    local chain = chain_info.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain, 
      dest_chain_index, 
      string.format("Send to %s", dest_chain_name)
    )
    chain_info.send_to_osc_fx = send_device
    chain_info.routed_to_osc_fx = dest_chain_name
  end
  
  print(string.format("PakettiMetaSynth: Routed %d frame chains -> %s (index %d)", 
    #frame_chains, dest_chain_name, dest_chain_index))
end

-- Route chains to their Group Master chain using #Send devices
-- source_chains: either Osc FX chains or frame chains (if no Osc FX)
function PakettiMetaSynthRouteChainsToGroupMaster(source_chains, group_master_info)
  if not group_master_info then return end
  
  local dest_chain_index = group_master_info.chain_index
  local dest_chain_name = group_master_info.chain_name
  
  for _, chain_info in ipairs(source_chains) do
    local chain = chain_info.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain, 
      dest_chain_index, 
      string.format("Send to %s", dest_chain_name)
    )
    chain_info.send_to_group_master = send_device
    chain_info.routed_to_group_master = dest_chain_name
  end
  
  print(string.format("PakettiMetaSynth: Routed %d chains -> %s (index %d)", 
    #source_chains, dest_chain_name, dest_chain_index))
end

-- Route all Group Master chains to the Stack Master chain using #Send devices
function PakettiMetaSynthRouteGroupMastersToStackedMaster(group_master_chains, stack_master_info)
  if not stack_master_info then return end
  if #group_master_chains == 0 then return end
  
  local dest_chain_index = stack_master_info.chain_index
  local dest_chain_name = stack_master_info.chain_name
  
  for _, group_master_info_item in ipairs(group_master_chains) do
    local chain = group_master_info_item.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain,
      dest_chain_index,
      "Send to Stack Master"
    )
    group_master_info_item.send_to_stack_master = send_device
    print(string.format("PakettiMetaSynth: Routed '%s' -> Stack Master (index %d)", 
      group_master_info_item.chain_name, dest_chain_index))
  end
end

-- ============================================================================
-- INTER-GROUP SCAN: Add wavetable/vector scanning across groups
-- Adds Gainers and LFOs to Group Master chains for inter-group morphing
-- ============================================================================
function PakettiMetaSynthAddInterGroupScan(group_master_chains, architecture)
  local total_groups = #group_master_chains
  if total_groups < 2 then
    print("PakettiMetaSynth: Inter-group scan requires 2+ groups, skipping")
    return
  end
  
  if not architecture.group_scan_enabled then
    return
  end
  
  local curve_type = architecture.group_scan_curve or "equal_power"
  local control_source = architecture.group_scan_control_source or "lfo"
  
  -- Calculate LFO frequency for group scanning
  local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    "preset",
    0.5,
    "1 bar",
    architecture.group_scan_lfo_rate_preset or architecture.group_scan_speed or "slow"
  )
  
  print(string.format("PakettiMetaSynth: Adding inter-group scan to %d groups (curve: %s, source: %s)",
    total_groups, curve_type, control_source))
  
  for gi, group_master_info in ipairs(group_master_chains) do
    local chain = group_master_info.chain
    
    -- Generate crossfade curve for this group's position
    local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      curve_type,
      128,
      gi,
      total_groups
    )
    
    -- Add Group Scan Gainer
    local initial_gain = group_crossfade_curve[1].value
    local scan_gainer, scan_gainer_position = PakettiMetaSynthCreateGainer(
      chain,
      initial_gain,
      string.format("Group Scan %d/%d", gi, total_groups)
    )
    
    group_master_info.scan_gainer = scan_gainer
    group_master_info.scan_gainer_position = scan_gainer_position
    
    -- Add Group Scan LFO if using LFO control
    if control_source == "lfo" then
      -- Scale curve to 0-1 range
      local scaled_curve = {}
      for _, point in ipairs(group_crossfade_curve) do
        table.insert(scaled_curve, {
          time = point.time,
          value = math.min(1.0, math.max(0.0, point.value))
        })
      end
      
      local scan_lfo = PakettiMetaSynthCreateCrossfadeLFO(
        chain,
        scaled_curve,
        string.format("Group Scan LFO %d", gi),
        scan_gainer_position,
        1,  -- Gain parameter
        lfo_freq
      )
      
      group_master_info.scan_lfo = scan_lfo
      print(string.format("PakettiMetaSynth: Added Group Scan Gainer + LFO to '%s' (gain=%.2f, freq=%.3f)",
        group_master_info.chain_name, initial_gain, lfo_freq))
    else
      -- Macro control - just leave gainer for manual control
      print(string.format("PakettiMetaSynth: Added Group Scan Gainer to '%s' (gain=%.2f, macro control)",
        group_master_info.chain_name, initial_gain))
    end
  end
end

-- ============================================================================
-- VECTOR SYNTHESIS: Calculate gains for 4-corner XY vector blending
-- Maps X/Y coordinates (0-1) to gain values for 4 groups (corners)
-- ============================================================================

-- Calculate vector gains for 4 groups based on X/Y position
-- Returns table with gains for group_a (BL), group_b (BR), group_c (TL), group_d (TR)
function PakettiMetaSynthCalculateVectorGains(x, y)
  -- Clamp inputs to 0-1 range
  x = math.min(1.0, math.max(0.0, x or 0.5))
  y = math.min(1.0, math.max(0.0, y or 0.5))
  
  -- Bilinear interpolation for 4-corner blending
  -- Bottom-left (Group A): strong when x=0, y=0
  -- Bottom-right (Group B): strong when x=1, y=0
  -- Top-left (Group C): strong when x=0, y=1
  -- Top-right (Group D): strong when x=1, y=1
  return {
    group_a = (1 - x) * (1 - y),  -- Bottom-left
    group_b = x * (1 - y),        -- Bottom-right
    group_c = (1 - x) * y,        -- Top-left
    group_d = x * y               -- Top-right
  }
end

-- Calculate vector gains with equal power crossfade (prevents volume dips)
function PakettiMetaSynthCalculateVectorGainsEqualPower(x, y)
  x = math.min(1.0, math.max(0.0, x or 0.5))
  y = math.min(1.0, math.max(0.0, y or 0.5))
  
  -- Equal power uses cosine/sine curves
  local cos_x = math.cos(x * math.pi / 2)
  local sin_x = math.sin(x * math.pi / 2)
  local cos_y = math.cos(y * math.pi / 2)
  local sin_y = math.sin(y * math.pi / 2)
  
  return {
    group_a = cos_x * cos_y,  -- Bottom-left
    group_b = sin_x * cos_y,  -- Bottom-right
    group_c = cos_x * sin_y,  -- Top-left
    group_d = sin_x * sin_y   -- Top-right
  }
end

-- Add Vector Synthesis to 4 group master chains
function PakettiMetaSynthAddVectorSynthesis(group_master_chains, architecture)
  local total_groups = #group_master_chains
  if total_groups ~= 4 then
    print(string.format("PakettiMetaSynth: Vector synthesis requires exactly 4 groups (got %d), skipping", total_groups))
    return
  end
  
  if not architecture.vector_enabled then
    return
  end
  
  local x_source = architecture.vector_x_source or "macro"
  local y_source = architecture.vector_y_source or "macro"
  
  print(string.format("PakettiMetaSynth: Adding Vector Synthesis (X: %s, Y: %s)", x_source, y_source))
  
  -- Initial position at center (0.5, 0.5)
  local initial_gains = PakettiMetaSynthCalculateVectorGainsEqualPower(0.5, 0.5)
  local corner_names = {"group_a", "group_b", "group_c", "group_d"}
  local corner_labels = {"BL", "BR", "TL", "TR"}  -- Bottom-Left, Bottom-Right, Top-Left, Top-Right
  
  for gi, group_master_info in ipairs(group_master_chains) do
    local chain = group_master_info.chain
    local corner = corner_names[gi]
    local initial_gain = initial_gains[corner]
    
    -- Add Vector Gainer
    local vector_gainer, vector_gainer_position = PakettiMetaSynthCreateGainer(
      chain,
      initial_gain,
      string.format("Vector %s", corner_labels[gi])
    )
    
    group_master_info.vector_gainer = vector_gainer
    group_master_info.vector_gainer_position = vector_gainer_position
    group_master_info.vector_corner = corner
    
    print(string.format("PakettiMetaSynth: Added Vector Gainer to '%s' (%s, gain=%.3f)",
      group_master_info.chain_name, corner_labels[gi], initial_gain))
  end
  
  -- Add Vector Envelope LFOs if envelope mode is enabled
  if architecture.vector_envelope and architecture.vector_envelope.enabled then
    PakettiMetaSynthAddVectorEnvelopeLFOs(group_master_chains, architecture)
  end
end

-- ============================================================================
-- VECTOR ENVELOPE: Generate per-group gain curves from XY path
-- Converts vector_envelope.points into LFO envelopes for each of the 4 groups
-- ============================================================================

-- Convert vector envelope XY path points to per-group gain envelopes
-- Returns a table with envelope points for each of the 4 groups
function PakettiMetaSynthGenerateVectorEnvelopeCurves(vector_envelope, num_points)
  num_points = num_points or 128
  
  local points = vector_envelope.points or {}
  if #points < 2 then
    -- Default to center position if no valid path
    points = {
      {x = 0.5, y = 0.5, time = 0},
      {x = 0.5, y = 0.5, time = 1}
    }
  end
  
  -- Generate envelope curves for each of the 4 groups
  local group_curves = {
    group_a = {},  -- Bottom-left
    group_b = {},  -- Bottom-right
    group_c = {},  -- Top-left
    group_d = {}   -- Top-right
  }
  
  -- Interpolate XY position at each point in the envelope
  for i = 1, num_points do
    local normalized_time = (i - 1) / (num_points - 1)  -- 0 to 1
    
    -- Find the two path points that bracket this time
    local x, y
    local found = false
    
    for pi = 1, #points - 1 do
      local p1 = points[pi]
      local p2 = points[pi + 1]
      
      if normalized_time >= p1.time and normalized_time <= p2.time then
        -- Linear interpolation between path points
        local segment_progress = 0
        if p2.time ~= p1.time then
          segment_progress = (normalized_time - p1.time) / (p2.time - p1.time)
        end
        
        x = p1.x + (p2.x - p1.x) * segment_progress
        y = p1.y + (p2.y - p1.y) * segment_progress
        found = true
        break
      end
    end
    
    -- If not found (edge case), use nearest point
    if not found then
      if normalized_time <= points[1].time then
        x = points[1].x
        y = points[1].y
      else
        x = points[#points].x
        y = points[#points].y
      end
    end
    
    -- Calculate equal power gains for this XY position
    local gains = PakettiMetaSynthCalculateVectorGainsEqualPower(x, y)
    
    -- Store gain values for each group
    table.insert(group_curves.group_a, {time = i, value = gains.group_a})
    table.insert(group_curves.group_b, {time = i, value = gains.group_b})
    table.insert(group_curves.group_c, {time = i, value = gains.group_c})
    table.insert(group_curves.group_d, {time = i, value = gains.group_d})
  end
  
  return group_curves
end

-- Add Vector Envelope LFOs to all 4 group master chains
-- Creates one LFO per group with a custom envelope derived from the XY path
function PakettiMetaSynthAddVectorEnvelopeLFOs(group_master_chains, architecture)
  if #group_master_chains ~= 4 then
    print("PakettiMetaSynth: Vector envelope requires exactly 4 groups")
    return
  end
  
  local vector_envelope = architecture.vector_envelope
  if not vector_envelope or not vector_envelope.enabled then
    return
  end
  
  -- Generate per-group gain curves from the XY path
  local group_curves = PakettiMetaSynthGenerateVectorEnvelopeCurves(vector_envelope, 128)
  
  -- Calculate LFO frequency from envelope duration
  local duration = vector_envelope.duration or 4.0
  local lfo_freq = 1.0 / duration  -- Hz
  
  -- Convert to Renoise LFO frequency parameter value
  local lfo_freq_param = PakettiMetaSynthCalculateLFOFrequency("free", lfo_freq, nil, nil)
  
  local corner_names = {"group_a", "group_b", "group_c", "group_d"}
  local corner_labels = {"BL", "BR", "TL", "TR"}
  
  print(string.format("PakettiMetaSynth: Adding Vector Envelope LFOs (duration=%.1fs, freq=%.3f Hz)",
    duration, lfo_freq))
  
  for gi, group_master_info in ipairs(group_master_chains) do
    local chain = group_master_info.chain
    local corner = corner_names[gi]
    local envelope_curve = group_curves[corner]
    
    -- Get the vector gainer position
    local gainer_position = group_master_info.vector_gainer_position
    if not gainer_position then
      print(string.format("PakettiMetaSynth: No vector gainer found for group %d, skipping envelope LFO", gi))
    else
      -- Create LFO with custom envelope
      local lfo = PakettiMetaSynthCreateCrossfadeLFO(
        chain,
        envelope_curve,
        string.format("Vector Env %s", corner_labels[gi]),
        gainer_position,
        1,              -- Gain parameter
        lfo_freq_param
      )
      
      if lfo then
        -- Set one-shot mode if envelope doesn't loop
        if not vector_envelope.loop then
          -- Note: One-shot mode is set via XML in CreateCrossfadeLFO, but we can update it here
          -- The current implementation loops by default - we'd need to modify the XML for one-shot
          print(string.format("PakettiMetaSynth: Vector Envelope LFO added to '%s' (looping)", 
            group_master_info.chain_name))
        else
          print(string.format("PakettiMetaSynth: Vector Envelope LFO added to '%s' (looping)", 
            group_master_info.chain_name))
        end
        
        group_master_info.vector_envelope_lfo = lfo
      end
    end
  end
end

-- Helper function to generate common vector envelope presets
function PakettiMetaSynthGetVectorEnvelopePreset(preset_name)
  local presets = {
    -- Circle: sweep around all 4 corners
    circle = {
      enabled = true,
      points = {
        {x = 0.5, y = 0.0, time = 0.0},    -- Bottom center
        {x = 1.0, y = 0.5, time = 0.25},   -- Right center
        {x = 0.5, y = 1.0, time = 0.5},    -- Top center
        {x = 0.0, y = 0.5, time = 0.75},   -- Left center
        {x = 0.5, y = 0.0, time = 1.0}     -- Back to bottom
      },
      loop = true,
      duration = 4.0
    },
    
    -- Figure-8: sweep in figure-8 pattern
    figure8 = {
      enabled = true,
      points = {
        {x = 0.5, y = 0.5, time = 0.0},    -- Center
        {x = 1.0, y = 1.0, time = 0.125},  -- Top-right
        {x = 0.5, y = 0.5, time = 0.25},   -- Center
        {x = 0.0, y = 1.0, time = 0.375},  -- Top-left
        {x = 0.5, y = 0.5, time = 0.5},    -- Center
        {x = 0.0, y = 0.0, time = 0.625},  -- Bottom-left
        {x = 0.5, y = 0.5, time = 0.75},   -- Center
        {x = 1.0, y = 0.0, time = 0.875},  -- Bottom-right
        {x = 0.5, y = 0.5, time = 1.0}     -- Back to center
      },
      loop = true,
      duration = 8.0
    },
    
    -- Diagonal: sweep from BL to TR and back
    diagonal = {
      enabled = true,
      points = {
        {x = 0.0, y = 0.0, time = 0.0},    -- Bottom-left
        {x = 1.0, y = 1.0, time = 0.5},    -- Top-right
        {x = 0.0, y = 0.0, time = 1.0}     -- Back to BL
      },
      loop = true,
      duration = 4.0
    },
    
    -- Square: visit each corner in sequence
    square = {
      enabled = true,
      points = {
        {x = 0.0, y = 0.0, time = 0.0},    -- Bottom-left
        {x = 1.0, y = 0.0, time = 0.25},   -- Bottom-right
        {x = 1.0, y = 1.0, time = 0.5},    -- Top-right
        {x = 0.0, y = 1.0, time = 0.75},   -- Top-left
        {x = 0.0, y = 0.0, time = 1.0}     -- Back to BL
      },
      loop = true,
      duration = 4.0
    },
    
    -- X sweep: sweep X axis at center Y
    x_sweep = {
      enabled = true,
      points = {
        {x = 0.0, y = 0.5, time = 0.0},    -- Left center
        {x = 1.0, y = 0.5, time = 0.5},    -- Right center
        {x = 0.0, y = 0.5, time = 1.0}     -- Back to left
      },
      loop = true,
      duration = 2.0
    },
    
    -- Y sweep: sweep Y axis at center X
    y_sweep = {
      enabled = true,
      points = {
        {x = 0.5, y = 0.0, time = 0.0},    -- Bottom center
        {x = 0.5, y = 1.0, time = 0.5},    -- Top center
        {x = 0.5, y = 0.0, time = 1.0}     -- Back to bottom
      },
      loop = true,
      duration = 2.0
    },
    
    -- Random walk: visit random positions
    random_walk = {
      enabled = true,
      points = {
        {x = 0.5, y = 0.5, time = 0.0},
        {x = math.random(), y = math.random(), time = 0.2},
        {x = math.random(), y = math.random(), time = 0.4},
        {x = math.random(), y = math.random(), time = 0.6},
        {x = math.random(), y = math.random(), time = 0.8},
        {x = 0.5, y = 0.5, time = 1.0}
      },
      loop = true,
      duration = 6.0
    }
  }
  
  return presets[preset_name] or presets.circle
end

-- ============================================================================
-- GLOBAL MODULATION: Shared LFO sources across all groups
-- Creates synchronized LFOs in each group master chain that modulate the same targets
-- This provides instrument-wide modulation without being limited to a single chain
-- ============================================================================

-- LFO wave type mapping for XML generation
local GLOBAL_MOD_LFO_TYPES = {
  sine = 0,
  triangle = 1,
  square = 2,
  saw = 3,
  random = 4
}

-- Create a global modulation LFO on a chain
-- Returns the LFO device or nil if creation failed
function PakettiMetaSynthCreateGlobalModLFO(chain, lfo_config, lfo_name, target_device_index, target_param_index)
  if not lfo_config or not lfo_config.enabled then
    return nil
  end
  
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "*LFO", position)
  
  if device then
    device.display_name = lfo_name or "Global LFO"
    
    -- Calculate LFO frequency
    local freq_param = PakettiMetaSynthCalculateLFOFrequency(
      "free",
      lfo_config.frequency or 0.5,
      nil,
      nil
    )
    
    -- Get wave type
    local wave_type = GLOBAL_MOD_LFO_TYPES[lfo_config.shape or "sine"] or 0
    
    -- Set LFO type parameter (parameter index for Type varies by device)
    -- For *LFO: Type is usually parameter 4
    local params = device.parameters
    for pi = 1, #params do
      local param = params[pi]
      if param.name == "Type" then
        -- Set to specified wave type
        param.value = wave_type / 4.0  -- Normalize to 0-1 range (5 types: 0,1,2,3,4)
        break
      end
    end
    
    -- Set frequency
    for pi = 1, #params do
      local param = params[pi]
      if param.name == "Frequency" then
        param.value = freq_param
        break
      end
    end
    
    -- Set amplitude (modulation depth)
    for pi = 1, #params do
      local param = params[pi]
      if param.name == "Amplitude" then
        param.value = lfo_config.amplitude or 0.5
        break
      end
    end
    
    -- Set offset (center point)
    for pi = 1, #params do
      local param = params[pi]
      if param.name == "Offset" then
        param.value = lfo_config.offset or 0.0
        break
      end
    end
    
    -- Set routing if target specified
    if target_device_index and target_param_index then
      local effect_index = target_device_index - 1
      device.parameters[1].value = -1            -- Current chain
      device.parameters[2].value = effect_index  -- Target device
      device.parameters[3].value = target_param_index  -- Target parameter
    end
    
    return device
  end
  
  return nil
end

-- Add global modulation to group master chains
-- Creates synchronized LFOs in each group based on global_modulation settings
function PakettiMetaSynthAddGlobalModulation(group_master_chains, architecture)
  local global_mod = architecture.global_modulation
  if not global_mod or not global_mod.enabled then
    return
  end
  
  print("PakettiMetaSynth: Adding Global Modulation to groups")
  
  local lfo1_config = global_mod.lfo1
  local lfo2_config = global_mod.lfo2
  
  for gi, group_master_info in ipairs(group_master_chains) do
    local chain = group_master_info.chain
    
    -- Add Global LFO 1 if enabled
    if lfo1_config and lfo1_config.enabled then
      -- Find target device and parameter based on target name
      local target_info = PakettiMetaSynthResolveGlobalModTarget(chain, lfo1_config.targets, gi)
      
      local lfo1 = PakettiMetaSynthCreateGlobalModLFO(
        chain,
        lfo1_config,
        string.format("Global LFO1 G%d", gi),
        target_info.device_index,
        target_info.param_index
      )
      
      if lfo1 then
        group_master_info.global_lfo1 = lfo1
        print(string.format("PakettiMetaSynth: Added Global LFO1 to '%s' (%.2f Hz, %s)",
          group_master_info.chain_name, lfo1_config.frequency, lfo1_config.shape))
      end
    end
    
    -- Add Global LFO 2 if enabled
    if lfo2_config and lfo2_config.enabled then
      local target_info = PakettiMetaSynthResolveGlobalModTarget(chain, lfo2_config.targets, gi)
      
      local lfo2 = PakettiMetaSynthCreateGlobalModLFO(
        chain,
        lfo2_config,
        string.format("Global LFO2 G%d", gi),
        target_info.device_index,
        target_info.param_index
      )
      
      if lfo2 then
        group_master_info.global_lfo2 = lfo2
        print(string.format("PakettiMetaSynth: Added Global LFO2 to '%s' (%.2f Hz, %s)",
          group_master_info.chain_name, lfo2_config.frequency, lfo2_config.shape))
      end
    end
  end
end

-- Resolve global modulation target to device/parameter indices
-- targets can include: "group_gain", "filter_cutoff", "filter_resonance", etc.
function PakettiMetaSynthResolveGlobalModTarget(chain, targets, group_index)
  local result = {
    device_index = nil,
    param_index = nil
  }
  
  if not targets or #targets == 0 then
    return result
  end
  
  local target_name = targets[1]  -- Use first target for now
  
  -- Search for target device in chain
  for di = 1, #chain.devices do
    local device = chain.devices[di]
    local device_name = device.display_name or device.name
    
    -- Match target name to device type
    if target_name == "group_gain" then
      if device_name:find("Group") and device_name:find("Gainer") then
        result.device_index = di
        result.param_index = 1  -- Gain parameter
        break
      end
    elseif target_name == "filter_cutoff" then
      if device_name:find("Filter") then
        -- Look for cutoff parameter
        for pi = 1, #device.parameters do
          if device.parameters[pi].name:find("Cutoff") or 
             device.parameters[pi].name:find("Frequency") then
            result.device_index = di
            result.param_index = pi
            break
          end
        end
        if result.device_index then break end
      end
    elseif target_name == "filter_resonance" then
      if device_name:find("Filter") then
        for pi = 1, #device.parameters do
          if device.parameters[pi].name:find("Resonance") or 
             device.parameters[pi].name:find("Q") then
            result.device_index = di
            result.param_index = pi
            break
          end
        end
        if result.device_index then break end
      end
    elseif target_name == "scan_gain" then
      if device_name:find("Scan") and device_name:find("Gainer") then
        result.device_index = di
        result.param_index = 1
        break
      end
    elseif target_name == "vector_gain" then
      if device_name:find("Vector") then
        result.device_index = di
        result.param_index = 1
        break
      end
    end
  end
  
  return result
end

-- Helper to get available global modulation targets for UI
function PakettiMetaSynthGetGlobalModTargets()
  return {
    {name = "group_gain", label = "Group Gain"},
    {name = "scan_gain", label = "Scan Gain"},
    {name = "vector_gain", label = "Vector Gain"},
    {name = "filter_cutoff", label = "Filter Cutoff"},
    {name = "filter_resonance", label = "Filter Resonance"}
  }
end

-- Get default global modulation settings
function PakettiMetaSynthGetDefaultGlobalModulation()
  return {
    enabled = false,
    lfo1 = {
      enabled = false,
      frequency = 0.5,
      shape = "sine",
      amplitude = 0.5,
      offset = 0.0,
      targets = {"group_gain"}
    },
    lfo2 = {
      enabled = false,
      frequency = 0.25,
      shape = "triangle",
      amplitude = 0.3,
      offset = 0.0,
      targets = {}
    },
    envelope = {
      enabled = false,
      attack = 0.1,
      decay = 0.2,
      sustain = 0.7,
      release = 0.5,
      targets = {}
    }
  }
end

-- ============================================================================
-- SECTION 7: INSTRUMENT GENERATION (TWO-PHASE APPROACH)
-- ============================================================================

-- Generate a complete instrument from an architecture
-- Uses two-phase approach: 
--   Phase 1: Create ALL chains first (no sends)
--   Phase 2: Add ALL sends using stable indices
function PakettiMetaSynthGenerateInstrument(architecture)
  -- Safety check: ensure song is loaded
  local song = renoise.song()
  if not song then
    print("[PakettiMetaSynth Generate] ERROR: No song loaded in GenerateInstrument")
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return nil
  end
  
  local selected_index = song.selected_instrument_index
  local instrument_name = architecture and architecture.name or "unknown"
  print(string.format("[PakettiMetaSynth Generate] === Starting GenerateInstrument ==="))
  print(string.format("[PakettiMetaSynth Generate] Instrument index: %d, architecture name: '%s'", selected_index, instrument_name))
  
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = nil
  if PakettiTemporarilyDisableNewSampleMonitoring then
    AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    print("[PakettiMetaSynth Generate] AutoSamplify monitoring disabled")
  end
  
  trueRandomSeed()
  
  -- Validate architecture first
  print("[PakettiMetaSynth Generate] Validating architecture...")
  local validation = PakettiMetaSynthValidateArchitecture(architecture)
  if not validation.valid then
    print(string.format("[PakettiMetaSynth Generate] ERROR: Architecture validation FAILED with %d errors", #validation.errors))
    for _, err in ipairs(validation.errors) do
      print(string.format("[PakettiMetaSynth Generate] Validation error: %s", err))
    end
    renoise.app():show_status("PakettiMetaSynth: Architecture validation failed - check console")
    -- Restore AutoSamplify monitoring
    if PakettiRestoreNewSampleMonitoring and AutoSamplifyMonitoringState then
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
      print("[PakettiMetaSynth Generate] AutoSamplify monitoring restored (after validation failure)")
    end
    print(string.format("[PakettiMetaSynth Generate] Returning nil due to validation failure"))
    return nil
  end
  
  print(string.format("[PakettiMetaSynth Generate] Architecture validation PASSED (%d warnings)", #validation.warnings))
  
  -- Show warnings
  for _, warn in ipairs(validation.warnings) do
    print(string.format("[PakettiMetaSynth Generate] Validation warning: %s", warn))
  end
  
  -- Create or reset instrument
  local instrument = song.selected_instrument
  instrument:clear()
  instrument.name = architecture.name
  
  local sample_index = 1
  local mod_set_index = 0
  local randomization_amount = architecture.fx_randomization and architecture.fx_randomization.param_randomization or 0.3
  
  -- ========================================================================
  -- CHAIN REGISTRY: Stores all chain info for Phase 2 routing
  -- ========================================================================
  local chain_registry = {
    -- Per-group data
    groups = {},  -- [group_index] = { oscillators = {}, group_frame_chains = {}, group_master = nil }
    -- Global
    stack_master = nil
  }
  
  print("PakettiMetaSynth: === PHASE 1: Creating all chains (no sends) ===")
  
  -- ========================================================================
  -- PHASE 1: CREATE ALL CHAINS (NO ROUTING/SENDS)
  -- ========================================================================
  
  for gi, group in ipairs(architecture.oscillator_groups) do
    print(string.format("PakettiMetaSynth: Building Group '%s'", group.name))
    
    -- Initialize registry for this group
    chain_registry.groups[gi] = {
      group_name = group.name,
      oscillators = {},  -- [osc_index] = { frame_chains = {}, osc_fx = nil }
      group_master = nil
    }
    
    local total_oscs_in_group = #group.oscillators
    
    -- Process each oscillator in the group
    for oi, osc in ipairs(group.oscillators) do
      print(string.format("PakettiMetaSynth: Building Oscillator '%s' (%d samples, %d unison, %d frames)",
        osc.name, osc.sample_count, osc.unison_voices, osc.frame_count))
      
      -- Initialize registry for this oscillator
      chain_registry.groups[gi].oscillators[oi] = {
        osc_name = osc.name,
        frame_chains = {},
        osc_fx = nil
      }
      
      -- Get sample files based on source
      local sample_files = {}
      local total_samples_needed = osc.sample_count * osc.unison_voices
      
      if osc.sample_source == "akwf" then
        -- Use profile-driven family filtering if waveform families are specified
        if osc.waveform_families and #osc.waveform_families > 0 then
          sample_files = PakettiMetaSynthGetAKWFSamplesByFamily(
            osc.waveform_families, 
            total_samples_needed, 
            osc.avoid_families
          )
        else
          sample_files = PakettiMetaSynthGetRandomAKWFSamples(total_samples_needed)
        end
      elseif osc.sample_source == "folder" and osc.sample_folder then
        sample_files = PakettiMetaSynthGetRandomSamplesFromFolder(osc.sample_folder, total_samples_needed)
      end
      
      -- Get current chain index before creating frame chains
      local starting_chain_index = #instrument.sample_device_chains
      
      -- Build frame chains for this oscillator (creates chains, adds FX, no sends)
      local frame_routing = PakettiMetaSynthBuildFrameRouting(
        instrument, 
        {
          name = osc.name,
          frame_count = osc.frame_count,
          fx_randomization = architecture.fx_randomization
        },
        starting_chain_index,
        architecture.crossfade
      )
      
      -- Store frame chains in registry
      for fi, frame_info in ipairs(frame_routing) do
        table.insert(chain_registry.groups[gi].oscillators[oi].frame_chains, frame_info)
      end
      
      -- ALWAYS create Oscillator FX chain as summing bus - NO ROUTING YET
      local osc_fx_info = PakettiMetaSynthCreateOscillatorFXChain(
        instrument,
        osc,
        randomization_amount
      )
      
      -- Store Osc FX chain in registry (always exists now)
      chain_registry.groups[gi].oscillators[oi].osc_fx = osc_fx_info
      
      -- Add Osc Gainer (for oscillator crossfade) to the Oscillator FX chain
      PakettiMetaSynthAddGroupCrossfadeToChain(
        osc_fx_info.chain,
        osc_fx_info,
        oi,
        total_oscs_in_group,
        group
      )
      
      -- Create modulation set for this oscillator
      local mod_set, mod_set_idx = PakettiMetaSynthCreateModulationSet(instrument, osc.name .. " Mod")
      mod_set_index = mod_set_idx
      
      -- Apply modulation profile (GESTURE layer - voice articulation)
      -- Use modulation-specific resolution that checks architecture.modulation_layer first
      local modulation_rules = PakettiMetaSynthResolveModulationProfile(osc, group, architecture)
      PakettiMetaSynthApplyModulationRules(mod_set, modulation_rules, architecture)
      
      -- Get detune and pan spread values (with defaults)
      local detune_spread = osc.detune_spread or 10
      local pan_spread = osc.pan_spread or 0.8
      
      -- Load samples and assign to frames
      local file_index = 1
      for si = 1, osc.sample_count do
        for ui = 1, osc.unison_voices do
          -- Ensure sample slot exists
          while #instrument.samples < sample_index do
            instrument:insert_sample_at(#instrument.samples + 1)
          end
          
          local sample = instrument.samples[sample_index]
          
          -- Load sample if we have files
          if file_index <= #sample_files then
            local success = sample.sample_buffer:load_from(sample_files[file_index])
            if success then
              sample.name = string.format("%s S%d U%d", osc.name, si, ui)
            else
              sample.name = string.format("%s S%d U%d (load failed)", osc.name, si, ui)
            end
            file_index = file_index + 1
          else
            -- No file available, create silent sample
            sample.name = string.format("%s S%d U%d (empty)", osc.name, si, ui)
          end
          
          -- Apply unison detuning (with division by zero protection)
          if osc.unison_voices > 1 then
            local detune_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * detune_spread
            sample.fine_tune = math.floor(detune_offset * 1.28) -- Convert cents to Renoise fine tune
            
            -- Pan spread for unison
            local pan_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * pan_spread
            sample.panning = 0.5 + pan_offset * 0.5
          else
            -- Single voice: center pan, no detune
            sample.fine_tune = 0
            sample.panning = 0.5
          end
          
          -- Assign to frame (cycle through frames)
          local frame_for_sample = ((si - 1) % osc.frame_count) + 1
          local frame_chains = chain_registry.groups[gi].oscillators[oi].frame_chains
          if frame_chains[frame_for_sample] then
            PakettiMetaSynthAssignSampleToFXChain(sample, frame_chains[frame_for_sample].chain_index)
          end
          
          -- Assign to modulation set
          PakettiMetaSynthAssignSampleToModSet(sample, mod_set_index)
          
          -- Set loop mode for single-cycle waveforms
          if osc.sample_source == "akwf" then
            sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
          end
          
          sample_index = sample_index + 1
        end
      end
    end
    
    -- CREATE GROUP FRAME CHAINS if enabled (meta-wavetable at group level)
    local group_frame_chains = nil
    if group.group_frames_enabled and group.group_frame_count > 1 then
      group_frame_chains = PakettiMetaSynthCreateGroupFrameChains(
        instrument,
        group,
        group.name,
        randomization_amount
      )
      print(string.format("PakettiMetaSynth: Created %d Group Frame chains for '%s'", 
        #group_frame_chains, group.name))
    end
    chain_registry.groups[gi].group_frame_chains = group_frame_chains
    
    -- ALWAYS create Group Master chain as summing bus - NO ROUTING YET
    local total_groups = #architecture.oscillator_groups
    local group_master_info = PakettiMetaSynthCreateGroupMasterChain(
      instrument,
      group,
      group.name,
      gi,              -- group_index for Group Gainer crossfade position
      total_groups,    -- total_groups for Group Gainer crossfade calculation
      randomization_amount
    )
    
    -- Store Group Master in registry (always exists now)
    chain_registry.groups[gi].group_master = group_master_info
  end
  
  -- ALWAYS create Stack Master chain as final summing bus - NO ROUTING YET
  local stack_master_info = PakettiMetaSynthCreateStackedMasterChain(
    instrument,
    architecture,
    randomization_amount
  )
  
  -- Store Stack Master in registry (always exists now)
  chain_registry.stack_master = stack_master_info
  
  -- Create Total Group Frame chains if enabled (Layer 7) - NO ROUTING YET
  local total_group_frame_chains = nil
  if architecture.global_fx_frames_enabled and architecture.global_fx_frame_count > 1 then
    print(string.format("PakettiMetaSynth: Creating %d Total Group Frame chains...", 
      architecture.global_fx_frame_count))
    total_group_frame_chains = PakettiMetaSynthCreateTotalGroupFrameChains(
      instrument,
      architecture,
      randomization_amount
    )
    chain_registry.total_group_frames = total_group_frame_chains
  end
  
  -- ========================================================================
  -- PHASE 2: ADD ALL SENDS (using stable indices from registry)
  -- All buses now always exist, so routing is deterministic
  -- ========================================================================
  
  print("PakettiMetaSynth: === PHASE 2: Adding sends with stable indices ===")
  
  -- Collect all group master chains for Stack Master routing
  local all_group_master_chains = {}
  
  for gi, group_data in ipairs(chain_registry.groups) do
    -- Collect Osc FX chains that need routing
    local osc_fx_chains_for_routing = {}
    
    for oi, osc_data in ipairs(group_data.oscillators) do
      -- Route Frame chains -> Osc FX chain (Osc FX always exists now)
      PakettiMetaSynthRouteFramesToOscFX(osc_data.frame_chains, osc_data.osc_fx)
      -- Collect Osc FX chain for group routing
      table.insert(osc_fx_chains_for_routing, osc_data.osc_fx)
    end
    
    -- Check if Group Frame chains are enabled
    if group_data.group_frame_chains and #group_data.group_frame_chains > 0 then
      -- NEW: Route Osc FX -> Group Frame chains -> Group Master
      print(string.format("PakettiMetaSynth: Routing through %d Group Frame chains for '%s'",
        #group_data.group_frame_chains, group_data.group_name))
      
      -- Route Osc FX chains to all Group Frame chains
      PakettiMetaSynthRouteOscFXToGroupFrames(osc_fx_chains_for_routing, group_data.group_frame_chains)
      
      -- Add Group Frame Vector Synthesis if enabled (requires 4 frames)
      if #group_data.group_frame_chains == 4 then
        local group_config = architecture.oscillator_groups[gi]
        PakettiMetaSynthAddGroupFrameVectorSynthesis(group_data.group_frame_chains, group_config, architecture)
      end
      
      -- Route Group Frame chains to Group Master
      PakettiMetaSynthRouteGroupFramesToMaster(group_data.group_frame_chains, group_data.group_master)
    else
      -- Standard routing: Osc FX -> Group Master
      PakettiMetaSynthRouteChainsToGroupMaster(osc_fx_chains_for_routing, group_data.group_master)
    end
    
    table.insert(all_group_master_chains, group_data.group_master)
  end
  
  -- Add Inter-Group Scan if enabled (wavetable/vector across groups)
  if architecture.group_scan_enabled and #all_group_master_chains > 1 then
    PakettiMetaSynthAddInterGroupScan(all_group_master_chains, architecture)
  end
  
  -- Add Vector Synthesis if enabled (requires exactly 4 groups)
  if architecture.vector_enabled and #all_group_master_chains == 4 then
    PakettiMetaSynthAddVectorSynthesis(all_group_master_chains, architecture)
  end
  
  -- Add Global Modulation if enabled (shared LFOs across all groups)
  if architecture.global_modulation and architecture.global_modulation.enabled then
    PakettiMetaSynthAddGlobalModulation(all_group_master_chains, architecture)
  end
  
  -- Route Group Masters -> Stack Master (Stack Master always exists now)
  PakettiMetaSynthRouteGroupMastersToStackedMaster(all_group_master_chains, chain_registry.stack_master)
  
  -- Route Stack Master -> Total Group Frame chains (Layer 7, if enabled)
  if chain_registry.total_group_frames and #chain_registry.total_group_frames > 0 then
    print(string.format("PakettiMetaSynth: Routing Stack Master through %d Total Group Frame chains",
      #chain_registry.total_group_frames))
    PakettiMetaSynthRouteStackedMasterToTotalGroupFrames(chain_registry.stack_master, chain_registry.total_group_frames)
    
    -- Add Global FX Wavetable Scan if enabled
    if architecture.global_fx_scan_enabled and #chain_registry.total_group_frames >= 2 then
      PakettiMetaSynthAddTotalGroupFramesWavetableScan(chain_registry.total_group_frames, architecture)
    end
    
    -- Add Global FX Vector Synthesis if enabled (requires exactly 4 frames)
    if architecture.global_fx_vector_enabled and #chain_registry.total_group_frames == 4 then
      PakettiMetaSynthAddTotalGroupFramesVectorSynthesis(chain_registry.total_group_frames, architecture)
    end
  end
  
  -- ========================================================================
  -- FINAL OUTPUT STAGE (Master EQ, Limiter, Output Shaping)
  -- ========================================================================
  local final_output_info = nil
  if architecture.final_output_enabled then
    final_output_info = PakettiMetaSynthCreateFinalOutputChain(instrument, architecture, randomization_amount)
    chain_registry.final_output = final_output_info
    
    -- Route to Final Output from the last stage
    if final_output_info then
      if chain_registry.total_group_frames and #chain_registry.total_group_frames > 0 then
        -- Route from each Global FX Frame to Final Output
        for _, frame_info in ipairs(chain_registry.total_group_frames) do
          PakettiMetaSynthRouteToFinalOutput(frame_info, final_output_info)
        end
      else
        -- Route from Stack Master to Final Output
        PakettiMetaSynthRouteToFinalOutput(chain_registry.stack_master, final_output_info)
      end
    end
  end
  
  -- Add Spectral Morph Macro if enabled
  PakettiMetaSynthAddSpectralMorphMacro(instrument, architecture)
  
  -- ========================================================================
  -- FINALIZATION
  -- ========================================================================
  
  -- Set up macros
  if architecture.crossfade.control_source == "macro" then
    local macro_idx = architecture.crossfade.macro_index
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Crossfade"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  -- Set up Group Scan macro if using macro control
  if architecture.group_scan_enabled and architecture.group_scan_control_source == "macro" then
    local macro_idx = architecture.group_scan_macro_index or 6
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Group Scan"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  -- Set up Vector macros if using macro control
  if architecture.vector_enabled then
    if architecture.vector_x_source == "macro" then
      local macro_idx = architecture.vector_x_macro or 7
      if macro_idx >= 1 and macro_idx <= 8 then
        instrument.macros[macro_idx].name = "Vector X"
        instrument.macros[macro_idx].value = 0.5
      end
    end
    if architecture.vector_y_source == "macro" then
      local macro_idx = architecture.vector_y_macro or 8
      if macro_idx >= 1 and macro_idx <= 8 then
        instrument.macros[macro_idx].name = "Vector Y"
        instrument.macros[macro_idx].value = 0.5
      end
    end
  end
  
  -- Name additional macros
  instrument.macros[2].name = "Filter Cutoff"
  instrument.macros[3].name = "Filter Resonance"
  instrument.macros[4].name = "Attack"
  instrument.macros[5].name = "Release"
  
  -- Restore AutoSamplify monitoring
  if PakettiRestoreNewSampleMonitoring and AutoSamplifyMonitoringState then
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    print("[PakettiMetaSynth Generate] AutoSamplify monitoring restored")
  end
  
  -- Calculate total chains
  local total_chains = #instrument.sample_device_chains
  local total_samples = sample_index - 1
  
  print(string.format("[PakettiMetaSynth Generate] === Generation completed successfully ==="))
  print(string.format("[PakettiMetaSynth Generate] Instrument: index=%d, name='%s', samples=%d, chains=%d", 
    selected_index, instrument.name, total_samples, total_chains))
  
  -- Verify instrument has content
  if total_samples == 0 then
    print(string.format("[PakettiMetaSynth Generate] WARNING: Generated instrument has NO SAMPLES!"))
  end
  if total_chains == 0 then
    print(string.format("[PakettiMetaSynth Generate] WARNING: Generated instrument has NO FX CHAINS!"))
  end
  if instrument.name == "" or instrument.name == nil then
    print(string.format("[PakettiMetaSynth Generate] WARNING: Generated instrument has NO NAME!"))
  end
  
  renoise.app():show_status(string.format(
    "PakettiMetaSynth: Generated '%s' with %d samples, %d FX chains",
    architecture.name,
    total_samples,
    total_chains
  ))
  
  print(string.format("[PakettiMetaSynth Generate] Returning instrument object"))
  return instrument
end

-- ============================================================================
-- SECTION 7B: WAVETABLE ARCHITECTURE GENERATOR
-- ============================================================================
-- This implements the "true wavetable" conceptual model where:
-- - All samples go to a SOURCE CHAIN (Frame 1)
-- - #Send devices split the signal to parallel FRAME FX chains
-- - Each frame applies different FX to the SAME source
-- - Frame Gainers + Frame Morph LFO blend between FX treatments
-- - Oscillator Groups provide wavetable-style scanning between oscillators

-- Generate a wavetable-style instrument from an architecture
function PakettiMetaSynthGenerateWavetableInstrument(architecture)
  -- Temporarily disable AutoSamplify monitoring
  local AutoSamplifyMonitoringState = nil
  if rawget(_G, "PakettiTemporarilyDisableNewSampleMonitoring") then
    AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  end
  
  -- Create new instrument
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  local instrument = song.instruments[song.selected_instrument_index + 1]
  instrument.name = architecture.name or "MetaSynth Wavetable"
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  local randomization_amount = architecture.fx_randomization and architecture.fx_randomization.param_randomization or 0.3
  local sample_index = 1
  
  -- Registry to track all chains for routing
  local chain_registry = {
    groups = {},
    stack_master = nil
  }
  
  print("PakettiMetaSynth Wavetable: === PHASE 1: Creating all chains ===")
  
  -- ========================================================================
  -- PHASE 1: CREATE ALL CHAINS
  -- ========================================================================
  
  for gi, group in ipairs(architecture.oscillator_groups) do
    print(string.format("PakettiMetaSynth Wavetable: Building Group '%s'", group.name))
    
    chain_registry.groups[gi] = {
      group_name = group.name,
      oscillators = {},
      group_master = nil
    }
    
    local total_oscs_in_group = #group.oscillators
    
    for oi, osc in ipairs(group.oscillators) do
      print(string.format("PakettiMetaSynth Wavetable: Building Oscillator '%s' (%d samples, %d unison, %d frames)",
        osc.name, osc.sample_count, osc.unison_voices, osc.frame_count))
      
      chain_registry.groups[gi].oscillators[oi] = {
        osc_name = osc.name,
        source_chain = nil,
        frame_chains = {},
        osc_fx = nil
      }
      
      -- Get sample files
      local sample_files = {}
      local total_samples_needed = osc.sample_count * osc.unison_voices
      
      if osc.sample_source == "akwf" then
        -- Use profile-driven family filtering if waveform families are specified
        if osc.waveform_families and #osc.waveform_families > 0 then
          sample_files = PakettiMetaSynthGetAKWFSamplesByFamily(
            osc.waveform_families, 
            total_samples_needed, 
            osc.avoid_families
          )
        else
          sample_files = PakettiMetaSynthGetRandomAKWFSamples(total_samples_needed)
        end
      elseif osc.sample_source == "folder" and osc.sample_folder then
        sample_files = PakettiMetaSynthGetRandomSamplesFromFolder(osc.sample_folder, total_samples_needed)
      end
      
      -- ================================================================
      -- CREATE SOURCE CHAIN (Frame 1) - All samples go here
      -- ================================================================
      local source_chain_name = string.format("%s Source", osc.name)
      local source_chain, source_chain_index = PakettiMetaSynthCreateFXChain(instrument, source_chain_name)
      
      chain_registry.groups[gi].oscillators[oi].source_chain = {
        chain = source_chain,
        chain_index = source_chain_index,
        chain_name = source_chain_name
      }
      
      -- ================================================================
      -- CREATE FRAME FX CHAINS (Frame 2, 3, N) - Receive via #Send
      -- ================================================================
      local frame_count = osc.frame_count
      
      for frame = 1, frame_count do
        local frame_chain_name = string.format("%s Frame %d", osc.name, frame)
        local frame_chain, frame_chain_index = PakettiMetaSynthCreateFXChain(instrument, frame_chain_name)
        
        -- Add random FX to each frame chain
        if architecture.fx_randomization and architecture.fx_randomization.enabled then
          PakettiMetaSynthBuildRandomFXChain(
            frame_chain,
            architecture.fx_randomization.device_pool or PakettiMetaSynthSafeFXDevices,
            2,
            randomization_amount
          )
        end
        
        -- Generate crossfade curve for this frame position
        local crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
          architecture.crossfade.curve_type or "equal_power",
          128,
          frame,
          frame_count
        )
        
        -- Add Frame Gainer at the end
        local initial_gain = crossfade_curve[1].value
        local gainer, gainer_position = PakettiMetaSynthCreateGainer(frame_chain, initial_gain, 
          string.format("Frame %d Gainer", frame))
        
        -- Add Frame Morph LFO (controls this frame's gainer)
        local lfo = nil
        if frame_count > 1 then
          -- Calculate Frame LFO frequency from rate settings
          local frame_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
            architecture.crossfade.lfo_rate_mode,
            architecture.crossfade.lfo_rate_free,
            architecture.crossfade.lfo_rate_sync,
            architecture.crossfade.lfo_rate_preset
          )
          
          lfo = PakettiMetaSynthCreateCrossfadeLFO(
            frame_chain,
            crossfade_curve,
            string.format("Frame %d Morph LFO", frame),
            gainer_position,
            1,              -- Gain parameter
            frame_lfo_freq  -- LFO frequency
          )
        end
        
        table.insert(chain_registry.groups[gi].oscillators[oi].frame_chains, {
          chain = frame_chain,
          chain_index = frame_chain_index,
          chain_name = frame_chain_name,
          frame_number = frame,
          gainer = gainer,
          gainer_position = gainer_position,
          lfo = lfo,
          crossfade_curve = crossfade_curve
        })
      end
      
      -- ================================================================
      -- CREATE OSC FX CHAIN (summing bus for all frames)
      -- ================================================================
      local osc_fx_chain_name = osc.name .. " FX"
      local osc_fx_chain, osc_fx_chain_index = PakettiMetaSynthCreateFXChain(instrument, osc_fx_chain_name)
      
      -- Add Osc FX devices if enabled
      local osc_fx_devices = {}
      if osc.osc_fx_enabled then
        local device_count = osc.osc_fx_count or 2
        for i = 1, device_count do
          local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
          local device = PakettiMetaSynthInsertDevice(osc_fx_chain, random_device)
          if device then
            PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
            device.display_name = string.format("OscFX %d", i)
            table.insert(osc_fx_devices, device)
          end
        end
      end
      
      -- Add Osc Gainer for group crossfade (oscillator morphing within group)
      local osc_gainer = nil
      local osc_gainer_position = nil
      local osc_lfo = nil
      
      if total_oscs_in_group > 1 and group.group_crossfade_enabled then
        local osc_curve = PakettiMetaSynthGenerateCrossfadeCurve(
          group.group_crossfade_curve or "equal_power",
          128,
          oi,
          total_oscs_in_group
        )
        
        local osc_initial_gain = osc_curve[1].value
        osc_gainer, osc_gainer_position = PakettiMetaSynthCreateGainer(
          osc_fx_chain,
          osc_initial_gain,
          string.format("Osc %d/%d Gainer", oi, total_oscs_in_group)
        )
        
        -- Calculate Group LFO frequency from rate settings
        local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
          group.group_lfo_rate_mode,
          group.group_lfo_rate_free,
          group.group_lfo_rate_sync,
          group.group_lfo_rate_preset
        )
        
        osc_lfo = PakettiMetaSynthCreateCrossfadeLFO(
          osc_fx_chain,
          osc_curve,
          string.format("Osc %d Morph LFO", oi),
          osc_gainer_position,
          1,              -- Gain parameter
          group_lfo_freq  -- LFO frequency
        )
      end
      
      chain_registry.groups[gi].oscillators[oi].osc_fx = {
        chain = osc_fx_chain,
        chain_index = osc_fx_chain_index,
        chain_name = osc_fx_chain_name,
        devices = osc_fx_devices,
        osc_gainer = osc_gainer,
        osc_gainer_position = osc_gainer_position,
        osc_lfo = osc_lfo
      }
      
      print(string.format("PakettiMetaSynth Wavetable: Created Osc FX '%s' with %d devices", 
        osc_fx_chain_name, #osc_fx_devices))
      
      -- ================================================================
      -- CREATE MODULATION SET
      -- ================================================================
      local mod_set, mod_set_idx = PakettiMetaSynthCreateModulationSet(instrument, osc.name .. " Mod")
      
      -- Apply modulation profile (GESTURE layer - voice articulation)
      -- Use modulation-specific resolution that checks architecture.modulation_layer first
      local modulation_rules = PakettiMetaSynthResolveModulationProfile(osc, group, architecture)
      PakettiMetaSynthApplyModulationRules(mod_set, modulation_rules, architecture)
      
      -- ================================================================
      -- LOAD SAMPLES - ALL go to SOURCE CHAIN
      -- ================================================================
      local detune_spread = osc.detune_spread or 10
      local pan_spread = osc.pan_spread or 0.8
      local file_index = 1
      
      for si = 1, osc.sample_count do
        for ui = 1, osc.unison_voices do
          while #instrument.samples < sample_index do
            instrument:insert_sample_at(#instrument.samples + 1)
          end
          
          local sample = instrument.samples[sample_index]
          
          if file_index <= #sample_files then
            local success = sample.sample_buffer:load_from(sample_files[file_index])
            if success then
              sample.name = string.format("%s S%d U%d", osc.name, si, ui)
            else
              sample.name = string.format("%s S%d U%d (load failed)", osc.name, si, ui)
            end
            file_index = file_index + 1
          else
            sample.name = string.format("%s S%d U%d (empty)", osc.name, si, ui)
          end
          
          -- Unison detuning
          if osc.unison_voices > 1 then
            local detune_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * detune_spread
            sample.fine_tune = math.floor(detune_offset * 1.28)
            local pan_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * pan_spread
            sample.panning = 0.5 + pan_offset * 0.5
          else
            sample.fine_tune = 0
            sample.panning = 0.5
          end
          
          -- ALL samples go to SOURCE CHAIN (this is the key difference!)
          PakettiMetaSynthAssignSampleToFXChain(sample, source_chain_index)
          PakettiMetaSynthAssignSampleToModSet(sample, mod_set_idx)
          
          if osc.sample_source == "akwf" then
            sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
          end
          
          sample_index = sample_index + 1
        end
      end
    end
    
    -- ================================================================
    -- CREATE GROUP FRAME CHAINS (if enabled - meta-wavetable at group level)
    -- ================================================================
    local group_frame_chains = nil
    if group.group_frames_enabled and group.group_frame_count > 1 then
      group_frame_chains = PakettiMetaSynthCreateGroupFrameChains(
        instrument,
        group,
        group.name,
        randomization_amount
      )
      print(string.format("PakettiMetaSynth Wavetable: Created %d Group Frame chains for '%s'", 
        #group_frame_chains, group.name))
    end
    chain_registry.groups[gi].group_frame_chains = group_frame_chains
    
    -- ================================================================
    -- CREATE GROUP MASTER CHAIN
    -- ================================================================
    local total_groups = #architecture.oscillator_groups
    local group_master_info = PakettiMetaSynthCreateGroupMasterChain(
      instrument,
      group,
      group.name,
      gi,
      total_groups,
      randomization_amount
    )
    
    chain_registry.groups[gi].group_master = group_master_info
  end
  
  -- ================================================================
  -- CREATE STACKED MASTER CHAIN
  -- ================================================================
  local stack_master_info = PakettiMetaSynthCreateStackedMasterChain(
    instrument,
    architecture,
    randomization_amount
  )
  chain_registry.stack_master = stack_master_info
  
  -- Create Total Group Frame chains if enabled (Layer 7) - NO ROUTING YET
  local total_group_frame_chains = nil
  if architecture.global_fx_frames_enabled and architecture.global_fx_frame_count > 1 then
    print(string.format("PakettiMetaSynth Wavetable: Creating %d Total Group Frame chains...", 
      architecture.global_fx_frame_count))
    total_group_frame_chains = PakettiMetaSynthCreateTotalGroupFrameChains(
      instrument,
      architecture,
      randomization_amount
    )
    chain_registry.total_group_frames = total_group_frame_chains
  end
  
  -- ========================================================================
  -- PHASE 2: ADD ALL ROUTING (#Send devices)
  -- ========================================================================
  
  print("PakettiMetaSynth Wavetable: === PHASE 2: Adding routing ===")
  
  local all_group_master_chains = {}
  
  for gi, group_data in ipairs(chain_registry.groups) do
    local osc_fx_chains_for_group = {}
    
    for oi, osc_data in ipairs(group_data.oscillators) do
      local source_chain = osc_data.source_chain.chain
      local frame_chains = osc_data.frame_chains
      local osc_fx = osc_data.osc_fx
      
      -- Route SOURCE CHAIN -> all FRAME CHAINS via #Send
      -- Frame 1 gets the dry signal (no send needed, just route output)
      -- Frames 2+ get signal via #Send from source
      
      for fi, frame_info in ipairs(frame_chains) do
        if fi == 1 then
          -- Frame 1: Route source chain output directly to Frame 1
          -- Add #Send from source to Frame 1
          PakettiMetaSynthAddSendDevice(
            source_chain,
            frame_info.chain_index,
            "Send to Frame 1"
          )
        else
          -- Frames 2+: Add #Send from source chain
          PakettiMetaSynthAddSendDevice(
            source_chain,
            frame_info.chain_index,
            string.format("Send to Frame %d", fi)
          )
        end
        
        -- Route each Frame chain -> Osc FX chain
        PakettiMetaSynthAddSendDevice(
          frame_info.chain,
          osc_fx.chain_index,
          "Send to Osc FX"
        )
      end
      
      print(string.format("PakettiMetaSynth Wavetable: Routed %s Source -> %d Frames -> Osc FX",
        osc_data.osc_name, #frame_chains))
      
      table.insert(osc_fx_chains_for_group, osc_fx)
    end
    
    -- Check if Group Frame chains are enabled
    if group_data.group_frame_chains and #group_data.group_frame_chains > 0 then
      -- NEW: Route Osc FX -> Group Frame chains -> Group Master
      print(string.format("PakettiMetaSynth Wavetable: Routing through %d Group Frame chains for '%s'",
        #group_data.group_frame_chains, group_data.group_name))
      
      -- Route Osc FX chains to all Group Frame chains
      PakettiMetaSynthRouteOscFXToGroupFrames(osc_fx_chains_for_group, group_data.group_frame_chains)
      
      -- Add Group Frame Vector Synthesis if enabled (requires 4 frames)
      if #group_data.group_frame_chains == 4 then
        local group_config = architecture.oscillator_groups[gi]
        PakettiMetaSynthAddGroupFrameVectorSynthesis(group_data.group_frame_chains, group_config, architecture)
      end
      
      -- Route Group Frame chains to Group Master
      PakettiMetaSynthRouteGroupFramesToMaster(group_data.group_frame_chains, group_data.group_master)
    else
      -- Standard routing: Osc FX -> Group Master
      PakettiMetaSynthRouteChainsToGroupMaster(osc_fx_chains_for_group, group_data.group_master)
    end
    
    table.insert(all_group_master_chains, group_data.group_master)
  end
  
  -- Add Inter-Group Scan if enabled (wavetable/vector across groups)
  if architecture.group_scan_enabled and #all_group_master_chains > 1 then
    PakettiMetaSynthAddInterGroupScan(all_group_master_chains, architecture)
  end
  
  -- Add Vector Synthesis if enabled (requires exactly 4 groups)
  if architecture.vector_enabled and #all_group_master_chains == 4 then
    PakettiMetaSynthAddVectorSynthesis(all_group_master_chains, architecture)
  end
  
  -- Add Global Modulation if enabled (shared LFOs across all groups)
  if architecture.global_modulation and architecture.global_modulation.enabled then
    PakettiMetaSynthAddGlobalModulation(all_group_master_chains, architecture)
  end
  
  -- Route Group Masters -> Stack Master
  PakettiMetaSynthRouteGroupMastersToStackedMaster(all_group_master_chains, chain_registry.stack_master)
  
  -- Route Stack Master -> Global FX Frame chains (if enabled)
  if chain_registry.total_group_frames and #chain_registry.total_group_frames > 0 then
    print(string.format("PakettiMetaSynth Wavetable: Routing Stack Master through %d Global FX Frame chains",
      #chain_registry.total_group_frames))
    PakettiMetaSynthRouteStackedMasterToTotalGroupFrames(chain_registry.stack_master, chain_registry.total_group_frames)
    
    -- Add Global FX Wavetable Scan if enabled
    if architecture.global_fx_scan_enabled and #chain_registry.total_group_frames >= 2 then
      PakettiMetaSynthAddTotalGroupFramesWavetableScan(chain_registry.total_group_frames, architecture)
    end
    
    -- Add Global FX Vector Synthesis if enabled (requires exactly 4 frames)
    if architecture.global_fx_vector_enabled and #chain_registry.total_group_frames == 4 then
      PakettiMetaSynthAddTotalGroupFramesVectorSynthesis(chain_registry.total_group_frames, architecture)
    end
  end
  
  -- ========================================================================
  -- FINAL OUTPUT STAGE (Master EQ, Limiter, Output Shaping)
  -- ========================================================================
  local final_output_info = nil
  if architecture.final_output_enabled then
    final_output_info = PakettiMetaSynthCreateFinalOutputChain(instrument, architecture, randomization_amount)
    chain_registry.final_output = final_output_info
    
    -- Route to Final Output from the last stage
    if final_output_info then
      if chain_registry.total_group_frames and #chain_registry.total_group_frames > 0 then
        -- Route from each Global FX Frame to Final Output
        for _, frame_info in ipairs(chain_registry.total_group_frames) do
          PakettiMetaSynthRouteToFinalOutput(frame_info, final_output_info)
        end
      else
        -- Route from Stack Master to Final Output
        PakettiMetaSynthRouteToFinalOutput(chain_registry.stack_master, final_output_info)
      end
    end
  end
  
  -- Add Spectral Morph Macro if enabled
  PakettiMetaSynthAddSpectralMorphMacro(instrument, architecture)
  
  -- ========================================================================
  -- FINALIZATION
  -- ========================================================================
  
  if architecture.crossfade.control_source == "macro" then
    local macro_idx = architecture.crossfade.macro_index
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Frame Morph"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  -- Set up Group Scan macro if using macro control
  if architecture.group_scan_enabled and architecture.group_scan_control_source == "macro" then
    local macro_idx = architecture.group_scan_macro_index or 6
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Group Scan"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  -- Set up Vector macros if using macro control
  if architecture.vector_enabled then
    if architecture.vector_x_source == "macro" then
      local macro_idx = architecture.vector_x_macro or 7
      if macro_idx >= 1 and macro_idx <= 8 then
        instrument.macros[macro_idx].name = "Vector X"
        instrument.macros[macro_idx].value = 0.5
      end
    end
    if architecture.vector_y_source == "macro" then
      local macro_idx = architecture.vector_y_macro or 8
      if macro_idx >= 1 and macro_idx <= 8 then
        instrument.macros[macro_idx].name = "Vector Y"
        instrument.macros[macro_idx].value = 0.5
      end
    end
  end
  
  instrument.macros[2].name = "Osc Morph"
  instrument.macros[3].name = "Filter Cutoff"
  instrument.macros[4].name = "Attack"
  instrument.macros[5].name = "Release"
  
  if rawget(_G, "PakettiRestoreNewSampleMonitoring") and AutoSamplifyMonitoringState then
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  end
  
  local total_chains = #instrument.sample_device_chains
  
  renoise.app():show_status(string.format(
    "PakettiMetaSynth Wavetable: Generated '%s' with %d samples, %d FX chains",
    architecture.name,
    sample_index - 1,
    total_chains
  ))
  
  return instrument
end

-- ============================================================================
-- SECTION 8: RANDOMIZATION SYSTEM
-- ============================================================================

-- Randomize oscillator configuration
function PakettiMetaSynthRandomizeOscillator(osc, max_samples_remaining, profile_name, group, architecture)
  max_samples_remaining = max_samples_remaining or 12
  
  -- Get oscillator rules from profile
  local osc_rules = PakettiMetaSynthResolveProfile("oscillator", nil, group, architecture)
  local frame_rules = PakettiMetaSynthResolveProfile("frame", nil, group, architecture)
  
  -- Use profile-guided ranges or fallback to defaults
  local frame_range = osc_rules.frame_count_range or {1, 4}
  local unison_range = osc_rules.unison_range or {1, 4}
  local sample_range = osc_rules.sample_count_range or {1, 2}
  local detune_range = osc_rules.detune_range or {5, 25}
  local pan_range = osc_rules.pan_spread_range or {0.3, 1.0}
  
  -- Random frame count using profile range - determines minimum samples needed
  osc.frame_count = PakettiMetaSynthGetIntInRange(frame_range)
  
  -- Sample count must be >= frame_count so each frame has at least one sample
  -- Limited by remaining budget
  local min_samples = osc.frame_count
  local profile_max_samples = sample_range[2] or 4
  local max_samples = math.min(profile_max_samples, max_samples_remaining)
  if min_samples > max_samples then
    -- Not enough budget for this many frames, reduce frame count
    osc.frame_count = max_samples
    min_samples = max_samples
  end
  local sample_min = math.max(min_samples, sample_range[1] or 1)
  osc.sample_count = math.max(sample_min, math.min(math.random(sample_min, profile_max_samples), max_samples_remaining))
  
  -- Random unison using profile range, limited by remaining budget after samples
  local samples_used = osc.sample_count
  local max_unison = math.max(1, math.floor(max_samples_remaining / samples_used))
  local profile_unison = PakettiMetaSynthGetIntInRange(unison_range)
  osc.unison_voices = math.min(profile_unison, max_unison)
  
  -- Get sample selection rules from profile
  local sample_rules = PakettiMetaSynthResolveProfile("sample_selection", nil, group, architecture)
  local source_pref = sample_rules.source_preference or "akwf"
  local waveform_families = sample_rules.waveform_families or {}
  local avoid_families = sample_rules.avoid_families or {}
  
  -- Determine sample source based on profile preference and folder availability
  if source_pref == "folder" and PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
    osc.sample_source = "folder"
    osc.sample_folder = PakettiMetaSynthLastFolderPath
  elseif source_pref == "both" and PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
    -- Mix between folder and AKWF based on random selection
    local sources = {"akwf", "akwf", "folder"}
    osc.sample_source = sources[math.random(1, #sources)]
    if osc.sample_source == "folder" then
      osc.sample_folder = PakettiMetaSynthLastFolderPath
    end
  elseif source_pref == "akwf_first" and PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
    -- Prefer AKWF but allow folder as fallback
    local sources = {"akwf", "akwf", "akwf", "folder"}
    osc.sample_source = sources[math.random(1, #sources)]
    if osc.sample_source == "folder" then
      osc.sample_folder = PakettiMetaSynthLastFolderPath
    end
  elseif source_pref == "folder_first" and PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
    -- Prefer folder but allow AKWF as fallback
    local sources = {"folder", "folder", "folder", "akwf"}
    osc.sample_source = sources[math.random(1, #sources)]
    if osc.sample_source == "folder" then
      osc.sample_folder = PakettiMetaSynthLastFolderPath
    end
  else
    -- Default to AKWF
    osc.sample_source = "akwf"
  end
  
  -- Store waveform families for profile-driven AKWF selection
  osc.waveform_families = waveform_families
  osc.avoid_families = avoid_families
  
  -- Random spread values using profile ranges
  osc.detune_spread = PakettiMetaSynthGetValueInRange(detune_range)
  osc.pan_spread = PakettiMetaSynthGetValueInRange(pan_range)
  
  -- Oscillator FX settings - guided by FX profile (if set) or frame rules
  local fx_tendencies = PakettiMetaSynthGetFXTendencies("frame", nil, group, architecture)
  local fx_count_range = frame_rules.fx_count_range or {1, 4}
  
  osc.osc_fx_enabled = true
  osc.osc_fx_count = PakettiMetaSynthGetIntInRange(fx_count_range)
  -- Clamp to 1-5 when enabled (validation requires 1-5 when enabled)
  if osc.osc_fx_count < 1 then
    osc.osc_fx_count = 1
  elseif osc.osc_fx_count > 5 then
    osc.osc_fx_count = 5
  end
  
  -- Use profile FX tendencies if available, otherwise random
  if #fx_tendencies > 0 then
    osc.osc_fx_mode = "selective"
    osc.osc_fx_types = {}
    -- Pick FX from tendencies
    local shuffled = {}
    for _, fx in ipairs(fx_tendencies) do table.insert(shuffled, fx) end
    for i = #shuffled, 2, -1 do
      local j = math.random(1, i)
      shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local num_fx = math.min(osc.osc_fx_count, #shuffled)
    for i = 1, num_fx do
      table.insert(osc.osc_fx_types, shuffled[i])
    end
  else
    -- Random mode when no tendencies defined
    osc.osc_fx_mode = math.random() > 0.5 and "random" or "selective"
    osc.osc_fx_types = {}
    if osc.osc_fx_mode == "selective" then
      local fx_names = PakettiMetaSynthGetSelectableFXTypeNames()
      local num_types = math.random(1, math.min(3, #fx_names))
      local shuffled_types = {}
      for _, name in ipairs(fx_names) do table.insert(shuffled_types, name) end
      for i = #shuffled_types, 2, -1 do
        local j = math.random(1, i)
        shuffled_types[i], shuffled_types[j] = shuffled_types[j], shuffled_types[i]
      end
      for i = 1, num_types do
        table.insert(osc.osc_fx_types, shuffled_types[i])
      end
    end
  end
  
  -- Profile override: nil means inherit from group (default behavior)
  -- Optionally randomize a per-oscillator override (rare - 10% chance)
  if math.random() < 0.1 then
    osc.profile_override = PakettiMetaSynthGetRandomModulationProfile()
  else
    osc.profile_override = nil  -- Inherit from group/global
  end
  -- Clear deprecated field
  osc.modulation_profile = nil
  
  return osc
end

-- Randomize entire architecture
-- skip_seed: if true, skip seeding (useful when seed is already set, e.g. in batch generation)
function PakettiMetaSynthRandomizeArchitecture(architecture, skip_seed)
  skip_seed = skip_seed or false
  if not skip_seed then
    trueRandomSeed()
  end
  
  -- Initialize constraints if not present
  architecture.constraints = architecture.constraints or {}
  local constraints = architecture.constraints
  
  -- Set GLOBAL PROFILE at architecture level - defines musical intent for all layers
  architecture.global_profile = PakettiMetaSynthGetRandomModulationProfile()
  
  -- Initialize MODULATION LAYER settings
  -- 20% chance to override modulation independently of other layers
  architecture.modulation_layer = architecture.modulation_layer or {}
  if math.random() < 0.2 then
    architecture.modulation_layer.profile_override = PakettiMetaSynthGetRandomModulationProfile()
  else
    architecture.modulation_layer.profile_override = nil
  end
  architecture.modulation_layer.custom_modulation = nil  -- No custom modulation by default
  
  -- Random number of oscillator groups - respect constraints
  local group_range = constraints.group_count_range or {1, 2}
  local num_groups = math.random(group_range[1], group_range[2])
  architecture.oscillator_groups = {}
  
  local samples_remaining = 12
  
  -- LFO rate mode options
  local rate_modes = {"free", "tempo_sync", "preset"}
  local rate_presets = {"slow", "medium", "fast"}
  local rate_syncs = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"}
  
  for gi = 1, num_groups do
    -- Randomize Group LFO rate settings
    local group_rate_mode = rate_modes[math.random(1, #rate_modes)]
    
    -- Get oscillator groups rules from the global profile (or override if set)
    local group_profile_name = nil  -- nil = inherit from global
    -- 30% chance to override with a different profile for this group (hybrid sound)
    if math.random() < 0.3 then
      group_profile_name = PakettiMetaSynthGetRandomModulationProfile()
    end
    
    -- Get profile rules for this group
    local temp_group = { profile_override = group_profile_name }
    local osc_group_rules = PakettiMetaSynthResolveProfile("oscillator_groups", nil, temp_group, architecture)
    local group_frame_rules = PakettiMetaSynthResolveProfile("group_frame", nil, temp_group, architecture)
    
    -- Extract oscillator group FX from oscillator_groups layer
    local osc_group_fx_rules = {
      enabled = osc_group_rules.osc_group_fx_enabled,
      count_range = osc_group_rules.osc_group_fx_count_range or {1, 2},
      tendencies = osc_group_rules.osc_group_fx_tendencies or {}
    }
    
    local group = {
      name = "Group " .. string.char(64 + gi), -- A, B, C...
      crossfade_mode = ({"linear", "xy", "stack"})[math.random(1, 3)],
      -- Group crossfade settings (wavetable scanning) - guided by profile
      group_crossfade_enabled = osc_group_rules.crossfade_enabled ~= false,
      group_crossfade_curve = PakettiMetaSynthGetRandomCrossfadeCurve(),
      -- Group LFO rate settings - guided by profile
      group_lfo_rate_mode = group_rate_mode,
      group_lfo_rate_free = 0.1 + math.random() * 1.9,  -- 0.1-2.0 Hz
      group_lfo_rate_sync = rate_syncs[math.random(1, #rate_syncs)],
      group_lfo_rate_preset = osc_group_rules.lfo_rate_preset or rate_presets[math.random(1, #rate_presets)],
      -- Group Master FX settings - guided by profile oscillator_groups.osc_group_fx rules
      group_master_fx_enabled = osc_group_fx_rules.enabled ~= false,
      group_master_fx_mode = "selective",  -- Use profile tendencies
      group_master_fx_count = PakettiMetaSynthGetIntInRange(osc_group_fx_rules.count_range or {1, 4}),
      group_master_fx_types = {},
      
      -- GROUP FRAMES (meta-wavetable at group level) - guided by profile AND constraints
      group_frames_enabled = (constraints.allow_group_frames ~= false) and (group_frame_rules.enabled == true),
      group_frame_count = PakettiMetaSynthGetIntInRange(group_frame_rules.frame_count_range or {1, 1}),
      group_frame_morph_enabled = group_frame_rules.morph_enabled == true,
      group_frame_morph_speed = group_frame_rules.morph_speed or "none",
      group_frame_crossfade_curve = PakettiMetaSynthGetRandomCrossfadeCurve(),
      group_frame_control_source = "lfo",  -- Always LFO for now
      group_frame_lfo_rate_preset = rate_presets[math.random(1, #rate_presets)],
      group_frame_fx_enabled = group_frame_rules.enabled and #(group_frame_rules.fx_tendencies or {}) > 0,
      group_frame_fx_tendencies = group_frame_rules.fx_tendencies or {},
      group_frame_fx_count = PakettiMetaSynthGetIntInRange(constraints.fx_count_range or group_frame_rules.fx_count_range or {0, 0}),
      
      -- Profile override at GROUP level (nil = inherit from global_profile)
      profile_override = group_profile_name,
      -- DEPRECATED: modulation_profile - cleared for new architecture
      modulation_profile = nil,
      oscillators = {}
    }
    
    -- Ensure group master FX count is valid when enabled (must be 1-5)
    if group.group_master_fx_enabled and group.group_master_fx_count < 1 then
      group.group_master_fx_count = 1
    elseif group.group_master_fx_enabled and group.group_master_fx_count > 5 then
      group.group_master_fx_count = 5
    end
    
    -- Set group FX types from FX profile (respects fx_profile_override) or sound profile
    local fx_tendencies = PakettiMetaSynthGetFXTendencies("group", nil, group, architecture)
    if #fx_tendencies > 0 then
      local shuffled = {}
      for _, fx in ipairs(fx_tendencies) do table.insert(shuffled, fx) end
      for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
      end
      local num_fx = math.min(group.group_master_fx_count, #shuffled)
      for i = 1, num_fx do
        table.insert(group.group_master_fx_types, shuffled[i])
      end
    else
      -- Fallback: random FX if no tendencies defined
      group.group_master_fx_mode = "random"
    end
    
    -- Skip creating this group if no samples remaining
    if samples_remaining <= 0 then
      break
    end
    
    -- Random number of oscillators per group (1-3), minimum 1
    local max_oscs = math.min(3, samples_remaining)
    if max_oscs < 1 then max_oscs = 1 end
    local num_oscs = math.random(1, max_oscs)
    
    for oi = 1, num_oscs do
      if samples_remaining <= 0 then break end
      
      local osc = {
        name = "Osc " .. oi,
        sample_count = 1,
        unison_voices = 1,
        frame_count = 1,
        sample_source = "akwf",
        detune_spread = 10,
        pan_spread = 0.8,
        profile_override = nil,
        modulation_profile = nil
      }
      
      -- Pass group and architecture context for profile-guided randomization
      PakettiMetaSynthRandomizeOscillator(osc, samples_remaining, nil, group, architecture)
      samples_remaining = samples_remaining - (osc.sample_count * osc.unison_voices)
      
      table.insert(group.oscillators, osc)
    end
    
    -- Only add group if it has at least one oscillator
    if #group.oscillators > 0 then
      table.insert(architecture.oscillator_groups, group)
    end
  end
  
  -- Validate and adjust total sample count to ensure it never exceeds 12 (Renoise limit)
  local total_samples = PakettiMetaSynthCalculateTotalSamples(architecture)
  if total_samples > 12 then
    -- Reduce to fit within limit - prefer reducing unison voices first (less impact on sound)
    local reduction_factor = 12 / total_samples
    for gi, group in ipairs(architecture.oscillator_groups) do
      for oi, osc in ipairs(group.oscillators) do
        local osc_total = osc.sample_count * osc.unison_voices
        local new_total = math.max(1, math.floor(osc_total * reduction_factor))
        -- Prefer reducing unison first, then sample count if needed
        if osc.unison_voices > 1 then
          osc.unison_voices = math.max(1, math.floor(osc.unison_voices * reduction_factor))
          osc.sample_count = math.max(1, math.ceil(new_total / osc.unison_voices))
        else
          osc.sample_count = math.max(1, new_total)
        end
      end
    end
    -- Verify the adjustment worked
    total_samples = PakettiMetaSynthCalculateTotalSamples(architecture)
    if total_samples > 12 then
      -- If still over limit, more aggressive reduction
      for gi, group in ipairs(architecture.oscillator_groups) do
        for oi, osc in ipairs(group.oscillators) do
          if total_samples > 12 then
            if osc.unison_voices > 1 then
              osc.unison_voices = osc.unison_voices - 1
              total_samples = total_samples - osc.sample_count
            elseif osc.sample_count > 1 then
              osc.sample_count = osc.sample_count - 1
              total_samples = total_samples - 1
            end
          end
        end
      end
    end
  end
  
  -- Random crossfade settings - guided by frame rules from global profile
  local frame_rules = PakettiMetaSynthResolveProfile("frame", nil, nil, architecture)
  
  architecture.crossfade.curve_type = PakettiMetaSynthGetRandomCrossfadeCurve()
  -- Always use LFO for now - macro mode routing is not fully implemented
  architecture.crossfade.control_source = "lfo"
  architecture.crossfade.macro_index = math.random(1, 4)
  
  -- Randomize Frame LFO rate settings - guided by frame morph_speed from profile
  local morph_speed = frame_rules.morph_speed or "medium"
  local frame_rate_mode = rate_modes[math.random(1, #rate_modes)]
  architecture.crossfade.lfo_rate_mode = frame_rate_mode
  architecture.crossfade.lfo_rate_free = 0.1 + math.random() * 1.9  -- 0.1-2.0 Hz
  architecture.crossfade.lfo_rate_sync = rate_syncs[math.random(1, #rate_syncs)]
  -- Map morph_speed to rate preset
  if morph_speed == "slow" then
    architecture.crossfade.lfo_rate_preset = "slow"
  elseif morph_speed == "fast" then
    architecture.crossfade.lfo_rate_preset = "fast"
  else
    architecture.crossfade.lfo_rate_preset = "medium"
  end
  
  -- Random FX settings
  architecture.fx_randomization.enabled = math.random() > 0.3
  architecture.fx_randomization.param_randomization = 0.2 + math.random() * 0.4
  
  -- Randomly select 2-4 devices from the pool
  local pool = {}
  local shuffled = {}
  for _, d in ipairs(PakettiMetaSynthSafeFXDevices) do table.insert(shuffled, d) end
  for i = #shuffled, 2, -1 do
    local j = math.random(1, i)
    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
  end
  for i = 1, math.random(2, 4) do
    table.insert(pool, shuffled[i])
  end
  architecture.fx_randomization.device_pool = pool
  
  -- Stack Master FX settings - always enabled for full architecture
  architecture.stack_master_fx_enabled = true
  architecture.stack_master_fx_mode = math.random() > 0.5 and "random" or "selective"
  architecture.stack_master_fx_count = math.random(1, 4)
  architecture.stack_master_fx_types = {}
  
  -- Ensure stack master FX count is valid when enabled (must be 1-5)
  if architecture.stack_master_fx_enabled and architecture.stack_master_fx_count < 1 then
    architecture.stack_master_fx_count = 1
  elseif architecture.stack_master_fx_enabled and architecture.stack_master_fx_count > 5 then
    architecture.stack_master_fx_count = 5
  end
  
  -- If selective mode, randomly pick some FX types for stacked master
  if architecture.stack_master_fx_mode == "selective" then
    local fx_names = PakettiMetaSynthGetSelectableFXTypeNames()
    local num_types = math.random(1, math.min(3, #fx_names))
    local shuffled_types = {}
    for _, name in ipairs(fx_names) do table.insert(shuffled_types, name) end
    for i = #shuffled_types, 2, -1 do
      local j = math.random(1, i)
      shuffled_types[i], shuffled_types[j] = shuffled_types[j], shuffled_types[i]
    end
    for i = 1, num_types do
      table.insert(architecture.stack_master_fx_types, shuffled_types[i])
    end
  end
  
  -- Default to output_routing (safer, no sends) - can be overridden by caller
  architecture.master_routing_mode = "output_routing"
  
  return architecture
end

-- Quick random instrument generation with specified routing mode
-- routing_mode: "output_routing" (chain routing, no sends) or "send_device" (#Send devices)
function PakettiMetaSynthGenerateRandomInstrumentWithRouting(routing_mode)
  -- Safety check: ensure song is loaded
  local song = renoise.song()
  if not song then
    print("[PakettiMetaSynth Generate] ERROR: No song loaded in GenerateRandomInstrumentWithRouting")
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return nil
  end
  
  local selected_index = song.selected_instrument_index
  print(string.format("[PakettiMetaSynth Generate] Starting random generation: routing_mode=%s, instrument_index=%d", 
    routing_mode or "output_routing", selected_index))
  
  local architecture = PakettiMetaSynthCreateDefaultArchitecture()
  if not architecture then
    print("[PakettiMetaSynth Generate] ERROR: Failed to create default architecture")
    return nil
  end
  
  print("[PakettiMetaSynth Generate] Architecture created, randomizing...")
  PakettiMetaSynthRandomizeArchitecture(architecture)
  
  -- Override the routing mode with specified value
  architecture.master_routing_mode = routing_mode or "output_routing"
  architecture.name = "MetaSynth Random " .. os.date("%H%M%S")
  
  print(string.format("[PakettiMetaSynth Generate] Architecture ready: name='%s', routing_mode=%s", 
    architecture.name, architecture.master_routing_mode))
  
  local result = PakettiMetaSynthGenerateInstrument(architecture)
  
  if result then
    print(string.format("[PakettiMetaSynth Generate] Random generation completed successfully for instrument %d", selected_index))
  else
    print(string.format("[PakettiMetaSynth Generate] WARNING: Random generation returned nil for instrument %d", selected_index))
  end
  
  return result
end

-- Quick random instrument generation (uses output_routing - no sends, more reliable)
function PakettiMetaSynthGenerateRandomInstrument()
  return PakettiMetaSynthGenerateRandomInstrumentWithRouting("output_routing")
end

-- Quick random instrument generation with #Send devices
function PakettiMetaSynthGenerateRandomInstrumentWithSends()
  return PakettiMetaSynthGenerateRandomInstrumentWithRouting("send_device")
end

-- Global counter for ensuring unique random seeds in batch generation
PakettiMetaSynthBatchSeedCounter = 0

-- Generate a unique random seed for batch generation
-- Combines time, counter, and clock to ensure uniqueness even when called multiple times per second
function PakettiMetaSynthGetUniqueSeed()
  PakettiMetaSynthBatchSeedCounter = PakettiMetaSynthBatchSeedCounter + 1
  local time_seed = os.time()
  local counter_seed = PakettiMetaSynthBatchSeedCounter
  local clock_seed = math.floor(os.clock() * 1000) % 1000  -- milliseconds component
  local combined_seed = time_seed * 10000 + counter_seed * 1000 + clock_seed
  math.randomseed(combined_seed)
  -- Warm up the generator
  math.random(); math.random(); math.random()
end

-- Batch generate multiple randomized instruments for quick auditioning
function PakettiMetaSynthGenerateBatchInstruments(generation_type, count)
  -- generation_type: "standard", "sends", or "wavetable"
  generation_type = generation_type or "standard"
  count = count or 1
  local song = renoise.song()
  
  print(string.format("[PakettiMetaSynth Batch] Starting batch generation: type=%s, requested_count=%d", generation_type, count))
  
  if not song then
    print("[PakettiMetaSynth Batch] ERROR: No song loaded")
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return
  end
  
  -- Renoise has a maximum of 255 instruments per song
  local current_count = #song.instruments
  local available_slots = 255 - current_count
  
  print(string.format("[PakettiMetaSynth Batch] Initial state: current_instruments=%d, available_slots=%d", current_count, available_slots))
  
  if available_slots <= 0 then
    print("[PakettiMetaSynth Batch] ERROR: No available slots (song has 255 instruments)")
    renoise.app():show_warning("Cannot add more instruments - song already has 255 instruments (maximum)")
    return
  end
  
  -- Cap the requested count to available slots
  if count > available_slots then
    print(string.format("[PakettiMetaSynth Batch] Limiting count from %d to %d (max available)", count, available_slots))
    renoise.app():show_status(string.format("PakettiMetaSynth: Limiting batch to %d instruments (max 255 per song)", available_slots))
    count = available_slots
  end
  
  local success_count = 0
  local failed_count = 0
  local empty_slots_count = 0
  
  for i = 1, count do
    print(string.format("[PakettiMetaSynth Batch] === Iteration %d of %d ===", i, count))
    
    -- Retry logic: try up to 3 times to generate a valid instrument
    local max_retries = 3
    local retry_count = 0
    local generation_success = false
    local generation_result = nil
    local generation_error = nil
    local insert_index = song.selected_instrument_index + 1
    
    while not generation_success and retry_count < max_retries do
      retry_count = retry_count + 1
      
      if retry_count > 1 then
        print(string.format("[PakettiMetaSynth Batch] Retry attempt %d of %d", retry_count, max_retries))
      end
      
      -- Fresh unique random seed for each attempt to ensure uniqueness
      PakettiMetaSynthGetUniqueSeed()
      
      -- Generate and validate architecture BEFORE creating instrument slot
      print(string.format("[PakettiMetaSynth Batch] Creating and validating architecture (type=%s, attempt=%d)...", generation_type, retry_count))
      
      local architecture = nil
      local validation = nil
      
      local success, result = pcall(function()
        -- Create architecture based on type
        local arch = nil
        if generation_type == "wavetable" then
          -- For wavetable, we need to check if there's a separate randomization function
          -- For now, use standard randomization
          arch = PakettiMetaSynthCreateDefaultArchitecture()
          PakettiMetaSynthRandomizeArchitecture(arch, true)  -- skip_seed=true: seed already set uniquely
          arch.master_routing_mode = "output_routing"
        else
          arch = PakettiMetaSynthCreateDefaultArchitecture()
          PakettiMetaSynthRandomizeArchitecture(arch, true)  -- skip_seed=true: seed already set uniquely
          if generation_type == "sends" then
            arch.master_routing_mode = "send_device"
          else
            arch.master_routing_mode = "output_routing"
          end
        end
        arch.name = "MetaSynth Random " .. os.date("%H%M%S")
        
        -- Validate architecture before creating instrument slot
        local valid = PakettiMetaSynthValidateArchitecture(arch)
        return {architecture = arch, validation = valid}
      end)
      
      if not success then
        generation_error = result
        print(string.format("[PakettiMetaSynth Batch] ERROR: Architecture creation failed with Lua error: %s", tostring(result)))
        print(string.format("[PakettiMetaSynth Batch] Stack trace: %s", debug.traceback()))
      else
        architecture = result.architecture
        validation = result.validation
        if not validation.valid then
          print(string.format("[PakettiMetaSynth Batch] Architecture validation FAILED with %d errors (attempt %d)", #validation.errors, retry_count))
          for _, err in ipairs(validation.errors) do
            print(string.format("[PakettiMetaSynth Batch] Validation error: %s", err))
          end
          -- Will retry with new random architecture
          coroutine.yield()
        else
          -- Validation passed! Now create instrument slot and generate
        print(string.format("[PakettiMetaSynth Batch] Architecture validation PASSED (attempt %d)", retry_count))
        
        -- Insert new instrument after current
        print(string.format("[PakettiMetaSynth Batch] Creating instrument slot at index %d", insert_index))
        song:insert_instrument_at(insert_index)
        song.selected_instrument_index = insert_index
        
        -- Verify instrument was created
        local instrument = song.selected_instrument
        if not instrument then
          print(string.format("[PakettiMetaSynth Batch] ERROR: Failed to create instrument at index %d", insert_index))
          generation_error = "Failed to create instrument slot"
        else
          print(string.format("[PakettiMetaSynth Batch] Instrument slot created: index=%d, name='%s', samples=%d, chains=%d", 
            insert_index, instrument.name, #instrument.samples, #instrument.sample_device_chains))
          
          -- Generate instrument with the validated architecture
          print(string.format("[PakettiMetaSynth Batch] Generating instrument with validated architecture..."))
          
          local gen_success, gen_result = pcall(function()
            return PakettiMetaSynthGenerateInstrument(architecture)
          end)
          
          if not gen_success then
            generation_error = gen_result
            print(string.format("[PakettiMetaSynth Batch] ERROR: Generation failed with Lua error: %s", tostring(gen_result)))
            print(string.format("[PakettiMetaSynth Batch] Stack trace: %s", debug.traceback()))
          else
            generation_result = gen_result
            if generation_result == nil then
              print(string.format("[PakettiMetaSynth Batch] WARNING: Generation returned nil"))
              generation_error = "Generation returned nil"
            else
              generation_success = true
              print(string.format("[PakettiMetaSynth Batch] Generation returned instrument object"))
            end
          end
        end
        end
      end
    end
    
    -- Handle result after retries
    if not generation_success then
      print(string.format("[PakettiMetaSynth Batch] ERROR: Failed to generate valid instrument after %d attempts", max_retries))
      failed_count = failed_count + 1
      
      -- Check if instrument slot was created (it would be if validation passed but generation failed)
      local instrument_check = song.selected_instrument
      if instrument_check and song.selected_instrument_index == insert_index then
        local sample_count = #instrument_check.samples
        local chain_count = #instrument_check.sample_device_chains
        if sample_count == 0 and chain_count == 0 then
          empty_slots_count = empty_slots_count + 1
          print(string.format("[PakettiMetaSynth Batch] Empty slot left at index %d", insert_index))
        end
      end
      coroutine.yield()  -- Yield after error handling
    else
      -- Verify instrument content after generation
      local instrument_after = song.selected_instrument
      if instrument_after then
        local sample_count = #instrument_after.samples
        local chain_count = #instrument_after.sample_device_chains
        local has_name = instrument_after.name ~= "" and instrument_after.name ~= nil
        
        print(string.format("[PakettiMetaSynth Batch] Instrument after generation: index=%d, name='%s', samples=%d, chains=%d, has_name=%s", 
          insert_index, instrument_after.name, sample_count, chain_count, tostring(has_name)))
        
        if sample_count == 0 and chain_count == 0 then
          print(string.format("[PakettiMetaSynth Batch] WARNING: Instrument at index %d is EMPTY (no samples, no chains)", insert_index))
          empty_slots_count = empty_slots_count + 1
          failed_count = failed_count + 1
          success_count = success_count - 1
        elseif sample_count == 0 then
          print(string.format("[PakettiMetaSynth Batch] WARNING: Instrument at index %d has no samples (but has %d chains)", insert_index, chain_count))
        elseif chain_count == 0 then
          print(string.format("[PakettiMetaSynth Batch] WARNING: Instrument at index %d has no chains (but has %d samples)", insert_index, sample_count))
        else
          success_count = success_count + 1
          print(string.format("[PakettiMetaSynth Batch] SUCCESS: Instrument at index %d generated successfully", insert_index))
        end
      else
        print(string.format("[PakettiMetaSynth Batch] ERROR: Instrument at index %d no longer exists after generation!", insert_index))
        failed_count = failed_count + 1
        empty_slots_count = empty_slots_count + 1
      end
    end
    
    renoise.app():show_status(string.format("PakettiMetaSynth: Generated instrument %d of %d", i, count))
    coroutine.yield()  -- Yield after each instrument to maintain UI responsiveness
  end
  
  print(string.format("[PakettiMetaSynth Batch] === BATCH COMPLETE ==="))
  print(string.format("[PakettiMetaSynth Batch] Summary: requested=%d, successful=%d, failed=%d, empty_slots=%d", 
    count, success_count, failed_count, empty_slots_count))
  
  renoise.app():show_status(string.format("PakettiMetaSynth: Batch complete - %d %s instruments created (%d successful, %d failed)", 
    count, generation_type, success_count, failed_count))
end

-- Launcher function that wraps batch generation in ProcessSlicer
-- All menu entries, keybindings, and MIDI mappings should call this
function PakettiMetaSynthLaunchBatchGeneration(generation_type, count)
  local function batch_generation_wrapper()
    PakettiMetaSynthGenerateBatchInstruments(generation_type, count)
  end
  local slicer = ProcessSlicer(batch_generation_wrapper)
  slicer:start()
end

-- Dialog for batch generation with user-specified count
PakettiMetaSynthBatchDialogVb = nil
PakettiMetaSynthBatchDialogHandle = nil
PakettiMetaSynthBatchExportDialogHandle = nil

-- Batch export instruments to XRNI files
-- start_idx: first instrument index to export (1-based)
-- count: number of instruments to export
-- folder_path: destination folder path
function PakettiMetaSynthBatchExportXRNI(start_idx, count, folder_path)
  local song = renoise.song()
  local exported = 0
  local failed = 0
  
  for i = 0, count - 1 do
    local inst_idx = start_idx + i
    if inst_idx <= #song.instruments then
      -- Select the instrument
      song.selected_instrument_index = inst_idx
      local instrument = song.instruments[inst_idx]
      
      -- Generate filename from instrument name or index
      local inst_name = instrument.name
      if inst_name == "" then
        inst_name = string.format("MetaSynth_%03d", inst_idx)
      else
        -- Sanitize filename
        inst_name = inst_name:gsub("[/\\:*?\"<>|]", "_")
      end
      
      local filepath = folder_path .. "/" .. inst_name .. ".xrni"
      
      -- Export
      local success = renoise.app():save_instrument(filepath)
      if success then
        exported = exported + 1
        print(string.format("PakettiMetaSynth: Exported %s", filepath))
      else
        failed = failed + 1
        print(string.format("PakettiMetaSynth: Failed to export %s", filepath))
      end
    end
  end
  
  renoise.app():show_status(string.format("PakettiMetaSynth: Exported %d instruments (%d failed)", exported, failed))
  return exported, failed
end

-- Show batch XRNI export dialog
function PakettiMetaSynthShowBatchExportDialog()
  -- Close existing dialog if open
  if PakettiMetaSynthBatchExportDialogHandle and PakettiMetaSynthBatchExportDialogHandle.visible then
    PakettiMetaSynthBatchExportDialogHandle:close()
    PakettiMetaSynthBatchExportDialogHandle = nil
  end
  
  local vb = renoise.ViewBuilder()
  local song = renoise.song()
  
  local dialog_content = vb:column {
    vb:row {
      vb:text { text = "Start instrument", width = 140 },
      vb:valuebox {
        id = "start_idx",
        min = 1,
        max = #song.instruments,
        value = song.selected_instrument_index,
        width = 80
      }
    },
    vb:row {
      vb:text { text = "Number to export", width = 140 },
      vb:valuebox {
        id = "export_count",
        min = 1,
        max = #song.instruments,
        value = math.min(10, #song.instruments),
        width = 80
      }
    },
    vb:row {
      vb:button {
        text = "Select Folder & Export",
        width = 110,
        notifier = function()
          -- Close dialog before showing blocking prompt
          if PakettiMetaSynthBatchExportDialogHandle then
            PakettiMetaSynthBatchExportDialogHandle:close()
            PakettiMetaSynthBatchExportDialogHandle = nil
          end
          
          local folder = renoise.app():prompt_for_path("Select export folder")
          if folder and folder ~= "" then
            local start_idx = vb.views.start_idx.value
            local count = vb.views.export_count.value
            PakettiMetaSynthBatchExportXRNI(start_idx, count, folder)
          end
        end
      },
      vb:button {
        text = "Cancel",
        width = 110,
        notifier = function()
          if PakettiMetaSynthBatchExportDialogHandle then
            PakettiMetaSynthBatchExportDialogHandle:close()
            PakettiMetaSynthBatchExportDialogHandle = nil
          end
        end
      }
    }
  }
  
  PakettiMetaSynthBatchExportDialogHandle = renoise.app():show_custom_dialog("MetaSynth Batch XRNI Export", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiMetaSynthShowBatchGenerationDialog()
  -- Close existing dialog if open
  if PakettiMetaSynthBatchDialogHandle and PakettiMetaSynthBatchDialogHandle.visible then
    PakettiMetaSynthBatchDialogHandle:close()
    PakettiMetaSynthBatchDialogHandle = nil
  end
  
  PakettiMetaSynthBatchDialogVb = renoise.ViewBuilder()
  local vb = PakettiMetaSynthBatchDialogVb
  
  -- Function to execute batch generation
  local function execute_batch_generation()
    local count_text = vb.views.instrument_count.text
    local count = tonumber(count_text)
    if not count or count < 1 then
      count = 10
    end
    if count > 1000 then
      count = 1000
    end
    
    local type_idx = vb.views.generation_type.value
    local gen_type = "standard"
    if type_idx == 2 then
      gen_type = "sends"
    elseif type_idx == 3 then
      gen_type = "wavetable"
    end
    
    -- Close dialog before generating
    if PakettiMetaSynthBatchDialogHandle then
      PakettiMetaSynthBatchDialogHandle:close()
      PakettiMetaSynthBatchDialogHandle = nil
    end
    
    PakettiMetaSynthLaunchBatchGeneration(gen_type, count)
  end
  
  -- Key handler for Enter key
  local function batch_key_handler(dialog, key)
    if key.name == "return" or key.name == "numpadenter" then
      execute_batch_generation()
      return nil  -- Consume the key
    elseif key.name == "esc" then
      if PakettiMetaSynthBatchDialogHandle then
        PakettiMetaSynthBatchDialogHandle:close()
        PakettiMetaSynthBatchDialogHandle = nil
      end
      return nil
    end
    return key
  end
  
  local dialog_content = vb:column {
    vb:row {
      vb:text { text = "Number of instruments", width = 140 },
      vb:textfield {
        id = "instrument_count",
        text = "10",
        width = 120,
        edit_mode = true,
        notifier = function(value)
          -- notifier fires when Enter is pressed to confirm textfield
          local num = tonumber(value)
          if num and num >= 1 and num <= 1000 then
            execute_batch_generation()
          end
        end
      }
    },
    
    vb:row {
      vb:text { text = "Generation type", width = 140 },
      vb:popup {
        id = "generation_type",
        items = {"Standard", "With Sends", "Wavetable"},
        value = 1,
        width = 120
      }
    },
    
    vb:row {
      vb:button {
        text = "Generate",
        width = 85,
        notifier = execute_batch_generation
      },
      vb:button {
        text = "Cancel",
        width = 85,
        notifier = function()
          if PakettiMetaSynthBatchDialogHandle then
            PakettiMetaSynthBatchDialogHandle:close()
            PakettiMetaSynthBatchDialogHandle = nil
          end
        end
      },
      vb:button {
        text = "Batch Export",
        width = 85,
        notifier = function()
          if PakettiMetaSynthBatchDialogHandle then
            PakettiMetaSynthBatchDialogHandle:close()
            PakettiMetaSynthBatchDialogHandle = nil
          end
          PakettiMetaSynthShowBatchExportDialog()
        end
      }
    },
    
    vb:text { text = "Press Enter to generate, Esc to cancel", style = "disabled" }
  }
  
  PakettiMetaSynthBatchDialogHandle = renoise.app():show_custom_dialog(
    "MetaSynth Batch Generation",
    dialog_content,
    batch_key_handler
  )
  
  -- Set focus to the textfield and focus Renoise
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Randomize architecture for wavetable mode
-- Key difference: frames are parallel FX paths for the SAME source, not different samples
function PakettiMetaSynthRandomizeWavetableArchitecture(architecture)
  trueRandomSeed()
  
  -- Set GLOBAL PROFILE - wavetable mode favors pad/lead profiles
  -- Use context-aware selection for evolving sounds
  architecture.global_profile = PakettiMetaSynthGetProfileForContext(math.random(2, 4), false, false)
  
  -- Initialize MODULATION LAYER settings
  -- Wavetable mode: modulation usually inherits from global profile
  architecture.modulation_layer = architecture.modulation_layer or {}
  architecture.modulation_layer.profile_override = nil  -- Inherit from global for wavetable
  architecture.modulation_layer.custom_modulation = nil
  
  -- LFO rate mode options
  local rate_modes = {"free", "tempo_sync", "preset"}
  local rate_presets = {"slow", "medium", "fast"}
  local rate_syncs = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"}
  
  -- Wavetable mode: typically 1 group with multiple oscillators for scanning
  local num_groups = 1  -- Keep it simple for wavetable
  architecture.oscillator_groups = {}
  
  local samples_remaining = 12
  
  for gi = 1, num_groups do
    -- Randomize Group LFO rate settings
    local group_rate_mode = rate_modes[math.random(1, #rate_modes)]
    
    -- Get profile rules for group configuration
    local osc_group_rules = PakettiMetaSynthResolveProfile("oscillator_groups", nil, nil, architecture)
    local group_frame_rules = PakettiMetaSynthResolveProfile("group_frame", nil, nil, architecture)
    
    -- Extract oscillator group FX from oscillator_groups layer
    local osc_group_fx_rules = {
      enabled = osc_group_rules.osc_group_fx_enabled,
      count_range = osc_group_rules.osc_group_fx_count_range or {1, 2},
      tendencies = osc_group_rules.osc_group_fx_tendencies or {}
    }
    
    local group = {
      name = "Group " .. string.char(64 + gi),
      crossfade_mode = "linear",
      -- Group crossfade = wavetable scanning between oscillators - always enabled
      group_crossfade_enabled = true,
      group_crossfade_curve = PakettiMetaSynthGetRandomCrossfadeCurve(),
      -- Group LFO rate settings (wavetable scanning speed) - guided by profile
      group_lfo_rate_mode = group_rate_mode,
      group_lfo_rate_free = 0.1 + math.random() * 0.9,  -- 0.1-1.0 Hz (slower for wavetable)
      group_lfo_rate_sync = rate_syncs[math.random(4, #rate_syncs)],  -- Prefer slower syncs (1/2 to 4 bars)
      group_lfo_rate_preset = osc_group_rules.lfo_rate_preset or rate_presets[math.random(1, 2)],
      -- Group Master FX - guided by profile oscillator_groups.osc_group_fx rules
      group_master_fx_enabled = osc_group_fx_rules.enabled ~= false,
      group_master_fx_mode = "selective",
      group_master_fx_count = PakettiMetaSynthGetIntInRange(osc_group_fx_rules.count_range or {1, 3}),
      group_master_fx_types = {},
      
      -- GROUP FRAMES (meta-wavetable at group level) - guided by profile
      -- Wavetable mode: group frames can add extra morphing layer
      group_frames_enabled = group_frame_rules.enabled == true,
      group_frame_count = PakettiMetaSynthGetIntInRange(group_frame_rules.frame_count_range or {1, 1}),
      group_frame_morph_enabled = group_frame_rules.morph_enabled == true,
      group_frame_morph_speed = group_frame_rules.morph_speed or "none",
      group_frame_crossfade_curve = PakettiMetaSynthGetRandomCrossfadeCurve(),
      group_frame_control_source = "lfo",
      group_frame_lfo_rate_preset = rate_presets[math.random(1, #rate_presets)],
      group_frame_fx_enabled = group_frame_rules.enabled and #(group_frame_rules.fx_tendencies or {}) > 0,
      group_frame_fx_tendencies = group_frame_rules.fx_tendencies or {},
      group_frame_fx_count = PakettiMetaSynthGetIntInRange(group_frame_rules.fx_count_range or {0, 0}),
      
      -- Profile override at GROUP level (nil = inherit from global_profile)
      profile_override = nil,
      -- DEPRECATED: modulation_profile
      modulation_profile = nil,
      oscillators = {}
    }
    
    -- Set group FX types from FX profile (respects fx_profile_override) or sound profile
    local fx_tendencies = PakettiMetaSynthGetFXTendencies("group", nil, group, architecture)
    if #fx_tendencies > 0 then
      local shuffled = {}
      for _, fx in ipairs(fx_tendencies) do table.insert(shuffled, fx) end
      for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
      end
      local num_fx = math.min(group.group_master_fx_count, #shuffled)
      for i = 1, num_fx do
        table.insert(group.group_master_fx_types, shuffled[i])
      end
    else
      group.group_master_fx_mode = "random"
    end
    
    if samples_remaining <= 0 then break end
    
    -- Get oscillator rules from profile
    local osc_rules = PakettiMetaSynthResolveProfile("oscillator", nil, group, architecture)
    local frame_rules = PakettiMetaSynthResolveProfile("frame", nil, group, architecture)
    
    -- Wavetable mode: 2-4 oscillators for scanning between different waveforms
    local num_oscs = math.random(2, math.min(4, samples_remaining))
    
    for oi = 1, num_oscs do
      if samples_remaining <= 0 then break end
      
      local osc = {
        name = "Osc " .. oi,
        sample_count = 1,  -- Wavetable: 1 sample per oscillator
        unison_voices = PakettiMetaSynthGetIntInRange(osc_rules.unison_range or {1, 3}),
        frame_count = PakettiMetaSynthGetIntInRange(osc_rules.frame_count_range or {2, 4}),
        sample_source = "akwf",
        detune_spread = PakettiMetaSynthGetValueInRange(osc_rules.detune_range or {5, 20}),
        pan_spread = PakettiMetaSynthGetValueInRange(osc_rules.pan_spread_range or {0.3, 0.8}),
        -- Osc FX enabled for summing - guided by frame rules
        osc_fx_enabled = math.random() > 0.3,  -- 70% chance
        osc_fx_mode = "selective",
        osc_fx_count = PakettiMetaSynthGetIntInRange(frame_rules.fx_count_range or {1, 3}),
        osc_fx_types = {},
        -- Profile override: nil = inherit from group/global
        profile_override = nil,
        modulation_profile = nil
      }
      
      -- Clamp osc_fx_count to 1-5 when enabled (validation requires 1-5 when enabled)
      if osc.osc_fx_enabled then
        if osc.osc_fx_count < 1 then
          osc.osc_fx_count = 1
        elseif osc.osc_fx_count > 5 then
          osc.osc_fx_count = 5
        end
      end
      
      -- Set osc FX from FX profile (if set) or frame tendencies
      local osc_fx_tendencies = PakettiMetaSynthGetFXTendencies("frame", nil, group, architecture)
      if #osc_fx_tendencies > 0 then
        local shuffled = {}
        for _, fx in ipairs(osc_fx_tendencies) do table.insert(shuffled, fx) end
        for i = #shuffled, 2, -1 do
          local j = math.random(1, i)
          shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        local num_fx = math.min(osc.osc_fx_count, #shuffled)
        for i = 1, num_fx do
          table.insert(osc.osc_fx_types, shuffled[i])
        end
      else
        osc.osc_fx_mode = "random"
      end
      
      -- Check if custom folder is configured
      if PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
        if math.random() > 0.75 then
          osc.sample_source = "folder"
          osc.sample_folder = PakettiMetaSynthLastFolderPath
        end
      end
      
      samples_remaining = samples_remaining - (osc.sample_count * osc.unison_voices)
      table.insert(group.oscillators, osc)
    end
    
    if #group.oscillators > 0 then
      table.insert(architecture.oscillator_groups, group)
    end
  end
  
  -- Crossfade settings for frame morphing - guided by frame rules
  local frame_rules = PakettiMetaSynthResolveProfile("frame", nil, nil, architecture)
  
  architecture.crossfade.curve_type = PakettiMetaSynthGetRandomCrossfadeCurve()
  architecture.crossfade.control_source = "lfo"  -- LFO for frame morphing
  architecture.crossfade.macro_index = 1
  
  -- Randomize Frame LFO rate settings - guided by morph_speed from profile
  local morph_speed = frame_rules.morph_speed or "slow"
  local frame_rate_mode = rate_modes[math.random(1, #rate_modes)]
  architecture.crossfade.lfo_rate_mode = frame_rate_mode
  architecture.crossfade.lfo_rate_free = 0.2 + math.random() * 1.3  -- 0.2-1.5 Hz
  architecture.crossfade.lfo_rate_sync = rate_syncs[math.random(3, #rate_syncs)]  -- 1/4 to 4 bars
  -- Map morph_speed to rate preset
  if morph_speed == "slow" then
    architecture.crossfade.lfo_rate_preset = "slow"
  elseif morph_speed == "fast" then
    architecture.crossfade.lfo_rate_preset = "fast"
  else
    architecture.crossfade.lfo_rate_preset = "medium"
  end
  
  -- FX randomization enabled for frame variation
  architecture.fx_randomization.enabled = true
  architecture.fx_randomization.param_randomization = 0.2 + math.random() * 0.3  -- 0.2-0.5
  
  -- Total Group FX (Stack Master FX) - guided by total_group_fx rules (Layer 6)
  local total_group_fx_rules = PakettiMetaSynthResolveProfile("total_group_fx", nil, nil, architecture)
  architecture.stack_master_fx_enabled = total_group_fx_rules.enabled ~= false
  local fx_count_range = total_group_fx_rules.count_range or {2, 4}
  architecture.stack_master_fx_count = math.random(fx_count_range[1], fx_count_range[2])
  architecture.stack_master_fx_types = {}
  
  -- Set stacked FX from total_group_fx tendencies
  local total_group_tendencies = total_group_fx_rules.tendencies or {}
  if #total_group_tendencies > 0 then
    architecture.stack_master_fx_mode = "selective"
    local shuffled = {}
    for _, fx in ipairs(total_group_tendencies) do table.insert(shuffled, fx) end
    for i = #shuffled, 2, -1 do
      local j = math.random(1, i)
      shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local num_fx = math.min(architecture.stack_master_fx_count, #shuffled)
    for i = 1, num_fx do
      table.insert(architecture.stack_master_fx_types, shuffled[i])
    end
  else
    architecture.stack_master_fx_mode = "random"
  end
  
  -- Modulation
  architecture.modulation.random_phase_offsets = math.random() > 0.5
  
  return architecture
end

-- Quick wavetable instrument generation
function PakettiMetaSynthGenerateRandomWavetableInstrument()
  local architecture = PakettiMetaSynthCreateDefaultArchitecture()
  PakettiMetaSynthRandomizeWavetableArchitecture(architecture)
  architecture.name = "MetaSynth Wavetable " .. os.date("%H%M%S")
  return PakettiMetaSynthGenerateWavetableInstrument(architecture)
end

-- ============================================================================
-- SECTION 9: ARCHITECTURE PRESET SAVE/LOAD
-- ============================================================================

-- Serialize architecture to string
function PakettiMetaSynthSerializeArchitecture(architecture)
  local function serialize_value(val, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    if type(val) == "string" then
      return '"' .. val:gsub('"', '\\"') .. '"'
    elseif type(val) == "number" then
      return tostring(val)
    elseif type(val) == "boolean" then
      return tostring(val)
    elseif type(val) == "nil" then
      return "nil"
    elseif type(val) == "table" then
      local result = "{\n"
      local is_array = #val > 0
      
      if is_array then
        for i, v in ipairs(val) do
          result = result .. spaces .. "  " .. serialize_value(v, indent + 1) .. ",\n"
        end
      else
        for k, v in pairs(val) do
          local key_str
          if type(k) == "string" then
            key_str = k
          else
            key_str = "[" .. tostring(k) .. "]"
          end
          result = result .. spaces .. "  " .. key_str .. " = " .. serialize_value(v, indent + 1) .. ",\n"
        end
      end
      
      result = result .. spaces .. "}"
      return result
    else
      return '"<unsupported type>"'
    end
  end
  
  return "return " .. serialize_value(architecture)
end

-- Save architecture to file
function PakettiMetaSynthSaveArchitecture(architecture, filepath)
  local content = PakettiMetaSynthSerializeArchitecture(architecture)
  local file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
    renoise.app():show_status("PakettiMetaSynth: Architecture saved to " .. filepath)
    return true
  else
    renoise.app():show_status("PakettiMetaSynth: Failed to save architecture")
    return false
  end
end

-- Load architecture from file
function PakettiMetaSynthLoadArchitecture(filepath)
  local file = io.open(filepath, "r")
  if not file then
    renoise.app():show_status("PakettiMetaSynth: Could not open file " .. filepath)
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  local loader, err = loadstring(content)
  if not loader then
    renoise.app():show_status("PakettiMetaSynth: Failed to parse architecture file")
    print("PakettiMetaSynth parse error: " .. tostring(err))
    return nil
  end
  
  local success, result = pcall(loader)
  if success and type(result) == "table" then
    renoise.app():show_status("PakettiMetaSynth: Architecture loaded from " .. filepath)
    return result
  else
    renoise.app():show_status("PakettiMetaSynth: Invalid architecture file")
    return nil
  end
end

-- ============================================================================
-- SECTION 9.5: USER PROFILE SAVE/LOAD SYSTEM
-- ============================================================================

-- User profiles folder path
PakettiMetaSynthUserProfilesPath = nil

function PakettiMetaSynthGetUserProfilesPath()
  if not PakettiMetaSynthUserProfilesPath then
    local separator = package.config:sub(1,1)
    PakettiMetaSynthUserProfilesPath = renoise.tool().bundle_path .. "MetaSynthUserProfiles" .. separator
  end
  return PakettiMetaSynthUserProfilesPath
end

-- Ensure user profiles folder exists
function PakettiMetaSynthEnsureUserProfilesFolder()
  local path = PakettiMetaSynthGetUserProfilesPath()
  -- Try to create directory (will fail silently if exists)
  os.execute('mkdir -p "' .. path .. '"')
  return path
end

-- Convert current architecture to profile format
function PakettiMetaSynthArchitectureToProfile(architecture, profile_name)
  local profile = {
    name = profile_name,
    description = "User-created profile from architecture",
    family = "user",
    
    -- LAYER 1: Oscillator rules (extract from first group/oscillator)
    oscillator = {
      unison_range = {1, 4},
      frame_count_range = {1, 4},
      detune_range = {5, 25},
      pan_spread_range = {0.0, 1.0},
      sample_count_range = {1, 4},
    },
    
    -- LAYER 2: Frame rules
    frame = {
      morph_enabled = architecture.crossfade and architecture.crossfade.control_source == "lfo",
      morph_speed = "medium",
      fx_tendencies = {},
      fx_count_range = {0, 3},
    },
    
    -- LAYER 3: Oscillator Modulation rules (SEPARATE layer)
    modulation = {},
    
    -- LAYER 4: Oscillator Groups (summing, organization, oscillator group FX, wavetable/vector control)
    oscillator_groups = {
      crossfade_enabled = false,
      scan_speed = nil,
      lfo_rate_preset = "medium",
      osc_group_fx_enabled = false,
      osc_group_fx_tendencies = {},
      osc_group_fx_count_range = {0, 3},
      wavetable_scan_enabled = false,
      vector_enabled = false,
    },
    
    -- LAYER 5: Group Frames
    group_frame = {
      enabled = false,
      frame_count_range = {1, 2},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 2},
    },
    
    -- LAYER 6: Total Group FX (FX after all groups summed - Stack Master FX)
    total_group_fx = {
      enabled = false,
      tendencies = {},
      count_range = {0, 3},
    },
    
    -- LAYER 7: Total Group Frames / Vector Layer (frame morphing at total summed groups level)
    total_group_frames = {
      enabled = false,
      frame_count_range = {1, 1},
      morph_enabled = false,
      morph_speed = "none",
      fx_tendencies = {},
      fx_count_range = {0, 0},
    },
    
    -- LAYER 8: Global FX rules
    global_fx = {
      enabled = true,
      tendencies = {},
      reverb_size = nil,
    },
    
    -- LAYER 9: Sample Selection rules
    sample_selection = {
      source_preference = "akwf",
      waveform_families = {"basic", "saw", "square"},
      avoid_families = {},
    },
  }
  
  -- Extract modulation from architecture if available
  if architecture.modulation_layer and architecture.modulation_layer.custom_modulation then
    local mod = architecture.modulation_layer.custom_modulation
    if mod.volume_ahdsr then
      profile.modulation.volume_ahdsr = mod.volume_ahdsr
    end
    if mod.filter_ahdsr then
      profile.modulation.filter_ahdsr = mod.filter_ahdsr
    end
    if mod.volume_lfo then
      profile.modulation.volume_lfo = mod.volume_lfo
    end
    if mod.filter_lfo then
      profile.modulation.filter_lfo = mod.filter_lfo
    end
    if mod.pitch_lfo then
      profile.modulation.pitch_lfo = mod.pitch_lfo
    end
    if mod.velocity_volume then
      profile.modulation.velocity_volume = mod.velocity_volume
    end
  end
  
  -- Extract from first group if available
  if architecture.oscillator_groups and #architecture.oscillator_groups > 0 then
    local group = architecture.oscillator_groups[1]
    
    -- Oscillator Groups crossfade settings
    if group.group_crossfade_enabled then
      profile.oscillator_groups.crossfade_enabled = true
      profile.oscillator_groups.lfo_rate_preset = group.group_crossfade_lfo_rate_preset or "medium"
    end
    
    -- Oscillator Groups FX (per-group FX)
    if group.group_master_fx_enabled then
      profile.oscillator_groups.osc_group_fx_enabled = true
      profile.oscillator_groups.osc_group_fx_count_range = {group.group_master_fx_count or 2, group.group_master_fx_count or 2}
    end
    
    -- Group frames
    if group.group_frames_enabled then
      profile.group_frame.enabled = true
      profile.group_frame.frame_count_range = {group.group_frame_count or 2, group.group_frame_count or 2}
    end
    
    -- Total Group FX (Stack Master FX)
    if architecture.stack_master_fx_enabled then
      profile.total_group_fx.enabled = true
      profile.total_group_fx.count_range = {architecture.stack_master_fx_count or 2, architecture.stack_master_fx_count or 2}
    end
    
    -- Total Group Frames
    if architecture.global_fx_frames_enabled then
      profile.total_group_frames.enabled = true
      profile.total_group_frames.frame_count_range = {architecture.global_fx_frame_count or 2, architecture.global_fx_frame_count or 2}
    end
    
    -- Extract from first oscillator
    if group.oscillators and #group.oscillators > 0 then
      local osc = group.oscillators[1]
      profile.oscillator.frame_count_range = {osc.frame_count or 1, osc.frame_count or 4}
      profile.oscillator.unison_range = {osc.unison_voices or 1, osc.unison_voices or 4}
      profile.oscillator.sample_count_range = {osc.sample_count or 1, osc.sample_count or 4}
    end
  end
  
  -- Stack master FX
  if architecture.stack_master_fx_enabled then
    profile.global_fx.tendencies = {}
  end
  
  return profile
end

-- Serialize profile to string
function PakettiMetaSynthSerializeProfile(profile)
  local function serialize_value(val, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    if type(val) == "string" then
      return '"' .. val:gsub('"', '\\"') .. '"'
    elseif type(val) == "number" then
      return tostring(val)
    elseif type(val) == "boolean" then
      return tostring(val)
    elseif type(val) == "nil" then
      return "nil"
    elseif type(val) == "table" then
      local result = "{\n"
      local is_array = #val > 0
      
      if is_array then
        for i, v in ipairs(val) do
          result = result .. spaces .. "  " .. serialize_value(v, indent + 1) .. ",\n"
        end
      else
        for k, v in pairs(val) do
          local key_str
          if type(k) == "string" then
            key_str = k
          else
            key_str = "[" .. tostring(k) .. "]"
          end
          result = result .. spaces .. "  " .. key_str .. " = " .. serialize_value(v, indent + 1) .. ",\n"
        end
      end
      
      result = result .. spaces .. "}"
      return result
    else
      return '"<unsupported type>"'
    end
  end
  
  return "return " .. serialize_value(profile)
end

-- Save user profile to file
function PakettiMetaSynthSaveUserProfile(profile, profile_key)
  local folder = PakettiMetaSynthEnsureUserProfilesFolder()
  local separator = package.config:sub(1,1)
  local filepath = folder .. profile_key .. ".lua"
  
  local content = PakettiMetaSynthSerializeProfile(profile)
  local file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
    print("PakettiMetaSynth: User profile saved to " .. filepath)
    return true
  else
    print("PakettiMetaSynth: Failed to save user profile to " .. filepath)
    return false
  end
end

-- Load a single user profile from file
function PakettiMetaSynthLoadUserProfile(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  local loader, err = loadstring(content)
  if not loader then
    print("PakettiMetaSynth: Failed to parse profile file: " .. tostring(err))
    return nil
  end
  
  local success, result = pcall(loader)
  if success and type(result) == "table" then
    return result
  end
  return nil
end

-- Storage for user profiles
PakettiMetaSynthUserProfiles = {}

-- Load all user profiles from folder
function PakettiMetaSynthLoadAllUserProfiles()
  local folder = PakettiMetaSynthGetUserProfilesPath()
  PakettiMetaSynthUserProfiles = {}
  
  -- Try to list .lua files in the folder
  local success, files = pcall(os.filenames, folder, "*.lua")
  if not success or not files then
    print("PakettiMetaSynth: No user profiles folder or no profiles found")
    return
  end
  
  local loaded_count = 0
  for _, filename in ipairs(files) do
    local separator = package.config:sub(1,1)
    local filepath = folder .. filename
    local profile = PakettiMetaSynthLoadUserProfile(filepath)
    if profile then
      -- Extract profile key from filename (remove .lua extension)
      local profile_key = "user_" .. filename:gsub("%.lua$", "")
      
      -- Add to user profiles storage
      PakettiMetaSynthUserProfiles[profile_key] = profile
      
      -- Also add to main profiles table
      PakettiMetaSynthProfiles[profile_key] = profile
      
      -- Add to profile lists
      table.insert(PakettiMetaSynthProfileNamesList, profile_key)
      table.insert(PakettiMetaSynthProfileDisplayList, profile.name or profile_key)
      
      loaded_count = loaded_count + 1
      print("PakettiMetaSynth: Loaded user profile: " .. profile_key)
    end
  end
  
  if loaded_count > 0 then
    print(string.format("PakettiMetaSynth: Loaded %d user profiles", loaded_count))
  end
end

-- Quick-save current architecture as a new profile
function PakettiMetaSynthQuickSaveAsProfile(architecture)
  local vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column {
    vb:row {
      vb:text { text = "Profile Name:", width = 100 },
      vb:textfield {
        id = "profile_name",
        text = architecture.name or "My Profile",
        width = 200
      }
    },
    vb:row {
      vb:text { text = "Profile Key:", width = 100 },
      vb:textfield {
        id = "profile_key",
        text = "my_profile",
        width = 200
      }
    },
    vb:row {
      vb:button {
        text = "Save Profile",
        width = 150,
        notifier = function()
          local profile_name = vb.views.profile_name.text
          local profile_key = vb.views.profile_key.text
          
          -- Sanitize key
          profile_key = profile_key:gsub("[^%w_]", "_"):lower()
          if profile_key == "" then
            profile_key = "user_profile_" .. os.time()
          end
          
          -- Convert architecture to profile
          local profile = PakettiMetaSynthArchitectureToProfile(architecture, profile_name)
          
          -- Save to file
          if PakettiMetaSynthSaveUserProfile(profile, profile_key) then
            -- Add to runtime profiles
            local full_key = "user_" .. profile_key
            PakettiMetaSynthUserProfiles[full_key] = profile
            PakettiMetaSynthProfiles[full_key] = profile
            table.insert(PakettiMetaSynthProfileNamesList, full_key)
            table.insert(PakettiMetaSynthProfileDisplayList, profile_name)
            
            renoise.app():show_status("PakettiMetaSynth: Profile saved as " .. profile_name)
          else
            renoise.app():show_status("PakettiMetaSynth: Failed to save profile")
          end
        end
      },
      vb:button {
        text = "Cancel",
        width = 150,
        notifier = function()
          -- Dialog will close automatically
        end
      }
    }
  }
  
  renoise.app():show_custom_dialog("Save as Profile", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Full Profile Editor Dialog
PakettiMetaSynthProfileEditorVb = nil
PakettiMetaSynthProfileEditorDialog = nil
PakettiMetaSynthEditingProfile = nil

function PakettiMetaSynthShowProfileEditorDialog(profile_key)
  -- Close existing dialog
  if PakettiMetaSynthProfileEditorDialog and PakettiMetaSynthProfileEditorDialog.visible then
    PakettiMetaSynthProfileEditorDialog:close()
  end
  
  PakettiMetaSynthProfileEditorVb = renoise.ViewBuilder()
  local vb = PakettiMetaSynthProfileEditorVb
  
  -- Load existing profile or create new one
  local profile
  local is_new = false
  if profile_key and PakettiMetaSynthProfiles[profile_key] then
    -- Deep copy the profile for editing
    profile = {}
    for k, v in pairs(PakettiMetaSynthProfiles[profile_key]) do
      if type(v) == "table" then
        profile[k] = {}
        for k2, v2 in pairs(v) do
          if type(v2) == "table" then
            profile[k][k2] = {}
            for k3, v3 in pairs(v2) do
              profile[k][k2][k3] = v3
            end
          else
            profile[k][k2] = v2
          end
        end
      else
        profile[k] = v
      end
    end
  else
    -- New profile template
    is_new = true
    profile = {
      name = "New Profile",
      description = "User-created profile",
      family = "user",
      oscillator = {
        unison_range = {1, 4},
        frame_count_range = {1, 4},
        detune_range = {5, 25},
        pan_spread_range = {0.0, 1.0},
        sample_count_range = {1, 4},
      },
      frame = {
        morph_enabled = true,
        morph_speed = "medium",
        fx_tendencies = {},
        fx_count_range = {0, 3},
      },
      oscillator_groups = {
        crossfade_enabled = false,
        scan_speed = nil,
        lfo_rate_preset = "medium",
        osc_group_fx_enabled = false,
        osc_group_fx_tendencies = {},
        osc_group_fx_count_range = {0, 3},
        wavetable_scan_enabled = false,
        vector_enabled = false,
      },
      modulation = {
        volume_ahdsr = { attack = 0.01, hold = 0.0, decay = 0.2, sustain = 0.7, release = 0.3 },
        velocity_volume = 0.5,
      },
      group_frame = {
        enabled = false,
        frame_count_range = {1, 2},
        morph_enabled = false,
        morph_speed = "none",
        fx_tendencies = {},
        fx_count_range = {0, 2},
      },
      total_group_fx = {
        enabled = false,
        tendencies = {},
        count_range = {0, 3},
      },
      global_fx = {
        tendencies = {},
        reverb_size = nil,
      },
      sample_selection = {
        source_preference = "akwf",
        waveform_families = {"basic", "saw", "square"},
        avoid_families = {},
      },
    }
    profile_key = "user_new_" .. os.time()
  end
  
  PakettiMetaSynthEditingProfile = profile
  
  -- Build the dialog UI
  local dialog_content = vb:column {
    vb:row {
      vb:text { text = "Profile Name:", width = 100 },
      vb:textfield {
        id = "profile_name",
        text = profile.name or "New Profile",
        width = 200,
        notifier = function(value)
          profile.name = value
        end
      }
    },
    vb:row {
      vb:text { text = "Description:", width = 100 },
      vb:textfield {
        id = "profile_desc",
        text = profile.description or "",
        width = 200,
        notifier = function(value)
          profile.description = value
        end
      }
    },
    
    -- Oscillator Layer
    vb:column {
      style = "group",
      vb:text { text = "Oscillator Layer", font = "bold" },
      vb:row {
        vb:text { text = "Unison:", width = 80 },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.oscillator.unison_range[1],
          width = 50,
          notifier = function(v) profile.oscillator.unison_range[1] = v end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.oscillator.unison_range[2],
          width = 50,
          notifier = function(v) profile.oscillator.unison_range[2] = v end
        }
      },
      vb:row {
        vb:text { text = "Frames:", width = 80 },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.oscillator.frame_count_range[1],
          width = 50,
          notifier = function(v) profile.oscillator.frame_count_range[1] = v end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.oscillator.frame_count_range[2],
          width = 50,
          notifier = function(v) profile.oscillator.frame_count_range[2] = v end
        }
      },
      vb:row {
        vb:text { text = "Detune:", width = 80 },
        vb:valuebox {
          min = 0, max = 100,
          value = profile.oscillator.detune_range[1],
          width = 50,
          notifier = function(v) profile.oscillator.detune_range[1] = v end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 0, max = 100,
          value = profile.oscillator.detune_range[2],
          width = 50,
          notifier = function(v) profile.oscillator.detune_range[2] = v end
        }
      }
    },
    
    -- Modulation Layer
    vb:column {
      style = "group",
      vb:text { text = "Modulation Layer", font = "bold" },
      vb:row {
        vb:text { text = "Attack:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.volume_ahdsr and profile.modulation.volume_ahdsr.attack or 0.01,
          width = 100,
          notifier = function(v)
            profile.modulation.volume_ahdsr = profile.modulation.volume_ahdsr or {}
            profile.modulation.volume_ahdsr.attack = v
          end
        }
      },
      vb:row {
        vb:text { text = "Hold:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.volume_ahdsr and profile.modulation.volume_ahdsr.hold or 0.0,
          width = 100,
          notifier = function(v)
            profile.modulation.volume_ahdsr = profile.modulation.volume_ahdsr or {}
            profile.modulation.volume_ahdsr.hold = v
          end
        }
      },
      vb:row {
        vb:text { text = "Decay:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.volume_ahdsr and profile.modulation.volume_ahdsr.decay or 0.2,
          width = 100,
          notifier = function(v)
            profile.modulation.volume_ahdsr = profile.modulation.volume_ahdsr or {}
            profile.modulation.volume_ahdsr.decay = v
          end
        }
      },
      vb:row {
        vb:text { text = "Sustain:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.volume_ahdsr and profile.modulation.volume_ahdsr.sustain or 0.7,
          width = 100,
          notifier = function(v)
            profile.modulation.volume_ahdsr = profile.modulation.volume_ahdsr or {}
            profile.modulation.volume_ahdsr.sustain = v
          end
        }
      },
      vb:row {
        vb:text { text = "Release:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.volume_ahdsr and profile.modulation.volume_ahdsr.release or 0.3,
          width = 100,
          notifier = function(v)
            profile.modulation.volume_ahdsr = profile.modulation.volume_ahdsr or {}
            profile.modulation.volume_ahdsr.release = v
          end
        }
      },
      vb:row {
        vb:text { text = "Velocity:", width = 60 },
        vb:slider {
          min = 0, max = 1,
          value = profile.modulation.velocity_volume or 0.5,
          width = 100,
          notifier = function(v)
            profile.modulation.velocity_volume = v
          end
        }
      }
    },
    
    -- Oscillator Groups Layer (Layer 4) - Summing and FX
    vb:column {
      style = "group",
      vb:text { text = "Oscillator Groups Layer (Level 4)", font = "bold" },
      vb:row {
        vb:checkbox {
          value = profile.oscillator_groups.osc_group_fx_enabled or false,
          notifier = function(v) profile.oscillator_groups.osc_group_fx_enabled = v end
        },
        vb:text { text = "Enable Oscillator Group FX (FX on summed oscillators per group)" }
      },
      vb:row {
        vb:text { text = "FX Count:", width = 80 },
        vb:valuebox {
          min = 0, max = 8,
          value = profile.oscillator_groups.osc_group_fx_count_range[1] or 0,
          width = 50,
          notifier = function(v) 
            profile.oscillator_groups.osc_group_fx_count_range = profile.oscillator_groups.osc_group_fx_count_range or {0, 2}
            profile.oscillator_groups.osc_group_fx_count_range[1] = v 
          end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 0, max = 8,
          value = profile.oscillator_groups.osc_group_fx_count_range[2] or 2,
          width = 50,
          notifier = function(v) 
            profile.oscillator_groups.osc_group_fx_count_range = profile.oscillator_groups.osc_group_fx_count_range or {0, 2}
            profile.oscillator_groups.osc_group_fx_count_range[2] = v 
          end
        }
      }
    },
    
    -- Group Frame Layer
    vb:column {
      style = "group",
      vb:text { text = "Group Frame Layer", font = "bold" },
      vb:row {
        vb:checkbox {
          value = profile.group_frame.enabled or false,
          notifier = function(v) profile.group_frame.enabled = v end
        },
        vb:text { text = "Enable Group Frames" }
      },
      vb:row {
        vb:text { text = "Frame Count:", width = 80 },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.group_frame.frame_count_range[1],
          width = 50,
          notifier = function(v) profile.group_frame.frame_count_range[1] = v end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 1, max = 8,
          value = profile.group_frame.frame_count_range[2],
          width = 50,
          notifier = function(v) profile.group_frame.frame_count_range[2] = v end
        }
      }
    },
    
    -- Total Group FX Layer (Layer 6) - FX on all summed groups
    vb:column {
      style = "group",
      vb:text { text = "Total Group FX Layer (Level 6)", font = "bold" },
      vb:row {
        vb:checkbox {
          value = profile.total_group_fx.enabled or false,
          notifier = function(v) profile.total_group_fx.enabled = v end
        },
        vb:text { text = "Enable Total Group FX (FX on all summed groups)" }
      },
      vb:row {
        vb:text { text = "FX Count:", width = 80 },
        vb:valuebox {
          min = 0, max = 8,
          value = profile.total_group_fx.count_range[1],
          width = 50,
          notifier = function(v) profile.total_group_fx.count_range[1] = v end
        },
        vb:text { text = "to" },
        vb:valuebox {
          min = 0, max = 8,
          value = profile.total_group_fx.count_range[2],
          width = 50,
          notifier = function(v) profile.total_group_fx.count_range[2] = v end
        }
      }
    },
    
    -- Sample Selection
    vb:column {
      style = "group",
      vb:text { text = "Sample Selection", font = "bold" },
      vb:row {
        vb:text { text = "Source:", width = 80 },
        vb:popup {
          items = {"AKWF", "Folder", "Both", "AKWF First", "Folder First"},
          value = (function()
            local src = profile.sample_selection.source_preference or "akwf"
            if src == "akwf" then return 1
            elseif src == "folder" then return 2
            elseif src == "both" then return 3
            elseif src == "akwf_first" then return 4
            else return 5 end
          end)(),
          width = 100,
          notifier = function(idx)
            local sources = {"akwf", "folder", "both", "akwf_first", "folder_first"}
            profile.sample_selection.source_preference = sources[idx]
          end
        }
      }
    },
    
    -- Buttons
    vb:row {
      vb:button {
        text = "Save Profile",
        width = 100,
        notifier = function()
          -- Generate a safe key
          local safe_key = profile.name:gsub("[^%w_]", "_"):lower()
          if safe_key == "" then
            safe_key = "user_profile_" .. os.time()
          else
            safe_key = "user_" .. safe_key
          end
          
          -- Save to file
          if PakettiMetaSynthSaveUserProfile(profile, safe_key:gsub("^user_", "")) then
            -- Add to runtime profiles
            PakettiMetaSynthUserProfiles[safe_key] = profile
            PakettiMetaSynthProfiles[safe_key] = profile
            
            -- Check if already in list, if not add it
            local found = false
            for i, key in ipairs(PakettiMetaSynthProfileNamesList) do
              if key == safe_key then
                found = true
                PakettiMetaSynthProfileDisplayList[i + 1] = profile.name
                break
              end
            end
            if not found then
              table.insert(PakettiMetaSynthProfileNamesList, safe_key)
              table.insert(PakettiMetaSynthProfileDisplayList, profile.name)
            end
            
            renoise.app():show_status("PakettiMetaSynth: Profile saved as " .. profile.name)
            
            if PakettiMetaSynthProfileEditorDialog then
              PakettiMetaSynthProfileEditorDialog:close()
            end
          end
        end
      },
      vb:button {
        text = "Cancel",
        width = 100,
        notifier = function()
          if PakettiMetaSynthProfileEditorDialog then
            PakettiMetaSynthProfileEditorDialog:close()
          end
        end
      }
    }
  }
  
  PakettiMetaSynthProfileEditorDialog = renoise.app():show_custom_dialog(
    "MetaSynth Profile Editor",
    dialog_content,
    my_keyhandler_func
  )
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ============================================================================
-- SECTION 10: GUI - VISUAL ARCHITECTURE DESIGNER
-- ============================================================================

-- GUI state
PakettiMetaSynthDialog = nil
PakettiMetaSynthDialogContent = nil
PakettiMetaSynthVB = nil

-- Initialize ViewBuilder
function PakettiMetaSynthInitVB()
  if not PakettiMetaSynthVB then
    PakettiMetaSynthVB = renoise.ViewBuilder()
  end
  return PakettiMetaSynthVB
end

-- Custom key handler for dialog
function PakettiMetaSynthKeyHandler(dialog, key)
  -- Handle our shortcuts
  if key.modifiers == "" then
    if key.name == "return" or key.name == "numpadenter" then
      -- Enter = Generate
      PakettiMetaSynthGenerateInstrument(PakettiMetaSynthCurrentArchitecture)
      return nil  -- Consume the key
    elseif key.name == "r" then
      -- R = Randomize
      PakettiMetaSynthRandomizeArchitecture(PakettiMetaSynthCurrentArchitecture)
      PakettiMetaSynthRebuildDialog()
      return nil  -- Consume the key
    elseif key.name == "esc" then
      -- Escape = Close
      if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
        PakettiMetaSynthDialog:close()
        PakettiMetaSynthDialog = nil
      end
      return nil  -- Consume the key
    end
  end
  -- Pass unhandled keys to dialog
  return key
end

-- Build oscillator row for GUI (with folder browse button, Oscillator FX controls, and modulation routing)
function PakettiMetaSynthBuildOscillatorRow(vb, group_index, osc_index, osc)
  local row_id = string.format("osc_%d_%d", group_index, osc_index)
  
  -- Get oscillator FX values with defaults
  local osc_fx_enabled = osc.osc_fx_enabled or false
  local osc_fx_mode = osc.osc_fx_mode or "random"
  local osc_fx_count = osc.osc_fx_count or 2
  local osc_fx_mode_index = osc_fx_mode == "selective" and 2 or 1
  
  -- Get FX category index (1 = Inherit Profile)
  local osc_fx_category = osc.osc_fx_category or nil
  local fx_category_index = 1  -- Default: Inherit Profile
  if osc_fx_category then
    for i, cat in ipairs(PakettiMetaSynthFXCategoryList) do
      if cat == osc_fx_category then
        fx_category_index = i
        break
      end
    end
  end
  
  -- Initialize modulation_routing if not present
  if not osc.modulation_routing then
    osc.modulation_routing = {
      velocity_to_volume = 0.5,
      velocity_to_filter = 0.0,
      velocity_to_pitch = 0.0,
      keytrack_to_filter = 0.0,
      modwheel_to_filter = 0.0,
      modwheel_to_volume = 0.0,
      aftertouch_to_filter = 0.0,
      aftertouch_to_pitch = 0.0,
      pitchbend_range = 2,
      random_to_pitch = 0.0,
      random_to_pan = 0.0
    }
  end
  local mod = osc.modulation_routing
  
  return vb:column {
    id = row_id,
    style = "plain",
    
    -- Row 1: Main oscillator controls
    vb:row {
      vb:text {
        text = osc.name,
        width = 50,
        font = "bold"
      },
      
      vb:text { text = "S:" },
      vb:valuebox {
        id = row_id .. "_samples",
        min = 1,
        max = 12,
        value = osc.sample_count,
        width = 50,
        tooltip = "Sample count per frame",
        notifier = function(value)
          osc.sample_count = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:text { text = "U:" },
      vb:valuebox {
        id = row_id .. "_unison",
        min = 1,
        max = 8,
        value = osc.unison_voices,
        width = 50,
        tooltip = "Unison voices",
        notifier = function(value)
          osc.unison_voices = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:text { text = "F:" },
      vb:valuebox {
        id = row_id .. "_frames",
        min = 1,
        max = 16,
        value = osc.frame_count,
        width = 50,
        tooltip = "Frame count (wavetable positions)",
        notifier = function(value)
          osc.frame_count = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:popup {
        id = row_id .. "_source",
        items = {"AKWF", "Folder"},
        value = osc.sample_source == "akwf" and 1 or 2,
        width = 60,
        notifier = function(value)
          osc.sample_source = value == 1 and "akwf" or "folder"
        end
      },
      
      vb:button {
        id = row_id .. "_browse",
        text = "...",
        width = 24,
        notifier = function()
          local folder = renoise.app():prompt_for_path("Select Sample Folder")
          if folder then
            osc.sample_folder = folder
            osc.sample_source = "folder"
            PakettiMetaSynthLastFolderPath = folder
            local source_popup = vb.views[row_id .. "_source"]
            if source_popup then
              source_popup.value = 2
            end
            renoise.app():show_status("PakettiMetaSynth: Folder set to " .. folder)
          end
        end
      },
      
      vb:button {
        text = "X",
        width = 20,
        notifier = function()
          PakettiMetaSynthRemoveOscillator(group_index, osc_index)
        end
      }
    },
    
    -- Row 2: Frame FX controls with Category dropdown
    vb:row {
      vb:text { text = "", width = 50 },
      
      vb:checkbox {
        id = row_id .. "_fx_enabled",
        value = osc_fx_enabled,
        notifier = function(value)
          osc.osc_fx_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Frame FX", width = 48 },
      vb:popup {
        id = row_id .. "_fx_category",
        items = PakettiMetaSynthFXCategoryList,
        value = fx_category_index,
        width = 90,
        tooltip = "FX Category for this oscillator's frames",
        notifier = function(value)
          if value == 1 then
            osc.osc_fx_category = nil
          else
            osc.osc_fx_category = PakettiMetaSynthFXCategoryList[value]
          end
        end
      },
      vb:popup {
        id = row_id .. "_fx_mode",
        items = {"Random", "Selective"},
        value = osc_fx_mode_index,
        width = 70,
        notifier = function(value)
          osc.osc_fx_mode = value == 1 and "random" or "selective"
        end
      },
      vb:text { text = "N:" },
      vb:valuebox {
        id = row_id .. "_fx_count",
        min = 1,
        max = 5,
        value = osc_fx_count,
        width = 50,
        tooltip = "Number of FX devices",
        notifier = function(value)
          osc.osc_fx_count = value
          PakettiMetaSynthUpdatePreview()
        end
      }
    },
    
    -- Row 3: Velocity modulation routing
    vb:row {
      vb:text { text = "", width = 50 },
      vb:text { text = "Vel:", width = 25, font = "italic" },
      vb:text { text = "Vol" },
      vb:minislider {
        id = row_id .. "_vel_vol",
        min = 0,
        max = 1,
        value = mod.velocity_to_volume,
        width = 50,
        tooltip = "Velocity to Volume amount",
        notifier = function(value)
          mod.velocity_to_volume = value
        end
      },
      vb:text { text = "Flt" },
      vb:minislider {
        id = row_id .. "_vel_flt",
        min = 0,
        max = 1,
        value = mod.velocity_to_filter,
        width = 50,
        tooltip = "Velocity to Filter Cutoff amount",
        notifier = function(value)
          mod.velocity_to_filter = value
        end
      },
      vb:text { text = "Pch" },
      vb:minislider {
        id = row_id .. "_vel_pch",
        min = 0,
        max = 1,
        value = mod.velocity_to_pitch,
        width = 50,
        tooltip = "Velocity to Pitch amount",
        notifier = function(value)
          mod.velocity_to_pitch = value
        end
      }
    },
    
    -- Row 4: Keytrack, Modwheel, Aftertouch
    vb:row {
      vb:text { text = "", width = 50 },
      vb:text { text = "Key:", width = 25, font = "italic" },
      vb:text { text = "Flt" },
      vb:minislider {
        id = row_id .. "_key_flt",
        min = 0,
        max = 1,
        value = mod.keytrack_to_filter,
        width = 50,
        tooltip = "Key Tracking to Filter Cutoff",
        notifier = function(value)
          mod.keytrack_to_filter = value
        end
      },
      vb:text { text = "MW:", font = "italic" },
      vb:text { text = "Flt" },
      vb:minislider {
        id = row_id .. "_mw_flt",
        min = 0,
        max = 1,
        value = mod.modwheel_to_filter,
        width = 40,
        tooltip = "Mod Wheel to Filter Cutoff",
        notifier = function(value)
          mod.modwheel_to_filter = value
        end
      },
      vb:text { text = "Vol" },
      vb:minislider {
        id = row_id .. "_mw_vol",
        min = 0,
        max = 1,
        value = mod.modwheel_to_volume,
        width = 40,
        tooltip = "Mod Wheel to Volume",
        notifier = function(value)
          mod.modwheel_to_volume = value
        end
      }
    },
    
    -- Row 5: Aftertouch, Pitch Bend, Random
    vb:row {
      vb:text { text = "", width = 50 },
      vb:text { text = "AT:", width = 25, font = "italic" },
      vb:text { text = "Flt" },
      vb:minislider {
        id = row_id .. "_at_flt",
        min = 0,
        max = 1,
        value = mod.aftertouch_to_filter,
        width = 40,
        tooltip = "Aftertouch to Filter Cutoff",
        notifier = function(value)
          mod.aftertouch_to_filter = value
        end
      },
      vb:text { text = "Pch" },
      vb:minislider {
        id = row_id .. "_at_pch",
        min = 0,
        max = 1,
        value = mod.aftertouch_to_pitch,
        width = 40,
        tooltip = "Aftertouch to Pitch",
        notifier = function(value)
          mod.aftertouch_to_pitch = value
        end
      },
      vb:text { text = "PB:", font = "italic" },
      vb:valuebox {
        id = row_id .. "_pb_range",
        min = 0,
        max = 24,
        value = mod.pitchbend_range,
        width = 50,
        tooltip = "Pitch Bend range (semitones)",
        notifier = function(value)
          mod.pitchbend_range = value
        end
      },
      vb:text { text = "st" }
    },
    
    -- Row 6: Random modulation
    vb:row {
      vb:text { text = "", width = 50 },
      vb:text { text = "Rnd:", width = 25, font = "italic" },
      vb:text { text = "Pch" },
      vb:minislider {
        id = row_id .. "_rnd_pch",
        min = 0,
        max = 1,
        value = mod.random_to_pitch,
        width = 50,
        tooltip = "Random to Pitch amount",
        notifier = function(value)
          mod.random_to_pitch = value
        end
      },
      vb:text { text = "Pan" },
      vb:minislider {
        id = row_id .. "_rnd_pan",
        min = 0,
        max = 1,
        value = mod.random_to_pan,
        width = 50,
        tooltip = "Random to Pan amount",
        notifier = function(value)
          mod.random_to_pan = value
        end
      }
    }
  }
end

-- Build group section for GUI
function PakettiMetaSynthBuildGroupSection(vb, group_index, group)
  local group_id = string.format("group_%d", group_index)
  local osc_rows = vb:column {}
  
  for oi, osc in ipairs(group.oscillators) do
    osc_rows:add_child(PakettiMetaSynthBuildOscillatorRow(vb, group_index, oi, osc))
  end
  
  -- Determine initial values for group crossfade controls (with defaults for legacy data)
  local group_xfade_enabled = group.group_crossfade_enabled or false
  local group_xfade_curve = group.group_crossfade_curve or "equal_power"
  local group_xfade_time = group.group_crossfade_time or 4.0
  
  -- Map curve type to popup index
  local curve_index = 2  -- Default to equal_power
  if group_xfade_curve == "linear" then
    curve_index = 1
  elseif group_xfade_curve == "equal_power" then
    curve_index = 2
  elseif group_xfade_curve == "s_curve" then
    curve_index = 3
  elseif group_xfade_curve == "stepped" then
    curve_index = 4
  elseif group_xfade_curve == "spectral" then
    curve_index = 5
  elseif group_xfade_curve == "vector" then
    curve_index = 6
  end
  
  -- Determine initial values for Group Master FX controls (with defaults)
  local group_master_fx_enabled = group.group_master_fx_enabled or false
  local group_master_fx_mode = group.group_master_fx_mode or "random"
  local group_master_fx_count = math.max(1, math.min(5, group.group_master_fx_count or 3))
  local group_master_fx_types = group.group_master_fx_types or {}
  
  -- Map mode to popup index (Random=1, Selective=2)
  local master_fx_mode_index = group_master_fx_mode == "selective" and 2 or 1
  
  return vb:column {
    id = group_id,
    style = "group",
    width = 440,
    
    -- ================================================================
    -- GROUP + MODULATION LAYER (Unified Structural Level)
    -- Oscillator summing + modulation chain + first vector point
    -- ================================================================
    vb:row {
      vb:text {
        text = group.name .. " + Mod",
        font = "bold",
        width = 100,
        tooltip = "Group + Modulation: Oscillator summing and voice articulation"
      },
      vb:popup {
        id = group_id .. "_mode",
        items = {"Linear", "XY", "Stack"},
        value = group.crossfade_mode == "linear" and 1 or (group.crossfade_mode == "xy" and 2 or 3),
        width = 60,
        tooltip = "Crossfade mode for oscillators in this group",
        notifier = function(value)
          group.crossfade_mode = ({"linear", "xy", "stack"})[value]
        end
      },
      vb:button {
        text = "+Osc",
        width = 40,
        notifier = function()
          PakettiMetaSynthAddOscillator(group_index)
        end
      },
      vb:button {
        text = "X",
        width = 20,
        notifier = function()
          PakettiMetaSynthRemoveGroup(group_index)
        end
      }
    },
    
    -- ================================================================
    -- OSCILLATORS SECTION (signal flow: oscillators first)
    -- ================================================================
    osc_rows,
    
    -- Sound Profile & Modulation Selector Row (defines articulation)
    vb:row {
      vb:text { text = "Profile:", width = 45 },
      vb:popup {
        id = group_id .. "_profile",
        items = PakettiMetaSynthProfileDisplayList,
        value = (function()
          if not group.profile_override then return 1 end
          for i, name in ipairs(PakettiMetaSynthProfileNamesList) do
            if name == group.profile_override then return i + 1 end
          end
          return 1
        end)(),
        width = 110,
        notifier = function(value)
          if value == 1 then
            group.profile_override = nil
          else
            group.profile_override = PakettiMetaSynthProfileNamesList[value - 1]
          end
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:button {
        text = "Load",
        width = 35,
        tooltip = "Load profile defaults into this group",
        notifier = function()
          local profile_name = group.profile_override
          if not profile_name then
            profile_name = PakettiMetaSynthCurrentArchitecture.global_profile or "default"
          end
          PakettiMetaSynthApplyProfileDefaultsToGroup(group, profile_name, PakettiMetaSynthCurrentArchitecture)
          PakettiMetaSynthRebuildDialog()
        end
      },
      vb:text { text = "FX:", width = 20 },
      vb:popup {
        id = group_id .. "_fx_profile",
        items = PakettiMetaSynthFXProfileDisplayList,
        value = (function()
          if not group.fx_profile_override then return 1 end
          for i, name in ipairs(PakettiMetaSynthFXProfileNamesList) do
            if name == group.fx_profile_override then return i + 1 end
          end
          return 1
        end)(),
        width = 100,
        notifier = function(value)
          if value == 1 then
            group.fx_profile_override = nil
          else
            group.fx_profile_override = PakettiMetaSynthFXProfileNamesList[value - 1]
          end
          PakettiMetaSynthUpdatePreview()
        end
      }
    },
    
    -- Group Crossfade Controls (Wavetable Scanning)
    vb:row {
      vb:checkbox {
        id = group_id .. "_xfade_enabled",
        value = group_xfade_enabled,
        notifier = function(value)
          group.group_crossfade_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Group Morph", width = 65 },
      vb:popup {
        id = group_id .. "_xfade_curve",
        items = {"Linear", "Equal Power", "S-Curve", "Stepped", "Spectral", "Vector"},
        value = curve_index,
        width = 85,
        notifier = function(value)
          group.group_crossfade_curve = ({"linear", "equal_power", "s_curve", "stepped", "spectral", "vector"})[value]
        end
      },
      vb:text { text = "LFO:" },
      vb:popup {
        id = group_id .. "_lfo_rate_mode",
        items = {"Free", "Sync", "Preset"},
        value = group.group_lfo_rate_mode == "free" and 1 or 
               (group.group_lfo_rate_mode == "tempo_sync" and 2 or 3),
        width = 55,
        notifier = function(value)
          group.group_lfo_rate_mode = ({"free", "tempo_sync", "preset"})[value]
        end
      },
      -- Filtered profile dropdown: only profiles with group.crossfade_enabled = true
      vb:popup {
        id = group_id .. "_xfade_profile",
        items = PakettiMetaSynthGroupCrossfadeProfileDisplay,
        value = PakettiMetaSynthFindProfileIndex(group.group_crossfade_profile_override, PakettiMetaSynthGroupCrossfadeProfileNames),
        width = 80,
        tooltip = "Profile for Group Crossfade (filtered: only shows profiles with crossfade enabled)",
        notifier = function(value)
          group.group_crossfade_profile_override = PakettiMetaSynthGetProfileKey(value, PakettiMetaSynthGroupCrossfadeProfileNames)
          PakettiMetaSynthUpdatePreview()
        end
      }
    },
    
    -- Group LFO Rate Details Row
    vb:row {
      vb:text { text = "Hz:", width = 25 },
      vb:valuefield {
        id = group_id .. "_lfo_rate_free",
        min = 0.01,
        max = 10,
        value = group.group_lfo_rate_free or 0.5,
        width = 45,
        notifier = function(value)
          group.group_lfo_rate_free = value
        end
      },
      vb:text { text = "Sync:" },
      vb:popup {
        id = group_id .. "_lfo_rate_sync",
        items = {"1/16", "1/8", "1/4", "1/2", "1bar", "2bar", "4bar"},
        value = ({["1/16"]=1, ["1/8"]=2, ["1/4"]=3, ["1/2"]=4, ["1 bar"]=5, ["2 bars"]=6, ["4 bars"]=7})[group.group_lfo_rate_sync or "1 bar"] or 5,
        width = 50,
        notifier = function(value)
          group.group_lfo_rate_sync = ({"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"})[value]
        end
      },
      vb:text { text = "Pre:" },
      vb:popup {
        id = group_id .. "_lfo_rate_preset",
        items = {"Slow", "Med", "Fast"},
        value = group.group_lfo_rate_preset == "slow" and 1 or 
               (group.group_lfo_rate_preset == "medium" and 2 or 3),
        width = 50,
        notifier = function(value)
          group.group_lfo_rate_preset = ({"slow", "medium", "fast"})[value]
        end
      }
    },
    
    -- Group Summing FX Controls (FX applied after oscillators are summed in this group)
    vb:row {
      vb:checkbox {
        id = group_id .. "_master_fx_enabled",
        value = group_master_fx_enabled,
        notifier = function(value)
          group.group_master_fx_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Group Sum FX", width = 70, tooltip = "FX applied after oscillators are summed in this group" },
      vb:popup {
        id = group_id .. "_master_fx_category",
        items = PakettiMetaSynthFXCategoryList,
        value = (function()
          local cat = group.group_master_fx_category
          if not cat then return 1 end
          for i, c in ipairs(PakettiMetaSynthFXCategoryList) do
            if c == cat then return i end
          end
          return 1
        end)(),
        width = 90,
        tooltip = "FX Category for Group Summing FX",
        notifier = function(value)
          if value == 1 then
            group.group_master_fx_category = nil
          else
            group.group_master_fx_category = PakettiMetaSynthFXCategoryList[value]
          end
        end
      },
      vb:popup {
        id = group_id .. "_master_fx_mode",
        items = {"Random", "Selective"},
        value = master_fx_mode_index,
        width = 70,
        notifier = function(value)
          group.group_master_fx_mode = value == 1 and "random" or "selective"
        end
      },
      vb:text { text = "N:" },
      vb:valuebox {
        id = group_id .. "_master_fx_count",
        min = 1,
        max = 5,
        value = group_master_fx_count,
        width = 50,
        tooltip = "Number of FX devices",
        notifier = function(value)
          group.group_master_fx_count = value
        end
      }
    },
    
    -- Group FX Archetype Selection
    vb:row {
      vb:text { text = "FX Style:", width = 50 },
      vb:checkbox {
        id = group_id .. "_fx_clean",
        value = (function()
          local archetypes = group.group_fx_archetypes or {}
          for _, a in ipairs(archetypes) do if a == "clean" then return true end end
          return false
        end)(),
        notifier = function(value)
          group.group_fx_archetypes = group.group_fx_archetypes or {}
          if value then
            table.insert(group.group_fx_archetypes, "clean")
          else
            for i, a in ipairs(group.group_fx_archetypes) do
              if a == "clean" then table.remove(group.group_fx_archetypes, i) break end
            end
          end
        end
      },
      vb:text { text = "Cln", width = 25 },
      vb:checkbox {
        id = group_id .. "_fx_character",
        value = (function()
          local archetypes = group.group_fx_archetypes or {}
          for _, a in ipairs(archetypes) do if a == "character" then return true end end
          return false
        end)(),
        notifier = function(value)
          group.group_fx_archetypes = group.group_fx_archetypes or {}
          if value then
            table.insert(group.group_fx_archetypes, "character")
          else
            for i, a in ipairs(group.group_fx_archetypes) do
              if a == "character" then table.remove(group.group_fx_archetypes, i) break end
            end
          end
        end
      },
      vb:text { text = "Chr", width = 25 },
      vb:checkbox {
        id = group_id .. "_fx_movement",
        value = (function()
          local archetypes = group.group_fx_archetypes or {}
          for _, a in ipairs(archetypes) do if a == "movement" then return true end end
          return false
        end)(),
        notifier = function(value)
          group.group_fx_archetypes = group.group_fx_archetypes or {}
          if value then
            table.insert(group.group_fx_archetypes, "movement")
          else
            for i, a in ipairs(group.group_fx_archetypes) do
              if a == "movement" then table.remove(group.group_fx_archetypes, i) break end
            end
          end
        end
      },
      vb:text { text = "Mov", width = 25 }
    },
    vb:row {
      vb:text { text = "", width = 50 },
      vb:checkbox {
        id = group_id .. "_fx_spatial",
        value = (function()
          local archetypes = group.group_fx_archetypes or {}
          for _, a in ipairs(archetypes) do if a == "spatial" then return true end end
          return false
        end)(),
        notifier = function(value)
          group.group_fx_archetypes = group.group_fx_archetypes or {}
          if value then
            table.insert(group.group_fx_archetypes, "spatial")
          else
            for i, a in ipairs(group.group_fx_archetypes) do
              if a == "spatial" then table.remove(group.group_fx_archetypes, i) break end
            end
          end
        end
      },
      vb:text { text = "Spc", width = 25 },
      vb:checkbox {
        id = group_id .. "_fx_aggressive",
        value = (function()
          local archetypes = group.group_fx_archetypes or {}
          for _, a in ipairs(archetypes) do if a == "aggressive" then return true end end
          return false
        end)(),
        notifier = function(value)
          group.group_fx_archetypes = group.group_fx_archetypes or {}
          if value then
            table.insert(group.group_fx_archetypes, "aggressive")
          else
            for i, a in ipairs(group.group_fx_archetypes) do
              if a == "aggressive" then table.remove(group.group_fx_archetypes, i) break end
            end
          end
        end
      },
      vb:text { text = "Agr", width = 25 }
    },
    
    -- Group Frames Controls (Meta-wavetable at group level)
    vb:row {
      vb:checkbox {
        id = group_id .. "_gframes_enabled",
        value = group.group_frames_enabled or false,
        notifier = function(value)
          group.group_frames_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Group Frames", width = 70 },
      vb:text { text = "Count:" },
      vb:valuebox {
        id = group_id .. "_gframe_count",
        min = 1,
        max = 8,
        value = group.group_frame_count or 1,
        width = 50,
        notifier = function(value)
          group.group_frame_count = value
        end
      },
      vb:checkbox {
        id = group_id .. "_gframe_morph",
        value = group.group_frame_morph_enabled or false,
        notifier = function(value)
          group.group_frame_morph_enabled = value
        end
      },
      vb:text { text = "Morph", width = 35 },
      vb:popup {
        id = group_id .. "_gframe_speed",
        items = {"None", "Slow", "Med", "Fast"},
        value = (function()
          local speed = group.group_frame_morph_speed or "none"
          if speed == "none" then return 1
          elseif speed == "slow" then return 2
          elseif speed == "medium" then return 3
          else return 4 end
        end)(),
        width = 50,
        notifier = function(value)
          group.group_frame_morph_speed = ({"none", "slow", "medium", "fast"})[value]
        end
      },
      -- Filtered profile dropdown: only profiles with group_frame.enabled = true
      vb:popup {
        id = group_id .. "_gframe_profile",
        items = PakettiMetaSynthGroupFrameProfileDisplay,
        value = PakettiMetaSynthFindProfileIndex(group.group_frame_profile_override, PakettiMetaSynthGroupFrameProfileNames),
        width = 90,
        tooltip = "Profile for Group Frames (filtered: only shows profiles with Group Frames enabled)",
        notifier = function(value)
          group.group_frame_profile_override = PakettiMetaSynthGetProfileKey(value, PakettiMetaSynthGroupFrameProfileNames)
          PakettiMetaSynthUpdatePreview()
        end
      }
    },
    
    -- Group Frame FX Controls (FX per group frame)
    vb:row {
      vb:text { text = "", width = 20 },
      vb:checkbox {
        id = group_id .. "_gframe_fx_enabled",
        value = group.group_frame_fx_enabled or false,
        notifier = function(value)
          group.group_frame_fx_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Grp Frame FX", width = 72, tooltip = "FX applied per group frame" },
      vb:popup {
        id = group_id .. "_gframe_fx_category",
        items = PakettiMetaSynthFXCategoryList,
        value = (function()
          local cat = group.group_frame_fx_category
          if not cat then return 1 end
          for i, c in ipairs(PakettiMetaSynthFXCategoryList) do
            if c == cat then return i end
          end
          return 1
        end)(),
        width = 90,
        tooltip = "FX Category for Group Frame FX",
        notifier = function(value)
          if value == 1 then
            group.group_frame_fx_category = nil
          else
            group.group_frame_fx_category = PakettiMetaSynthFXCategoryList[value]
          end
        end
      },
      vb:popup {
        id = group_id .. "_gframe_fx_mode",
        items = {"Random", "Selective"},
        value = (group.group_frame_fx_mode == "selective") and 2 or 1,
        width = 70,
        notifier = function(value)
          group.group_frame_fx_mode = value == 1 and "random" or "selective"
        end
      },
      vb:text { text = "N:" },
      vb:valuebox {
        id = group_id .. "_gframe_fx_count",
        min = 0,
        max = 5,
        value = group.group_frame_fx_count or 1,
        width = 50,
        tooltip = "Number of FX devices per group frame",
        notifier = function(value)
          group.group_frame_fx_count = value
        end
      }
    },
    
    -- Per-Group Modulation Controls (Stepper, ARP)
    vb:row {
      vb:text { text = "Modulation:", width = 60, font = "italic" },
      vb:checkbox {
        id = group_id .. "_stepper_enabled",
        value = group.stepper_enabled or false,
        tooltip = "Enable step sequencer modulation for this group",
        notifier = function(value)
          group.stepper_enabled = value
          if value and not group.stepper_config then
            group.stepper_config = { steps = {1.0, 0.8, 0.5, 0.3}, rate = "1/16", target = "volume" }
          end
        end
      },
      vb:text { text = "Stepper", width = 50 },
      vb:popup {
        id = group_id .. "_stepper_target",
        items = {"Volume", "Filter", "Pitch"},
        value = (function()
          local target = group.stepper_config and group.stepper_config.target or "volume"
          if target == "volume" then return 1
          elseif target == "filter" then return 2
          else return 3 end
        end)(),
        width = 70,
        notifier = function(value)
          if not group.stepper_config then
            group.stepper_config = { steps = {1.0, 0.8, 0.5, 0.3}, rate = "1/16" }
          end
          group.stepper_config.target = ({"volume", "filter", "pitch"})[value]
        end
      },
      vb:popup {
        id = group_id .. "_stepper_rate",
        items = {"1/4", "1/8", "1/16", "1/32"},
        value = (function()
          local rate = group.stepper_config and group.stepper_config.rate or "1/16"
          if rate == "1/4" then return 1
          elseif rate == "1/8" then return 2
          elseif rate == "1/16" then return 3
          else return 4 end
        end)(),
        width = 45,
        notifier = function(value)
          if not group.stepper_config then
            group.stepper_config = { steps = {1.0, 0.8, 0.5, 0.3} }
          end
          group.stepper_config.rate = ({"1/4", "1/8", "1/16", "1/32"})[value]
        end
      }
    },
    
    -- ARP Pattern Controls
    vb:row {
      vb:text { text = "", width = 60 },
      vb:checkbox {
        id = group_id .. "_arp_enabled",
        value = group.arp_enabled or false,
        tooltip = "Enable arpeggiator-style pitch modulation for this group",
        notifier = function(value)
          group.arp_enabled = value
          if value and not group.arp_config then
            group.arp_config = { pattern = "up", rate = "1/16", octaves = 1, enabled = true }
          end
        end
      },
      vb:text { text = "ARP", width = 50 },
      vb:popup {
        id = group_id .. "_arp_pattern",
        items = {"Up", "Down", "Up-Down", "Minor Up", "Minor Down", "Octave", "Fifth", "Random"},
        value = (function()
          local pattern = group.arp_config and group.arp_config.pattern or "up"
          local patterns = {up=1, down=2, updown=3, minor_up=4, minor_down=5, octave=6, fifth=7, random=8}
          return patterns[pattern] or 1
        end)(),
        width = 70,
        notifier = function(value)
          if not group.arp_config then
            group.arp_config = { rate = "1/16", octaves = 1, enabled = true }
          end
          local patterns = {"up", "down", "updown", "minor_up", "minor_down", "octave", "fifth", "random"}
          group.arp_config.pattern = patterns[value]
        end
      },
      vb:popup {
        id = group_id .. "_arp_rate",
        items = {"1/4", "1/8", "1/16", "1/32"},
        value = (function()
          local rate = group.arp_config and group.arp_config.rate or "1/16"
          if rate == "1/4" then return 1
          elseif rate == "1/8" then return 2
          elseif rate == "1/16" then return 3
          else return 4 end
        end)(),
        width = 45,
        notifier = function(value)
          if not group.arp_config then
            group.arp_config = { pattern = "up", octaves = 1, enabled = true }
          end
          group.arp_config.rate = ({"1/4", "1/8", "1/16", "1/32"})[value]
        end
      },
      vb:text { text = "Oct:", width = 25 },
      vb:valuebox {
        id = group_id .. "_arp_octaves",
        min = 1,
        max = 4,
        value = group.arp_config and group.arp_config.octaves or 1,
        width = 50,
        notifier = function(value)
          if not group.arp_config then
            group.arp_config = { pattern = "up", rate = "1/16", enabled = true }
          end
          group.arp_config.octaves = value
        end
      }
    }
  }
end

-- Update preview display
function PakettiMetaSynthUpdatePreview()
  if not PakettiMetaSynthCurrentArchitecture or not PakettiMetaSynthVB then return end
  
  local validation = PakettiMetaSynthValidateArchitecture(PakettiMetaSynthCurrentArchitecture)
  
  local vb = PakettiMetaSynthVB
  
  -- Update sample count display
  local sample_text = vb.views["preview_samples"]
  if sample_text then
    sample_text.text = string.format("Samples: %d/12", validation.total_samples)
    sample_text.style = validation.total_samples > 12 and "disabled" or "normal"
  end
  
  -- Update FX chains display
  local fx_text = vb.views["preview_fx_chains"]
  if fx_text then
    fx_text.text = string.format("FX Chains: %d", validation.total_fx_chains)
  end
  
  -- Update group morph display
  local group_morph_text = vb.views["preview_group_morph"]
  if group_morph_text then
    local morph_count = 0
    local morph_info = {}
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      if group.group_crossfade_enabled and #group.oscillators > 1 then
        morph_count = morph_count + 1
        table.insert(morph_info, string.format("%s:%d", group.name, #group.oscillators))
      end
    end
    if morph_count > 0 then
      group_morph_text.text = string.format("Group Morph: %s", table.concat(morph_info, ", "))
    else
      group_morph_text.text = "Group Morph: Off"
    end
  end
  
  -- Update oscillator FX display
  local osc_fx_text = vb.views["preview_osc_fx"]
  if osc_fx_text then
    local osc_fx_count = 0
    local osc_fx_info = {}
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      for oi, osc in ipairs(group.oscillators) do
        if osc.osc_fx_enabled then
          osc_fx_count = osc_fx_count + 1
          table.insert(osc_fx_info, osc.name)
        end
      end
    end
    if osc_fx_count > 0 then
      osc_fx_text.text = string.format("Osc FX: %d (%s)", osc_fx_count, table.concat(osc_fx_info, ", "))
    else
      osc_fx_text.text = "Osc FX: Off"
    end
  end
  
  -- Update master FX display
  local master_fx_text = vb.views["preview_master_fx"]
  if master_fx_text then
    local master_info = {}
    -- Count groups with Group Master FX enabled
    local group_master_count = 0
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      if group.group_master_fx_enabled then
        group_master_count = group_master_count + 1
      end
    end
    if group_master_count > 0 then
      table.insert(master_info, string.format("Grp:%d", group_master_count))
    end
    -- Check Stack Master FX
    if PakettiMetaSynthCurrentArchitecture.stack_master_fx_enabled then
      table.insert(master_info, "Stack")
    end
    
    if #master_info > 0 then
      master_fx_text.text = string.format("Master FX: %s", table.concat(master_info, "+"))
    else
      master_fx_text.text = "Master FX: Off"
    end
  end
  
  -- Update Global FX Frames display
  local global_frames_text = vb.views["preview_global_frames"]
  if global_frames_text then
    if PakettiMetaSynthCurrentArchitecture.global_fx_frames_enabled and 
       PakettiMetaSynthCurrentArchitecture.global_fx_frame_count > 1 then
      local morph_info = PakettiMetaSynthCurrentArchitecture.global_fx_frame_morph_enabled and "M" or ""
      local fx_info = PakettiMetaSynthCurrentArchitecture.global_fx_frame_fx_enabled and 
        string.format("+%dFX", PakettiMetaSynthCurrentArchitecture.global_fx_frame_fx_count) or ""
      global_frames_text.text = string.format("Global Frames: %d%s%s", 
        PakettiMetaSynthCurrentArchitecture.global_fx_frame_count, morph_info, fx_info)
    else
      global_frames_text.text = "Global Frames: Off"
    end
  end
  
  -- Update Group Scan display
  local group_scan_text = vb.views["preview_group_scan"]
  if group_scan_text then
    local num_groups = #PakettiMetaSynthCurrentArchitecture.oscillator_groups
    if PakettiMetaSynthCurrentArchitecture.group_scan_enabled and num_groups > 1 then
      local curve_abbrev = ({linear = "L", equal_power = "EP", s_curve = "S", stepped = "St", spectral = "Sp", vector = "V"})[
        PakettiMetaSynthCurrentArchitecture.group_scan_curve or "equal_power"] or "EP"
      group_scan_text.text = string.format("Group Scan: %dG/%s", num_groups, curve_abbrev)
    else
      group_scan_text.text = "Group Scan: Off"
    end
  end
  
  -- Update Vector display
  local vector_text = vb.views["preview_vector"]
  if vector_text then
    local num_groups = #PakettiMetaSynthCurrentArchitecture.oscillator_groups
    if PakettiMetaSynthCurrentArchitecture.vector_enabled then
      if num_groups == 4 then
        vector_text.text = string.format("Vector: XY M%d/%d", 
          PakettiMetaSynthCurrentArchitecture.vector_x_macro or 7,
          PakettiMetaSynthCurrentArchitecture.vector_y_macro or 8)
      else
        vector_text.text = string.format("Vector: Need 4G (have %d)", num_groups)
      end
    else
      vector_text.text = "Vector: Off"
    end
  end
  
  -- Update warning display
  local warning_text = vb.views["preview_warning"]
  if warning_text then
    if #validation.errors > 0 then
      warning_text.text = validation.errors[1]
      warning_text.style = "disabled"
    elseif #validation.warnings > 0 then
      warning_text.text = validation.warnings[1]
      warning_text.style = "normal"
    else
      warning_text.text = "Ready to generate"
      warning_text.style = "normal"
    end
  end
end

-- Add oscillator to a group
function PakettiMetaSynthAddOscillator(group_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local group = PakettiMetaSynthCurrentArchitecture.oscillator_groups[group_index]
  if not group then return end
  
  local new_osc = {
    name = "Osc " .. (#group.oscillators + 1),
    sample_count = 1,
    unison_voices = 1,
    frame_count = 1,
    sample_source = "akwf",
    sample_folder = PakettiMetaSynthLastFolderPath,
    detune_spread = 10,
    pan_spread = 0.8,
    -- Oscillator FX settings (processing after frame morphing, before group morphing)
    osc_fx_enabled = false,
    osc_fx_mode = "random",
    osc_fx_count = 2,
    osc_fx_types = {}
  }
  
  table.insert(group.oscillators, new_osc)
  PakettiMetaSynthRebuildDialog()
end

-- Remove oscillator from a group
function PakettiMetaSynthRemoveOscillator(group_index, osc_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local group = PakettiMetaSynthCurrentArchitecture.oscillator_groups[group_index]
  if not group or #group.oscillators <= 1 then return end
  
  table.remove(group.oscillators, osc_index)
  PakettiMetaSynthRebuildDialog()
end

-- Add a new group
function PakettiMetaSynthAddGroup()
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local new_group = {
    name = "Group " .. string.char(64 + #PakettiMetaSynthCurrentArchitecture.oscillator_groups + 1),
    crossfade_mode = "linear",
    -- Group-level crossfade settings (wavetable scanning between oscillators)
    group_crossfade_enabled = false,
    group_crossfade_curve = "equal_power",
    group_crossfade_time = 4.0,
    -- Group Master FX settings (glue FX per wavetable group)
    group_master_fx_enabled = false,
    group_master_fx_mode = "random",
    group_master_fx_count = 3,
    group_master_fx_types = {},
    oscillators = {
      {
        name = "Osc 1",
        sample_count = 1,
        unison_voices = 1,
        frame_count = 1,
        sample_source = "akwf",
        sample_folder = PakettiMetaSynthLastFolderPath,
        detune_spread = 10,
        pan_spread = 0.8
      }
    }
  }
  
  table.insert(PakettiMetaSynthCurrentArchitecture.oscillator_groups, new_group)
  PakettiMetaSynthRebuildDialog()
end

-- Add a new group from a profile (creates group with profile defaults applied)
function PakettiMetaSynthAddGroupFromProfile(profile_name)
  if not PakettiMetaSynthCurrentArchitecture then return end
  if not profile_name or profile_name == "" or profile_name == "default" then
    -- Fall back to regular add group
    PakettiMetaSynthAddGroup()
    return
  end
  
  local profile = PakettiMetaSynthGetProfile(profile_name)
  if not profile then
    print("PakettiMetaSynth: Profile '" .. tostring(profile_name) .. "' not found, adding blank group")
    PakettiMetaSynthAddGroup()
    return
  end
  
  -- Get profile rules for oscillator creation
  local osc_rules = profile.oscillator or {}
  local frame_rules = profile.frame or {}
  local osc_group_rules = profile.oscillator_groups or {}
  local group_frame_rules = profile.group_frame or {}
  local osc_group_fx_rules = { enabled = osc_group_rules.osc_group_fx_enabled, count_range = osc_group_rules.osc_group_fx_count_range or {0, 2} }
  local sample_rules = profile.sample_selection or {}
  
  -- Determine oscillator count (1-3 based on profile family)
  local osc_count = 1
  if profile.family == "pad" or profile.family == "fx" then
    osc_count = math.random(2, 3)
  elseif profile.family == "lead" then
    osc_count = math.random(1, 2)
  end
  
  -- Create oscillators based on profile rules
  local oscillators = {}
  for oi = 1, osc_count do
    local unison_range = osc_rules.unison_range or {1, 3}
    local frame_range = osc_rules.frame_count_range or {1, 3}
    local detune_range = osc_rules.detune_range or {5, 20}
    local pan_range = osc_rules.pan_spread_range or {0.2, 0.5}
    local sample_range = osc_rules.sample_count_range or {1, 2}
    
    table.insert(oscillators, {
      name = "Osc " .. oi,
      sample_count = math.random(sample_range[1], sample_range[2]),
      unison_voices = math.random(unison_range[1], unison_range[2]),
      frame_count = math.random(frame_range[1], frame_range[2]),
      sample_source = sample_rules.source_preference or "akwf",
      sample_folder = PakettiMetaSynthLastFolderPath,
      detune_spread = math.random(detune_range[1], detune_range[2]),
      pan_spread = detune_range[1] + math.random() * (pan_range[2] - pan_range[1]),
      -- Store waveform preferences from profile
      waveform_families = sample_rules.waveform_families,
      avoid_families = sample_rules.avoid_families,
      -- Frame morph settings from profile
      frame_morph_enabled = frame_rules.morph_enabled or false,
      frame_morph_speed = frame_rules.morph_speed or "medium",
      -- Oscillator FX settings
      osc_fx_enabled = (#(frame_rules.fx_tendencies or {}) > 0),
      osc_fx_mode = "selective",
      osc_fx_count = math.random((frame_rules.fx_count_range or {1, 2})[1], (frame_rules.fx_count_range or {1, 2})[2]),
      osc_fx_types = frame_rules.fx_tendencies or {},
    })
    -- Clamp osc_fx_count to 1-5 when enabled (validation requires 1-5 when enabled)
    if oscillators[#oscillators].osc_fx_enabled then
      if oscillators[#oscillators].osc_fx_count < 1 then
        oscillators[#oscillators].osc_fx_count = 1
      elseif oscillators[#oscillators].osc_fx_count > 5 then
        oscillators[#oscillators].osc_fx_count = 5
      end
    end
  end
  
  -- Create the new group with profile-derived settings
  local new_group = {
    name = "Group " .. string.char(64 + #PakettiMetaSynthCurrentArchitecture.oscillator_groups + 1),
    profile_override = profile_name,  -- Remember which profile this came from
    crossfade_mode = "linear",
    -- Group-level crossfade settings (from profile group rules)
    group_crossfade_enabled = group_rules.crossfade_enabled or false,
    group_crossfade_curve = "equal_power",
    group_crossfade_time = 4.0,
    group_lfo_rate_preset = group_rules.lfo_rate_preset or "medium",
    -- Group Master FX settings (from profile group_fx rules)
    group_master_fx_enabled = fx_rules.enabled ~= false,
    group_master_fx_mode = (#(fx_rules.tendencies or {}) > 0) and "selective" or "random",
    group_master_fx_count = math.max(1, math.min(5, math.random(math.max(1, (fx_rules.count_range or {1, 2})[1]), (fx_rules.count_range or {1, 2})[2]))),
    group_master_fx_types = fx_rules.tendencies or {},
    -- Group Frames settings (from profile group_frame rules)
    group_frames_enabled = group_frame_rules.enabled or false,
    group_frame_count = math.random((group_frame_rules.frame_count_range or {1, 1})[1], (group_frame_rules.frame_count_range or {1, 1})[2]),
    group_frame_morph_enabled = group_frame_rules.morph_enabled or false,
    group_frame_morph_speed = group_frame_rules.morph_speed or "none",
    group_frame_fx_enabled = (#(group_frame_rules.fx_tendencies or {}) > 0),
    group_frame_fx_tendencies = group_frame_rules.fx_tendencies or {},
    group_frame_fx_count = math.random((group_frame_rules.fx_count_range or {0, 0})[1], (group_frame_rules.fx_count_range or {0, 0})[2]),
    -- Oscillators
    oscillators = oscillators
  }
  
  table.insert(PakettiMetaSynthCurrentArchitecture.oscillator_groups, new_group)
  
  print(string.format("PakettiMetaSynth: Added group '%s' from profile '%s' with %d oscillator(s)", 
    new_group.name, profile_name, #oscillators))
  
  PakettiMetaSynthRebuildDialog()
end

-- Remove a group
function PakettiMetaSynthRemoveGroup(group_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  if #PakettiMetaSynthCurrentArchitecture.oscillator_groups <= 1 then return end
  
  table.remove(PakettiMetaSynthCurrentArchitecture.oscillator_groups, group_index)
  PakettiMetaSynthRebuildDialog()
end

-- Build the main dialog content
function PakettiMetaSynthBuildDialogContent()
  local vb = PakettiMetaSynthInitVB()
  local arch = PakettiMetaSynthCurrentArchitecture
  
  -- Build oscillator groups section
  local groups_column = vb:column {
    id = "groups_container",
    width = 445
  }
  
  for gi, group in ipairs(arch.oscillator_groups) do
    groups_column:add_child(PakettiMetaSynthBuildGroupSection(vb, gi, group))
  end
  
  -- Main content
  local content = vb:column {
    
    -- Instrument name
    vb:row {
      vb:text { text = "Instrument Name:", width = 100 },
      vb:textfield {
        id = "inst_name",
        text = arch.name,
        width = 200,
        notifier = function(value)
          arch.name = value
        end
      }
    },
    
    -- Global Profile & FX Profile Selectors
    vb:row {
      vb:text { text = "Global Profile:", width = 100 },
      vb:popup {
        id = "global_profile",
        items = PakettiMetaSynthProfileDisplayList,
        value = (function()
          if not arch.global_profile or arch.global_profile == "default" then return 1 end
          for i, name in ipairs(PakettiMetaSynthProfileNamesList) do
            if name == arch.global_profile then return i + 1 end
          end
          return 1
        end)(),
        width = 120,
        notifier = function(value)
          if value == 1 then
            arch.global_profile = "default"
          else
            arch.global_profile = PakettiMetaSynthProfileNamesList[value - 1]
          end
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "FX Style:", width = 55 },
      vb:popup {
        id = "fx_profile",
        items = PakettiMetaSynthFXProfileDisplayList,
        value = (function()
          if not arch.fx_profile_override then return 1 end
          for i, name in ipairs(PakettiMetaSynthFXProfileNamesList) do
            if name == arch.fx_profile_override then return i + 1 end
          end
          return 1
        end)(),
        width = 110,
        notifier = function(value)
          if value == 1 then
            arch.fx_profile_override = nil
          else
            arch.fx_profile_override = PakettiMetaSynthFXProfileNamesList[value - 1]
          end
          PakettiMetaSynthUpdatePreview()
        end
      }
    },
    
    -- Modulation Character Quick-Select
    vb:row {
      vb:text { text = "Mod Character:", width = 100 },
      vb:popup {
        id = "mod_character",
        items = METASYNTH_MODULATION_CHARACTER_NAMES,
        value = (function()
          -- Check if custom modulation matches a character
          if arch.modulation_layer and arch.modulation_layer.custom_modulation then
            for i, char in ipairs(METASYNTH_MODULATION_CHARACTERS) do
              -- Simple check: compare keys
              if arch.modulation_layer.modulation_character_key == char.key then
                return i + 1  -- +1 because "(Default)" is at index 1
              end
            end
          end
          return 1  -- Default
        end)(),
        width = 120,
        tooltip = "Quick-select modulation envelope character",
        notifier = function(value)
          if value == 1 then
            -- Clear custom modulation, use profile default
            PakettiMetaSynthClearModulationCharacter(arch)
            arch.modulation_layer.modulation_character_key = nil
          else
            local char = METASYNTH_MODULATION_CHARACTERS[value - 1]
            if char then
              PakettiMetaSynthApplyModulationCharacter(arch, char.key)
              arch.modulation_layer.modulation_character_key = char.key
            end
          end
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { 
        id = "mod_character_desc",
        text = "",
        width = 200,
        font = "italic"
      },
      vb:checkbox {
        id = "mod_tempo_sync",
        value = arch.modulation_layer and arch.modulation_layer.tempo_synced or false,
        tooltip = "Enable tempo sync for all modulation devices (AHDSR, LFO)",
        notifier = function(value)
          arch.modulation_layer = arch.modulation_layer or {}
          arch.modulation_layer.tempo_synced = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Tempo Sync", width = 70 }
    },
    
    -- Two-column layout
    vb:row {
      
      -- Left column: Oscillator Groups
      vb:column {
        style = "panel",
        width = 460,
        
        vb:row {
          vb:text { text = "Oscillator Groups", font = "bold" },
          vb:button {
            text = "+ Add",
            width = 45,
            tooltip = "Add blank group",
            notifier = function()
              PakettiMetaSynthAddGroup()
            end
          },
          vb:popup {
            id = "add_from_profile_selector",
            items = PakettiMetaSynthProfileDisplayList,
            value = 1,
            width = 100,
            tooltip = "Select a profile to add as a new group"
          },
          vb:button {
            text = "+ From Profile",
            width = 85,
            tooltip = "Add new group with selected profile's defaults",
            notifier = function()
              local popup = vb.views["add_from_profile_selector"]
              if popup and popup.value > 1 then
                local profile_name = PakettiMetaSynthProfileNamesList[popup.value - 1]
                PakettiMetaSynthAddGroupFromProfile(profile_name)
              else
                PakettiMetaSynthAddGroup()
              end
            end
          }
        },
        
        groups_column
      },
      
      -- Right panel: Preview and Settings (3 columns side by side)
      vb:row {
        
        -- COLUMN 1: Preview, Crossfade, FX Randomization, Total Group FX
        vb:column {
          width = 220,
          
          -- Preview section
          vb:column {
            style = "group",
            width = 205,
            
            vb:text { text = "Preview", style = "strong", font = "bold" },
          vb:text { id = "preview_samples", text = "Samples 0/12" },
          vb:text { id = "preview_fx_chains", text = "FX Chains 0" },
          vb:text { id = "preview_group_morph", text = "Group Morph Off" },
          vb:text { id = "preview_osc_fx", text = "Osc FX Off" },
          vb:text { id = "preview_master_fx", text = "Master FX Off" },
          vb:text { id = "preview_global_frames", text = "Global Frames Off" },
          vb:text { id = "preview_group_scan", text = "Group Scan Off" },
          vb:text { id = "preview_vector", text = "Vector Off" },
          vb:text { id = "preview_warning", text = "" }
        },
        
        -- Crossfade Settings
          vb:column {
            style = "group",
            width = 205,
          
          vb:text { text = "Crossfade", style = "strong", font = "bold" },
          
          vb:row {
            vb:text { text = "Curve", width = 65 },
            vb:popup {
              id = "crossfade_curve",
              items = {"Linear", "Equal Power", "S-Curve", "Stepped", "Spectral", "Vector"},
              value = (function()
                local curve = arch.crossfade.curve_type or "equal_power"
                if curve == "linear" then return 1
                elseif curve == "equal_power" then return 2
                elseif curve == "s_curve" then return 3
                elseif curve == "stepped" then return 4
                elseif curve == "spectral" then return 5
                else return 6 end
              end)(),
              width = 130,
              notifier = function(value)
                arch.crossfade.curve_type = ({"linear", "equal_power", "s_curve", "stepped", "spectral", "vector"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Ctrl", width = 65 },
            vb:popup {
              id = "crossfade_control",
              items = {"Macro", "LFO"},
              value = arch.crossfade.control_source == "macro" and 1 or 2,
              width = 130,
              notifier = function(value)
                arch.crossfade.control_source = value == 1 and "macro" or "lfo"
              end
            }
          },
          
          vb:row {
            vb:text { text = "Macro", width = 65 },
            vb:valuebox {
              id = "crossfade_macro",
              min = 1,
              max = 8,
              value = arch.crossfade.macro_index,
              width = 55,
              notifier = function(value)
                arch.crossfade.macro_index = value
              end
            }
          },
          
          -- Frame LFO Rate Mode
          vb:row {
            vb:text { text = "LFO Mode", width = 65 },
            vb:popup {
              id = "frame_lfo_rate_mode",
              items = {"Free", "Tempo Sync", "Preset"},
              value = arch.crossfade.lfo_rate_mode == "free" and 1 or 
                     (arch.crossfade.lfo_rate_mode == "tempo_sync" and 2 or 3),
              width = 130,
              notifier = function(value)
                arch.crossfade.lfo_rate_mode = ({"free", "tempo_sync", "preset"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Free Hz", width = 65 },
            vb:valuefield {
              id = "frame_lfo_rate_free",
              min = 0.01,
              max = 10,
              value = arch.crossfade.lfo_rate_free or 0.5,
              width = 70,
              notifier = function(value)
                arch.crossfade.lfo_rate_free = value
              end
            }
          },
          
          vb:row {
            vb:text { text = "Sync", width = 65 },
            vb:popup {
              id = "frame_lfo_rate_sync",
              items = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"},
              value = ({["1/16"]=1, ["1/8"]=2, ["1/4"]=3, ["1/2"]=4, ["1 bar"]=5, ["2 bars"]=6, ["4 bars"]=7})[arch.crossfade.lfo_rate_sync or "1 bar"] or 5,
              width = 130,
              notifier = function(value)
                arch.crossfade.lfo_rate_sync = ({"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Preset", width = 65 },
            vb:popup {
              id = "frame_lfo_rate_preset",
              items = {"Slow", "Medium", "Fast"},
              value = arch.crossfade.lfo_rate_preset == "slow" and 1 or 
                     (arch.crossfade.lfo_rate_preset == "medium" and 2 or 3),
              width = 130,
              notifier = function(value)
                arch.crossfade.lfo_rate_preset = ({"slow", "medium", "fast"})[value]
              end
            }
          }
        },
        
        -- FX Randomization
        vb:column {
          style = "group",
          width = 205,
          
          vb:text { text = "FX Randomization", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "fx_enabled",
              value = arch.fx_randomization.enabled,
              notifier = function(value)
                arch.fx_randomization.enabled = value
              end
            },
            vb:text { text = "Enable" }
          },
          
          vb:row {
            vb:text { text = "Amt", width = 65 },
            vb:slider {
              id = "fx_amount",
              min = 0,
              max = 1,
              value = arch.fx_randomization.param_randomization,
              width = 130,
              notifier = function(value)
                arch.fx_randomization.param_randomization = value
              end
            }
          }
        },
        
        -- Total Group FX / Stack Master FX (FX after all groups summed)
        vb:column {
          style = "group",
          width = 205,
          
          vb:text { text = "Total Group FX", style = "strong", font = "bold", tooltip = "FX applied after all groups are summed (Stack Master)" },
          
          vb:row {
            vb:checkbox {
              id = "stack_master_enabled",
              value = arch.stack_master_fx_enabled or false,
              notifier = function(value)
                arch.stack_master_fx_enabled = value
                PakettiMetaSynthUpdatePreview()
              end
            },
            vb:text { text = "Enable", width = 45 },
            vb:popup {
              id = "stack_master_fx_category",
              items = PakettiMetaSynthFXCategoryList,
              value = (function()
                local cat = arch.stack_master_fx_category
                if not cat then return 1 end
                for i, c in ipairs(PakettiMetaSynthFXCategoryList) do
                  if c == cat then return i end
                end
                return 1
              end)(),
              width = 130,
              tooltip = "FX Category for Total Group FX",
              notifier = function(value)
                if value == 1 then
                  arch.stack_master_fx_category = nil
                else
                  arch.stack_master_fx_category = PakettiMetaSynthFXCategoryList[value]
                end
              end
            }
          },
          
          vb:row {
            vb:text { text = "Mode", width = 65 },
            vb:popup {
              id = "stack_master_mode",
              items = {"Random", "Selective"},
              value = (arch.stack_master_fx_mode or "random") == "selective" and 2 or 1,
              width = 80,
              notifier = function(value)
                arch.stack_master_fx_mode = value == 1 and "random" or "selective"
              end
            },
            vb:text { text = "N" },
            vb:valuebox {
              id = "stack_master_count",
              min = 1,
              max = 5,
              value = arch.stack_master_fx_count or 3,
              width = 55,
              tooltip = "Number of FX devices",
              notifier = function(value)
                arch.stack_master_fx_count = value
              end
            }
          },
          
          vb:row {
            vb:text { text = "Route", width = 65 },
            vb:popup {
              id = "master_routing_mode",
              items = {"Chain Output", "#Send Device"},
              value = (arch.master_routing_mode or "output_routing") == "send_device" and 2 or 1,
              width = 130,
              tooltip = "Chain Output: uses output_routing property\n#Send Device: adds #Send device to each chain",
              notifier = function(value)
                arch.master_routing_mode = value == 1 and "output_routing" or "send_device"
              end
            }
          },
          
          -- FX Archetype selection
          vb:text { text = "FX Style", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "stack_fx_clean",
              value = (function()
                local archetypes = arch.stack_master_fx_archetypes or {}
                for _, a in ipairs(archetypes) do if a == "clean" then return true end end
                return false
              end)(),
              notifier = function(value)
                arch.stack_master_fx_archetypes = arch.stack_master_fx_archetypes or {}
                if value then
                  table.insert(arch.stack_master_fx_archetypes, "clean")
                else
                  for i, a in ipairs(arch.stack_master_fx_archetypes) do
                    if a == "clean" then table.remove(arch.stack_master_fx_archetypes, i) break end
                  end
                end
              end
            },
            vb:text { text = "Clean", width = 45 },
            vb:checkbox {
              id = "stack_fx_character",
              value = (function()
                local archetypes = arch.stack_master_fx_archetypes or {}
                for _, a in ipairs(archetypes) do if a == "character" then return true end end
                return false
              end)(),
              notifier = function(value)
                arch.stack_master_fx_archetypes = arch.stack_master_fx_archetypes or {}
                if value then
                  table.insert(arch.stack_master_fx_archetypes, "character")
                else
                  for i, a in ipairs(arch.stack_master_fx_archetypes) do
                    if a == "character" then table.remove(arch.stack_master_fx_archetypes, i) break end
                  end
                end
              end
            },
            vb:text { text = "Char", width = 35 },
            vb:checkbox {
              id = "stack_fx_movement",
              value = (function()
                local archetypes = arch.stack_master_fx_archetypes or {}
                for _, a in ipairs(archetypes) do if a == "movement" then return true end end
                return false
              end)(),
              notifier = function(value)
                arch.stack_master_fx_archetypes = arch.stack_master_fx_archetypes or {}
                if value then
                  table.insert(arch.stack_master_fx_archetypes, "movement")
                else
                  for i, a in ipairs(arch.stack_master_fx_archetypes) do
                    if a == "movement" then table.remove(arch.stack_master_fx_archetypes, i) break end
                  end
                end
              end
            },
            vb:text { text = "Move", width = 35 }
          },
          vb:row {
            vb:checkbox {
              id = "stack_fx_spatial",
              value = (function()
                local archetypes = arch.stack_master_fx_archetypes or {}
                for _, a in ipairs(archetypes) do if a == "spatial" then return true end end
                return false
              end)(),
              notifier = function(value)
                arch.stack_master_fx_archetypes = arch.stack_master_fx_archetypes or {}
                if value then
                  table.insert(arch.stack_master_fx_archetypes, "spatial")
                else
                  for i, a in ipairs(arch.stack_master_fx_archetypes) do
                    if a == "spatial" then table.remove(arch.stack_master_fx_archetypes, i) break end
                  end
                end
              end
            },
            vb:text { text = "Space", width = 45 },
            vb:checkbox {
              id = "stack_fx_aggressive",
              value = (function()
                local archetypes = arch.stack_master_fx_archetypes or {}
                for _, a in ipairs(archetypes) do if a == "aggressive" then return true end end
                return false
              end)(),
              notifier = function(value)
                arch.stack_master_fx_archetypes = arch.stack_master_fx_archetypes or {}
                if value then
                  table.insert(arch.stack_master_fx_archetypes, "aggressive")
                else
                  for i, a in ipairs(arch.stack_master_fx_archetypes) do
                    if a == "aggressive" then table.remove(arch.stack_master_fx_archetypes, i) break end
                  end
                end
              end
            },
            vb:text { text = "Aggro", width = 40 }
          }
        }
        },  -- End of COLUMN 1
        
        -- COLUMN 2: Global FX Frames, Group Scan, Vector Synthesis
        vb:column {
          width = 220,
          
          -- Global FX Frames (frame scanning at output stage)
          vb:column {
            style = "group",
            width = 205,
            
            vb:text { text = "Global FX Frames", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "global_fx_frames_enabled",
              value = arch.global_fx_frames_enabled or false,
              notifier = function(value)
                arch.global_fx_frames_enabled = value
                PakettiMetaSynthUpdatePreview()
              end
            },
            vb:text { text = "Enable" }
          },
          
          vb:row {
            vb:text { text = "Frames", width = 65 },
            vb:valuebox {
              id = "global_fx_frame_count",
              min = 1,
              max = 8,
              value = arch.global_fx_frame_count or 1,
              width = 55,
              notifier = function(value)
                arch.global_fx_frame_count = value
                PakettiMetaSynthUpdatePreview()
              end
            }
          },
          
          vb:row {
            vb:checkbox {
              id = "global_fx_frame_morph_enabled",
              value = arch.global_fx_frame_morph_enabled or false,
              notifier = function(value)
                arch.global_fx_frame_morph_enabled = value
              end
            },
            vb:text { text = "Morph" },
            vb:popup {
              id = "global_fx_frame_morph_speed",
              items = {"Slow", "Medium", "Fast"},
              value = (function()
                local speed = arch.global_fx_frame_morph_speed or "slow"
                if speed == "slow" then return 1
                elseif speed == "medium" then return 2
                else return 3 end
              end)(),
              width = 80,
              notifier = function(value)
                local speeds = {"slow", "medium", "fast"}
                arch.global_fx_frame_morph_speed = speeds[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Curve", width = 65 },
            vb:popup {
              id = "global_fx_frame_curve",
              items = {"Linear", "Equal Power", "S-Curve", "Stepped", "Spectral", "Vector"},
              value = (function()
                local curve = arch.global_fx_frame_crossfade_curve or "equal_power"
                if curve == "linear" then return 1
                elseif curve == "equal_power" then return 2
                elseif curve == "s_curve" then return 3
                elseif curve == "stepped" then return 4
                elseif curve == "spectral" then return 5
                else return 6 end
              end)(),
              width = 130,
              notifier = function(value)
                local curves = {"linear", "equal_power", "s_curve", "stepped", "spectral", "vector"}
                arch.global_fx_frame_crossfade_curve = curves[value]
              end
            }
          },
          
          vb:row {
            vb:checkbox {
              id = "global_fx_frame_fx_enabled",
              value = arch.global_fx_frame_fx_enabled or false,
              notifier = function(value)
                arch.global_fx_frame_fx_enabled = value
              end
            },
            vb:text { text = "Frame FX", width = 55 },
            vb:popup {
              id = "global_fx_frame_fx_category",
              items = PakettiMetaSynthFXCategoryList,
              value = (function()
                local cat = arch.global_fx_frame_fx_category
                if not cat then return 1 end
                for i, c in ipairs(PakettiMetaSynthFXCategoryList) do
                  if c == cat then return i end
                end
                return 1
              end)(),
              width = 130,
              tooltip = "FX Category for Total Group Frame FX",
              notifier = function(value)
                if value == 1 then
                  arch.global_fx_frame_fx_category = nil
                else
                  arch.global_fx_frame_fx_category = PakettiMetaSynthFXCategoryList[value]
                end
              end
            },
            vb:text { text = "N" },
            vb:valuebox {
              id = "global_fx_frame_fx_count",
              min = 0,
              max = 3,
              value = arch.global_fx_frame_fx_count or 1,
              width = 55,
              tooltip = "Number of FX devices per frame",
              notifier = function(value)
                arch.global_fx_frame_fx_count = value
              end
            }
          },
          
          -- Global FX Scan section
          vb:text { text = "GFX Scan", style = "strong", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "global_fx_scan_enabled",
              value = arch.global_fx_scan_enabled or false,
              tooltip = "Enable wavetable scanning across Global FX Frames (requires 2+ frames)",
              notifier = function(value)
                arch.global_fx_scan_enabled = value
              end
            },
            vb:text { text = "Enable", width = 40 }
          },
          vb:row {
            vb:text { text = "Curve", width = 65 },
            vb:popup {
              id = "global_fx_scan_curve",
              items = METASYNTH_CROSSFADE_CURVE_NAMES,
              value = (function()
                local curve = arch.global_fx_scan_curve or "equal_power"
                for i, c in ipairs(METASYNTH_CROSSFADE_CURVES) do
                  if c == curve then return i end
                end
                return 2  -- Default to equal_power
              end)(),
              width = 130,
              notifier = function(value)
                arch.global_fx_scan_curve = METASYNTH_CROSSFADE_CURVES[value]
              end
            }
          },
          vb:row {
            vb:text { text = "Ctrl", width = 65 },
            vb:popup {
              id = "global_fx_scan_control",
              items = {"LFO", "Macro"},
              value = arch.global_fx_scan_control_source == "macro" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.global_fx_scan_control_source = value == 2 and "macro" or "lfo"
              end
            },
            vb:popup {
              id = "global_fx_scan_speed",
              items = {"Slow", "Medium", "Fast"},
              value = (function()
                local speed = arch.global_fx_scan_lfo_rate_preset or "slow"
                if speed == "slow" then return 1
                elseif speed == "medium" then return 2
                else return 3 end
              end)(),
              width = 65,
              notifier = function(value)
                local speeds = {"slow", "medium", "fast"}
                arch.global_fx_scan_lfo_rate_preset = speeds[value]
              end
            }
          },
          
          -- Global FX Vector section
          vb:text { text = "GFX Vector", style = "strong", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "global_fx_vector_enabled",
              value = arch.global_fx_vector_enabled or false,
              tooltip = "Enable XY vector synthesis on Global FX Frames (requires exactly 4 frames)",
              notifier = function(value)
                arch.global_fx_vector_enabled = value
              end
            },
            vb:text { text = "Enable (4 Frames)", width = 100 }
          },
          vb:row {
            vb:text { text = "X", width = 20 },
            vb:popup {
              id = "global_fx_vector_x_source",
              items = {"Macro", "LFO"},
              value = arch.global_fx_vector_x_source == "lfo" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.global_fx_vector_x_source = value == 2 and "lfo" or "macro"
              end
            },
            vb:text { text = "Y", width = 20 },
            vb:popup {
              id = "global_fx_vector_y_source",
              items = {"Macro", "LFO"},
              value = arch.global_fx_vector_y_source == "lfo" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.global_fx_vector_y_source = value == 2 and "lfo" or "macro"
              end
            }
          },
          vb:row {
            vb:text { text = "X Rate", width = 45 },
            vb:valuebox {
              id = "global_fx_vector_x_rate",
              min = 0.01,
              max = 5.0,
              value = arch.global_fx_vector_x_lfo_rate or 0.25,
              width = 55,
              tostring = function(v) return string.format("%.2f", v) end,
              tonumber = function(s) return tonumber(s) or 0.25 end,
              notifier = function(value)
                arch.global_fx_vector_x_lfo_rate = value
              end
            },
            vb:text { text = "Y", width = 20 },
            vb:valuebox {
              id = "global_fx_vector_y_rate",
              min = 0.01,
              max = 5.0,
              value = arch.global_fx_vector_y_lfo_rate or 0.15,
              width = 55,
              tostring = function(v) return string.format("%.2f", v) end,
              tonumber = function(s) return tonumber(s) or 0.15 end,
              notifier = function(value)
                arch.global_fx_vector_y_lfo_rate = value
              end
            }
          }
        },
        
        -- Group Scan (wavetable across groups)
        vb:column {
          style = "group",
          width = 205,
          
          vb:text { text = "Group Scan", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "group_scan_enabled",
              value = arch.group_scan_enabled or false,
              tooltip = "Enable wavetable scanning between groups (requires 2+ groups)",
              notifier = function(value)
                arch.group_scan_enabled = value
                PakettiMetaSynthUpdatePreview()
              end
            },
            vb:text { text = "Enable", width = 50 }
          },
          
          vb:row {
            vb:text { text = "Curve", width = 65 },
            vb:popup {
              id = "group_scan_curve",
              items = {"Linear", "Equal Power", "S-Curve", "Stepped", "Spectral", "Vector"},
              value = (function()
                local curve = arch.group_scan_curve or "equal_power"
                if curve == "linear" then return 1
                elseif curve == "equal_power" then return 2
                elseif curve == "s_curve" then return 3
                elseif curve == "stepped" then return 4
                elseif curve == "spectral" then return 5
                else return 6 end
              end)(),
              width = 130,
              notifier = function(value)
                local curves = {"linear", "equal_power", "s_curve", "stepped", "spectral", "vector"}
                arch.group_scan_curve = curves[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Ctrl", width = 65 },
            vb:popup {
              id = "group_scan_control",
              items = {"LFO", "Macro"},
              value = arch.group_scan_control_source == "macro" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.group_scan_control_source = value == 2 and "macro" or "lfo"
              end
            },
            vb:popup {
              id = "group_scan_speed",
              items = {"Slow", "Medium", "Fast"},
              value = (function()
                local speed = arch.group_scan_speed or "slow"
                if speed == "slow" then return 1
                elseif speed == "medium" then return 2
                else return 3 end
              end)(),
              width = 65,
              notifier = function(value)
                local speeds = {"slow", "medium", "fast"}
                arch.group_scan_speed = speeds[value]
              end
            }
          }
        },
        
        -- Vector Synthesis (4-group XY morph)
        vb:column {
          style = "group",
          width = 205,
          
          
          vb:text { text = "Vector Synthesis", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "vector_enabled",
              value = arch.vector_enabled or false,
              tooltip = "Enable XY vector synthesis (requires exactly 4 groups)",
              notifier = function(value)
                arch.vector_enabled = value
                PakettiMetaSynthUpdatePreview()
              end
            },
            vb:text { text = "Enable (4 Groups)", width = 100 }
          },
          
          vb:row {
            vb:text { text = "X", width = 20 },
            vb:popup {
              id = "vector_x_source",
              items = {"Macro", "LFO"},
              value = arch.vector_x_source == "lfo" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.vector_x_source = value == 2 and "lfo" or "macro"
              end
            },
            vb:text { text = "Y", width = 20 },
            vb:popup {
              id = "vector_y_source",
              items = {"Macro", "LFO"},
              value = arch.vector_y_source == "lfo" and 2 or 1,
              width = 65,
              notifier = function(value)
                arch.vector_y_source = value == 2 and "lfo" or "macro"
              end
            }
          },
          
          vb:row {
            vb:text { text = "X Macro", width = 55 },
            vb:valuebox {
              id = "vector_x_macro",
              min = 1,
              max = 8,
              value = arch.vector_x_macro or 7,
              width = 55,
              notifier = function(value)
                arch.vector_x_macro = value
              end
            },
            vb:text { text = "Y", width = 20 },
            vb:valuebox {
              id = "vector_y_macro",
              min = 1,
              max = 8,
              value = arch.vector_y_macro or 8,
              width = 55,
              notifier = function(value)
                arch.vector_y_macro = value
              end
            }
          },
          
          -- Vector Envelope controls
          vb:row {
            vb:checkbox {
              id = "vector_envelope_enabled",
              value = arch.vector_envelope and arch.vector_envelope.enabled or false,
              notifier = function(value)
                if not arch.vector_envelope then
                  arch.vector_envelope = PakettiMetaSynthGetVectorEnvelopePreset("circle")
                end
                arch.vector_envelope.enabled = value
              end
            },
            vb:text { text = "Envelope Path" }
          },
          
          vb:row {
            vb:text { text = "Preset", width = 65 },
            vb:popup {
              id = "vector_envelope_preset",
              items = {"Circle", "Figure-8", "Diagonal", "Square", "X Sweep", "Y Sweep", "Random"},
              value = 1,
              width = 130,
              notifier = function(value)
                local preset_names = {"circle", "figure8", "diagonal", "square", "x_sweep", "y_sweep", "random_walk"}
                local preset = PakettiMetaSynthGetVectorEnvelopePreset(preset_names[value])
                arch.vector_envelope = preset
                -- Update duration display
                local duration_view = vb.views["vector_envelope_duration"]
                if duration_view then
                  duration_view.value = preset.duration
                end
                -- Update loop checkbox
                local loop_view = vb.views["vector_envelope_loop"]
                if loop_view then
                  loop_view.value = preset.loop
                end
              end
            }
          },
          
          vb:row {
            vb:text { text = "Duration", width = 55 },
            vb:valuebox {
              id = "vector_envelope_duration",
              min = 0.5,
              max = 32.0,
              value = arch.vector_envelope and arch.vector_envelope.duration or 4.0,
              width = 55,
              notifier = function(value)
                if arch.vector_envelope then
                  arch.vector_envelope.duration = value
                end
              end
            },
            vb:text { text = "s" },
            vb:checkbox {
              id = "vector_envelope_loop",
              value = arch.vector_envelope and arch.vector_envelope.loop or true,
              notifier = function(value)
                if arch.vector_envelope then
                  arch.vector_envelope.loop = value
                end
              end
            },
            vb:text { text = "Loop" }
          }
        }
        },  -- End of COLUMN 2
        
        -- COLUMN 3: Global Modulation, Final Output, Constraints, Shortcuts
        vb:column {
          width = 220,
          
          -- Global Modulation (shared LFOs across groups)
          vb:column {
            style = "group",
            width = 205,
            
            
            vb:text { text = "Global Modulation", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "global_mod_enabled",
              value = arch.global_modulation and arch.global_modulation.enabled or false,
              tooltip = "Enable shared LFO modulation across all groups",
              notifier = function(value)
                if not arch.global_modulation then
                  arch.global_modulation = PakettiMetaSynthGetDefaultGlobalModulation()
                end
                arch.global_modulation.enabled = value
              end
            },
            vb:text { text = "Enable" }
          },
          
          vb:text { text = "LFO 1", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "global_mod_lfo1_enabled",
              value = arch.global_modulation and arch.global_modulation.lfo1 and arch.global_modulation.lfo1.enabled or false,
              notifier = function(value)
                if not arch.global_modulation then
                  arch.global_modulation = PakettiMetaSynthGetDefaultGlobalModulation()
                end
                arch.global_modulation.lfo1.enabled = value
              end
            },
            vb:valuebox {
              id = "global_mod_lfo1_freq",
              min = 0.01,
              max = 20.0,
              value = arch.global_modulation and arch.global_modulation.lfo1 and arch.global_modulation.lfo1.frequency or 0.5,
              width = 55,
              tostring = function(v) return string.format("%.2f", v) end,
              tonumber = function(s) return tonumber(s) or 0.5 end,
              notifier = function(value)
                if arch.global_modulation and arch.global_modulation.lfo1 then
                  arch.global_modulation.lfo1.frequency = value
                end
              end
            },
            vb:text { text = "Hz" },
            vb:popup {
              id = "global_mod_lfo1_shape",
              items = {"Sine", "Triangle", "Square", "Saw"},
              value = (function()
                if arch.global_modulation and arch.global_modulation.lfo1 then
                  local shape = arch.global_modulation.lfo1.shape or "sine"
                  if shape == "sine" then return 1
                  elseif shape == "triangle" then return 2
                  elseif shape == "square" then return 3
                  else return 4 end
                end
                return 1
              end)(),
              width = 80,
              notifier = function(value)
                if arch.global_modulation and arch.global_modulation.lfo1 then
                  local shapes = {"sine", "triangle", "square", "saw"}
                  arch.global_modulation.lfo1.shape = shapes[value]
                end
              end
            }
          },
          
          vb:text { text = "LFO 2", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "global_mod_lfo2_enabled",
              value = arch.global_modulation and arch.global_modulation.lfo2 and arch.global_modulation.lfo2.enabled or false,
              notifier = function(value)
                if not arch.global_modulation then
                  arch.global_modulation = PakettiMetaSynthGetDefaultGlobalModulation()
                end
                arch.global_modulation.lfo2.enabled = value
              end
            },
            vb:valuebox {
              id = "global_mod_lfo2_freq",
              min = 0.01,
              max = 20.0,
              value = arch.global_modulation and arch.global_modulation.lfo2 and arch.global_modulation.lfo2.frequency or 0.25,
              width = 55,
              tostring = function(v) return string.format("%.2f", v) end,
              tonumber = function(s) return tonumber(s) or 0.25 end,
              notifier = function(value)
                if arch.global_modulation and arch.global_modulation.lfo2 then
                  arch.global_modulation.lfo2.frequency = value
                end
              end
            },
            vb:text { text = "Hz" },
            vb:popup {
              id = "global_mod_lfo2_shape",
              items = {"Sine", "Triangle", "Square", "Saw"},
              value = (function()
                if arch.global_modulation and arch.global_modulation.lfo2 then
                  local shape = arch.global_modulation.lfo2.shape or "triangle"
                  if shape == "sine" then return 1
                  elseif shape == "triangle" then return 2
                  elseif shape == "square" then return 3
                  else return 4 end
                end
                return 2
              end)(),
              width = 80,
              notifier = function(value)
                if arch.global_modulation and arch.global_modulation.lfo2 then
                  local shapes = {"sine", "triangle", "square", "saw"}
                  arch.global_modulation.lfo2.shape = shapes[value]
                end
              end
            }
          },
          
          vb:row {
            vb:text { text = "Target", width = 65 },
            vb:popup {
              id = "global_mod_lfo1_target",
              items = {"Group Gain", "Scan Gain", "Vector Gain"},
              value = 1,
              width = 130,
              notifier = function(value)
                if arch.global_modulation and arch.global_modulation.lfo1 then
                  local targets = {"group_gain", "scan_gain", "vector_gain"}
                  arch.global_modulation.lfo1.targets = {targets[value]}
                end
              end
            }
          }
        },
        
        -- Final Output Stage (Master EQ, Limiter, Output Shaping)
        vb:column {
          style = "group",
          width = 205,
          
          
          vb:text { text = "Final Output", style = "strong", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "final_output_enabled",
              value = arch.final_output_enabled or false,
              tooltip = "Enable final output processing (Master EQ, Limiter, Width)",
              notifier = function(value)
                arch.final_output_enabled = value
              end
            },
            vb:text { text = "Enable Final Output Stage" }
          },
          
          -- Master EQ
          vb:text { text = "Master EQ", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "final_output_eq_enabled",
              value = arch.final_output_master_eq_enabled ~= false,
              notifier = function(value)
                arch.final_output_master_eq_enabled = value
              end
            },
            vb:text { text = "EQ", width = 25 },
            vb:text { text = "Low", width = 30 },
            vb:valuebox {
              id = "final_output_eq_low",
              min = -12,
              max = 12,
              value = arch.final_output_master_eq_low_shelf or 0,
              width = 55,
              notifier = function(value)
                arch.final_output_master_eq_low_shelf = value
              end
            },
            vb:text { text = "Hi", width = 20 },
            vb:valuebox {
              id = "final_output_eq_high",
              min = -12,
              max = 12,
              value = arch.final_output_master_eq_high_shelf or 0,
              width = 55,
              notifier = function(value)
                arch.final_output_master_eq_high_shelf = value
              end
            }
          },
          
          -- Limiter
          vb:text { text = "Limiter", font = "italic" },
          vb:row {
            vb:checkbox {
              id = "final_output_limiter_enabled",
              value = arch.final_output_limiter_enabled ~= false,
              notifier = function(value)
                arch.final_output_limiter_enabled = value
              end
            },
            vb:text { text = "On", width = 20 },
            vb:text { text = "Ceil", width = 30 },
            vb:valuebox {
              id = "final_output_limiter_ceiling",
              min = -6.0,
              max = 0.0,
              value = arch.final_output_limiter_ceiling or -0.3,
              width = 55,
              tostring = function(v) return string.format("%.1f", v) end,
              tonumber = function(s) return tonumber(s) or -0.3 end,
              notifier = function(value)
                arch.final_output_limiter_ceiling = value
              end
            },
            vb:text { text = "dB" }
          },
          
          -- Saturation & Width
          vb:row {
            vb:checkbox {
              id = "final_output_saturation_enabled",
              value = arch.final_output_saturation_enabled or false,
              notifier = function(value)
                arch.final_output_saturation_enabled = value
              end
            },
            vb:text { text = "Warmth", width = 50 },
            vb:checkbox {
              id = "final_output_width_enabled",
              value = arch.final_output_width_enabled or false,
              notifier = function(value)
                arch.final_output_width_enabled = value
              end
            },
            vb:text { text = "Width", width = 40 },
            vb:valuebox {
              id = "final_output_width_amount",
              min = 0.0,
              max = 2.0,
              value = arch.final_output_width_amount or 1.0,
              width = 55,
              tostring = function(v) return string.format("%.1f", v) end,
              tonumber = function(s) return tonumber(s) or 1.0 end,
              notifier = function(value)
                arch.final_output_width_amount = value
              end
            }
          },
          
          -- Spectral Morph Macro
          vb:row {
            vb:checkbox {
              id = "spectral_morph_enabled",
              value = arch.spectral_morph_enabled or false,
              tooltip = "Enable macro-controlled spectral morphing intensity",
              notifier = function(value)
                arch.spectral_morph_enabled = value
              end
            },
            vb:text { text = "Spectral Morph Macro", width = 120 },
            vb:valuebox {
              id = "spectral_morph_macro",
              min = 1,
              max = 8,
              value = arch.spectral_morph_macro_index or 5,
              width = 55,
              notifier = function(value)
                arch.spectral_morph_macro_index = value
              end
            }
          }
        },
        
        -- Constraints Section
        vb:column {
          style = "group",
          width = 205,
          vb:text { text = "Constraints", style = "strong", font = "bold" },
          vb:row {
            vb:text { text = "Groups", width = 65 },
            vb:valuebox {
              min = 1, max = 4,
              value = arch.constraints and arch.constraints.group_count_range and arch.constraints.group_count_range[1] or 1,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.group_count_range = arch.constraints.group_count_range or {1, 2}
                arch.constraints.group_count_range[1] = v
              end
            },
            vb:text { text = "-" },
            vb:valuebox {
              min = 1, max = 4,
              value = arch.constraints and arch.constraints.group_count_range and arch.constraints.group_count_range[2] or 2,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.group_count_range = arch.constraints.group_count_range or {1, 2}
                arch.constraints.group_count_range[2] = v
              end
            }
          },
          vb:row {
            vb:text { text = "Frames", width = 65 },
            vb:valuebox {
              min = 1, max = 8,
              value = arch.constraints and arch.constraints.frame_count_range and arch.constraints.frame_count_range[1] or 1,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.frame_count_range = arch.constraints.frame_count_range or {1, 4}
                arch.constraints.frame_count_range[1] = v
              end
            },
            vb:text { text = "-" },
            vb:valuebox {
              min = 1, max = 8,
              value = arch.constraints and arch.constraints.frame_count_range and arch.constraints.frame_count_range[2] or 4,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.frame_count_range = arch.constraints.frame_count_range or {1, 4}
                arch.constraints.frame_count_range[2] = v
              end
            }
          },
          vb:row {
            vb:text { text = "FX", width = 65 },
            vb:valuebox {
              min = 0, max = 8,
              value = arch.constraints and arch.constraints.fx_count_range and arch.constraints.fx_count_range[1] or 0,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.fx_count_range = arch.constraints.fx_count_range or {0, 4}
                arch.constraints.fx_count_range[1] = v
              end
            },
            vb:text { text = "-" },
            vb:valuebox {
              min = 0, max = 8,
              value = arch.constraints and arch.constraints.fx_count_range and arch.constraints.fx_count_range[2] or 4,
              width = 55,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.fx_count_range = arch.constraints.fx_count_range or {0, 4}
                arch.constraints.fx_count_range[2] = v
              end
            }
          },
          vb:text { text = "Features", font = "italic" },
          vb:row {
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_group_frames ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_group_frames = v
              end
            },
            vb:text { text = "Group Frames", width = 75 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_vector ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_vector = v
              end
            },
            vb:text { text = "Vector", width = 45 }
          },
          vb:row {
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_group_scan ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_group_scan = v
              end
            },
            vb:text { text = "Group Scan", width = 75 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_stepper ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_stepper = v
              end
            },
            vb:text { text = "Stepper", width = 45 }
          },
          vb:text { text = "FX Devices", font = "italic" },
          vb:row {
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_reverb ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_reverb = v
              end
            },
            vb:text { text = "Reverb", width = 45 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_chorus ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_chorus = v
              end
            },
            vb:text { text = "Chorus", width = 45 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_distortion ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_distortion = v
              end
            },
            vb:text { text = "Dist", width = 30 }
          },
          vb:row {
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_filter ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_filter = v
              end
            },
            vb:text { text = "Filter", width = 45 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_eq ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_eq = v
              end
            },
            vb:text { text = "EQ", width = 45 },
            vb:checkbox {
              value = arch.constraints and arch.constraints.allow_maximizer ~= false,
              notifier = function(v)
                arch.constraints = arch.constraints or {}
                arch.constraints.allow_maximizer = v
              end
            },
            vb:text { text = "Max", width = 30 }
          }
        },
        
          -- Shortcuts hint
          vb:column {
            style = "group",
            width = 205,
            vb:text { text = "Shortcuts", style = "strong", font = "bold" },
            vb:text { text = "Enter Generate" },
            vb:text { text = "R Randomize" },
            vb:text { text = "Esc Close" }
          }
        }  -- End of COLUMN 3
      }  -- End of 3-column row
    },
    
    -- Bottom buttons
    vb:row {
      
      vb:button {
        text = "Generate",
        width = 100,
        height = 28,
        notifier = function()
          PakettiMetaSynthGenerateInstrument(PakettiMetaSynthCurrentArchitecture)
        end
      },
      
      vb:button {
        text = "Randomize",
        width = 80,
        height = 28,
        notifier = function()
          PakettiMetaSynthRandomizeArchitecture(PakettiMetaSynthCurrentArchitecture)
          PakettiMetaSynthRebuildDialog()
        end
      },
      
      vb:button {
        text = "Quick Random",
        width = 90,
        height = 28,
        notifier = function()
          PakettiMetaSynthGenerateRandomInstrument()
        end
      },
      
      vb:button {
        text = "Save",
        width = 50,
        height = 28,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_write("lua", "Save MetaSynth Architecture")
          if filename then
            PakettiMetaSynthSaveArchitecture(PakettiMetaSynthCurrentArchitecture, filename)
          end
        end
      },
      
      vb:button {
        text = "Load",
        width = 50,
        height = 28,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_read({"lua"}, "Load MetaSynth Architecture")
          if filename then
            local loaded = PakettiMetaSynthLoadArchitecture(filename)
            if loaded then
              PakettiMetaSynthCurrentArchitecture = loaded
              PakettiMetaSynthRebuildDialog()
            end
          end
        end
      },
      
      vb:button {
        text = "Reset",
        width = 50,
        height = 28,
        notifier = function()
          PakettiMetaSynthCurrentArchitecture = PakettiMetaSynthCreateDefaultArchitecture()
          PakettiMetaSynthRebuildDialog()
        end
      },
      
      vb:button {
        text = "Export XRNI",
        width = 80,
        height = 28,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_write("xrni", "Export Instrument as XRNI")
          if filename then
            local success = renoise.app():save_instrument(filename)
            if success then
              renoise.app():show_status("PakettiMetaSynth: Exported to " .. filename)
            else
              renoise.app():show_status("PakettiMetaSynth: Export failed")
            end
          end
        end
      },
      
      vb:button {
        text = "Save Profile",
        width = 80,
        height = 28,
        notifier = function()
          PakettiMetaSynthQuickSaveAsProfile(PakettiMetaSynthCurrentArchitecture)
        end
      },
      
      vb:button {
        text = "Close",
        width = 50,
        height = 28,
        notifier = function()
          if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
            PakettiMetaSynthDialog:close()
          end
        end
      }
    }
  }
  
  return content
end

-- Rebuild the dialog (for dynamic updates)
function PakettiMetaSynthRebuildDialog()
  if not PakettiMetaSynthDialog or not PakettiMetaSynthDialog.visible then return end
  
  -- Close and reopen with new content
  PakettiMetaSynthDialog:close()
  PakettiMetaSynthVB = nil
  PakettiMetaSynthShowDialog()
end

-- Show the main MetaSynth dialog
function PakettiMetaSynthShowDialog()
  -- Safety check: ensure song is loaded
  if not renoise.song() then
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return
  end
  
  -- Initialize architecture if needed
  if not PakettiMetaSynthCurrentArchitecture then
    PakettiMetaSynthCurrentArchitecture = PakettiMetaSynthCreateDefaultArchitecture()
  end
  
  -- Close existing dialog
  if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
    PakettiMetaSynthDialog:close()
  end
  
  -- Reset ViewBuilder
  PakettiMetaSynthVB = nil
  
  -- Build content
  local content = PakettiMetaSynthBuildDialogContent()
  
  -- Create dialog with custom key handler
  PakettiMetaSynthDialog = renoise.app():show_custom_dialog(
    "PakettiMetaSynth - Architecture Designer",
    content,
    PakettiMetaSynthKeyHandler
  )
  
  -- Update preview
  PakettiMetaSynthUpdatePreview()
  
  -- Restore keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ============================================================================
-- SECTION 10.5: MODULATION PROFILE DIALOG
-- ============================================================================

-- Dialog state for modulation profile selector
PakettiMetaSynthProfileDialogVb = nil
PakettiMetaSynthProfileDialogHandle = nil

-- Show the modulation profile selection dialog
function PakettiMetaSynthShowProfileDialog()
  -- Close existing dialog if open
  if PakettiMetaSynthProfileDialogHandle and PakettiMetaSynthProfileDialogHandle.visible then
    PakettiMetaSynthProfileDialogHandle:close()
    PakettiMetaSynthProfileDialogHandle = nil
  end
  
  -- Check if we have a valid instrument with modulation sets
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("PakettiMetaSynth: No instrument selected")
    return
  end
  
  if #instrument.sample_modulation_sets == 0 then
    renoise.app():show_status("PakettiMetaSynth: No modulation sets in selected instrument")
    return
  end
  
  PakettiMetaSynthProfileDialogVb = renoise.ViewBuilder()
  local vb = PakettiMetaSynthProfileDialogVb
  
  -- Build sound category dropdown items
  local category_items = {}
  for i, cat in ipairs(PakettiMetaSynthSoundCategories) do
    category_items[i] = cat.name
  end
  
  -- Build profile dropdown items
  local profile_items = {}
  for i, profile_name in ipairs(PakettiMetaSynthModulationProfileNames) do
    local profile = PakettiMetaSynthModulationProfiles[profile_name]
    if profile and profile.name then
      profile_items[i] = profile.name .. " - " .. (profile.description or "")
    else
      profile_items[i] = profile_name or "Unknown Profile"
    end
  end
  
  -- Build modulation set dropdown items
  local mod_set_items = {"All Modulation Sets"}
  for i, mod_set in ipairs(instrument.sample_modulation_sets) do
    mod_set_items[i + 1] = string.format("%d: %s", i, mod_set.name or "Unnamed")
  end
  
  -- Helper to find profile index by name
  local function getProfileIndex(profile_name)
    for i, name in ipairs(PakettiMetaSynthModulationProfileNames) do
      if name == profile_name then
        return i
      end
    end
    return 1
  end
  
  local dialog_content = vb:column {
    
    -- Sound Category selection (high-level)
    vb:row {
      vb:text { text = "Sound Category:", width = 120 },
      vb:popup {
        id = "category_selector",
        items = category_items,
        value = 1,
        width = 250,
        notifier = function(idx)
          -- Auto-select the associated profile when category changes
          local category = PakettiMetaSynthSoundCategories[idx]
          if category then
            local profile_idx = getProfileIndex(category.profile)
            vb.views.profile_selector.value = profile_idx
            -- Update description and details
            local profile = PakettiMetaSynthModulationProfiles[category.profile]
            if profile then
              vb.views.profile_description.text = profile.description or ""
              vb.views.profile_details.text = PakettiMetaSynthGetProfileDetailsText(category.profile)
            end
          end
        end
      }
    },
    
    
    
    -- Direct Profile selection (detailed)
    vb:row {
      vb:text { text = "Modulation Profile:", width = 120 },
      vb:popup {
        id = "profile_selector",
        items = profile_items,
        value = 1,
        width = 250,
        notifier = function(idx)
          -- Update description when profile changes
          local profile_name = PakettiMetaSynthModulationProfileNames[idx]
          local profile = PakettiMetaSynthModulationProfiles[profile_name]
          vb.views.profile_description.text = profile.description or ""
          vb.views.profile_details.text = PakettiMetaSynthGetProfileDetailsText(profile_name)
        end
      }
    },
    
    vb:row {
      vb:text { text = "Description:", width = 120 },
      vb:text {
        id = "profile_description",
        text = PakettiMetaSynthModulationProfiles["neutral_flat"].description or "",
        width = 250,
        font = "italic"
      }
    },
    
    
    vb:row {
      vb:text { text = "Apply to:", width = 120 },
      vb:popup {
        id = "target_selector",
        items = mod_set_items,
        value = 1,
        width = 250
      }
    },
    
    
    
    -- Profile details preview
    vb:column {
      style = "group",
      
      vb:text { text = "Profile Components:", font = "bold" },
      vb:text {
        id = "profile_details",
        text = PakettiMetaSynthGetProfileDetailsText("neutral_flat"),
        font = "mono"
      }
    },
    
    
    vb:row {
      vb:button {
        text = "Apply Profile",
        width = 120,
        notifier = function()
          local profile_idx = vb.views.profile_selector.value
          local target_idx = vb.views.target_selector.value
          local profile_name = PakettiMetaSynthModulationProfileNames[profile_idx]
          
          if target_idx == 1 then
            -- Apply to all modulation sets
            PakettiMetaSynthApplyProfileToAllModSets(instrument, profile_name)
            renoise.app():show_status("Applied '" .. profile_name .. "' to all modulation sets")
          else
            -- Apply to specific modulation set
            local mod_set_index = target_idx - 1
            PakettiMetaSynthApplyProfileToInstrument(instrument, mod_set_index, profile_name)
            renoise.app():show_status("Applied '" .. profile_name .. "' to modulation set " .. mod_set_index)
          end
        end
      },
      vb:button {
        text = "Close",
        width = 80,
        notifier = function()
          if PakettiMetaSynthProfileDialogHandle and PakettiMetaSynthProfileDialogHandle.visible then
            PakettiMetaSynthProfileDialogHandle:close()
          end
        end
      }
    }
  }
  
  -- Update profile details when selection changes
  vb.views.profile_selector:add_notifier(function(idx)
    local profile_name = PakettiMetaSynthModulationProfileNames[idx]
    vb.views.profile_details.text = PakettiMetaSynthGetProfileDetailsText(profile_name)
  end)
  
  PakettiMetaSynthProfileDialogHandle = renoise.app():show_custom_dialog(
    "MetaSynth - Apply Modulation Profile",
    dialog_content,
    my_keyhandler_func
  )
  
  -- Restore keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Generate a text description of profile components
function PakettiMetaSynthGetProfileDetailsText(profile_name)
  local profile = PakettiMetaSynthModulationProfiles[profile_name]
  if not profile then return "Unknown profile" end
  
  local lines = {}
  
  -- Volume envelope
  if profile.volume_ahdsr then
    local env = profile.volume_ahdsr
    table.insert(lines, string.format("Volume Env: A:%.2f H:%.2f D:%.2f S:%.2f R:%.2f",
      env.attack, env.hold, env.decay, env.sustain, env.release))
  else
    table.insert(lines, "Volume Env: None (raw)")
  end
  
  -- Filter envelope
  if profile.filter_ahdsr then
    local env = profile.filter_ahdsr
    table.insert(lines, string.format("Filter Env: A:%.2f H:%.2f D:%.2f S:%.2f R:%.2f",
      env.attack, env.hold, env.decay, env.sustain, env.release))
  else
    table.insert(lines, "Filter Env: None")
  end
  
  -- Pitch envelope
  if profile.pitch_ahdsr then
    local env = profile.pitch_ahdsr
    table.insert(lines, string.format("Pitch Env:  A:%.2f D:%.2f Amt:%.2f",
      env.attack, env.decay, env.amount or 0))
  else
    table.insert(lines, "Pitch Env:  None")
  end
  
  -- Velocity tracking
  local vel_parts = {}
  if profile.velocity_volume and profile.velocity_volume > 0 then
    table.insert(vel_parts, string.format("Vol:%.0f%%", profile.velocity_volume * 100))
  end
  if profile.velocity_filter and profile.velocity_filter > 0 then
    table.insert(vel_parts, string.format("Filter:%.0f%%", profile.velocity_filter * 100))
  end
  if #vel_parts > 0 then
    table.insert(lines, "Velocity: " .. table.concat(vel_parts, ", "))
  else
    table.insert(lines, "Velocity: None")
  end
  
  -- Keytracking
  if profile.filter_keytrack and profile.filter_keytrack > 0 then
    table.insert(lines, string.format("Filter Keytrack: %.0f%%", profile.filter_keytrack * 100))
  end
  
  -- LFOs
  local lfos = {}
  if profile.volume_lfo then
    table.insert(lfos, string.format("Vol:%.1fHz", profile.volume_lfo.frequency))
  end
  if profile.pitch_lfo then
    table.insert(lfos, string.format("Pitch:%.1fHz", profile.pitch_lfo.frequency))
  end
  if profile.filter_lfo then
    table.insert(lfos, string.format("Filter:%.1fHz", profile.filter_lfo.frequency))
  end
  
  if #lfos > 0 then
    table.insert(lines, "LFOs: " .. table.concat(lfos, ", "))
  else
    table.insert(lines, "LFOs: None")
  end
  
  return table.concat(lines, "\n")
end

-- Quick apply profile to current instrument (all modulation sets)
function PakettiMetaSynthQuickApplyProfile(profile_name)
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("PakettiMetaSynth: No instrument selected")
    return
  end
  
  if #instrument.sample_modulation_sets == 0 then
    renoise.app():show_status("PakettiMetaSynth: No modulation sets in selected instrument")
    return
  end
  
  PakettiMetaSynthApplyProfileToAllModSets(instrument, profile_name)
  renoise.app():show_status("Applied modulation profile: " .. profile_name)
end

-- ============================================================================
-- SECTION 11: MENU ENTRIES, KEYBINDINGS, AND MIDI MAPPINGS
-- ============================================================================

-- Load user profiles on tool startup
PakettiMetaSynthLoadAllUserProfiles()

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument (Wavetable)",
  invoke = function()
    PakettiMetaSynthGenerateRandomWavetableInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Batch Instruments...",
  invoke = function()
    PakettiMetaSynthShowBatchGenerationDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("standard", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("sends", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate 20 Random Wavetable Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("wavetable", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Modulation Profile...",
  invoke = function()
    PakettiMetaSynthShowProfileDialog()
  end
}

-- Neutral profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Neutral:Flat",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("neutral_flat")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Neutral:None",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("neutral_none")
  end
}

-- Bass profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bass:Tight",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_tight")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bass:Sustain",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_sustain")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bass:Filter",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_filter")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bass:Wide",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_wide")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bass:Dynamic",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_dynamic")
  end
}

-- Pluck profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pluck:Short",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck_short")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pluck:Natural",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck_natural")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pluck:Percussive",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck_percussive")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pluck:Soft",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck_soft")
  end
}

-- Lead profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Lead:Expressive",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_expressive")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Lead:Smooth",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_smooth")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Lead:Classic",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_classic")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Lead:Wide",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_wide")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Lead:Glide",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_glide")
  end
}

-- Pad profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pad:Slow",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad_slow")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pad:Evolving",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad_evolving")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pad:Ensemble",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad_ensemble")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Pad:Formant",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad_formant")
  end
}

-- Keys profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Keys:Dynamic",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("keys_dynamic")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Keys:Sustain",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("keys_sustain")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Keys:Velocity",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("keys_velocity")
  end
}

-- Arp profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Arp:Tight",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("arp_tight")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Arp:Gated",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("arp_gated")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Arp:Rhythmic",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("arp_rhythmic")
  end
}

-- FX profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:FX:Envelope",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("fx_envelope")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:FX:Percussive",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("fx_percussive")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:FX:Sustain",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("fx_sustain")
  end
}

-- Orchestral profiles
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Orchestral:Strings",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("strings")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Orchestral:Brass",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("brass")
  end
}

-- Bell profile
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Bell",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bell")
  end
}

-- Legacy profiles (for backward compatibility)
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Default",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("default")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Pluck",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Bass",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Pad",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Lead",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Organ",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("organ")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Keys",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("keys")
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Apply Profile:Legacy:Percussive",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("percussive")
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument (Wavetable)",
  invoke = function()
    PakettiMetaSynthGenerateRandomWavetableInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Batch Instruments...",
  invoke = function()
    PakettiMetaSynthShowBatchGenerationDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("standard", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("sends", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate 20 Random Wavetable Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("wavetable", 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Apply Modulation Profile...",
  invoke = function()
    PakettiMetaSynthShowProfileDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Sample FX Mixer:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

-- Keybindings
renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Open Architecture Designer",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate Batch Instruments Dialog",
  invoke = function()
    PakettiMetaSynthShowBatchGenerationDialog()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("standard", 20)
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("sends", 20)
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate 20 Random Wavetable Instruments",
  invoke = function()
    PakettiMetaSynthLaunchBatchGeneration("wavetable", 20)
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Modulation Profile Dialog",
  invoke = function()
    PakettiMetaSynthShowProfileDialog()
  end
}

-- Quick profile application keybindings by family
renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Bass Tight",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("bass_tight")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Pluck Short",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pluck_short")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Lead Expressive",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("lead_expressive")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Pad Slow",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("pad_slow")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Keys Dynamic",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("keys_dynamic")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Arp Tight",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("arp_tight")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile FX Envelope",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("fx_envelope")
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Apply Profile Neutral Flat",
  invoke = function()
    PakettiMetaSynthQuickApplyProfile("neutral_flat")
  end
}

-- MIDI mappings
renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate Random Instrument",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateRandomInstrument()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate Random Instrument (with Sends)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateRandomInstrumentWithSends()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate Batch Instruments Dialog",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthShowBatchGenerationDialog()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate 20 Random Instruments",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthLaunchBatchGeneration("standard", 20)
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate 20 Random Instruments (with Sends)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthLaunchBatchGeneration("sends", 20)
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate 20 Random Wavetable Instruments",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthLaunchBatchGeneration("wavetable", 20)
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Open Architecture Designer",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthShowDialog()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Modulation Profile Dialog",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthShowProfileDialog()
    end
  end
}

-- Quick profile MIDI mappings by family
renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Bass Tight",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("bass_tight")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Pluck Short",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("pluck_short")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Lead Expressive",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("lead_expressive")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Pad Slow",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("pad_slow")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Keys Dynamic",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("keys_dynamic")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Arp Tight",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("arp_tight")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile FX Envelope",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("fx_envelope")
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Apply Profile Neutral Flat",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthQuickApplyProfile("neutral_flat")
    end
  end
}

print("PakettiMetaSynth loaded successfully")
