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

-- the Amigo window this feature opened last, so a ten-file drop leaves one
-- editor showing the last import instead of ten stacked windows. Editors you
-- opened yourself are never touched.
local pakettiAmigoLastOpenedEditor = nil

local function pakettiAmigoShowEditorFor(instrument_index)
  if pakettiAmigoLastOpenedEditor then
    pcall(function() pakettiAmigoLastOpenedEditor.external_editor_visible = false end)
    pakettiAmigoLastOpenedEditor = nil
  end
  local device = PakettiAmigoFindDevice(renoise.song().instruments[instrument_index])
  if device then
    local shown = pcall(function() device.external_editor_visible = true end)
    if shown then pakettiAmigoLastOpenedEditor = device end
  end
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
  -- Octatrack .ot samples arrive named with the whole slice table baked in,
  -- which is a 200-character filename one step away from the filesystem limit
  if #name > 80 then name = name:sub(1, 80):gsub("[%s%._%-]+$", "") end
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

-- Writes the sample to the Paketti Amigo Samples folder and returns path and
-- name. Never clobbers a wav that is already there: if the name is taken, the
-- file gets a -2, -3, ... suffix. The one exception is `keep_path`, which is
-- the file this very Amigo already points at - re-exporting to the same slot
-- should land on the same file rather than pile up copies.
local function pakettiAmigoWriteSampleFile(sample, fallback_name, keep_path)
  local base = pakettiAmigoSafeName(sample.name ~= "" and sample.name or fallback_name)
  local folder = PakettiAmigoSampleFolder()
  local name = base
  local path = folder .. name .. ".wav"
  local attempt = 1
  while io.exists(path) and path ~= keep_path do
    attempt = attempt + 1
    name = base .. "-" .. attempt
    path = folder .. name .. ".wav"
  end
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
    -- Amigo's slice0 IS the sample start, so a Renoise marker sitting on frame 1
    -- would only duplicate it and waste a slot. Dropping it means 64 Renoise
    -- slices land in Amigo's 64 slots exactly, with nothing lost.
    local cuts = {}
    for _, marker in ipairs(sample.slice_markers) do
      if marker > 1 then cuts[#cuts + 1] = marker end
    end
    if frames > 1 then
      for i = 1, math.min(#cuts, PakettiAmigoMaxSlices - 1) do
        slices[i] = (cuts[i] - 1) / (frames - 1)
      end
    end
    dropped = math.max(0, #cuts - (PakettiAmigoMaxSlices - 1))
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

  -- if this instrument already hosts an Amigo, re-export onto the same file
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  local keep_path
  if device then
    local existing = PakettiAmigoReadState(device)
    if existing then
      keep_path = pakettiAmigoVarToString(pakettiAmigoGetProp(existing.tree, "pathname") or "")
    end
  end

  local path, name, err = pakettiAmigoWriteSampleFile(source, song.selected_instrument.name, keep_path)
  if not path then
    renoise.app():show_status("Renoise to Amigo: " .. tostring(err))
    return
  end

  -- put it in the selected instrument's Amigo if it already has one, otherwise
  -- in a fresh instrument right after it. The source sample is never touched.
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

-- Renoise keeps one empty instrument slot at the end of the list, and
-- app():load_instrument() adds a fresh one every time it is called. When we
-- append in a loop that would strand an empty instrument between every result,
-- so the trailing empty slot is reused instead of inserting on top of it.
local function pakettiAmigoAppendIndex()
  local song = renoise.song()
  local index = #song.instruments
  local last = song.instruments[index]
  if last and #last.samples == 0 and last.name == ""
    and not (last.plugin_properties and last.plugin_properties.plugin_loaded) then
    return index, true
  end
  return index + 1, false
end

-- Builds a Renoise instrument at `at_index` from one Amigo device: the audio it
-- is holding plus its slice points. The Amigo instrument itself is never
-- touched. Pass reuse_slot when at_index is an empty instrument that should be
-- filled in rather than pushed aside. Returns ok, name, slice_count, error.
function PakettiAmigoExtractDeviceToInstrument(device, at_index, reuse_slot)
  local song = renoise.song()
  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then return false, nil, 0, err end

  local path = pakettiAmigoVarToString(pakettiAmigoGetProp(ctx.tree, "pathname") or "")
  local embedded = pakettiAmigoVarToString(pakettiAmigoGetProp(ctx.tree, "EMBEDDED_FILE") or "")

  local load_path, name, temp_path
  if path and path ~= "" and io.exists(path) then
    load_path = path
    name = path:match("([^/\\]+)$") or "Amigo Sample"
  elseif embedded and embedded ~= "" then
    local wav = base64.decode(embedded)
    if not wav or wav:sub(1, 4) ~= "RIFF" then
      return false, nil, 0, "the embedded data is not a WAV file"
    end
    temp_path = pakettiGetTempFilePath(".wav")
    local file = io.open(temp_path, "wb")
    if not file then return false, nil, 0, "could not write " .. temp_path end
    file:write(wav)
    file:close()
    load_path = temp_path
    name = (path and path ~= "" and (path:match("([^/\\]+)$"))) or "Amigo Sample"
  else
    return false, nil, 0, "this Amigo has no sample - load one, or click Embed"
  end

  if not reuse_slot then song:insert_instrument_at(at_index) end
  song.selected_instrument_index = at_index
  pakettiPreferencesDefaultInstrumentLoader()

  local instrument = song.instruments[at_index]
  instrument:insert_sample_at(1)
  song.selected_sample_index = 1
  local sample = instrument.samples[1]

  local loaded, message = sample.sample_buffer:load_from(load_path)
  if not loaded then
    if temp_path then os.remove(temp_path) end
    if not reuse_slot then song:delete_instrument_at(at_index) end
    return false, nil, 0, "sample load failed - " .. tostring(message)
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
  return true, name, slice_count, nil
end

function PakettiAmigoAmigoToRenoise()
  local song = renoise.song()
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  if not device then
    renoise.app():show_status("Amigo to Renoise: select an instrument that has the Amigo plugin loaded.")
    return
  end

  local index = song.selected_instrument_index + 1
  local ok, name, slice_count, err = PakettiAmigoExtractDeviceToInstrument(device, index)
  if not ok then
    renoise.app():show_status("Amigo to Renoise: " .. tostring(err))
    return
  end

  local status = "Amigo to Renoise: " .. name .. " loaded into instrument " .. string.format("%02X", index - 1)
  if slice_count > 0 then status = status .. " with " .. slice_count .. " slices" end
  renoise.app():show_status(status)
end

--------------------------------------------------------------------------------
-- OTHER WAYS TO SLICE INTO AMIGO
--
-- Transient detection reuses Paketti's Beat Detect engine (headless, so no
-- dialog has to be open), and the BPM variants reuse pakettiBPMBasedSlice.
-- Both then hand the result to Amigo exactly like Wipe&Slice&Amigo does.
--------------------------------------------------------------------------------

local function pakettiAmigoAfterSlicing(label)
  local song = renoise.song()
  local source_index = song.selected_instrument_index
  local sample = song.instruments[source_index].samples[1]
  local found = sample and #sample.slice_markers or 0
  local ok, err, count, dropped, index = PakettiAmigoSendInstrumentToAmigo(source_index)
  if not ok then
    renoise.app():show_status(label .. ": " .. tostring(err) .. " - the sliced instrument is untouched.")
    return false
  end
  song.selected_instrument_index = index
  pakettiAmigoShowEditorFor(index)
  local message = label .. ": " .. found .. " slices -> Amigo"
  if dropped > 0 then message = message .. " (" .. dropped .. " past Amigo's 64 were dropped)" end
  renoise.app():show_status(message)
  return true
end

local function pakettiAmigoSliceableSample()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return nil, "select a sample with audio data first"
  end
  if PakettiAmigoFindDevice(song.selected_instrument) then
    return nil, "that instrument is an Amigo - select the sampled one instead"
  end
  return sample
end

function PakettiAmigoTransientSliceAndAmigo()
  local sample, err = pakettiAmigoSliceableSample()
  if not sample then
    renoise.app():show_status("Transient Slice & Amigo: " .. err .. ".")
    return
  end
  renoise.song().selected_sample_index = 1
  PakettiBeatDetectSliceHeadless("combined")
  pakettiAmigoAfterSlicing("Transient Slice & Amigo")
end

function PakettiAmigoBPMSliceAndAmigo(beats_per_slice)
  local sample, err = pakettiAmigoSliceableSample()
  if not sample then
    renoise.app():show_status("BPM Slice & Amigo: " .. err .. ".")
    return
  end
  local song = renoise.song()
  song.selected_sample_index = 1
  if #sample.slice_markers > 0 then sample.slice_markers = {} end
  pakettiBPMBasedSlice(song.transport.bpm, beats_per_slice)
  pakettiAmigoAfterSlicing(string.format("BPM Slice & Amigo (%g beat%s)",
    beats_per_slice, (beats_per_slice == 1) and "" or "s"))
end

--------------------------------------------------------------------------------
-- PRINT AMIGO SLICES TO THE PATTERN
--
-- Measured live by rendering a probe: Amigo maps its slices chromatically
-- upward from the `basenote` parameter (default 60 = C-4), one slice per
-- semitone, and notes below the root make no sound at all. So printing slice k
-- means writing basenote + k.
--------------------------------------------------------------------------------

-- how many slices an Amigo is actually holding, and where its keyboard starts
function PakettiAmigoSliceInfo(device)
  local ctx, err = PakettiAmigoReadState(device)
  if not ctx then return nil, nil, err end
  local basenote = pakettiAmigoGetParam(ctx.tree, "basenote") or 60
  basenote = math.floor(basenote + 0.5)
  local count = 1 -- slice0 is the sample start and is always playable
  for i = 1, PakettiAmigoMaxSlices - 1 do
    local value = pakettiAmigoGetParam(ctx.tree, "slice" .. i)
    if value and value > 0 and value < 1 then count = count + 1 end
  end
  local slicemode = pakettiAmigoGetParam(ctx.tree, "slicemode") or 0
  if slicemode < 0.5 then count = 1 end
  return count, basenote, nil
end

function PakettiAmigoPrintSlicesToPattern()
  local song = renoise.song()
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  if not device then
    renoise.app():show_status("Print Amigo Slices: select an instrument that has the Amigo plugin loaded.")
    return
  end
  if song.selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Print Amigo Slices: select a normal track, not the master or a send.")
    return
  end

  local count, basenote, err = PakettiAmigoSliceInfo(device)
  if not count then
    renoise.app():show_status("Print Amigo Slices: " .. tostring(err))
    return
  end

  local pattern = song.selected_pattern
  local track = pattern.tracks[song.selected_track_index]
  local lines = pattern.number_of_lines
  local instrument_value = song.selected_instrument_index - 1

  -- clear the column we are about to fill, so re-printing does not layer
  for row = 1, lines do
    track:line(row).note_columns[1]:clear()
  end

  local written = 0
  for k = 0, count - 1 do
    local row = math.floor(k * lines / count) + 1
    local note = basenote + k
    if row <= lines and note <= 119 then
      local column = track:line(row).note_columns[1]
      column.note_value = note
      column.instrument_value = instrument_value
      written = written + 1
    end
  end

  renoise.app():show_status(string.format(
    "Print Amigo Slices: %d of %d slices across %d lines, from %s",
    written, count, lines, tostring(song.selected_instrument.name)))
end

-- Wipe, slice, hand to Amigo, and print the slice triggers in one go
function PakettiAmigoWipeSliceAndAmigoAndPrint(slice_count)
  PakettiAmigoWipeSliceAndAmigo(slice_count)
  if PakettiAmigoFindDevice(renoise.song().selected_instrument) then
    PakettiAmigoPrintSlicesToPattern()
  end
end

--------------------------------------------------------------------------------
-- AMIGO -> RENOISE DRUMKIT
--
-- Import gives you one sliced instrument. This gives you the slices as separate
-- keyzone-mapped one-shots instead, which is what you want for finger drumming
-- and for the drumkit-shaped exporters. Paketti already turns a sliced
-- instrument into a drumkit, so this only has to get the Amigo into that shape
-- first. Both instruments are kept: the sliced one and the drumkit.
--------------------------------------------------------------------------------

function PakettiAmigoDeviceToDrumkit(device, at_index)
  local song = renoise.song()
  local ok, name, slice_count, err = PakettiAmigoExtractDeviceToInstrument(device, at_index)
  if not ok then return false, nil, 0, err end
  if slice_count == 0 then
    return true, name, 0, nil -- nothing to isolate, the plain sample is already there
  end
  song.selected_instrument_index = at_index
  song.selected_sample_index = 1
  PakettiIsolateSlicesToInstrumentNoProcess()

  -- The isolate step leaves every sample mapped across the whole keyboard, so
  -- one key would fire all of them at once. Lay them out one per key from C-0,
  -- which is what the Paketti drumkit template itself does (its placeholder is
  -- base 0, range 0-0).
  local drumkit = song.instruments[song.selected_instrument_index]
  if drumkit and #drumkit.samples > 0 then
    for k = 1, #drumkit.samples do
      local note = k - 1
      if note > 119 then note = 119 end
      local mapping = drumkit.samples[k].sample_mapping
      mapping.base_note = note
      mapping.note_range = {note, note}
    end
  end

  return true, name, slice_count, nil
end

function PakettiAmigoToRenoiseDrumkit()
  local song = renoise.song()
  local device = PakettiAmigoFindDevice(song.selected_instrument)
  if not device then
    renoise.app():show_status("Amigo to Renoise Drumkit: select an instrument that has the Amigo plugin loaded.")
    return
  end
  local ok, name, slice_count, err = PakettiAmigoDeviceToDrumkit(device, song.selected_instrument_index + 1)
  if not ok then
    renoise.app():show_status("Amigo to Renoise Drumkit: " .. tostring(err))
    return
  end
  if slice_count == 0 then
    renoise.app():show_status("Amigo to Renoise Drumkit: " .. name ..
      " has no slices, so it came in as a single sample.")
    return
  end
  renoise.app():show_status("Amigo to Renoise Drumkit: " .. name .. " -> " ..
    slice_count .. " keyzone-mapped one-shots")
end

function PakettiAmigoBatchAmigosToDrumkits()
  local song = renoise.song()
  local devices, sources = {}, {}
  for i = 1, #song.instruments do
    local device = PakettiAmigoFindDevice(song.instruments[i])
    if device then devices[#devices + 1] = device sources[#sources + 1] = i end
  end
  if #devices == 0 then
    renoise.app():show_status("Amigo batch: this song has no instruments with the Amigo plugin.")
    return
  end
  local made, failed = 0, {}
  for n = 1, #devices do
    local at_index = pakettiAmigoAppendIndex()
    local ok, name, slice_count, err = PakettiAmigoDeviceToDrumkit(devices[n], at_index)
    if ok then
      made = made + 1
      print(string.format("PakettiAmigo: instrument %02X -> %s drumkit (%d one-shots)",
        sources[n] - 1, name, slice_count))
    else
      failed[#failed + 1] = string.format("%02X (%s)", sources[n] - 1, tostring(err))
    end
  end
  local status = "Amigo batch: " .. made .. " of " .. #devices .. " Amigos are now drumkits"
  if #failed > 0 then status = status .. " - skipped " .. table.concat(failed, ", ") end
  renoise.app():show_status(status)
  print("PakettiAmigo: " .. status)
end

--------------------------------------------------------------------------------
-- batch, both ways
--
-- Both of these APPEND to the end of the instrument list and never move, alter
-- or remove anything that is already in the song. Appending matters: inserting
-- in the middle would renumber every instrument after it, and your pattern data
-- points at instrument numbers.
--------------------------------------------------------------------------------

-- Every Amigo in the song -> a Renoise instrument each, appended in order.
-- So a song of 10 Amigos ends up as those 10 Amigos followed by 10 sampled
-- instruments with the slices set. The Amigo instruments are left alone.
function PakettiAmigoBatchAmigosToRenoise()
  local song = renoise.song()
  local devices, sources = {}, {}
  for i = 1, #song.instruments do
    local device = PakettiAmigoFindDevice(song.instruments[i])
    if device then
      devices[#devices + 1] = device
      sources[#sources + 1] = i
    end
  end
  if #devices == 0 then
    renoise.app():show_status("Amigo batch: this song has no instruments with the Amigo plugin.")
    return
  end

  local made, failed = 0, {}
  for n = 1, #devices do
    -- appending keeps every existing index valid, including the ones we scanned
    local at_index, reuse = pakettiAmigoAppendIndex()
    local ok, name, slice_count, err = PakettiAmigoExtractDeviceToInstrument(devices[n], at_index, reuse)
    if ok then
      made = made + 1
      print(string.format("PakettiAmigo: instrument %02X -> %s (%d slices)", sources[n] - 1, name, slice_count))
    else
      failed[#failed + 1] = string.format("%02X (%s)", sources[n] - 1, tostring(err))
    end
  end

  local status = "Amigo batch: " .. made .. " of " .. #devices .. " Amigos are now Renoise instruments"
  if #failed > 0 then status = status .. " - skipped " .. table.concat(failed, ", ") end
  renoise.app():show_status(status)
  print("PakettiAmigo: " .. status)
end

-- Every sampled instrument in the song -> an Amigo each, appended in order.
-- Instruments that already host Amigo are skipped, and nothing existing moves.
function PakettiAmigoBatchInstrumentsToAmigo()
  local song = renoise.song()
  local sources = {}
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    local sample = instrument.samples[1]
    if not PakettiAmigoFindDevice(instrument)
      and sample and sample.sample_buffer and sample.sample_buffer.has_sample_data then
      sources[#sources + 1] = i
    end
  end
  if #sources == 0 then
    renoise.app():show_status("Amigo batch: this song has no sampled instruments to send to Amigo.")
    return
  end

  local made, failed = 0, {}
  for _, index in ipairs(sources) do
    local instrument = song.instruments[index]
    local sample = instrument.samples[1]
    local path, name, err = pakettiAmigoWriteSampleFile(sample, instrument.name)
    if not path then
      failed[#failed + 1] = string.format("%02X (%s)", index - 1, tostring(err))
    else
      local device, new_index, new_err = pakettiAmigoNewInstrumentWithAmigo(#song.instruments, name)
      if not device then
        failed[#failed + 1] = string.format("%02X (%s)", index - 1, tostring(new_err))
      else
        local count, apply_err, dropped = pakettiAmigoApplySample(device, path, sample)
        if not count then
          song:delete_instrument_at(new_index)
          failed[#failed + 1] = string.format("%02X (%s)", index - 1, tostring(apply_err))
        else
          made = made + 1
          print(string.format("PakettiAmigo: instrument %02X -> Amigo %02X, %s, %d slices%s",
            index - 1, new_index - 1, name, count, (dropped > 0) and (" (" .. dropped .. " dropped)") or ""))
        end
      end
    end
  end

  local status = "Amigo batch: " .. made .. " of " .. #sources .. " instruments are now Amigos"
  if #failed > 0 then status = status .. " - skipped " .. table.concat(failed, ", ") end
  renoise.app():show_status(status)
  print("PakettiAmigo: " .. status)
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

-- true when a sliced import (RX2, REX, PTI, ITI, OT, WAV with CUE markers) should also land in Amigo
function PakettiAmigoSlicedImportEnabled()
  return preferences and preferences.pakettiAmigoRX2Import and preferences.pakettiAmigoRX2Import.value or false
end

function PakettiAmigoToggleSlicedImport()
  local on = not PakettiAmigoSlicedImportEnabled()
  preferences.pakettiAmigoRX2Import.value = on
  preferences:save_as("preferences.xml")
  if on then
    renoise.app():show_status("Sliced imports (RX2, REX, PTI, ITI, OT, WAV+CUE) also go into Amigo: ON")
  else
    renoise.app():show_status("Sliced imports also go into Amigo: OFF")
  end
end

-- called from the RX2, REX, PTI, ITI, OT and WAV+CUE loaders once the file has been
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

  -- show the Amigo you just made, closing the one the previous drop opened
  pakettiAmigoShowEditorFor(index)

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
-- Wipe & Slice & Amigo
--
-- The same shape as Paketti's Wipe&Slice&Pattern and Wipe&Slice&Phrase: wipe
-- whatever slicing the sample has, cut it into N equal slices with the existing
-- slicerough() engine, then build the Amigo beside it and open its editor. The
-- sampled instrument is kept, exactly like the import path.
--------------------------------------------------------------------------------

function PakettiAmigoWipeSliceAndAmigo(slice_count)
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Wipe&Slice&Amigo: select a sample with audio data first.")
    return
  end
  if PakettiAmigoFindDevice(song.selected_instrument) then
    renoise.app():show_status("Wipe&Slice&Amigo: that instrument is an Amigo - select the sampled one instead.")
    return
  end

  slicerough(slice_count)

  local source_index = song.selected_instrument_index
  local ok, err, count, dropped, index = PakettiAmigoSendInstrumentToAmigo(source_index)
  if not ok then
    renoise.app():show_status("Wipe&Slice&Amigo: " .. tostring(err) .. " - the sliced instrument is untouched.")
    return
  end
  song.selected_instrument_index = index
  pakettiAmigoShowEditorFor(index)

  local message = "Wipe&Slice&Amigo: " .. slice_count .. " slices -> Amigo"
  if dropped > 0 then
    message = message .. " (" .. dropped .. " past Amigo's 64 were dropped)"
  end
  renoise.app():show_status(message)
end

--------------------------------------------------------------------------------
-- AMIGO -> HARDWARE FORMATS (Octatrack .ot+.wav, Digitakt chain, WAV+CUE)
--
-- Paketti already knows how to write all three, so this only has to carry the
-- audio and the slice points over to those exporters. The Amigo is read, never
-- written: the Renoise instrument used to hand the sample to the exporter is
-- temporary and is removed again afterwards.
--------------------------------------------------------------------------------

-- Runs work inside a ProcessSlicer with a progress dialog. Writing a long ITI
-- takes minutes, and doing it in one go made Renoise put up "script not
-- responding"; inside a coroutine the exporters yield instead. `work` is called
-- with a report(text) function.
local function pakettiAmigoRunSliced(title, work)
  local slicer, dialog, vb
  slicer = ProcessSlicer(function()
    work(function(text)
      if vb and vb.views and vb.views.progress_text then vb.views.progress_text.text = text end
    end)
    if dialog and dialog.visible then dialog:close() end
  end)
  dialog, vb = slicer:create_dialog(title)
  slicer:start()
end

local function pakettiAmigoPathSeparator()
  return (os.platform() == "WINDOWS") and "\\" or "/"
end

-- one entry per export target. `taken` decides when a name in a batch folder is
-- already in use, since Octatrack writes two files per export.
local pakettiAmigoExportTargets = {
  ot = {
    label = "Octatrack (.ot + .wav)",
    extension = "wav",
    taken = function(folder, name)
      return io.exists(folder .. name .. ".wav") or io.exists(folder .. name .. ".ot")
    end,
    run = function(path, report) PakettiOTExport(path) end,
  },
  digitakt = {
    label = "Digitakt chain (.wav)",
    extension = "wav",
    taken = function(folder, name) return io.exists(folder .. name .. ".wav") end,
    run = function(path, report)
      export_digitakt_chain{
        digitakt_version = "digitakt2",
        export_mode = "chain",
        slot_count = nil,
        mono_method = "average",
        apply_fadeout = true,
        apply_dither = false,
        pad_with_zero = false,
        output_path = path,
      }
    end,
  },
  wavcue = {
    label = "WAV with CUE header",
    extension = "wav",
    taken = function(folder, name)
      return io.exists(folder .. name .. ".wav") or io.exists(folder .. name .. ".cue")
    end,
    run = function(path, report) PakettiWavCueExportSampleWithCues(true, path) end,
  },
  -- Polyend PTI holds 48 slices; Amigo can hold 64, so a heavily sliced Amigo
  -- loses the tail. The PTI exporter itself decides how to truncate.
  pti = {
    label = "Polyend PTI (.pti)",
    extension = "pti",
    taken = function(folder, name) return io.exists(folder .. name .. ".pti") end,
    run = function(path, report) pti_savesample_to_path(path) end,
  },
  -- Impulse Tracker ITI writes the instrument, so a sliced Amigo arrives as the
  -- full sample plus one sample per slice, the way Renoise itself keyzones it.
  iti = {
    label = "Impulse Tracker ITI (.iti)",
    extension = "iti",
    taken = function(folder, name) return io.exists(folder .. name .. ".iti") end,
    run = function(path, report) iti_export_instrument(renoise.song().selected_instrument, path, report) end,
  },
}

local function pakettiAmigoUniqueExportPath(target, folder, name, used)
  local base, attempt = name, 1
  while target.taken(folder, name) or used[name:lower()] do
    attempt = attempt + 1
    name = base .. "-" .. attempt
  end
  used[name:lower()] = true
  return folder .. name .. "." .. (target.extension or "wav")
end

-- folder = nil asks for a filename, otherwise the name comes from the Amigo
local function pakettiAmigoExportDeviceVia(target, device, folder, used, output_path, report)
  local song = renoise.song()
  local at_index, reuse = pakettiAmigoAppendIndex()
  local ok, name, slice_count, err = PakettiAmigoExtractDeviceToInstrument(device, at_index, reuse)
  if not ok then return false, nil, 0, err end

  song.selected_instrument_index = at_index
  song.selected_sample_index = 1

  local path = output_path
  if not path or path == "" then
    if folder and folder ~= "" then
      path = pakettiAmigoUniqueExportPath(target, folder, name, used)
    else
      path = renoise.app():prompt_for_filename_to_write(target.extension or "wav",
        "Save Amigo as " .. target.label .. "...")
    end
  end
  if not path or path == "" then
    song:delete_instrument_at(at_index)
    return false, name, 0, "cancelled"
  end

  local ran, run_err = pcall(function() target.run(path, report) end)
  song:delete_instrument_at(at_index)
  if not ran then return false, name, 0, tostring(run_err) end
  return true, name, slice_count, nil
end

-- the selected instrument's Amigo. output_path is optional and skips the dialog.
function PakettiAmigoExportSelectedTo(target_key, output_path)
  local target = pakettiAmigoExportTargets[target_key]
  if not target then return end
  local device = PakettiAmigoFindDevice(renoise.song().selected_instrument)
  if not device then
    renoise.app():show_status("Amigo to " .. target.label ..
      ": select an instrument that has the Amigo plugin loaded.")
    return
  end
  -- ask for the filename here, on the main thread - a modal file dialog opened
  -- from inside the ProcessSlicer coroutine is asking for trouble
  local path = output_path
  if not path or path == "" then
    path = renoise.app():prompt_for_filename_to_write(target.extension or "wav",
      "Save Amigo as " .. target.label .. "...")
    if not path or path == "" then
      renoise.app():show_status("Amigo to " .. target.label .. ": cancelled.")
      return
    end
  end

  pakettiAmigoRunSliced("Amigo to " .. target.label .. "...", function(report)
    local ok, name, slice_count, err = pakettiAmigoExportDeviceVia(target, device, nil, {}, path, report)
    if not ok then
      if err ~= "cancelled" then
        renoise.app():show_status("Amigo to " .. target.label .. ": " .. tostring(err))
      end
      return
    end
    renoise.app():show_status("Amigo to " .. target.label .. ": " .. name ..
      " exported with " .. slice_count .. " slices")
  end)
end

-- every Amigo in the song. target_folder is optional and skips the dialog.
function PakettiAmigoBatchExportTo(target_key, target_folder)
  local target = pakettiAmigoExportTargets[target_key]
  if not target then return end
  local song = renoise.song()
  local devices, sources = {}, {}
  for i = 1, #song.instruments do
    local device = PakettiAmigoFindDevice(song.instruments[i])
    if device then
      devices[#devices + 1] = device
      sources[#sources + 1] = i
    end
  end
  if #devices == 0 then
    renoise.app():show_status("Amigo to " .. target.label ..
      ": this song has no instruments with the Amigo plugin.")
    return
  end

  local folder = target_folder
  if not folder or folder == "" then
    folder = renoise.app():prompt_for_path("Export every Amigo as " .. target.label .. " into...")
  end
  if not folder or folder == "" then
    renoise.app():show_status("Amigo to " .. target.label .. ": cancelled.")
    return
  end
  local separator = pakettiAmigoPathSeparator()
  if folder:sub(-1) ~= separator then folder = folder .. separator end

  pakettiAmigoRunSliced("Amigo to " .. target.label .. "...", function(report)
    local used, made, failed = {}, 0, {}
    for n = 1, #devices do
      report(string.format("Amigo %d/%d...", n, #devices))
      local ok, name, slice_count, err = pakettiAmigoExportDeviceVia(target, devices[n], folder, used,
        nil, function(text) report(string.format("Amigo %d/%d - %s", n, #devices, text)) end)
      if ok then
        made = made + 1
        print(string.format("PakettiAmigo: instrument %02X -> %s as %s (%d slices)",
          sources[n] - 1, name, target.label, slice_count))
      else
        failed[#failed + 1] = string.format("%02X (%s)", sources[n] - 1, tostring(err))
      end
      coroutine.yield()
    end

    local status = "Amigo to " .. target.label .. ": exported " .. made .. " of " ..
      #devices .. " Amigos into " .. folder
    if #failed > 0 then status = status .. " - skipped " .. table.concat(failed, ", ") end
    renoise.app():show_status(status)
    print("PakettiAmigo: " .. status)
  end)
end

function PakettiAmigoToOT(output_path) PakettiAmigoExportSelectedTo("ot", output_path) end
function PakettiAmigoToDigitakt(output_path) PakettiAmigoExportSelectedTo("digitakt", output_path) end
function PakettiAmigoToWavCue(output_path) PakettiAmigoExportSelectedTo("wavcue", output_path) end
function PakettiAmigoBatchAmigosToOT(folder) PakettiAmigoBatchExportTo("ot", folder) end
function PakettiAmigoBatchAmigosToDigitakt(folder) PakettiAmigoBatchExportTo("digitakt", folder) end
function PakettiAmigoBatchAmigosToWavCue(folder) PakettiAmigoBatchExportTo("wavcue", folder) end
function PakettiAmigoToPTI(output_path) PakettiAmigoExportSelectedTo("pti", output_path) end
function PakettiAmigoToITI(output_path) PakettiAmigoExportSelectedTo("iti", output_path) end
function PakettiAmigoBatchAmigosToPTI(folder) PakettiAmigoBatchExportTo("pti", folder) end
function PakettiAmigoBatchAmigosToITI(folder) PakettiAmigoBatchExportTo("iti", folder) end

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

PakettiAddMenuEntry{name = "Main Menu:Options:Sliced Imports Also Go Into Amigo (RX2, REX, PTI, ITI, OT, WAV+CUE) Toggle",
  invoke = function() PakettiAmigoToggleSlicedImport() end,
  selected = function() return PakettiAmigoSlicedImportEnabled() end}

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(2) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(4) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(8) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(16) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(32) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(64) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoToOT() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoBatchAmigosToOT() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoToDigitakt() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoBatchAmigosToDigitakt() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to WAV with CUE Header",
  invoke = function() PakettiAmigoToWavCue() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to WAV with CUE Header",
  invoke = function() PakettiAmigoBatchAmigosToWavCue() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoToPTI() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoBatchAmigosToPTI() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoToITI() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoBatchAmigosToITI() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Amigo to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoToOT() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Amigo in Song to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoBatchAmigosToOT() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Amigo to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoToDigitakt() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Amigo in Song to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoBatchAmigosToDigitakt() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Amigo to WAV with CUE Header",
  invoke = function() PakettiAmigoToWavCue() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Amigo in Song to WAV with CUE Header",
  invoke = function() PakettiAmigoBatchAmigosToWavCue() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Amigo to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoToPTI() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Amigo in Song to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoBatchAmigosToPTI() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Amigo to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoToITI() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Amigo in Song to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoBatchAmigosToITI() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(2) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(2) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(4) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(4) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(8) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(8) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(16) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(16) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(32) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(32) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Wipe&Slice&Amigo (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(64) end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Amigo:Wipe&Slice&Amigo (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(64) end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoToOT() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to Octatrack (.ot + .wav)",
  invoke = function() PakettiAmigoBatchAmigosToOT() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoToDigitakt() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to Digitakt Chain (.wav)",
  invoke = function() PakettiAmigoBatchAmigosToDigitakt() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to WAV with CUE Header",
  invoke = function() PakettiAmigoToWavCue() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to WAV with CUE Header",
  invoke = function() PakettiAmigoBatchAmigosToWavCue() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoToPTI() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to Polyend PTI (.pti)",
  invoke = function() PakettiAmigoBatchAmigosToPTI() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoToITI() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to Impulse Tracker ITI (.iti)",
  invoke = function() PakettiAmigoBatchAmigosToITI() end}

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Transient Slice & Amigo",
  invoke = function() PakettiAmigoTransientSliceAndAmigo() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (Quarter Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(0.25) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (Half Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(0.5) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (1 Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(1) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (2 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(2) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (4 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(4) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:BPM Slice & Amigo (8 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(8) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Print Amigo Slices to Pattern",
  invoke = function() PakettiAmigoPrintSlicesToPattern() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(2) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(4) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(8) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(16) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(32) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Wipe&Slice&Amigo&Print (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(64) end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Amigo to Renoise Drumkit (One-Shot per Slice)",
  invoke = function() PakettiAmigoToRenoiseDrumkit() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Renoise Drumkits",
  invoke = function() PakettiAmigoBatchAmigosToDrumkits() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Import Amigo as Renoise Drumkit (One-Shot per Slice)",
  invoke = function() PakettiAmigoToRenoiseDrumkit() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Amigo to Renoise Drumkit (One-Shot per Slice)",
  invoke = function() PakettiAmigoToRenoiseDrumkit() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Amigo in Song to Renoise Instruments",
  invoke = function() PakettiAmigoBatchAmigosToRenoise() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:Amigo:Batch: Every Sampled Instrument in Song to Amigo",
  invoke = function() PakettiAmigoBatchInstrumentsToAmigo() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Import Every Amigo in Song to Renoise Instruments",
  invoke = function() PakettiAmigoBatchAmigosToRenoise() end}
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Every Sampled Instrument in Song to Amigo",
  invoke = function() PakettiAmigoBatchInstrumentsToAmigo() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Amigo in Song to Renoise Instruments",
  invoke = function() PakettiAmigoBatchAmigosToRenoise() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Amigo:Batch: Every Sampled Instrument in Song to Amigo",
  invoke = function() PakettiAmigoBatchInstrumentsToAmigo() end}

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
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(2) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(4) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(8) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(16) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(32) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigo(64) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Octatrack ot and wav",
  invoke = function() PakettiAmigoToOT() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Octatrack ot and wav",
  invoke = function() PakettiAmigoBatchAmigosToOT() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Digitakt Chain",
  invoke = function() PakettiAmigoToDigitakt() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Digitakt Chain",
  invoke = function() PakettiAmigoBatchAmigosToDigitakt() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to WAV with CUE Header",
  invoke = function() PakettiAmigoToWavCue() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to WAV with CUE Header",
  invoke = function() PakettiAmigoBatchAmigosToWavCue() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Polyend PTI",
  invoke = function() PakettiAmigoToPTI() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Polyend PTI",
  invoke = function() PakettiAmigoBatchAmigosToPTI() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Impulse Tracker ITI",
  invoke = function() PakettiAmigoToITI() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Impulse Tracker ITI",
  invoke = function() PakettiAmigoBatchAmigosToITI() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Transient Slice and Amigo",
  invoke = function() PakettiAmigoTransientSliceAndAmigo() end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (Quarter Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(0.25) end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (Half Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(0.5) end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (1 Beat)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(1) end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (2 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(2) end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (4 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(4) end}
renoise.tool():add_keybinding{name = "Global:Paketti:BPM Slice and Amigo (8 Beats)",
  invoke = function() PakettiAmigoBPMSliceAndAmigo(8) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Print Amigo Slices to Pattern",
  invoke = function() PakettiAmigoPrintSlicesToPattern() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (002)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(2) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (004)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(4) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (008)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(8) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (016)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(16) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (032)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(32) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Wipe&Slice&Amigo&Print (064)",
  invoke = function() PakettiAmigoWipeSliceAndAmigoAndPrint(64) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Renoise Drumkit One-Shot per Slice",
  invoke = function() PakettiAmigoToRenoiseDrumkit() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Renoise Drumkits",
  invoke = function() PakettiAmigoBatchAmigosToDrumkits() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Amigo in Song to Renoise Instruments",
  invoke = function() PakettiAmigoBatchAmigosToRenoise() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Batch Every Sampled Instrument in Song to Amigo",
  invoke = function() PakettiAmigoBatchInstrumentsToAmigo() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Renoise to Amigo Selected Sample",
  invoke = function() PakettiAmigoRenoiseToAmigo() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Renoise to Amigo Selected Sample Embedded",
  invoke = function() PakettiAmigoRenoiseToAmigoEmbedded() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Amigo to Renoise New Instrument",
  invoke = function() PakettiAmigoAmigoToRenoise() end}

renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (002)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(2) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (004)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(4) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (008)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(8) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (016)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(16) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (032)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(32) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Wipe&Slice&Amigo (064)",
  invoke = function(message) if message:is_trigger() then PakettiAmigoWipeSliceAndAmigo(64) end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Octatrack ot and wav",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToOT() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Digitakt Chain",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToDigitakt() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to WAV with CUE Header",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToWavCue() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Polyend PTI",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToPTI() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Impulse Tracker ITI",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToITI() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Transient Slice and Amigo",
  invoke = function(message) if message:is_trigger() then PakettiAmigoTransientSliceAndAmigo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Print Amigo Slices to Pattern",
  invoke = function(message) if message:is_trigger() then PakettiAmigoPrintSlicesToPattern() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Renoise Drumkit One-Shot per Slice",
  invoke = function(message) if message:is_trigger() then PakettiAmigoToRenoiseDrumkit() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Batch Every Amigo in Song to Renoise Instruments",
  invoke = function(message) if message:is_trigger() then PakettiAmigoBatchAmigosToRenoise() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Batch Every Sampled Instrument in Song to Amigo",
  invoke = function(message) if message:is_trigger() then PakettiAmigoBatchInstrumentsToAmigo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Renoise to Amigo Selected Sample",
  invoke = function(message) if message:is_trigger() then PakettiAmigoRenoiseToAmigo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Amigo to Renoise New Instrument",
  invoke = function(message) if message:is_trigger() then PakettiAmigoAmigoToRenoise() end end}
