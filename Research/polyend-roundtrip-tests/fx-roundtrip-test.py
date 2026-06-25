#!/usr/bin/env python3
"""
FX round-trip test: for each Renoise effect command Paketti maps to Polyend, export
a pattern carrying that effect (via Paketti's REAL export_pattern_to_mtp, sliced live),
read it back with Paketti's REAL read_pattern_file, and assert the Polyend FX type is
what the bidirectional map promises. Catches regressions in renoise_fx_to_polyend.

Usage:  python3 fx-roundtrip-test.py
"""
import os, re, subprocess, sys

PAKETTI = os.path.expanduser("~/work/paketti/PakettiPolyendPatternData.lua")

# (Renoise effect cmd, amount hex, expected Polyend FX type index)
CASES = [
    ("0C","40",18),("08","80",31),("F0","20",15),("0D","00",13),("01","10",41),
    ("02","10",42),("05","40",19),("00","37",21),("09","80",22),("0E","03",3),
    ("EC","02",20),("0B","01",26),("0S","05",25),("24","80",27),("ZD","A0",17),("0M","C0",34),
]

def blk(src, rx):
    i = next(k for k,l in enumerate(src) if re.match(rx,l)); j=i+1
    while not re.match(r"^end\b", src[j]): j+=1
    return "\n".join(src[i:j+1])

def main():
    src = open(PAKETTI).read().splitlines()
    cs = next(i for i,l in enumerate(src) if l.startswith("local POLYEND_CONSTANTS = {")); ce=cs+1
    while not src[ce].startswith("}"): ce+=1
    consts = "\n".join(src[cs:ce+1])
    helpers = "\n".join(blk(src, rf"^local function {n}\b") for n in
        ["read_uint8","read_uint16_le","read_uint32_le","read_int8","read_float_le","write_uint16_le","write_uint32_le"])
    reader = blk(src, r"^function read_pattern_file\b")
    writer = blk(src, r"^function export_pattern_to_mtp\b")
    lua_cases = "{" + ",".join(f'{{"{c}","{a}",{e}}}' for c,a,e in CASES) + "}"
    stub = f'''local bit=require("bit"); local preferences=nil
renoise={{Track={{TRACK_TYPE_SEQUENCER=1}}}}
local CASES={lua_cases}
local function mkfx(cmd,amt) return {{note_columns={{{{note_value=60,note_string="",instrument_value=0}}}},effect_columns={{{{number_string=cmd,amount_string=amt}},{{number_string="",amount_string="00"}}}}}} end
local function blank() return {{note_columns={{{{note_value=121,note_string="",instrument_value=255}}}},effect_columns={{{{number_string="",amount_string="00"}},{{number_string="",amount_string="00"}}}}}} end
local function mktrack(ti) local L={{}}; for i=1,16 do if i==1 and CASES[ti] then L[i]=mkfx(CASES[ti][1],CASES[ti][2]) else L[i]=blank() end end; return {{type=1,line=function(_,n) return L[n] end}} end
local _t={{}}; for t=1,16 do _t[t]=mktrack(t) end
local _p={{number_of_lines=16,track=function(_,ti) return _t[ti] end}}
renoise.song=function() return {{patterns={{_p}},tracks=_t}} end
'''
    driver = '''
local out=os.tmpname()..".mtp"
export_pattern_to_mtp(1,out,16)
local old=print; print=function() end; local p=read_pattern_file(out); print=old
local npass=0
for ti,c in ipairs(CASES) do
  local got=p.tracks[ti][1].fx[1].type
  if got==c[3] then npass=npass+1 end
  print(string.format("  %s  Renoise %s -> Polyend FX %d (expect %d)", got==c[3] and "PASS" or "FAIL", c[1], got, c[3]))
end
print(string.format("\\n%s (%d/%d)", npass==#CASES and "ALL PASS" or "FAILURES", npass, #CASES))
os.exit(npass==#CASES and 0 or 1)
'''
    open("/tmp/_fxrt.lua","w").write("\n".join([stub,consts,helpers,reader,writer,driver]))
    r = subprocess.run(["luajit","/tmp/_fxrt.lua"], capture_output=True, text=True)
    print(r.stdout, end="")
    if r.returncode != 0 and not r.stdout: print(r.stderr[-1500:])
    sys.exit(r.returncode)

if __name__ == "__main__":
    main()
