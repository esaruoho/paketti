----------------------------------------------------
-- PakettiAutoHideDiskBrowser
-- Automatically hides the disk browser when a new song is loaded
----------------------------------------------------

-- Function to toggle the auto-hide disk browser setting
function pakettiAutoHideDiskBrowserToggle()
  preferences.paketti_auto_hide_disk_browser = not preferences.paketti_auto_hide_disk_browser
  
  local status = preferences.paketti_auto_hide_disk_browser and "ENABLED" or "DISABLED"
  renoise.app():show_status("Auto-Hide Disk Browser: " .. status)
  print("-- Paketti Auto-Hide Disk Browser: " .. status)
end

-- Function to check if auto-hide is enabled (for menu checkmark)
function pakettiAutoHideDiskBrowserIsEnabled()
  return preferences.paketti_auto_hide_disk_browser == true
end

-- Notification handler for when new song is loaded
local function pakettiAutoHideDiskBrowserNewDocumentHandler()
  if preferences.paketti_auto_hide_disk_browser then
    -- Hide the disk browser when a new song is loaded
    renoise.app().window.disk_browser_is_visible = false
    print("-- Paketti Auto-Hide Disk Browser: Disk browser hidden on song load")
  end
end

-- Add notification for new document/song loads
renoise.tool().app_new_document_observable:add_notifier(pakettiAutoHideDiskBrowserNewDocumentHandler)

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Experimental:Auto-Hide Disk Browser on Song Load",
  invoke = pakettiAutoHideDiskBrowserToggle,
  selected = pakettiAutoHideDiskBrowserIsEnabled
}

renoise.tool():add_menu_entry{
  name = "Disk Browser:Paketti:Auto-Hide Disk Browser on Song Load",
  invoke = pakettiAutoHideDiskBrowserToggle,
  selected = pakettiAutoHideDiskBrowserIsEnabled
}

renoise.tool():add_keybinding{name = "Global:Paketti:Auto-Hide Disk Browser on Song Load",invoke = pakettiAutoHideDiskBrowserToggle}

-- MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Auto-Hide Disk Browser on Song Load",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiAutoHideDiskBrowserToggle() 
    end 
  end
}

-- ======================================
-- Paketti Loop Block Transport Control
-- ======================================
-- Recreates Renoise 2.x-style loop block behavior with improvements
-- Provides enhanced transport control for loop blocks with catch-up functionality

-- Position comparison utilities
local function paketti_pos_le(pos1, pos2)
  if not pos1 or not pos2 then return false end
  if pos1.sequence < pos2.sequence then 
    return true 
  elseif pos1.sequence == pos2.sequence then
    return pos1.line <= pos2.line 
  else 
    return false 
  end
end

local function paketti_pos_lt(pos1, pos2)
  if not pos1 or not pos2 then return false end
  if pos1.sequence < pos2.sequence then 
    return true 
  elseif pos1.sequence == pos2.sequence then
    return pos1.line < pos2.line 
  else 
    return false 
  end
end

-- Enhanced toggle and play with error handling and status feedback
function PakettiToggleLoopBlockAndPlay()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_warning("No song available")
    return
  end
  
  local transport = song.transport
  
  if transport.loop_block_enabled then
    transport.loop_block_enabled = false
    renoise.app():show_status("Loop Block disabled")
    print("-- Paketti Loop Block: Disabled loop block")
  else
    transport.loop_block_enabled = true
    transport.playing = true
    renoise.app():show_status("Loop Block enabled and playing")
    print("-- Paketti Loop Block: Enabled loop block and started playback")
  end
end

-- Enhanced next block selection with catch-up
function PakettiSelectNextLoopBlockAndCatchUp()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_warning("No song available")
    return
  end
  
  local transport = song.transport
  
  if not transport.loop_block_enabled then
    renoise.app():show_status("Loop Block not enabled")
    return
  end
  
  local playpos = transport.playback_pos
  if not playpos then
    renoise.app():show_warning("No playback position available")
    return
  end
  
  -- Safety check for valid sequence
  if playpos.sequence > #song.sequencer.pattern_sequence then
    renoise.app():show_warning("Invalid sequence position")
    return
  end
  
  local patt_idx = song.sequencer:pattern(playpos.sequence)
  local patt = song.patterns[patt_idx]
  local block_coeff = transport.loop_block_range_coeff
  local block_size = math.floor(patt.number_of_lines / block_coeff)
  local block_start = transport.loop_block_start_pos
  
  if not block_start then
    renoise.app():show_warning("No loop block start position")
    return
  end
  
  local block_end = {
    sequence = block_start.sequence, 
    line = block_start.line + block_size
  }
  
  local within = paketti_pos_le(block_start, playpos) and paketti_pos_lt(playpos, block_end)
  
  -- Move to next block
  transport:loop_block_move_forwards()
  
  -- Catch up playback position if it was within the block
  if within and transport.playing then
    local new_playpos = {
      sequence = playpos.sequence,
      line = playpos.line + block_size
    }
    
    -- Ensure we don't go beyond pattern length
    if new_playpos.line < patt.number_of_lines then
      transport.playback_pos = new_playpos
      renoise.app():show_status(string.format("Moved to next loop block (caught up to line %d)", new_playpos.line))
      print(string.format("-- Paketti Loop Block: Moved to next block, caught up playback to line %d", new_playpos.line))
    else
      renoise.app():show_status("Moved to next loop block (reached pattern end)")
      print("-- Paketti Loop Block: Moved to next block, reached pattern end")
    end
  else
    renoise.app():show_status("Moved to next loop block")
    print("-- Paketti Loop Block: Moved to next block")
  end
end

-- New: Previous block selection with catch-up
function PakettiSelectPreviousLoopBlockAndCatchUp()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_warning("No song available")
    return
  end
  
  local transport = song.transport
  
  if not transport.loop_block_enabled then
    renoise.app():show_status("Loop Block not enabled")
    return
  end
  
  local playpos = transport.playback_pos
  if not playpos then
    renoise.app():show_warning("No playback position available")
    return
  end
  
  -- Safety check for valid sequence
  if playpos.sequence > #song.sequencer.pattern_sequence then
    renoise.app():show_warning("Invalid sequence position")
    return
  end
  
  local patt_idx = song.sequencer:pattern(playpos.sequence)
  local patt = song.patterns[patt_idx]
  local block_coeff = transport.loop_block_range_coeff
  local block_size = math.floor(patt.number_of_lines / block_coeff)
  local block_start = transport.loop_block_start_pos
  
  if not block_start then
    renoise.app():show_warning("No loop block start position")
    return
  end
  
  local block_end = {
    sequence = block_start.sequence, 
    line = block_start.line + block_size
  }
  
  local within = paketti_pos_le(block_start, playpos) and paketti_pos_lt(playpos, block_end)
  
  -- Move to previous block
  transport:loop_block_move_backwards()
  
  -- Catch up playback position if it was within the block
  if within and transport.playing then
    local new_playpos = {
      sequence = playpos.sequence,
      line = playpos.line - block_size
    }
    
    -- Ensure we don't go below 1
    if new_playpos.line >= 1 then
      transport.playback_pos = new_playpos
      renoise.app():show_status(string.format("Moved to previous loop block (caught up to line %d)", new_playpos.line))
      print(string.format("-- Paketti Loop Block: Moved to previous block, caught up playback to line %d", new_playpos.line))
    else
      renoise.app():show_status("Moved to previous loop block (reached pattern start)")
      print("-- Paketti Loop Block: Moved to previous block, reached pattern start")
    end
  else
    renoise.app():show_status("Moved to previous loop block")
    print("-- Paketti Loop Block: Moved to previous block")
  end
end

-- New: Set loop block to current playback position
function PakettiSetLoopBlockToPlaybackPosition()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_warning("No song available")
    return
  end
  
  local transport = song.transport
  local playpos = transport.playback_pos
  
  if not playpos then
    renoise.app():show_warning("No playback position available")
    return
  end
  
  -- Enable loop block if not already enabled
  if not transport.loop_block_enabled then
    transport.loop_block_enabled = true
  end
  
  -- Set loop block start to current playback position
  transport.loop_block_start_pos = playpos
  
  renoise.app():show_status(string.format("Set loop block to sequence %d, line %d", playpos.sequence, playpos.line))
  print(string.format("-- Paketti Loop Block: Set loop block to sequence %d, line %d", playpos.sequence, playpos.line))
end

-- New: Get current loop block info
function PakettiShowLoopBlockInfo()
  local song = renoise.song()
  
  if not song then
    renoise.app():show_warning("No song available")
    return
  end
  
  local transport = song.transport
  
  if not transport.loop_block_enabled then
    renoise.app():show_message("Loop Block is disabled")
    return
  end
  
  local playpos = transport.playback_pos
  local block_start = transport.loop_block_start_pos
  local block_coeff = transport.loop_block_range_coeff
  
  if not playpos or not block_start then
    renoise.app():show_warning("Position information not available")
    return
  end
  
  local patt_idx = song.sequencer:pattern(playpos.sequence)
  local patt = song.patterns[patt_idx]
  local block_size = math.floor(patt.number_of_lines / block_coeff)
  
  local info = string.format(
    "Loop Block Info:\n\n" ..
    "Enabled: %s\n" ..
    "Start: Sequence %d, Line %d\n" ..
    "Block Size: %d lines\n" ..
    "Block Coefficient: %d\n" ..
    "Current Playback: Sequence %d, Line %d\n" ..
    "Pattern Length: %d lines",
    transport.loop_block_enabled and "Yes" or "No",
    block_start.sequence, block_start.line,
    block_size,
    block_coeff,
    playpos.sequence, playpos.line,
    patt.number_of_lines
  )
  
  renoise.app():show_message(info)
end

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Toggle Loop Block and Play (2.x style)",
  invoke = PakettiToggleLoopBlockAndPlay
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Select Next Loop Block (catch up)",
  invoke = PakettiSelectNextLoopBlockAndCatchUp
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Select Previous Loop Block (catch up)",
  invoke = PakettiSelectPreviousLoopBlockAndCatchUp
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Set Loop Block to Playback Position",
  invoke = PakettiSetLoopBlockToPlaybackPosition
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Loop Block Info",
  invoke = PakettiShowLoopBlockInfo
}

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Transport:Toggle Loop Block and Play (2.x style)",
  invoke = PakettiToggleLoopBlockAndPlay
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Transport:Select Next Loop Block (catch up)",
  invoke = PakettiSelectNextLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Transport:Select Previous Loop Block (catch up)",
  invoke = PakettiSelectPreviousLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Transport:Set Loop Block to Playback Position",
  invoke = PakettiSetLoopBlockToPlaybackPosition
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Transport:Show Loop Block Info",
  invoke = PakettiShowLoopBlockInfo
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Transport:Toggle Loop Block and Play (2.x style)",
  invoke = PakettiToggleLoopBlockAndPlay
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Transport:Select Next Loop Block (catch up)",
  invoke = PakettiSelectNextLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Transport:Select Previous Loop Block (catch up)",
  invoke = PakettiSelectPreviousLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Transport:Set Loop Block to Playback Position",
  invoke = PakettiSetLoopBlockToPlaybackPosition
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Transport:Show Loop Block Info",
  invoke = PakettiShowLoopBlockInfo
}

renoise.tool():add_menu_entry{
  name = "Pattern Matrix:Paketti:Transport:Toggle Loop Block and Play (2.x style)",
  invoke = PakettiToggleLoopBlockAndPlay
}

renoise.tool():add_menu_entry{
  name = "Pattern Matrix:Paketti:Transport:Select Next Loop Block (catch up)",
  invoke = PakettiSelectNextLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Pattern Matrix:Paketti:Transport:Select Previous Loop Block (catch up)",
  invoke = PakettiSelectPreviousLoopBlockAndCatchUp
}

renoise.tool():add_menu_entry{
  name = "Pattern Matrix:Paketti:Transport:Set Loop Block to Playback Position",
  invoke = PakettiSetLoopBlockToPlaybackPosition
}

renoise.tool():add_menu_entry{
  name = "Pattern Matrix:Paketti:Transport:Show Loop Block Info",
  invoke = PakettiShowLoopBlockInfo
}

-- MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Toggle Loop Block and Play (2.x style)",
  invoke = function(message) 
    if message:is_trigger() then 
      PakettiToggleLoopBlockAndPlay() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Select Next Loop Block (catch up)",
  invoke = function(message) 
    if message:is_trigger() then 
      PakettiSelectNextLoopBlockAndCatchUp() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Select Previous Loop Block (catch up)",
  invoke = function(message) 
    if message:is_trigger() then 
      PakettiSelectPreviousLoopBlockAndCatchUp() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Set Loop Block to Playback Position",
  invoke = function(message) 
    if message:is_trigger() then 
      PakettiSetLoopBlockToPlaybackPosition() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Show Loop Block Info",
  invoke = function(message) 
    if message:is_trigger() then 
      PakettiShowLoopBlockInfo() 
    end 
  end
}

-- ======================================
-- Paketti Sample Bitmap Visualizer
-- ======================================
-- Integrates danoise bitmap functions directly for cross-platform sample visualization

local sample_viz_dialog = nil

-- ======================================
-- INTEGRATED DANOISE BITMAP FUNCTIONS
-- ======================================
-- These functions are integrated from danoise for self-contained bitmap creation

-- Create a new bitmap structure
local function BMPCreate(width, height)
  if not width or not height or width <= 0 or height <= 0 then
    return nil
  end
  
  local bitmap = {
    width = width,
    height = height,
    data = {}
  }
  
  -- Initialize bitmap data (24-bit RGB)
  for y = 0, height - 1 do
    bitmap.data[y] = {}
    for x = 0, width - 1 do
      bitmap.data[y][x] = 0x000000 -- Black default
    end
  end
  
  return bitmap
end

-- Draw a pixel on the bitmap
local function DrawBitmap(bitmap, x, y, color)
  if not bitmap or not bitmap.data then
    return false
  end
  
  -- Bounds checking
  if x < 0 or x >= bitmap.width or y < 0 or y >= bitmap.height then
    return false
  end
  
  -- Set pixel color
  bitmap.data[y][x] = color
  return true
end

-- Convert bitmap to BMP file format (basic implementation)
local function BMPSave(bitmap, filename)
  if not bitmap or not bitmap.data then
    return false
  end
  
  -- This is a simplified BMP file format implementation
  -- In a real implementation, you'd write proper BMP headers and data
  local file = io.open(filename, "wb")
  if not file then
    return false
  end
  
  -- Write basic BMP header (simplified)
  local width = bitmap.width
  local height = bitmap.height
  local filesize = 54 + (width * height * 3) -- 54 byte header + RGB data
  
  -- BMP File Header (14 bytes)
  file:write("BM") -- Signature
  file:write(string.char(
    filesize % 256, math.floor(filesize / 256) % 256, 
    math.floor(filesize / 65536) % 256, math.floor(filesize / 16777216) % 256
  )) -- File size
  file:write(string.char(0, 0, 0, 0)) -- Reserved
  file:write(string.char(54, 0, 0, 0)) -- Data offset
  
  -- DIB Header (40 bytes)
  file:write(string.char(40, 0, 0, 0)) -- DIB header size
  file:write(string.char(
    width % 256, math.floor(width / 256) % 256, 
    math.floor(width / 65536) % 256, math.floor(width / 16777216) % 256
  )) -- Width
  file:write(string.char(
    height % 256, math.floor(height / 256) % 256, 
    math.floor(height / 65536) % 256, math.floor(height / 16777216) % 256
  )) -- Height
  file:write(string.char(1, 0)) -- Planes
  file:write(string.char(24, 0)) -- Bits per pixel
  file:write(string.char(0, 0, 0, 0)) -- Compression
  file:write(string.char(0, 0, 0, 0)) -- Image size
  file:write(string.char(0, 0, 0, 0)) -- X pixels per meter
  file:write(string.char(0, 0, 0, 0)) -- Y pixels per meter
  file:write(string.char(0, 0, 0, 0)) -- Colors used
  file:write(string.char(0, 0, 0, 0)) -- Important colors
  
  -- Write pixel data (bottom-up, BGR format)
  for y = height - 1, 0, -1 do
    for x = 0, width - 1 do
      local color = bitmap.data[y][x]
      local r = math.floor(color / 65536) % 256
      local g = math.floor(color / 256) % 256
      local b = color % 256
      file:write(string.char(b, g, r)) -- BGR format
    end
    -- Add padding if necessary (BMP rows must be multiple of 4 bytes)
    local padding = (4 - ((width * 3) % 4)) % 4
    for i = 1, padding do
      file:write(string.char(0))
    end
  end
  
  file:close()
  return true
end

-- Save bitmap and update display in dialog
local function saveAndDisplayBitmap(bitmap, base_filename, vb_views)
  if not bitmap then
    return false, "No bitmap to save"
  end
  
  local filename = base_filename .. ".bmp"
  
  if BMPSave(bitmap, filename) then
    -- Get the absolute path of where we saved it
    local absolute_path = io.popen("pwd"):read("*l") or ""
    if absolute_path == "" and package.config:sub(1,1) == '\\' then
      -- Windows fallback
      absolute_path = io.popen("cd"):read("*l") or ""
    end
    
    -- Update the bitmap display in the dialog
    if vb_views and vb_views.bitmap_display then
      vb_views.bitmap_display.bitmap = filename
    end
    
    return true, filename, absolute_path
  else
    return false, "Failed to save bitmap file", nil
  end
end

-- Add support for multiple formats if needed (BMP/PNG/TIF)
local function getBestImageFormat()
  -- Renoise supports BMP, PNG, TIF - BMP is what we've implemented
  return "bmp"
end

-- Get bitmap info
local function BMPGetInfo(bitmap)
  if not bitmap then
    return nil
  end
  
  return {
    width = bitmap.width,
    height = bitmap.height,
    pixels = bitmap.width * bitmap.height,
    size_bytes = bitmap.width * bitmap.height * 3
  }
end

-- Create bitmap from sample data
local function createSampleBitmap(sample_buffer, width, height)
  if not sample_buffer.has_sample_data then
    return nil
  end
  
  -- Create bitmap using integrated BMPCreate
  local bitmap = BMPCreate(width, height)
  if not bitmap then
    print("-- Paketti Sample Visualizer: Failed to create bitmap")
    return nil
  end
  
  -- Clear bitmap to black background
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      DrawBitmap(bitmap, x, y, 0x000000) -- Black background
    end
  end
  
  local num_frames = sample_buffer.number_of_frames
  local num_channels = sample_buffer.number_of_channels
  
  if num_frames == 0 then
    return bitmap
  end
  
  -- Draw waveform
  local x_scale = num_frames / width
  local y_center = height / 2
  local y_scale = (height / 2) * 0.8 -- Leave some margin
  
  for x = 0, width - 1 do
    local frame_pos = math.floor(x * x_scale) + 1
    frame_pos = math.min(frame_pos, num_frames)
    
    -- Get sample value (use first channel for now)
    local sample_value = sample_buffer:sample_data(1, frame_pos)
    
    -- Convert to screen coordinates
    local y = math.floor(y_center - (sample_value * y_scale))
    y = math.max(0, math.min(height - 1, y))
    
    -- Draw waveform in green
    DrawBitmap(bitmap, x, y, 0x00FF00) -- Green waveform
    
    -- Draw center line for reference
    if x % 10 == 0 then
      DrawBitmap(bitmap, x, y_center, 0x404040) -- Dark gray center line
    end
  end
  
  -- Draw amplitude markers
  for i = 1, 4 do
    local y_pos = math.floor(y_center + (i * y_scale / 4))
    if y_pos < height then
      for x = 0, width - 1, 20 do
        DrawBitmap(bitmap, x, y_pos, 0x202020) -- Dark gray amplitude lines
      end
    end
    
    y_pos = math.floor(y_center - (i * y_scale / 4))
    if y_pos >= 0 then
      for x = 0, width - 1, 20 do
        DrawBitmap(bitmap, x, y_pos, 0x202020) -- Dark gray amplitude lines
      end
    end
  end
  
  return bitmap
end

-- Create enhanced bitmap (currently just adds a marker - text rendering not implemented)
local function createEnhancedSampleBitmap(sample_buffer, width, height)
  local bitmap = createSampleBitmap(sample_buffer, width, height)
  if not bitmap then
    return nil
  end
  
  -- Add a simple visual marker to show this is "enhanced" mode
  -- Draw a small indicator in top-right corner
  for y = 5, 15 do
    for x = width - 20, width - 5 do
      if x >= 0 and x < width and y >= 0 and y < height then
        DrawBitmap(bitmap, x, y, 0xFF0000) -- Red marker
      end
    end
  end
  
  -- Simple frequency estimation (very basic)
  local num_frames = sample_buffer.number_of_frames
  local sample_rate = sample_buffer.sample_rate
  
  if num_frames > 0 then
    local estimated_freq = sample_rate / num_frames
    print(string.format("-- Sample Visualizer Enhanced: Estimated frequency %.1f Hz (very rough calculation)", estimated_freq))
    print("-- Sample Visualizer Enhanced: Red marker added to top-right corner")
  end
  
  return bitmap
end

-- Main sample visualizer dialog
function pakettiSampleVisualizerDialog()
  if sample_viz_dialog and sample_viz_dialog.visible then 
    sample_viz_dialog:close() 
    return 
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_warning("No sample data available for visualization")
    return
  end
  
  local vb = renoise.ViewBuilder()
  local bitmap_width = 1024
  local sampleWidth = 1024
  local bitmap_height = 512
  local current_bitmap = nil
  local last_saved_file = nil
  local last_saved_path = nil
  local temp_filename = string.format("temp_sample_%s_%d", 
    sample.name:gsub("[^%w_-]", "_"), 
    os.time())
  
  -- Create initial bitmap
  current_bitmap = createSampleBitmap(sample.sample_buffer, bitmap_width, bitmap_height)
  
  if not current_bitmap then
    renoise.app():show_warning("Failed to create sample bitmap")
    return
  end
  
  -- Save initial bitmap for display
  local success, initial_file, initial_path = saveAndDisplayBitmap(current_bitmap, temp_filename, nil)
  if not success then
    renoise.app():show_warning("Failed to save initial bitmap for display")
    return
  end
  last_saved_path = initial_path
  
  -- Create info text
  local buffer = sample.sample_buffer
  local info_text = string.format(
    "Sample: %s\nFrames: %d\nChannels: %d\nSample Rate: %d Hz\nLength: %.2f seconds",
    sample.name,
    buffer.number_of_frames,
    buffer.number_of_channels,
    buffer.sample_rate,
    buffer.number_of_frames / buffer.sample_rate
  )
  
  sample_viz_dialog = renoise.app():show_custom_dialog(
    "Paketti Sample Visualizer",
    vb:column{
      margin = 10,
      spacing = 10,
      
      vb:row{
        vb:text{
          text = "Sample Waveform Visualization",
          font = "bold",
          style = "strong"
        }
      },
      
      vb:row{
        vb:text{
          text = info_text,
          width = sampleWidth
        }
      },
      
      -- Actual bitmap display!
      vb:row{
        vb:column{
          vb:text{
            text = string.format("Sample Waveform (%dx%d pixels)", bitmap_width, bitmap_height),
            style = "strong"
          },
          vb:bitmap{
            bitmap = initial_file,
            mode = "plain",
            id = "bitmap_display"
          }
        }
      },
      
      -- Color legend and info
      vb:row{
        vb:text{
          text = "🟢 Green=Waveform • ⚫ Dark Gray=Reference Lines • ⚫ Black=Background • 🔴 Red=Enhanced marker\nRefresh=Update for current sample • Enhanced=Add red marker + basic frequency estimate",
          width = sampleWidth,
          style = "disabled"
        }
      },
      
      vb:row{
        vb:text{
          text = string.format("Save Path: %s\nLast Saved: %s", initial_path or "Unknown", initial_file),
          width = sampleWidth,
          id = "save_path_text"
        }
      },
      
      vb:horizontal_aligner{
        mode = "center",
        vb:row{
          vb:button{
            text = "Refresh",
            width = 80,
            tooltip = "Update visualization for currently selected sample",
            notifier = function()
              local current_sample = renoise.song().selected_sample
              if current_sample and current_sample.sample_buffer.has_sample_data then
                current_bitmap = createSampleBitmap(current_sample.sample_buffer, bitmap_width, bitmap_height)
                if current_bitmap then
                  -- Save and update display
                  local refresh_filename = string.format("temp_sample_%s_refresh_%d", 
                    current_sample.name:gsub("[^%w_-]", "_"), 
                    os.time())
                  local success, filename, filepath = saveAndDisplayBitmap(current_bitmap, refresh_filename, vb.views)
                  if success then
                    last_saved_path = filepath
                    vb.views.save_path_text.text = string.format("Save Path: %s\nLast Saved: %s", filepath or "Unknown", filename)
                    renoise.app():show_status("Sample bitmap refreshed and displayed")
                    print("-- Paketti Sample Visualizer: Bitmap refreshed and displayed")
                  else
                    renoise.app():show_warning("Failed to update bitmap display")
                  end
                else
                  renoise.app():show_warning("Failed to refresh bitmap")
                end
              else
                renoise.app():show_warning("No sample data to refresh")
              end
            end
          },
          --[[
          vb:button{
            text = "Enhanced",
            width = 80,
            tooltip = "Adds red marker and basic frequency estimation (console output only)",
            notifier = function()
              local current_sample = renoise.song().selected_sample
              if current_sample and current_sample.sample_buffer.has_sample_data then
                current_bitmap = createEnhancedSampleBitmap(current_sample.sample_buffer, bitmap_width, bitmap_height)
                if current_bitmap then
                  -- Save and update display
                  local enhanced_filename = string.format("temp_sample_%s_enhanced_%d", 
                    current_sample.name:gsub("[^%w_-]", "_"), 
                    os.time())
                  local success, filename, filepath = saveAndDisplayBitmap(current_bitmap, enhanced_filename, vb.views)
                  if success then
                    last_saved_path = filepath
                    vb.views.save_path_text.text = string.format("Save Path: %s\nLast Saved: %s", filepath or "Unknown", filename)
                    renoise.app():show_status("Enhanced sample bitmap with red marker and basic frequency estimation created")
                    print("-- Paketti Sample Visualizer: Enhanced bitmap with red marker created")
                  else
                    renoise.app():show_warning("Failed to update enhanced bitmap display")
                  end
                else
                  renoise.app():show_warning("Failed to create enhanced bitmap")
                end
              else
                renoise.app():show_warning("No sample data for enhanced visualization")
              end
            end
          },
          ]]--
          vb:button{
            text = "Save File",
            width = 80,
            tooltip = "Save current visualization as BMP file to disk",
            notifier = function()
              if current_bitmap then
                local filename = string.format("sample_%s_%d", 
                  sample.name:gsub("[^%w_-]", "_"), 
                  os.time())
                
                -- Use integrated BMPSave function
                local success, saved_filename, saved_path = saveAndDisplayBitmap(current_bitmap, filename, nil)
                if success then
                  last_saved_file = saved_filename
                  last_saved_path = saved_path
                  vb.views.save_path_text.text = string.format("Save Path: %s\nLast Saved: %s", saved_path or "Unknown", saved_filename)
                  renoise.app():show_status(string.format("Bitmap saved as %s", saved_filename))
                  print(string.format("-- Paketti Sample Visualizer: Saved bitmap as %s in %s", saved_filename, saved_path or "unknown location"))
                else
                  renoise.app():show_warning("Failed to save bitmap file")
                  print("-- Paketti Sample Visualizer: Failed to save bitmap file")
                end
              else
                renoise.app():show_warning("No bitmap to save")
              end
            end
          },
          
          vb:button{
            text = "Open Path",
            width = 80,
            tooltip = "Open folder containing saved BMP files in your file explorer",
            notifier = function()
              if last_saved_path and last_saved_path ~= "" then
                -- Try to open the directory in file explorer
                local command = ""
                if os.platform then
                  if os.platform() == "WINDOWS" then
                    command = string.format('start "" "%s"', last_saved_path)
                  elseif os.platform() == "MACINTOSH" then
                    command = string.format('open "%s"', last_saved_path)
                  else -- Linux
                    command = string.format('xdg-open "%s"', last_saved_path)
                  end
                else
                  -- Fallback detection
                  if package.config:sub(1,1) == '\\' then
                    -- Windows
                    command = string.format('start "" "%s"', last_saved_path)
                  else
                    -- Unix-like (macOS/Linux)
                    command = string.format('open "%s" 2>/dev/null || xdg-open "%s"', last_saved_path, last_saved_path)
                  end
                end
                
                if command ~= "" then
                  os.execute(command)
                  renoise.app():show_status(string.format("Opened directory: %s", last_saved_path))
                  print(string.format("-- Paketti Sample Visualizer: Opened directory: %s", last_saved_path))
                else
                  renoise.app():show_warning("Cannot open directory on this platform")
                end
              else
                renoise.app():show_warning("No saved files yet - save a file first, then use Open Path")
              end
            end
          },
          
          vb:button{
            text = "Close",
            width = 80,
            tooltip = "Close the sample visualizer dialog",
            notifier = function()
              sample_viz_dialog:close()
            end
          }
        }
      },
      
      vb:row{
        vb:text{
          text = "Platform Support: Linux, macOS, Windows (integrated bitmap functions)\nBitmap is displayed above AND saved to disk. Use 'Open Path' for saved files.",
          width = sampleWidth,
          font = "italic",
          style = "disabled"
        }
      }
    }
  )
  
  print("-- Paketti Sample Visualizer: Dialog opened")
  print(string.format("-- Paketti Sample Visualizer: Created %dx%d bitmap for sample '%s'", 
    bitmap_width, bitmap_height, sample.name))
  print("-- Paketti Sample Visualizer: Displaying bitmap directly in dialog (Renoise supports BMP/PNG/TIF)")
  
  -- Show save path info
  print(string.format("-- Paketti Sample Visualizer: BMP files will be saved to: %s", initial_path or "Unknown"))
  
  -- Show bitmap info
  local bitmap_info = BMPGetInfo(current_bitmap)
  if bitmap_info then
    print(string.format("-- Paketti Sample Visualizer: Bitmap info - %d total pixels, %d bytes", 
      bitmap_info.pixels, bitmap_info.size_bytes))
  end
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Sample:Visualize Sample (Bitmap)",
  invoke = pakettiSampleVisualizerDialog
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Visualize Sample (Bitmap)",
  invoke = pakettiSampleVisualizerDialog
}

-- Keybinding
renoise.tool():add_keybinding{
  name = "Global:Paketti:Sample Visualizer (Bitmap)",
  invoke = pakettiSampleVisualizerDialog
}

-- MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Sample Visualizer (Bitmap)",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiSampleVisualizerDialog() 
    end 
  end
}

-- ======================================
-- Paketti Phrase Looping Batch Operations
-- ======================================
-- Based on danoise PhraseProps.lua - batch operations for phrase looping settings

-- Disable looping in all phrases of the selected instrument
function pakettiDisableAllPhraseLooping()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return
  end
  
  local disabled_count = 0
  for i, phrase in ipairs(instr.phrases) do
    if phrase.mapping.looping then
      phrase.mapping.looping = false
      disabled_count = disabled_count + 1
    end
  end
  
  if disabled_count > 0 then
    renoise.app():show_status(string.format("Disabled looping in %d phrase(s) of instrument '%s'", disabled_count, instr.name))
    print(string.format("-- Paketti Phrase Looping: Disabled looping in %d phrase(s) of instrument '%s'", disabled_count, instr.name))
  else
    renoise.app():show_status("No phrases had looping enabled")
    print("-- Paketti Phrase Looping: No phrases had looping enabled")
  end
end

-- Enable looping in all phrases of the selected instrument
function pakettiEnableAllPhraseLooping()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return
  end
  
  local enabled_count = 0
  for i, phrase in ipairs(instr.phrases) do
    if not phrase.mapping.looping then
      phrase.mapping.looping = true
      enabled_count = enabled_count + 1
    end
  end
  
  if enabled_count > 0 then
    renoise.app():show_status(string.format("Enabled looping in %d phrase(s) of instrument '%s'", enabled_count, instr.name))
    print(string.format("-- Paketti Phrase Looping: Enabled looping in %d phrase(s) of instrument '%s'", enabled_count, instr.name))
  else
    renoise.app():show_status("All phrases already had looping enabled")
    print("-- Paketti Phrase Looping: All phrases already had looping enabled")
  end
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Phrases:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Phrases:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Phrases:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Phrases:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Phrase Editor:Paketti:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Phrase Editor:Paketti:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

-- MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Disable Looping in All Phrases",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiDisableAllPhraseLooping() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Enable Looping in All Phrases",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiEnableAllPhraseLooping() 
    end 
  end
}

-- ======================================
-- Paketti Sample Loop Points Batch Operations
-- ======================================
-- Based on danoise Copy Loop Points.lua - batch operations for sample loop settings

-- Copy loop points from current instrument to all other compatible instruments
function pakettiCopyCurrentLoopPointsGlobally()
  local song = renoise.song()
  local src_instr = song.selected_instrument
  local src_idx = song.selected_instrument_index
  
  if not src_instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #src_instr.samples == 0 then
    renoise.app():show_warning("Selected instrument has no samples")
    return
  end
  
  local instruments_modified = 0
  local samples_modified = 0
  
  for target_idx = 1, #song.instruments do
    if target_idx ~= src_idx then
      local target_instr = song.instruments[target_idx]
      
      -- Only copy to instruments with the same number of samples
      if #target_instr.samples == #src_instr.samples then
        local instrument_had_changes = false
        
        for sample_idx = 1, #src_instr.samples do
          local src_sample = src_instr.samples[sample_idx]
          local target_sample = target_instr.samples[sample_idx]
          
          if src_sample and target_sample and src_sample.sample_buffer.has_sample_data and target_sample.sample_buffer.has_sample_data then
            local src_frames = src_sample.sample_buffer.number_of_frames
            local target_frames = target_sample.sample_buffer.number_of_frames
            
            -- Calculate safe loop points for target sample
            local safe_loop_start, safe_loop_end
            
            if src_frames > 0 and target_frames > 0 then
              -- Proportionally scale loop points to target sample size
              local scale_factor = target_frames / src_frames
              safe_loop_start = math.floor(src_sample.loop_start * scale_factor)
              safe_loop_end = math.floor(src_sample.loop_end * scale_factor)
              
              -- Clamp to valid ranges
              safe_loop_start = math.max(1, math.min(safe_loop_start, target_frames))
              
              -- If trying to set loop_end to a frame that doesn't exist, set it to maxFrames
              if safe_loop_end > target_frames then
                safe_loop_end = target_frames
              end
              
              -- Ensure loop_start < loop_end
              if safe_loop_end <= safe_loop_start then
                safe_loop_end = math.min(safe_loop_start + 100, target_frames)
              end
            else
              -- Fallback for samples without data
              safe_loop_start = 1
              safe_loop_end = target_frames
            end
            
            -- If trying to set loop_start+loop_end to frames that don't exist, skip that sample
            if safe_loop_start >= target_frames or safe_loop_end <= 1 or safe_loop_start >= safe_loop_end then
              print(string.format("-- Paketti Loop Points: Skipped sample %d in '%s' (invalid loop points)", sample_idx, target_instr.name))
            else
              -- Check if any loop settings are different
              local needs_update = (target_sample.loop_mode ~= src_sample.loop_mode) or
                                  (target_sample.loop_start ~= safe_loop_start) or
                                  (target_sample.loop_end ~= safe_loop_end)
              
              if needs_update then
                target_sample.loop_mode = src_sample.loop_mode
                target_sample.loop_start = safe_loop_start
                target_sample.loop_end = safe_loop_end
                samples_modified = samples_modified + 1
                instrument_had_changes = true
                
                -- Log the scaling for debugging
                if src_frames ~= target_frames then
                  print(string.format("-- Paketti Loop Points: Scaled loop %d-%d (src:%d frames) to %d-%d (target:%d frames)", 
                    src_sample.loop_start, src_sample.loop_end, src_frames, safe_loop_start, safe_loop_end, target_frames))
                end
              end
            end
          end
        end
        
        if instrument_had_changes then
          instruments_modified = instruments_modified + 1
          print(string.format("-- Paketti Loop Points: Copied loop settings from '%s' to '%s' (%d samples)", 
            src_instr.name, target_instr.name, #src_instr.samples))
        end
      end
    end
  end
  
  if instruments_modified > 0 then
    renoise.app():show_status(string.format("Copied loop points from '%s' to %d compatible instrument(s), %d sample(s) updated", 
      src_instr.name, instruments_modified, samples_modified))
    print(string.format("-- Paketti Loop Points: Operation completed - %d instruments, %d samples updated", 
      instruments_modified, samples_modified))
  else
    renoise.app():show_status("No compatible instruments found (same sample count required)")
    print("-- Paketti Loop Points: No compatible instruments found with matching sample count")
  end
end

-- Copy loop points from current sample to all samples in current instrument
function pakettiCopyCurrentSampleLoopPointsToAllSamples()
  local song = renoise.song()
  local instr = song.selected_instrument
  local src_sample = song.selected_sample
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if not src_sample or not src_sample.sample_buffer.has_sample_data then
    renoise.app():show_warning("No valid sample selected")
    return
  end
  
  if #instr.samples <= 1 then
    renoise.app():show_status("Instrument has only one sample")
    return
  end
  
  local src_frames = src_sample.sample_buffer.number_of_frames
  local samples_modified = 0
  local samples_skipped = 0
  
  for sample_idx = 1, #instr.samples do
    local target_sample = instr.samples[sample_idx]
    
    -- Don't copy to self
    if target_sample ~= src_sample and target_sample.sample_buffer.has_sample_data then
      local target_frames = target_sample.sample_buffer.number_of_frames
      
      if src_frames > 0 and target_frames > 0 then
        -- Proportionally scale loop points to target sample size
        local scale_factor = target_frames / src_frames
        local safe_loop_start = math.floor(src_sample.loop_start * scale_factor)
        local safe_loop_end = math.floor(src_sample.loop_end * scale_factor)
        
        -- Clamp to valid ranges
        safe_loop_start = math.max(1, math.min(safe_loop_start, target_frames))
        
        -- If trying to set loop_end to a frame that doesn't exist, set it to maxFrames
        if safe_loop_end > target_frames then
          safe_loop_end = target_frames
        end
        
        -- Ensure loop_start < loop_end
        if safe_loop_end <= safe_loop_start then
          safe_loop_end = math.min(safe_loop_start + 100, target_frames)
        end
        
        -- If trying to set loop_start+loop_end to frames that don't exist, skip that sample
        if safe_loop_start >= target_frames or safe_loop_end <= 1 or safe_loop_start >= safe_loop_end then
          samples_skipped = samples_skipped + 1
          print(string.format("-- Paketti Loop Points: Skipped sample %d '%s' (invalid loop points)", sample_idx, target_sample.name))
        else
          -- Check if any loop settings are different
          local needs_update = (target_sample.loop_mode ~= src_sample.loop_mode) or
                              (target_sample.loop_start ~= safe_loop_start) or
                              (target_sample.loop_end ~= safe_loop_end)
          
          if needs_update then
            target_sample.loop_mode = src_sample.loop_mode
            target_sample.loop_start = safe_loop_start
            target_sample.loop_end = safe_loop_end
            samples_modified = samples_modified + 1
            
            -- Log the scaling for debugging
            if src_frames ~= target_frames then
              print(string.format("-- Paketti Loop Points: Scaled loop %d-%d (src:%d frames) to %d-%d (target:%d frames) for sample '%s'", 
                src_sample.loop_start, src_sample.loop_end, src_frames, safe_loop_start, safe_loop_end, target_frames, target_sample.name))
            end
          end
        end
      else
        samples_skipped = samples_skipped + 1
      end
    end
  end
  
  if samples_modified > 0 then
    renoise.app():show_status(string.format("Copied loop points from '%s' to %d sample(s) in '%s'", src_sample.name, samples_modified, instr.name))
    print(string.format("-- Paketti Loop Points: Applied to %d samples, skipped %d samples", samples_modified, samples_skipped))
  else
    renoise.app():show_status("No samples needed loop point updates")
    print("-- Paketti Loop Points: No samples needed updates")
  end
end


-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Samples:Copy Current Loop Points to All Compatible Instruments",
  invoke = pakettiCopyCurrentLoopPointsGlobally
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Samples:Copy Current Sample Loop Points to All Samples",
  invoke = pakettiCopyCurrentSampleLoopPointsToAllSamples
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Copy Current Loop Points to All Compatible Instruments",
  invoke = pakettiCopyCurrentLoopPointsGlobally
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Copy Current Sample Loop Points to All Samples",
  invoke = pakettiCopyCurrentSampleLoopPointsToAllSamples
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Copy Current Loop Points to All Compatible Instruments",
  invoke = pakettiCopyCurrentLoopPointsGlobally
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Copy Current Sample Loop Points to All Samples",
  invoke = pakettiCopyCurrentSampleLoopPointsToAllSamples
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Copy Current Loop Points to All Compatible Instruments",
  invoke = pakettiCopyCurrentLoopPointsGlobally
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Copy Current Sample Loop Points to All Samples",
  invoke = pakettiCopyCurrentSampleLoopPointsToAllSamples
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Copy Current Loop Points to All Compatible Instruments",
  invoke = pakettiCopyCurrentLoopPointsGlobally
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Copy Current Sample Loop Points to All Samples",
  invoke = pakettiCopyCurrentSampleLoopPointsToAllSamples
}


-- MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Copy Current Loop Points to All Compatible Instruments",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiCopyCurrentLoopPointsGlobally() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Copy Current Sample Loop Points to All Samples",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiCopyCurrentSampleLoopPointsToAllSamples() 
    end 
  end
}

