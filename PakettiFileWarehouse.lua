-- PakettiFileWarehouse.lua
-- A canvas-rendered file *system* inside Renoise: stand in a folder, see its
-- files/subfolders as clickable nodes, navigate with history, and (toggle on)
-- see the architectural connections BETWEEN files drawn as edges.
--
-- Phase 1   : folder browsing on canvas + history (back/forward/up) + selection.
-- Phase 1.5 : local, free "connections" — edge A->B when file A's head mentions
--             file B's name. The edge source is factored into fw_compute_edges so
--             Phase 2 can swap it for an MLX-over-Convey graph with no renderer change.
-- Phase 3   : per-file history (git) — scaffolded as fw_file_history(), unused yet.
--
-- FEATURE-CARD >> features/file-warehouse.feature   (to be written)

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local fw_dialog = nil
local fw_canvas = nil
local fw_vb = nil
local fw_scrollbar = nil
local fw_updating_scrollbar = false

local fw_current_path = nil
local fw_history  = {}   -- back stack of paths
local fw_forward  = {}   -- forward stack of paths
local fw_entries  = {}   -- { {name=, kind="dir"|"file", path=, ext=, size=}, ... }
local fw_nodes    = {}   -- layout: { {entry=, x=, y=, w=, h=, cx=, cy=}, ... }
local fw_edges    = {}   -- { {from=<node idx>, to=<node idx>}, ... }
local fw_hover    = nil  -- hovered node index
local fw_selected = nil  -- selected node index
local fw_scroll   = 0    -- vertical scroll, in rows
local fw_connections_on = false

-- Music-graph mode: bipartite "which songs use which sample" view, built by
-- probing each .xrns in the folder via PakettiXRNSProbeExtractManifest (XRNSProbe
-- reads Song.xml WITHOUT loading the song). fw_mode = "files" | "music".
local fw_mode = "files"
local fw_manifest_cache = {}   -- [xrns_path] = manifest
local fw_m_songs = {}          -- { {label=, path=, keys={k,...}, x,y,w,h,cx,cy}, ... }
local fw_m_samples = {}        -- { {label=, key=, is_file=, songs={song_idx,...}, x,y,w,h,cx,cy}, ... }
local fw_m_sample_idx = {}     -- key -> index into fw_m_samples
local fw_m_sel_song = nil      -- focused song index (collapses view to its samples)
local fw_m_sel_sample = nil    -- focused sample index (collapses view to its songs)
local fw_m_drag = nil          -- {y=, scroll=, moved=} drag-to-pan state
local fw_mode_button = nil
local FW_MUSIC_MAX_XRNS = 120  -- safety cap on songs probed per folder

local fw_path_text   = nil  -- vb text view (breadcrumb)
local fw_status_text = nil  -- vb text view (selected-file info)
local fw_conn_button = nil  -- vb button (connections toggle)

--------------------------------------------------------------------------------
-- Layout / theme constants
--------------------------------------------------------------------------------
local FW_W        = 940
local FW_H        = 560
local FW_MARGIN   = 14
local FW_NODE_W   = 150
local FW_NODE_H   = 54
local FW_GAP_X    = 14
local FW_GAP_Y    = 14
local FW_LABEL_SZ = 6
local FW_SUB_SZ   = 5

local FW_C = {
  bg       = {18, 19, 22},
  dir      = {54, 78, 120},
  dir_hi   = {78, 110, 165},
  file     = {44, 46, 52},
  file_hi  = {70, 74, 84},
  sel      = {210, 160, 60},
  border   = {90, 94, 104},
  text     = {225, 228, 235},
  subtext  = {150, 156, 168},
  edge     = {120, 150, 200, 90},
}

local FW_MAX_EDGE_FILES = 60   -- safety cap for local connection scan
local FW_EDGE_HEAD_BYTES = 8192

--------------------------------------------------------------------------------
-- Path / fs helpers
--------------------------------------------------------------------------------
local function fw_basename(p)
  return (p:match("[^/]+$")) or p
end

local function fw_stem(name)
  return (name:gsub("%.[^.]+$", ""))
end

local function fw_ext(name)
  return (name:match("%.([^.]+)$") or ""):lower()
end

local function fw_join(dir, name)
  if dir == "/" then return "/" .. name end
  return dir .. "/" .. name
end

local function fw_parent(dir)
  if dir == "/" or not dir:find("/") then return "/" end
  local p = dir:gsub("/[^/]+$", "")
  if p == "" then return "/" end
  return p
end

local FW_TEXT_EXTS = { lua=true, txt=true, md=true, xml=true, json=true,
  c=true, h=true, cpp=true, py=true, js=true, ts=true, html=true, css=true,
  cfg=true, ini=true, yaml=true, yml=true, sh=true, asm=true, inc=true }

local function fw_is_text(ext) return FW_TEXT_EXTS[ext] == true end

local function fw_read_head(path, max)
  local ok, f = pcall(io.open, path, "r")
  if not ok or not f then return "" end
  local data = f:read(max or FW_EDGE_HEAD_BYTES) or ""
  f:close()
  return data
end

local function fw_size_str(n)
  if not n then return "" end
  if n < 1024 then return string.format("%dB", n) end
  if n < 1024*1024 then return string.format("%.0fK", n/1024) end
  return string.format("%.1fM", n/(1024*1024))
end

--------------------------------------------------------------------------------
-- Scan a folder into fw_entries
--------------------------------------------------------------------------------
local function fw_scan(path)
  fw_entries = {}
  fw_selected = nil
  fw_hover = nil
  fw_scroll = 0
  fw_edges = {}

  -- Parent entry (unless at root)
  if path ~= "/" then
    fw_entries[#fw_entries+1] = { name = "..", kind = "dir", path = fw_parent(path), ext = "" }
  end

  local ok_d, dirs = pcall(os.dirnames, path)
  if ok_d and dirs then
    table.sort(dirs, function(a,b) return a:lower() < b:lower() end)
    for _, d in ipairs(dirs) do
      local nm = fw_basename(d)
      if nm ~= "." and nm ~= ".." then
        fw_entries[#fw_entries+1] = { name = nm, kind = "dir", path = fw_join(path, nm), ext = "" }
      end
    end
  end

  local ok_f, files = pcall(os.filenames, path)
  if ok_f and files then
    table.sort(files, function(a,b) return a:lower() < b:lower() end)
    for _, fn in ipairs(files) do
      local nm = fw_basename(fn)
      local fp = fw_join(path, nm)
      local size = nil
      local ok_s, st = pcall(io.stat, fp)
      if ok_s and st then size = st.size end
      fw_entries[#fw_entries+1] = { name = nm, kind = "file", path = fp, ext = fw_ext(nm), size = size }
    end
  end
end

--------------------------------------------------------------------------------
-- Edge computation (Phase 1.5: local, free). Returns { {from=,to=}, ... } over
-- the CURRENT fw_entries node indices. Phase 2 swaps the body for an MLX call.
--------------------------------------------------------------------------------
function fw_compute_edges()
  local edges = {}
  -- gather text-file entries by node index
  local text_idx = {}
  for i, e in ipairs(fw_entries) do
    if e.kind == "file" and fw_is_text(e.ext) then text_idx[#text_idx+1] = i end
  end
  if #text_idx == 0 or #text_idx > FW_MAX_EDGE_FILES then return edges end

  -- read heads + precompute stems
  local heads, stems = {}, {}
  for _, i in ipairs(text_idx) do
    heads[i] = fw_read_head(fw_entries[i].path)
    stems[i] = fw_stem(fw_entries[i].name)
  end

  for _, a in ipairs(text_idx) do
    local head = heads[a]
    for _, b in ipairs(text_idx) do
      if a ~= b then
        local stem = stems[b]
        if stem and #stem > 3 and head:find(stem, 1, true) then
          edges[#edges+1] = { from = a, to = b }
        end
      end
    end
  end
  return edges
end

-- Phase 3 scaffold: a file's history (git log) — not wired into the UI yet.
function fw_file_history(path)  -- luacheck: ignore
  return {}
end

--------------------------------------------------------------------------------
-- MUSIC GRAPH: "which songs use which sample", built by probing each .xrns in the
-- folder with XRNSProbe (reads Song.xml without loading the song).
--------------------------------------------------------------------------------
local function fw_truncate(text, avail_w, size)
  local per = size * 1.4
  local maxc = math.floor(avail_w / per)
  if maxc < 1 then maxc = 1 end
  if #text <= maxc then return text end
  if maxc <= 1 then return text:sub(1, 1) end
  return text:sub(1, maxc - 1) .. "…"
end

-- The canvas font draws glyphs with ctx:stroke(), so the TEXT color is the
-- STROKE color, not the fill color. Always set stroke_color here, or labels
-- inherit whatever stroke (e.g. a node border) was last used = unreadable.
local function fw_text(ctx, color, s, x, y, size)
  ctx.fill_color = color
  ctx.stroke_color = color
  ctx.line_width = 1
  PakettiCanvasFontDrawText(ctx, s, x, y, size)
end

local FW_AUDIO_EXTS = { wav=true, aif=true, aiff=true, flac=true, ogg=true, mp3=true, iff=true }

local function fw_norm_key(name) return name:lower() end

local function fw_build_music_graph()
  fw_m_songs = {}; fw_m_samples = {}; fw_m_sample_idx = {}
  fw_m_sel_song = nil; fw_m_sel_sample = nil; fw_scroll = 0

  local function ensure_sample(key, label, is_file)
    local idx = fw_m_sample_idx[key]
    if idx then
      if is_file then fw_m_samples[idx].is_file = true end
      return idx
    end
    fw_m_samples[#fw_m_samples+1] = { label = label, key = key, is_file = is_file or false, songs = {} }
    fw_m_sample_idx[key] = #fw_m_samples
    return #fw_m_samples
  end

  -- loose audio files in the folder become sample nodes (real, on-disk)
  for _, e in ipairs(fw_entries) do
    if e.kind == "file" and FW_AUDIO_EXTS[e.ext] then
      ensure_sample(fw_norm_key(e.name), e.name, true)
    end
  end

  -- probe each .xrns and wire song -> sample edges
  local count = 0
  for _, e in ipairs(fw_entries) do
    if e.kind == "file" and e.ext == "xrns" and count < FW_MUSIC_MAX_XRNS then
      count = count + 1
      local man = fw_manifest_cache[e.path]
      if not man then
        if type(PakettiXRNSProbeExtractManifest) == "function" then
          local ok, res = pcall(PakettiXRNSProbeExtractManifest, e.path)
          man = ok and res or { ok = false, samples = {} }
        else
          man = { ok = false, samples = {} }
        end
        fw_manifest_cache[e.path] = man
      end
      fw_m_songs[#fw_m_songs+1] = { label = e.name, path = e.path, keys = {} }
      local sidx = #fw_m_songs
      local song = fw_m_songs[sidx]
      if man and man.ok then
        local seen = {}
        for _, s in ipairs(man.samples) do
          local key = s.file and fw_norm_key(s.file) or ("name:" .. fw_norm_key(s.name or "?"))
          if not seen[key] then
            seen[key] = true
            local samp_i = ensure_sample(key, s.file or s.name or "?", false)
            song.keys[#song.keys+1] = samp_i
            local songs = fw_m_samples[samp_i].songs
            songs[#songs+1] = sidx
          end
        end
      end
    end
  end
end

local FW_M_NODE_W = 240
local FW_M_NODE_H = 22
local FW_M_GAP    = 5

local function fw_layout_music()
  local left_x  = FW_MARGIN
  local right_x = FW_W - FW_MARGIN - FW_M_NODE_W

  local function place(n, x, row)
    n.x = x; n.w = FW_M_NODE_W; n.h = FW_M_NODE_H
    n.y = FW_MARGIN + (row - fw_scroll) * (FW_M_NODE_H + FW_M_GAP)
    n.cx = (x == left_x) and (x + FW_M_NODE_W) or x
    n.cy = n.y + FW_M_NODE_H/2
  end
  local function hide(n) n.x = nil; n.y = nil; n.cx = nil; n.cy = nil end

  if fw_m_sel_sample then
    -- collapse: only the focused sample (right) + the songs that use it (left)
    local samp = fw_m_samples[fw_m_sel_sample]
    local using = {}
    for _, si in ipairs(samp.songs) do using[si] = true end
    for i, s in ipairs(fw_m_samples) do if i == fw_m_sel_sample then place(s, right_x, 0) else hide(s) end end
    local row = 0
    for i, s in ipairs(fw_m_songs) do
      if using[i] then place(s, left_x, row); row = row + 1 else hide(s) end
    end
  elseif fw_m_sel_song then
    -- collapse: only the focused song (left) + the samples it uses (right)
    local song = fw_m_songs[fw_m_sel_song]
    local uses = {}
    for _, k in ipairs(song.keys) do uses[k] = true end
    for i, s in ipairs(fw_m_songs) do if i == fw_m_sel_song then place(s, left_x, 0) else hide(s) end end
    local row = 0
    for i, s in ipairs(fw_m_samples) do
      if uses[i] then place(s, right_x, row); row = row + 1 else hide(s) end
    end
  else
    -- full bipartite view
    for i, s in ipairs(fw_m_songs)   do place(s, left_x,  i - 1) end
    for i, s in ipairs(fw_m_samples) do place(s, right_x, i - 1) end
  end
end

local FW_MC = {
  song = {60,70,95}, samp = {48,78,58}, samp_file = {64,104,74},
  hi = {232,180,70}, dim = {38,40,46},
  edge = {110,140,190,70}, edge_hi = {235,200,110,210}, text = {225,228,235},
}

-- In collapsed (focus) mode only connected nodes are laid out at all, so the
-- only thing to highlight is the node you actually clicked. true = the clicked
-- node (gold), nil = normal. (No "dim in place" — the collapse IS the filter.)
local function fw_song_active(i)
  return (fw_m_sel_song and i == fw_m_sel_song) and true or nil
end
local function fw_sample_active(i)
  return (fw_m_sel_sample and i == fw_m_sel_sample) and true or nil
end

local function fw_render_music(ctx)
  ctx:clear_rect(0, 0, FW_W, FW_H)
  ctx.fill_color = FW_C.bg
  ctx:fill_rect(0, 0, FW_W, FW_H)

  if #fw_m_songs == 0 and #fw_m_samples == 0 then
    fw_text(ctx, FW_C.subtext, "NO .XRNS SONGS IN THIS FOLDER", FW_MARGIN, FW_MARGIN + 6, 7)
    return
  end

  -- edges — only when focused (full view of all edges is an unreadable hairball,
  -- and redrawing thousands of lines on every drag is slow). In focus mode only
  -- the connected nodes are laid out, so this draws a clean star.
  if fw_m_sel_song or fw_m_sel_sample then
    ctx.stroke_color = FW_MC.edge_hi
    ctx.line_width = 2
    for _, song in ipairs(fw_m_songs) do
      for _, sampi in ipairs(song.keys) do
        local samp = fw_m_samples[sampi]
        if song.cy and samp.cy then
          ctx:begin_path(); ctx:move_to(song.cx, song.cy); ctx:line_to(samp.cx, samp.cy); ctx:stroke()
        end
      end
    end
  end

  local function draw_node(n, base, active, label)
    if not n.y or n.y + n.h < 0 or n.y > FW_H then return end
    local fill = base
    if active == true then fill = FW_MC.hi elseif active == false then fill = FW_MC.dim end
    ctx.fill_color = fill
    ctx:fill_rect(n.x, n.y, n.w, n.h)
    ctx.stroke_color = FW_C.border; ctx.line_width = 1
    ctx:stroke_rect(n.x, n.y, n.w, n.h)
    local txt = (active == true) and FW_C.bg or FW_MC.text
    fw_text(ctx, txt, fw_truncate(label, n.w - 10, 6), n.x + 5, n.y + 7, 6)
  end

  for i, s in ipairs(fw_m_songs) do draw_node(s, FW_MC.song, fw_song_active(i), s.label) end
  for i, s in ipairs(fw_m_samples) do
    draw_node(s, s.is_file and FW_MC.samp_file or FW_MC.samp, fw_sample_active(i),
      (s.is_file and "● " or "") .. s.label)
  end
end

local function fw_hit_music(x, y)
  for i, s in ipairs(fw_m_songs) do
    if s.x and x >= s.x and x <= s.x + s.w and y >= s.y and y <= s.y + s.h then return "song", i end
  end
  for i, s in ipairs(fw_m_samples) do
    if s.x and x >= s.x and x <= s.x + s.w and y >= s.y and y <= s.y + s.h then return "sample", i end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Layout entries into a scrollable grid of nodes
--------------------------------------------------------------------------------
local function fw_cols()
  local avail = FW_W - 2*FW_MARGIN + FW_GAP_X
  local c = math.floor(avail / (FW_NODE_W + FW_GAP_X))
  if c < 1 then c = 1 end
  return c
end

local function fw_layout()
  fw_nodes = {}
  local cols = fw_cols()
  for i, e in ipairs(fw_entries) do
    local idx0 = i - 1
    local col = idx0 % cols
    local row = math.floor(idx0 / cols)
    local x = FW_MARGIN + col * (FW_NODE_W + FW_GAP_X)
    local y = FW_MARGIN + (row - fw_scroll) * (FW_NODE_H + FW_GAP_Y)
    fw_nodes[i] = { entry = e, x = x, y = y, w = FW_NODE_W, h = FW_NODE_H,
                    cx = x + FW_NODE_W/2, cy = y + FW_NODE_H/2 }
  end
end

-- Mode-aware scroll metrics: how many content rows exist and how many fit.
local function fw_scroll_metrics()
  if fw_mode == "music" then
    local total
    if fw_m_sel_sample then total = #fw_m_samples[fw_m_sel_sample].songs
    elseif fw_m_sel_song then total = #fw_m_songs[fw_m_sel_song].keys
    else total = math.max(#fw_m_songs, #fw_m_samples) end
    if total < 1 then total = 1 end
    local visible = math.floor((FW_H - 2*FW_MARGIN) / (FW_M_NODE_H + FW_M_GAP))
    return total, visible
  end
  local cols = fw_cols()
  local total = math.ceil(#fw_entries / cols)
  local visible = math.floor((FW_H - 2*FW_MARGIN) / (FW_NODE_H + FW_GAP_Y))
  return total, visible
end

local function fw_max_scroll()
  local total, visible = fw_scroll_metrics()
  local m = total - visible
  if m < 0 then m = 0 end
  return m
end

-- Push current scroll metrics into the scrollbar widget (guarded against the
-- notifier feedback loop). Called after any content/layout change.
local function fw_sync_scrollbar()
  if not fw_scrollbar then return end
  local total, visible = fw_scroll_metrics()
  if total < 1 then total = 1 end
  if visible < 1 then visible = 1 end
  local page = math.min(visible, total)
  local maxv = total - page
  if fw_scroll > maxv then fw_scroll = maxv end
  if fw_scroll < 0 then fw_scroll = 0 end
  -- Order matters: Renoise validates pagestep against the CURRENT max, and value
  -- against max-pagestep. Shrink to safe values first, then grow into the new
  -- range, so no intermediate assignment is ever out of range.
  fw_updating_scrollbar = true
  fw_scrollbar.min = 0
  fw_scrollbar.pagestep = 1
  fw_scrollbar.value = 0
  fw_scrollbar.max = total
  fw_scrollbar.pagestep = page
  fw_scrollbar.value = fw_scroll
  fw_updating_scrollbar = false
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------
local function fw_render(ctx)
  if fw_mode == "music" then return fw_render_music(ctx) end
  ctx:clear_rect(0, 0, FW_W, FW_H)
  ctx.fill_color = FW_C.bg
  ctx:fill_rect(0, 0, FW_W, FW_H)

  -- edges first (under nodes)
  if fw_connections_on and #fw_edges > 0 then
    ctx.stroke_color = FW_C.edge
    ctx.line_width = 1
    for _, ed in ipairs(fw_edges) do
      local a, b = fw_nodes[ed.from], fw_nodes[ed.to]
      if a and b then
        ctx:begin_path()
        ctx:move_to(a.cx, a.cy)
        ctx:line_to(b.cx, b.cy)
        ctx:stroke()
      end
    end
  end

  for i, n in ipairs(fw_nodes) do
    -- cull off-canvas
    if n.y + n.h > 0 and n.y < FW_H then
      local e = n.entry
      local is_dir = (e.kind == "dir")
      local fill
      if i == fw_selected then fill = FW_C.sel
      elseif is_dir then fill = (i == fw_hover) and FW_C.dir_hi or FW_C.dir
      else fill = (i == fw_hover) and FW_C.file_hi or FW_C.file end
      ctx.fill_color = fill
      ctx:fill_rect(n.x, n.y, n.w, n.h)
      ctx.stroke_color = FW_C.border
      ctx.line_width = 1
      ctx:stroke_rect(n.x, n.y, n.w, n.h)

      -- name
      local name_col = (i == fw_selected) and FW_C.bg or FW_C.text
      fw_text(ctx, name_col, fw_truncate(e.name, n.w - 12, FW_LABEL_SZ), n.x + 6, n.y + 10, FW_LABEL_SZ)

      -- subtitle: DIR / ext / size
      local sub
      if e.name == ".." then sub = "PARENT"
      elseif is_dir then sub = "DIR"
      else sub = (e.ext ~= "" and ("." .. e.ext) or "FILE") .. "  " .. fw_size_str(e.size) end
      local sub_col = (i == fw_selected) and FW_C.bg or FW_C.subtext
      fw_text(ctx, sub_col, sub, n.x + 6, n.y + 34, FW_SUB_SZ)
    end
  end
end

--------------------------------------------------------------------------------
-- Hit-test + mouse
--------------------------------------------------------------------------------
local function fw_hit_test(x, y)
  for i, n in ipairs(fw_nodes) do
    if x >= n.x and x <= n.x + n.w and y >= n.y and y <= n.y + n.h then
      return i
    end
  end
  return nil
end

local function fw_refresh_canvas()
  if fw_mode == "music" then fw_layout_music() else fw_layout() end
  fw_sync_scrollbar()
  if fw_canvas then fw_canvas:update() end
end

-- forward declaration
local fw_navigate

local function fw_handle_mouse(ev)
  if ev.type == "exit" then
    fw_m_drag = nil
    if fw_hover ~= nil then fw_hover = nil; fw_refresh_canvas() end
    return
  end
  if not ev.position then return end
  local x, y = ev.position.x, ev.position.y

  if fw_mode == "music" then
    if ev.type == "down" then
      fw_m_drag = { y = y, scroll = fw_scroll, moved = false }
      return
    elseif ev.type == "move" then
      if fw_m_drag then
        local dy = y - fw_m_drag.y
        if math.abs(dy) > 4 then
          fw_m_drag.moved = true
          local rowh = FW_M_NODE_H + FW_M_GAP
          fw_scroll = fw_m_drag.scroll - dy / rowh
          local maxs = fw_max_scroll()
          if fw_scroll < 0 then fw_scroll = 0 end
          if fw_scroll > maxs then fw_scroll = maxs end
          fw_layout_music(); fw_sync_scrollbar()
          if fw_canvas then fw_canvas:update() end
        end
      end
      return
    elseif ev.type ~= "up" then
      return
    end
    -- mouse "up": a click only if we didn't drag
    local was_click = fw_m_drag and not fw_m_drag.moved
    fw_m_drag = nil
    if not was_click then return end

    local kind, idx = fw_hit_music(x, y)
    fw_scroll = 0  -- collapse/restore always resets scroll to the top
    if kind == "song" then
      fw_m_sel_song = (fw_m_sel_song == idx) and nil or idx
      fw_m_sel_sample = nil
      if fw_m_sel_song and fw_status_text then
        fw_status_text.text = string.format("Song '%s' uses %d samples — showing only those",
          fw_m_songs[idx].label, #fw_m_songs[idx].keys)
      end
    elseif kind == "sample" then
      fw_m_sel_sample = (fw_m_sel_sample == idx) and nil or idx
      fw_m_sel_song = nil
      if fw_m_sel_sample and fw_status_text then
        local s = fw_m_samples[idx]
        fw_status_text.text = string.format("Sample '%s' used by %d song(s) — showing only those",
          s.label, #s.songs)
      end
    else
      fw_m_sel_song = nil; fw_m_sel_sample = nil
      if fw_status_text then
        fw_status_text.text = string.format("Music graph: %d songs, %d samples (click to focus, drag to pan)",
          #fw_m_songs, #fw_m_samples)
      end
    end
    fw_refresh_canvas()
    return
  end

  if ev.type == "move" then
    local h = fw_hit_test(x, y)
    if h ~= fw_hover then fw_hover = h; fw_refresh_canvas() end
    return
  end

  if ev.type == "down" then
    local h = fw_hit_test(x, y)
    if not h then return end
    local e = fw_nodes[h].entry
    if e.kind == "dir" then
      fw_navigate(e.path, true)
    else
      fw_selected = h
      local info = string.format("%s   %s   %s", e.name,
        (e.ext ~= "" and ("." .. e.ext) or "file"), fw_size_str(e.size))
      if fw_status_text then fw_status_text.text = "Selected: " .. info end
      renoise.app():show_status("File Warehouse: " .. e.path)
      fw_refresh_canvas()
    end
  end
end

--------------------------------------------------------------------------------
-- Navigation + history
--------------------------------------------------------------------------------
local function fw_after_navigate()
  fw_scan(fw_current_path)
  if fw_connections_on then fw_edges = fw_compute_edges() else fw_edges = {} end
  if fw_path_text then fw_path_text.text = fw_current_path end
  if fw_mode == "music" then
    fw_build_music_graph()
    if fw_status_text then
      fw_status_text.text = string.format("Music graph: %d songs, %d samples",
        #fw_m_songs, #fw_m_samples)
    end
  else
    if fw_status_text then fw_status_text.text = string.format("%d items", #fw_entries) end
  end
  fw_refresh_canvas()
end

-- record_history=true pushes the old path onto the back stack (a user-driven move)
fw_navigate = function(path, record_history)
  if not path then return end
  if record_history and fw_current_path and fw_current_path ~= path then
    fw_history[#fw_history+1] = fw_current_path
    fw_forward = {}
  end
  fw_current_path = path
  fw_after_navigate()
end

local function fw_go_back()
  if #fw_history == 0 then return end
  local prev = table.remove(fw_history)
  fw_forward[#fw_forward+1] = fw_current_path
  fw_current_path = prev
  fw_after_navigate()
end

local function fw_go_forward()
  if #fw_forward == 0 then return end
  local nxt = table.remove(fw_forward)
  fw_history[#fw_history+1] = fw_current_path
  fw_current_path = nxt
  fw_after_navigate()
end

local function fw_go_up()
  fw_navigate(fw_parent(fw_current_path), true)
end

local function fw_scroll_by(delta)
  fw_scroll = fw_scroll + delta
  if fw_scroll < 0 then fw_scroll = 0 end
  local m = fw_max_scroll()
  if fw_scroll > m then fw_scroll = m end
  fw_refresh_canvas()
end

local function fw_toggle_connections()
  fw_connections_on = not fw_connections_on
  if fw_connections_on then
    fw_edges = fw_compute_edges()
    renoise.app():show_status(string.format("File Warehouse: %d connections found", #fw_edges))
  else
    fw_edges = {}
  end
  if fw_conn_button then
    fw_conn_button.text = fw_connections_on and "Connections: On" or "Connections: Off"
  end
  fw_refresh_canvas()
end

local function fw_toggle_mode()
  fw_mode = (fw_mode == "music") and "files" or "music"
  if fw_mode == "music" then
    renoise.app():show_status("File Warehouse: probing .xrns songs for the music graph…")
    fw_build_music_graph()
    if fw_status_text then
      fw_status_text.text = string.format("Music graph: %d songs, %d samples (click a sample to see which songs use it)",
        #fw_m_songs, #fw_m_samples)
    end
  else
    if fw_status_text then fw_status_text.text = string.format("%d items", #fw_entries) end
  end
  if fw_mode_button then
    fw_mode_button.text = (fw_mode == "music") and "Mode: Music Graph" or "Mode: Files"
  end
  fw_refresh_canvas()
end

local function fw_default_path()
  local home = os.getenv("HOME")
  -- Prefer a real folder of songs so Music Graph has something to show. First
  -- existing candidate wins; otherwise home; otherwise root.
  local candidates = {}
  if home and home ~= "" then
    candidates[#candidates+1] = home .. "/Music/Projects/Projects-Renoise"
    candidates[#candidates+1] = home .. "/Music/Projects"
  end
  for _, p in ipairs(candidates) do
    if io.exists(p) then return p end
  end
  if home and home ~= "" then return home end
  return "/"
end

--------------------------------------------------------------------------------
-- Dialog
--------------------------------------------------------------------------------
function PakettiFileWarehouseShow()
  if fw_dialog and fw_dialog.visible then
    fw_dialog:close(); fw_dialog = nil; return
  end
  fw_vb = renoise.ViewBuilder()
  local vb = fw_vb

  if not fw_current_path then fw_current_path = fw_default_path() end

  fw_path_text   = vb:text{ text = fw_current_path, font = "bold", style = "strong", width = FW_W - 20 }
  fw_status_text = vb:text{ text = "", width = FW_W - 20 }
  fw_conn_button = vb:button{ text = fw_connections_on and "Connections: On" or "Connections: Off",
    width = 130, notifier = fw_toggle_connections }
  fw_mode_button = vb:button{ text = (fw_mode == "music") and "Mode: Music Graph" or "Mode: Files",
    width = 130, tooltip = "Files = browse folder. Music Graph = probe the folder's .xrns songs and show which songs use which sample.",
    notifier = fw_toggle_mode }

  fw_canvas = vb:canvas{
    width = FW_W, height = FW_H,
    mode = "plain",
    render = fw_render,
    mouse_handler = fw_handle_mouse,
    mouse_events = {"down", "up", "move", "exit"},
  }

  fw_scrollbar = vb:scrollbar{
    width = 18, height = FW_H,
    min = 0, max = 1, value = 0, pagestep = 1,
    autohide = false,
    notifier = function(v)
      if fw_updating_scrollbar then return end
      fw_scroll = math.floor(v + 0.5)
      if fw_mode == "music" then fw_layout_music() else fw_layout() end
      if fw_canvas then fw_canvas:update() end
    end
  }

  local controls = vb:row{
    vb:button{ text = "◀ Back", width = 64, notifier = fw_go_back },
    vb:button{ text = "Fwd ▶", width = 64, notifier = fw_go_forward },
    vb:button{ text = "Up", width = 44, notifier = fw_go_up },
    vb:button{ text = "Open Folder…", width = 100, notifier = function()
      local p = renoise.app():prompt_for_path("Open folder in File Warehouse")
      if p and p ~= "" then
        -- prompt_for_path returns a trailing slash; normalize
        p = p:gsub("/$", "")
        if p == "" then p = "/" end
        fw_navigate(p, true)
      end
    end },
    vb:button{ text = "Refresh", width = 64, notifier = fw_after_navigate },
    fw_mode_button,
    fw_conn_button,
    vb:button{ text = "▲", width = 30, notifier = function() fw_scroll_by(-1) end },
    vb:button{ text = "▼", width = 30, notifier = function() fw_scroll_by(1) end },
  }

  local content = vb:column{
    margin = 8, spacing = 4,
    controls,
    fw_path_text,
    vb:row{ spacing = 2, fw_canvas, fw_scrollbar },
    fw_status_text,
  }

  local keyhandler = function(dialog_obj, key)
    if key.modifiers == "" and key.name == "esc" then
      dialog_obj:close(); fw_dialog = nil; return nil
    end
    return key
  end

  fw_dialog = renoise.app():show_custom_dialog("Paketti File Warehouse", content, keyhandler)
  fw_after_navigate()
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------
PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:File Warehouse…", invoke = PakettiFileWarehouseShow }
renoise.tool():add_keybinding{ name = "Global:Paketti:File Warehouse", invoke = function() PakettiFileWarehouseShow() end }
