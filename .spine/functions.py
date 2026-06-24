#!/usr/bin/env python3
"""functions.py — the GROUND TRUTH of what Paketti adds.

Zero-token. Runs .spine/harness.lua under luajit (a mocked renoise EXECUTES the Lua, so every
add_keybinding / add_menu_entry / add_midi_mapping is captured with FOR-LOOPS RESOLVED to their
final names — a regex grep can't do this), then groups every registration by FUNCTION (so the
KeyBinding, the MidiMapping and the MenuEntry that do the same thing sit together as one row),
grouped by AREA (keybinding scope: Mixer, Sample Editor, Pattern Editor, …).

Writes:
  docs/PAKETTI-FUNCTIONS.md     — human: per-area tables, ⌨ KeyBinding / 🎛 MidiMapping / ☰ MenuEntry
  docs/paketti-functions.json   — machine: {area: [{function, kb:[…], midi:[…], menu:[…]}]}

Usage:  python3 .spine/functions.py [repo_root] [spine.json]
"""
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/Users/esaruoho/work/paketti"
SP = sys.argv[2] if len(sys.argv) > 2 else "/tmp/paketti-functions-spine.json"


def harness_names():
    """The full resolved registration names per door (keybinding/menu_entry/midi_mapping)."""
    if not os.path.exists(SP):
        lj = shutil.which("luajit") or shutil.which("lua")
        if not lj:
            sys.exit("functions.py: need luajit (a regex grep would miss for-loop registrations).")
        subprocess.run([lj, os.path.join(ROOT, ".spine", "harness.lua"), ROOT, SP],
                       timeout=300, check=False, stdout=subprocess.DEVNULL)
        if not os.path.exists(SP):
            sys.exit("functions.py: harness produced no output")
    return json.load(open(SP))["names"]


# Function identity for grouping the three doors into ONE function — same approach as
# .spine/features.py so a KeyBinding, its MidiMapping and its MenuEntry collapse together:
# the leaf phrase, lower-cased, with parameter noise (+1/-10, slot NN, x[Knob], NN dB) and
# common filler words removed. Parameter variants intentionally MERGE (+1 and +10 are the same
# function); the per-door name lists below still record every concrete registration.
# strip parameter noise AND the door-specific suffixes MIDI names carry but keybindings don't:
#   x[Knob]/x[Toggle]/[Trigger]/[Button]/[Slider]  — same FUNCTION, different door.
_PARAM = re.compile(r"""\(?[-+]?\d+(\.\d+)?\)?|x?\[[^\]]*\]|\b\d+\s*db\b""", re.I)
_FILLER = {"to", "the", "a", "of", "for", "by", "in", "on", "and", "or", "as", "with",
           "this", "paketti", "selected", "current", "trigger"}


def leaf(n):
    return n.split(":")[-1].strip()


def ident(n):
    s = _PARAM.sub(" ", leaf(n)).lower()
    s = re.sub(r"[^a-z ]", " ", s)
    toks = [t for t in s.split() if t and t not in _FILLER]
    return " ".join(toks) or leaf(n).lower()


def kb_area(n):
    """Keybinding scope = the part before the first ':' (Mixer, Sample Editor, …)."""
    p = n.split(":")
    return (p[0].strip() or "Global") if len(p) > 1 else "Global"


# Areas in a sensible reading order; anything new the harness finds is appended after.
AREA_ORDER = ["Sample Editor", "Sample Keyzones", "Sample Navigator", "Sample Mappings",
              "Instrument Box", "Mixer", "Pattern Editor", "Phrase Editor", "Pattern Sequencer",
              "Pattern Matrix", "DSP Chain", "Automation", "Global", "(menu/midi only)"]


def build():
    names = harness_names()
    KB, MI, ME = names["keybinding"], names["midi_mapping"], names["menu_entry"]

    F = {}   # ident -> {label, areas:set, kb:[], midi:[], menu:[]}

    def get(n):
        i = ident(n)
        return F.setdefault(i, {"label": leaf(n), "areas": set(), "kb": [], "midi": [], "menu": []})

    for n in KB:
        f = get(n); f["kb"].append(n); f["areas"].add(kb_area(n))
    for n in MI:
        get(n)["midi"].append(n)
    for n in ME:
        get(n)["menu"].append(n)

    # primary area per function: its keybinding scope if it has one, else menu/midi-only bucket
    by_area = defaultdict(list)
    for f in F.values():
        area = sorted(f["areas"])[0] if f["areas"] else "(menu/midi only)"
        by_area[area].append(f)
    for fns in by_area.values():
        fns.sort(key=lambda f: f["label"].lower())

    return F, by_area, len(KB), len(MI), len(ME)


def _ordered_areas(by_area):
    seen = [a for a in AREA_ORDER if a in by_area]
    extra = sorted(a for a in by_area if a not in AREA_ORDER)
    return seen + extra


def write_md(by_area, nkb, nmi, nme, nfunc):
    tick = lambda x: "✅" if x else "·"
    M = [
        "# Paketti — every function, grouped by area (the ground truth)",
        "",
        "> Generated **zero-token** from `.spine/harness.lua` (for-loops resolved). Regenerated on",
        "> every push by `.github/workflows/functions.yml`. Each row is one FUNCTION; the columns",
        "> show which of its three doors exist — ⌨ KeyBinding · 🎛 MidiMapping · ☰ MenuEntry.",
        "",
        f"**{nfunc:,} functions** · {nkb:,} keybindings · {nmi:,} midimappings · {nme:,} menu entries.",
        "",
    ]
    for area in _ordered_areas(by_area):
        fns = by_area[area]
        ck = sum(1 for f in fns if f["kb"]); cm = sum(1 for f in fns if f["midi"]); ce = sum(1 for f in fns if f["menu"])
        M.append(f"## {area}  ·  {len(fns)} functions  ·  ⌨ {ck} · 🎛 {cm} · ☰ {ce}")
        M.append("")
        M.append("| Function | ⌨ | 🎛 | ☰ |")
        M.append("|---|:--:|:--:|:--:|")
        for f in fns:
            label = f["label"].replace("|", "\\|")
            M.append(f"| {label} | {tick(f['kb'])} | {tick(f['midi'])} | {tick(f['menu'])} |")
        M.append("")
    return "\n".join(M) + "\n"


def write_json(by_area):
    out = {}
    for area, fns in by_area.items():
        out[area] = [{"function": f["label"], "kb": f["kb"], "midi": f["midi"], "menu": f["menu"]}
                     for f in fns]
    return json.dumps(out, ensure_ascii=False, separators=(",", ":"))   # compact (committed by CI)


def main():
    F, by_area, nkb, nmi, nme = build()
    nfunc = len(F)
    docs = os.path.join(ROOT, "docs")
    os.makedirs(docs, exist_ok=True)
    open(os.path.join(docs, "PAKETTI-FUNCTIONS.md"), "w", encoding="utf-8").write(
        write_md(by_area, nkb, nmi, nme, nfunc))
    open(os.path.join(docs, "paketti-functions.json"), "w", encoding="utf-8").write(
        write_json(by_area))
    print(f"functions: {nfunc:,} · keybindings {nkb:,} · midimappings {nmi:,} · menu {nme:,}")
    print("wrote docs/PAKETTI-FUNCTIONS.md + docs/paketti-functions.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
