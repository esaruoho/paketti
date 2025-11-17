-- PakettiWavCueExtract.lua
-- Extract CUE markers from WAV files and apply them as slice markers in Renoise

-- Helper function: read 16-bit little-endian unsigned integer
function PakettiWavCueU16LE(str, pos)
  local b1, b2 = str:byte(pos, pos+1)
  return b1 + b2 * 256
end

-- Helper function: read 32-bit little-endian unsigned integer
function PakettiWavCueU32LE(str, pos)
  local b1, b2, b3, b4 = str:byte(pos, pos+3)
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

-- Parse WAV file and extract cue markers
-- Returns: table with sample_rate, cues array, and labels_by_id map
function PakettiWavCueParseWavCues(path)
  local f, err = io.open(path, "rb")
  if not f then
    return nil, "could not open file: " .. (err or "")
  end

  local header = f:read(12)
  if not header or #header < 12 then
    f:close()
    return nil, "file too small"
  end

  if header:sub(1,4) ~= "RIFF" or header:sub(9,12) ~= "WAVE" then
    f:close()
    return nil, "not a RIFF/WAVE file"
  end

  local sample_rate = nil
  local cues = {}
  local labels_by_id = {}
  
  print("PakettiWavCueExtract: Parsing WAV chunks:")

  while true do
    local chunk_header = f:read(8)
    if not chunk_header or #chunk_header < 8 then
      print("  End of file or incomplete chunk header")
      break
    end

    local chunk_id  = chunk_header:sub(1,4)
    local chunk_len = PakettiWavCueU32LE(chunk_header, 5)
    
    -- Debug: show hex bytes of chunk ID
    local hex_bytes = ""
    for i = 1, 4 do
      hex_bytes = hex_bytes .. string.format("%02X ", chunk_header:byte(i))
    end
    
    print(string.format("  Found chunk '%s' [%s] (size: %d bytes)", chunk_id, hex_bytes, chunk_len))

    local skip_padding_check = false

    if chunk_id == "fmt " then
      local data = f:read(chunk_len)
      if data and #data >= 12 then
        -- wFormatTag (2), nChannels (2), nSamplesPerSec (4)
        local fmt_tag      = PakettiWavCueU16LE(data, 1)
        local num_channels = PakettiWavCueU16LE(data, 3)
        local sr           = PakettiWavCueU32LE(data, 5)
        sample_rate = sr
      end
      
    elseif chunk_id == "data" then
      -- Skip the data chunk (don't read it into memory, just seek past it)
      print("    Skipping data chunk content (seeking past " .. chunk_len .. " bytes)")
      f:seek("cur", chunk_len)
      -- Handle padding here explicitly
      if (chunk_len % 2) == 1 then
        f:seek("cur", 1)
        print("    Data chunk has odd size, skipping padding byte")
      end
      -- Skip the padding check at the end of the loop (we handled it here)
      skip_padding_check = true

    elseif chunk_id == "cue " then
      print(string.format("  Processing cue chunk (size: %d)", chunk_len))
      local data = f:read(chunk_len)
      if data and #data >= 4 then
        local num_cues = PakettiWavCueU32LE(data, 1)
        print(string.format("    Number of cue points in chunk: %d", num_cues))
        local off = 5
        for i = 1, num_cues do
          if off + 23 > #data then 
            print(string.format("    Warning: Not enough data for cue point %d (need %d bytes, have %d)", i, off + 24, #data))
            break 
          end
          local cue_id        = PakettiWavCueU32LE(data, off + 0)
          local dwPosition    = PakettiWavCueU32LE(data, off + 4)
          local fccChunk      = data:sub(off + 8, off + 11) -- usually "data"
          local dwChunkStart  = PakettiWavCueU32LE(data, off + 12)
          local dwBlockStart  = PakettiWavCueU32LE(data, off + 16)
          local sample_offset = PakettiWavCueU32LE(data, off + 20)

          print(string.format("    Cue %d: id=%d, offset=%d", i, cue_id, sample_offset))

          table.insert(cues, {
            id     = cue_id,
            offset = sample_offset
          })

          off = off + 24
        end
        print(string.format("    Successfully parsed %d cue points", #cues))
      else
        print("    Error: Cue chunk data too small or failed to read")
      end

    elseif chunk_id == "LIST" then
      -- Could contain "adtl" with 'labl' / 'note' subchunks
      local data = f:read(chunk_len)
      if data and #data >= 4 then
        local list_type = data:sub(1,4)
        if list_type == "adtl" then
          local pos = 5
          while pos + 8 <= #data do
            local sub_id   = data:sub(pos, pos+3)
            local sub_size = PakettiWavCueU32LE(data, pos+4)
            pos = pos + 8
            if pos + sub_size - 1 > #data then break end

            if sub_id == "labl" or sub_id == "note" then
              if sub_size >= 4 then
                local cue_id = PakettiWavCueU32LE(data, pos)
                local text   = data:sub(pos+4, pos+sub_size-1)
                text = text:gsub("%z+$", "") -- strip trailing NULs
                labels_by_id[cue_id] = text
              end
            end

            pos = pos + sub_size
            if (sub_size % 2) == 1 then
              pos = pos + 1 -- pad byte inside LIST
            end
          end
        end
      end

    else
      -- Skip this chunk
      print(string.format("    Skipping unknown chunk '%s'", chunk_id))
      f:seek("cur", chunk_len)
    end

    -- padding to even byte boundary for every chunk (unless already handled)
    if not skip_padding_check and (chunk_len % 2) == 1 then
      f:seek("cur", 1)
    end
  end

  f:close()

  print(string.format("PakettiWavCueExtract: Finished parsing. Found %d cue points total", #cues))

  if not sample_rate then
    return nil, "no fmt chunk / sample rate not found"
  end

  table.sort(cues, function(a,b) return a.offset < b.offset end)

  return {
    sample_rate  = sample_rate,
    cues         = cues,
    labels_by_id = labels_by_id
  }
end

-- Convert sample offset to mm:ss:ff format (75 frames per second for CD)
function PakettiWavCueSamplesToMSF(samples, sample_rate)
  local total_seconds = samples / sample_rate
  local minutes = math.floor(total_seconds / 60)
  local seconds = math.floor(total_seconds - minutes * 60)
  local frac    = total_seconds - (minutes * 60 + seconds)
  local frames  = math.floor(frac * 75 + 0.5)

  -- Normalise in case we rounded up to 75
  if frames >= 75 then
    frames = frames - 75
    seconds = seconds + 1
    if seconds >= 60 then
      seconds = 0
      minutes = minutes + 1
    end
  end

  return minutes, seconds, frames
end

-- Write .cue file next to the WAV file
-- Returns: cue_path on success, or nil + error message
function PakettiWavCueWriteCueFile(wav_path, info)
  local cues         = info.cues
  local sample_rate  = info.sample_rate
  local labels_by_id = info.labels_by_id or {}

  if not cues or #cues == 0 then
    return nil, "no cues to write"
  end

  -- derive .cue path
  local cue_path = wav_path:gsub("%.[Ww][Aa][Vv]$", ".cue")
  if cue_path == wav_path then
    cue_path = wav_path .. ".cue"
  end

  -- Check if .cue file already exists - don't overwrite
  local existing_file = io.open(cue_path, "r")
  if existing_file then
    existing_file:close()
    print("PakettiWavCueExtract: .cue file already exists, skipping: " .. cue_path)
    return cue_path  -- Return the path but don't overwrite
  end

  local f, err = io.open(cue_path, "w")
  if not f then
    return nil, "cannot create cue file: " .. (err or "")
  end

  -- just the base file name in FILE line
  local fname = wav_path:match("([^/\\]+)$") or wav_path

  f:write(string.format('FILE "%s" WAVE\n', fname))

  for i, cp in ipairs(cues) do
    local mm, ss, ff = PakettiWavCueSamplesToMSF(cp.offset, sample_rate)
    local title = labels_by_id[cp.id] or ("Marker " .. i)

    f:write(string.format("\n  TRACK %02d AUDIO\n", i))
    f:write(string.format('    TITLE "%s"\n', title:gsub('"','\\"')))
    f:write(string.format("    INDEX 01 %02d:%02d:%02d\n", mm, ss, ff))
  end

  f:close()
  return cue_path
end

-- Import WAV file with cue markers into a sample
function PakettiWavCueImportWavWithCuesIntoSample(sample, wav_path)
  print("========================================")
  print("PakettiWavCueExtract: Starting WAV CUE extraction")
  print("File: " .. wav_path)
  print("========================================")
  
  -- 1) Parse cues (before Renoise touches the file)
  local info, err = PakettiWavCueParseWavCues(wav_path)
  if not info then
    -- no cues or parsing failed; just load the file normally
    print("PakettiWavCueExtract: parse_wav_cues: " .. (err or "unknown error"))
    sample.sample_buffer:load_from(wav_path)
    renoise.app():show_status("Loaded WAV (no cue markers found)")
    return
  end

  -- Display detailed header information
  print("")
  print("WAV HEADER INFORMATION:")
  print("  Sample Rate: " .. info.sample_rate .. " Hz")
  print("  Number of Cue Points: " .. #info.cues)
  print("")
  
  -- Display all cue points with their details
  print("CUE POINTS EXTRACTED:")
  for i, cp in ipairs(info.cues) do
    local label = info.labels_by_id[cp.id] or ("Marker " .. i)
    local time_seconds = cp.offset / info.sample_rate
    print(string.format("  [%02d] ID:%d  Offset:%d samples  Time:%.3fs  Label:'%s'", 
      i, cp.id, cp.offset, time_seconds, label))
  end
  print("")

  -- 2) Write .cue file (if it doesn't exist)
  local cue_path, cue_err = PakettiWavCueWriteCueFile(wav_path, info)
  if cue_path then
    print("CUE FILE OUTPUT:")
    print("  Wrote cue file: " .. cue_path)
  else
    print("CUE FILE ERROR:")
    print("  write_cue_file failed: " .. (cue_err or "unknown error"))
  end
  print("")

  -- 3) Load WAV into Renoise
  print("LOADING WAV INTO RENOISE:")
  sample.sample_buffer:load_from(wav_path)
  
  -- Extract filename without path and extension for naming
  local filename = wav_path:match("([^/\\]+)$") or wav_path
  local name_without_ext = filename:gsub("%.[Ww][Aa][Vv]$", "")
  
  -- Set sample name immediately after loading (before slicing)
  sample.name = name_without_ext
  
  print("  WAV loaded successfully")
  print("  Sample name set to: " .. name_without_ext)
  print("")

  -- 4) Add slice markers from cue offsets
  local buf = sample.sample_buffer
  if not buf.has_sample_data then
    print("ERROR: Sample buffer has no data after load")
    return
  end

  local frames = buf.number_of_frames
  print("SAMPLE BUFFER INFO:")
  print("  Total frames: " .. frames)
  print("  Sample rate: " .. buf.sample_rate .. " Hz")
  print("  Channels: " .. buf.number_of_channels)
  print("")
  
  local markers_added = 0

  -- Always insert first slice marker at frame 1
  print("INSERTING SLICE MARKERS:")
  sample:insert_slice_marker(1)
  print("  [01] Inserted at frame 1 (forced first marker)")
  markers_added = 1

  -- Then insert all cue markers (skip 0 and 1 to avoid duplicates)
  for i, cp in ipairs(info.cues) do
    local pos = cp.offset
    local label = info.labels_by_id[cp.id] or ("Marker " .. i)

    -- Skip marker at 0 or 1 (already set), and ensure position is within bounds
    if pos > 1 and pos < frames then
      sample:insert_slice_marker(pos)
      markers_added = markers_added + 1
      print(string.format("  [%02d] Inserted at frame %d - '%s'", markers_added, pos, label))
    elseif pos == 0 or pos == 1 then
      print(string.format("  [--] Skipped cue at frame %d (duplicate) - '%s'", pos, label))
    elseif pos >= frames then
      print(string.format("  [--] Skipped cue at frame %d (out of bounds) - '%s'", pos, label))
    end
  end
  
  print("")
  
  -- Apply Paketti loader settings to the main sample
  if preferences then
    print("APPLYING PAKETTI LOADER SETTINGS:")
    sample.autofade = preferences.pakettiLoaderAutofade.value
    sample.autoseek = preferences.pakettiLoaderAutoseek.value
    sample.loop_mode = preferences.pakettiLoaderLoopMode.value
    sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
    sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
    sample.oneshot = preferences.pakettiLoaderOneshot.value
    sample.new_note_action = preferences.pakettiLoaderNNA.value
    sample.loop_release = preferences.pakettiLoaderLoopExit.value
    print("  Applied Paketti loader settings to main sample")
    
    -- Apply settings to all slice samples
    if #sample.slice_markers > 0 then
      local song = renoise.song()
      local current_instrument = song.selected_instrument
      print("  Applying Paketti loader settings to " .. #sample.slice_markers .. " slice samples")
      for i = 1, #sample.slice_markers do
        local slice_sample = current_instrument.samples[i + 1]
        if slice_sample then
          slice_sample.autofade = preferences.pakettiLoaderAutofade.value
          slice_sample.autoseek = preferences.pakettiLoaderAutoseek.value
          slice_sample.loop_mode = preferences.pakettiLoaderLoopMode.value
          slice_sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
          slice_sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
          slice_sample.oneshot = preferences.pakettiLoaderOneshot.value
          slice_sample.new_note_action = preferences.pakettiLoaderNNA.value
          slice_sample.loop_release = preferences.pakettiLoaderLoopExit.value
        end
      end
      print("  Applied Paketti loader settings to all slice samples")
    end
  end
  
  print("")
  
  -- Set instrument name at the very end (after all processing is done)
  local song = renoise.song()
  song.selected_instrument.name = name_without_ext
  print("FINAL NAMING:")
  print("  Instrument name set to: " .. name_without_ext)
  
  print("")
  print("========================================")
  print(string.format("SUMMARY: Inserted %d slice markers total", markers_added))
  print("========================================")
  renoise.app():show_status(string.format("Loaded WAV with %d cue markers applied", markers_added))
end

--------------------------------------------------------------------------------
-- EXPORT FUNCTIONS
--------------------------------------------------------------------------------

-- Helper: Write 16-bit little-endian unsigned integer
function PakettiWavCueWriteU16LE(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  return string.char(b1, b2)
end

-- Helper: Write 32-bit little-endian unsigned integer
function PakettiWavCueWriteU32LE(value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

-- Build cue chunk binary data from slice markers
function PakettiWavCueBuildCueChunk(slice_markers, sample_rate)
  if not slice_markers or #slice_markers == 0 then
    return nil
  end
  
  -- Number of cue points (including the implicit one at position 1)
  local num_cues = #slice_markers + 1
  
  -- Build the cue data (without chunk header)
  local cue_data = ""
  
  -- Number of cue points
  cue_data = cue_data .. PakettiWavCueWriteU32LE(num_cues)
  
  -- First cue point at position 1
  cue_data = cue_data .. PakettiWavCueWriteU32LE(0)  -- cue ID
  cue_data = cue_data .. PakettiWavCueWriteU32LE(0)  -- dwPosition
  cue_data = cue_data .. "data"                       -- fccChunk
  cue_data = cue_data .. PakettiWavCueWriteU32LE(0)  -- dwChunkStart
  cue_data = cue_data .. PakettiWavCueWriteU32LE(0)  -- dwBlockStart
  cue_data = cue_data .. PakettiWavCueWriteU32LE(1)  -- dwSampleOffset (position 1)
  
  print(string.format("  Building cue point 0: offset=1"))
  
  -- Write all slice markers
  for i, marker in ipairs(slice_markers) do
    cue_data = cue_data .. PakettiWavCueWriteU32LE(i)         -- cue ID
    cue_data = cue_data .. PakettiWavCueWriteU32LE(0)          -- dwPosition
    cue_data = cue_data .. "data"                               -- fccChunk
    cue_data = cue_data .. PakettiWavCueWriteU32LE(0)          -- dwChunkStart
    cue_data = cue_data .. PakettiWavCueWriteU32LE(0)          -- dwBlockStart
    cue_data = cue_data .. PakettiWavCueWriteU32LE(marker)     -- dwSampleOffset
    print(string.format("  Building cue point %d: offset=%d", i, marker))
  end
  
  -- Chunk size is the size of the data (not including the chunk ID and size fields)
  local chunk_size = #cue_data
  
  -- Build complete chunk with header
  local chunk = "cue " .. PakettiWavCueWriteU32LE(chunk_size) .. cue_data
  
  -- Add padding byte if data size is odd (to maintain word alignment)
  if (chunk_size % 2) == 1 then
    chunk = chunk .. string.char(0)
    print("  Added padding byte to cue chunk")
  end
  
  print(string.format("  Cue chunk size: %d bytes (data) + 8 bytes (header) = %d bytes total", chunk_size, #chunk))
  
  return chunk
end

-- Build LIST/adtl chunk with labels for slice markers
function PakettiWavCueBuildAdtlChunk(sample_name, slice_markers)
  if not slice_markers or #slice_markers == 0 then
    return nil
  end
  
  local labels_data = ""
  local num_cues = #slice_markers + 1
  
  -- First label for position 1
  local label_text = sample_name or "Slice 00"
  local label_chunk = "labl"
  local label_size = 4 + #label_text + 1  -- cue_id + text + null terminator
  label_chunk = label_chunk .. PakettiWavCueWriteU32LE(label_size)
  label_chunk = label_chunk .. PakettiWavCueWriteU32LE(0)  -- cue ID
  label_chunk = label_chunk .. label_text .. string.char(0)
  -- Pad to even byte boundary
  if (label_size % 2) == 1 then
    label_chunk = label_chunk .. string.char(0)
  end
  labels_data = labels_data .. label_chunk
  
  -- Labels for each slice marker
  for i, marker in ipairs(slice_markers) do
    label_text = string.format("Slice %02d", i)
    label_chunk = "labl"
    label_size = 4 + #label_text + 1
    label_chunk = label_chunk .. PakettiWavCueWriteU32LE(label_size)
    label_chunk = label_chunk .. PakettiWavCueWriteU32LE(i)  -- cue ID
    label_chunk = label_chunk .. label_text .. string.char(0)
    -- Pad to even byte boundary
    if (label_size % 2) == 1 then
      label_chunk = label_chunk .. string.char(0)
    end
    labels_data = labels_data .. label_chunk
  end
  
  -- Build LIST chunk wrapper
  local list_chunk = "LIST"
  local list_size = 4 + #labels_data  -- "adtl" + all label chunks
  list_chunk = list_chunk .. PakettiWavCueWriteU32LE(list_size)
  list_chunk = list_chunk .. "adtl"
  list_chunk = list_chunk .. labels_data
  
  -- Pad to even byte boundary
  if (list_size % 2) == 1 then
    list_chunk = list_chunk .. string.char(0)
  end
  
  return list_chunk
end

-- Write cue chunks into an existing WAV file
function PakettiWavCueWriteCueChunksToWav(wav_path, slice_markers, sample_rate, sample_name)
  -- Read the entire WAV file
  local f, err = io.open(wav_path, "rb")
  if not f then
    return false, "Could not open WAV file: " .. (err or "")
  end
  
  local wav_data = f:read("*all")
  f:close()
  
  if #wav_data < 44 then
    return false, "WAV file too small"
  end
  
  -- Verify RIFF/WAVE header
  if wav_data:sub(1,4) ~= "RIFF" or wav_data:sub(9,12) ~= "WAVE" then
    return false, "Not a valid RIFF/WAVE file"
  end
  
  -- Build cue chunk
  local cue_chunk = PakettiWavCueBuildCueChunk(slice_markers, sample_rate)
  if not cue_chunk then
    return false, "Failed to build cue chunk"
  end
  
  -- Build adtl chunk
  local adtl_chunk = PakettiWavCueBuildAdtlChunk(sample_name, slice_markers)
  
  -- Find the end of the data chunk to insert our chunks after it
  local pos = 13  -- Start after "RIFF" header (bytes 1-12: RIFF + size + WAVE)
  local insert_pos = #wav_data  -- Default: append at end
  
  print("  Scanning WAV file for chunks:")
  print(string.format("    WAV file total size: %d bytes", #wav_data))
  
  while pos < #wav_data - 8 do
    local chunk_id = wav_data:sub(pos, pos+3)
    local chunk_size = PakettiWavCueU32LE(wav_data, pos+4)
    
    print(string.format("    Found chunk '%s' at pos %d, size %d", chunk_id, pos, chunk_size))
    
    if chunk_id == "data" then
      -- Found data chunk - insert after it
      insert_pos = pos + 8 + chunk_size
      if (chunk_size % 2) == 1 then
        insert_pos = insert_pos + 1  -- Account for padding
        print(string.format("    Data chunk has odd size, adding padding byte"))
      end
      print(string.format("    Will insert cue chunks at position %d", insert_pos))
      break
    end
    
    pos = pos + 8 + chunk_size
    if (chunk_size % 2) == 1 then
      pos = pos + 1  -- Account for padding
    end
  end
  
  -- Build new WAV file with cue chunks inserted
  print(string.format("  Building new WAV file:"))
  print(string.format("    Original data up to insert point (excluding): %d bytes", insert_pos - 1))
  print(string.format("    Cue chunk size: %d bytes", #cue_chunk))
  if adtl_chunk then
    print(string.format("    ADTL chunk size: %d bytes", #adtl_chunk))
  end
  print(string.format("    Discarding %d bytes after insert point (old trailing data)", #wav_data - insert_pos + 1))
  
  -- Build new file: original data + our cue chunks (discard any old trailing data)
  -- Use insert_pos - 1 because insert_pos is the position AFTER the last byte we want
  local new_wav = wav_data:sub(1, insert_pos - 1)
  new_wav = new_wav .. cue_chunk
  if adtl_chunk then
    new_wav = new_wav .. adtl_chunk
  end
  -- DO NOT append old trailing data: new_wav = new_wav .. wav_data:sub(insert_pos + 1)
  
  print(string.format("    New WAV file total size: %d bytes (was %d bytes)", #new_wav, #wav_data))
  
  -- Update RIFF chunk size (file size - 8)
  local old_riff_size = PakettiWavCueU32LE(wav_data, 5)
  local new_size = #new_wav - 8
  local size_bytes = PakettiWavCueWriteU32LE(new_size)
  new_wav = new_wav:sub(1, 4) .. size_bytes .. new_wav:sub(9)
  
  print(string.format("    Updated RIFF size from %d to %d", old_riff_size, new_size))
  
  -- Write the modified WAV file
  f, err = io.open(wav_path, "wb")
  if not f then
    return false, "Could not write WAV file: " .. (err or "")
  end
  
  f:write(new_wav)
  f:close()
  
  print(string.format("    Successfully wrote %d bytes to disk", #new_wav))
  
  return true
end

-- Export sample with slice markers to WAV + CUE files
function PakettiWavCueExportSampleWithCues(include_cue_header)
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data to export")
    return
  end
  
  -- Get slice markers
  local slice_markers = {}
  for i = 1, #sample.slice_markers do
    table.insert(slice_markers, sample.slice_markers[i])
  end
  
  if #slice_markers == 0 then
    renoise.app():show_status("Sample has no slice markers")
    return
  end
  
  -- Prompt for save location
  local default_name = sample.name:gsub("[^%w%s%-_]", "_") .. ".wav"
  local wav_path = renoise.app():prompt_for_filename_to_write("wav", "Export WAV with CUE markers")
  
  if not wav_path or wav_path == "" then
    return
  end
  
  print("========================================")
  print("PakettiWavCueExtract: Exporting WAV with CUE markers")
  print("========================================")
  print("Sample: " .. sample.name)
  print("Slice markers: " .. #slice_markers)
  print("")
  
  -- Save WAV file using Renoise API
  local success, error_msg = sample.sample_buffer:save_as(wav_path, "wav")
  if not success then
    renoise.app():show_status("Failed to save WAV file: " .. (error_msg or "unknown error"))
    return
  end
  
  print("WAV FILE SAVED:")
  print("  Path: " .. wav_path)
  print("")
  
  -- If requested, write cue chunks into the WAV file
  if include_cue_header then
    local cue_success, cue_err = PakettiWavCueWriteCueChunksToWav(
      wav_path, 
      slice_markers, 
      sample.sample_buffer.sample_rate,
      sample.name
    )
    
    if cue_success then
      print("CUE CHUNKS WRITTEN TO WAV:")
      print("  Added cue chunk with " .. (#slice_markers + 1) .. " markers")
      print("  Added LIST/adtl chunk with labels")
    else
      print("WARNING: Failed to write cue chunks to WAV: " .. (cue_err or "unknown error"))
    end
    print("")
  end
  
  -- Build cue info structure for writing .cue file
  local info = {
    sample_rate = sample.sample_buffer.sample_rate,
    cues = {},
    labels_by_id = {}
  }
  
  -- Add implicit first cue at position 1
  table.insert(info.cues, { id = 0, offset = 1 })
  info.labels_by_id[0] = sample.name
  
  -- Add all slice markers
  for i, marker in ipairs(slice_markers) do
    table.insert(info.cues, { id = i, offset = marker })
    info.labels_by_id[i] = string.format("Slice %02d", i)
  end
  
  -- Write .cue file
  local cue_path, cue_err = PakettiWavCueWriteCueFile(wav_path, info)
  if cue_path then
    print("CUE FILE WRITTEN:")
    print("  Path: " .. cue_path)
  else
    print("ERROR writing .cue file: " .. (cue_err or "unknown error"))
  end
  
  print("")
  print("========================================")
  print("EXPORT COMPLETE")
  print("========================================")
  
  renoise.app():show_status("Exported WAV with " .. #slice_markers .. " cue markers")
end

-- Export with .cue file only (no cue header in WAV)
function PakettiWavCueExportSampleWithCueFile()
  PakettiWavCueExportSampleWithCues(false)
end

-- Export with cue header in WAV + .cue file
function PakettiWavCueExportSampleWithCueHeader()
  PakettiWavCueExportSampleWithCues(true)
end

--------------------------------------------------------------------------------
-- IMPORT FUNCTIONS
--------------------------------------------------------------------------------

-- Helper: Check if an instrument is completely empty (no samples with data)
function PakettiWavCueIsInstrumentEmpty(instrument)
  if #instrument.samples == 0 then
    return true
  end
  
  for i = 1, #instrument.samples do
    local sample = instrument.samples[i]
    if sample.sample_buffer.has_sample_data then
      return false
    end
  end
  
  return true
end

-- Prompt for WAV file and import with cue markers
function PakettiWavCuePromptAndImportWithCues()
  local file = renoise.app():prompt_for_filename_to_read(
    {"*.wav"}, "Select WAV with CUE markers"
  )
  if not file or file == "" then
    return
  end

  local song = renoise.song()
  
  -- Check if we're on instrument 00 (index 1) and if it's empty
  local current_index = song.selected_instrument_index
  local current_instrument = song.selected_instrument
  local use_existing_instrument = false
  
  if current_index == 1 and PakettiWavCueIsInstrumentEmpty(current_instrument) then
    print("PakettiWavCueExtract: Using existing empty instrument 00 instead of creating new instrument")
    use_existing_instrument = true
  else
    -- Create a new instrument
    song:insert_instrument_at(current_index + 1)
    song.selected_instrument_index = current_index + 1
    print("PakettiWavCueExtract: Inserted new instrument at index: " .. song.selected_instrument_index)
  end

  -- Inject the default Paketti instrument configuration if available
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
    if use_existing_instrument then
      print("PakettiWavCueExtract: Injected Paketti default instrument configuration for existing instrument 00")
    else
      print("PakettiWavCueExtract: Injected Paketti default instrument configuration for new instrument")
    end
  else
    print("PakettiWavCueExtract: pakettiPreferencesDefaultInstrumentLoader not found - skipping default configuration")
  end

  local inst = song.selected_instrument
  
  -- Ensure there's at least one sample in the instrument
  if #inst.samples == 0 then
    inst:insert_sample_at(1)
    print("PakettiWavCueExtract: Created first sample slot")
  end
  
  -- Ensure we're working with the first sample slot
  song.selected_sample_index = 1
  local sample = song.selected_sample
  
  PakettiWavCueImportWavWithCuesIntoSample(sample, file)
end

-- Add menu entries and keybindings
renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

renoise.tool():add_menu_entry{
  name = "Main Menu:File:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

renoise.tool():add_menu_entry{
  name = "Sample Navigator:Paketti:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:!Sample Editor:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Load WAV with CUE Markers...",
  invoke = PakettiWavCuePromptAndImportWithCues
}

-- Export menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:File:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_menu_entry{
  name = "Main Menu:File:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

renoise.tool():add_menu_entry{
  name = "Sample Navigator:Paketti:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_menu_entry{
  name = "Sample Navigator:Paketti:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:!Sample Editor:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:!Sample Editor:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Export WAV with CUE File...",
  invoke = PakettiWavCueExportSampleWithCueFile
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Export WAV with Embedded CUE Headers...",
  invoke = PakettiWavCueExportSampleWithCueHeader
}

