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
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Auto-Hide Disk Browser on Song Load",
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
  
  local filename = base_filename
  
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
    renoise.app():show_status("No sample data available for visualization")
    return
  end
  
  local vb = renoise.ViewBuilder()
  local bitmap_width = 1024
  local sampleWidth = 1024
  local bitmap_height = 512
  local current_bitmap = nil
  local last_saved_file = nil
  local last_saved_path = nil
  local temp_filename = os.tmpname() .. ".bmp"
  
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
  local channel_text = buffer.number_of_channels == 1 and "Mono" or "Stereo"
  local total_seconds = buffer.number_of_frames / buffer.sample_rate
  local minutes = math.floor(total_seconds / 60)
  local seconds = math.floor(total_seconds % 60)
  local info_text = string.format(
    "%s, %d Hz, %d-bit, %s, %d:%02d seconds (%d Frames)",
    sample.name,
    buffer.sample_rate,
    buffer.bit_depth,
    channel_text,
    minutes,
    seconds,
    buffer.number_of_frames
  )
  
  sample_viz_dialog = renoise.app():show_custom_dialog(
    string.format("Paketti Sample Visualizer (%dx%d)", bitmap_width, bitmap_height),
          vb:column{
        margin = 10,
        
        
        vb:row{
          vb:text{
            text = info_text,
            width = sampleWidth
          }
        },
      
              -- Actual bitmap display!
        vb:row{
          vb:column{
            vb:bitmap{
              bitmap = initial_file,
              mode = "plain",
              id = "bitmap_display"
            }
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
                  local refresh_filename = os.tmpname() .. ".bmp"
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
                  local enhanced_filename = os.tmpname() .. ".bmp"
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

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Visualize Sample (Bitmap)",invoke = pakettiSampleVisualizerDialog}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Xperimental/Work in Progress:Visualize Sample (Bitmap)",invoke = pakettiSampleVisualizerDialog}
renoise.tool():add_menu_entry{name = "--Sample Editor Ruler:Visualize Sample (Bitmap)",invoke = pakettiSampleVisualizerDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Sample Visualizer (Bitmap)",invoke = pakettiSampleVisualizerDialog}
renoise.tool():add_midi_mapping{name = "Paketti:Sample Visualizer (Bitmap)",invoke = function(message) if message:is_trigger() then pakettiSampleVisualizerDialog() end  end}

-- ======================================
-- Paketti Instrument MetaInfo
-- ======================================
-- Comprehensive instrument metadata viewing and editing

local instrument_info_dialog = nil

-- Quick instrument info status
function pakettiInstrumentInfoStatus()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local phrase_count = #instr.phrases
  local memory_usage = 0
  local slice_count = 0
  local real_sample_count = 0
  
  -- Calculate total memory usage, real sample count, and slice count
  for i, sample in ipairs(instr.samples) do
    if sample.sample_buffer.has_sample_data then
      -- Only count memory for non-slice-alias samples to avoid double counting
      if not sample.is_slice_alias then
        local frames = sample.sample_buffer.number_of_frames
        local channels = sample.sample_buffer.number_of_channels
        local bit_depth = sample.sample_buffer.bit_depth
        memory_usage = memory_usage + (frames * channels * (bit_depth / 8))
        real_sample_count = real_sample_count + 1
      end
    else
      -- Count samples without data as real samples too
      if not sample.is_slice_alias then
        real_sample_count = real_sample_count + 1
      end
    end
    -- Count slices (only from first sample to avoid counting aliases)
    if i == 1 and sample.slice_markers then
      slice_count = #sample.slice_markers
    end
  end
  
  -- Format memory usage
  local memory_text = ""
  if memory_usage > 1024 * 1024 then
    memory_text = string.format("%.1f MB", memory_usage / (1024 * 1024))
  elseif memory_usage > 1024 then
    memory_text = string.format("%.1f KB", memory_usage / 1024)
  else
    memory_text = string.format("%d bytes", memory_usage)
  end
  
  -- Get selected sample info
  local selected_sample = song.selected_sample
  local selected_sample_info = ""
  local selected_slice_info = ""
  
  if selected_sample and selected_sample.sample_buffer.has_sample_data then
    local sel_frames = selected_sample.sample_buffer.number_of_frames
    local sel_channels = selected_sample.sample_buffer.number_of_channels
    local sel_memory = sel_frames * sel_channels * (selected_sample.sample_buffer.bit_depth / 8)
    
    local sel_memory_text = ""
    if sel_memory > 1024 * 1024 then
      sel_memory_text = string.format("%.1f MB", sel_memory / (1024 * 1024))
    elseif sel_memory > 1024 then
      sel_memory_text = string.format("%.1f KB", sel_memory / 1024)
    else
      sel_memory_text = string.format("%d bytes", sel_memory)
    end
    
    selected_sample_info = string.format(", Selected: %s", sel_memory_text)
    
    -- Check if selected sample is a slice alias
    if selected_sample.is_slice_alias and instr.samples[1] and instr.samples[1].slice_markers then
      local slice_index = song.selected_sample_index - 1 -- slice aliases start from sample 2
      if slice_index >= 1 and slice_index <= #instr.samples[1].slice_markers then
        selected_slice_info = string.format(" (Slice %d)", slice_index)
      end
    end
  end
  
  -- Get comments (if any)
  local comments_text = ""
  if #instr.comments > 0 then
    local first_comment = instr.comments[1] or ""
    if #first_comment > 30 then
      comments_text = " [" .. first_comment:sub(1, 30) .. "...]"
    elseif #first_comment > 0 then
      comments_text = " [" .. first_comment .. "]"
    end
  end
  
  -- Build status text with better slice handling
  local sample_slice_text = ""
  if slice_count > 0 then
    -- When slices are present, emphasize the relationship
    if real_sample_count == 1 then
      sample_slice_text = string.format("%d sample with %d slices", real_sample_count, slice_count)
    else
      sample_slice_text = string.format("%d samples with %d slices", real_sample_count, slice_count)
    end
  else
    -- No slices, just show sample count
    sample_slice_text = string.format("%d samples", real_sample_count)
  end
  
  local status_text = string.format("%s: %s, %d phrases, %s%s%s%s", 
    instr.name, sample_slice_text, phrase_count, memory_text, selected_sample_info, selected_slice_info, comments_text)
  
  renoise.app():show_status(status_text)
  print("-- Paketti Instrument Info: " .. status_text)
end

-- Full instrument info dialog
function pakettiInstrumentInfoDialog()
  if instrument_info_dialog and instrument_info_dialog.visible then 
    instrument_info_dialog:close() 
    return 
  end
  
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local vb = renoise.ViewBuilder()
  local dialog_width = 600
  local dialog_height = preferences.pakettiInstrumentInfoDialogHeight.value
  -- Calculate proportional heights based on total dialog height
  local comments_height = math.max(80, math.floor(dialog_height * 0.25))  -- 25% of dialog height, min 80
  local sample_details_height = math.max(120, math.floor(dialog_height * 0.4))  -- 40% of dialog height, min 120
  
  -- Calculate instrument statistics
  local phrase_count = #instr.phrases
  local memory_usage = 0
  local sample_details = {}
  local slice_count = 0
  local real_sample_count = 0
  
  for i, sample in ipairs(instr.samples) do
    if sample.sample_buffer.has_sample_data then
      local frames = sample.sample_buffer.number_of_frames
      local channels = sample.sample_buffer.number_of_channels
      local bit_depth = sample.sample_buffer.bit_depth
      local sample_rate = sample.sample_buffer.sample_rate
      local duration = frames / sample_rate
      local sample_memory = frames * channels * (bit_depth / 8)
      
      -- Only count memory for non-slice-alias samples to avoid double counting
      if not sample.is_slice_alias then
        memory_usage = memory_usage + sample_memory
        real_sample_count = real_sample_count + 1
      end
      
      local channel_text = channels == 1 and "Mono" or "Stereo"
      local minutes = math.floor(duration / 60)
      local seconds = math.floor(duration % 60)
      
      -- Add slice information for sample details
      local slice_info = ""
      if sample.slice_markers and #sample.slice_markers > 0 then
        slice_info = string.format(", %d slices", #sample.slice_markers)
        if i == 1 then slice_count = #sample.slice_markers end
      elseif sample.is_slice_alias then
        slice_info = " (slice alias)"
      end
      
      table.insert(sample_details, string.format("%02d: %s, %d Hz, %d-bit, %s, %d:%02d (%d frames)%s", 
        i, sample.name, sample_rate, bit_depth, channel_text, minutes, seconds, frames, slice_info))
    else
      -- Count samples without data as real samples too (if not slice aliases)
      if not sample.is_slice_alias then
        real_sample_count = real_sample_count + 1
      end
      table.insert(sample_details, string.format("%02d: %s (no data)", i, sample.name))
    end
  end
  
  -- Format memory usage
  local memory_text = ""
  if memory_usage > 1024 * 1024 then
    memory_text = string.format("%.2f MB", memory_usage / (1024 * 1024))
  elseif memory_usage > 1024 then
    memory_text = string.format("%.2f KB", memory_usage / 1024)
  else
    memory_text = string.format("%d bytes", memory_usage)
  end
  
  -- Get current comments
  local current_comments = table.concat(instr.comments, "\n")
  
  -- MIDI output info
  local midi_device = instr.midi_output_properties.device_name
  local midi_channel = instr.midi_output_properties.channel
  local midi_info = string.format("Device: %s, Channel: %d", 
    midi_device == "" and "None" or midi_device, midi_channel)
  
  -- Selected sample info
  local selected_sample = song.selected_sample
  local selected_info = "None selected"
  if selected_sample and selected_sample.sample_buffer.has_sample_data then
    local sel_frames = selected_sample.sample_buffer.number_of_frames
    local sel_channels = selected_sample.sample_buffer.number_of_channels
    local sel_memory = sel_frames * sel_channels * (selected_sample.sample_buffer.bit_depth / 8)
    local sel_duration = sel_frames / selected_sample.sample_buffer.sample_rate
    
    local sel_memory_text = ""
    if sel_memory > 1024 * 1024 then
      sel_memory_text = string.format("%.1f MB", sel_memory / (1024 * 1024))
    elseif sel_memory > 1024 then
      sel_memory_text = string.format("%.1f KB", sel_memory / 1024)
    else
      sel_memory_text = string.format("%d bytes", sel_memory)
    end
    
    local sel_minutes = math.floor(sel_duration / 60)
    local sel_seconds = math.floor(sel_duration % 60)
    local sel_channel_text = sel_channels == 1 and "Mono" or "Stereo"
    
    local slice_info = ""
    if selected_sample.is_slice_alias and instr.samples[1] and instr.samples[1].slice_markers then
      local slice_index = song.selected_sample_index - 1
      if slice_index >= 1 and slice_index <= #instr.samples[1].slice_markers then
        slice_info = string.format(" (Slice %d)", slice_index)
      end
    end
    
    selected_info = string.format("#%d: %s, %s, %d:%02d, %s%s", 
      song.selected_sample_index, selected_sample.name, sel_channel_text, 
      sel_minutes, sel_seconds, sel_memory_text, slice_info)
  end
  
  instrument_info_dialog = renoise.app():show_custom_dialog(
    string.format("Instrument MetaInfo - %s", instr.name),
    vb:column{
      margin = 10,
      
      
      -- Basic info
      vb:row{
        vb:text{
          text = string.format("Instrument: %s", instr.name),
          font = "bold",
          width = dialog_width
        }
      },
      
      vb:row{
        vb:text{
          text = slice_count > 0 and 
            (real_sample_count == 1 and 
              string.format("%d sample with %d slices, %d phrases, Memory: %s", 
                real_sample_count, slice_count, phrase_count, memory_text) or
              string.format("%d samples with %d slices, %d phrases, Memory: %s", 
                real_sample_count, slice_count, phrase_count, memory_text)) or
            string.format("%d samples, %d phrases, Memory: %s", 
              real_sample_count, phrase_count, memory_text),
          width = dialog_width
        }
      },
      
      vb:row{
        vb:text{
          text = string.format("MIDI Output: %s", midi_info),
          width = dialog_width
        }
      },
      
      vb:row{
        vb:text{
          text = string.format("Selected Sample: %s", selected_info),
          width = dialog_width
        }
      },
      
      -- Comments section
      vb:row{
        vb:text{
          text = "Comments:",
          style = "strong"
        }
      },
      
      vb:row{
        vb:multiline_textfield{
          text = current_comments,
          width = dialog_width,
          height = comments_height,
          id = "comments_field"
        }
      },
      

      
      -- Sample details
      vb:row{
        vb:text{
          text = "Sample Details:",
          style = "strong"
        }
      },
      
      vb:row{
        vb:multiline_text{
          text = real_sample_count > 0 and table.concat(sample_details, "\n") or "No samples",
          width = dialog_width,
          height = sample_details_height,
          font = "mono"
        }
      },
      
      -- Buttons
      vb:horizontal_aligner{
        mode = "center",
        vb:row{
          vb:button{
            text = "Save Changes",
            width = 100,
            notifier = function()
              -- Save comments
              local new_comments = vb.views.comments_field.text
              local comment_lines = {}
              for line in new_comments:gmatch("[^\r\n]+") do
                table.insert(comment_lines, line)
              end
              instr.comments = comment_lines
              
              renoise.app():show_status("Instrument metadata saved")
              print("-- Paketti Instrument MetaInfo: Saved metadata for " .. instr.name)
              instrument_info_dialog:close()
            end
          },
          
          vb:button{
            text = "Refresh",
            width = 100,
            notifier = function()
              instrument_info_dialog:close()
              pakettiInstrumentInfoDialog()
            end
          },
          
          vb:button{
            text = "Close",
            width = 100,
            notifier = function()
              instrument_info_dialog:close()
            end
          }
        }
      }
    }
  )
  
  print("-- Paketti Instrument MetaInfo: Dialog opened for " .. instr.name)
end

-- Set configurable height for instrument metainfo dialog
function pakettiSetInstrumentInfoDialogHeight()
  local current_height = preferences.pakettiInstrumentInfoDialogHeight.value
  
  local vb = renoise.ViewBuilder()
  local height_dialog = nil
  
  height_dialog = renoise.app():show_custom_dialog(
    "Set Instrument MetaInfo Dialog Height",
    vb:column{
      margin = 10,
      spacing = 10,
      
      vb:row{
        vb:text{
          text = "Configure the height of the Instrument MetaInfo dialog:",
          style = "strong"
        }
      },
      
      vb:row{
        vb:text{
          text = string.format("Current height: %d pixels", current_height)
        }
      },
      
      vb:row{
        vb:text{
          text = "New height:"
        },
        vb:valuebox{
          min = 400,
          max = 1200,
          value = current_height,
          width = 80,
          id = "height_valuebox"
        }
      },
      
      vb:row{
        vb:text{
          text = "Recommended: 750 pixels (default), 600 for smaller screens, 900+ for large displays",
          font = "italic"
        }
      },
      
      vb:horizontal_aligner{
        mode = "center",
        vb:row{
          vb:button{
            text = "Apply",
            width = 80,
            notifier = function()
              local new_height = vb.views.height_valuebox.value
              preferences.pakettiInstrumentInfoDialogHeight.value = new_height
              preferences:save_as("preferences.xml")
              
              renoise.app():show_status(string.format("Instrument MetaInfo dialog height set to %d pixels", new_height))
              print(string.format("-- Paketti: Instrument MetaInfo dialog height set to %d pixels", new_height))
              
              height_dialog:close()
            end
          },
          
          vb:button{
            text = "Cancel",
            width = 80,
            notifier = function()
              height_dialog:close()
            end
          }
        }
      }
    }
  )
end

-- Menu entries
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti:Instruments:Show Instrument Info (Status)",invoke = pakettiInstrumentInfoStatus}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Instruments:Show Instrument Info (Dialog)",invoke = pakettiInstrumentInfoDialog}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Instruments:Set Instrument Info Dialog Height",invoke = pakettiSetInstrumentInfoDialogHeight}

renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Show Instrument Info (Status)",invoke = pakettiInstrumentInfoStatus}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Show Instrument Info (Dialog)",invoke = pakettiInstrumentInfoDialog}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Set Instrument Info Dialog Height",invoke = pakettiSetInstrumentInfoDialogHeight}

renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Show Instrument Info (Status)",invoke = pakettiInstrumentInfoStatus}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Show Instrument Info (Dialog)",invoke = pakettiInstrumentInfoDialog}
renoise.tool():add_menu_entry{name = "--Sample Editor Ruler:Show Instrument Info (Status)",invoke = pakettiInstrumentInfoStatus}
renoise.tool():add_menu_entry{name = "--Sample Editor Ruler:Show Instrument Info (Dialog)",invoke = pakettiInstrumentInfoDialog}

-- Keybindings
renoise.tool():add_keybinding{name = "Global:Paketti:Show Instrument Info (Status)",invoke = pakettiInstrumentInfoStatus}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Instrument Info (Dialog)",invoke = pakettiInstrumentInfoDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Set Instrument Info Dialog Height",invoke = pakettiSetInstrumentInfoDialogHeight}

-- MIDI mappings
renoise.tool():add_midi_mapping{name = "Paketti:Show Instrument Info (Status)",invoke = function(message) if message:is_trigger() then pakettiInstrumentInfoStatus() end  end}
renoise.tool():add_midi_mapping{name = "Paketti:Show Instrument Info (Dialog)",invoke = function(message) if message:is_trigger() then pakettiInstrumentInfoDialog() end  end}
renoise.tool():add_midi_mapping{name = "Paketti:Set Instrument Info Dialog Height",invoke = function(message) if message:is_trigger() then pakettiSetInstrumentInfoDialogHeight() end  end}


-- Set MIDI output globally to each instrument
function pakettiSetMidiOutputGlobally()
  local song = renoise.song()
  
  -- Get available MIDI devices
  local midi_devices = renoise.Midi.available_output_devices()
  
  if #midi_devices == 0 then
    renoise.app():show_warning("No MIDI output devices available")
    return
  end
  
  -- Create device selection dialog
  local vb = renoise.ViewBuilder()
  local device_dialog = nil
  
  device_dialog = renoise.app():show_custom_dialog(
    "Select MIDI Output Device",
    vb:column{
      margin = 10,
      spacing = 10,
      
      vb:row{
        vb:text{
          text = "Select MIDI device to assign to all instruments:",
          style = "strong"
        }
      },
      
      vb:row{
        vb:popup{
          items = midi_devices,
          width = 300,
          id = "device_popup"
        }
      },
      
      vb:row{
        vb:text{
          text = string.format("This will affect %d instrument(s)", #song.instruments)
        }
      },
      
      vb:horizontal_aligner{
        mode = "center",
        vb:row{
          vb:button{
            text = "Apply",
            width = 80,
            notifier = function()
              local selected_device = midi_devices[vb.views.device_popup.value]
              local instruments_affected = 0
              
              for i, instr in ipairs(song.instruments) do
                if instr.midi_output_properties.device_name ~= selected_device then
                  instr.midi_output_properties.device_name = selected_device
                  instruments_affected = instruments_affected + 1
                end
              end
              
              renoise.app():show_status(string.format("Set MIDI output '%s' for %d instrument(s)", 
                selected_device, instruments_affected))
              print(string.format("-- Paketti MIDI Output: Set '%s' for %d instruments", 
                selected_device, instruments_affected))
              
              device_dialog:close()
            end
          },
          
          vb:button{
            text = "Cancel",
            width = 80,
            notifier = function()
              device_dialog:close()
            end
          }
        }
      }
    }
  )
end

-- Add MIDI global function to appropriate menu sections
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Instruments:Set MIDI Output for All Instruments",invoke = pakettiSetMidiOutputGlobally}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Set MIDI Output for All Instruments",invoke = pakettiSetMidiOutputGlobally}
renoise.tool():add_keybinding{name = "Global:Paketti:Set MIDI Output for All Instruments",invoke = pakettiSetMidiOutputGlobally}
renoise.tool():add_midi_mapping{name = "Paketti:Set MIDI Output for All Instruments",invoke = function(message) if message:is_trigger() then pakettiSetMidiOutputGlobally() end  end}

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
  name = "Main Menu:Tools:Paketti:Phrase Editor:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Phrase Editor:Enable Looping in All Phrases",
  invoke = pakettiEnableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Phrase Editor:Disable Looping in All Phrases",
  invoke = pakettiDisableAllPhraseLooping
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Phrase Editor:Enable Looping in All Phrases",
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

-- Reset basenotes to lowest note range for all samples in selected instrument
function pakettiResetBasenotesToLowestNoteRange()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  local samples_modified = 0
  
  for idx = 1, #instr.samples do
    local sample = instr.samples[idx]
    local smap = sample.sample_mapping
    
    -- Check if base note is different from note range start
    if smap.base_note ~= smap.note_range[1] then
      smap.base_note = smap.note_range[1]
      samples_modified = samples_modified + 1
      print(string.format("-- Paketti Basenote Reset: Sample '%s' base note set to %d", sample.name, smap.base_note))
    end
  end
  
  if samples_modified > 0 then
    renoise.app():show_status(string.format("Reset %d basenote(s) in instrument '%s'", samples_modified, instr.name))
    print(string.format("-- Paketti Basenote Reset: Reset %d basenote(s) in instrument '%s'", samples_modified, instr.name))
  else
    renoise.app():show_status("All basenotes already aligned with note ranges")
    print("-- Paketti Basenote Reset: No basenotes needed adjustment")
  end
end

-- Menu entries for basenote reset
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Global:Reset Basenote to Lowest Note Range",invoke = pakettiResetBasenotesToLowestNoteRange}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Reset Basenote to Lowest Note Range",invoke = pakettiResetBasenotesToLowestNoteRange}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Reset Basenote to Lowest Note Range",invoke = pakettiResetBasenotesToLowestNoteRange}

-- Keybinding
renoise.tool():add_keybinding{name = "Global:Paketti:Reset Basenote to Lowest Note Range",invoke = pakettiResetBasenotesToLowestNoteRange}

-- MIDI mapping
renoise.tool():add_midi_mapping{name = "Paketti:Reset Basenote to Lowest Note Range",invoke = function(message) if message:is_trigger() then pakettiResetBasenotesToLowestNoteRange() end end}

-- ======================================
-- Paketti UIOWA Sample Processing
-- ======================================
-- Based on danoise UIOWA_Importer.lua - for University of Iowa Musical Instrument Samples

-- Note name translation table (UIOWA format to Renoise format)
local UIOWA_NOTE_TRANSLATION = {
  {source = "C", target = "C"},
  {source = "Db", target = "C#"},
  {source = "D", target = "D"},
  {source = "Eb", target = "D#"},
  {source = "E", target = "E"},
  {source = "F", target = "F"},
  {source = "Gb", target = "F#"},
  {source = "G", target = "G"},
  {source = "Ab", target = "G#"},
  {source = "A", target = "A"},
  {source = "Bb", target = "A#"},
  {source = "B", target = "B"}
}

-- Convert UIOWA note format to MIDI note number
local function pakettiUIowaGetMidiNoteFromPattern(note_pattern)
  for _, translation in ipairs(UIOWA_NOTE_TRANSLATION) do
    -- Look for pattern like "C4", "Db5", etc.
    local note_match = note_pattern:match(translation.source .. "(%d+)")
    if note_match then
      local octave = tonumber(note_match)
      if octave and octave >= 0 and octave <= 10 then
        -- Find the semitone offset for this note
        local semitone = 0
        for i, trans in ipairs(UIOWA_NOTE_TRANSLATION) do
          if trans.source == translation.source then
            semitone = i - 1  -- C=0, C#=1, D=2, etc.
            break
          end
        end
        
        local midi_note = octave * 12 + semitone
        -- Clamp to valid MIDI range
        midi_note = math.max(0, math.min(119, midi_note))
        return midi_note, string.format("%s%d", translation.target, octave)
      end
    end
  end
  return nil, nil
end

-- Process existing samples in selected instrument for UIOWA patterns
function pakettiUIowaProcessor()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  local processed_count = 0
  local skipped_count = 0
  local pattern_info = {}
  
  for idx = 1, #instr.samples do
    local sample = instr.samples[idx]
    local smap = sample.sample_mapping
    local sample_name = sample.name
    
    -- Try to find UIOWA note pattern in sample name
    local midi_note, note_name = pakettiUIowaGetMidiNoteFromPattern(sample_name)
    
    if midi_note then
      -- Set the keyzone mapping
      smap.base_note = midi_note
      smap.note_range = {midi_note, midi_note}
      
      processed_count = processed_count + 1
      table.insert(pattern_info, string.format("Sample '%s' -> %s (MIDI %d)", sample_name, note_name, midi_note))
      print(string.format("-- Paketti UIOWA Processor: Sample '%s' mapped to %s (MIDI note %d)", sample_name, note_name, midi_note))
    else
      skipped_count = skipped_count + 1
      print(string.format("-- Paketti UIOWA Processor: No UIOWA pattern found in '%s'", sample_name))
    end
  end
  
  if processed_count > 0 then
    renoise.app():show_status(string.format("UIOWA Processor: Mapped %d sample(s), skipped %d in '%s'", processed_count, skipped_count, instr.name))
    print(string.format("-- Paketti UIOWA Processor: Successfully processed %d samples, skipped %d samples", processed_count, skipped_count))
    
    -- Show detailed mapping info
    for _, info in ipairs(pattern_info) do
      print("-- " .. info)
    end
  else
    renoise.app():show_status("No UIOWA note patterns found in sample names")
    print("-- Paketti UIOWA Processor: No UIOWA patterns detected. Expected patterns: C4, Db5, F#3, etc.")
  end
end

-- Import UIOWA samples with automatic keyzone mapping
function pakettiUIowaImporter()
  -- Prompt for multiple sample files
  local file_paths = renoise.app():prompt_for_multiple_filenames_to_read(
    {"*.wav", "*.aif", "*.aiff", "*.flac", "*.ogg"}, 
    "Select UIOWA Sample Files"
  )
  
  if not file_paths or #file_paths == 0 then
    renoise.app():show_status("No files selected")
    return
  end
  
  local song = renoise.song()
  
  -- Create new instrument for UIOWA samples
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  -- Initialize with Paketti default instrument configuration
  pakettiPreferencesDefaultInstrumentLoader()
  
  local instr = song.selected_instrument
  local original_name = instr.name ~= "" and instr.name or "Untitled"
  instr.name = original_name .. " (UIOWA Import)"
  
  local imported_count = 0
  local skipped_count = 0
  local total_files = #file_paths
  local mapping_info = {}
  
  for i, file_path in ipairs(file_paths) do
    renoise.app():show_status(string.format("UIOWA Import: Loading file %d of %d", i, total_files))
    
    -- Extract filename for pattern detection
    local filename = file_path:match("([^\\/]+)$") or ""
    local sample_name = filename:match("(.+)%..+$") or filename  -- Remove extension
    
    -- Try to detect UIOWA pattern
    local midi_note, note_name = pakettiUIowaGetMidiNoteFromPattern(sample_name)
    
    if midi_note then
      -- Load the sample
      local sample_loaded = false
      local sample = nil
      
      -- Try to load the sample file
      pcall(function()
        if #instr.samples == 1 and not instr.samples[1].sample_buffer.has_sample_data then
          -- Replace empty first sample
          sample = instr.samples[1]
          sample.sample_buffer:load_from(file_path)
        else
          -- Insert new sample
          sample = instr:insert_sample_at(#instr.samples + 1)
          sample.sample_buffer:load_from(file_path)
        end
        sample_loaded = true
      end)
      
      if sample_loaded and sample then
        -- Set sample name and keyzone mapping
        sample.name = sample_name
        local smap = sample.sample_mapping
        smap.base_note = midi_note
        smap.note_range = {midi_note, midi_note}
        
        imported_count = imported_count + 1
        table.insert(mapping_info, string.format("'%s' -> %s (MIDI %d)", sample_name, note_name, midi_note))
        print(string.format("-- Paketti UIOWA Importer: Loaded '%s' as %s (MIDI note %d)", filename, note_name, midi_note))
      else
        skipped_count = skipped_count + 1
        print(string.format("-- Paketti UIOWA Importer: Failed to load file '%s'", filename))
      end
    else
      skipped_count = skipped_count + 1
      print(string.format("-- Paketti UIOWA Importer: No UIOWA pattern in filename '%s'", filename))
    end
  end
  
  -- Clean up empty samples if any
  for sample_index = #instr.samples, 1, -1 do
    if not instr.samples[sample_index].sample_buffer.has_sample_data then
      instr:delete_sample_at(sample_index)
    end
  end
  
  -- Update instrument name with more info
  if imported_count > 0 then
    instr.name = string.format("%s (%d samples)", original_name .. " (UIOWA Import)", imported_count)
    
    -- Switch to keyzone view to show the results
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
    
    renoise.app():show_status(string.format("UIOWA Import: Loaded %d sample(s), skipped %d, mapped automatically", imported_count, skipped_count))
    print(string.format("-- Paketti UIOWA Importer: Import complete - %d samples loaded and mapped, %d skipped", imported_count, skipped_count))
    
    -- Show mapping details
    print("-- Paketti UIOWA Importer: Keyzone mappings:")
    for _, info in ipairs(mapping_info) do
      print("--   " .. info)
    end
    
    print("-- Paketti UIOWA Importer: Supported patterns: C4, Db5, F#3, Bb2, etc. (note + octave)")
  else
    renoise.app():show_warning("No UIOWA samples could be imported. Check filename patterns (e.g., 'Flute_C4.wav')")
    print("-- Paketti UIOWA Importer: No samples imported. Expected filename patterns like 'Instrument_C4.wav', 'Piano_Db5.aif', etc.")
  end
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Samples:UIOWA Sample Importer",
  invoke = pakettiUIowaImporter
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Samples:UIOWA Sample Processor",
  invoke = pakettiUIowaProcessor
}

renoise.tool():add_menu_entry{
  name = "--Instrument Box:Paketti:Load:UIOWA Sample Importer",
  invoke = pakettiUIowaImporter
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Load:UIOWA Sample Processor",
  invoke = pakettiUIowaProcessor
}

renoise.tool():add_menu_entry{
  name = "--Sample Editor:Paketti:Load:UIOWA Sample Importer",
  invoke = pakettiUIowaImporter
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Load:UIOWA Sample Processor",
  invoke = pakettiUIowaProcessor
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:UIOWA Sample Importer",
  invoke = pakettiUIowaImporter
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:UIOWA Sample Processor",
  invoke = pakettiUIowaProcessor
}

-- MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:UIOWA Sample Importer",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiUIowaImporter() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:UIOWA Sample Processor",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiUIowaProcessor() 
    end 
  end
}

-- ======================================
-- Paketti Experimental/Work in Progress Tools
-- ======================================
-- Based on various danoise scripts - experimental features for testing

-- ======================================
-- Paketti Sample Trimmer
-- ======================================
-- Based on danoise Trimmer.lua - trim samples to loop points or selection

-- Trim a single sample based on mode
local function pakettiTrimSample(instr, sample_idx, mode)
  local sample = instr.samples[sample_idx]
  if not sample then
    print("-- Paketti Trimmer: Could not locate sample at index " .. sample_idx)
    return false, "Sample not found"
  end
  
  local sbuf = sample.sample_buffer
  if not sbuf.has_sample_data then
    print(string.format("-- Paketti Trimmer: Sample '%s' has no sample data", sample.name))
    return false, "No sample data"
  end
  
  if sbuf.read_only then
    print(string.format("-- Paketti Trimmer: Sample '%s' is read-only (sliced?)", sample.name))
    return false, "Sample is read-only"
  end
  
  local trim_start, trim_end
  
  if mode == "loop" then
    if sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
      print(string.format("-- Paketti Trimmer: Sample '%s' has no loop defined", sample.name))
      return false, "No loop defined"
    end
    trim_start = sample.loop_start - 1
    trim_end = sample.loop_end - 1
  elseif mode == "selection" then
    if sbuf.selection_start == 0 or sbuf.selection_end == 0 then
      print(string.format("-- Paketti Trimmer: Sample '%s' has no selection", sample.name))
      return false, "No selection defined"
    end
    trim_start = sbuf.selection_start - 1
    trim_end = sbuf.selection_end - 1
  else
    return false, "Unsupported trim mode"
  end
  
  -- Validate trim points
  if trim_start < 0 or trim_end <= trim_start or trim_end > sbuf.number_of_frames then
    print(string.format("-- Paketti Trimmer: Invalid trim points for '%s': %d to %d (max %d)", 
      sample.name, trim_start, trim_end, sbuf.number_of_frames))
    return false, "Invalid trim points"
  end
  
  print(string.format("-- Paketti Trimmer: Trimming sample '%s' from frame %d to %d", 
    sample.name, trim_start, trim_end))
  
  -- Create a new sample (duplicate first)
  local new_sample = instr:insert_sample_at(sample_idx)
  local new_sbuf = new_sample.sample_buffer
  
  new_sample:copy_from(sample)
  
  local sample_rate = sbuf.sample_rate
  local bit_depth = sbuf.bit_depth
  local num_channels = sbuf.number_of_channels
  local num_frames = 1 + trim_end - trim_start
  
  new_sbuf:create_sample_data(sample_rate, bit_depth, num_channels, num_frames)
  
  -- Copy the trimmed portion
  for chan_idx = 1, sbuf.number_of_channels do
    for frame_idx = 1, num_frames do
      new_sbuf:set_sample_data(chan_idx, frame_idx,
        sbuf:sample_data(chan_idx, frame_idx + trim_start))
    end
  end
  
  -- Update loop markers if we were trimming by loop
  if mode == "loop" then
    new_sample.loop_start = 1
    new_sample.loop_end = num_frames
  end
  
  -- Remove original sample
  instr:delete_sample_at(sample_idx + 1)
  
  print(string.format("-- Paketti Trimmer: Successfully trimmed '%s' to %d frames", 
    sample.name, num_frames))
  return true, "Trim successful"
end

-- Trim selected sample to loop points
function pakettiTrimSelectedSampleToLoop()
  local song = renoise.song()
  local instr = song.selected_instrument
  local sample_idx = song.selected_sample_index
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  local success, message = pakettiTrimSample(instr, sample_idx, "loop")
  if success then
    renoise.app():show_status(string.format("Trimmed sample to loop points: %s", message))
  else
    renoise.app():show_status(string.format("Trim failed: %s", message))
  end
end

-- Trim selected sample to selection
function pakettiTrimSelectedSampleToSelection()
  local song = renoise.song()
  local instr = song.selected_instrument
  local sample_idx = song.selected_sample_index
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  local success, message = pakettiTrimSample(instr, sample_idx, "selection")
  if success then
    renoise.app():show_status(string.format("Trimmed sample to selection: %s", message))
  else
    renoise.app():show_status(string.format("Trim failed: %s", message))
  end
end

-- Trim all samples in instrument to their loop points
function pakettiTrimAllSamplesToLoop()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in instrument")
    return
  end
  
  local trimmed_count = 0
  local skipped_count = 0
  
  -- Work backwards to avoid index shifting issues
  for sample_idx = #instr.samples, 1, -1 do
    local success, message = pakettiTrimSample(instr, sample_idx, "loop")
    if success then
      trimmed_count = trimmed_count + 1
    else
      skipped_count = skipped_count + 1
    end
  end
  
  renoise.app():show_status(string.format("Trim complete: %d samples trimmed, %d skipped", 
    trimmed_count, skipped_count))
  print(string.format("-- Paketti Trimmer: Batch trim complete - %d trimmed, %d skipped", 
    trimmed_count, skipped_count))
end

-- ======================================
-- Paketti Sample Renamer
-- ======================================
-- Based on danoise Renamer.lua - rename samples with note names or GM drum names

-- Note names array
local PAKETTI_NOTE_ARRAY = { "C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-" }

-- GM Drum Kit mapping (MIDI note to drum name)
local PAKETTI_GMKIT_ARRAY = {
  [35]="Acoustic_Bass_Drum",  [36]="Bass_Drum_1",       [37]="Side_Stick",        [38]="Acoustic_Snare",
  [39]="Hand_Clap",           [40]="Electric_Snare",    [41]="Low_Floor_Tom",     [42]="Closed_Hi_Hat",
  [43]="High_Floor_Tom",      [44]="Pedal_Hi_Hat",      [45]="Low_Tom",           [46]="Open_Hi_Hat",
  [47]="Low_Mid_Tom",         [48]="Hi_Mid_Tom",        [49]="Crash_Cymbal_1",   [50]="High_Tom",
  [51]="Ride_Cymbal_1",       [52]="Chinese_Cymbal",    [53]="Ride_Bell",         [54]="Tambourine",
  [55]="Splash_Cymbal",       [56]="Cowbell",           [57]="Crash_Cymbal_2",   [58]="Vibraslap",
  [59]="Ride_Cymbal_2",       [60]="Hi_Bongo",          [61]="Low_Bongo",         [62]="Mute_Hi_Conga",
  [63]="Open_Hi_Conga",       [64]="Low_Conga",         [65]="High_Timbale",      [66]="Low_Timbale",
  [67]="High_Agogo",          [68]="Low_Agogo",         [69]="Cabasa",            [70]="Maracas",
  [71]="Short_Whistle",       [72]="Long_Whistle",      [73]="Short_Guiro",       [74]="Long_Guiro",
  [75]="Claves",              [76]="Hi_Wood_Block",     [77]="Low_Wood_Block",    [78]="Mute_Cuica",
  [79]="Open_Cuica",          [80]="Mute_Triangle",     [81]="Open_Triangle"
}

-- Convert MIDI note number to note name
local function pakettiNoteValueToString(val)
  if not val then
    return "Unknown"
  elseif val == 120 then
    return "OFF"
  elseif val == 121 then
    return "---"
  elseif val == 0 then
    return "C-0"
  else
    local oct = math.floor(val/12)
    local note = PAKETTI_NOTE_ARRAY[(val%12)+1]
    return string.format("%s%s", note, oct)
  end
end

-- Rename samples with note names (melodic instruments)
function pakettiRenameSamplesWithNoteNames()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in instrument")
    return
  end
  
  local instrument_name = instr.name ~= "" and instr.name or "Instrument"
  local renamed_count = 0
  
  for idx, sample in ipairs(instr.samples) do
    local smap = sample.sample_mapping
    local base_note = smap.base_note
    local note_name = pakettiNoteValueToString(base_note)
    local new_name = string.format("%s_%s", instrument_name, note_name)
    
    if sample.name ~= new_name then
      sample.name = new_name
      renamed_count = renamed_count + 1
      print(string.format("-- Paketti Renamer: Sample %d renamed to '%s'", idx, new_name))
    end
  end
  
  renoise.app():show_status(string.format("Renamed %d sample(s) with note names in '%s'", 
    renamed_count, instrument_name))
  print(string.format("-- Paketti Renamer: Completed note naming - %d samples renamed", renamed_count))
end

-- Rename samples with GM drum names (drum kits)
function pakettiRenameSamplesWithDrumNames()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in instrument")
    return
  end
  
  local instrument_name = instr.name ~= "" and instr.name or "Drumkit"
  local renamed_count = 0
  local unknown_count = 0
  
  for idx, sample in ipairs(instr.samples) do
    local smap = sample.sample_mapping
    local base_note = smap.base_note
    local drum_name = PAKETTI_GMKIT_ARRAY[base_note] or "Unknown_Drum"
    local new_name = string.format("%s_%s", drum_name, instrument_name)
    
    if sample.name ~= new_name then
      sample.name = new_name
      renamed_count = renamed_count + 1
      
      if drum_name == "Unknown_Drum" then
        unknown_count = unknown_count + 1
      end
      
      print(string.format("-- Paketti Renamer: Sample %d (note %d) renamed to '%s'", 
        idx, base_note, new_name))
    end
  end
  
  local status_msg = string.format("Renamed %d sample(s) with drum names in '%s'", 
    renamed_count, instrument_name)
  if unknown_count > 0 then
    status_msg = status_msg .. string.format(" (%d unknown drums)", unknown_count)
  end
  
  renoise.app():show_status(status_msg)
  print(string.format("-- Paketti Renamer: Completed drum naming - %d samples renamed, %d unknown", 
    renamed_count, unknown_count))
end

-- ======================================
-- Paketti Kontakt Export
-- ======================================
-- Based on danoise KontaktExport.lua - format filenames for Kontakt sampler export

function pakettiKontaktExportSamples()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples == 0 then
    renoise.app():show_status("No samples in instrument")
    return
  end
  
  -- Prompt for output folder
  local output_folder = renoise.app():prompt_for_path("Select folder for Kontakt export")
  if not output_folder or output_folder == "" then
    renoise.app():show_status("Export cancelled")
    return
  end
  
  -- Ensure folder ends with separator
  if not output_folder:match("[/\\]$") then
    output_folder = output_folder .. "/"
  end
  
  local exported_count = 0
  local skipped_count = 0
  
  for sample_idx, sample in ipairs(instr.samples) do
    if sample.sample_buffer.has_sample_data then
      local original_name = sample.name
      
      -- Apply Kontakt formatting to filename
      -- Input: "VST: iblit (PwmBass 1)_0x7F_C-3"
      -- Output: "VST_iblit_PwmBass_1_127_C3"
      local kontakt_filename = original_name:gsub("(.*)_(0x%x%x)_([A-Z])-?(#?%d)", function(a, b, c, d)
        -- Clean up the main part
        a = a:gsub(":", "")           -- Remove colons
        a = a:gsub("[%(%)]", "")      -- Remove parentheses  
        a = a:gsub("%s", "_")         -- Replace spaces with underscores
        
        -- Convert hex velocity to decimal
        local velocity_decimal = string.format("%d", tonumber(b))
        
        -- Remove dash from note name (C-3 becomes C3)
        local note_name = c .. d
        
        return a .. "_" .. velocity_decimal .. "_" .. note_name
      end)
      
      -- If no pattern matched, clean up the filename anyway
      if kontakt_filename == original_name then
        kontakt_filename = original_name:gsub(":", "")
        kontakt_filename = kontakt_filename:gsub("[%(%)]", "")
        kontakt_filename = kontakt_filename:gsub("%s", "_")
        kontakt_filename = kontakt_filename:gsub("[^%w_%-]", "_")  -- Replace non-alphanumeric with underscore
      end
      
      -- Ensure .wav extension
      if not kontakt_filename:match("%.wav$") then
        kontakt_filename = kontakt_filename .. ".wav"
      end
      
      local export_path = output_folder .. kontakt_filename
      
      -- Set current sample for export
      song.selected_sample_index = sample_idx
      
      -- Export the sample
      local success = pcall(function()
        renoise.app():save_instrument_sample(export_path)
      end)
      
      if success then
        exported_count = exported_count + 1
        print(string.format("-- Paketti Kontakt Export: '%s' -> '%s'", original_name, kontakt_filename))
      else
        skipped_count = skipped_count + 1
        print(string.format("-- Paketti Kontakt Export: Failed to export '%s'", original_name))
      end
    else
      skipped_count = skipped_count + 1
      print(string.format("-- Paketti Kontakt Export: Skipped '%s' (no sample data)", sample.name))
    end
  end
  
  renoise.app():show_status(string.format("Kontakt Export: %d samples exported, %d skipped to '%s'", 
    exported_count, skipped_count, output_folder))
  print(string.format("-- Paketti Kontakt Export: Complete - %d exported, %d skipped", 
    exported_count, skipped_count))
end

-- ======================================
-- Menu Entries for Experimental/Work in Progress Tools
-- ======================================

-- Sample Trimmer
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim Selected Sample to Loop Points",
  invoke = pakettiTrimSelectedSampleToLoop
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim Selected Sample to Selection",
  invoke = pakettiTrimSelectedSampleToSelection
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim All Samples to Loop Points",
  invoke = pakettiTrimAllSamplesToLoop
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim Selected Sample to Loop Points",
  invoke = pakettiTrimSelectedSampleToLoop
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim Selected Sample to Selection",
  invoke = pakettiTrimSelectedSampleToSelection
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Xperimental/Work in Progress:Sample Trimmer:Trim All Samples to Loop Points",
  invoke = pakettiTrimAllSamplesToLoop
}

-- Sample Renamer
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Renamer:Rename with Note Names (Melodic)",
  invoke = pakettiRenameSamplesWithNoteNames
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Renamer:Rename with Drum Names (GM Kit)",
  invoke = pakettiRenameSamplesWithDrumNames
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Renamer:Rename with Note Names (Melodic)",
  invoke = pakettiRenameSamplesWithNoteNames
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Renamer:Rename with Drum Names (GM Kit)",
  invoke = pakettiRenameSamplesWithDrumNames
}

-- Kontakt Export
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Kontakt Export:Export Samples for Kontakt",
  invoke = pakettiKontaktExportSamples
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Kontakt Export:Export Samples for Kontakt",
  invoke = pakettiKontaktExportSamples
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Xperimental/Work in Progress:Kontakt Export:Export Samples for Kontakt",
  invoke = pakettiKontaktExportSamples
}

-- ======================================
-- Keybindings for Experimental Tools
-- ======================================

renoise.tool():add_keybinding{
  name = "Global:Paketti:Trim Selected Sample to Loop Points",
  invoke = pakettiTrimSelectedSampleToLoop
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Trim Selected Sample to Selection", 
  invoke = pakettiTrimSelectedSampleToSelection
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Rename Samples with Note Names",
  invoke = pakettiRenameSamplesWithNoteNames
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Rename Samples with Drum Names",
  invoke = pakettiRenameSamplesWithDrumNames
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export Samples for Kontakt",
  invoke = pakettiKontaktExportSamples
}

-- ======================================
-- MIDI Mappings for Experimental Tools  
-- ======================================

renoise.tool():add_midi_mapping{
  name = "Paketti:Trim Selected Sample to Loop Points",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiTrimSelectedSampleToLoop() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Rename Samples with Note Names",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiRenameSamplesWithNoteNames() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Export Samples for Kontakt",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiKontaktExportSamples() 
    end 
  end
}

-- ======================================
-- Paketti Sample Sorter
-- ======================================
-- Based on danoise Samplesort.lua - sort samples by different criteria

-- Sort samples by name (alphabetical)
function pakettiSortSamplesByName()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples < 2 then
    renoise.app():show_status("Need at least 2 samples to sort")
    return
  end
  
  -- Create array of sample data with indices
  local sample_data = {}
  for idx = 1, #instr.samples do
    table.insert(sample_data, {
      index = idx,
      name = instr.samples[idx].name,
      sample = instr.samples[idx]
    })
  end
  
  -- Sort by name
  table.sort(sample_data, function(a, b)
    return a.name < b.name
  end)
  
  -- Reorder samples based on sorted indices
  local sorted_samples = {}
  for i, data in ipairs(sample_data) do
    table.insert(sorted_samples, data.sample)
  end
  
  -- Clear existing samples and add sorted ones
  for i = #instr.samples, 1, -1 do
    instr:delete_sample_at(i)
  end
  
  for i, sample in ipairs(sorted_samples) do
    local new_sample = instr:insert_sample_at(i)
    new_sample:copy_from(sample)
  end
  
  renoise.app():show_status(string.format("Sorted %d samples by name in '%s'", #sorted_samples, instr.name))
  print(string.format("-- Paketti Sample Sorter: Sorted %d samples by name", #sorted_samples))
end

-- Sort samples by base note (MIDI note number)
function pakettiSortSamplesByBaseNote()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples < 2 then
    renoise.app():show_status("Need at least 2 samples to sort")
    return
  end
  
  -- Create array of sample data with indices
  local sample_data = {}
  for idx = 1, #instr.samples do
    table.insert(sample_data, {
      index = idx,
      base_note = instr.samples[idx].sample_mapping.base_note,
      name = instr.samples[idx].name,
      sample = instr.samples[idx]
    })
  end
  
  -- Sort by base note (ascending)
  table.sort(sample_data, function(a, b)
    if a.base_note == b.base_note then
      return a.name < b.name  -- Secondary sort by name if same base note
    end
    return a.base_note < b.base_note
  end)
  
  -- Reorder samples based on sorted indices
  local sorted_samples = {}
  for i, data in ipairs(sample_data) do
    table.insert(sorted_samples, data.sample)
  end
  
  -- Clear existing samples and add sorted ones
  for i = #instr.samples, 1, -1 do
    instr:delete_sample_at(i)
  end
  
  for i, sample in ipairs(sorted_samples) do
    local new_sample = instr:insert_sample_at(i)
    new_sample:copy_from(sample)
  end
  
  renoise.app():show_status(string.format("Sorted %d samples by base note in '%s'", #sorted_samples, instr.name))
  print(string.format("-- Paketti Sample Sorter: Sorted %d samples by base note", #sorted_samples))
end

-- Sort samples by velocity range (lowest velocity first)
function pakettiSortSamplesByVelocity()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples < 2 then
    renoise.app():show_status("Need at least 2 samples to sort")
    return
  end
  
  -- Create array of sample data with indices
  local sample_data = {}
  for idx = 1, #instr.samples do
    local velocity_range = instr.samples[idx].sample_mapping.velocity_range
    table.insert(sample_data, {
      index = idx,
      velocity_low = velocity_range[1],
      velocity_high = velocity_range[2],
      name = instr.samples[idx].name,
      sample = instr.samples[idx]
    })
  end
  
  -- Sort by velocity range (ascending by low velocity, then high velocity)
  table.sort(sample_data, function(a, b)
    if a.velocity_low == b.velocity_low then
      if a.velocity_high == b.velocity_high then
        return a.name < b.name  -- Tertiary sort by name
      end
      return a.velocity_high < b.velocity_high  -- Secondary sort by high velocity
    end
    return a.velocity_low < b.velocity_low  -- Primary sort by low velocity
  end)
  
  -- Reorder samples based on sorted indices
  local sorted_samples = {}
  for i, data in ipairs(sample_data) do
    table.insert(sorted_samples, data.sample)
  end
  
  -- Clear existing samples and add sorted ones
  for i = #instr.samples, 1, -1 do
    instr:delete_sample_at(i)
  end
  
  for i, sample in ipairs(sorted_samples) do
    local new_sample = instr:insert_sample_at(i)
    new_sample:copy_from(sample)
  end
  
  renoise.app():show_status(string.format("Sorted %d samples by velocity in '%s'", #sorted_samples, instr.name))
  print(string.format("-- Paketti Sample Sorter: Sorted %d samples by velocity", #sorted_samples))
end

-- Sort samples by combined criteria: Base Note -> Velocity -> Name
function pakettiSortSamplesByMultipleCriteria()
  local song = renoise.song()
  local instr = song.selected_instrument
  
  if not instr then
    renoise.app():show_warning("No instrument selected")
    return
  end
  
  if #instr.samples < 2 then
    renoise.app():show_status("Need at least 2 samples to sort")
    return
  end
  
  -- Create array of sample data with indices
  local sample_data = {}
  for idx = 1, #instr.samples do
    local velocity_range = instr.samples[idx].sample_mapping.velocity_range
    table.insert(sample_data, {
      index = idx,
      base_note = instr.samples[idx].sample_mapping.base_note,
      velocity_low = velocity_range[1],
      name = instr.samples[idx].name,
      sample = instr.samples[idx]
    })
  end
  
  -- Sort by multiple criteria: Base Note -> Velocity -> Name
  table.sort(sample_data, function(a, b)
    if a.base_note == b.base_note then
      if a.velocity_low == b.velocity_low then
        return a.name < b.name  -- Tertiary sort by name
      end
      return a.velocity_low < b.velocity_low  -- Secondary sort by velocity
    end
    return a.base_note < b.base_note  -- Primary sort by base note
  end)
  
  -- Reorder samples based on sorted indices
  local sorted_samples = {}
  for i, data in ipairs(sample_data) do
    table.insert(sorted_samples, data.sample)
  end
  
  -- Clear existing samples and add sorted ones
  for i = #instr.samples, 1, -1 do
    instr:delete_sample_at(i)
  end
  
  for i, sample in ipairs(sorted_samples) do
    local new_sample = instr:insert_sample_at(i)
    new_sample:copy_from(sample)
  end
  
  renoise.app():show_status(string.format("Sorted %d samples by base note -> velocity -> name in '%s'", #sorted_samples, instr.name))
  print(string.format("-- Paketti Sample Sorter: Sorted %d samples by multiple criteria", #sorted_samples))
end

-- ======================================
-- Menu Entries for Sample Sorter
-- ======================================

-- Sample Sorter
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Name",
  invoke = pakettiSortSamplesByName
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Base Note",
  invoke = pakettiSortSamplesByBaseNote
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Velocity",
  invoke = pakettiSortSamplesByVelocity
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Note->Velocity->Name",
  invoke = pakettiSortSamplesByMultipleCriteria
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Name",
  invoke = pakettiSortSamplesByName
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Base Note",
  invoke = pakettiSortSamplesByBaseNote
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Velocity",
  invoke = pakettiSortSamplesByVelocity
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti:Xperimental/Work in Progress:Sample Sorter:Sort by Note->Velocity->Name",
  invoke = pakettiSortSamplesByMultipleCriteria
}

-- ======================================
-- Keybindings for Sample Sorter
-- ======================================

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sort Samples by Name",
  invoke = pakettiSortSamplesByName
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sort Samples by Base Note",
  invoke = pakettiSortSamplesByBaseNote
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sort Samples by Velocity",
  invoke = pakettiSortSamplesByVelocity
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sort Samples by Multiple Criteria",
  invoke = pakettiSortSamplesByMultipleCriteria
}

-- ======================================
-- MIDI Mappings for Sample Sorter
-- ======================================

renoise.tool():add_midi_mapping{
  name = "Paketti:Sort Samples by Name",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiSortSamplesByName() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Sort Samples by Base Note",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiSortSamplesByBaseNote() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Sort Samples by Multiple Criteria",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiSortSamplesByMultipleCriteria() 
    end 
  end
}



