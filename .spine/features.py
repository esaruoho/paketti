#!/usr/bin/env python3
"""features.py — turn the raw spine JSON into a HUMAN, non-technical feature view.

Reads the harness JSON (names per orifice), and produces:
  • docs/FEATURE-MAP.md  — what Paketti adds, by PLACE and FEATURE GROUP, with the
                            three doors (keyboard / MIDI / menu) it's reachable through.
  • docs/MIDI-GAPS.md    — feature groups & concrete actions reachable by key/menu
                            but NOT by MIDI: the mappings worth adding.

No .lua files, no internals — "this feature, in this place, via these doors."

    python3 .spine/features.py <spine.json> [repo_root]
"""
import json, os, re, shutil, subprocess, sys
from collections import defaultdict

SP = sys.argv[1] if len(sys.argv) > 1 else "/tmp/sp4.json"
ROOT = sys.argv[2] if len(sys.argv) > 2 else "."

VALID_KB = {"Global","Automation","Disk Browser","DSP Chain","Instrument Box","Mixer",
 "Pattern Editor","Pattern Matrix","Pattern Sequencer","Phrase Editor","Phrase Map",
 "Phrase Script Editor","Sample Editor","Sample FX Mixer","Sample Keyzones","Sample Modulation Matrix"}

# Place = the Renoise GUI region the user is looking at. MIDI fires regardless → "Anywhere (MIDI)".
def strip(n): return n.lstrip("-").lstrip("!").strip()

def place(n):
    p = strip(n).split(":")
    seg = p[0]
    if seg.startswith("Main Menu"): return "Main Menu ▸ Tools"
    if seg.startswith("Scripting Menu"): return "Scripting Menu"
    if seg == "Paketti" or seg == "": return "Anywhere (MIDI)"
    return seg

# Feature GROUP = the first menu sub-folder after the "Paketti"/"Paketti Gadgets" token,
# or for flat MIDI names the leading capability phrase. This is the human grouping.
def group(n):
    p = strip(n).split(":")
    # find the Paketti anchor
    anchor = None
    for i,seg in enumerate(p):
        if seg in ("Paketti","Paketti Gadgets"):
            anchor = i; break
    if anchor is None:
        return "(misc)"
    rest = p[anchor+1:]
    if len(rest) >= 2:
        return rest[0]                 # there IS a sub-folder before the leaf
    return "(top level)"               # leaf sits directly under Paketti

# Normalised feature identity for cross-door matching: the descriptive words, minus
# all parameter noise (numbers, +N/-N, slot/track/device NN, dB, MIDI x[Knob] suffix,
# common filler). Two registrations with the same identity are the SAME feature.
PARAM = re.compile(r"""\(?[-+]?\d+(\.\d+)?\)?|x\[[a-z]+\]|\b\d+\s*db\b""", re.I)
FILLER = {"to","the","a","of","for","by","in","on","and","or","as","with","this","paketti"}
def ident(n):
    s = strip(n).split(":")[-1]                 # the leaf / phrase
    s = PARAM.sub(" ", s).lower()
    s = re.sub(r"[^a-z ]", " ", s)
    toks = [t for t in s.split() if t and t not in FILLER]
    return " ".join(toks)

def load():
    # If the spine JSON isn't there, run the harness ourselves (so CI can call this
    # standalone, same as build.py does). Otherwise reuse the provided JSON.
    if not os.path.exists(SP):
        lj = shutil.which("luajit") or shutil.which("lua")
        if not lj:
            sys.exit("features.py: need luajit, or pass an existing spine JSON")
        harness = os.path.join(ROOT, ".spine", "harness.lua")
        subprocess.run([lj, harness, ROOT, SP], timeout=300, check=False,
                       stdout=subprocess.DEVNULL)
    d = json.load(open(SP))
    return d["names"]

def main():
    names = load()
    KB, MI, ME = names["keybinding"], names["midi_mapping"], names["menu_entry"]

    # identity -> set of doors, and a representative human label + place + group
    feat = {}   # ident -> {"doors":set, "label":str, "places":set, "groups":set}
    def add(name, door):
        i = ident(name)
        if not i: return
        f = feat.setdefault(i, {"doors":set(),"label":strip(name).split(":")[-1],
                                "places":set(),"groups":set()})
        f["doors"].add(door)
        f["places"].add(place(name))
        f["groups"].add(group(name))
    for n in ME: add(n, "E")     # menu (most descriptive labels) first → best representative label
    for n in KB: add(n, "K")
    for n in MI: add(n, "M")

    # The three doors name the same action differently (menu "Cut to Slot" vs MIDI
    # "Clipboard Cut to Slot"), so exact identity under-counts MIDI coverage. Augment:
    # a feature also counts as MIDI-reachable if some MIDI phrase strongly overlaps
    # its tokens. Approximate — but it stops false "0% MIDI" on areas that DO have it.
    midi_sets = {frozenset(i.split()) for i,f in feat.items() if "M" in f["doors"]}
    midi_sets = [s for s in midi_sets if s]
    def fuzzy_midi(ftoks):
        for ms in midi_sets:
            inter = len(ftoks & ms)
            # require ≥2 shared tokens (stops generic 1-word features matching anything)
            if inter >= 2 and inter >= round(0.7 * min(len(ftoks), len(ms))):
                return True
        return False
    for i,f in feat.items():
        if "M" not in f["doors"] and fuzzy_midi(frozenset(i.split())):
            f["doors"].add("M"); f["fuzzy_m"] = True

    nfeat = len(feat)
    by_group = defaultdict(list)
    for i,f in feat.items():
        g = sorted(f["groups"], key=len)[0]
        by_group[g].append((i,f))

    # ---------- FEATURE-MAP.md ----------
    door_word = {"K":"keyboard","M":"MIDI","E":"menu"}
    def doors_str(s): return " · ".join(door_word[x] for x in ("K","M","E") if x in s)

    grp_rows = []
    for g, items in by_group.items():
        k = sum("K" in f["doors"] for _,f in items)
        m = sum("M" in f["doors"] for _,f in items)
        e = sum("E" in f["doors"] for _,f in items)
        grp_rows.append((len(items), g, k, m, e))
    grp_rows.sort(reverse=True)

    M = ["# Paketti — the feature map (what it adds to Renoise)", "",
         "*Non-technical. Every Paketti capability as **a feature, in a place, reachable through "
         "one or more doors** — keyboard shortcut · MIDI mapping · menu entry. Parameter variants "
         "(e.g. Transpose −120…+120) are collapsed into the one feature they are. Auto-generated "
         "from the running code by `.spine/features.py`; do not hand-edit.*", "",
         f"## {nfeat:,} distinct features across {len(by_group)} groups", "",
         "| Feature group | features | ⌨ keyboard | 🎛 MIDI | ☰ menu |", "|---|--:|--:|--:|--:|"]
    for n,g,k,m,e in grp_rows:
        if n >= 3:
            M.append(f"| **{g}** | {n} | {k} | {m} | {e} |")
    M += ["", "## Every feature, by group", ""]
    for n,g,k,m,e in grp_rows:
        items = sorted(by_group[g], key=lambda x: x[1]["label"].lower())
        M.append(f"### {g}  ·  {len(items)} features  ·  ⌨{k} 🎛{m} ☰{e}")
        # one place line for the group (most common place)
        M.append("")
        for i,f in items:
            M.append(f"- **{f['label']}** — _{doors_str(f['doors'])}_")
        M.append("")
    open(f"{ROOT}/docs/FEATURE-MAP.md","w").write("\n".join(M)+"\n")

    # ---------- MIDI-GAPS.md ----------
    no_midi = {i:f for i,f in feat.items() if "M" not in f["doors"]}
    has_midi = {i:f for i,f in feat.items() if "M" in f["doors"]}
    gap_by_group = defaultdict(list)
    for i,f in no_midi.items():
        g = sorted(f["groups"], key=len)[0]
        gap_by_group[g].append((i,f))

    rows = []
    for g, items in gap_by_group.items():
        total = len(by_group[g])
        midi = sum("M" in f["doors"] for _,f in by_group[g])
        rows.append((len(items), g, total, midi))
    rows.sort(reverse=True)

    G = ["# Paketti — the MIDI-mapping gaps (what's worth adding)", "",
         "*Features you can reach by **keyboard or menu but NOT by a MIDI mapping** — so a "
         "controller/hardware user can't trigger them. Grouped by feature area, biggest gap first. "
         "Auto-generated by `.spine/features.py`.*", "",
         f"## {len(no_midi):,} of {nfeat:,} features have no MIDI mapping "
         f"({len(has_midi):,} do)", "",
         "> **Caveat:** the three doors name the same action differently, so matching is "
         "approximate (token-overlap). A handful of features listed here may already have a "
         "differently-worded MIDI mapping — treat this as a strong lead, not gospel. The *fully "
         "0% groups* below are the most reliable signal.", "",
         "| Feature group | no MIDI | has MIDI | total | coverage |", "|---|--:|--:|--:|--:|"]
    for n,g,total,midi in rows:
        if n >= 3:
            cov = f"{round(100*midi/total)}%" if total else "—"
            G.append(f"| **{g}** | **{n}** | {midi} | {total} | {cov} |")
    G += ["", "## The biggest fully-unmapped areas (0% MIDI — whole capabilities a controller can't reach)", ""]
    for n,g,total,midi in rows:
        if midi == 0 and n >= 4:
            items = sorted(gap_by_group[g], key=lambda x: x[1]["label"].lower())
            G.append(f"### {g} — {n} features, **none MIDI-mappable**")
            for i,f in items[:14]:
                G.append(f"- {f['label']}  _( {doors_str(f['doors'])} )_")
            if len(items) > 14: G.append(f"- …and {len(items)-14} more")
            G.append("")
    open(f"{ROOT}/docs/MIDI-GAPS.md","w").write("\n".join(G)+"\n")

    print(f"features: {nfeat:,} distinct · groups: {len(by_group)}")
    print(f"MIDI gaps: {len(no_midi):,} features have no MIDI ({len(has_midi):,} do)")
    print("wrote docs/FEATURE-MAP.md + docs/MIDI-GAPS.md")
    # quick console preview of the biggest 0% groups
    print("\nbiggest fully-unmapped (0% MIDI) areas:")
    for n,g,total,midi in rows:
        if midi==0 and n>=4: print(f"  {n:>4}  {g}")

if __name__ == "__main__":
    main()
