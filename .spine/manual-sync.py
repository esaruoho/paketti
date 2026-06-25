#!/usr/bin/env python3
"""manual-sync.py — ZERO-TOKEN manual sync.

Fills `<!-- AUTO:X -->...<!-- /AUTO -->` blocks in manual/Experimental.md with the real, current
Paketti function data straight from the .spine harness (for-loops resolved). No LLM, no tokens.

  X = counts        → the live ⌨/🎛/☰ totals + function count
  X = experimental  → every Xperimental/WIP + "(Experimental)" function, with its doors
  X = <area name>   → that area's functions (Mixer, Sample Editor, Pattern Editor, …)

Everything OUTSIDE the AUTO markers is your prose and is left untouched. If the manual has no
markers yet, a starter "Auto-Generated Function Reference" section is appended once.

  python3 .spine/manual-sync.py [repo_root]
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/Users/esaruoho/work/paketti")
MANUAL = ROOT / "manual" / "Experimental.md"
INDEX = ROOT / "docs" / "paketti-functions.json"
SPINE = Path("/tmp/manual-sync-spine.json")
GEN = ROOT / ".spine" / "functions.py"

AUTO_RE = re.compile(r"(<!-- AUTO:(.+?) -->)(.*?)(<!-- /AUTO -->)", re.S)

STARTER = """

---

## 📋 Auto-Generated Function Reference

*Zero-token, regenerated from the code on every commit by `.spine/manual-sync.py` — never hand-edit
between the `AUTO` markers. ⌨ = KeyBinding · 🎛 = MidiMapping · ☰ = MenuEntry.*

**Coverage:** <!-- AUTO:counts -->(run manual-sync)<!-- /AUTO -->

### 🧪 Experimental / WIP

<!-- AUTO:experimental -->(run manual-sync)<!-- /AUTO -->
"""


def ensure_index():
    """Regenerate the function index + spine JSON via functions.py (which runs the harness)."""
    subprocess.run([sys.executable, str(GEN), str(ROOT), str(SPINE)], check=False,
                   stdout=subprocess.DEVNULL)


def experimental_funcs():
    names = json.loads(SPINE.read_text(encoding="utf-8"))["names"]
    exp = {}   # cleaned leaf -> set of door glyphs
    for glyph, key in (("⌨", "keybinding"), ("🎛", "midi_mapping"), ("☰", "menu_entry")):
        for n in names[key]:
            leaf = n.split(":")[-1].strip()
            if "xperimental/wip" in n.lower() or "experimental" in leaf.lower():
                e = re.sub(r"x?\[[^\]]*\]", "", leaf).strip()
                if e:
                    exp.setdefault(e, set()).add(glyph)
    return exp


def block_counts(idx):
    nkb = sum(len(f["kb"]) for v in idx.values() for f in v)
    nmi = sum(len(f["midi"]) for v in idx.values() for f in v)
    nme = sum(len(f["menu"]) for v in idx.values() for f in v)
    nfn = sum(len(v) for v in idx.values())
    return (f"⌨ **{nkb:,}** keybindings · 🎛 **{nmi:,}** midimappings · "
            f"☰ **{nme:,}** menu entries → **{nfn:,}** functions")


def block_experimental(exp):
    lines = [f"_{len(exp)} experimental / WIP functions, listed straight from the code:_", ""]
    for e in sorted(exp, key=str.lower):
        lines.append(f"- {' '.join(sorted(exp[e]))} {e}")
    return "\n".join(lines)


def block_area(idx, area):
    fns = sorted(idx.get(area, []), key=lambda f: f["function"].lower())
    lines = [f"_{len(fns)} {area} functions:_", ""]
    for f in fns:
        d = "".join(g for g, k in (("⌨", "kb"), ("🎛", "midi"), ("☰", "menu")) if f.get(k))
        lines.append(f"- {f['function']} — {d}")
    return "\n".join(lines)


def fill(text, idx, exp):
    def repl(m):
        tag = m.group(2).strip()
        low = tag.lower()
        if low == "counts":
            body = block_counts(idx)
        elif low == "experimental":
            body = block_experimental(exp)
        else:
            area = next((a for a in idx if a.lower() == low or low in a.lower()), None)
            body = block_area(idx, area) if area else f"_(no area matching “{tag}”)_"
        return f"{m.group(1)}\n{body}\n{m.group(4)}"
    return AUTO_RE.sub(repl, text)


def main():
    ensure_index()
    idx = json.loads(INDEX.read_text(encoding="utf-8"))
    exp = experimental_funcs()
    text = MANUAL.read_text(encoding="utf-8")
    if not AUTO_RE.search(text):
        text = text.rstrip() + STARTER          # seed the markers once
    text = fill(text, idx, exp)
    MANUAL.write_text(text, encoding="utf-8")
    print(f"synced manual/Experimental.md — {len(exp)} experimental, "
          f"{sum(len(v) for v in idx.values())} functions (zero tokens)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
