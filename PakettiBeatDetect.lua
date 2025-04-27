-- TODO Finish BeatDetect

vb = renoise.ViewBuilder()
vbs = vb.views
dialog = nil

-- Delete existing slice markers
local function DeleteSliceMarkers()
  local sample = renoise.song().selected_sample
  if not sample then return end
  if #sample.slice_markers > 0 then
    for i = #sample.slice_markers, 1, -1 do
      sample:delete_slice_marker(sample.slice_markers[i])
    end
  end
end

-- Zero-Crossing Detection Function
local function find_zero_crossing(buffer, pos, search_range_samples, zero_threshold)
  local start_pos = math.max(1, pos - search_range_samples)
  local end_pos = math.min(buffer.number_of_frames, pos + search_range_samples)

  local zero_crossing_pos = pos
  local min_amplitude = math.abs(buffer:sample_data(1, pos))

  -- Search backward
  for i = pos, start_pos, -1 do
    local sample_value = buffer:sample_data(1, i)
    if math.abs(sample_value) <= zero_threshold then
      zero_crossing_pos = i
      break
    elseif math.abs(sample_value) < min_amplitude then
      min_amplitude = math.abs(sample_value)
      zero_crossing_pos = i
    end
  end

  -- Search forward if not found backward
  if zero_crossing_pos == pos then
    for i = pos, end_pos do
      local sample_value = buffer:sample_data(1, i)
      if math.abs(sample_value) <= zero_threshold then
        zero_crossing_pos = i
        break
      elseif math.abs(sample_value) < min_amplitude then
        min_amplitude = math.abs(sample_value)
        zero_crossing_pos = i
      end
    end
  end

  return zero_crossing_pos
end

-- BeatDetector Class
class 'BeatDetector'
function BeatDetector:__init(filter_freq, release_time, trigger_on, trigger_off, filter_type)
  self.KBeatFilter = 0.0
  self.Filter1Out = 0.0
  self.Filter2Out = 0.0
  self.BeatRelease = 0.0
  self.PeakEnv = 0.0
  self.BeatTrigger = false
  self.PrevBeatPulse = false
  self.BeatPulse = false

  self.filter_freq = filter_freq
  self.release_time = release_time
  self.trigger_on = trigger_on
  self.trigger_off = trigger_off
  self.filter_type = filter_type -- 'lowpass' or 'highpass'
end

function BeatDetector:setSampleRate(samplerate)
  -- Compute all sample frequency coefficients
  local T_FILTER = 1.0 / (2.0 * math.pi * self.filter_freq)
  self.KBeatFilter = 1.0 / (samplerate * T_FILTER)
  self.BeatRelease = math.exp(-1.0 / (samplerate * self.release_time))
end

function BeatDetector:Process(input)
  -- Step 1: 2nd order lowpass filter
  self.Filter1Out = self.Filter1Out + (self.KBeatFilter * (input - self.Filter1Out))
  self.Filter2Out = self.Filter2Out + (self.KBeatFilter * (self.Filter1Out - self.Filter2Out))

  local filtered_input = nil

  if self.filter_type == 'lowpass' then
    filtered_input = self.Filter2Out
  elseif self.filter_type == 'highpass' then
    -- Highpass filter by subtracting lowpass output from the input
    filtered_input = input - self.Filter2Out
  else
    -- Default to highpass if filter_type is invalid
    filtered_input = input - self.Filter2Out
  end

  -- Step 2: Peak detector
  local EnvIn = math.abs(filtered_input)
  if EnvIn > self.PeakEnv then
    self.PeakEnv = EnvIn -- Attack time = 0
  else
    self.PeakEnv = self.PeakEnv * self.BeatRelease
    self.PeakEnv = self.PeakEnv + (1.0 - self.BeatRelease) * EnvIn
  end

  -- Step 3: Schmitt trigger
  if self.BeatTrigger == false then
    if self.PeakEnv > self.trigger_on then self.BeatTrigger = true end
  else
    if self.PeakEnv < self.trigger_off then self.BeatTrigger = false end
  end

  -- Step 4: Rising edge detector
  self.BeatPulse = false
  if self.BeatTrigger == true and self.PrevBeatPulse == false then
    self.BeatPulse = true
  end
  self.PrevBeatPulse = self.BeatTrigger
  return self.BeatPulse, self.PeakEnv
end

-- Analyze the sample and insert slice markers
function AnalyzeSample(detection_mode)
  local instrument = renoise.song().selected_instrument
  local sample = renoise.song().selected_sample

  -- Error handling
  if sample == nil then
    renoise.app():show_error('ERROR !!!\nThere is no sample.')
    return
  end

  -- Prompt if sample is already sliced
  if sample.is_slice_alias or #sample.slice_markers > 0 then
    local choice = renoise.app():show_prompt("Sample is already sliced", "Oh no, there's already a sliced sample there, do you want to wipe the slices?", {"Yes", "No"})
    if choice == "Yes" then
      DeleteSliceMarkers()
    else
      return
    end
  end

  -- Show status message if there are multiple samples
  if #instrument.samples > 1 then
    renoise.app():show_status("This instrument must only have one sample, otherwise this won't work.")
    -- Proceed with the first sample
    sample = instrument.samples[1]
  end

  local buffer = sample.sample_buffer

  -- Parameters for detectors
  local lowpass_freq = vbs.lowpass_freq_slider.value
  local rtime_low = vbs.rtime_low_slider.value
  local peak_on_low = vbs.peak_on_low_slider.value
  local peak_off_low = vbs.peak_off_low_slider.value

  local highpass_freq = vbs.highpass_freq_slider.value
  local rtime_high = vbs.rtime_high_slider.value
  local peak_on_high = vbs.peak_on_high_slider.value
  local peak_off_high = vbs.peak_off_high_slider.value

  local min_slice_distance_ms = vbs.min_slice_distance_slider.value
  local zero_crossing_sensitivity = vbs.zero_crossing_slider.value

  local sample_rate = buffer.sample_rate
  local min_slice_distance_samples = math.floor((min_slice_distance_ms / 1000) * sample_rate)
  local zero_crossing_threshold = zero_crossing_sensitivity / 100 -- Convert percentage to amplitude threshold
  local search_range_samples = math.floor((10 / 1000) * sample_rate) -- Search range of +/-10ms

  -- Create BeatDetector instances as needed
  local det_low = nil
  local det_high = nil

  if detection_mode == 'lowpass' or detection_mode == 'combined' then
    det_low = BeatDetector(lowpass_freq, rtime_low, peak_on_low, peak_off_low, 'lowpass')
    det_low:setSampleRate(sample_rate)
  end

  if detection_mode == 'highpass' or detection_mode == 'combined' then
    det_high = BeatDetector(highpass_freq, rtime_high, peak_on_high, peak_off_high, 'highpass')
    det_high:setSampleRate(sample_rate)
  end

  -- Collect detected positions
  local detected_positions = {}

  for i = 1, buffer.number_of_frames do
    local input = buffer:sample_data(1, i)
    local beat_detected = false

    if det_low then
      local beat_low, _ = det_low:Process(input)
      if beat_low == true then
        beat_detected = true
      end
    end

    if det_high then
      local beat_high, _ = det_high:Process(input)
      if beat_high == true then
        beat_detected = true
      end
    end

    if beat_detected then
      table.insert(detected_positions, i)
    end
  end

  -- Sort and filter positions to ensure minimum slice distance
  table.sort(detected_positions)
  local filtered_positions = {}
  local last_position = nil

  for _, pos in ipairs(detected_positions) do
    if not last_position or (pos - last_position) >= min_slice_distance_samples then
      -- Find zero-crossing position
      local zero_crossing_pos = find_zero_crossing(buffer, pos, search_range_samples, zero_crossing_threshold)
      table.insert(filtered_positions, zero_crossing_pos)
      last_position = zero_crossing_pos
    end
  end

  -- Insert slice markers
  for _, pos in ipairs(filtered_positions) do
    if #sample.slice_markers < 255 then
      sample:insert_slice_marker(pos)
    else
      renoise.app():show_error('ERROR !!!\nToo many slices with current settings.\nAdjust the values.')
      break
    end
  end
end

-- Headless mode function (Combined detection)
function BeatSlicerDetect()
  -- Set default values
  vbs.lowpass_freq_slider.value = 150
  vbs.rtime_low_slider.value = 0.0200
  vbs.peak_on_low_slider.value = 0.12
  vbs.peak_off_low_slider.value = 0.005

  vbs.highpass_freq_slider.value = 3000
  vbs.rtime_high_slider.value = 0.0200
  vbs.peak_on_high_slider.value = 0.12
  vbs.peak_off_high_slider.value = 0.005

  vbs.min_slice_distance_slider.value = 50 -- Default minimum slice distance in milliseconds
  vbs.zero_crossing_slider.value = 1 -- Default zero-crossing sensitivity (%)

  AnalyzeSample('combined')
  renoise.app():show_status("Beat detection (combined) completed.")
end

-- GUI Creation
function Row(idx, text, _min, _max, _default, unit, format_func)
  local function default_format(value)
    return string.format("%.3f %s", value, unit)
  end
  format_func = format_func or default_format

  local gui = vb:horizontal_aligner{
    mode='left',
    width='100%',
    vb:text{text=text, width=150},
    vb:slider{
      id=idx..'_slider',
      width=400,
      min=_min,
      max=_max,
      value=_default,
      notifier=function(value)
        vbs[idx..'_label'].text=format_func(value)
      end
    },
    vb:text{
      id=idx..'_label',
      width=100,
      text=format_func(_default)
    },
  }
  return gui
end

makeBeatDetector_gui = vb:column{
  style='invisible',
  spacing=4,
  margin=4,
  width=800,
  vb:column{
    style='panel',
    spacing=4,
    margin=4,
    width='100%',
    vb:horizontal_aligner{
      mode='left',
      vb:text{text='Lowpass Detector Settings', font='bold', style='strong'},
    },
    Row('lowpass_freq', 'Lowpass Freq', 1, 800, 150, 'Hz'),
    Row('rtime_low', 'Release Time', 0.001, 0.05, 0.0200, 'ms', function(value)
      return string.format("%.1f %s", value * 1000, 'ms')
    end),
    Row('peak_on_low', 'Trigger On', 0.001, 0.2, 0.12, ''),
    Row('peak_off_low', 'Trigger Off', 0.001, 0.1, 0.005, ''),
  },
  vb:column{
    style='panel',
    spacing=4,
    margin=4,
    width='100%',
    vb:horizontal_aligner{
      mode='left',
      vb:text{text='Highpass Detector Settings', font='bold', style='strong'},
    },
    Row('highpass_freq', 'Highpass Freq', 1, 8000, 3000, 'Hz'),
    Row('rtime_high', 'Release Time', 0.001, 0.05, 0.0200, 'ms', function(value)
      return string.format("%.1f %s", value * 1000, 'ms')
    end),
    Row('peak_on_high', 'Trigger On', 0.001, 0.2, 0.12, ''),
    Row('peak_off_high', 'Trigger Off', 0.001, 0.1, 0.005, ''),
  },
  vb:column{
    style='panel',
    spacing=4,
    margin=4,
    width='100%',
    vb:horizontal_aligner{
      mode='left',
      vb:text{text='General Settings', font='bold', style='strong'},
    },
    Row('min_slice_distance', 'Min Slice ms', 1, 500, 50, 'ms', function(value)
      return string.format("%d %s", value, 'ms')
    end),
    Row('zero_crossing', 'Zero Cross %', 0.1, 10, 1, '%', function(value)
      return string.format("%.1f %s", value, '%')
    end),
  },
  vb:horizontal_aligner{
    mode='left',
    width='100%',
    vb:button{
      text='Detect Lowpass',
      width='33%',
      notifier=function()
        AnalyzeSample('lowpass')
      end
    },
    vb:button{
      text='Detect Highpass',
      width='33%',
      notifier=function()
        AnalyzeSample('highpass')
      end
    },
    vb:button{
      text='Detect Combined',
      width='34%',
      notifier=function()
        AnalyzeSample('combined')
      end
    },
  },
}

-- Prepare and show dialog
function prepare_for_start()
  if dialog and dialog.visible then
    dialog:show()
    return
  else
    dialog = renoise.app():show_custom_dialog('BeatDetector Modified v0.354', makeBeatDetector_gui, my_keyhandler_func)
  end
end

renoise.tool():add_menu_entry{name='Sample Editor:Paketti..:Experimental/WIP..:BeatDetector Modified...',invoke=function() prepare_for_start() end }
renoise.tool():add_menu_entry{name='Sample Editor:Paketti..:Experimental/WIP..:BeatDetector Modified (Headless Mode)',invoke=function() BeatSlicerDetect() end }
renoise.tool():add_menu_entry{name='Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:BeatDetector Modified...',invoke=function() prepare_for_start() end }
renoise.tool():add_keybinding{name='Global:Paketti:BeatDetector Modified...',invoke=function() prepare_for_start() end }
