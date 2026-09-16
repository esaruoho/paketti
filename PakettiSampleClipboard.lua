-- PakettiSampleClipboard.lua
-- A session-persistent sample clipboard, in the spirit of Hex's HexTools.
--
-- Renoise's own sample copy/paste is buffer-only and tied to the Sample Editor.
-- This keeps ONE sample (its audio plus the properties that matter) parked in a
-- clipboard that survives switching instruments and songs for the length of the
-- session, so you can copy a sample here and paste it into any instrument there.
--
-- The audio is written to a temp WAV on disk (Renoise Lua can't hold a raw
-- buffer across instrument edits safely); the properties travel in a Lua table.

local M = {}

-- The clipboard: a temp WAV path plus the sample properties to restore.
local clip = nil  -- { path=..., name=..., props={...} }

local function copy_props(sample)
  return {
    volume            = sample.volume,
    panning           = sample.panning,
    transpose         = sample.transpose,
    fine_tune         = sample.fine_tune,
    beat_sync_enabled = sample.beat_sync_enabled,
    beat_sync_lines   = sample.beat_sync_lines,
    oneshot           = sample.oneshot,
    loop_release      = sample.loop_release,
    loop_mode         = sample.loop_mode,
    loop_start        = sample.loop_start,
    loop_end          = sample.loop_end,
    autoseek          = sample.autoseek,
    autofade          = sample.autofade,
    interpolation     = sample.interpolation,
    oversample_enabled= sample.oversample_enabled,
    new_note_action   = sample.new_note_action,
  }
end

local function apply_props(sample, p, frames)
  -- Wrap each assignment: property availability varies across Renoise versions,
  -- and loop bounds must be valid for the pasted buffer length.
  local function try(fn) pcall(fn) end
  try(function() sample.volume            = p.volume end)
  try(function() sample.panning           = p.panning end)
  try(function() sample.transpose         = p.transpose end)
  try(function() sample.fine_tune         = p.fine_tune end)
  try(function() sample.autoseek          = p.autoseek end)
  try(function() sample.autofade          = p.autofade end)
  try(function() sample.interpolation     = p.interpolation end)
  try(function() sample.oversample_enabled= p.oversample_enabled end)
  try(function() sample.oneshot           = p.oneshot end)
  try(function() sample.loop_release      = p.loop_release end)
  try(function() sample.new_note_action   = p.new_note_action end)
  try(function() sample.beat_sync_lines   = p.beat_sync_lines end)
  try(function() sample.beat_sync_enabled = p.beat_sync_enabled end)
  -- Loop points: clamp to the pasted buffer, then set the mode.
  if frames and frames > 0 and p.loop_start and p.loop_end then
    local ls = math.max(1, math.min(p.loop_start, frames))
    local le = math.max(ls, math.min(p.loop_end, frames))
    try(function() sample.loop_start = ls end)
    try(function() sample.loop_end   = le end)
  end
  try(function() sample.loop_mode = p.loop_mode end)
end

function PakettiSampleClipboardCopy()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample with data selected to copy.")
    return
  end

  -- Fresh temp file each copy; drop the previous one.
  if clip and clip.path then pcall(function() os.remove(clip.path) end) end

  local path = os.tmpname() .. "_paketti_sample_clipboard.wav"
  local ok = sample.sample_buffer:save_as(path, "wav")
  if not ok then
    renoise.app():show_status("Failed to write sample to clipboard.")
    return
  end

  clip = {
    path  = path,
    name  = sample.name,
    props = copy_props(sample),
  }
  renoise.app():show_status(string.format(
    "Copied sample '%s' to clipboard. Use Paste Sample from Clipboard.",
    (sample.name ~= "" and sample.name or "(unnamed)")))
end

function PakettiSampleClipboardPaste()
  if not clip or not clip.path then
    renoise.app():show_status("Sample clipboard is empty. Copy a sample first.")
    return
  end
  if not io.exists(clip.path) then
    renoise.app():show_status("Clipboard sample file is gone. Copy a sample again.")
    clip = nil
    return
  end

  local song = renoise.song()
  local instr = song.selected_instrument
  if not instr then
    renoise.app():show_status("No instrument selected to paste into.")
    return
  end

  local slot = #instr.samples + 1
  instr:insert_sample_at(slot)
  song.selected_sample_index = slot
  local sample = instr.samples[slot]  -- direct access; never trust selected_sample here

  local ok = sample.sample_buffer:load_from(clip.path)
  if not ok then
    renoise.app():show_status("Failed to load clipboard sample.")
    return
  end

  local frames = sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_frames or 0
  if clip.name and clip.name ~= "" then sample.name = clip.name end
  apply_props(sample, clip.props, frames)

  renoise.app():show_status(string.format(
    "Pasted sample '%s' into instrument slot %d.",
    (clip.name ~= "" and clip.name or "(unnamed)"), slot))
end

function PakettiSampleClipboardClear()
  if clip and clip.path then pcall(function() os.remove(clip.path) end) end
  clip = nil
  renoise.app():show_status("Sample clipboard cleared.")
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Copy Sample to Clipboard",    invoke=PakettiSampleClipboardCopy}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Paste Sample from Clipboard", invoke=PakettiSampleClipboardPaste}
renoise.tool():add_keybinding{name="Global:Paketti:Copy Sample to Clipboard",    invoke=PakettiSampleClipboardCopy}
renoise.tool():add_keybinding{name="Global:Paketti:Paste Sample from Clipboard", invoke=PakettiSampleClipboardPaste}
renoise.tool():add_keybinding{name="Global:Paketti:Clear Sample Clipboard",      invoke=PakettiSampleClipboardClear}

local MENU = "Main Menu:Tools:Paketti:!Sample Editor:Sample Clipboard:"
PakettiAddMenuEntry{name=MENU.."Copy Sample to Clipboard",    invoke=PakettiSampleClipboardCopy}
PakettiAddMenuEntry{name=MENU.."Paste Sample from Clipboard", invoke=PakettiSampleClipboardPaste}
PakettiAddMenuEntry{name=MENU.."Clear Sample Clipboard",      invoke=PakettiSampleClipboardClear}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Copy Sample to Clipboard",    invoke=PakettiSampleClipboardCopy}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Paste Sample from Clipboard", invoke=PakettiSampleClipboardPaste}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Paste Sample from Clipboard", invoke=PakettiSampleClipboardPaste}

renoise.tool():add_midi_mapping{name="Paketti:Copy Sample to Clipboard",    invoke=function(m) if m:is_trigger() then PakettiSampleClipboardCopy() end end}
renoise.tool():add_midi_mapping{name="Paketti:Paste Sample from Clipboard", invoke=function(m) if m:is_trigger() then PakettiSampleClipboardPaste() end end}

return M
