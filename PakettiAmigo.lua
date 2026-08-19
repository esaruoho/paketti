--[[============================================================================
PakettiAmigo.lua

RENOISE <-> AMIGO, single sample, both ways.

  * Renoise -> Amigo : takes the selected sample, writes it to a .wav on disk and
                       points the Amigo instance at it.
  * Amigo -> Renoise : takes whatever sample the Amigo instance is holding and
                       loads it into a brand new Renoise instrument.

Works with both the AU and the VST3 build of PotenzaDSP Amigo. No plutil, no
shelling out, no hand-rolled byte surgery - the plugin state is parsed and
rewritten properly.

--------------------------------------------------------------------------------
FORMAT NOTES (verified live against Amigo AU v1.1.6 and VST3 v1.0.2, 2026-08-19)
--------------------------------------------------------------------------------
Renoise hands us the plugin state as a <FilterDevicePreset> XML document whose
<ParameterChunk> is base64. What is inside that base64 depends on the plugin
format:

  VST3 : "VST3" | uint32 version | 32 ASCII class-id bytes | uint64 body size
         | body. The body starts with the JUCE ValueTree, and ends with a
         "JUCEPrivateDataList" trailer holding (4-char id, uint64 offset,
         uint64 size) entries. Growing the ValueTree by N bytes means the
         header size += N, the "Comp" entry size += N, and every later entry
         offset += N.

  AU   : an Apple binary plist. The JUCE ValueTree lives in the
         "jucePluginState" data entry; everything else in the plist is AU
         housekeeping and is preserved untouched.

The JUCE ValueTree itself (JUCE ValueTree::writeToStream) is:
    type string (NUL terminated)
    compressed int : number of properties
      per property: name string (NUL terminated) + var
    compressed int : number of children
      per child: the same structure, recursively

  compressed int = 1 length byte, then that many little-endian value bytes.
  var            = compressed int of the payload size, then a marker byte,
                   then the payload. Markers: 1=int32 2=true 3=false 4=double
                   5=string 6=int64 7=array 8=binary.

Amigo's root node is "PARAMS" with one PARAM child per parameter (id + value)
and these root properties:

    pathname       string  absolute path of the wav Amigo should play
    EMBEDDED_FILE  string  base64 of the whole wav file (only written when the
                           "embedsample" parameter is 1, AU v1.1.6 and up)

pathname wins: if it is set and the file is missing, Amigo puts up its
"FILE NOT FOUND!" panel and ignores EMBEDDED_FILE. So export always writes a
real file to disk and points pathname at it, and import prefers pathname when
the file is still there, falling back to EMBEDDED_FILE when it is not.
============================================================================]]--

_G.bit32 = nil -- make base64.lua take its Lua 5.1 path
local ok64, base64 = pcall(require, "base64")
if not ok64 then
  print("PakettiAmigo: could not load base64 module: " .. tostring(base64))
  return
end

local AMIGO_AU_PATH = "Audio/Generators/AU/aumu:Amgo:PTNZ"
local AMIGO_VST3_PATH = "Audio/Generators/VST3/ABCDEF019182FAEB50544E5A416D676F"

--------------------------------------------------------------------------------
-- little binary helpers
--------------------------------------------------------------------------------

local function pakettiAmigoReadLE(s, pos, count)
  local v = 0
  for i = 0, count - 1 do
    local b = s:byte(pos + i)
    if not b then return 0 end
    v = v + b * (256 ^ i)
  end
  return v
end

local function pakettiAmigoWriteLE(v, count)
  local out = {}
  for _ = 1, count do
    out[#out + 1] = string.char(v % 256)
    v = math.floor(v / 256)
  end
  return table.concat(out)
end

local function pakettiAmigoReadBE(s, pos, count)
  local v = 0
  for i = 0, count - 1 do
    local b = s:byte(pos + i)
    if not b then return 0 end
    v = v * 256 + b
  end
  return v
end

local function pakettiAmigoWriteBE(v, count)
  local out = {}
  for i = count, 1, -1 do
    out[i] = string.char(v % 256)
    v = math.floor(v / 256)
  end
  return table.concat(out)
end

--------------------------------------------------------------------------------
-- JUCE ValueTree
--
-- A node is { type = string, props = { {name, varbytes}, ... }, children = {...} }.
-- Property values are kept as raw var bytes, so anything we do not understand
-- survives a read/write round trip byte for byte.
--------------------------------------------------------------------------------

local function pakettiAmigoReadCompressedInt(s, pos)
  local n = s:byte(pos)
  if not n then return 0, pos + 1 end
  n = n % 128
  return pakettiAmigoReadLE(s, pos + 1, n), pos + 1 + n
end

local function pakettiAmigoWriteCompressedInt(v)
  local out = {}
  while v > 0 do
    out[#out + 1] = string.char(v % 256)
    v = math.floor(v / 256)
  end
  return string.char(#out) .. table.concat(out)
end

local function pakettiAmigoReadCString(s, pos)
  local stop = s:find("\0", pos, true)
  if not stop then return "", #s + 1 end
  return s:sub(pos, stop - 1), stop + 1
end

-- returns the raw var bytes (size prefix included) and the position after them
local function pakettiAmigoReadVar(s, pos)
  local size, after = pakettiAmigoReadCompressedInt(s, pos)
  return s:sub(pos, after + size - 1), after + size
end

local function pakettiAmigoVarString(str)
  local payload = "\5" .. str .. "\0"
  return pakettiAmigoWriteCompressedInt(#payload) .. payload
end

-- decodes a var that holds a string, otherwise nil
local function pakettiAmigoVarToString(varbytes)
  local size, after = pakettiAmigoReadCompressedInt(varbytes, 1)
  if size < 1 then return nil end
  if varbytes:byte(after) ~= 5 then return nil end
  return varbytes:sub(after + 1, after + size - 2) -- drop marker and trailing NUL
end

-- IEEE 754 binary64, little-endian. Amigo keeps every parameter as a double,
-- and slice positions need real fractions, not just 0 and 1.
local function pakettiAmigoDoubleBytes(value)
  if value == 0 then return string.rep("\0", 8) end
  local sign = 0
  if value < 0 then sign = 1 value = -value end
  local mantissa, exponent = math.frexp(value) -- value = mantissa * 2^exponent, 0.5 <= mantissa < 1
  local biased = exponent - 1 + 1023
  if biased < 1 then return string.rep("\0", 8) end
  if biased > 2046 then biased = 2046 mantissa = 0.99999999999999989 end
  local fraction = math.floor((mantissa * 2 - 1) * 4503599627370496 + 0.5) -- 2^52
  if fraction > 4503599627370495 then fraction = 4503599627370495 end
  local out = {}
  for i = 1, 6 do
    out[i] = string.char(fraction % 256)
    fraction = math.floor(fraction / 256)
  end
  out[7] = string.char(fraction % 16 + (biased % 16) * 16)
  out[8] = string.char(math.floor(biased / 16) + sign * 128)
  return table.concat(out)
end

-- and back the other way, so slices made inside Amigo can return to Renoise
local function pakettiAmigoBytesToDouble(bytes)
  if #bytes < 8 then return 0 end
  local b = {bytes:byte(1, 8)}
  local sign = (b[8] >= 128) and -1 or 1
  local exponent = (b[8] % 128) * 16 + math.floor(b[7] / 16)
  local fraction = b[7] % 16
  for i = 6, 1, -1 do fraction = fraction * 256 + b[i] end
  if exponent == 0 then
    if fraction == 0 then return 0 end
    return sign * math.ldexp(fraction, -1074)
  end
  if exponent == 2047 then return sign * math.huge end
  return sign * math.ldexp(1 + fraction / 4503599627370496, exponent - 1023)
end

-- decodes a var that holds a double, otherwise nil
local function pakettiAmigoVarToDouble(varbytes)
  local size, after = pakettiAmigoReadCompressedInt(varbytes, 1)
  if size < 9 then return nil end
  if varbytes:byte(after) ~= 4 then return nil end
  return pakettiAmigoBytesToDouble(varbytes:sub(after + 1, after + 8))
end

local function pakettiAmigoVarDouble(value)
  local payload = "\4" .. pakettiAmigoDoubleBytes(value)
  return pakettiAmigoWriteCompressedInt(#payload) .. payload
end

local function pakettiAmigoReadTree(s, pos)
  local node = {props = {}, children = {}}
  node.type, pos = pakettiAmigoReadCString(s, pos)
  local count
  count, pos = pakettiAmigoReadCompressedInt(s, pos)
  for _ = 1, count do
    local name, var
    name, pos = pakettiAmigoReadCString(s, pos)
    var, pos = pakettiAmigoReadVar(s, pos)
    node.props[#node.props + 1] = {name, var}
  end
  count, pos = pakettiAmigoReadCompressedInt(s, pos)
  for _ = 1, count do
    local child
    child, pos = pakettiAmigoReadTree(s, pos)
    node.children[#node.children + 1] = child
  end
  return node, pos
end

local function pakettiAmigoWriteTree(node)
  local out = {node.type, "\0", pakettiAmigoWriteCompressedInt(#node.props)}
  for _, p in ipairs(node.props) do
    out[#out + 1] = p[1]
    out[#out + 1] = "\0"
    out[#out + 1] = p[2]
  end
  out[#out + 1] = pakettiAmigoWriteCompressedInt(#node.children)
  for _, c in ipairs(node.children) do
    out[#out + 1] = pakettiAmigoWriteTree(c)
  end
  return table.concat(out)
end

local function pakettiAmigoGetProp(node, name)
  for _, p in ipairs(node.props) do
    if p[1] == name then return p[2] end
  end
  return nil
end

local function pakettiAmigoSetProp(node, name, varbytes)
  for _, p in ipairs(node.props) do
    if p[1] == name then p[2] = varbytes return end
  end
  node.props[#node.props + 1] = {name, varbytes}
end

local function pakettiAmigoRemoveProp(node, name)
  for i = #node.props, 1, -1 do
    if node.props[i][1] == name then table.remove(node.props, i) end
  end
end

-- sets a PARAM child's value (Amigo stores every parameter as a PARAM node
-- with an "id" string and a "value" double)
local function pakettiAmigoGetParam(root, id)
  for _, child in ipairs(root.children) do
    local child_id = pakettiAmigoVarToString(pakettiAmigoGetProp(child, "id") or "")
    if child_id == id then
      return pakettiAmigoVarToDouble(pakettiAmigoGetProp(child, "value") or "")
    end
  end
  return nil
end

local function pakettiAmigoSetParam(root, id, value)
  for _, child in ipairs(root.children) do
    local child_id = pakettiAmigoVarToString(pakettiAmigoGetProp(child, "id") or "")
    if child_id == id then
      pakettiAmigoSetProp(child, "value", pakettiAmigoVarDouble(value))
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Apple binary plist (only what an AU state needs: dict / ascii / int / data)
--------------------------------------------------------------------------------

local function pakettiAmigoPlistRead(data)
  if data:sub(1, 6) ~= "bplist" then return nil, "not a binary plist" end
  local trailer = #data - 32
  local offset_size = data:byte(trailer + 7)
  local ref_size = data:byte(trailer + 8)
  local num_objects = pakettiAmigoReadBE(data, trailer + 9, 8)
  local top_object = pakettiAmigoReadBE(data, trailer + 17, 8)
  local table_offset = pakettiAmigoReadBE(data, trailer + 25, 8)

  local offsets = {}
  for i = 0, num_objects - 1 do
    offsets[i] = pakettiAmigoReadBE(data, table_offset + 1 + i * offset_size, offset_size)
  end

  local read_object

  local function read_count(pos, low)
    if low ~= 15 then return low, pos + 1 end
    local marker = data:byte(pos + 1)
    local nbytes = 2 ^ (marker % 16)
    return pakettiAmigoReadBE(data, pos + 2, nbytes), pos + 2 + nbytes
  end

  read_object = function(index)
    local pos = offsets[index] + 1
    local marker = data:byte(pos)
    local high = math.floor(marker / 16)
    local low = marker % 16
    if high == 1 then
      local nbytes = 2 ^ low
      return {kind = "int", value = pakettiAmigoReadBE(data, pos + 1, nbytes), bytes = nbytes}
    elseif high == 4 then
      local count, start = read_count(pos, low)
      return {kind = "data", value = data:sub(start, start + count - 1)}
    elseif high == 5 then
      local count, start = read_count(pos, low)
      return {kind = "string", value = data:sub(start, start + count - 1)}
    elseif high == 6 then
      local count, start = read_count(pos, low)
      return {kind = "ustring", value = data:sub(start, start + count * 2 - 1)}
    elseif high == 13 then
      local count, start = read_count(pos, low)
      local node = {kind = "dict", keys = {}, values = {}}
      for i = 0, count - 1 do
        local kref = pakettiAmigoReadBE(data, start + i * ref_size, ref_size)
        node.keys[i + 1] = read_object(kref)
      end
      local vbase = start + count * ref_size
      for i = 0, count - 1 do
        local vref = pakettiAmigoReadBE(data, vbase + i * ref_size, ref_size)
        node.values[i + 1] = read_object(vref)
      end
      return node
    elseif high == 0 then
      if low == 8 then return {kind = "bool", value = false} end
      if low == 9 then return {kind = "bool", value = true} end
      return {kind = "null"}
    end
    return {kind = "unsupported", marker = marker}
  end

  return read_object(top_object)
end

local function pakettiAmigoPlistWrite(root)
  local objects = {}

  local function flatten(node)
    objects[#objects + 1] = node
    if node.kind == "dict" then
      for _, k in ipairs(node.keys) do flatten(k) end
      for _, v in ipairs(node.values) do flatten(v) end
    end
  end
  flatten(root)

  local index_of = {}
  for i, node in ipairs(objects) do index_of[node] = i - 1 end

  local ref_size = (#objects <= 255) and 1 or ((#objects <= 65535) and 2 or 4)

  local function encode_count(high, count)
    if count < 15 then
      return string.char(high * 16 + count)
    end
    -- int object holding the real count
    if count <= 255 then
      return string.char(high * 16 + 15, 0x10) .. pakettiAmigoWriteBE(count, 1)
    elseif count <= 65535 then
      return string.char(high * 16 + 15, 0x11) .. pakettiAmigoWriteBE(count, 2)
    else
      return string.char(high * 16 + 15, 0x12) .. pakettiAmigoWriteBE(count, 4)
    end
  end

  local encoded = {}
  for i, node in ipairs(objects) do
    if node.kind == "int" then
      local nbytes = node.bytes or 4
      if node.value > 4294967295 then nbytes = 8 end
      local marker = (nbytes == 1 and 0x10) or (nbytes == 2 and 0x11) or (nbytes == 4 and 0x12) or 0x13
      encoded[i] = string.char(marker) .. pakettiAmigoWriteBE(node.value, nbytes)
    elseif node.kind == "data" then
      encoded[i] = encode_count(4, #node.value) .. node.value
    elseif node.kind == "string" then
      encoded[i] = encode_count(5, #node.value) .. node.value
    elseif node.kind == "ustring" then
      encoded[i] = encode_count(6, #node.value / 2) .. node.value
    elseif node.kind == "bool" then
      encoded[i] = string.char(node.value and 0x09 or 0x08)
    elseif node.kind == "dict" then
      local parts = {encode_count(13, #node.keys)}
      for _, k in ipairs(node.keys) do parts[#parts + 1] = pakettiAmigoWriteBE(index_of[k], ref_size) end
      for _, v in ipairs(node.values) do parts[#parts + 1] = pakettiAmigoWriteBE(index_of[v], ref_size) end
      encoded[i] = table.concat(parts)
    else
      encoded[i] = string.char(0x00)
    end
  end

  local body = {"bplist00"}
  local offsets = {}
  local pos = 8
  for i = 1, #objects do
    offsets[i] = pos
    body[#body + 1] = encoded[i]
    pos = pos + #encoded[i]
  end

  local table_offset = pos
  local offset_size = (table_offset <= 255) and 1 or ((table_offset <= 65535) and 2 or 4)
  for i = 1, #objects do
    body[#body + 1] = pakettiAmigoWriteBE(offsets[i], offset_size)
  end

  body[#body + 1] = string.rep("\0", 6)
  body[#body + 1] = string.char(offset_size, ref_size)
  body[#body + 1] = pakettiAmigoWriteBE(#objects, 8)
  body[#body + 1] = pakettiAmigoWriteBE(0, 8)
  body[#body + 1] = pakettiAmigoWriteBE(table_offset, 8)

  return table.concat(body)
end

local function pakettiAmigoPlistGet(dict, key)
  for i, k in ipairs(dict.keys) do
    if k.value == key then return dict.values[i] end
  end
  return nil
end

--------------------------------------------------------------------------------
-- reading and writing the Amigo plugin state
--------------------------------------------------------------------------------

-- Returns the Amigo plugin device on the given instrument, or nil.
function PakettiAmigoFindDevice(instrument)
  local props = instrument and instrument.plugin_properties
  if not props or not props.plugin_loaded then return nil end
  local device = props.plugin_device
  if not device then return nil end
  if device.name and device.name:lower():find("amigo", 1, true) then return device end
  return nil
end

-- Reads the plugin state and returns a context table:
--   {device, format, preset_xml, tree, plist, header, tail, valuetree_length}
function PakettiAmigoReadState(device)
  local preset = device.active_preset_data
  if not preset or preset == "" then return nil, "plugin returned no preset data" end
  local b64 = preset:match("<ParameterChunk><!%[CDATA%[(.-)%]%]></ParameterChunk>")
  if not b64 then return nil, "no ParameterChunk in preset data" end
  local chunk = base64.decode(b64)

  local ctx = {device = device, preset_xml = preset}

  if chunk:sub(1, 4) == "VST3" then
    ctx.format = "VST3"
    ctx.header = chunk:sub(1, 48)
    local body = chunk:sub(49)
    local tree, after = pakettiAmigoReadTree(body, 1)
    ctx.tree = tree
    ctx.valuetree_length = after - 1
    ctx.tail = body:sub(after)
  elseif chunk:sub(1, 6) == "bplist" then
    ctx.format = "AU"
    local plist, err = pakettiAmigoPlistRead(chunk)
    if not plist then return nil, err end
    ctx.plist = plist
    local state = pakettiAmigoPlistGet(plist, "jucePluginState")
    if not state then return nil, "no jucePluginState in AU plist" end
    ctx.state_node = state
    ctx.tree = pakettiAmigoReadTree(state.value, 1)
  else
    return nil, "unrecognised ParameterChunk (not VST3 and not bplist)"
  end

  if ctx.tree.type ~= "PARAMS" then
    return nil, "unexpected plugin state root '" .. tostring(ctx.tree.type) .. "'"
  end
  return ctx
end

-- Serialises ctx.tree back into the plugin.
function PakettiAmigoWriteState(ctx)
  local new_tree = pakettiAmigoWriteTree(ctx.tree)
  local chunk

  if ctx.format == "VST3" then
    local delta = #new_tree - ctx.valuetree_length
    local header = ctx.header
    local total = pakettiAmigoReadLE(header, 41, 8) + delta
    header = header:sub(1, 40) .. pakettiAmigoWriteLE(total, 8)

    -- fix up the JUCEPrivateDataList entry table: the component chunk grew,
    -- everything positioned after it moved along by the same amount
    local tail = ctx.tail
    local list_pos
    local search = 1
    while true do
      local found = tail:find("JUCEPrivateDataList", search, true)
      if not found then break end
      list_pos = found
      search = found + 1
    end
    if list_pos then
      local p = list_pos + 19
      local count = pakettiAmigoReadLE(tail, p, 4)
      p = p + 4
      local rebuilt = {tail:sub(1, p - 1)}
      for _ = 1, count do
        local id = tail:sub(p, p + 3)
        local offset = pakettiAmigoReadLE(tail, p + 4, 8)
        local size = pakettiAmigoReadLE(tail, p + 12, 8)
        if id == "Comp" then
          size = size + delta
        else
          offset = offset + delta
        end
        rebuilt[#rebuilt + 1] = id .. pakettiAmigoWriteLE(offset, 8) .. pakettiAmigoWriteLE(size, 8)
        p = p + 20
      end
      rebuilt[#rebuilt + 1] = tail:sub(p)
      tail = table.concat(rebuilt)
    end

    chunk = header .. new_tree .. tail
  else
    ctx.state_node.value = new_tree
    chunk = pakettiAmigoPlistWrite(ctx.plist)
  end

  local encoded = base64.encode(chunk)
  local out = ctx.preset_xml:gsub("(<ParameterChunk><!%[CDATA%[).-(%]%]></ParameterChunk>)",
    function(open, close) return open .. encoded .. close end, 1)
  ctx.device.active_preset_data = out
  return true
end

--------------------------------------------------------------------------------
-- where exported wavs live
--------------------------------------------------------------------------------

function PakettiAmigoSampleFolder()
  local sep = (os.platform() == "WINDOWS") and "\\" or "/"
  local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
  local folder = home .. sep .. "Paketti Amigo Samples"
  if not io.exists(folder) then
    os.mkdir(folder)
  end
  return folder .. sep
end

local function pakettiAmigoSafeName(name)
  name = name or ""
  -- drop a trailing file extension, whatever it is - an RX2 import arrives as
  -- "loop.rx2" and should not become "loop.rx2.wav"
  local extension = name:match("%.(%w+)$")
  if extension and #extension <= 4 then name = name:sub(1, #name - #extension - 1) end
  name = name:gsub("[^%w%-%_%. ]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then name = "Amigo Sample" end
  return name
end

--------------------------------------------------------------------------------
-- RENOISE -> AMIGO
--
-- Amigo plays from a file on disk, not from the preset, so the sample is
-- written to a permanent folder and the preset points at it. Slice markers
-- come along for the ride: Amigo's slice0..slice63 are normalised 0..1
-- positions and slicemode 1 puts it into SLICE mode (verified live, AU v1.1.6).
-- Amigo has 64 slice slots, so a longer sample loses its tail slices.
--------------------------------------------------------------------------------

PakettiAmigoMaxSlices = 64

-- writes the sample to the Paketti Amigo Samples folder, returns path and name
local function pakettiAmigoWriteSampleFile(sample, fallback_name)
  local name = pakettiAmigoSafeName(sample.name ~= "" and sample.name or fallback_name)
  local path = PakettiAmigoSampleFolder() .. name .. ".wav"
  if not sample.sample_buffer:save_as(path, "wav") then
    return nil, nil, "could not write " .. path
  end
  return path, name
end

-- points an Amigo instance at a file and copies the sample's slice markers in
local function pakettiAmigoApplySample(device, path, sample)
  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then return nil, err end

  pakettiAmigoSetProp(ctx.tree, "pathname", pakettiAmigoVarString(path))
  -- clear any stale embedded payload so the plugin cannot pick up the old sample
  pakettiAmigoRemoveProp(ctx.tree, "EMBEDDED_FILE")
  pakettiAmigoSetParam(ctx.tree, "embedsample", 0)

  local slices, dropped = {}, 0
  if sample then
    local frames = sample.sample_buffer.number_of_frames
    local markers = sample.slice_markers
    if frames > 1 then
      for i = 1, math.min(#markers, PakettiAmigoMaxSlices - 1) do
        slices[i] = (markers[i] - 1) / (frames - 1)
      end
    end
    dropped = math.max(0, #markers - (PakettiAmigoMaxSlices - 1))
  end
  -- slice0 is the sample start; the markers fill slice1 upward
  for i = 0, PakettiAmigoMaxSlices - 1 do
    pakettiAmigoSetParam(ctx.tree, "slice" .. i, slices[i] or 0)
  end
  pakettiAmigoSetParam(ctx.tree, "slicemode", (#slices > 0) and 1 or 0)

  PakettiAmigoWriteState(ctx)
  return #slices, nil, dropped
end

-- creates a new instrument holding Amigo, right after `after_index`
local function pakettiAmigoNewInstrumentWithAmigo(after_index, name)
  local song = renoise.song()
  local index = after_index + 1
  song:insert_instrument_at(index)
  local instrument = song.instruments[index]
  local ok = pcall(function() instrument.plugin_properties:load_plugin(AMIGO_AU_PATH) end)
  if not ok or not instrument.plugin_properties.plugin_loaded then
    pcall(function() instrument.plugin_properties:load_plugin(AMIGO_VST3_PATH) end)
  end
  local device = PakettiAmigoFindDevice(instrument)
  if not device then
    song:delete_instrument_at(index)
    return nil, nil, "Amigo plugin is not installed / not scanned by Renoise"
  end
  -- loading a plugin renames the instrument, so set the name afterwards
  instrument.name = name
  return device, index
end

function PakettiAmigoRenoiseToAmigo()
  local song = renoise.song()
  local source = song.selected_sample
  if not source or not source.sample_buffer or not source.sample_buffer.has_sample_data then
    renoise.app():show_status("Renoise to Amigo: select a sample with audio data first.")
    return
  end

  local path, name, err = pakettiAmigoWriteSampleFile(source, song.selected_instrument.name)
  if not path then
    renoise.app():show_status("Renoise to Amigo: " .. tostring(err))
    return
  end

  -- put it in the selected instrument's Amigo if it already has one, otherwise
  -- in a fresh instrument right after it. The source sample is never touched.
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  if not device then
    local index
    device, index, err = pakettiAmigoNewInstrumentWithAmigo(song.selected_instrument_index, name)
    if not device then
      renoise.app():show_status("Renoise to Amigo: " .. tostring(err))
      return
    end
    song.selected_instrument_index = index
  end

  local count, apply_err, dropped = pakettiAmigoApplySample(device, path, source)
  if not count then
    renoise.app():show_status("Renoise to Amigo: " .. tostring(apply_err))
    return
  end

  local message = "Renoise to Amigo: " .. name .. ".wav -> " .. device.name
  if count > 0 then
    message = message .. " with " .. count .. " slices"
    if dropped > 0 then message = message .. " (" .. dropped .. " past Amigo's 64 dropped)" end
  end
  renoise.app():show_status(message)
  print("PakettiAmigo: exported to " .. path)
end

-- Same as above but also asks Amigo to bake the wav into its own state, so the
-- preset travels without the file. Needs Amigo AU v1.1.6 or newer.
function PakettiAmigoRenoiseToAmigoEmbedded()
  PakettiAmigoRenoiseToAmigo()
  local device = PakettiAmigoFindDevice(renoise.song().selected_instrument)
  if not device then return end
  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then
    renoise.app():show_status("Renoise to Amigo (embedded): " .. tostring(err))
    return
  end
  pakettiAmigoSetParam(ctx.tree, "embedsample", 1)
  PakettiAmigoWriteState(ctx)

  -- read back and report whether the plugin actually embedded anything
  local check = PakettiAmigoReadState(device)
  local embedded = check and pakettiAmigoGetProp(check.tree, "EMBEDDED_FILE")
  if embedded then
    renoise.app():show_status("Renoise to Amigo: sample embedded into the Amigo preset.")
  else
    renoise.app():show_status("Renoise to Amigo: sample linked. This Amigo build does not support Embed.")
  end
end

--------------------------------------------------------------------------------
-- AMIGO -> RENOISE
--------------------------------------------------------------------------------

function PakettiAmigoAmigoToRenoise()
  local song = renoise.song()
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  if not device then
    renoise.app():show_status("Amigo to Renoise: select an instrument that has the Amigo plugin loaded.")
    return
  end

  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then
    renoise.app():show_status("Amigo to Renoise: " .. tostring(err))
    return
  end

  local path = pakettiAmigoVarToString(pakettiAmigoGetProp(ctx.tree, "pathname") or "")
  local embedded = pakettiAmigoVarToString(pakettiAmigoGetProp(ctx.tree, "EMBEDDED_FILE") or "")

  local load_path, name, temp_path
  if path and path ~= "" and io.exists(path) then
    load_path = path
    name = path:match("([^/\\]+)$") or "Amigo Sample"
  elseif embedded and embedded ~= "" then
    local wav = base64.decode(embedded)
    if not wav or wav:sub(1, 4) ~= "RIFF" then
      renoise.app():show_status("Amigo to Renoise: the embedded data is not a WAV file.")
      return
    end
    temp_path = pakettiGetTempFilePath(".wav")
    local file = io.open(temp_path, "wb")
    if not file then
      renoise.app():show_status("Amigo to Renoise: could not write " .. temp_path)
      return
    end
    file:write(wav)
    file:close()
    load_path = temp_path
    name = (path and path ~= "" and (path:match("([^/\\]+)$"))) or "Amigo Sample"
  else
    renoise.app():show_status("Amigo to Renoise: this Amigo has no sample - load one, or click Embed.")
    return
  end

  local index = song.selected_instrument_index + 1
  song:insert_instrument_at(index)
  song.selected_instrument_index = index
  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.instruments[song.selected_instrument_index]
  instrument:insert_sample_at(1)
  song.selected_sample_index = 1
  local sample = instrument.samples[1]

  local loaded, message = sample.sample_buffer:load_from(load_path)
  if not loaded then
    renoise.app():show_status("Amigo to Renoise: sample load failed - " .. tostring(message))
    if temp_path then os.remove(temp_path) end
    return
  end

  name = name:gsub("%.wav$", "")
  instrument.name = name
  sample.name = name

  local last = #instrument.samples
  if last > 1 and instrument.samples[last].name == "Placeholder sample" then
    instrument:delete_sample_at(last)
  end

  -- bring Amigo's slices back with the audio. Amigo's slice0..slice63 are
  -- normalised 0..1 positions, so they turn straight back into Renoise slice
  -- markers - including any slicing you did inside Amigo itself.
  local slice_count = 0
  local frames = sample.sample_buffer.number_of_frames
  if frames > 1 then
    local positions = {}
    for i = 0, PakettiAmigoMaxSlices - 1 do
      local value = pakettiAmigoGetParam(ctx.tree, "slice" .. i)
      if value and value > 0 and value < 1 then positions[#positions + 1] = value end
    end
    table.sort(positions)
    local previous = 0
    if #positions > 0 then
      -- Amigo's slice0 is the sample start, and Renoise spells that as a marker
      -- on frame 1. Without it the first region would be lost on the way back.
      sample:insert_slice_marker(1)
      previous = 1
      slice_count = 1
    end
    for _, value in ipairs(positions) do
      local frame = math.floor(value * (frames - 1) + 0.5) + 1
      if frame > previous and frame < frames then
        sample:insert_slice_marker(frame)
        previous = frame
        slice_count = slice_count + 1
      end
    end
  end

  if temp_path then os.remove(temp_path) end
  local status = "Amigo to Renoise: " .. name .. " loaded into instrument " .. string.format("%02X", index - 1)
  if slice_count > 0 then status = status .. " with " .. slice_count .. " slices" end
  renoise.app():show_status(status)
end

--------------------------------------------------------------------------------
-- send a freshly imported instrument to Amigo, alongside the original
--
-- Used by the "Import Goes Straight Into Amigo" option. The imported Renoise
-- instrument is left exactly as it is - samples, slices and all - and a second
-- instrument holding Amigo is created right after it with the same audio and
-- the same slice points. Two instruments, nothing destroyed, and no double
-- triggering (a single instrument holding both a plugin and samples would
-- sound both on every note).
--------------------------------------------------------------------------------

function PakettiAmigoSendInstrumentToAmigo(source_index)
  local song = renoise.song()
  local instrument = song.instruments[source_index]
  if not instrument then return false, "no such instrument" end
  local source = instrument.samples[1]
  if not source or not source.sample_buffer or not source.sample_buffer.has_sample_data then
    return false, "instrument has no sample data"
  end

  local path, name, err = pakettiAmigoWriteSampleFile(source, instrument.name)
  if not path then return false, err end

  local device, index, new_err = pakettiAmigoNewInstrumentWithAmigo(source_index, name)
  if not device then return false, new_err end

  local count, apply_err, dropped = pakettiAmigoApplySample(device, path, source)
  if not count then
    song:delete_instrument_at(index)
    return false, apply_err
  end
  return true, nil, count, dropped, index
end

-- true when a sliced import (RX2, REX, PTI, WAV with CUE markers) should also land in Amigo
function PakettiAmigoSlicedImportEnabled()
  return preferences and preferences.pakettiAmigoRX2Import and preferences.pakettiAmigoRX2Import.value or false
end

function PakettiAmigoToggleSlicedImport()
  local on = not PakettiAmigoSlicedImportEnabled()
  preferences.pakettiAmigoRX2Import.value = on
  preferences:save_as("preferences.xml")
  if on then
    renoise.app():show_status("Sliced imports (RX2, REX, PTI, WAV+CUE) also go into Amigo: ON")
  else
    renoise.app():show_status("Sliced imports also go into Amigo: OFF")
  end
end

-- called from the RX2, REX, PTI and WAV+CUE loaders once the file has been
-- decoded into a normal Renoise instrument
function PakettiAmigoHandleSlicedImport(instrument_index, label)
  if not PakettiAmigoSlicedImportEnabled() then return false end
  local ok, err, count, dropped, index = PakettiAmigoSendInstrumentToAmigo(instrument_index)
  if not ok then
    renoise.app():show_status((label or "Import") .. " to Amigo: " .. tostring(err) ..
      " - the Renoise instrument is untouched.")
    return false
  end
  renoise.song().selected_instrument_index = index
  local message = (label or "Import") .. " also loaded into Amigo with " .. count .. " slices"
  if dropped > 0 then
    message = message .. " (" .. dropped .. " slices past Amigo's 64 were dropped)"
  end
  renoise.app():show_status(message)
  return true
end

-- kept for the RX2 loader's existing call site
function PakettiAmigoHandleRX2Import(instrument_index)
  return PakettiAmigoHandleSlicedImport(instrument_index, "RX2")
end

--------------------------------------------------------------------------------
-- what is in there? (console dump, handy when a preset misbehaves)
--------------------------------------------------------------------------------

function PakettiAmigoDumpState()
  local device = PakettiAmigoFindDevice(renoise.song().selected_instrument)
  if not device then
    renoise.app():show_status("Amigo: select an instrument that has the Amigo plugin loaded.")
    return
  end
  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then
    renoise.app():show_status("Amigo: " .. tostring(err))
    return
  end
  print("--- Amigo state (" .. ctx.format .. ", " .. device.name .. ") ---")
  for _, p in ipairs(ctx.tree.props) do
    local value = pakettiAmigoVarToString(p[2])
    if p[1] == "EMBEDDED_FILE" then
      print(string.format("  %s = <%d base64 chars>", p[1], value and #value or 0))
    else
      print(string.format("  %s = %s", p[1], tostring(value)))
    end
  end
  print("  " .. #ctx.tree.children .. " parameters")
  renoise.app():show_status("Amigo state dumped to the scripting console.")
end

--------------------------------------------------------------------------------
-- registrations
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Renoise to Amigo (Selected Sample)",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Renoise to Amigo (Selected Sample, Embedded)",
  invoke = function() PakettiAmigoRenoiseToAmigoEmbedded() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Renoise (New Instrument)",
  invoke = function() PakettiAmigoAmigoToRenoise() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Dump Amigo State to Console",
  invoke = function() PakettiAmigoDumpState() end}

PakettiAddMenuEntry{name = "Main Menu:Options:Sliced Imports Also Go Into Amigo (RX2, REX, PTI, WAV+CUE) Toggle",
  invoke = function() PakettiAmigoToggleSlicedImport() end,
  selected = function() return PakettiAmigoSlicedImportEnabled() end}

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Selected Sample to Amigo Sampler",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Selected Sample to Amigo Sampler (Embedded)",
  invoke = function() PakettiAmigoRenoiseToAmigoEmbedded() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Import Sample from Amigo Sampler",
  invoke = function() PakettiAmigoAmigoToRenoise() end}

PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Renoise to Amigo (Selected Sample)",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Renoise (New Instrument)",
  invoke = function() PakettiAmigoAmigoToRenoise() end}

PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Renoise to Amigo (Selected Sample)",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Amigo to Renoise (New Instrument)",
  invoke = function() PakettiAmigoAmigoToRenoise() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Toggle Sliced Imports Also Go Into Amigo",
  invoke = function() PakettiAmigoToggleSlicedImport() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Renoise to Amigo Selected Sample",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Renoise to Amigo Selected Sample Embedded",
  invoke = function() PakettiAmigoRenoiseToAmigoEmbedded() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Renoise New Instrument",
  invoke = function() PakettiAmigoAmigoToRenoise() end}

renoise.tool():add_midi_mapping{name = "Paketti:Renoise to Amigo Selected Sample",
  invoke = function(message) if message:is_trigger() then PakettiAmigoRenoiseToAmigo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Renoise New Instrument",
  invoke = function(message) if message:is_trigger() then PakettiAmigoAmigoToRenoise() end end}
