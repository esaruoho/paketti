-- PakettiDuplicateInstrumentFinder.lua
-- Find instruments whose samples are byte-for-byte the same audio, ported in
-- spirit from Hex's HexTools "Find Duplicate Single-Sample Instruments".
--
-- Paketti already has "Duplicate Instrument" (which CREATES a copy). This is the
-- opposite: a DETECTOR that reports which existing instruments are audio-identical
-- so you can spot and clean up accidental duplicates. It only reports — nothing
-- is deleted or changed.
--
-- The HexTools original compares every frame of every sample pair (O(n^2) over
-- full buffers), which can freeze Renoise on long samples. Here each sample gets
-- a cheap fingerprint (length + channels + rate + a checksum over sampled frames),
-- instruments are grouped by their concatenated per-sample fingerprints, and any
-- group with more than one member is reported.

-- Number of frames to sample per channel when checksumming a buffer.
local FINGERPRINT_TAPS = 512

local function buffer_fingerprint(buf)
  if not buf.has_sample_data then return "empty" end
  local frames = buf.number_of_frames
  local chans  = buf.number_of_channels
  local rate   = buf.sample_rate
  local bits   = buf.bit_depth
  -- Even stride across the buffer; at least 1.
  local step = math.max(1, math.floor(frames / FINGERPRINT_TAPS))
  local sum1, sum2 = 0.0, 0.0
  local n = 0
  for ch = 1, chans do
    local f = 1
    while f <= frames do
      local v = buf:sample_data(ch, f)
      sum1 = sum1 + v
      sum2 = sum2 + v * v * (f % 97)   -- position-weighted so order matters
      n = n + 1
      f = f + step
    end
  end
  return string.format("%d:%d:%d:%d:%d:%.8g:%.8g", frames, chans, rate, bits, n, sum1, sum2)
end

local function instrument_fingerprint(instr)
  local parts = {}
  for s = 1, #instr.samples do
    parts[#parts + 1] = buffer_fingerprint(instr:sample(s).sample_buffer)
  end
  return table.concat(parts, "|")
end

function PakettiFindDuplicateInstruments()
  local song = renoise.song()

  -- Group non-empty, non-plugin instruments by fingerprint.
  local groups = {}       -- fingerprint -> { indices... }
  local order  = {}       -- keep first-seen order of fingerprints
  for i = 1, #song.instruments do
    local instr = song:instrument(i)
    if #instr.samples > 0 and not instr.plugin_properties.plugin_loaded then
      local fp = instrument_fingerprint(instr)
      if not groups[fp] then groups[fp] = {} order[#order + 1] = fp end
      table.insert(groups[fp], i)
    end
  end

  local lines = {}
  local dup_count = 0
  for _, fp in ipairs(order) do
    local members = groups[fp]
    if #members > 1 then
      dup_count = dup_count + 1
      local names = {}
      for _, idx in ipairs(members) do
        local instr = song:instrument(idx)
        local nm = instr.name ~= "" and instr.name or "(unnamed)"
        -- Show the 0-based instrument index in HEX, like Renoise's instrument box.
        names[#names + 1] = string.format("%02X %s", idx - 1, nm)
      end
      lines[#lines + 1] = "• " .. table.concat(names, "   ==   ")
    end
  end

  if dup_count == 0 then
    renoise.app():show_message("No duplicate instruments found (compared by sample audio).")
    return
  end

  local header = string.format(
    "Found %d group(s) of instruments with identical sample audio:\n\n", dup_count)
  renoise.app():show_message(header .. table.concat(lines, "\n"))
end

renoise.tool():add_keybinding{name="Global:Paketti:Find Duplicate Instruments (by Audio)", invoke=PakettiFindDuplicateInstruments}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:Find Duplicate Instruments (by Audio)...", invoke=PakettiFindDuplicateInstruments}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Find Duplicate Instruments (by Audio)...", invoke=PakettiFindDuplicateInstruments}
renoise.tool():add_midi_mapping{name="Paketti:Find Duplicate Instruments (by Audio)", invoke=function(m) if m:is_trigger() then PakettiFindDuplicateInstruments() end end}
