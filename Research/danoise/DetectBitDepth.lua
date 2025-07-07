function get_bit_depth(sample)
  
  local function reverse(t)
    local nt = {}
    local size = #t + 1
    for k,v in ipairs(t) do
      nt[size - k] = v
    end
    return nt
  end
  
  local function tobits(num)
    local t = {}
    while num > 0 do
      local rest = num % 2
      t[#t + 1] = rest
      num = (num - rest) / 2
    end
    t = reverse(t)
    return t
  end
  
  -- Vars and crap
  local bit_depth = 0
  local sample_max = math.pow(2, 32) / 2
  local buffer = sample.sample_buffer
  
  -- If we got some sample data to analyze
  if (buffer.has_sample_data) then
  
    local channels = buffer.number_of_channels
    local frames = buffer.number_of_frames
    
    -- For each frame
    for f = 1, frames do
      
      -- For each channel
      for c = 1, channels do
      
        -- Convert float to 32-bit unsigned int
        local s = (1 + buffer:sample_data(c, f)) * sample_max
        
        -- Measure bits used
        local bits = tobits(s)
        for b = 1, #bits do
          if bits[b] == 1 then
            if b > bit_depth then
              bit_depth = b
            end
          end
        end
      end
    end
  end
    
  return bit_depth
end

local bit_depth = get_bit_depth(renoise.song().selected_sample)

print(string.format('Sample appears to be %d-bit!', bit_depth))
