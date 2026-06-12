-- PakettiMCP/tools/composition.lua
-- High-level musical generators: breakbeats, basslines, drum fills.
--
-- Inspired by the generators in zakhap/renoise-mcp's pattern_gen.py (MIT), but
-- rewritten DETERMINISTIC (no randomization) and writing notes straight into the
-- selected Renoise pattern via the Lua API — so the local-LLM bridge can do
-- "give me an amen break at 174" and get a recognizable groove every time.
--
-- Drum voices use General-MIDI note values (Renoise numbering, C-3 = 36): point
-- these at a GM-style drumkit instrument, or override per-voice with *_note args.
-- Each voice gets its own note column so simultaneous hits never collide.

local function text(s) return { content = {{ type = "text", text = tostring(s) }} } end
local function err(s)  return { content = {{ type = "text", text = tostring(s) }}, isError = true } end
local function song()
  local ok, s = pcall(renoise.song)
  if not ok or not s then error("No song loaded") end
  return s
end

local EMPTY_NOTE = 121
local EMPTY_INST = 255

local DRUMS    = { kick = 36, snare = 38, chh = 42, ohh = 46 }  -- GM, Renoise note values
local VOICE_COL= { kick = 1,  snare = 2,  chh = 3,  ohh = 4 }   -- one column per voice

-- 16-step (one bar of 16th notes) grids; 0-based step indices per voice.
local BREAKS = {
  amen          = { kick={0,10},      snare={4,7,12,15}, chh={0,2,4,6,8,10,12,14}, ohh={14} },
  think         = { kick={0,6,10},    snare={4,12},      chh={0,2,4,6,8,10,12,14}, ohh={7,15} },
  funky_drummer = { kick={0,3,10},    snare={4,6,12,14}, chh={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}, ohh={} },
  apache        = { kick={0,8},       snare={4,12},      chh={0,2,4,6,8,10,12,14}, ohh={} },
  straight      = { kick={0,4,8,12},  snare={4,12},      chh={0,2,4,6,8,10,12,14}, ohh={} },
  two_step      = { kick={0,10},      snare={4,12},      chh={2,6,8,14},           ohh={} },
}

local SCALES = {
  minor            = {0,2,3,5,7,8,10},
  minor_pentatonic = {0,3,5,7,10},
  dorian           = {0,2,3,5,7,9,10},
  phrygian         = {0,1,3,5,7,8,10},
  major            = {0,2,4,5,7,9,11},
}

local NOTE_IDX = {["C"]=0,["C#"]=1,["D"]=2,["D#"]=3,["E"]=4,["F"]=5,["F#"]=6,
                  ["G"]=7,["G#"]=8,["A"]=9,["A#"]=10,["B"]=11}
local function parse_note(s, default_val)
  if s == nil then return default_val end
  s = tostring(s):upper():gsub("%s", "")
  local name, oct = s:match("^([A-G]#?)%-?(%d+)$")
  if not name or not NOTE_IDX[name] or not oct then return default_val end
  return tonumber(oct) * 12 + NOTE_IDX[name]
end

local function resolve(args, s)
  local ti   = math.floor(tonumber(args.track) or s.selected_track_index)
  local pi   = (args.pattern ~= nil) and (math.floor(tonumber(args.pattern)) + 1)
               or s.selected_pattern_index
  local inst = (args.instrument ~= nil) and math.floor(tonumber(args.instrument))
               or (s.selected_instrument_index - 1)
  return ti, pi, inst
end

-- validate + return pat, song_track (or nil + error string)
local function target(args, s)
  local ti, pi, inst = resolve(args, s)
  if pi < 1 or pi > #s.patterns then return nil, "invalid pattern index" end
  local pat = s.patterns[pi]
  if ti < 1 or ti > #pat.tracks then return nil, "invalid track index" end
  local st = s.tracks[ti]
  if st.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return nil, "target track is not a sequencer track"
  end
  return pat, st, ti, inst
end

local function put(pat, st, ti, line_no, col, note_val, inst, vel)
  while st.visible_note_columns < col do
    st.visible_note_columns = st.visible_note_columns + 1
  end
  local nc = pat.tracks[ti]:line(line_no):note_column(col)
  nc.note_value = note_val
  nc.instrument_value = inst < 0 and EMPTY_INST or inst
  if vel ~= nil then nc.volume_value = math.max(0, math.min(0x7F, math.floor(vel))) end
end

local function clear_cols(pat, ti, nlines, cols)
  for L = 1, nlines do
    for _, c in pairs(cols) do
      pat.tracks[ti]:line(L):note_column(c).note_value = EMPTY_NOTE
    end
  end
end

return {
  {
    name = "generate_breakbeat",
    description = [[Write a recognizable breakbeat drum pattern into the pattern, tiled to fill it.
style: amen | think | funky_drummer | apache | straight | two_step (default amen).
Uses GM drum notes (kick/snare/closed-hat/open-hat) on one instrument across 4 note columns.
Does NOT change tempo — call transport_set_bpm separately (e.g. amen break at 174).
track 1-based (default selected), instrument 0-based (default selected), pattern 0-based (default selected).]],
    inputSchema = {
      type = "object",
      properties = {
        style      = { type = "string", description = "amen|think|funky_drummer|apache|straight|two_step" },
        track      = { type = "number", description = "1-based track (default selected)" },
        instrument = { type = "number", description = "0-based instrument (default selected)" },
        pattern    = { type = "number", description = "0-based pattern (default selected)" },
        velocity   = { type = "number", description = "0x00-0x7F base velocity (default 0x7F)" },
        clear      = { type = "boolean", description = "clear the 4 drum columns first (default true)" },
      },
      required = {},
    },
    handler = function(args)
      local ok, s = pcall(song); if not ok then return err(tostring(s)) end
      local style = tostring(args.style or "amen"):lower():gsub("%s", "_")
      local grid = BREAKS[style]
      if not grid then return err("unknown style '" .. style ..
        "' (amen, think, funky_drummer, apache, straight, two_step)") end
      local pat, st, ti, inst = target(args, s)
      if not pat then return err(st) end
      local vel    = math.floor(tonumber(args.velocity) or 0x7F)
      local nlines = pat.number_of_lines
      if args.clear ~= false then clear_cols(pat, ti, nlines, VOICE_COL) end

      local sets = {}
      for voice, list in pairs(grid) do
        local set = {}; for _, stp in ipairs(list) do set[stp] = true end
        sets[voice] = set
      end

      local hits = 0
      for L = 1, nlines do
        local step = (L - 1) % 16
        for voice, set in pairs(sets) do
          if set[step] then
            local v = vel
            if voice == "snare" and step ~= 4 and step ~= 12 then v = vel * 0.5 end  -- ghost
            if voice == "chh" then v = vel * 0.7 end
            put(pat, st, ti, L, VOICE_COL[voice], DRUMS[voice], inst, v)
            hits = hits + 1
          end
        end
      end
      return text(string.format(
        "Wrote '%s' breakbeat: %d hits over %d lines on track %d (instrument %d). Tempo unchanged — set it with transport_set_bpm.",
        style, hits, nlines, ti, inst))
    end,
  },

  {
    name = "generate_bassline",
    description = [[Write a scale-aware bassline into the pattern, tiled to fill it.
scale: minor | minor_pentatonic | dorian | phrygian | major (default minor).
root: note like "C-2" (default C-2). track/instrument/pattern as in generate_breakbeat.]],
    inputSchema = {
      type = "object",
      properties = {
        scale      = { type = "string", description = "minor|minor_pentatonic|dorian|phrygian|major" },
        root       = { type = "string", description = 'root note, e.g. "C-2" (default C-2)' },
        track      = { type = "number", description = "1-based track (default selected)" },
        instrument = { type = "number", description = "0-based instrument (default selected)" },
        pattern    = { type = "number", description = "0-based pattern (default selected)" },
        velocity   = { type = "number", description = "0x00-0x7F (default 0x6A)" },
        clear      = { type = "boolean", description = "clear column 1 first (default true)" },
      },
      required = {},
    },
    handler = function(args)
      local ok, s = pcall(song); if not ok then return err(tostring(s)) end
      local scale = SCALES[tostring(args.scale or "minor"):lower()]
      if not scale then return err("unknown scale (minor, minor_pentatonic, dorian, phrygian, major)") end
      local pat, st, ti, inst = target(args, s)
      if not pat then return err(st) end
      local root   = parse_note(args.root, 24)  -- C-2
      local vel    = math.floor(tonumber(args.velocity) or 0x6A)
      local nlines = pat.number_of_lines
      if args.clear ~= false then clear_cols(pat, ti, nlines, { 1 }) end

      -- deterministic 16-step figure of scale degrees (-1 = rest)
      local FIG = {0,-1,0,-1, 4,-1,0,2, 0,-1,3,-1, 4,-1,2,0}
      local n = #scale
      local notes = 0
      for L = 1, nlines do
        local deg = FIG[((L - 1) % 16) + 1]
        if deg and deg >= 0 then
          local within = scale[(deg % n) + 1]
          local octs   = math.floor(deg / n)
          put(pat, st, ti, L, 1, root + within + octs * 12, inst, vel)
          notes = notes + 1
        end
      end
      return text(string.format("Wrote %s bassline (root %s): %d notes over %d lines on track %d (instrument %d).",
        tostring(args.scale or "minor"), tostring(args.root or "C-2"), notes, nlines, ti, inst))
    end,
  },

  {
    name = "add_drum_fill",
    description = [[Add a snare-roll drum fill (ascending velocity) over the last few lines of the pattern.
fill_lines: how many lines at the end to fill (default 4). track/instrument/pattern as above.]],
    inputSchema = {
      type = "object",
      properties = {
        fill_lines = { type = "number", description = "lines at the end to fill (default 4)" },
        track      = { type = "number", description = "1-based track (default selected)" },
        instrument = { type = "number", description = "0-based instrument (default selected)" },
        pattern    = { type = "number", description = "0-based pattern (default selected)" },
      },
      required = {},
    },
    handler = function(args)
      local ok, s = pcall(song); if not ok then return err(tostring(s)) end
      local pat, st, ti, inst = target(args, s)
      if not pat then return err(st) end
      local nlines = pat.number_of_lines
      local fill   = math.max(1, math.min(nlines, math.floor(tonumber(args.fill_lines) or 4)))
      local startL = nlines - fill + 1
      local base, top = 0x40, 0x7F
      for L = startL, nlines do
        local t = (fill > 1) and (L - startL) / (fill - 1) or 1
        put(pat, st, ti, L, VOICE_COL.snare, DRUMS.snare, inst, base + t * (top - base))
      end
      return text(string.format("Added %d-line snare-roll fill (lines %d-%d) on track %d (instrument %d).",
        fill, startL, nlines, ti, inst))
    end,
  },
}
