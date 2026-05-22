-- PakettiHack.lua
-- XRNI XML roundtrip to bypass Renoise UI clamps.
-- Currently: BeatSyncLines beyond the 1-512 API range (XML accepts 8192, 16384, 32768, ...).
-- Pipeline: save_instrument -> unzip Instrument.xml -> patch -> zip update -> load_instrument.

local function paketti_hack_run_shell(cmd)
  local handle = io.popen(cmd .. " 2>&1; echo __RC__$?")
  if not handle then return false, "io.popen failed" end
  local out = handle:read("*a") or ""
  handle:close()
  local rc = out:match("__RC__(%d+)%s*$")
  out = out:gsub("__RC__%d+%s*$", "")
  return rc == "0", out
end

local function paketti_hack_set_beatsync_lines(target_lines)
  if os.platform() == "WINDOWS" then
    renoise.app():show_status("PakettiHack: shell zip/unzip not wired for Windows yet")
    return
  end

  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr or #instr.samples == 0 then
    renoise.app():show_status("PakettiHack: no instrument/sample selected")
    return
  end
  local sample_idx = song.selected_sample_index
  if sample_idx < 1 then sample_idx = 1 end
  local sample = instr.samples[sample_idx]

  if type(target_lines) ~= "number" or target_lines < 1 or target_lines > 65535 then
    renoise.app():show_status("PakettiHack: target_lines out of range (1-65535)")
    return
  end
  target_lines = math.floor(target_lines)

  -- Force BeatSync on so the patched value has effect when reloaded
  if sample.beat_sync_enabled == false then
    sample.beat_sync_enabled = true
  end

  local instr_name = instr.name
  local sel_inst_idx = song.selected_instrument_index
  local sel_sample_idx = sample_idx

  local t0 = os.clock()
  local tmp_xrni = os.tmpname() .. ".xrni"
  local tmp_dir = tmp_xrni .. ".d"
  os.mkdir(tmp_dir)

  renoise.app():save_instrument(tmp_xrni)
  local t_saved = os.clock()

  local ok, err = paketti_hack_run_shell(string.format(
    'unzip -o -j %q Instrument.xml -d %q', tmp_xrni, tmp_dir))
  if not ok then
    renoise.app():show_status("PakettiHack: unzip failed - " .. tostring(err))
    return
  end
  local xml_path = tmp_dir .. "/Instrument.xml"

  local f = io.open(xml_path, "rb")
  if not f then renoise.app():show_status("PakettiHack: cannot read extracted XML") return end
  local xml = f:read("*a"); f:close()

  local count = 0
  local patched = false
  xml = xml:gsub("(<BeatSyncLines>)(%-?%d+)(</BeatSyncLines>)", function(open_tag, val, close_tag)
    count = count + 1
    if count == sel_sample_idx then
      patched = true
      return open_tag .. tostring(target_lines) .. close_tag
    end
    return open_tag .. val .. close_tag
  end)

  if not patched then
    renoise.app():show_status(string.format(
      "PakettiHack: no <BeatSyncLines> tag for sample %d (only %d found)", sel_sample_idx, count))
    return
  end

  local fo = io.open(xml_path, "wb")
  if not fo then renoise.app():show_status("PakettiHack: cannot write XML") return end
  fo:write(xml); fo:close()

  ok, err = paketti_hack_run_shell(string.format(
    'cd %q && zip -q %q Instrument.xml', tmp_dir, tmp_xrni))
  if not ok then
    renoise.app():show_status("PakettiHack: zip update failed - " .. tostring(err))
    return
  end

  renoise.app():load_instrument(tmp_xrni)
  local t_loaded = os.clock()

  -- Restore name + selection (load_instrument can rename based on filename)
  local reloaded = song.instruments[sel_inst_idx]
  if reloaded then
    reloaded.name = instr_name
  end
  song.selected_instrument_index = sel_inst_idx
  if sel_sample_idx <= #song.selected_instrument.samples then
    song.selected_sample_index = sel_sample_idx
  end

  -- Best-effort cleanup
  os.remove(xml_path)
  os.remove(tmp_xrni)

  renoise.app():show_status(string.format(
    "PakettiHack: BeatSyncLines=%d on sample %d (save %.0fms + load %.0fms = %.0fms)",
    target_lines, sel_sample_idx,
    (t_saved - t0) * 1000,
    (t_loaded - t_saved) * 1000,
    (t_loaded - t0) * 1000))
end

local paketti_hack_dialog = nil

function pakettiBeatSyncHackDialog()
  if paketti_hack_dialog and paketti_hack_dialog.visible then
    paketti_hack_dialog:close()
    paketti_hack_dialog = nil
    return
  end
  local vb = renoise.ViewBuilder()
  local value_view = vb:valuebox{min = 1, max = 65535, value = 8192, width = 100}
  local content = vb:column{
    margin = 8, spacing = 6,
    vb:text{
      style = "strong", font = "bold",
      text = "DO NOT SAVE THESE SONGS AS XRNS"
    },
    vb:text{
      style = "strong", font = "bold",
      text = "WITHOUT SETTING BEATSYNC BACK TO <512"
    },
    vb:text{text = "BeatSyncLines (1 - 65535). UI normally caps at 512."},
    vb:row{
      spacing = 4,
      vb:text{text = "Lines:", width = 50},
      value_view
    },
    vb:row{
      spacing = 4,
      vb:button{text = "1024", notifier = function() paketti_hack_set_beatsync_lines(1024) end},
      vb:button{text = "2048", notifier = function() paketti_hack_set_beatsync_lines(2048) end},
      vb:button{text = "4096", notifier = function() paketti_hack_set_beatsync_lines(4096) end},
      vb:button{text = "8192", notifier = function() paketti_hack_set_beatsync_lines(8192) end},
      vb:button{text = "16384", notifier = function() paketti_hack_set_beatsync_lines(16384) end},
      vb:button{text = "32768", notifier = function() paketti_hack_set_beatsync_lines(32768) end},
    },
    vb:button{
      text = "Apply Custom Value",
      notifier = function()
        paketti_hack_set_beatsync_lines(value_view.value)
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      end
    }
  }
  paketti_hack_dialog = renoise.app():show_custom_dialog("Paketti BeatSyncHack Dialog", content)
end

local presets = {1024, 2048, 4096, 8192, 16384, 32768}
for _, n in ipairs(presets) do
  local label = string.format("%05d", n)
  PakettiAddMenuEntry{
    name = "Main Menu:Tools:Paketti:Xperimental/WIP:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  PakettiAddMenuEntry{
    name = "Sample Editor:Paketti:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  PakettiAddMenuEntry{
    name = "Instrument Box:Paketti:BeatSyncHack:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Set BeatSyncLines " .. label,
    invoke = function() paketti_hack_set_beatsync_lines(n) end
  }
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Xperimental/WIP:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:BeatSyncHack:Set BeatSyncLines Dialog...",
  invoke = pakettiBeatSyncHackDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Set BeatSyncLines Dialog",
  invoke = pakettiBeatSyncHackDialog
}
