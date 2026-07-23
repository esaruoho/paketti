#!/usr/bin/env python3
"""check.py — CI gate: fail the build if Paketti can't load cleanly.

Runs the registration harness (Paketti's real add_* code under a mocked Renoise)
and FAILS (exit 1) on anything that would crash or degrade a real Renoise load:

  • duplicate MIDI mappings  — Renoise throws "invalid midi mapping entry: 'X' was
    already added" and aborts the tool load (this shipped once and broke users).
  • duplicate keybindings    — same fatal duplicate guard.
  • brittle files            — a source file that errors during registration.
  • self-referential globals — `PakettiFoo = PakettiFoo or {}` reads the global on
    the RHS before it exists; Renoise strict-globals mode throws "variable X is not
    declared" AT LOAD TIME and aborts the whole tool load. This shipped 2026-07-23
    in PakettiStepMute (3 user reports). The harness can't catch it — its mocked _G
    returns a stub for undeclared reads — so we scan for it statically here.

Run locally before committing, and in CI on every push / PR:

    python3 .spine/check.py [repo_root]
"""
import glob, json, os, re, shutil, subprocess, sys

ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
HARNESS = os.path.join(ROOT, ".spine", "harness.lua")
OUT = os.path.join(ROOT, ".spine", "check.json")

# ── static scan: self-referential read of an undeclared Paketti global ────────
_IDENT  = r'[A-Za-z_][A-Za-z0-9_]*'
_ASSIGN = re.compile(r'^(?P<name>' + _IDENT + r')\s*=\s*(?P<rhs>.*)$')  # col-0 only
_LOCAL  = re.compile(r'^\s*local\s+(?:function\s+)?(' + _IDENT + r')')
_FUNC   = re.compile(r'^\s*function\s+(' + _IDENT + r')')


def _self_ref_violations(root):
    """`PakettiFoo = PakettiFoo or {}` at module scope, first mention of the name.
    Precision guards keep this at zero false positives on the current tree:
    column 0 (not indented table fields), Paketti-prefixed, bare self-reference
    (RHS `name` not preceded by '.'/':'/word char), first occurrence only, and
    names given a `local` are ignored."""
    out = []
    for path in sorted(glob.glob(os.path.join(root, "*.lua"))):
        seen, locs = set(), set()
        for i, raw in enumerate(open(path, encoding='utf-8', errors='replace'), 1):
            code = raw.split('--', 1)[0]
            m = _LOCAL.match(code)
            if m:
                locs.add(m.group(1)); seen.add(m.group(1)); continue
            m = _FUNC.match(code)
            if m:
                seen.add(m.group(1)); continue
            m = _ASSIGN.match(code)
            if m:
                name, rhs = m.group('name'), m.group('rhs')
                if (name[:7] in ("Paketti", "paketti", "PAKETTI")
                        and name not in seen and name not in locs
                        and re.search(r'(?<![.:\w])' + re.escape(name) + r'\b', rhs)):
                    out.append((os.path.basename(path), i, name, raw.rstrip()))
                seen.add(name)
    return out


def run():
    lj = shutil.which("luajit") or shutil.which("lua")
    if not lj:
        sys.exit("check.py: need luajit (apt-get install luajit / brew install luajit)")
    subprocess.run([lj, HARNESS, ROOT, OUT], timeout=300, check=False,
                   stdout=subprocess.DEVNULL)
    if not os.path.exists(OUT):
        sys.exit("check.py: harness produced no output")
    with open(OUT) as f:
        return json.load(f)


def main():
    d = run()
    dups = d.get("duplicates", {})
    dup_mi = dups.get("midi_mapping", [])
    dup_kb = dups.get("keybinding", [])
    brittle = [f for f in d.get("files", []) if not f.get("ok")]
    fs = d["file_stats"]
    selfref = _self_ref_violations(ROOT)

    print(f"Paketti registration check — {d['unique']['keybinding']:,} keybindings · "
          f"{d['unique']['midi_mapping']:,} MIDI · {d['unique']['menu_entry']:,} menus · "
          f"{fs['loaded']}/{fs['total']} files loaded")

    fail = False
    if selfref:
        fail = True
        print(f"\n❌ {len(selfref)} SELF-REFERENTIAL GLOBAL(S) — Renoise strict-globals "
              f"will abort the whole tool load:")
        for fn, ln, name, text in selfref:
            print(f"   • {fn}:{ln}  '{name}' is read before it is declared")
            print(f"       {text.strip()}")
            print(f"       fix: initialise without reading it, e.g. `{name} = {{}}`")
    if dup_mi:
        fail = True
        print(f"\n❌ {len(dup_mi)} DUPLICATE MIDI MAPPING(S) — Renoise will refuse to load:")
        for n in dup_mi:
            print(f"   • {n}")
    if dup_kb:
        fail = True
        print(f"\n❌ {len(dup_kb)} DUPLICATE KEYBINDING(S) — Renoise will refuse to load:")
        for n in dup_kb:
            print(f"   • {n}")
    if brittle:
        fail = True
        print(f"\n❌ {len(brittle)} BRITTLE FILE(S) (errored during registration):")
        for f in brittle:
            print(f"   • {f['module']} — {f.get('err','')[:160]}")

    try:
        os.unlink(OUT)
    except OSError:
        pass

    if fail:
        print("\nFAILED — fix the above before this can ship. Each of these aborts the whole "
              "tool load in real Renoise: a duplicate add_midi_mapping/add_keybinding, a file "
              "that errors at load, or a global read before it is declared (strict-globals).")
        return 1
    print("\n✅ clean — no duplicate registrations, no brittle files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
