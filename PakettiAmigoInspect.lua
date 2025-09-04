--[[============================================================================
PakettiAmigoInspect.lua

Decode, Export, Import, and Modify Active Plugin Wavefile Pathname within ParameterChunk

This Renoise tool extends the original "Decode Active Plugin ParameterChunk" script
with functions to:
  • extract (export) the embedded WAV file from an Amigo preset
  • import a new WAV back into the active preset data
  • read and display the embedded pathname
  • override that pathname with a new one on disk

Uses macOS `plutil` and a local base64.lua module.

Prerequisites:
  • base64.lua in the same folder
  • macOS `plutil` on your PATH

After installation, restart Renoise and use under the Tools menu:
  • Decode Active Plugin ParameterChunk
  • Export Active Plugin Wavefile
  • Import Active Plugin Wavefile
  • Set Active Plugin Pathname
============================================================================]]--

-- Ensure bit32 is nil so base64 module uses its Lua 5.1 fallback
_G.bit32 = nil

-- Load base64 module
local ok64, base64 = pcall(require, "base64")
if not ok64 then
  renoise.app():show_status("Error loading base64 module: " .. tostring(base64))
  print("Error loading base64 module: " .. tostring(base64))
  return
end

-- Debug-print helper - prints to both console and status bar
function pakettiAmigoDebug(msg, show_in_status)
    print(msg)
    if show_in_status then
        renoise.app():show_status(msg)
    end
end

-- Verify JUCE header structure
function pakettiAmigoVerifyJuceHeader(data)
    -- Check minimum size
    if #data < 8 then
        return false, "Data too small for JUCE header"
    end
    
    -- Check magic
    local magic = data:sub(1, 6)
    if magic ~= "PARAMS" then
        return false, string.format("Invalid magic: %q (expected 'PARAMS')", magic)
    end
    
    -- Check version in little-endian format
    local version_lo = data:byte(7)  -- First byte is low byte
    local version_hi = data:byte(8)  -- Second byte is high byte
    local version = version_lo + version_hi * 256
    
    pakettiAmigoDebug("\nVerifying JUCE header:")
    pakettiAmigoDebug(string.format("  Magic: %s", magic))
    pakettiAmigoDebug(string.format("  Version bytes: 0x%02X 0x%02X", version_lo, version_hi))
    pakettiAmigoDebug(string.format("  Calculated version: %d", version))
    
    -- If version bytes are reversed, swap them and recalculate
    if version ~= 1 and version_hi == 1 and version_lo == 0 then
        pakettiAmigoDebug("  Warning: Version bytes appear to be reversed")
        version = 1  -- Force to version 1 since we know that's what it should be
    end
    
    if version ~= 1 then
        return false, string.format("Unexpected version: %d (bytes: 0x%02X 0x%02X, expected 0x01 0x00)", 
            version, version_lo, version_hi)
    end
    
    -- Verify basic structure by looking for known entries
    local found_entries = {}
    local offset = 9
    while offset < #data do
        if offset + 8 > #data then break end
        local id = data:sub(offset, offset + 7)
        local clean_id = id:match("([%w]+)") -- Extract printable part
        if clean_id then
            table.insert(found_entries, clean_id)
        end
        offset = offset + 8
    end
    
    return true, {
        magic = magic,
        version = version,
        entries = found_entries
    }
end

-- Write raw data to a file
function pakettiAmigoWriteFile(path, data)
    pakettiAmigoDebug("Writing file: " .. path .. " (" .. tostring(#data) .. " bytes)")
    local f, err = io.open(path, "wb")
    if not f then error("Cannot write file '" .. tostring(path) .. "': " .. tostring(err)) end
    f:write(data)
    f:close()
end

-- Convert binary plist to XML via plutil
function pakettiAmigoPlistToXml(bin_data)
    pakettiAmigoDebug("Converting binary plist to XML")
    local tmpbin = pakettiGetTempFilePath(".tmp")
    local f = io.open(tmpbin, "wb")
    if not f then error("Failed to open temp file") end
    f:write(bin_data)
    f:close()
    local tmpxml = tmpbin .. ".xml"
    local ok = os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
    if ok ~= 0 then
        os.remove(tmpbin)
        error("plutil conversion failed")
    end
    local xf = io.open(tmpxml, "rb")
    local xml = xf:read("*a")
    xf:close()
    os.remove(tmpbin)
    os.remove(tmpxml)
    pakettiAmigoDebug("  XML plist length: " .. tostring(#xml))
    return xml
end

-- Extract and decode jucePluginState blob
function pakettiAmigoExtractJuceState(xml_plist)
    pakettiAmigoDebug("Extracting jucePluginState data")
    local pattern = "<key>%s*jucePluginState%s*</key>%s*<data>(.-)</data>"
    local b64 = xml_plist:match(pattern)
    if not b64 then error("jucePluginState <data> not found") end
    pakettiAmigoDebug("  Base64 size: " .. tostring(#b64))
    local state = base64.decode(b64)
    pakettiAmigoDebug("  Decoded state size: " .. tostring(#state))
    return state
end

-- Extract WAV data from state blob
function pakettiAmigoExtractWavFromState(state_blob)
    pakettiAmigoDebug("Locating EMBEDDED_FILE marker")
    local marker = "EMBEDDED_FILE"
    local s, e = state_blob:find(marker, 1, true)
    if not s then
        error("NO_EMBEDDED_SAMPLE") -- Special error code we'll handle in the main function
    end
    pakettiAmigoDebug("  Marker at bytes " .. s .. "–" .. e)

    local valid = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    -- skip to first Base64 char after marker
    local pos = e + 1
    while pos <= #state_blob and not valid:find(state_blob:sub(pos,pos),1,true) do
        pos = pos + 1
    end
    if pos > #state_blob then error("No Base64 payload after marker") end

    local start_b64 = pos
    while pos <= #state_blob and valid:find(state_blob:sub(pos,pos),1,true) do
        pos = pos + 1
    end
    local wav_b64 = state_blob:sub(start_b64, pos-1)
    pakettiAmigoDebug("  WAV Base64 length: " .. tostring(#wav_b64))
    if #wav_b64 == 0 then error("Empty WAV payload") end

    pakettiAmigoDebug("  Decoding WAV payload")
    local wav_data = base64.decode(wav_b64)
    pakettiAmigoDebug("  Decoded WAV size: " .. tostring(#wav_data))
    return wav_data
end

-- Utility: hex dump a portion of data with ASCII representation
function pakettiAmigoHexDump(data, start, length)
    local result = ""
    local ascii  = ""
    for i = start, math.min(start + length - 1, #data) do
        local byte = data:byte(i)
        result = result .. string.format("%02X ", byte)
        if byte >= 32 and byte <= 126 then
            ascii = ascii .. string.char(byte)
        else
            ascii = ascii .. "."
        end
        if (i - start + 1) % 16 == 0 then
            result = result .. " | " .. ascii .. "\n"
            ascii = ""
        end
    end
    if ascii ~= "" then
        while #ascii < 16 do
            result = result .. "   "
            ascii = ascii .. " "
        end
        result = result .. " | " .. ascii .. "\n"
    end
    return result
end

-- Utility: convert bytes to ASCII string if printable
function pakettiAmigoBytesToAscii(data, start, length)
    local result = ""
    for i = start, math.min(start + length - 1, #data) do
        local byte = data:byte(i)
        if byte >= 32 and byte <= 126 then
            result = result .. string.char(byte)
        else
            result = result .. string.format("\\x%02X", byte)
        end
    end
    return result
end

-- Read a little-endian integer from data
function pakettiAmigoReadLeInt(data, offset, size)
  local val = 0
  for i = 0, size - 1 do
    val = val + data:byte(offset + i) * (256 ^ i)  -- Little-endian: lowest byte first
  end
  pakettiAmigoDebug(string.format("Reading %d-byte LE int at offset %d:", size, offset))
  for i = 0, size - 1 do
    pakettiAmigoDebug(string.format("  Byte %d: 0x%02X", i, data:byte(offset + i)))
  end
  pakettiAmigoDebug(string.format("  Value: %d (0x%X)", val, val))
  return val
end

-- Parse JUCE parameter chunk header and content
function pakettiAmigoParseJuceParams(chunk)
  if not chunk or #chunk < 8 then return nil, "Chunk too small" end
  
  local working_chunk = chunk
  
  -- First convert binary plist to XML if needed
  if working_chunk:sub(1,6) == "bplist" then
    print("Debug: Converting binary plist to XML first...")
    local tmpbin = pakettiGetTempFilePath(".tmp")
    local tmpxml = tmpbin .. ".xml"
    local ok, err = pcall(function()
      -- Write binary file
      local f = io.open(tmpbin, "wb")
      if not f then error("Failed to create temporary binary file") end
      f:write(working_chunk)
      f:close()

      -- Convert to XML
      local plutil_result = os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
      if plutil_result ~= 0 then
        error("plutil conversion failed with code: " .. tostring(plutil_result))
      end

      -- Read XML file
      local xf = io.open(tmpxml, "r")
      if not xf then error("Failed to open converted XML file") end
      local xmlc = xf:read("*a")
      xf:close()

      -- Clean up temp files
      os.remove(tmpxml)
      os.remove(tmpbin)

      -- Look for JUCE state in plist
      local juce_b64 = xmlc:match('<key>jucePluginState</key>%s*<data><!%[CDATA%[(.-)%]%]></data>') or
                      xmlc:match('<key>jucePluginState</key>%s*<data>(.-)</data>') or
                      xmlc:match('<key>data</key>%s*<data><!%[CDATA%[(.-)%]%]></data>') or
                      xmlc:match('<key>data</key>%s*<data>(.-)</data>')
      
      if not juce_b64 then
          print("Debug: XML content:")
          print(xmlc:sub(1, 500)) -- Print first 500 chars to help diagnose
          error("No JUCE plugin state found in plist")
      end
      
      -- Decode JUCE state
      working_chunk = base64.decode(juce_b64)
      if not working_chunk then
          error("Failed to decode JUCE plugin state")
      end
      
      -- Verify we got JUCE data
      if working_chunk:sub(1,6) ~= "PARAMS" then
          print("Debug: First 64 bytes of decoded data:")
          print(pakettiAmigoHexDump(working_chunk, 1, 64))
          error("Invalid JUCE data (no PARAMS header)")
      end
      
      pakettiAmigoDebug(string.format("Successfully converted binary plist to JUCE data (%d bytes)", #working_chunk))
    end)

    -- Clean up in case of error
    if not ok then
      if tmpbin then os.remove(tmpbin) end
      if tmpxml then os.remove(tmpxml) end
      return nil, "Binary plist conversion failed: " .. tostring(err)
    end
  end
  
  local info = {
    magic   = working_chunk:sub(1, 6),                 -- Should be "PARAMS"
    version = working_chunk:byte(7) + working_chunk:byte(8) * 256,  -- Version in little-endian
    entries = {}
  }
  
  if info.magic ~= "PARAMS" then
    return nil, "Not a JUCE parameter chunk (invalid magic)"
  end

  pakettiAmigoDebug("JUCE Parameter chunk:")
  pakettiAmigoDebug(string.format("  Magic: %s", info.magic))
  pakettiAmigoDebug(string.format("  Version bytes: 0x%02X 0x%02X", working_chunk:byte(7), working_chunk:byte(8)))
  pakettiAmigoDebug(string.format("  Version: %d", info.version))

  -- First scan for metadata to build path lookup table
  local path_lookup = {}
  local offset = 9
  while offset < #working_chunk do
    if offset + 8 > #working_chunk then break end
    local id = working_chunk:sub(offset, offset + 7)
    local clean_id = id:match("metadata")
    if clean_id then
      offset = offset + 8
      if offset + 4 > #working_chunk then break end
      local version = pakettiAmigoReadLeInt(working_chunk, offset, 2)
      offset = offset + 2
      if offset + 2 > #working_chunk then break end
      local length = pakettiAmigoReadLeInt(working_chunk, offset, 2)
      offset = offset + 2
      if offset + length > #working_chunk then break end
      local data = working_chunk:sub(offset, offset + length - 1)
      
      pakettiAmigoDebug("\nFound metadata entry:")
      pakettiAmigoDebug("  First 128 bytes of metadata:")
      pakettiAmigoDebug(pakettiAmigoHexDump(data, 1, 128))
      
      -- Look for paths in metadata
      local pos = 1
      while pos <= #data do
        local null_pos = data:find("\0", pos)
        if not null_pos then break end
        local str = data:sub(pos, null_pos - 1)
        if str:match("%.wav$") or str:match("%.WAV$") then
          table.insert(path_lookup, str)
          pakettiAmigoDebug(string.format("  Found path in metadata: %q", str))
        end
        pos = null_pos + 1
      end
      
      offset = offset + length
    else
      offset = offset + 8
    end
  end

  pakettiAmigoDebug("\nFound paths in lookup table:")
  for i, path in ipairs(path_lookup) do
    pakettiAmigoDebug(string.format("  [%d] %q", i, path))
  end

  -- Now parse the actual entries
  offset = 9
  while offset < #working_chunk do
    if offset + 8 > #working_chunk then break end

    -- Try to read the ID, handling potential binary data
    local raw_id = working_chunk:sub(offset, offset + 7)
    local id = raw_id:match("pathnam?e?") or raw_id:match("jucedata") or raw_id:match("metadata")
    
    if id then
      offset = offset + 8
      local entry = { id = id, offset = offset - 8 }
      table.insert(info.entries, entry)

      if id:match("pathnam?e?") then
        -- version (2 bytes), length (1), flag (1), then path string
        if offset + 4 > #working_chunk then break end
        entry.version = pakettiAmigoReadLeInt(working_chunk, offset, 2)
        offset = offset + 2
        entry.length = working_chunk:byte(offset)
        offset = offset + 1
        entry.flag = working_chunk:byte(offset)
        offset = offset + 1
        
        -- Enhanced path extraction with detailed debugging
        pakettiAmigoDebug(string.format("\nPathname entry details at offset %d:", entry.offset))
        pakettiAmigoDebug(string.format("  Raw ID bytes: %s", pakettiAmigoHexDump(raw_id, 1, 8):match("(.-)\n")))
        pakettiAmigoDebug(string.format("  Version: %d (0x%04X)", entry.version, entry.version))
        pakettiAmigoDebug(string.format("  Length: %d bytes", entry.length))
        pakettiAmigoDebug(string.format("  Flag: %d (0x%02X)", entry.flag, entry.flag))
        
        if offset + entry.length > #working_chunk then break end
        
        -- Show raw path bytes before extraction
        local raw_path_bytes = working_chunk:sub(offset, offset + entry.length - 1)
        pakettiAmigoDebug("  Raw path bytes:")
        pakettiAmigoDebug(pakettiAmigoHexDump(raw_path_bytes, 1, entry.length))
        
        -- Handle special flag values
        if entry.flag == 0x19 then
            -- This is a special flag indicating a path index followed by the actual path
            local path_index = working_chunk:byte(offset)
            pakettiAmigoDebug(string.format("  Special path index: %d", path_index))
            
            -- Look for the actual path after the index
            -- Find the next null-terminated string
            local path_start = offset + 1
            local path_end = working_chunk:find("\0", path_start) or #working_chunk
            local full_path = working_chunk:sub(path_start, path_end - 1)
            
            pakettiAmigoDebug(string.format("  Found path after index: %q", full_path))
            -- Extract just the filename
            local filename = full_path:match("[^/\\]+$") or full_path
            pakettiAmigoDebug(string.format("  Extracted filename: %q", filename))
            
            entry.path = filename
            entry.full_path = full_path
            entry.path_index = path_index
            
            -- Update offset to skip both the index and the path
            offset = path_end + 1
        elseif entry.flag == 0x3C then
            -- This is another special flag indicating a path index that needs lookup
            local path_index = working_chunk:byte(offset)
            pakettiAmigoDebug(string.format("  Special path index: %d", path_index))
            
            -- Look up the path in our collected paths
            if path_lookup[path_index] then
                local full_path = path_lookup[path_index]
                local filename = full_path:match("[^/\\]+$") or full_path
                entry.path = filename
                entry.full_path = full_path
                pakettiAmigoDebug(string.format("  Found path in lookup table: %q", full_path))
                pakettiAmigoDebug(string.format("  Extracted filename: %q", filename))
            else
                -- Try to find the path before EMBEDDED_FILE marker
                local marker = "EMBEDDED_FILE"
                local s, e = working_chunk:find(marker, 1, true)
                if s then
                    pakettiAmigoDebug(string.format("\nFound EMBEDDED_FILE marker at offset %d", s))
                    pakettiAmigoDebug("Context around marker:")
                    pakettiAmigoDebug(pakettiAmigoHexDump(working_chunk, math.max(1, s - 64), 128))
                    
                    -- Look backwards from EMBEDDED_FILE for the path
                    local before = working_chunk:sub(1, s-1)
                    -- Find the last null byte before EMBEDDED_FILE
                    local last_null = before:reverse():find("\0")
                    if last_null then
                        -- Now look for the path - it starts with a slash
                        local path_start = before:find("/[^%z]*%.%w+%z$")
                        if path_start then
                            local full_path = before:sub(path_start, #before - 1) -- -1 to remove trailing null
                            pakettiAmigoDebug(string.format("  Found complete path: %q", full_path))
                            
                            -- Extract just the filename
                            local filename = full_path:match("[^/]+$")
                            pakettiAmigoDebug(string.format("  Extracted filename: %q", filename))
                            
                            entry.path = filename
                            entry.full_path = full_path
                        end
                    end
                end
                
                if not entry.path or entry.path == "" then
                    pakettiAmigoDebug("  Warning: Could not find path for index " .. path_index)
                    entry.path = string.format("<unknown_path_%d>", path_index)
                end
            end
            entry.path_index = path_index
            offset = offset + entry.length
        else
            -- Normal path string extraction
            local path_chars = {}
            for i = 1, entry.length do
                local byte = working_chunk:byte(offset + i - 1)
                if byte >= 32 and byte <= 126 then  -- Printable ASCII
                    table.insert(path_chars, string.char(byte))
                else
                    -- For non-printable characters, use hex representation
                    table.insert(path_chars, string.format("\\x%02X", byte))
                end
            end
            entry.path = table.concat(path_chars)
            offset = offset + entry.length
        end
        
        pakettiAmigoDebug(string.format("  Final path value: %q", entry.path))
      elseif id == "jucedata" or id == "metadata" then
        -- both store: version (2), length (2), then data
        if offset + 4 > #working_chunk then break end
        entry.version = pakettiAmigoReadLeInt(working_chunk, offset, 2)
        offset = offset + 2
        entry.length = pakettiAmigoReadLeInt(working_chunk, offset, 2)
        offset = offset + 2
        if offset + entry.length > #working_chunk then break end
        entry.data = working_chunk:sub(offset, offset + entry.length - 1)
        offset = offset + entry.length
      end
    else
      -- Try to resync by looking for next known pattern
      local found = false
      for i = offset + 1, math.min(offset + 32, #working_chunk - 8) do
        local next_bytes = working_chunk:sub(i, i + 7)
        if next_bytes:match("pathnam?e?") or next_bytes:match("jucedata") or next_bytes:match("metadata") then
          offset = i
          found = true
          break
        end
      end
      if not found then offset = offset + 8 end
    end
  end
  return info
end

-- Inspect chunk entries
function pakettiAmigoInspectChunkEntries(chunk)
    local offset = 9  -- Start after PARAMS header
    local entries = {}
    
    while offset < #chunk do
        if offset + 8 > #chunk then break end
        
        -- Get the raw ID bytes and try to interpret them
        local raw_id = chunk:sub(offset, offset + 7)
        pakettiAmigoDebug("\nFound entry at offset " .. offset)
        pakettiAmigoDebug("Raw ID bytes: " .. pakettiAmigoHexDump(raw_id, 1, 8))
        
        -- Try to read version and length
        if offset + 12 <= #chunk then
            local version = chunk:byte(offset + 8) * 256 + chunk:byte(offset + 9)
            local length = chunk:byte(offset + 10) * 256 + chunk:byte(offset + 11)
            pakettiAmigoDebug(string.format("Version: %d (0x%04X)", version, version))
            pakettiAmigoDebug(string.format("Length: %d bytes", length))
            
            -- Show some data bytes
            if offset + 12 + length <= #chunk then
                local data = chunk:sub(offset + 12, offset + 12 + math.min(32, length) - 1)
                pakettiAmigoDebug("First bytes of data:")
                pakettiAmigoDebug(pakettiAmigoHexDump(data, 1, #data))
            end
            
            table.insert(entries, {
                offset = offset,
                raw_id = raw_id,
                version = version,
                length = length
            })
            
            offset = offset + 12 + length
        else
            offset = offset + 8
        end
    end
    return entries
end

-- Parse WAV header info from a given position
function pakettiAmigoParseWavHeader(chunk, pos)
  if #chunk < pos + 44 then return nil, "Insufficient data for WAV header" end
  local function read_le(offset, size)
    local v = 0
    for i = 0, size - 1 do
      v = v + chunk:byte(pos + offset + i) * (256 ^ i)
    end
    return v
  end
  return {
    chunk_id       = chunk:sub(pos,     pos + 3),
    chunk_size     = read_le(4, 4),
    format         = chunk:sub(pos + 8, pos + 11),
    fmt_chunk_id   = chunk:sub(pos + 12, pos + 15),
    fmt_chunk_size = read_le(16, 4),
    audio_format   = read_le(20, 2),
    num_channels   = read_le(22, 2),
    sample_rate    = read_le(24, 4),
    byte_rate      = read_le(28, 4),
    block_align    = read_le(32, 2),
    bits_per_sample= read_le(34, 2),
  }
end

-- Extract the raw binary plist from the active preset data
function pakettiAmigoGetRawPlist()
  local song = renoise.song()
  local dev  = song.selected_instrument.plugin_properties.plugin_device
  local xml  = dev.active_preset_data
  if not xml or xml == "" then
    return nil, "No active preset data found."
  end
  local b64 = xml:match('<ParameterChunk><!%[CDATA%[(.-)%]%]></ParameterChunk>')
  if not b64 then
    return nil, "<ParameterChunk> not found in preset data."
  end
  return base64.decode(b64)
end

-- Main functions
function pakettiAmigoDecodeActiveParameterChunk()
  local raw, err = pakettiAmigoGetRawPlist()
  if not raw then
    renoise.app():show_status(err)
    print(err)
    return
  end

  -- Convert raw plist to XML for inspection
  local tmpbin = pakettiGetTempFilePath(".tmp")
  do local f = io.open(tmpbin, "wb") f:write(raw) f:close() end
  local tmpxml = tmpbin .. ".xml"
  if os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin)) ~= 0 then
    renoise.app():show_status("Failed converting plist to XML.")
    print("Failed converting plist to XML.")
    os.remove(tmpbin)
    return
  end
  local xmlc = io.open(tmpxml, "r"):read("*a")
  os.remove(tmpxml) os.remove(tmpbin)

  -- Known keys to search
  local keys = { "AudioFileData", "attachment", "jucePluginState" }
  local foundAny = false

  for _, key in ipairs(keys) do
    local data_b64 = xmlc:match('<key>' .. key .. '</key>%s*<data>(.-)</data>')
    if data_b64 then
      foundAny = true
      local chunk = base64.decode(data_b64)
      print(string.format("\nAnalyzing chunk '%s', size: %d bytes", key, #chunk))
      print("First 64 bytes:") print(pakettiAmigoHexDump(chunk, 1, 64))

      if key == "jucePluginState" then
        local info, perr = pakettiAmigoParseJuceParams(chunk)
        if not info then
          print("Error parsing JUCE parameters: " .. tostring(perr))
        else
          print("\nJUCE Parameter Chunk Analysis:")
          print(string.format("  Magic:   %s", info.magic))
          print(string.format("  Version: %d", info.version))
          print("\nEntries found:")
          for i, entry in ipairs(info.entries) do
            print(string.format("\nEntry %d: '%s' at offset %d", i, entry.id, entry.offset))
            if entry.length then
              print(string.format("  Length: %d bytes", entry.length))
            end
            if entry.path then
              print(string.format("  Path: %s", entry.path))
              renoise.app():show_status("Found pathname: " .. entry.path)
              print("Found pathname: " .. entry.path)
            end
            if entry.preview then
              print("  Preview of data:")
              print(pakettiAmigoHexDump(entry.preview, 1, #entry.preview))
            end
          end

          -- Scan for RIFF/WAV blocks
          local pos = 1
          while true do
            pos = chunk:find("RIFF", pos, true)
            if not pos then break end
            print(string.format("\nFound RIFF at offset %d", pos - 1))
            print("Context:") print(pakettiAmigoHexDump(chunk, math.max(1, pos - 16), 64))
            local winfo, werr = pakettiAmigoParseWavHeader(chunk, pos)
            if winfo then
              print("\nWAV Header:")
              print(string.format("  Sample Rate: %d Hz", winfo.sample_rate))
              -- Extract WAV
              local endpos = pos + 8 + winfo.chunk_size - 1
              local wavseg = chunk:sub(pos, math.min(endpos, #chunk))
              local wavfile = pakettiGetTempFilePath(".wav")
              local wf = io.open(wavfile, "wb"); wf:write(wavseg); wf:close()
              print("Extracted WAV to: " .. wavfile)
            else
              print("Error parsing WAV header: " .. tostring(werr))
            end
            pos = pos + 1
          end
        end
      end
    end
  end

  if not foundAny then
    renoise.app():show_status("No known data chunks found.")
    print("No known data chunks found.")
  end
end

-- Helper function to check if Amigo is available and loaded
function pakettiAmigoIsAvailable()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- First check: Is there even a plugin loaded?
  if not inst.plugin_properties or not inst.plugin_properties.plugin_loaded then
    renoise.app():show_status("There is no Amigo available in the current Instrument, doing nothing.")
    return false
  end
  
  local device = inst.plugin_properties.plugin_device
  
  -- Debug output to help diagnose any issues
  print("Found plugin device:")
  print("  Short name: " .. tostring(device.short_name))
  print("  Name: " .. tostring(device.name))
  
  -- Most reliable check: short_name should be "Amigo" for both AU and VST3
  if device.short_name ~= "Amigo" then
    renoise.app():show_status("There is no Amigo available in the current Instrument, doing nothing.")
    return false
  end
  
  return true, device
end

-- Load embedded WAV into a new sample slot
function pakettiAmigoLoadIntoSample()
  print ("--------------------------------")
  local ok, err = pcall(function()
    -- Check if Amigo is available
    local is_available, device = pakettiAmigoIsAvailable()
    if not is_available then return end
    
    -- If we get here, we definitely have Amigo loaded
    print("Confirmed Amigo plugin detected, proceeding with sample extraction...")
    
    -- unpack
    local raw_plist = pakettiAmigoGetRawPlist()
    if not raw_plist then error("Failed to get raw plist") end
    
    local xml_plist = pakettiAmigoPlistToXml(raw_plist)
    local juce_bin  = pakettiAmigoExtractJuceState(xml_plist)
    local wav_data  = pakettiAmigoExtractWavFromState(juce_bin)

    -- Extract filename from preset data
    pakettiAmigoDebug("Step 5: Extracting filename from preset data")
    local info = pakettiAmigoParseJuceParams(juce_bin)
    local filename = "Amigo Sample Export"  -- Better default name
    if info then
      -- Look for pathname entry
      for _, entry in ipairs(info.entries) do
        if entry.id:match("pathnam?e?") then
          pakettiAmigoDebug("\nFound pathname entry:")
          pakettiAmigoDebug(string.format("  ID: %s", entry.id))
          pakettiAmigoDebug(string.format("  Flag: 0x%02X", entry.flag))
          pakettiAmigoDebug(string.format("  Path: %q", entry.path))
          
          if entry.path and entry.path ~= "" and entry.path ~= "\\x05" then
            -- Use the full filename including extension
            filename = entry.path
            pakettiAmigoDebug(string.format("  Using filename: %q", filename))
          else
            pakettiAmigoDebug(string.format("  Invalid filename detected, using default: %q", filename))
          end
          break
        end
      end
    end

    -- write to temp
    pakettiAmigoDebug("Step 6: Writing temp WAV file")
    local tmp_path = pakettiGetTempFilePath(".wav")
    pakettiAmigoWriteFile(tmp_path, wav_data)

    -- lookup the selected sample in the selected instrument
    pakettiAmigoDebug("Step 7: Loading into selected sample")
    -- Inject default XRNI settings before loading the sample
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
    renoise.song().selected_instrument_index = renoise.song().selected_instrument_index+1
    pakettiPreferencesDefaultInstrumentLoader()
    local song=renoise.song()
    local inst_index = song.selected_instrument_index
    local inst = song.instruments[inst_index]
    
    -- Insert new sample at index 1
    inst:insert_sample_at(1)
    song.selected_sample_index = 1
    local samp_index = song.selected_sample_index
    local samp = inst.samples[samp_index]
    
    if not samp then
      error(("No sample %d in instrument %d"):format(samp_index, inst_index))
    end

    -- Set names from extracted filename
    inst.name = filename
    samp.name = filename

    

    -- load into the sample buffer
    local success, msg = samp.sample_buffer:load_from(tmp_path)
    if not success then
      error("Sample load failed: " .. tostring(msg))
    end

  local num_samples = #inst.samples
  if num_samples > 0 and inst.samples[num_samples].name == "Placeholder sample" then
    inst:delete_sample_at(num_samples)
  end
    

    pakettiAmigoDebug("Sample loaded successfully from: " .. tmp_path)
    pakettiAmigoDebug(string.format("Named instrument and sample: %q", filename))
  end)
  if not ok then
    if type(err) == "string" then
      if err:find("NO_EMBEDDED_SAMPLE") then
        renoise.app():show_status("This instance of Amigo does not have an Embedded Sample - Please click on Embed in the Amigo interface and then try to export the Sample again.")
      else
        renoise.app():show_status(err)
      end
    else
      renoise.app():show_status("An error occurred while processing")
    end
    print("Error: " .. tostring(err))
  end
end

-- Helper function to find full path in JUCE data
function pakettiAmigoFindFullPath(chunk)
  print("\nSearching for full path in JUCE data...")
  
  -- First check if we have valid JUCE data
  if #chunk < 8 or chunk:sub(1, 6) ~= "PARAMS" then
    print("Not valid JUCE data (no PARAMS header)")
    return nil
  end
  
  -- Look for path patterns in the first 1024 bytes (where header info usually is)
  local search_area = chunk:sub(1, math.min(1024, #chunk))
  print("Searching first 1024 bytes for path pattern")
  print("First 64 bytes of search area:")
  print(pakettiAmigoHexDump(search_area, 1, 64))
  
  -- Look for /Users/ path pattern
  local path_start = search_area:find("/Users/[^%z]+%.wav", 1, false)
  if path_start then
    -- Find the end of the path (null terminator or .wav extension)
    local path_end = search_area:find("%.wav", path_start) + 4
    local full_path = search_area:sub(path_start, path_end)
    print("Found path:", full_path)
    return full_path
  end
  
  -- If not found in header, look near EMBEDDED_FILE marker
  local marker = "EMBEDDED_FILE"
  local marker_pos = chunk:find(marker, 1, true)
  if marker_pos then
    print("Found EMBEDDED_FILE marker at position", marker_pos)
    -- Look in 512 bytes before the marker
    local before_marker = chunk:sub(math.max(1, marker_pos - 512), marker_pos - 1)
    
    -- Look for the last path-like string before the marker
    local last_path
    local pos = 1
    while true do
      local next_path = before_marker:match("/[^%z]+%.wav", pos)
      if not next_path then break end
      last_path = next_path
      pos = before_marker:find(next_path, pos) + 1
    end
    
    if last_path then
      print("Found path before marker:", last_path)
      return last_path
    end
  end
  
  print("No path found using direct search methods")
  
  -- Last resort: try to find any path-like pattern in the whole chunk
  local paths = {}
  local pos = 1
  while pos < #chunk do
    local path = chunk:match("/[^%z]+%.wav", pos)
    if not path then break end
    table.insert(paths, path)
    pos = chunk:find(path, pos) + 1
  end
  
  if #paths > 0 then
    print("Found", #paths, "potential paths:")
    for i, path in ipairs(paths) do
      print(i .. ":", path)
    end
    -- Return the most likely path (usually the first one in the JUCE data)
    return paths[1]
  end
  
  print("No paths found in JUCE data")
  return nil
end

-- Open the folder containing the sample file from the active preset
function pakettiAmigoOpenSamplePath()
  print ("--------------------------------")
  print("Starting pakettiAmigoOpenSamplePath...")
  local ok, err = pcall(function()
    -- Check if Amigo is available
    local is_available, device = pakettiAmigoIsAvailable()
    if not is_available then return end
    
    print("\nDevice info:")
    print("  Name:", device.name)
    print("  Short name:", device.short_name)
    
    -- Get the raw plist data
    print("\nGetting raw plist data...")
    local raw_plist = pakettiAmigoGetRawPlist()
    if not raw_plist then 
      print("Failed to get raw plist")
      error("Failed to get raw plist") 
    end
    print("Raw plist size:", #raw_plist, "bytes")
    print("First 64 bytes of raw plist:")
    print(pakettiAmigoHexDump(raw_plist, 1, 64))
    
    print("\nConverting plist to XML...")
    local xml_plist = pakettiAmigoPlistToXml(raw_plist)
    print("XML plist size:", #xml_plist, "bytes")
    
    print("\nExtracting JUCE state...")
    local juce_bin = pakettiAmigoExtractJuceState(xml_plist)
    print("JUCE binary size:", #juce_bin, "bytes")
    print("First 64 bytes of JUCE data:")
    print(pakettiAmigoHexDump(juce_bin, 1, 64))
    
    -- Try to find the full path using our new function
    local full_path = pakettiAmigoFindFullPath(juce_bin)
    
    if full_path then
      -- Extract the directory path
      local dir_path = full_path:match("(.+)[/\\][^/\\]+$")
      if dir_path then
        print("\nOpening folder:", dir_path)
        renoise.app():open_path(dir_path)
      else
        print("Could not extract directory path from:", full_path)
        error("Could not extract directory path from: " .. full_path)
      end
    else
      print("\nNo valid path found in preset data")
      error("NO_PATH_FOUND")
    end
  end)
  
  if not ok then
    if type(err) == "string" then
      if err:find("NO_PATH_FOUND") then
        print("Error: No sample path found in the current Amigo preset")
        renoise.app():show_status("No sample path found in the current Amigo preset.")
      else
        print("Error:", err)
        renoise.app():show_status(err)
      end
    else
      print("Error:", tostring(err))
      renoise.app():show_status("There is no Amigo available in the current Instrument, doing nothing.")
    end
  end
end

-- Export the selected sample into Amigo as its embedded WAV
function pakettiAmigoExportSampleToAmigo()
    print ("--------------------------------")
    local ok, err = pcall(function()
        -- Check if Amigo is available
        local is_available, device = pakettiAmigoIsAvailable()
        if not is_available then return end
        
        local song = renoise.song()
        local sample = song.selected_sample
        
        if not sample then
            error("No sample selected")
        end
        
        if not sample.sample_buffer.has_sample_data then
            error("Selected sample has no audio data")
        end
        

        -- Print original sample details
        local original_frames = sample.sample_buffer.number_of_frames
        local original_channels = sample.sample_buffer.number_of_channels
        local original_bits = sample.sample_buffer.bit_depth
        local original_rate = sample.sample_buffer.sample_rate
        pakettiAmigoDebug("Original Renoise sample details:", true)
        pakettiAmigoDebug(string.format("  Name: %s", sample.name), true)
        pakettiAmigoDebug(string.format("  Frames: %d", original_frames), true)
        pakettiAmigoDebug(string.format("  Channels: %d", original_channels), true)
        pakettiAmigoDebug(string.format("  Bit depth: %d", original_bits), true)
        pakettiAmigoDebug(string.format("  Sample rate: %d", original_rate), true)
        
        -- Save to temporary WAV
        local tmp_path = pakettiGetTempFilePath(".wav")
        pakettiAmigoDebug(string.format("\nSaving temporary WAV to: %s", tmp_path), true)
        local success, msg = sample.sample_buffer:save_as(tmp_path, "wav")
        if not success then
            error("Failed to save sample as WAV: " .. tostring(msg))
        end
        
        -- Read and verify the temporary WAV
        local wav_file = io.open(tmp_path, "rb")
        if not wav_file then
            error("Failed to open temporary WAV file")
        end
        local wav_data = wav_file:read("*a")
        wav_file:close()
        
        pakettiAmigoDebug(string.format("\nTemporary WAV file size: %d bytes", #wav_data), true)
        
        -- Create new JUCE data
        pakettiAmigoDebug("\nCreating new JUCE data:", true)
        
        -- Build JUCE data step by step
        local juce_data = {}
        
        -- 1. PARAMS header with version 1 (0x01 0x00)
        table.insert(juce_data, "PARAMS")
        table.insert(juce_data, string.char(1, 0))  -- Version 1 in little-endian
        
        -- 2. Add pathname entry
        local clean_name = sample.name:gsub("[^%w%-%._]", "_") -- sanitize name
        if clean_name == "" then clean_name = "untitled" end
        clean_name = clean_name .. ".wav" -- ensure .wav extension
        
        -- Pathname entry structure
        table.insert(juce_data, "pathname" .. string.rep(string.char(0), 8 - #"pathname"))  -- ID padded to 8 bytes
        table.insert(juce_data, string.char(101, 0))  -- Version 101 in little-endian
        table.insert(juce_data, string.char(#clean_name))  -- Length
        table.insert(juce_data, string.char(0x21))  -- Flag
        table.insert(juce_data, clean_name)  -- The actual path
        
        -- 3. Add WAV data entry
        table.insert(juce_data, "jucedata" .. string.rep(string.char(0), 8 - #"jucedata"))  -- ID padded to 8 bytes
        table.insert(juce_data, string.char(101, 0))  -- Version 101 in little-endian
        table.insert(juce_data, string.char(#wav_data % 256, math.floor(#wav_data / 256)))  -- Length in little-endian
        table.insert(juce_data, wav_data)  -- The actual WAV data
        
        -- 4. Add EMBEDDED_FILE marker and base64 WAV
        table.insert(juce_data, "EMBEDDED_FILE")
        table.insert(juce_data, string.char(0))  -- Null terminator
        table.insert(juce_data, base64.encode(wav_data))
        
        -- Combine all parts
        local new_juce_data = table.concat(juce_data)
        
        -- Debug output
        pakettiAmigoDebug("\nJUCE data structure:", true)
        pakettiAmigoDebug(string.format("  Total size: %d bytes", #new_juce_data), true)
        pakettiAmigoDebug(string.format("  WAV data size: %d bytes", #wav_data), true)
        pakettiAmigoDebug(string.format("  Pathname: %s", clean_name), true)
        
        -- Convert to binary plist
        local tmpxml = pakettiGetTempFilePath(".xml")
        local tmpbin = tmpxml .. ".bin"
        
        -- Create XML plist with the JUCE data
        local plist_xml = string.format([==[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>jucePluginState</key>
    <data>%s</data>
</dict>
</plist>]==], base64.encode(new_juce_data))
        
        -- Write XML plist
        local f = io.open(tmpxml, "wb")
        if not f then error("Failed to create temporary XML file") end
        f:write(plist_xml)
        f:close()
        
        -- Convert to binary plist
        local plutil_result = os.execute(('plutil -convert binary1 -o "%s" "%s"'):format(tmpbin, tmpxml))
        if plutil_result ~= 0 then
            os.remove(tmpxml)
            error("plutil conversion failed")
        end
        
        -- Read binary plist
        local bin_file = io.open(tmpbin, "rb")
        if not bin_file then
            os.remove(tmpxml)
            os.remove(tmpbin)
            error("Failed to open converted binary file")
        end
        local bin_data = bin_file:read("*a")
        bin_file:close()
        
        -- Clean up temp files
        os.remove(tmpxml)
        os.remove(tmpbin)
        os.remove(tmp_path)
        
        -- Create final Renoise XML
        local final_b64 = base64.encode(bin_data)
        local renoise_xml = [==[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="AudioPluginDevice">
    <IsMaximized>true</IsMaximized>
    <ActiveProgram>-1</ActiveProgram>
    <PluginType>AU</PluginType>
    <PluginIdentifier>aumu:Amgo:PTNZ</PluginIdentifier>
    <PluginDisplayName>AU: PotenzaDSP: Amigo</PluginDisplayName>
    <PluginShortDisplayName>Amigo</PluginShortDisplayName>
    <PluginEditorWindowPosition>-1,-1</PluginEditorWindowPosition>
    <ParameterChunkType>Chunk</ParameterChunkType>
    <ParameterChunk><![CDATA[]==] .. final_b64 .. [==[]]></ParameterChunk>
  </DeviceSlot>
</FilterDevicePreset>]==]
        
        -- Update device
        pakettiAmigoDebug("\nUpdating preset data:", true)
        pakettiAmigoDebug(string.format("  Device: %s", device.name), true)
        device.active_preset_data = renoise_xml
        
        -- Force a refresh of the plugin state
        device:parameter(1).value = device:parameter(1).value
        
        -- Verify the update by reading back the preset data
        pakettiAmigoDebug("\nVerifying updated preset data:", true)
        local verify_plist = pakettiAmigoGetRawPlist()
        if not verify_plist then
            error("Failed to get updated preset data for verification")
        end
        
        local verify_xml = pakettiAmigoPlistToXml(verify_plist)
        local verify_juce = pakettiAmigoExtractJuceState(verify_xml)
        local verify_info = pakettiAmigoParseJuceParams(verify_juce)
        
        if not verify_info then
            error("Failed to parse updated JUCE parameters")
        end
        
        pakettiAmigoDebug("\nCurrent preset data contents:", true)
        pakettiAmigoDebug(string.format("  JUCE version: %d", verify_info.version), true)
        
        -- Look for pathname entry
        local found_path = false
        for _, entry in ipairs(verify_info.entries) do
            if entry.id:match("pathnam?e?") then
                found_path = true
                pakettiAmigoDebug("\nFound pathname entry:", true)
                pakettiAmigoDebug(string.format("  Path: %s", entry.path), true)
                if entry.full_path then
                    pakettiAmigoDebug(string.format("  Full path: %s", entry.full_path), true)
                end
                pakettiAmigoDebug(string.format("  Length: %d bytes", entry.length), true)
                pakettiAmigoDebug(string.format("  Flag: 0x%02X", entry.flag), true)
                pakettiAmigoDebug(string.format("  Version: %d", entry.version), true)
            end
        end
        
        if not found_path then
            pakettiAmigoDebug("Warning: No pathname entry found in updated preset data", true)
        end
        
        -- Look for WAV data
        local wav_start = verify_juce:find("EMBEDDED_FILE")
        if wav_start then
            -- Skip marker and look for base64 data
            local pos = wav_start + #"EMBEDDED_FILE"
            while pos <= #verify_juce and verify_juce:byte(pos) <= 32 do
                pos = pos + 1
            end
            
            -- Find end of base64 data
            local wav_end = pos
            local valid_b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
            while wav_end <= #verify_juce and valid_b64:find(verify_juce:sub(wav_end,wav_end), 1, true) do
                wav_end = wav_end + 1
            end
            
            local wav_b64 = verify_juce:sub(pos, wav_end - 1)
            local wav_data = base64.decode(wav_b64)
            
            pakettiAmigoDebug("\nFound WAV data:", true)
            pakettiAmigoDebug(string.format("  Base64 size: %d bytes", #wav_b64), true)
            pakettiAmigoDebug(string.format("  Decoded size: %d bytes", #wav_data), true)
            
            -- Parse WAV header
            local wav_info = pakettiAmigoParseWavHeader(wav_data, 1)
            if wav_info then
                pakettiAmigoDebug("\nWAV file details:", true)
                pakettiAmigoDebug(string.format("  Format: %s", wav_info.format), true)
                pakettiAmigoDebug(string.format("  Channels: %d", wav_info.num_channels), true)
                pakettiAmigoDebug(string.format("  Sample rate: %d Hz", wav_info.sample_rate), true)
                pakettiAmigoDebug(string.format("  Bits per sample: %d", wav_info.bits_per_sample), true)
                pakettiAmigoDebug(string.format("  Total size: %d bytes", wav_info.chunk_size + 8), true)
            end
        else
            pakettiAmigoDebug("Warning: No WAV data found in updated preset data", true)
        end
        
        pakettiAmigoDebug("\nSample successfully exported and preset data updated!", true)
    end)
    
    if not ok then
        pakettiAmigoDebug("Error: " .. tostring(err), true)
    end
end

-- Core functions for Amigo preset handling

function pakettiAmigoGetPresetDataSize(preset_data)
    if not preset_data then
        return nil, "No preset data provided"
    end
    return #preset_data
end

function pakettiAmigoGetSampleSize(sample_data)
    if not sample_data then
        return nil, "No sample data provided"
    end
    
    -- Check for RIFF WAV header
    if sample_data:sub(1,4) ~= "RIFF" then
        return nil, "Invalid WAV file (no RIFF header)"
    end
    
    -- Get data chunk size
    local data_pos = sample_data:find("data")
    if not data_pos then
        return nil, "No data chunk found in WAV"
    end
    
    -- Read 4-byte size after "data" chunk
    local size = pakettiAmigoReadLeInt(sample_data, data_pos + 4, 4)
    return size
end

function pakettiAmigoVerifySampleMatch(renoise_sample, amigo_sample)
    if not renoise_sample or not amigo_sample then
        return false, "Missing sample data"
    end
    
    -- First verify both are valid WAV files
    local renoise_info = pakettiAmigoParseWavHeader(renoise_sample, 1)
    local amigo_info = pakettiAmigoParseWavHeader(amigo_sample, 1)
    
    if not renoise_info then
        return false, "Invalid Renoise WAV format"
    end
    if not amigo_info then
        return false, "Invalid Amigo WAV format"
    end
    
    -- Compare WAV header fields
    local header_mismatches = {}
    if renoise_info.num_channels ~= amigo_info.num_channels then
        table.insert(header_mismatches, string.format("Channel count mismatch: %d vs %d",
            renoise_info.num_channels, amigo_info.num_channels))
    end
    if renoise_info.sample_rate ~= amigo_info.sample_rate then
        table.insert(header_mismatches, string.format("Sample rate mismatch: %d vs %d",
            renoise_info.sample_rate, amigo_info.sample_rate))
    end
    if renoise_info.bits_per_sample ~= amigo_info.bits_per_sample then
        table.insert(header_mismatches, string.format("Bit depth mismatch: %d vs %d",
            renoise_info.bits_per_sample, amigo_info.bits_per_sample))
    end
    
    if #header_mismatches > 0 then
        return false, "WAV format mismatch:\n  " .. table.concat(header_mismatches, "\n  ")
    end
    
    -- Get data chunk sizes
    local renoise_size = pakettiAmigoGetSampleSize(renoise_sample)
    local amigo_size = pakettiAmigoGetSampleSize(amigo_sample)
    
    if not renoise_size or not amigo_size then
        return false, "Could not determine sample sizes"
    end
    
    if renoise_size ~= amigo_size then
        pakettiAmigoDebug(string.format("Size mismatch: Renoise=%d, Amigo=%d", renoise_size, amigo_size))
        return false, string.format("Sample size mismatch: Renoise=%d bytes, Amigo=%d bytes", 
            renoise_size, amigo_size)
    end
    
    -- Find data chunks
    local renoise_data_pos = renoise_sample:find("data")
    local amigo_data_pos = amigo_sample:find("data")
    
    if not renoise_data_pos or not amigo_data_pos then
        return false, "Could not locate data chunks"
    end
    
    -- Skip chunk ID (4 bytes) and size field (4 bytes)
    renoise_data_pos = renoise_data_pos + 8
    amigo_data_pos = amigo_data_pos + 8
    
    -- Compare actual sample data
    local renoise_data = renoise_sample:sub(renoise_data_pos, renoise_data_pos + renoise_size - 1)
    local amigo_data = amigo_sample:sub(amigo_data_pos, amigo_data_pos + amigo_size - 1)
    
    if renoise_data ~= amigo_data then
        -- If data differs, try to find where it differs
        local first_diff = 1
        while first_diff <= #renoise_data and 
              first_diff <= #amigo_data and 
              renoise_data:byte(first_diff) == amigo_data:byte(first_diff) do
            first_diff = first_diff + 1
        end
        
        if first_diff <= #renoise_data then
            local context_start = math.max(1, first_diff - 16)
            local context_end = math.min(#renoise_data, first_diff + 16)
            
            pakettiAmigoDebug("Sample data differs at byte " .. first_diff)
            pakettiAmigoDebug("Renoise context:")
            pakettiAmigoDebug(pakettiAmigoHexDump(renoise_data, context_start, 32))
            pakettiAmigoDebug("Amigo context:")
            pakettiAmigoDebug(pakettiAmigoHexDump(amigo_data, context_start, 32))
            
            return false, string.format("Sample data differs at byte %d", first_diff)
        end
    end
    
    -- Calculate some statistics about the sample
    local frame_size = (renoise_info.bits_per_sample / 8) * renoise_info.num_channels
    local total_frames = renoise_size / frame_size
    
    return true, string.format("Samples match exactly: %d frames, %d channels, %d-bit, %d Hz",
        total_frames, renoise_info.num_channels, renoise_info.bits_per_sample, renoise_info.sample_rate)
end

function pakettiAmigoUpdatePresetSample(preset_data, new_sample)
    if not preset_data or not new_sample then
        return nil, "Missing data"
    end
    
    -- First verify the new sample is valid WAV
    local sample_size = pakettiAmigoGetSampleSize(new_sample)
    if not sample_size then
        return nil, "Invalid WAV sample data"
    end
    
    -- Find the embedded file marker
    local marker = "EMBEDDED_FILE"
    local marker_pos = preset_data:find(marker)
    if not marker_pos then
        return nil, "No embedded file marker found in preset"
    end
    
    -- Convert new sample to base64
    local sample_b64 = base64.encode(new_sample)
    
    -- Find the start of the old base64 data
    local valid_b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    local old_b64_start = marker_pos + #marker
    while old_b64_start <= #preset_data and not valid_b64:find(preset_data:sub(old_b64_start,old_b64_start), 1, true) do
        old_b64_start = old_b64_start + 1
    end
    
    -- Find the end of the old base64 data
    local old_b64_end = old_b64_start
    while old_b64_end <= #preset_data and valid_b64:find(preset_data:sub(old_b64_end,old_b64_end), 1, true) do
        old_b64_end = old_b64_end + 1
    end
    old_b64_end = old_b64_end - 1
    
    -- Create new preset data with updated sample
    local new_preset = preset_data:sub(1, old_b64_start - 1) .. 
                      sample_b64 .. 
                      preset_data:sub(old_b64_end + 1)
                      
    return new_preset
end

-- Helper function to get Renoise sample data
function pakettiAmigoGetRenoiseSelectedSample()
    local song = renoise.song()
    if not song.selected_sample then
        return nil, "No sample selected in Renoise"
    end
    
    local sample = song.selected_sample
    if not sample.sample_buffer.has_sample_data then
        return nil, "Selected sample has no data"
    end
    
    -- Get raw sample data
    local sample_data = sample.sample_buffer:load_from()
    if not sample_data then
        return nil, "Could not load sample data"
    end
    
    return sample_data
end

-- Enhanced JUCE parameter decoder based on AudioFormat spec
function pakettiAmigoDecodeJuceParameters(data)
    local params = {}
    local offset = 9  -- Start after PARAMS header
    
    -- Verify JUCE header first
    if #data < 8 or data:sub(1, 6) ~= "PARAMS" then
        return nil, "Invalid JUCE header"
    end
    
    -- Verify version (should be 1 in little-endian)
    local version_lo = data:byte(7)  -- First byte is low byte in little-endian
    local version_hi = data:byte(8)  -- Second byte is high byte
    local version = version_lo + version_hi * 256
    
    pakettiAmigoDebug(string.format("\nParsing JUCE header:", true))
    pakettiAmigoDebug(string.format("  Version bytes: 0x%02X 0x%02X", version_lo, version_hi), true)
    pakettiAmigoDebug(string.format("  Calculated version: %d", version), true)
    
    local info = {
      magic = chunk:sub(1, 6),
      version = version,
      entries = {}
    }
    
    -- Start parsing entries after header
    local offset = 9
    while offset < #chunk do
      if offset + 8 > #chunk then break end
      
      -- Get the raw ID bytes and try to interpret them
      local raw_id = chunk:sub(offset, offset + 7)
      local clean_id = raw_id:match("[%w]+") or "???"
      offset = offset + 8
      
      -- Always try to read version and length first
      if offset + 4 > #chunk then break end
      
      -- Read version in little-endian format
      local param_version_lo = chunk:byte(offset)
      local param_version_hi = chunk:byte(offset + 1)
      local param_version = param_version_lo + param_version_hi * 256
      
      -- Read length in little-endian format
      local param_length_lo = chunk:byte(offset + 2)
      local param_length_hi = chunk:byte(offset + 3)
      local param_length = param_length_lo + param_length_hi * 256
      
      offset = offset + 4
      
      -- Debug parameter header
      pakettiAmigoDebug(string.format("\nParameter at offset %d:", offset - 12), true)
      pakettiAmigoDebug(string.format("  ID: %s", clean_id), true)
      pakettiAmigoDebug(string.format("  Version bytes: 0x%02X 0x%02X", param_version_lo, param_version_hi), true)
      pakettiAmigoDebug(string.format("  Length bytes: 0x%02X 0x%02X", param_length_lo, param_length_hi), true)
      pakettiAmigoDebug(string.format("  Calculated version: %d", param_version), true)
      pakettiAmigoDebug(string.format("  Calculated length: %d", param_length), true)
      
      -- Special handling for pathname entries
      if raw_id:match("pathnam?e?") then
        local entry = {
          id = clean_id,
          version = param_version,
          length = param_length,
          offset = offset - 12
        }
        
        -- For pathname entries, let's look ahead for path data
        local path_start = offset
        local path_end = offset + 256  -- Look ahead up to 256 bytes
        local found_path = nil
        
        -- Look for a path-like string
        for i = path_start, math.min(path_end, #chunk) do
          local potential_path = chunk:sub(i, math.min(i + 256, #chunk))
          -- Look for path patterns like /Users/ or similar
          local path = potential_path:match("(/[^%z]+%.%w+)")
          if path then
            found_path = path
            break
          end
        end
        
        if found_path then
          entry.path = found_path
          entry.full_path = found_path
          pakettiAmigoDebug(string.format("  Found path: %s", found_path), true)
        else
          -- Fallback to original method
          local flag = chunk:byte(offset)
          local path = chunk:sub(offset + 1, offset + param_length - 1)
          entry.flag = flag
          entry.path = path
        end
        
        table.insert(info.entries, entry)
        offset = offset + param_length
        
      else
        -- Handle other entry types as before
        local entry = {
          id = clean_id,
          version = param_version,
          length = param_length,
          offset = offset - 12
        }
        
        if offset + param_length <= #chunk then
          entry.data = chunk:sub(offset, offset + param_length - 1)
        end
        
        table.insert(info.entries, entry)
        offset = offset + param_length
      end
    end
    
    return info
end

-- Helper function to handle version numbers consistently
function pakettiAmigoHandleVersion(version_number)
    -- Ensure version is a number
    version_number = tonumber(version_number) or 1
    
    -- Convert to little-endian bytes
    local lo = version_number % 256
    local hi = math.floor(version_number / 256)
    
    -- Return both the numeric version and its byte representation
    return {
        number = version_number,
        bytes = string.char(lo, hi),
        lo = lo,
        hi = hi
    }
end

-- Helper function to read version from bytes
function pakettiAmigoReadVersion(data, offset)
    if not data or not offset or offset + 1 > #data then
        return nil, "Invalid data or offset for version reading"
    end
    
    -- Read version in little-endian format
    local lo = data:byte(offset)
    local hi = data:byte(offset + 1)
    local version = lo + hi * 256
    
    return {
        number = version,
        bytes = data:sub(offset, offset + 1),
        lo = lo,
        hi = hi
    }
end



-- Import a WAV into the preset
function pakettiAmigoImportWavefile()
  -- Check if Amigo is available
  local is_available, device = pakettiAmigoIsAvailable()
  if not is_available then return end

  local raw, err = pakettiAmigoGetRawPlist()
  if not raw then
    renoise.app():show_status(err)
    print(err)
    return
  end

  local inpath = renoise.app():prompt_for_filename_to_read({"*.wav"}, "Select Wavefile to Import...")
  if not inpath then return end

  print("Debug: Reading WAV file...")
  local inf = io.open(inpath, "rb")
  local wave = inf:read("*a")
  inf:close()

  -- Verify input WAV file
  local winfo, werr = pakettiAmigoParseWavHeader(wave, 1)
  if not winfo then
    renoise.app():show_status("Invalid WAV file: " .. tostring(werr))
    print("Invalid WAV file: " .. tostring(werr))
    return
  end
  print("Debug: Input WAV file info:")
  print(string.format("  Sample Rate: %d Hz", winfo.sample_rate))
  print(string.format("  Channels: %d", winfo.num_channels))
  print(string.format("  Bits: %d", winfo.bits_per_sample))

  -- Convert existing plist to XML
  print("Debug: Converting plist to XML...")
  local tmpbin = pakettiGetTempFilePath(".tmp")
  do local f = io.open(tmpbin, "wb") f:write(raw) f:close() end
  local tmpxml = tmpbin .. ".xml"
  os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
  local xmlc = io.open(tmpxml, "r"):read("*a")
  os.remove(tmpxml) os.remove(tmpbin)

  -- Get JUCE plugin state
  print("Debug: Looking for JUCE plugin state...")
  local juce_b64 = xmlc:match('<key>jucePluginState</key>%s*<data>(.-)</data>')
  if not juce_b64 then
    renoise.app():show_status("No JUCE plugin state found")
    print("No JUCE plugin state found")
    return
  end

  local juce_data = base64.decode(juce_b64)
  local info, perr = pakettiAmigoParseJuceParams(juce_data)
  if not info then
    renoise.app():show_status("Failed to parse JUCE parameters: " .. tostring(perr))
    print("Failed to parse JUCE parameters: " .. tostring(perr))
    return
  end

  -- Find jucedata entry to replace
  local found = false
  for i, entry in ipairs(info.entries) do
    if entry.id == "jucedata" then
      print(string.format("Debug: Found jucedata entry at offset %d, length %d", entry.offset, entry.length))
      -- Replace WAV data in JUCE chunk
      local before = juce_data:sub(1, entry.offset + 12) -- Keep header and version/length fields
      local after = juce_data:sub(entry.offset + entry.length + 12)
      local new_juce_data = before .. wave .. after
      
      -- Update the length field in the header
      local len_bytes = string.char(
        (#wave) % 256,
        math.floor(#wave / 256) % 256
      )
      new_juce_data = new_juce_data:sub(1, entry.offset + 10) .. len_bytes .. new_juce_data:sub(entry.offset + 13)
      
      print("Debug: Created new JUCE data with updated WAV")
      
      -- Verify the new JUCE data structure
      pakettiAmigoDebug("\nVerifying new JUCE data structure...")
      local valid, result = pakettiAmigoVerifyJuceHeader(new_juce_data)
      if not valid then
          error("Invalid JUCE header after modification: " .. tostring(result))
      end
      pakettiAmigoDebug("Header verification passed:")
      pakettiAmigoDebug(string.format("  Magic: %s", result.magic))
      pakettiAmigoDebug(string.format("  Version: %d", result.version))
      pakettiAmigoDebug("  Found entries:")
      for i, entry in ipairs(result.entries) do
          pakettiAmigoDebug(string.format("    %d: %s", i, entry))
      end
      
      -- Convert back to base64
      local new_juce_b64 = base64.encode(new_juce_data)
      
      -- Replace in XML
      local new_xmlc = xmlc:gsub(
        '(<key>jucePluginState</key>%s*<data><!%[CDATA%[(.-)%]%]></data>)',
        string.format('<key>jucePluginState</key><data><![CDATA[%s]]></data>', new_juce_b64)
      )
      
      -- Convert back to binary plist
      print("Debug: Converting back to binary plist...")
      local tmpxml2 = pakettiGetTempFilePath(".xml")
      do local xf = io.open(tmpxml2, "wb") xf:write(new_xmlc) xf:close() end
      local tmpbin2 = tmpxml2 .. ".bin"
      local plutil_result = os.execute(('plutil -convert binary1 -o "%s" "%s"'):format(tmpbin2, tmpxml2))
      if plutil_result ~= 0 then
        error("plutil conversion failed with code: " .. tostring(plutil_result))
      end
      
      local bin_file = io.open(tmpbin2, "rb")
      if not bin_file then error("Failed to open converted binary file") end
      local bin_data = bin_file:read("*a")
      bin_file:close()
      os.remove(tmpxml2)
      os.remove(tmpbin2)
      
      pakettiAmigoDebug(string.format("Binary plist size: %d bytes", #bin_data))
      
      -- Re-embed into preset
      print("Debug: Updating preset data...")
      local new_b64 = base64.encode(bin_data)
      local old_preset_data = device.active_preset_data
      local new_preset_data = old_preset_data:gsub(
        '<ParameterChunk><!%[CDATA%[(.-)%]%]></ParameterChunk>',
        string.format('<ParameterChunk><![CDATA[%s]]></ParameterChunk>', new_b64)
      )
      
      -- Verify the modification worked
      if new_preset_data == old_preset_data then
        error("Failed to update preset data - no changes were made")
      end
      
      pakettiAmigoDebug("\nFinal size comparison:")
      pakettiAmigoDebug(string.format("Original preset data size: %d bytes", #old_preset_data))
      pakettiAmigoDebug(string.format("New preset data size: %d bytes", #new_preset_data))
      pakettiAmigoDebug(string.format("Difference: %d bytes", #new_preset_data - #old_preset_data))
      
      -- Apply the changes
      device.active_preset_data = new_preset_data
      
      -- Force a refresh of the plugin state
      pakettiAmigoDebug("Forcing plugin refresh...")
      device:parameter(1).value = device:parameter(1).value
      
      pakettiAmigoDebug("Successfully imported wavefile into plugin preset")
      found = true
      break
    end
  end

  if not found then
    renoise.app():show_status("No suitable jucedata entry found for WAV import")
    print("No suitable jucedata entry found for WAV import")
  end
end

-- Set (override) the pathname inside the JUCE parameter chunk
function pakettiAmigoSetJucePath(old_chunk, new_path)
    if not old_chunk or not new_path then
        return nil, "Missing data"
    end
    
    -- Normalize path to use forward slashes and remove any leading slashes
    new_path = new_path:gsub("\\", "/"):gsub("^/+", "")
    
    pakettiAmigoDebug("\nStarting pakettiAmigoSetJucePath:")
    pakettiAmigoDebug(string.format("  Input chunk size: %d bytes", #old_chunk))
    pakettiAmigoDebug(string.format("  New path: %s", new_path))
    
    -- Handle binary plist conversion first if needed
    local working_chunk = old_chunk
    if working_chunk:sub(1,6) == "bplist" then
        pakettiAmigoDebug("Converting binary plist to XML first...")
        local tmpbin = pakettiGetTempFilePath(".tmp")
        local tmpxml = tmpbin .. ".xml"
        
        -- Write binary plist to temp file
        local f = io.open(tmpbin, "wb")
        if not f then error("Failed to create temporary binary file") end
        f:write(working_chunk)
        f:close()
        
        -- Convert to XML - FIXED: changed binary1 to xml1
        local plutil_result = os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
        if plutil_result ~= 0 then
            os.remove(tmpbin)
            error("plutil conversion failed with code: " .. tostring(plutil_result))
        end
        
        -- Read XML file
        local xf = io.open(tmpxml, "r")
        if not xf then 
            os.remove(tmpbin)
            os.remove(tmpxml)
            error("Failed to open converted XML file") 
        end
        local xmlc = xf:read("*a")
        xf:close()
        
        -- Clean up temp files
        os.remove(tmpxml)
        os.remove(tmpbin)
        
        -- Print the XML content for debugging
        print("Debug: Converted XML content:")
        print(xmlc:sub(1, 500)) -- Print first 500 chars
        
        -- Extract JUCE state from XML plist - try both key names and both CDATA/non-CDATA formats
        local juce_b64 = xmlc:match('<key>jucePluginState</key>%s*<data><!%[CDATA%[(.-)%]%]></data>') or
                        xmlc:match('<key>jucePluginState</key>%s*<data>(.-)</data>') or
                        xmlc:match('<key>data</key>%s*<data><!%[CDATA%[(.-)%]%]></data>') or
                        xmlc:match('<key>data</key>%s*<data>(.-)</data>')
        
        if not juce_b64 then
            print("Debug: No direct match found, trying to parse XML structure...")
            -- Try to find any <data> tags
            local data_tags = {}
            for tag in xmlc:gmatch("<data>(.-)</data>") do
                table.insert(data_tags, tag)
            end
            print(string.format("Found %d <data> tags", #data_tags))
            for i, tag in ipairs(data_tags) do
                print(string.format("Data tag %d content preview: %s", i, tag:sub(1, 50)))
            end
            error("No JUCE plugin state found in plist")
        end
        
        -- Decode JUCE state
        working_chunk = base64.decode(juce_b64)
        if not working_chunk then
            error("Failed to decode JUCE plugin state")
        end
        
        -- Verify we got JUCE data
        if working_chunk:sub(1,6) ~= "PARAMS" then
            print("Debug: First 64 bytes of decoded data:")
            print(pakettiAmigoHexDump(working_chunk, 1, 64))
            error("Invalid JUCE data (no PARAMS header)")
        end
        
        pakettiAmigoDebug(string.format("Successfully converted binary plist to JUCE data (%d bytes)", #working_chunk))
    end
    
    -- Parse existing parameters
    local info, err = pakettiAmigoParseJuceParams(working_chunk)
    if not info then 
        pakettiAmigoDebug("Failed to parse JUCE parameters: " .. tostring(err))
        return nil, err 
    end
    
    -- First find and update the metadata entry if it exists
    local metadata_entry = nil
    local path_index = 1
    for _, entry in ipairs(info.entries) do
        if entry.id == "metadata" then
            metadata_entry = entry
            break
        end
    end
    
    -- If we found metadata, update or add the path to it
    if metadata_entry then
        -- Create new metadata with the path
        local new_metadata = ""
        local found_path = false
        local pos = 1
        while pos <= #metadata_entry.data do
            local null_pos = metadata_entry.data:find("\0", pos)
            if not null_pos then break end
            local str = metadata_entry.data:sub(pos, null_pos - 1)
            if str:match("%.wav$") or str:match("%.WAV$") then
                if not found_path then
                    -- Replace first WAV path with our new one
                    new_metadata = new_metadata .. new_path .. "\0"
                    found_path = true
                else
                    -- Keep other WAV paths
                    new_metadata = new_metadata .. str .. "\0"
                end
            else
                -- Keep non-WAV strings
                new_metadata = new_metadata .. str .. "\0"
            end
            pos = null_pos + 1
        end
        
        -- If we didn't find a WAV path to replace, add ours
        if not found_path then
            new_metadata = new_metadata .. new_path .. "\0"
        end
        
        -- Update the metadata entry
        local total_old = 8 + 2 + 2 + #metadata_entry.data
        local start = metadata_entry.offset
        local new_entry = metadata_entry.id .. string.rep("\0", 8 - #metadata_entry.id) ..
                         string.char(metadata_entry.version % 256, math.floor(metadata_entry.version / 256)) ..
                         string.char(#new_metadata % 256, math.floor(#new_metadata / 256)) ..
                         new_metadata
        
        working_chunk = working_chunk:sub(1, start - 1) .. new_entry .. working_chunk:sub(start + total_old)
    end
    
    -- Now find and update the pathname entry
    local found = false
    for _, entry in ipairs(info.entries) do
        if entry.id:match("pathnam?e?") then
            found = true
            local total_old = 8 + 2 + 1 + 1 + entry.length
            local start = entry.offset
            
            -- Always use direct path mode (0x21) for new paths
            local flag_byte = string.char(0x21)  -- Direct path mode
            local new_entry = entry.id .. string.rep("\0", 8 - #entry.id) ..
                            string.char(entry.version % 256, math.floor(entry.version / 256)) ..
                            string.char(#new_path) ..
                            flag_byte ..
                            new_path
            
            pakettiAmigoDebug("\nUpdating pathname entry:")
            pakettiAmigoDebug(string.format("  Original flag: 0x%02X", entry.flag))
            pakettiAmigoDebug(string.format("  New flag: 0x%02X (direct path)", 0x21))
            pakettiAmigoDebug(string.format("  New path length: %d", #new_path))
            pakettiAmigoDebug(string.format("  New path: %s", new_path))
            
            working_chunk = working_chunk:sub(1, start - 1) .. new_entry .. working_chunk:sub(start + total_old)
            break
        end
    end
    
    -- If no pathname entry exists, create one using direct path mode
    if not found then
        local header = working_chunk:sub(1, 8)  -- PARAMS + version
        local rest = working_chunk:sub(9)
        
        -- Create new pathname entry with direct path
        local new_entry = "pathname" .. string.rep("\0", 8 - #"pathname") ..
                         string.char(0x65, 0x00) ..  -- Version 101
                         string.char(#new_path) ..   -- Length
                         string.char(0x21) ..        -- Direct path flag
                         new_path
        
        pakettiAmigoDebug("\nCreating new pathname entry:")
        pakettiAmigoDebug(string.format("  Flag: 0x21 (direct path)"))
        pakettiAmigoDebug(string.format("  Path length: %d", #new_path))
        pakettiAmigoDebug(string.format("  Path: %s", new_path))
        
        working_chunk = header .. new_entry .. rest
    end
    
    -- Convert modified JUCE data back to binary plist if needed
    if old_chunk:sub(1,6) == "bplist" then
        pakettiAmigoDebug("\nConverting modified JUCE data back to binary plist...")
        
        -- Create XML plist with the modified JUCE data
        local plist_xml = string.format([==[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>jucePluginState</key>
    <data>%s</data>
</dict>
</plist>]==], base64.encode(working_chunk))
        
        -- Write XML plist
        local tmpxml = pakettiGetTempFilePath(".xml")
        local tmpbin = tmpxml .. ".bin"
        local f = io.open(tmpxml, "wb")
        if not f then error("Failed to create temporary XML file") end
        f:write(plist_xml)
        f:close()
        
        -- Convert to binary plist
        local plutil_result = os.execute(('plutil -convert binary1 -o "%s" "%s"'):format(tmpbin, tmpxml))
        if plutil_result ~= 0 then
            os.remove(tmpxml)
            error("plutil conversion failed")
        end
        
        -- Read binary plist
        local bin_file = io.open(tmpbin, "rb")
        if not bin_file then
            os.remove(tmpxml)
            os.remove(tmpbin)
            error("Failed to open converted binary file")
        end
        local bin_data = bin_file:read("*a")
        bin_file:close()
        
        -- Clean up temp files
        os.remove(tmpxml)
        os.remove(tmpbin)
        
        return bin_data
    end
    
    return working_chunk
end

-- Prompt user to set a new pathname in the active preset
function pakettiAmigoSetActivePathname()
  -- Check if Amigo is available
  local is_available, device = pakettiAmigoIsAvailable()
  if not is_available then return end
  
  local xml = device.active_preset_data
  
  if not xml or xml == "" then
    renoise.app():show_status("No active preset data found")
    print("No active preset data found")
    return
  end
  
  -- Try both CDATA and non-CDATA patterns
  local b64 = xml:match('<ParameterChunk><!%[CDATA%[(.-)%]%]></ParameterChunk>') or
              xml:match('<ParameterChunk>(.-)</ParameterChunk>')
  if not b64 then
    renoise.app():show_status("No <ParameterChunk> found")
    print("No <ParameterChunk> found")
    return
  end
  
  print("Debug: Decoding preset data...")
  local raw = base64.decode(b64)
  if not raw then
    renoise.app():show_status("Failed to decode base64 data")
    print("Failed to decode base64 data")
    return
  end
  print(string.format("Debug: Decoded %d bytes of raw data", #raw))
  
  -- If it's a binary plist, convert to XML first
  if raw:sub(1,6) == "bplist" then
    print("Debug: Converting binary plist to XML...")
    local tmpbin = pakettiGetTempFilePath(".tmp")
    local tmpxml = tmpbin .. ".xml"
    do 
      local f = io.open(tmpbin, "wb")
      if not f then
        print("Debug: Failed to create temporary binary file")
        return
      end
      f:write(raw)
      f:close()
    end
    
    local plutil_result = os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
    if plutil_result ~= 0 then
      print("Debug: plutil conversion failed")
      os.remove(tmpbin)
      return
    end
    
    local xmlc = io.open(tmpxml, "r"):read("*a")
    os.remove(tmpxml)
    os.remove(tmpbin)
    
    print("Debug: Converted plist contents:")
    print(xmlc:sub(1, 200) .. "...") -- Print first 200 chars
  end
  
  local new_path = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select New Pathname...")
  if not new_path then return end
  
  print("Debug: Attempting to set new path...")
  local new_raw, err = pakettiAmigoSetJucePath(raw, new_path)
  if not new_raw then
    renoise.app():show_status("Error: " .. tostring(err))
    print("Error: " .. tostring(err))
    return
  end
  
  print("Debug: Updating preset data...")
  local new_b64 = base64.encode(new_raw)
  
  -- Create new preset XML with updated data
  local new_xml = string.format([==[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="AudioPluginDevice">
    <IsMaximized>true</IsMaximized>
    <ActiveProgram>-1</ActiveProgram>
    <PluginType>AU</PluginType>
    <PluginIdentifier>aumu:Amgo:PTNZ</PluginIdentifier>
    <PluginDisplayName>AU: PotenzaDSP: Amigo</PluginDisplayName>
    <PluginShortDisplayName>Amigo</PluginShortDisplayName>
    <PluginEditorWindowPosition>-1,-1</PluginEditorWindowPosition>
    <ParameterChunkType>Chunk</ParameterChunkType>
    <ParameterChunk><![CDATA[%s]]></ParameterChunk>
  </DeviceSlot>
</FilterDevicePreset>]==], new_b64)
  
  -- Update the device with new preset data
  device.active_preset_data = new_xml
  
  -- Force a refresh of the plugin state
  print("Debug: Forcing plugin refresh...")
  -- First store all parameter values
  local param_values = {}
  for i = 1, #device.parameters do
    param_values[i] = device:parameter(i).value
  end
  
  -- Then restore them all to force a full refresh
  for i = 1, #device.parameters do
    device:parameter(i).value = param_values[i]
  end
  
  -- Verify the update
  print("Debug: Verifying update...")
  local verify_xml = device.active_preset_data
  local verify_b64 = verify_xml:match('<ParameterChunk><!%[CDATA%[(.-)%]%]>')
  if verify_b64 then
    local verify_raw = base64.decode(verify_b64)
    if verify_raw:sub(1,6) == "bplist" then
      print("Debug: Converting verification plist to XML...")
      local tmpbin = pakettiGetTempFilePath(".tmp")
      local tmpxml = tmpbin .. ".xml"
      do local f = io.open(tmpbin, "wb") f:write(verify_raw) f:close() end
      os.execute(('plutil -convert xml1 -o "%s" "%s"'):format(tmpxml, tmpbin))
      local xmlc = io.open(tmpxml, "r"):read("*a")
      os.remove(tmpxml) os.remove(tmpbin)
      
      -- Extract and decode JUCE state
      local juce_b64 = xmlc:match('<key>jucePluginState</key>%s*<data>(.-)</data>')
      if juce_b64 then
        local juce_data = base64.decode(juce_b64)
        local info = pakettiAmigoParseJuceParams(juce_data)
        if info then
          for _, entry in ipairs(info.entries) do
            if entry.id:match("pathnam?e?") then
              print("Debug: Verified path in preset:", entry.path)
              if entry.path ~= new_path:match("[^/\\]+$") then
                print("Warning: Path verification mismatch")
                print("  Expected:", new_path:match("[^/\\]+$"))
                print("  Found:", entry.path)
              end
              break
            end
          end
        end
      end
    end
  end
  
  renoise.app():show_status("Pathname updated to: " .. new_path)
  print("Pathname updated to: " .. new_path)
end


