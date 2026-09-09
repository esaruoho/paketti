#!/usr/bin/env python3
"""Diff a Paketti-written TX16W disk image against a real Yamaha library disk.

This is the check that is NOT circular. The Lua regression test in this folder
encodes my own reading of the format, so it can pass on a broken export - it did
exactly that once, asserting the wrong invariant while Cyclone refused the disk.
This compares the bytes Paketti writes against bytes Yamaha shipped, property by
property, and prints every place they differ.

    python3 tests/tx16w_corpus_diff.py [path/to/OUR_DISK.img]
    TX16W_REFERENCE=/path/to/sdNNN.img python3 tests/tx16w_corpus_diff.py ...

A "DIFFERS" line is not automatically a bug - counts legitimately vary (number
of Grop chunks, number of waves), and the OEM id differs because the corpus
images were dumped with WinImage while Paketti writes Typhoon's own `Y LM T8W`.
Read each one. What matters is that no STRUCTURAL property differs: chunk order,
chunk sizes, reference layout, INST/MARK shape, codec fields.
"""
import sys, os, struct, glob

import struct
class FAT12:
    def __init__(self,path):
        self.d=open(path,'rb').read(); b=self.d
        self.bps=struct.unpack_from('<H',b,11)[0]; self.spc=b[13]
        self.res=struct.unpack_from('<H',b,14)[0]; self.nfat=b[16]
        self.nroot=struct.unpack_from('<H',b,17)[0]
        self.tsec=struct.unpack_from('<H',b,19)[0]
        self.spf=struct.unpack_from('<H',b,22)[0]
        self.fat_off=self.res*self.bps
        self.root_off=self.fat_off+self.nfat*self.spf*self.bps
        self.data_off=self.root_off+self.nroot*32
    def fatent(self,n):
        o=self.fat_off+(n*3)//2; v=self.d[o]|(self.d[o+1]<<8)
        return (v>>4) if n&1 else (v&0xFFF)
    def entries(self):
        out=[]
        for i in range(self.nroot):
            e=self.d[self.root_off+i*32:self.root_off+i*32+32]
            if e[0]==0: break
            if e[0]==0xE5: continue
            out.append((e[0:8].decode('latin1').rstrip(),e[8:11].decode('latin1').rstrip(),
                        e[11],struct.unpack_from('<H',e,26)[0],struct.unpack_from('<I',e,28)[0]))
        return out
    def read(self,clus,size):
        out=b''
        while 2<=clus<0xFF8:
            off=self.data_off+(clus-2)*self.spc*self.bps
            out+=self.d[off:off+self.spc*self.bps]; clus=self.fatent(clus)
        return out[:size] if size else out


import sys,os,struct,glob
GOOD = os.environ.get("TX16W_REFERENCE",
    "/Users/esaruoho/Downloads/tx16w_typhoon/sd/cyclone-format/"
    "sd007-drums-and-percussion-electric-and-acoustic-1-2.img")
OURS = sys.argv[1] if len(sys.argv) > 1 else \
    "/Users/esaruoho/Downloads/tx16w/RELEASE/drumkit/TX16W__DISK1.img"
def chunks(d,off=12):
    o=[];i=off
    while i+8<=len(d):
        t=d[i:i+4].decode('latin1','replace');l=struct.unpack_from('>I',d,i+4)[0]
        if l>len(d): break
        o.append((t,l,d[i+8:i+8+l])); i+=8+l+(l&1)
    return o
def load(p):
    f=FAT12(p); out={}
    for n,e,a,c,s in f.entries():
        if a&0x08: continue
        out[n.strip()+'.'+e]=(f.read(c,s),a)
    return f,out
gf,g=load(GOOD); of,o=load(OURS)
rows=[]
def cmp(label,a,b):
    rows.append((label,str(a),str(b),"same" if str(a)==str(b) else "DIFFERS"))

# --- BPB ---
gd=open(GOOD,'rb').read(); od=open(OURS,'rb').read()
for name,off,ln in [("OEM id",3,8),("bytes/sector",11,2),("sectors/cluster",13,1),
                    ("reserved",14,2),("FAT count",16,1),("root entries",17,2),
                    ("total sectors",19,2),("media",21,1),("sectors/FAT",22,2),
                    ("sectors/track",24,2),("heads",26,2)]:
    a=gd[off:off+ln]; b=od[off:off+ln]
    fa=a.decode('latin1') if ln==8 else int.from_bytes(a,'little')
    fb=b.decode('latin1') if ln==8 else int.from_bytes(b,'little')
    cmp("BPB "+name,fa,fb)
cmp("boot signature 0x55AA", gd[510:512].hex(), od[510:512].hex())
cmp("volume label present", any(a&0x08 for _,_,a,_,_ in gf.entries()), any(a&0x08 for _,_,a,_,_ in of.entries()))
cmp("file attribute byte", sorted({a for _,(d,a) in g.items()}), sorted({a for _,(d,a) in o.items()}))

# --- waves ---
gw=[v[0] for k,v in g.items() if k.endswith('.C01')]
ow=[v[0] for k,v in o.items() if k.endswith('.C01')]
def wprofile(ws):
    order=set(); insttail=set(); marklen=set(); comm=set(); m64=0; noafter=0; appl=set()
    for w in ws:
        ch=chunks(w); d=dict((t,b) for t,l,b in ch)
        order.add(tuple(t for t,_,_ in ch))
        if 'INST' in d: insttail.add(d['INST'][2:].hex())
        if 'MARK' in d: marklen.add(len(d['MARK']))
        if 'COMM' in d:
            c=d['COMM']; comm.add((struct.unpack_from('>H',c,0)[0],struct.unpack_from('>H',c,6)[0],c[18:22].decode('latin1')))
            fr=struct.unpack_from('>I',c,2)[0]
            if fr%64==0: m64+=1
            if 'MARK' in d and struct.unpack_from('>I',d['MARK'],22)[0]==fr: noafter+=1
        if 'APPL' in d: appl.add(d['APPL'][:12].hex())
    return order,insttail,marklen,comm,m64,noafter,len(ws),appl
go=wprofile(gw); oo=wprofile(ow)
cmp("wave chunk order",go[0],oo[0])
cmp("wave INST tail values",go[1],oo[1])
cmp("wave MARK length",go[2],oo[2])
cmp("wave COMM (ch,bits,codec)",go[3],oo[3])
cmp("waves length %64 == all",f"{go[4]}/{go[6]}",f"{oo[4]}/{oo[6]}")
cmp("waves no data after loop",f"{go[5]}/{go[6]}",f"{oo[5]}/{oo[6]}")
cmp("APPL stoc/Typhoon prefix",go[7],oo[7])

# --- voices / perf / setup ---
def vprofile(files,exts):
    top=set(); grop=set(); parm=set(); mods=set(); reflen=set(); spaces=0; refs=0
    for k,(d,a) in files.items():
        if k.split('.')[1][0] not in exts: continue
        ch=chunks(d); top.add(tuple(t for t,_,_ in ch))
        for t,l,b in ch:
            if t=='Grop':
                inner=chunks(b,0); grop.add(tuple(x[0] for x in inner)[:10])
                for tt,ll,bb in inner:
                    if tt=='Parm': parm.add(ll)
                    if tt=='Mod ': mods.add(ll)
        i=0
        while True:
            j=min([x for x in [d.find(b'Wave',i),d.find(b'Voic',i),d.find(b'Perf',i)] if x>=0] or [-1])
            if j<0: break
            if struct.unpack_from('>I',d,j+4)[0]==20:
                refs+=1; reflen.add(20)
                if b' ' in d[j+8:j+16]: spaces+=1
            i=j+4
    return top,grop,parm,mods,reflen,spaces,refs
gv=vprofile(g,'O'); ov=vprofile(o,'O')
cmp("voice top-level chunks",gv[0],ov[0])
cmp("voice Grop inner order",gv[1],ov[1])
cmp("voice Parm sizes",sorted(gv[2]),sorted(ov[2]))
cmp("voice Mod size",gv[3],ov[3])
cmp("reference chunk length",gv[4],ov[4])
cmp("reference names with a space",f"{gv[5]} of {gv[6]}",f"{ov[5]} of {ov[6]}")
gp=vprofile(g,'P'); op_=vprofile(o,'P')
cmp("performance top-level chunks",gp[0],op_[0])
gs=vprofile(g,'X'); os_=vprofile(o,'X')
cmp("setup top-level chunks",gs[0],os_[0])

w=max(len(r[0]) for r in rows)
print(f"{'PROPERTY'.ljust(w)} | {'YAMAHA sd007'.ljust(46)} | {'PAKETTI disk1'.ljust(46)} | VERDICT")
print("-"*(w+104))
diff=0
for a,b,c,v in rows:
    if v=="DIFFERS": diff+=1
    print(f"{a.ljust(w)} | {b[:46].ljust(46)} | {c[:46].ljust(46)} | {v}")
print(f"\n{len(rows)-diff}/{len(rows)} properties identical to the Yamaha disk; {diff} differ.")
