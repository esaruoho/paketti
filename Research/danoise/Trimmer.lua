--[[

Trim content of sample

@param instr: renoise.Instrument
@param s_idx: (int) sample index
@param mode: (string) 
"loop" - match the loop start/end marker
"selection" - match the selection 
"custom" - provide custom start/end points

]]


function trim_sample(instr,s_idx,mode)

  local s = instr.samples[s_idx]
  if not s then
    print("Could not locate sample")
    return 
  end
  
  local sbuf = s.sample_buffer
  if not sbuf.has_sample_data then
    print(instr.name,s.name,"Skipped empty sample")
    return
  end  
  if sbuf.read_only then
    print(instr.name,s.name,"Sample is read-only (sliced?)")
    return
  end
  
  local trim_start, trim_end
  if (mode == "loop") then
    if (s.loop_mode == renoise.Sample.LOOP_MODE_OFF) then
      print(instr.name,s.name,"No loop defined in sample")
      return
    end
    trim_start = s.loop_start-1
    trim_end = s.loop_end-1
  elseif (mode == "selection") then
    if (s.loop_mode == renoise.Sample.LOOP_MODE_OFF) then
      print(instr.name,s.name,"No selection defined in sample")
      return
    end
    trim_start = sbuf.selection_start-1
    trim_end = sbuf.selection_end-1
  else
    print("Unsupported 'mode'")
    return
  end
 
  --print("trimming instrument:sample ",instr.name,s.name)
     
  -- create a new sample (duplicate) 
  --print("creating temporary sample at index",s_idx)
  local s_new = instr:insert_sample_at(s_idx)
  local sbuf_new = s_new.sample_buffer
  
  s_new:copy_from(s)

  --sbuf_new:prepare_sample_data_changes()
    
  local s_rate = sbuf.sample_rate
  local b_depth = sbuf.bit_depth
  local num_channels = sbuf.number_of_channels
  local num_frames = 1 + trim_end - trim_start
  sbuf_new:create_sample_data(s_rate,b_depth,num_channels,num_frames)
  
  for chan_idx = 1, sbuf.number_of_channels do
    for frame_idx = 1,num_frames do
      sbuf_new:set_sample_data(chan_idx,frame_idx,
        sbuf:sample_data(chan_idx,frame_idx + trim_start))
    end
  end
  
  --sbuf_new:finalize_sample_data_changes()
  
  -- if loop mode, update loop markers
  if (mode == "loop") then
    s_new.loop_start = 1
    s_new.loop_end = num_frames
  end
  
  -- remove original sample
  --print("deleting temporary sample at index",s_idx+1)
  instr:delete_sample_at(s_idx+1)
  
  
end


local trim_samples_in_instr = function(instr,mode)
  if instr then
    for s_idx,s in ipairs(instr.samples) do
      trim_sample(instr,s_idx,mode)
    end
  end
end


------------------------------------------------------
-- RUN THE SCRIPT
------------------------------------------------------

-- set the scope
-- "selection": run on selected instrument/sample
-- "instrument": all samples in selected instrument
-- "range": all instruments/samples in range
local scope = "instrument"
local range_start = 0x61
local range_end = 0xff

-- set the mode (loop,selection)
local trim_mode = "loop"

if (scope == "selected") then
  local instr = renoise.song().selected_instrument
  local s_idx = renoise.song().selected_sample_index
  trim_sample(instr,s_idx,trim_mode)
elseif (scope == "instrument") then
  local instr = renoise.song().selected_instrument
  trim_samples_in_instr(instr,trim_mode)
elseif (scope == "range") then
  for idx = range_start,range_end do
    instr = renoise.song().instruments[idx]
    trim_samples_in_instr(instr,trim_mode)
  end
end  


