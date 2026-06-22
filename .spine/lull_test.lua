-- lull_test.lua — proves PakettiLull approaches 1/2/3 against a LIVE Renoise.
-- Run via PakettiMCP:  paketti_eval { code = 'return dofile(".../.spine/lull_test.lua")' }
-- Non-destructive: adds a scratch instrument + track at the end, asserts, removes them.
local song = renoise.song()
local out = {}
local function log(s) out[#out+1] = s end
local function approx(a, b, tol) return math.abs(a - b) <= (tol or 0.001) end

local ok, e = pcall(dofile, "/Users/esaruoho/work/paketti/PakettiLull.lua")
if not ok then return "DOFILE FAIL: " .. tostring(e) end

local instr_before  = #song.instruments
local strack_before = song.sequencer_track_count

local function cleanup()
  pcall(function()
    if song.sequencer_track_count > strack_before then
      song:delete_track_at(song.sequencer_track_count)
    end
  end)
  pcall(function()
    while #song.instruments > instr_before do
      song:delete_instrument_at(#song.instruments)
    end
  end)
end

local okrun, err = pcall(function()
  -- ── setup: scratch instrument + track at the end ──
  local tinst = instr_before + 1
  song:insert_instrument_at(tinst)
  song.instruments[tinst].name = "LULLTEST"
  local ttrack = strack_before + 1
  song:insert_track_at(ttrack)
  song.tracks[ttrack].name = "LULLTEST"
  local pat = song:pattern(song.selected_pattern_index)
  local ptrack = pat:track(ttrack)
  local instr0 = tinst - 1
  for line = 1, 4 do
    local nc = ptrack:line(line).note_columns[1]
    nc.note_value = 48          -- C-4
    nc.instrument_value = instr0
    nc.volume_value = 0x40      -- 64
  end

  -- ── APPROACH 1: volume-column offset ──
  local changed = PakettiColumnOffsetRange("volume_value", -0x10, ttrack, ttrack, 1, 4, 1, 1)
  local v1 = ptrack:line(1).note_columns[1].volume_value
  log(("A1 vol-offset: changed=%d  0x40-0x10 -> 0x%X  %s"):format(changed, v1,
    (changed == 4 and v1 == 0x30) and "PASS" or "FAIL"))
  PakettiColumnOffsetRange("volume_value", -0x100, ttrack, ttrack, 1, 1, 1, 1)
  local vc = ptrack:line(1).note_columns[1].volume_value
  log(("A1 clamp-low: -> 0x%X  %s"):format(vc, vc == 0 and "PASS" or "FAIL"))

  -- ── APPROACH 2: Lull instrument duplicate ──
  local origvol = song.instruments[tinst].volume
  local _, n2 = PakettiLullInstrumentRange(0.5, ttrack, ttrack, 1, 4, 1, 1)
  local lidx = ptrack:line(1).note_columns[1].instrument_value
  local lins = song.instruments[lidx + 1]
  local nameok = lins.name:find("%(Lull%)$") ~= nil
  local volok = approx(lins.volume, origvol * 0.5, 0.02)
  local madeone = (#song.instruments == instr_before + 2)
  log(("A2 lull-instr: touched=%d remap->0x%X name='%s' vol %.3f->%.3f newInstr=%s  %s"):format(
    n2, lidx, lins.name, origvol, lins.volume, tostring(madeone),
    (nameok and volok and madeone and lidx ~= instr0) and "PASS" or "FAIL"))
  local before_dd = #song.instruments
  PakettiLullInstrumentRange(0.5, ttrack, ttrack, 1, 4, 1, 1)
  log(("A2 dedup: instr %d -> %d (no 2nd dupe)  %s"):format(before_dd, #song.instruments,
    #song.instruments == before_dd and "PASS" or "FAIL"))

  -- ── APPROACH 3: Lull track-volume automation ──
  local env = PakettiLullTrackVolumeRange(0.5, ttrack, 1, 4)
  local param = song.tracks[ttrack].prefx_volume
  local au = pat:track(ttrack):find_automation(param)
  local npts = 0
  pcall(function() npts = #au.points end)
  log(("A3 track-vol-auto: env=%s points=%d  %s"):format(tostring(au ~= nil), npts,
    (au ~= nil and npts >= 2) and "PASS" or "FAIL"))
end)
if not okrun then log("EXCEPTION: " .. tostring(err)) end

cleanup()
local restored = (#song.instruments == instr_before) and (song.sequencer_track_count == strack_before)
log(("CLEANUP: instr %d/%d tracks %d/%d  %s"):format(#song.instruments, instr_before,
  song.sequencer_track_count, strack_before, restored and "PASS" or "FAIL"))
return table.concat(out, "  |  ")
