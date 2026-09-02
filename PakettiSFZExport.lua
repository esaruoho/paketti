--[[============================================================================
PakettiSFZExport.lua — SFZ mapping export

SFZ is an open, plain-text instrument format read by sfizz, Sforzando, Bitwig,
Falcon and most free samplers. Paketti could already convert SFZ *into* XRNI
(PakettiForeignSnippets); this is the other direction.

Two shapes come out of it, both writing one WAV and one .sfz beside it:

  a sliced instrument   one region per slice, all pointing into the same WAV with
                        `offset` and `end` marking the slice, laid out from C1 up
  everything else       one region per sample, using each sample's own key range,
                        root note and velocity range

Nothing is transcoded: `sample_buffer:save_as` writes the audio and the .sfz is a
text sidecar, so the export is lossless with respect to what Renoise holds.
============================================================================]]--

local SFZ_FIRST_NOTE = 36   -- C1, matching the drum-kit convention elsewhere

local function sfz_escape(name)
  return (tostring(name or ""):gsub("[\r\n]", " "))
end

--- Write the selected instrument as a .sfz plus its WAV(s).
function PakettiSFZExport(sfz_path)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "the selected instrument has no samples"
  end

  local dir = pakettiFSPath.dirname(sfz_path)
  local base = pakettiFSPath.basename(sfz_path):gsub("%.sfz$", "")
  local first = instrument.samples[1]
  local markers = first.slice_markers

  local lines = {
    "// Exported from Renoise by Paketti",
    string.format("// instrument: %s", sfz_escape(instrument.name)),
    "",
    "<control>",
    "default_path=",
    "",
    "<global>",
    "ampeg_release=0.1",
    "",
  }
  local written_wavs = 0
  local regions = 0

  if #markers > 0 and first.sample_buffer.has_sample_data then
    -- one WAV, one region per slice, delimited by offset/end
    local wav_name = pakettiFSPath.sanitize_filename(base, "sample") .. ".wav"
    local wav_path = pakettiFSPath.join(dir, wav_name)
    local ok = pcall(function() return first.sample_buffer:save_as(wav_path, "wav") end)
    if not ok or not io.exists(wav_path) then
      return false, "could not write " .. wav_path
    end
    written_wavs = 1

    local frames = first.sample_buffer.number_of_frames
    local bounds = {}
    for i = 1, #markers do bounds[#bounds + 1] = markers[i] end
    bounds[#bounds + 1] = frames + 1

    -- 128 notes exist, so a set that will not fit from C1 starts lower rather than
    -- losing its tail; laying out from C1 and breaking at 127 silently dropped
    -- every slice past the 92nd.
    local count = #bounds - 1
    local first_note = SFZ_FIRST_NOTE
    if first_note + count - 1 > 127 then first_note = 128 - count end
    if first_note < 0 then first_note = 0 end

    for i = 1, count do
      local note = first_note + i - 1
      if note > 127 then break end
      local slice = instrument.samples[i + 1]
      lines[#lines + 1] = "<region>"
      lines[#lines + 1] = "sample=" .. wav_name
      lines[#lines + 1] = string.format("lokey=%d hikey=%d pitch_keycenter=%d", note, note, note)
      -- SFZ offset/end are frame indices into the sample, zero based
      lines[#lines + 1] = string.format("offset=%d end=%d", bounds[i] - 1, bounds[i + 1] - 2)
      if slice and slice.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
        local mode = (slice.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG)
          and "loop_alternate" or "loop_continuous"
        lines[#lines + 1] = "loop_mode=" .. mode
        lines[#lines + 1] = string.format("loop_start=%d loop_end=%d",
          math.max(0, slice.loop_start - 1), math.max(0, slice.loop_end - 1))
      end
      if slice and slice.name ~= "" then
        lines[#lines + 1] = "// " .. sfz_escape(slice.name)
      end
      lines[#lines + 1] = ""
      regions = regions + 1
    end
  else
    -- one WAV and one region per sample, keeping each sample's own mapping
    for i = 1, #instrument.samples do
      local smp = instrument.samples[i]
      if smp.sample_buffer.has_sample_data then
        local nm = pakettiFSPath.sanitize_filename(
          (smp.name ~= "" and smp.name) or (base .. "_" .. i), base .. "_" .. i)
        local wav_name = pakettiFSPath.sanitize_filename(
          string.format("%s_%02d_%s", base, i, nm), "sample") .. ".wav"
        local wav_path = pakettiFSPath.join(dir, wav_name)
        local ok = pcall(function() return smp.sample_buffer:save_as(wav_path, "wav") end)
        if ok and io.exists(wav_path) then
          written_wavs = written_wavs + 1
          local map = smp.sample_mapping
          lines[#lines + 1] = "<region>"
          lines[#lines + 1] = "sample=" .. wav_name
          lines[#lines + 1] = string.format("lokey=%d hikey=%d pitch_keycenter=%d",
            map.note_range[1], map.note_range[2], map.base_note)
          lines[#lines + 1] = string.format("lovel=%d hivel=%d",
            math.max(1, map.velocity_range[1]), map.velocity_range[2])
          if smp.transpose ~= 0 then
            lines[#lines + 1] = string.format("transpose=%d", smp.transpose)
          end
          if smp.fine_tune ~= 0 then
            lines[#lines + 1] = string.format("tune=%d",
              math.floor(smp.fine_tune / 127 * 100 + 0.5))
          end
          if smp.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
            local mode = (smp.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG)
              and "loop_alternate" or "loop_continuous"
            lines[#lines + 1] = "loop_mode=" .. mode
            lines[#lines + 1] = string.format("loop_start=%d loop_end=%d",
              math.max(0, smp.loop_start - 1), math.max(0, smp.loop_end - 1))
          end
          lines[#lines + 1] = ""
          regions = regions + 1
        end
      end
    end
  end

  if regions == 0 then
    return false, "nothing to export: no sample in the instrument holds audio"
  end

  local f = io.open(sfz_path, "wb")
  if not f then return false, "could not write " .. sfz_path end
  f:write(table.concat(lines, "\n"))
  f:close()

  return true, string.format("Wrote %s (%d region%s, %d WAV%s)",
    pakettiFSPath.basename(sfz_path), regions, regions == 1 and "" or "s",
    written_wavs, written_wavs == 1 and "" or "s")
end

function PakettiSFZExportDialog()
  local path = renoise.app():prompt_for_filename_to_write("sfz", "Export SFZ mapping")
  if not path or path == "" then return end
  if not path:lower():match("%.sfz$") then path = path .. ".sfz" end
  local ok, msg = PakettiSFZExport(path)
  if ok then renoise.app():show_status(msg)
  else renoise.app():show_error("SFZ export failed.\n\n" .. tostring(msg)) end
  print("-- PakettiSFZExport: " .. tostring(msg))
end

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:File Formats:Export SFZ Mapping (.sfz)...",
  invoke=function() PakettiSFZExportDialog() end}
PakettiAddMenuEntry{name="Sample Editor:Paketti:Export:Export SFZ Mapping (.sfz)...",
  invoke=function() PakettiSFZExportDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Export SFZ Mapping",
  invoke = function() PakettiSFZExportDialog() end }
