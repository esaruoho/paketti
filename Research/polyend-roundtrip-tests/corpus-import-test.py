#!/usr/bin/env python3
"""
Import-robustness test: run Paketti's REAL readers (read_pattern_file /
read_project_file, sliced live from PakettiPolyendPatternData.lua) over a whole
corpus of real device files, and cross-check every .mtp's detected track count
against the official Polyend reference parser (patternRead.py).

This makes the Polyend IMPORT side trustworthy: if Paketti can read every real
.mtp / project.mt without error and agrees with the reference on structure, the
importer is robust against real-world data.

Usage:  python3 corpus-import-test.py [corpus_dir]
        (default corpus: ~/Music/samples/PTI)
"""
import os, re, sys, subprocess, tempfile, glob

PAKETTI = os.path.expanduser("~/work/paketti/PakettiPolyendPatternData.lua")
PYREF   = os.path.expanduser("~/work/paketti/Research/TrackerFilesDocs/patternRead.py")
CORPUS  = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Music/samples/PTI")

def slice_block(src, start_re):
    i = next(k for k,l in enumerate(src) if re.match(start_re, l))
    j = i+1
    while j < len(src) and not re.match(r"^end\b", src[j]): j += 1
    return "\n".join(src[i:j+1])

def build_harness(manifest_path):
    src = open(PAKETTI).read().splitlines()
    cs = next(i for i,l in enumerate(src) if re.match(r"^local POLYEND_CONSTANTS = \{", l))
    ce = cs+1
    while not re.match(r"^\}", src[ce]): ce += 1
    consts = "\n".join(src[cs:ce+1])
    helpers = "\n".join(slice_block(src, rf"^local function {n}\b")
                        for n in ["read_uint8","read_uint16_le","read_uint32_le","read_int8","read_float_le"])
    reader  = slice_block(src, r"^function read_pattern_file\b")
    # read_project_file is a local function
    proj    = slice_block(src, r"^local function read_project_file\b")
    driver = r'''
local function silent(f, ...) -- suppress the readers' prints
  local old = print; print = function() end
  local ok, a, b = pcall(f, ...); print = old; return ok, a, b
end
local manifest = "%s"
local mf = io.open(manifest, "r")
for line in mf:lines() do
  local kind, path = line:match("^(%%a+)\t(.+)$")
  if kind == "mtp" then
    local ok, p = silent(read_pattern_file, path)
    if ok and p then
      local notes = 0
      for _,t in ipairs(p.tracks) do for _,s in ipairs(t) do if s.note >= 0 then notes = notes + 1 end end end
      io.write(string.format("MTP\t%%s\t%%d\t%%d\t%%d\t%%s\n", path, p.track_count, p.pattern_length, notes, p.header.id_file))
    else
      io.write(string.format("MTPERR\t%%s\t%%s\n", path, tostring(p)))
    end
  elseif kind == "mt" then
    local ok, r = silent(read_project_file, path)
    if ok and r then
      io.write(string.format("MT\t%%s\t%%s\t%%s\n", path, tostring(r.global_tempo), (r.project_name or ""):gsub("\t"," ")))
    else
      io.write(string.format("MTERR\t%%s\t%%s\n", path, tostring(r)))
    end
  end
end
mf:close()
''' % manifest_path
    return "\n".join(['local bit = require("bit")', 'local preferences = nil',
                      consts, helpers, reader, proj, driver])

def main():
    mtps = sorted(glob.glob(os.path.join(CORPUS, "**", "*.mtp"), recursive=True))
    mts  = sorted(glob.glob(os.path.join(CORPUS, "**", "project.mt"), recursive=True))
    print(f"=== Corpus import test: {len(mtps)} .mtp + {len(mts)} project.mt under {CORPUS} ===\n")
    tmp = tempfile.mkdtemp(prefix="polycorpus_")
    manifest = os.path.join(tmp, "manifest.tsv")
    with open(manifest, "w") as f:
        for p in mtps: f.write(f"mtp\t{p}\n")
        for p in mts:  f.write(f"mt\t{p}\n")
    harness = os.path.join(tmp, "h.lua")
    open(harness, "w").write(build_harness(manifest))
    r = subprocess.run(["luajit", harness], capture_output=True, text=True)
    if r.returncode != 0:
        print("HARNESS ERROR:\n", r.stderr[-2000:]); sys.exit(2)

    mtp_ok = mtp_err = mt_ok = mt_err = mismatch = 0
    ids = {}
    for line in r.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "MTP":
            _, path, tc, length, notes, idf = parts
            ids[idf] = ids.get(idf, 0) + 1
            # cross-check track count with the official reference
            v = subprocess.run(["python3", PYREF, path], capture_output=True, text=True)
            m = re.search(r"Detected track count: (\d+)", v.stdout)
            if m and int(m.group(1)) == int(tc):
                mtp_ok += 1
            else:
                mismatch += 1
                if mismatch <= 5:
                    print(f"  MISMATCH {os.path.basename(path)}: paketti={tc} ref={m.group(1) if m else '?'}")
        elif parts[0] == "MTPERR":
            mtp_err += 1
            if mtp_err <= 5: print(f"  MTP READ ERROR {os.path.basename(parts[1])}: {parts[2]}")
        elif parts[0] == "MT":
            _, path, bpm, name = parts
            mt_ok += 1
            print(f"  project.mt: bpm={bpm:<6} name={name!r}  ({os.path.basename(os.path.dirname(path))})")
        elif parts[0] == "MTERR":
            mt_err += 1
            print(f"  MT READ ERROR {parts[1]}: {parts[2]}")

    print(f"\n.mtp: {mtp_ok} read+agree, {mismatch} track-count mismatch, {mtp_err} read errors")
    print(f"file ids seen: {ids}")
    print(f"project.mt: {mt_ok} read, {mt_err} errors")
    ok = (mtp_err == 0 and mismatch == 0 and mt_err == 0)
    print(f"\n{'ALL PASS' if ok else 'FAILURES'}")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
