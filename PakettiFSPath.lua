--[[============================================================================
PakettiFSPath.lua — Cross-platform filesystem path utilities

Pure-Lua path manipulation (no Renoise API dependencies), a sample-relocation
helper used by importers that consume files containing absolute paths to other
files (EXS24, NKI/Kontakt, GIG, Polyend Tracker .mtp, Octatrack .ot pairs, etc),
and the filename-sanitising / folder-walking helpers shared by Paketti's batch
converters (see the bottom of this file).

Derived from matt-allan/renoise-exs24's fspath.lua (MIT, 2018) — adapted for
Paketti (GPLv3). The MIT attribution below satisfies the MIT license
requirement to retain copyright in substantial portions.

  MIT License — Copyright (c) 2018 Matt Allan and all contributors.
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction. The above copyright notice and this
  permission notice shall be included in all copies or substantial portions of
  the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
============================================================================]]--

pakettiFSPath = {}

local SEP = package.config:sub(1,1)
local SEPB = string.byte(SEP)
local DOT = string.byte(".")

pakettiFSPath.sep = SEP

---Split a string on the last occurrence of the given character code.
---@param s string
---@param c integer
---@return string, string
local function rsplit(s, c)
  local len = #s
  for i = len, 1, -1 do
    if string.byte(s, i) == c then
      return string.sub(s, 1, i - 1), string.sub(s, i + 1)
    end
  end
  return s, ""
end

---Split a path into (dirname, basename).
---@param p string
---@return string dirname, string basename
function pakettiFSPath.split(p)
  return rsplit(p, SEPB)
end

---Return the directory portion of a path.
---@param p string
---@return string
function pakettiFSPath.dirname(p)
  local d, _ = rsplit(p, SEPB)
  return d
end

---Return the file portion of a path, optionally stripping a trailing suffix.
---@param p string
---@param suffix string?
---@return string
function pakettiFSPath.basename(p, suffix)
  local _, b = rsplit(p, SEPB)
  if suffix and string.sub(b, -#suffix) == suffix then
    return string.sub(b, 1, -#suffix - 1)
  end
  return b
end

---Return the extension of a path (without the leading dot).
---@param p string
---@return string
function pakettiFSPath.extname(p)
  local _, ext = rsplit(p, DOT)
  return ext
end

---Join two or more path segments with the platform separator.
---@param p string
---@return string
function pakettiFSPath.join(p, ...)
  for _, s in ipairs({...}) do
    if string.byte(p, -1) ~= SEPB then
      p = p .. SEP
    end
    p = p .. s
  end
  return p
end

---Iterate over the segments of a path left-to-right.
---@param p string
function pakettiFSPath.parts(p)
  local pos = 1
  local len = #p
  if string.byte(p, pos) == SEPB then pos = pos + 1 end
  return function()
    local i = pos + 1
    while string.byte(p, i) ~= SEPB and i < len do i = i + 1 end
    if i > len then return nil end
    local start_index = pos
    local part = string.sub(p, pos, string.byte(p, i) == SEPB and i - 1 or i)
    pos = i + 1
    return part, start_index
  end
end

---Iterate over the segments of a path right-to-left.
---@param p string
function pakettiFSPath.rparts(p)
  local pos = #p
  if string.byte(p, pos) == SEPB then pos = pos - 1 end
  return function()
    local i = pos - 1
    while string.byte(p, i) ~= SEPB and i > 0 do i = i - 1 end
    if i <= 0 then return nil end
    local start_index = string.byte(p, i) == SEPB and i + 1 or i
    local part = string.sub(p, start_index, pos)
    pos = i - 1
    return part, start_index
  end
end

---Given two absolute paths, splice the tail of `path` onto the root portion of
---`root_path` by finding a common segment. Returns nil if no common segment is
---found. The optional `n` parameter skips the first (n-1) matches before
---splicing — useful when generic words ("Samples", "Audio") match before the
---actual library name does. Callers typically retry n = 1, 2, 3 in order.
---@param root_path string
---@param path string
---@param n integer?
---@return string?
function pakettiFSPath.rebase(root_path, path, n)
  n = n or 1
  for root_part, i in pakettiFSPath.parts(root_path) do
    for part, j in pakettiFSPath.rparts(path) do
      if root_part == part then
        n = n - 1
        if n == 0 then
          return pakettiFSPath.join(string.sub(root_path, 1, i - 1), string.sub(path, j))
        end
      end
    end
  end
  return nil
end

---Read the user-configured `pakettiSampleLibraryRoots` preference (newline-
---separated absolute paths) into an array of trimmed, non-empty strings.
---Shared by every importer that calls `resolve()` so users configure their
---library roots once. Returns an empty table when the pref is missing/empty.
---@return string[]
function pakettiFSPath.library_roots()
  local roots = {}
  if not preferences then return roots end
  local pref = preferences.pakettiSampleLibraryRoots
  if not pref then return roots end
  local s = pref.value
  if not s or s == "" then return roots end
  for line in string.gmatch(s, "[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then table.insert(roots, trimmed) end
  end
  return roots
end

---Resolve a (possibly broken) absolute sample-reference path against the file
---that contained it, with optional extra search roots. Tries, in order:
---  1. the reference path itself (if it still exists)
---  2. the same folder as the anchor file
---  3. rebase the reference path onto the anchor at common-segment depths 1..3
---  4. rebase the reference path onto each extra root at depths 1..3
---Returns the resolved absolute path or nil.
---@param reference_path string
---@param anchor_path string
---@param extra_roots string[]?
---@return string?
function pakettiFSPath.resolve(reference_path, anchor_path, extra_roots)
  if not reference_path or reference_path == "" then return nil end
  if io.exists(reference_path) then return reference_path end

  local anchor_dir = pakettiFSPath.dirname(anchor_path)
  local basename = pakettiFSPath.basename(reference_path)

  local same = pakettiFSPath.join(anchor_dir, basename)
  if io.exists(same) then return same end

  for depth = 1, 3 do
    local p = pakettiFSPath.rebase(anchor_path, reference_path, depth)
    if p and io.exists(p) then return p end
  end

  for _, root in ipairs(extra_roots or {}) do
    for depth = 1, 3 do
      local p = pakettiFSPath.rebase(root, reference_path, depth)
      if p and io.exists(p) then return p end
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Shared helpers for batch converters
--
-- sanitize_filename is pure Lua. collect_files uses Renoise's os.filenames /
-- os.dirnames extensions, so it is the one function in this file that needs the
-- Renoise host (it is never called at load time).
--------------------------------------------------------------------------------

---Make an arbitrary name safe to use as a filename component on macOS, Windows
---and Linux. Returns `fallback` when nothing usable is left.
---@param name string
---@param fallback string?
---@return string
function pakettiFSPath.sanitize_filename(name, fallback)
  fallback = fallback or "untitled"
  if type(name) ~= "string" then return fallback end

  -- drop control characters (NUL padding included), then the characters
  -- Windows and the Finder refuse
  local s = name:gsub("%c", "")
  s = s:gsub("[/\\:%*%?\"<>|]", "_")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("%s+", " ")
  s = s:gsub("%.+$", "")

  if s == "" then return fallback end
  if #s > 64 then s = s:sub(1, 64):gsub("%s+$", "") end
  if s == "" then return fallback end
  return s
end

---Quote a string so /bin/sh passes it through as one literal argument.
---Lua's `%q` escapes for LUA SOURCE, not for the shell: a path containing `$`,
---a backtick or a quote survives %q but is then expanded by the shell, so
---`/tmp/$HOME x.wav` became the home directory and backticks ran as a command.
---Single-quoting with the '\'' escape is the only form the shell never
---reinterprets.
---@param str string
---@return string
function pakettiFSPath.shell_quote(str)
  return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

---Strip a trailing audio-file extension from a name. Renoise sample names very
---often carry the source filename including its extension, which would otherwise
---produce "kick.wav.wav" when exporting. Only the extensions Renoise itself can
---import are removed, so a sample genuinely called "Track 1.2" keeps its name.
---@param name string
---@return string
function pakettiFSPath.strip_audio_extension(name)
  if type(name) ~= "string" then return "" end
  local stem, ext = name:match("^(.*)%.([%w%d]+)$")
  if not stem or stem == "" then return name end
  local AUDIO_EXTENSIONS = {
    wav = true, wave = true, aif = true, aiff = true, aifc = true, flac = true,
    ogg = true, mp3 = true, m4a = true, caf = true, w64 = true, snd = true,
    au = true, voc = true, iff = true, ["8svx"] = true, ["16sv"] = true,
    raw = true, rex = true, rx2 = true,
  }
  if AUDIO_EXTENSIONS[ext:lower()] then return stem end
  return name
end

---Collect files under a folder, keeping only those `match_fn(filename)` accepts.
---Recurses into subfolders when asked, skipping hidden ones. Returns a
---case-insensitively sorted array of absolute paths.
---@param folder string
---@param recurse boolean?
---@param match_fn fun(filename: string): boolean
---@return string[]
function pakettiFSPath.collect_files(folder, recurse, match_fn)
  local results = {}

  local function walk(dir)
    local ok_files, files = pcall(os.filenames, dir)
    if ok_files and files then
      for _, fn in ipairs(files) do
        if match_fn(fn) then
          table.insert(results, pakettiFSPath.join(dir, fn))
        end
      end
    end

    if recurse then
      local ok_dirs, dirs = pcall(os.dirnames, dir)
      if ok_dirs and dirs then
        for _, d in ipairs(dirs) do
          if not d:match("^%.") then walk(pakettiFSPath.join(dir, d)) end
        end
      end
    end
  end

  walk(folder)
  table.sort(results, function(a, b) return a:lower() < b:lower() end)
  return results
end
