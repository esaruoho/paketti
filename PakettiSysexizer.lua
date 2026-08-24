-- PakettiSysexizer.lua
-- SysEx Control Surface + .syx File Dumper
--
-- Renoise has no native device that emits SysEx, so unlike CCizer (which builds a
-- *Instr. MIDI Control device and lets Renoise do the sending), Sysexizer owns its
-- own control surface and sends the bytes itself via renoise.Midi.
--
-- 32 control slots are pre-registered as MIDI mappings at tool load time (names must
-- be static and unique -- see house rule 24), and a loaded definition file decides
-- what each slot actually transmits.
--
-- Definition file format (sysexizer/*.txt), one control per line:
--
--   # comment
--   @device  Yamaha TX16W
--   @channel 1
--   @delay   20
--   Filter Cutoff : F0 43 10+CH 7A ~ 00 4A VV SUM F7 : 0 127 64
--
--   Template tokens:
--     XX      literal hex byte
--     XX+CH   literal hex byte plus (channel - 1)      e.g. 10+CH on ch3 -> 0x12
--     VV      the control value, 7-bit (0..127)
--     VH / VL  high / low 7-bit half of a 14-bit value
--     ~       start of a checksum region (emits nothing)
--     SUM     Roland/Yamaha checksum over bytes since ~   ((0x80 - sum) % 0x80)
--
--   Trailing ": min max default" is optional (defaults to 0 127 0).

local separator = package.config:sub(1,1)
local bit = require("bit")
local SLOT_COUNT = 32

local dialog = nil
local vb = nil

-- module state; never touches renoise.song() at load time
local sx = {
  controls = {},          -- parsed control defs, 1..SLOT_COUNT
  values = {},            -- current value per slot
  device_name = "(none loaded)",
  definition = "",
  channel = 1,
  delay_ms = 20,
  out_dev = nil,
  out_name = nil,
  slider_id = {},
  value_id = {},
  syx_path = nil,
  syx_msgs = nil,
  sds_timer = nil,
  sds_packet = 0,
  sds_packets = 0,
  sds_sample_number = 0,
  building = false,
  dump_timer = nil,
  dump_index = 0,
  log = {},
  mon_dev = nil,
  mon_name = nil,
  mon_partial = nil,
  mon_msgs = {}
}

for i = 1, SLOT_COUNT do
  sx.slider_id[i] = "sysexizer_slider_" .. i
  sx.value_id[i] = "sysexizer_value_" .. i
  sx.values[i] = 0
end

--------------------------------------------------------------------------------
-- helpers (declared before every caller -- house rule 28)
--------------------------------------------------------------------------------

local function sx_log(fmt, ...)
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  print("-- Sysexizer: " .. msg)
  sx.log[#sx.log + 1] = msg
  if #sx.log > 200 then table.remove(sx.log, 1) end
end

local function get_sysexizer_folder()
  return renoise.tool().bundle_path .. "sysexizer" .. separator
end

local function scan_sysexizer_files()
  local path = get_sysexizer_folder()
  local files = {}
  local ok, result = pcall(function() return os.filenames(path, "*.txt") end)
  if ok and result then
    for _, filename in ipairs(result) do
      local clean = filename:match("[^" .. separator .. "]+$")
      -- files starting with "_" are documentation (e.g. _format.txt), not devices
      if clean and not clean:match("^_") then
        files[#files + 1] = {
          name = clean,
          display_name = clean:gsub("%.txt$", ""),
          full_path = path .. clean
        }
      end
    end
  end
  table.sort(files, function(a, b) return a.display_name:lower() < b.display_name:lower() end)
  return files
end

-- parse one template string into a token list; returns nil, err on failure
local function parse_template(template)
  local tokens = {}
  for word in template:gmatch("%S+") do
    local upper = word:upper()
    if upper == "VV" then
      tokens[#tokens + 1] = { kind = "value" }
    elseif upper == "VH" then
      tokens[#tokens + 1] = { kind = "value_hi" }
    elseif upper == "VL" then
      tokens[#tokens + 1] = { kind = "value_lo" }
    elseif upper == "CH" then
      tokens[#tokens + 1] = { kind = "channel" }
    elseif upper == "SUM" then
      tokens[#tokens + 1] = { kind = "checksum" }
    elseif upper == "~" then
      tokens[#tokens + 1] = { kind = "checksum_start" }
    else
      local base = upper:match("^(%x%x)%+CH$")
      if base then
        tokens[#tokens + 1] = { kind = "byte_plus_channel", value = tonumber(base, 16) }
      else
        local literal = upper:match("^(%x%x)$")
        if not literal then
          return nil, "unrecognised token '" .. word .. "'"
        end
        tokens[#tokens + 1] = { kind = "byte", value = tonumber(literal, 16) }
      end
    end
  end
  if #tokens == 0 then return nil, "empty template" end
  if tokens[1].kind ~= "byte" or tokens[1].value ~= 0xF0 then
    return nil, "template must start with F0"
  end
  if tokens[#tokens].kind ~= "byte" or tokens[#tokens].value ~= 0xF7 then
    return nil, "template must end with F7"
  end
  return tokens
end

-- realise a token list into actual bytes for a given value + channel
local function build_message(tokens, value, channel)
  local bytes = {}
  local sum, summing = 0, false
  local v = math.max(0, math.min(16383, math.floor(value or 0)))
  local function emit(b)
    b = b % 256
    bytes[#bytes + 1] = b
    if summing then sum = sum + b end
  end
  for _, t in ipairs(tokens) do
    if t.kind == "byte" then
      emit(t.value)
    elseif t.kind == "byte_plus_channel" then
      emit(t.value + (channel - 1))
    elseif t.kind == "channel" then
      emit(channel - 1)
    elseif t.kind == "value" then
      emit(v % 128)
    elseif t.kind == "value_hi" then
      emit(math.floor(v / 128) % 128)
    elseif t.kind == "value_lo" then
      emit(v % 128)
    elseif t.kind == "checksum_start" then
      summing, sum = true, 0
    elseif t.kind == "checksum" then
      summing = false
      emit((0x80 - (sum % 0x80)) % 0x80)
    end
  end
  return bytes
end

local function bytes_to_hex(bytes)
  local out = {}
  for _, b in ipairs(bytes) do out[#out + 1] = string.format("%02X", b) end
  return table.concat(out, " ")
end

local function clamp_byte(value)
  return math.max(0, math.min(127, math.floor(value or 0)))
end

local function append_u14_7bit(bytes, value)
  value = math.max(0, math.min(0x3FFF, math.floor(value or 0)))
  bytes[#bytes + 1] = value % 128
  bytes[#bytes + 1] = math.floor(value / 128) % 128
end

local function append_u21_7bit(bytes, value)
  value = math.max(0, math.min(0x1FFFFF, math.floor(value or 0)))
  bytes[#bytes + 1] = value % 128
  bytes[#bytes + 1] = math.floor(value / 128) % 128
  bytes[#bytes + 1] = math.floor(value / 16384) % 128
end

--------------------------------------------------------------------------------
-- definition file loading
--------------------------------------------------------------------------------

local function load_definition_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    renoise.app():show_error("Sysexizer: cannot open definition file: " .. tostring(filepath))
    return nil
  end

  local controls = {}
  local device_name = filepath:match("[^" .. separator .. "]+$") or "unknown"
  local channel, delay_ms = nil, nil
  local line_no, errors = 0, 0

  for line in file:lines() do
    line_no = line_no + 1
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and not line:match("^#") then
      local key, val = line:match("^@(%w+)%s+(.+)$")
      if key then
        key = key:lower()
        if key == "device" then device_name = val
        elseif key == "channel" then channel = tonumber(val)
        elseif key == "delay" then delay_ms = tonumber(val)
        else sx_log("line %d: unknown directive @%s (ignored)", line_no, key) end
      else
        local name, template, range = line:match("^(.-)%s*:%s*(.-)%s*:%s*(.+)$")
        if not name then
          name, template = line:match("^(.-)%s*:%s*(.+)$")
        end
        if name and template and name ~= "" then
          local tokens, err = parse_template(template)
          if tokens then
            local mn, mx, dflt = 0, 127, 0
            if range then
              local a, b, c = range:match("^(-?%d+)%s+(-?%d+)%s*(-?%d*)$")
              if a then
                mn, mx = tonumber(a), tonumber(b)
                dflt = tonumber(c) or mn
              end
            end
            if mx <= mn then mx = mn + 1 end
            if #controls < SLOT_COUNT then
              controls[#controls + 1] = {
                name = name, tokens = tokens, template = template,
                min = mn, max = mx, default = math.max(mn, math.min(mx, dflt))
              }
            else
              sx_log("line %d: more than %d controls, ignoring the rest", line_no, SLOT_COUNT)
              break
            end
          else
            errors = errors + 1
            sx_log("line %d: %s -- skipped", line_no, err)
          end
        else
          errors = errors + 1
          sx_log("line %d: could not parse '%s'", line_no, line)
        end
      end
    end
  end
  file:close()

  sx_log("loaded %d controls from %s (%d bad lines)", #controls, device_name, errors)
  return controls, device_name, channel, delay_ms
end

--------------------------------------------------------------------------------
-- MIDI output
--------------------------------------------------------------------------------

local function close_output()
  if sx.out_dev then
    pcall(function() sx.out_dev:close() end)
    sx.out_dev = nil
    sx.out_name = nil
  end
end

local function open_output(name)
  if sx.out_dev and sx.out_name == name then return true end
  close_output()
  if not name or name == "" then return false end
  local ok, dev = pcall(function() return renoise.Midi.create_output_device(name) end)
  if not ok or not dev then
    sx_log("could not open MIDI output '%s'", tostring(name))
    return false
  end
  sx.out_dev = dev
  sx.out_name = name
  sx_log("opened MIDI output '%s'", name)
  return true
end

local function send_bytes(bytes)
  if not sx.out_dev then
    renoise.app():show_status("Sysexizer: no MIDI output port selected")
    return false
  end
  local ok, err = pcall(function() sx.out_dev:send(bytes) end)
  if not ok then
    sx_log("send failed: %s", tostring(err))
    return false
  end
  return true
end

-- send one slot's SysEx for its current value; returns the bytes it built
local function send_slot(slot)
  local ctrl = sx.controls[slot]
  if not ctrl then return nil end
  local bytes = build_message(ctrl.tokens, sx.values[slot], sx.channel)
  send_bytes(bytes)
  return bytes
end

--------------------------------------------------------------------------------
-- value setting (shared by dialog sliders and MIDI mappings)
--------------------------------------------------------------------------------

local function update_slot_views(slot)
  if not (dialog and dialog.visible and vb) then return end
  local ctrl = sx.controls[slot]
  local sid, vid = sx.slider_id[slot], sx.value_id[slot]
  if vb.views[sid] then vb.views[sid].value = sx.values[slot] end
  if vb.views[vid] then
    vb.views[vid].text = ctrl and tostring(sx.values[slot]) or "-"
  end
end

-- set a slot value in the control's own range and transmit
function PakettiSysexizerSetSlot(slot, value, do_send)
  local ctrl = sx.controls[slot]
  if not ctrl then return end
  value = math.max(ctrl.min, math.min(ctrl.max, math.floor(value + 0.5)))
  sx.values[slot] = value
  update_slot_views(slot)
  if do_send ~= false then send_slot(slot) end
end

-- MIDI mapping entry point: 0..127 from the controller, scaled into the control range
function PakettiSysexizerMidiSlot(slot, message)
  local ctrl = sx.controls[slot]
  if not ctrl then
    renoise.app():show_status(string.format("Sysexizer: slot %02d has no control loaded", slot))
    return
  end
  if not message:is_abs_value() then return end
  local frac = message.int_value / 127
  local value = ctrl.min + frac * (ctrl.max - ctrl.min)
  PakettiSysexizerSetSlot(slot, value, true)
  renoise.app():show_status(string.format("Sysexizer: %s = %d", ctrl.name, sx.values[slot]))
end

function PakettiSysexizerSendAll()
  local n = 0
  for slot = 1, SLOT_COUNT do
    if sx.controls[slot] then
      send_slot(slot)
      n = n + 1
    end
  end
  renoise.app():show_status(string.format("Sysexizer: sent %d control messages", n))
  sx_log("Send All: %d messages", n)
  return n
end

function PakettiSysexizerApplyDefinition(filepath)
  local controls, device_name, channel, delay_ms = load_definition_file(filepath)
  if not controls then return false end
  sx.controls = controls
  sx.device_name = device_name
  sx.definition = filepath
  if channel then sx.channel = math.max(1, math.min(16, channel)) end
  if delay_ms then sx.delay_ms = math.max(0, math.min(1000, delay_ms)) end
  for slot = 1, SLOT_COUNT do
    sx.values[slot] = controls[slot] and controls[slot].default or 0
  end
  if dialog and dialog.visible then
    for slot = 1, SLOT_COUNT do
      local ctrl = controls[slot]
      local sid = sx.slider_id[slot]
      if vb and vb.views[sid] then
        vb.views[sid].min = ctrl and ctrl.min or 0
        vb.views[sid].max = ctrl and ctrl.max or 127
        vb.views[sid].value = sx.values[slot]
        vb.views[sid].active = (ctrl ~= nil)
      end
      local nid = "sysexizer_name_" .. slot
      if vb and vb.views[nid] then
        vb.views[nid].text = string.format("%02d %s", slot, ctrl and ctrl.name or "-")
      end
      update_slot_views(slot)
    end
    if vb and vb.views["sysexizer_device"] then
      vb.views["sysexizer_device"].text = sx.device_name
    end
  end
  renoise.app():show_status(string.format("Sysexizer: loaded %d controls from %s", #controls, device_name))
  return true
end

--------------------------------------------------------------------------------
-- .syx file dumping (paced -- unpaced back-to-back sends can arrive out of order)
--------------------------------------------------------------------------------

-- split a raw .syx byte string into individual F0..F7 messages
function PakettiSysexizerSplitSyx(data)
  local msgs, cur = {}, nil
  for i = 1, #data do
    local b = data:byte(i)
    if b == nil then break end
    if b == 0xF0 then
      cur = { b }
    elseif cur then
      cur[#cur + 1] = b
      if b == 0xF7 then
        msgs[#msgs + 1] = cur
        cur = nil
      end
    end
  end
  return msgs
end

function PakettiSysexizerLoadSyxFile(filepath)
  local f = io.open(filepath, "rb")
  if not f then
    renoise.app():show_error("Sysexizer: cannot open .syx file: " .. tostring(filepath))
    return nil
  end
  local data = f:read("*a")
  f:close()
  if not data or #data == 0 then
    renoise.app():show_error("Sysexizer: .syx file is empty: " .. tostring(filepath))
    return nil
  end
  local msgs = PakettiSysexizerSplitSyx(data)
  sx.syx_path = filepath
  sx.syx_msgs = msgs
  local total = 0
  for _, m in ipairs(msgs) do total = total + #m end
  sx_log("loaded %s: %d bytes -> %d SysEx messages (%d bytes in messages)", filepath, #data, #msgs, total)
  if dialog and dialog.visible and vb and vb.views["sysexizer_syxinfo"] then
    vb.views["sysexizer_syxinfo"].text = string.format("%s  (%d msgs, %d bytes)",
      filepath:match("[^" .. separator .. "]+$") or filepath, #msgs, total)
  end
  return msgs
end

local function stop_dump()
  if sx.dump_timer then
    pcall(function() renoise.tool():remove_timer(sx.dump_timer) end)
    sx.dump_timer = nil
  end
end

function PakettiSysexizerDumpSyx()
  if not sx.syx_msgs or #sx.syx_msgs == 0 then
    renoise.app():show_status("Sysexizer: no .syx file loaded")
    return false
  end
  if not sx.out_dev then
    renoise.app():show_status("Sysexizer: no MIDI output port selected")
    return false
  end
  stop_dump()
  sx.dump_index = 0
  local total = #sx.syx_msgs

  -- Pacing matters, and a FIXED gap is not enough. MIDI runs at 31250 baud, so one
  -- byte takes ~0.32 ms on the wire; a 512-byte block needs ~164 ms to drain. Firing
  -- the next message before the previous one has left causes the driver queue to back
  -- up, and short messages then OVERTAKE the large ones already queued -- verified on
  -- a loopback port: a 6-byte terminator arrived 6 places early behind 512-byte blocks.
  -- So each gap = the message's own wire time + the user's inter-message delay, and the
  -- timer re-arms itself with a fresh interval instead of running at a fixed rate.
  local function wire_time_ms(msg)
    return math.ceil(#msg * 0.32)
  end

  -- Nothing in here may throw: an error escaping a timer notifier makes Renoise
  -- disable ALL of this tool's notifiers until Renoise is restarted.
  local tick
  tick = function()
    local ok, err = pcall(function()
      pcall(function() renoise.tool():remove_timer(tick) end)
      sx.dump_index = sx.dump_index + 1
      if sx.dump_index > total then
        sx.dump_timer = nil
        renoise.app():show_status(string.format("Sysexizer: dump complete -- %d messages sent", total))
        sx_log("dump complete: %d messages", total)
        return
      end
      local msg = sx.syx_msgs[sx.dump_index]
      send_bytes(msg)
      renoise.app():show_status(string.format("Sysexizer: dumping %d/%d (%d bytes)",
        sx.dump_index, total, #msg))
      renoise.tool():add_timer(tick, math.max(1, sx.delay_ms + wire_time_ms(msg)))
    end)
    if not ok then
      stop_dump()
      sx_log("dump aborted: %s", tostring(err))
      renoise.app():show_status("Sysexizer: dump aborted -- see console")
    end
  end

  sx.dump_timer = tick
  renoise.tool():add_timer(tick, 1)
  sx_log("dumping %d messages to '%s' (gap = %d ms + wire time)", total, tostring(sx.out_name), sx.delay_ms)
  return true
end

function PakettiSysexizerBrowseAndDump()
  local path = renoise.app():prompt_for_filename_to_read({ "*.syx", "*.mid" }, "Select SysEx file to dump")
  if not path or path == "" then return end
  if PakettiSysexizerLoadSyxFile(path) then
    PakettiSysexizerDumpSyx()
  end
end

--------------------------------------------------------------------------------
-- MIDI Sample Dump Standard export (selected Renoise sample -> SDS)
--------------------------------------------------------------------------------

local function stop_sds_dump()
  if sx.sds_timer then
    pcall(function() renoise.tool():remove_timer(sx.sds_timer) end)
    sx.sds_timer = nil
  end
end

local function get_selected_sample_for_sds()
  local song = renoise.song()
  if not song or not song.selected_sample then
    renoise.app():show_status("Sysexizer SDS: no selected sample")
    return nil
  end
  local sample = song.selected_sample
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    renoise.app():show_status("Sysexizer SDS: selected sample has no audio")
    return nil
  end
  if buffer.number_of_frames < 1 then
    renoise.app():show_status("Sysexizer SDS: selected sample is empty")
    return nil
  end
  if buffer.number_of_frames > 0x1FFFFF then
    renoise.app():show_status("Sysexizer SDS: sample is too long for SDS (max 2097151 frames)")
    return nil
  end
  return sample, buffer
end

local function sds_device_id()
  return math.max(0, math.min(127, (sx.channel or 1) - 1))
end

function PakettiSysexizerEncodeSds16(sample_value)
  sample_value = math.max(-1, math.min(1, sample_value or 0))
  local word = math.floor((sample_value + 1) * 32767.5)
  word = math.max(0, math.min(65535, word))
  return {
    math.floor(word / 512) % 128,
    math.floor(word / 4) % 128,
    (word % 4) * 32
  }
end

function PakettiSysexizerBuildSdsHeader(sample_number, sample_rate, frames, loop_start, loop_end, loop_type, device_id)
  local bytes = { 0xF0, 0x7E, clamp_byte(device_id or sds_device_id()), 0x01 }
  append_u14_7bit(bytes, sample_number or sx.sds_sample_number)
  bytes[#bytes + 1] = 16
  append_u21_7bit(bytes, math.floor((1000000000 / math.max(1, sample_rate or 44100)) + 0.5))
  append_u21_7bit(bytes, frames or 1)
  append_u21_7bit(bytes, loop_start or 0)
  append_u21_7bit(bytes, loop_end or 0)
  bytes[#bytes + 1] = clamp_byte(loop_type or 0)
  bytes[#bytes + 1] = 0xF7
  return bytes
end

local function sds_loop_fields(sample, frames)
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and sample.loop_end > sample.loop_start then
    local loop_type = (sample.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG) and 1 or 0
    return sample.loop_start - 1, sample.loop_end - 1, loop_type
  end
  return 0, 0, 0
end

local function sds_frame_value(buffer, frame)
  if frame > buffer.number_of_frames then return -1 end
  if buffer.number_of_channels == 1 then
    return buffer:sample_data(1, frame)
  end
  local sum = 0
  for channel = 1, buffer.number_of_channels do
    sum = sum + buffer:sample_data(channel, frame)
  end
  return sum / buffer.number_of_channels
end

function PakettiSysexizerBuildSdsPacket(buffer, packet_index, device_id)
  local data = {}
  local first_frame = packet_index * 40 + 1
  for frame = first_frame, first_frame + 39 do
    local encoded = PakettiSysexizerEncodeSds16(sds_frame_value(buffer, frame))
    data[#data + 1] = encoded[1]
    data[#data + 1] = encoded[2]
    data[#data + 1] = encoded[3]
  end

  local packet_number = packet_index % 128
  local msg = { 0xF0, 0x7E, clamp_byte(device_id or sds_device_id()), 0x02, packet_number }
  local checksum = 0x7E
  for i = 3, #msg do checksum = bit.bxor(checksum, msg[i]) end
  for _, b in ipairs(data) do
    msg[#msg + 1] = b
    checksum = bit.bxor(checksum, b)
  end
  msg[#msg + 1] = checksum % 128
  msg[#msg + 1] = 0xF7
  return msg
end

function PakettiSysexizerDumpSelectedSampleSDS()
  local sample, buffer = get_selected_sample_for_sds()
  if not sample then return false end
  if not sx.out_dev then
    renoise.app():show_status("Sysexizer SDS: no MIDI output port selected")
    return false
  end

  stop_sds_dump()
  stop_dump()

  local frames = buffer.number_of_frames
  local loop_start, loop_end, loop_type = sds_loop_fields(sample, frames)
  local device_id = sds_device_id()
  local header = PakettiSysexizerBuildSdsHeader(
    sx.sds_sample_number, buffer.sample_rate, frames, loop_start, loop_end, loop_type, device_id)
  local total_packets = math.ceil(frames / 40)
  sx.sds_packet = -1
  sx.sds_packets = total_packets

  local function wire_time_ms(msg)
    return math.ceil(#msg * 0.32)
  end

  local tick
  tick = function()
    local ok, err = pcall(function()
      pcall(function() renoise.tool():remove_timer(tick) end)
      if sx.sds_packet == -1 then
        send_bytes(header)
        sx.sds_packet = 0
        renoise.app():show_status(string.format("Sysexizer SDS: sent header for %s", sample.name ~= "" and sample.name or "selected sample"))
        renoise.tool():add_timer(tick, math.max(1, sx.delay_ms + wire_time_ms(header)))
        return
      end
      if sx.sds_packet >= total_packets then
        sx.sds_timer = nil
        renoise.app():show_status(string.format("Sysexizer SDS: dump complete -- %d packets", total_packets))
        sx_log("SDS dump complete: %d frames, %d packets, sample #%d", frames, total_packets, sx.sds_sample_number)
        return
      end
      local msg = PakettiSysexizerBuildSdsPacket(buffer, sx.sds_packet, device_id)
      send_bytes(msg)
      sx.sds_packet = sx.sds_packet + 1
      renoise.app():show_status(string.format("Sysexizer SDS: packet %d/%d", sx.sds_packet, total_packets))
      renoise.tool():add_timer(tick, math.max(1, sx.delay_ms + wire_time_ms(msg)))
    end)
    if not ok then
      stop_sds_dump()
      sx_log("SDS dump aborted: %s", tostring(err))
      renoise.app():show_status("Sysexizer SDS: dump aborted -- see console")
    end
  end

  sx.sds_timer = tick
  renoise.tool():add_timer(tick, 1)
  sx_log("SDS dumping %d frames to '%s' as %d packets", frames, tostring(sx.out_name), total_packets)
  return true
end

--------------------------------------------------------------------------------
-- dialog
--------------------------------------------------------------------------------

local function build_slot_row(slot)
  local ctrl = sx.controls[slot]
  return vb:row{
    vb:text{
      id = "sysexizer_name_" .. slot,
      text = string.format("%02d %s", slot, ctrl and ctrl.name or "-"),
      width = 150
    },
    vb:slider{
      id = sx.slider_id[slot],
      width = 120,
      min = ctrl and ctrl.min or 0,
      max = ctrl and ctrl.max or 127,
      value = sx.values[slot],
      active = (ctrl ~= nil),
      notifier = function(value)
        if sx.building then return end
        PakettiSysexizerSetSlot(slot, value, true)
      end
    },
    vb:text{
      id = sx.value_id[slot],
      text = ctrl and tostring(sx.values[slot]) or "-",
      width = 34,
      align = "right"
    }
  }
end

function PakettiSysexizerDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  vb = renoise.ViewBuilder()
  sx.building = true

  local out_names = renoise.Midi.available_output_devices()
  local port_items = { "<no port>" }
  for _, n in ipairs(out_names) do port_items[#port_items + 1] = n end
  local port_index = 1
  for i, n in ipairs(port_items) do
    if n == sx.out_name then port_index = i break end
  end

  local defs = scan_sysexizer_files()
  local def_items = { "<none>" }
  for _, d in ipairs(defs) do def_items[#def_items + 1] = d.display_name end
  local def_index = 1
  for i, d in ipairs(defs) do
    if d.full_path == sx.definition then def_index = i + 1 break end
  end

  local columns = vb:row{ spacing = 12 }
  for c = 0, 3 do
    local col = vb:column{ spacing = 2 }
    for r = 1, 8 do
      col:add_child(build_slot_row(c * 8 + r))
    end
    columns:add_child(col)
  end

  local content = vb:column{
    margin = 8,
    spacing = 6,
    vb:row{
      spacing = 6,
      vb:text{ text = "Definition", width = 70, font = "bold" },
      vb:popup{
        id = "sysexizer_def_popup",
        width = 220,
        items = def_items,
        value = def_index,
        notifier = function(index)
          -- ViewBuilder fires notifiers while the view is being built; without this
          -- guard opening the dialog would re-apply whatever the popup happens to
          -- show and silently discard the definition already loaded.
          if sx.building then return end
          if index > 1 and defs[index - 1] then
            PakettiSysexizerApplyDefinition(defs[index - 1].full_path)
          end
        end
      },
      vb:button{
        text = "Load File...",
        width = 90,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_read({ "*.txt" }, "Select Sysexizer definition")
          if path and path ~= "" then PakettiSysexizerApplyDefinition(path) end
        end
      },
      vb:text{ id = "sysexizer_device", text = sx.device_name, width = 220 }
    },
    vb:row{
      spacing = 6,
      vb:text{ text = "MIDI Out", width = 70, font = "bold" },
      vb:popup{
        id = "sysexizer_port_popup",
        width = 220,
        items = port_items,
        value = port_index,
        notifier = function(index)
          if sx.building then return end
          if index == 1 then close_output() else open_output(port_items[index]) end
        end
      },
      vb:text{ text = "Channel", width = 56 },
      vb:valuebox{
        min = 1, max = 16, value = sx.channel, width = 60,
        notifier = function(value) if not sx.building then sx.channel = value end end
      },
      vb:text{ text = "Msg gap ms", width = 76 },
      vb:valuebox{
        min = 0, max = 1000, value = sx.delay_ms, width = 60,
        notifier = function(value) if not sx.building then sx.delay_ms = value end end
      },
      vb:button{
        text = "Send All",
        width = 80,
        notifier = function() PakettiSysexizerSendAll() end
      }
    },
    columns,
    vb:row{
      spacing = 6,
      vb:text{ text = ".syx Dump", width = 70, font = "bold" },
      vb:button{
        text = "Load .syx...",
        width = 90,
        notifier = function()
          local path = renoise.app():prompt_for_filename_to_read({ "*.syx", "*.mid" }, "Select SysEx file")
          if path and path ~= "" then PakettiSysexizerLoadSyxFile(path) end
        end
      },
      vb:button{
        text = "Dump to Port",
        width = 100,
        notifier = function() PakettiSysexizerDumpSyx() end
      },
      vb:button{
        text = "Stop",
        width = 50,
        notifier = function()
          stop_dump()
          stop_sds_dump()
          renoise.app():show_status("Sysexizer: dump stopped")
        end
      },
      vb:text{
        id = "sysexizer_syxinfo",
        text = sx.syx_path and (sx.syx_path:match("[^" .. separator .. "]+$") or sx.syx_path) or "(no file loaded)",
        width = 320
      }
    },
    vb:row{
      spacing = 6,
      vb:text{ text = "SDS Sample", width = 70, font = "bold" },
      vb:text{ text = "#", width = 12 },
      vb:valuebox{
        min = 0, max = 16383, value = sx.sds_sample_number, width = 70,
        notifier = function(value) if not sx.building then sx.sds_sample_number = value end end
      },
      vb:button{
        text = "Send Selected Sample",
        width = 150,
        notifier = function() PakettiSysexizerDumpSelectedSampleSDS() end
      },
      vb:button{
        text = "Stop",
        width = 50,
        notifier = function()
          stop_sds_dump()
          renoise.app():show_status("Sysexizer SDS: dump stopped")
        end
      },
      vb:text{
        text = "16-bit mono SDS, open-loop",
        width = 200
      }
    }
  }

  local keyhandler = function(dlg, key)
    if key.name == "esc" then
      dlg:close()
      dialog = nil
      return nil
    end
    return key
  end

  dialog = renoise.app():show_custom_dialog("Paketti Sysexizer", content, keyhandler)
  sx.building = false
  if port_index > 1 then open_output(port_items[port_index]) end
end

--------------------------------------------------------------------------------
-- headless helpers (used for verification without opening the dialog)
--------------------------------------------------------------------------------

function PakettiSysexizerSelectPort(name)
  return open_output(name)
end

function PakettiSysexizerBuildSlotBytes(slot, value, channel)
  local ctrl = sx.controls[slot]
  if not ctrl then return nil end
  return build_message(ctrl.tokens, value, channel or sx.channel)
end

function PakettiSysexizerState()
  return sx
end

function PakettiSysexizerHexString(bytes)
  return bytes_to_hex(bytes)
end

local function read_u14_7bit(bytes, pos)
  return (bytes[pos] or 0) + (bytes[pos + 1] or 0) * 128
end

local function read_u21_7bit(bytes, pos)
  return (bytes[pos] or 0) + (bytes[pos + 1] or 0) * 128 + (bytes[pos + 2] or 0) * 16384
end

--------------------------------------------------------------------------------
-- SysEx Monitor: capture what a synth sends, so its format can be reverse
-- engineered when the manufacturer never published one.
--
-- The TX16W is the motivating case: its manual says it transmits SysEx for front
-- panel switches and parameter changes, but points programmers at Yamaha for the
-- byte format. Wiggle a parameter, capture, diff two captures, and the moving byte
-- is the parameter address.
--
-- Renoise delivers incoming SysEx in 256-BYTE CHUNKS, not whole messages, so this
-- accumulates bytes and cuts on F0..F7 itself. A dump straight from the callback
-- would be shredded into 256-byte pieces.
--------------------------------------------------------------------------------

local monitor_dialog = nil
local monitor_vb = nil

local function monitor_refresh_view()
  if not (monitor_dialog and monitor_dialog.visible and monitor_vb) then return end
  local lines = {}
  local n = #sx.mon_msgs
  local first = math.max(1, n - 30)
  for i = first, n do
    local m = sx.mon_msgs[i]
    lines[#lines + 1] = string.format("[%03d] %3d bytes  %s", i, #m, bytes_to_hex(m))
  end
  if n == 0 then lines[1] = "(nothing captured yet -- move a control on the synth)" end
  if monitor_vb.views["sysexizer_mon_text"] then
    monitor_vb.views["sysexizer_mon_text"].text = table.concat(lines, "\n")
  end
  if monitor_vb.views["sysexizer_mon_count"] then
    monitor_vb.views["sysexizer_mon_count"].text = string.format("%d captured", n)
  end
end

function PakettiSysexizerMonitorStop()
  if sx.mon_dev then
    pcall(function() sx.mon_dev:close() end)
    sx.mon_dev = nil
    sx.mon_name = nil
  end
  sx.mon_partial = nil
end

function PakettiSysexizerMonitorStart(port_name)
  PakettiSysexizerMonitorStop()
  if not port_name or port_name == "" then return false end
  -- Nothing in this callback may throw: an error escaping it makes Renoise disable
  -- every notifier this tool owns until Renoise is restarted.
  local function on_sysex(chunk)
    pcall(function()
      for _, b in ipairs(chunk) do
        if b == 0xF0 then
          sx.mon_partial = { b }
        elseif sx.mon_partial then
          sx.mon_partial[#sx.mon_partial + 1] = b
          if b == 0xF7 then
            sx.mon_msgs[#sx.mon_msgs + 1] = sx.mon_partial
            sx.mon_partial = nil
            monitor_refresh_view()
          end
        end
      end
    end)
  end
  local ok, dev = pcall(function()
    return renoise.Midi.create_input_device(port_name, function() end, on_sysex)
  end)
  if not ok or not dev then
    sx_log("could not open MIDI input '%s'", tostring(port_name))
    return false
  end
  sx.mon_dev = dev
  sx.mon_name = port_name
  sx_log("monitoring SysEx on '%s'", port_name)
  return true
end

function PakettiSysexizerMonitorClear()
  sx.mon_msgs = {}
  sx.mon_partial = nil
  monitor_refresh_view()
end

-- Compare the last two captures byte by byte. Same length + one differing byte is
-- the giveaway: that offset is the parameter value, and the bytes around it are its
-- address.
function PakettiSysexizerMonitorDiff()
  local n = #sx.mon_msgs
  if n < 2 then
    renoise.app():show_status("Sysexizer Monitor: need at least two captured messages")
    return nil
  end
  local a, b = sx.mon_msgs[n - 1], sx.mon_msgs[n]
  local out = {}
  if #a ~= #b then
    out[#out + 1] = string.format("lengths differ: %d vs %d -- not the same message type", #a, #b)
  else
    local diffs = {}
    for i = 1, #a do
      if a[i] ~= b[i] then
        diffs[#diffs + 1] = string.format("offset %d: %02X -> %02X", i, a[i], b[i])
      end
    end
    if #diffs == 0 then
      out[#out + 1] = "identical -- the control did not change anything"
    else
      out[#out + 1] = string.format("%d byte(s) changed between the last two messages:", #diffs)
      for _, d in ipairs(diffs) do out[#out + 1] = "  " .. d end
      if #diffs == 1 then
        local off = tonumber(diffs[1]:match("offset (%d+)"))
        local tmpl = {}
        for i = 1, #a do tmpl[#tmpl + 1] = (i == off) and "VV" or string.format("%02X", a[i]) end
        out[#out + 1] = ""
        out[#out + 1] = "definition line for this control:"
        out[#out + 1] = "  My Parameter : " .. table.concat(tmpl, " ") .. " : 0 127 0"
      end
    end
  end
  local text = table.concat(out, "\n")
  print("-- Sysexizer Monitor diff:\n" .. text)
  renoise.app():show_message(text)
  return text
end

local function sds_packet_checksum(msg)
  local checksum = msg[2] or 0
  for i = 3, 125 do checksum = bit.bxor(checksum, msg[i] or 0) end
  return checksum % 128
end

local function is_sds_header(msg)
  return #msg == 21 and msg[1] == 0xF0 and msg[2] == 0x7E and msg[4] == 0x01 and msg[21] == 0xF7
end

local function is_sds_data_packet(msg)
  return #msg == 127 and msg[1] == 0xF0 and msg[2] == 0x7E and msg[4] == 0x02 and msg[127] == 0xF7
end

function PakettiSysexizerAnalyzeSDSMessages(messages)
  local dumps = {}
  local current = nil

  for index, msg in ipairs(messages or {}) do
    if is_sds_header(msg) then
      current = {
        header_index = index,
        device_id = msg[3],
        sample_number = read_u14_7bit(msg, 5),
        sample_format = msg[7],
        sample_period_ns = read_u21_7bit(msg, 8),
        sample_length = read_u21_7bit(msg, 11),
        loop_start = read_u21_7bit(msg, 14),
        loop_end = read_u21_7bit(msg, 17),
        loop_type = msg[20],
        packets = 0,
        bad_packets = {},
        first_packet_index = nil,
        last_packet_index = nil
      }
      dumps[#dumps + 1] = current
    elseif current and msg[1] == 0xF0 and msg[2] == 0x7E and msg[4] == 0x02 then
      current.packets = current.packets + 1
      current.first_packet_index = current.first_packet_index or index
      current.last_packet_index = index
      local expected_packet = (current.packets - 1) % 128
      if not is_sds_data_packet(msg) then
        current.bad_packets[#current.bad_packets + 1] =
          string.format("capture %d: bad data packet length/envelope (%d bytes)", index, #msg)
      else
        local actual_checksum = msg[126]
        local expected_checksum = sds_packet_checksum(msg)
        if msg[3] ~= current.device_id then
          current.bad_packets[#current.bad_packets + 1] =
            string.format("capture %d: device id changed %02X -> %02X", index, current.device_id, msg[3])
        end
        if msg[5] ~= expected_packet then
          current.bad_packets[#current.bad_packets + 1] =
            string.format("capture %d: packet number %02X, expected %02X", index, msg[5], expected_packet)
        end
        if actual_checksum ~= expected_checksum then
          current.bad_packets[#current.bad_packets + 1] =
            string.format("capture %d: checksum %02X, expected %02X", index, actual_checksum, expected_checksum)
        end
      end
    end
  end

  return dumps
end

function PakettiSysexizerMonitorAnalyzeSDS()
  if #sx.mon_msgs == 0 then
    renoise.app():show_status("Sysexizer Monitor: nothing captured")
    return nil
  end

  local dumps = PakettiSysexizerAnalyzeSDSMessages(sx.mon_msgs)
  local out = {}
  if #dumps == 0 then
    out[#out + 1] = "No MIDI Sample Dump Standard dumps found."
    out[#out + 1] = "Expected header: F0 7E <device> 01 ... F7"
    out[#out + 1] = "Expected data:   F0 7E <device> 02 <packet> <120 data bytes> <checksum> F7"
  else
    out[#out + 1] = string.format("Found %d SDS dump(s).", #dumps)
    for i, dump in ipairs(dumps) do
      local bytes_per_sample = math.max(1, math.ceil((dump.sample_format or 16) / 7))
      local expected_packets = math.ceil((dump.sample_length * bytes_per_sample) / 120)
      local rate = dump.sample_period_ns > 0 and math.floor((1000000000 / dump.sample_period_ns) + 0.5) or 0
      local status = "OK"
      if #dump.bad_packets > 0 or dump.packets ~= expected_packets then status = "PROBLEM" end
      out[#out + 1] = string.format(
        "Dump %d: %s sample #%d, device %d, %d-bit, %d Hz, %d samples, loop %d-%d type %d",
        i, status, dump.sample_number, dump.device_id, dump.sample_format, rate,
        dump.sample_length, dump.loop_start, dump.loop_end, dump.loop_type)
      out[#out + 1] = string.format(
        "  captured packets: %d, expected: %d, captures: header %d, packets %s-%s",
        dump.packets, expected_packets, dump.header_index,
        tostring(dump.first_packet_index or "-"), tostring(dump.last_packet_index or "-"))
      if dump.packets ~= expected_packets then
        out[#out + 1] = "  packet count does not match the SDS header sample length"
      end
      for _, err in ipairs(dump.bad_packets) do out[#out + 1] = "  " .. err end
    end
  end

  local text = table.concat(out, "\n")
  print("-- Sysexizer SDS analysis:\n" .. text)
  renoise.app():show_message(text)
  return text
end

function PakettiSysexizerMonitorSave()
  if #sx.mon_msgs == 0 then
    renoise.app():show_status("Sysexizer Monitor: nothing captured")
    return false
  end
  local path = renoise.app():prompt_for_filename_to_write("syx", "Save captured SysEx")
  if not path or path == "" then return false end
  local f = io.open(path, "wb")
  if not f then
    renoise.app():show_error("Sysexizer: cannot write " .. path)
    return false
  end
  local total = 0
  for _, m in ipairs(sx.mon_msgs) do
    local chars = {}
    for _, b in ipairs(m) do chars[#chars + 1] = string.char(b) end
    f:write(table.concat(chars))
    total = total + #m
  end
  f:close()
  sx_log("saved %d messages (%d bytes) to %s", #sx.mon_msgs, total, path)
  renoise.app():show_status(string.format("Sysexizer: saved %d messages to %s", #sx.mon_msgs, path))
  return true
end

function PakettiSysexizerMonitorDialog()
  if monitor_dialog and monitor_dialog.visible then
    monitor_dialog:close()
    monitor_dialog = nil
    return
  end
  monitor_vb = renoise.ViewBuilder()
  local building = true

  local in_names = renoise.Midi.available_input_devices()
  local items = { "<no port>" }
  for _, n in ipairs(in_names) do items[#items + 1] = n end
  local index = 1
  for i, n in ipairs(items) do
    if n == sx.mon_name then index = i break end
  end

  local content = monitor_vb:column{
    margin = 8,
    spacing = 6,
    monitor_vb:row{
      spacing = 6,
      monitor_vb:text{ text = "MIDI In", width = 60, font = "bold" },
      monitor_vb:popup{
        width = 240,
        items = items,
        value = index,
        notifier = function(i)
          if building then return end
          if i == 1 then PakettiSysexizerMonitorStop()
          else PakettiSysexizerMonitorStart(items[i]) end
        end
      },
      monitor_vb:text{ id = "sysexizer_mon_count", text = string.format("%d captured", #sx.mon_msgs), width = 100 },
      monitor_vb:button{ text = "Clear", width = 60, notifier = function() PakettiSysexizerMonitorClear() end },
      monitor_vb:button{ text = "Diff Last Two", width = 100, notifier = function() PakettiSysexizerMonitorDiff() end },
      monitor_vb:button{ text = "Analyze SDS", width = 90, notifier = function() PakettiSysexizerMonitorAnalyzeSDS() end },
      monitor_vb:button{ text = "Save .syx...", width = 90, notifier = function() PakettiSysexizerMonitorSave() end }
    },
    monitor_vb:text{
      text = "Move one control and diff it, or send SDS from ReCycle and press Analyze SDS.",
      width = 700
    },
    monitor_vb:multiline_text{
      id = "sysexizer_mon_text",
      width = 700,
      height = 300,
      font = "mono",
      text = "(nothing captured yet -- move a control on the synth)"
    }
  }

  local keyhandler = function(dlg, key)
    if key.name == "esc" then dlg:close() monitor_dialog = nil return nil end
    return key
  end

  monitor_dialog = renoise.app():show_custom_dialog("Paketti Sysexizer - SysEx Monitor", content, keyhandler)
  building = false
  if index > 1 then PakettiSysexizerMonitorStart(items[index]) end
  monitor_refresh_view()
end

--------------------------------------------------------------------------------
-- registrations (last -- house rule 18)
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:MIDI:Sysexizer Control Surface...", invoke=function() PakettiSysexizerDialog() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:MIDI:Sysexizer Dump .syx File...", invoke=function() PakettiSysexizerBrowseAndDump() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:MIDI:Sysexizer Send Selected Sample as SDS", invoke=function() PakettiSysexizerDumpSelectedSampleSDS() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:MIDI:Sysexizer SysEx Monitor...", invoke=function() PakettiSysexizerMonitorDialog() end}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sysexizer Control Surface",
  invoke = function() PakettiSysexizerDialog() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Sysexizer Send All Controls",
  invoke = function() PakettiSysexizerSendAll() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Sysexizer Dump Syx File",
  invoke = function() PakettiSysexizerBrowseAndDump() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Sysexizer Send Selected Sample as SDS",
  invoke = function() PakettiSysexizerDumpSelectedSampleSDS() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Sysexizer SysEx Monitor",
  invoke = function() PakettiSysexizerMonitorDialog() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Sysexizer Send All Controls",
  invoke = function(message) if message:is_trigger() then PakettiSysexizerSendAll() end end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Sysexizer Dump Syx File",
  invoke = function(message) if message:is_trigger() then PakettiSysexizerDumpSyx() end end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Sysexizer Send Selected Sample as SDS",
  invoke = function(message) if message:is_trigger() then PakettiSysexizerDumpSelectedSampleSDS() end end
}

for slot = 1, SLOT_COUNT do
  local this_slot = slot
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Sysexizer Control %02d [Knob]", this_slot),
    invoke = function(message) PakettiSysexizerMidiSlot(this_slot, message) end
  }
end
