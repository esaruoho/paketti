--[[============================================================================
PakettiAkaiFormats.lua — Comprehensive Akai Format Tools and Information
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[AkaiFormats]", ...)
end

-- Format information database
local AKAI_FORMATS = {
  {
    name = "S900/S950 Samples",
    description = "Early Akai samplers with 12-bit samples",
    extensions = {"s"},
    features = {"12-bit samples", "ASCII encoding", "Basic looping"},
    sample_rate = "Variable", 
    bit_depth = "12-bit",
    channels = "Mono",
    notes = "S900/S950 use 12-bit sample packing and ASCII filenames."
  },
  {
    name = "S1000/S1100/S01 Samples",
    description = "Popular 16-bit samplers with AKAII encoding",
    extensions = {"s"},
    features = {"16-bit samples", "AKAII encoding", "8 loops", "Tuning info"},
    sample_rate = "Variable",
    bit_depth = "16-bit", 
    channels = "Mono",
    notes = "S1000 series use 150-byte headers and AKAII character encoding."
  },
  {
    name = "S3000 Samples", 
    description = "Advanced sampler with enhanced loop support",
    extensions = {"s"},
    features = {"16-bit samples", "AKAII encoding", "Enhanced loops", "192-byte header"},
    sample_rate = "Variable",
    bit_depth = "16-bit",
    channels = "Mono", 
    notes = "S3000 uses 192-byte headers with first active loop field and enhanced parameters."
  },
  {
    name = "MPC2000",
    description = "MPC series sampler with DOS-compatible .SND files",
    extensions = {"snd"},
    features = {"16-bit samples", "ASCII names", "Stereo support", "Loop timing"},
    sample_rate = "Variable",
    bit_depth = "16-bit",
    channels = "Mono/Stereo",
    notes = "DOS-formatted disks. 42-byte header. Beats-in-loop parameter."
  },
  {
    name = "S5000/S6000 (AKP)",
    description = "Modern Akai format using WAV files and AKP programs",
    extensions = {"akp"},
    features = {"WAV samples", "Program files", "Multi-samples", "Velocity layers"},
    sample_rate = "Variable",
    bit_depth = "16-bit",
    channels = "Mono/Stereo",
    notes = "RIFF-based format. Separate WAV files with AKP program data."
  },
  {
    name = "S1000 Programs",
    description = "S1000 program files with keygroup and sample mappings",
    extensions = {"p"},
    features = {"Program data", "Sample mappings", "Keygroups"},
    sample_rate = "N/A",
    bit_depth = "N/A",
    channels = "N/A",
    notes = "Program files contain instrument configuration and sample assignments."
  },
  {
    name = "MPC Programs",
    description = "MPC1000/2000 program files",
    extensions = {"pgm"},
    features = {"Program data", "Pad assignments", "Sample mappings"},
    sample_rate = "N/A",
    bit_depth = "N/A", 
    channels = "N/A",
    notes = "MPC program files for drum kits and multi-samples."
  }
}

-- Show format information dialog
function showAkaiFormatsInfo()
  local info_text = "=== AKAI SAMPLER FORMATS SUPPORTED ===\n\n"
  
  for i, format in ipairs(AKAI_FORMATS) do
    info_text = info_text .. string.format("%d. %s\n", i, format.name)
    info_text = info_text .. string.format("   Description: %s\n", format.description)
    info_text = info_text .. string.format("   Extensions: %s\n", table.concat(format.extensions, ", "))
    info_text = info_text .. string.format("   Sample Rate: %s\n", format.sample_rate)
    info_text = info_text .. string.format("   Bit Depth: %s\n", format.bit_depth)
    info_text = info_text .. string.format("   Channels: %s\n", format.channels)
    info_text = info_text .. string.format("   Features: %s\n", table.concat(format.features, ", "))
    info_text = info_text .. string.format("   Notes: %s\n", format.notes)
    info_text = info_text .. "\n"
  end
  
  info_text = info_text .. "=== USAGE ===\n"
  info_text = info_text .. "• Import: Use 'Load' menu entries or drag & drop files\n"
  info_text = info_text .. "• Export: Use 'Export' menu entries on selected samples\n"
  info_text = info_text .. "• Batch: Use folder import options for multiple files\n"
  info_text = info_text .. "• All formats preserve tuning, looping, and sample data\n"
  
  renoise.app():show_message(info_text)
end

-- Get all supported Akai extensions
local function get_all_akai_extensions()
  local extensions = {}
  for _, format in ipairs(AKAI_FORMATS) do
    for _, ext in ipairs(format.extensions) do
      table.insert(extensions, ext)
    end
  end
  return extensions
end

-- Detect Akai format from file
local function detect_akai_format(file_path)
  local ext = file_path:lower():match("%.([^.]+)$")
  if not ext then return nil end
  
  for _, format in ipairs(AKAI_FORMATS) do
    for _, format_ext in ipairs(format.extensions) do
      if ext == format_ext then
        return format
      end
    end
  end
  return nil
end

-- Import any Akai format
function importAnyAkaiSample(file_path)
  if not file_path then
    local extensions = {}
    for _, ext in ipairs(get_all_akai_extensions()) do
      table.insert(extensions, "*." .. ext)
    end
    
    file_path = renoise.app():prompt_for_filename_to_read(
      extensions, "Import Akai Sample (Any Format)"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  local format = detect_akai_format(file_path)
  if not format then
    renoise.app():show_status("Unknown or unsupported Akai format")
    return
  end
  
  debug_print("Detected format:", format.name, "for file:", file_path)
  
  -- Route to appropriate importer
  local ext = file_path:lower():match("%.([^.]+)$")
  
  if ext == "s" then
    -- Auto-detect S900/S950/S1000/S3000 format
    -- For now, try S1000 first as it's most common
    importS1000Sample(file_path)
  elseif ext == "snd" then
    importMPC2000Sample(file_path)
  elseif ext == "akp" then
    importAKPFile(file_path)
  elseif ext == "p" or ext == "pgm" then
    importAkaiProgram(file_path)
  else
    renoise.app():show_status("No importer available for: " .. ext)
  end
end

-- Batch import from folder (any Akai format)
function importAkaiFolderBatch()
  local folder_path = renoise.app():prompt_for_path("Select Folder with Akai Samples")
  if not folder_path then
    renoise.app():show_status("No folder selected")
    return
  end
  
  print("---------------------------------")
  debug_print("Batch importing Akai samples from:", folder_path)
  
  -- Get list of all Akai files
  local extensions = get_all_akai_extensions()
  local all_files = {}
  
  for _, ext in ipairs(extensions) do
    local command
    if package.config:sub(1,1) == "\\" then  -- Windows
      command = string.format('dir "%s\\*.%s" /b 2>nul', folder_path:gsub('"', '\\"'), ext)
    else  -- macOS and Linux
      command = string.format("find '%s' -name '*.%s' -type f 2>/dev/null", folder_path:gsub("'", "'\\''"), ext)
    end
    
    local handle = io.popen(command)
    if handle then
      for line in handle:lines() do
        if package.config:sub(1,1) == "\\" then
          table.insert(all_files, {path = folder_path .. "\\" .. line, ext = ext})
        else
          table.insert(all_files, {path = line, ext = ext})
        end
      end
      handle:close()
    end
  end
  
  if #all_files == 0 then
    renoise.app():show_status("No Akai files found in folder")
    return
  end
  
  -- Sort by extension for organized import
  table.sort(all_files, function(a, b) return a.ext < b.ext end)
  
  local imported_count = 0
  local format_counts = {}
  
  for _, file_info in ipairs(all_files) do
    local ok, err = pcall(function()
      importAnyAkaiSample(file_info.path)
      imported_count = imported_count + 1
      format_counts[file_info.ext] = (format_counts[file_info.ext] or 0) + 1
    end)
    
    if not ok then
      debug_print("Failed to import:", file_info.path, "Error:", err)
    end
  end
  
  -- Show summary
  local summary = string.format("Imported %d/%d Akai samples:", imported_count, #all_files)
  for ext, count in pairs(format_counts) do
    summary = summary .. string.format("\n  %s: %d files", ext:upper(), count)
  end
  
  renoise.app():show_status(summary)
  debug_print("Batch import complete:", imported_count, "successful imports")
end

-- Export current sample in user-selected Akai format  
function exportCurrentSampleAsAkai()
  local song = renoise.song()
  
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  -- Show format selection dialog
  local format_names = {}
  local export_functions = {
    exportS900Sample,
    exportS1000Sample,
    exportS3000Sample,
    exportMPC2000Sample,
    exportCurrentSampleAsAKP,
    exportAkaiProgram
  }
  
  for i, format in ipairs(AKAI_FORMATS) do
    table.insert(format_names, string.format("%s (%s)", format.name, table.concat(format.extensions, ", ")))
  end
  
  local choice = renoise.app():show_popup_menu(format_names, "Select Akai Export Format")
  if choice > 0 and choice <= #export_functions then
    export_functions[choice]()
  end
end

-- Check which Akai importers are available
function checkAkaiImportersAvailable()
  local available = {}
  local missing = {}
  
  local importers = {
    {name = "S900/S950", func = "importS900Sample"},
    {name = "S1000/S1100/S01", func = "importS1000Sample"},
    {name = "S3000", func = "importS3000Sample"},
    {name = "MPC2000", func = "importMPC2000Sample"},
    {name = "AKP", func = "importAKPFile"},
    {name = "Programs", func = "importAkaiProgram"}
  }
  
  for _, importer in ipairs(importers) do
    if _G[importer.func] then
      table.insert(available, importer.name)
    else
      table.insert(missing, importer.name)
    end
  end
  
  local status = "=== AKAI IMPORTERS STATUS ===\n\n"
  status = status .. "Available formats:\n"
  for _, name in ipairs(available) do
    status = status .. "  " .. name .. "\n"
  end
  
  if #missing > 0 then
    status = status .. "\nMissing importers:\n"
    for _, name in ipairs(missing) do
      status = status .. "  " .. name .. " (missing)\n"
    end
    status = status .. "\nLoad the corresponding PakettiAkai*.lua files to enable all formats."
  else
    status = status .. "\nAll Akai importers are loaded and ready!"
  end
  
  renoise.app():show_message(status)
end

-- Menu entries


renoise.tool():add_keybinding{name = "Global:Paketti:Import Any Akai Sample...",invoke = importAnyAkaiSample}
renoise.tool():add_keybinding{name = "Global:Paketti:Import Akai Folder (Batch)...",invoke = importAkaiFolderBatch}
renoise.tool():add_keybinding{name = "Global:Paketti:Export as Akai Format...",invoke = exportCurrentSampleAsAkai}

-- Universal file import hook for all Akai formats
local universal_akai_integration = {
  name = "Akai Sampler Formats (Universal)",
  category = "sample", 
  extensions = get_all_akai_extensions(),
  invoke = importAnyAkaiSample
}

local function safe_add_hook()
  local ok, err = pcall(function()
    renoise.tool():add_file_import_hook(universal_akai_integration)
  end)
  if not ok then
    debug_print("Could not add universal hook (may already exist):", err)
  end
end

safe_add_hook() 