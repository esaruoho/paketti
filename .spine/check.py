#!/usr/bin/env python3
"""check.py — CI gate: fail the build if Paketti can't load cleanly.

Runs the registration harness (Paketti's real add_* code under a mocked Renoise)
and FAILS (exit 1) on anything that would crash or degrade a real Renoise load:

  • duplicate MIDI mappings  — Renoise throws "invalid midi mapping entry: 'X' was
    already added" and aborts the tool load (this shipped once and broke users).
  • duplicate keybindings    — same fatal duplicate guard.
  • brittle files            — a source file that errors during registration.
  • malformed keybindings    — keybinding names must be exactly three
    colon-separated parts: "Context:Topic:Name". Extra colons crash Renoise.
  • local-variable headroom  — WARNING only. Lua allows 200 locals live at once in one
    function, and a .lua file is a function, so every chunk-level `local` in a module
    spends one. Cross the line and the file will not compile at all — which arrives as a
    brittle file and a dead tool load, with no runtime warning first. This reports any
    file with less than 25 locals of room left, so it can be refactored on purpose
    instead of on the day an edit tips it over.
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
LOCALROOM = os.path.join(ROOT, ".spine", "localroom.lua")
LOCALROOM_OUT = os.path.join(ROOT, ".spine", "localroom.json")
LOCALROOM_WARN = 25   # warn when a file has fewer than this many chunk-level locals left

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


# ── static scan: a call to something not declared yet, or not declared at all ─────────────────
# Renoise runs with strict globals: reading a name that was never assigned THROWS rather than
# returning nil. Two shapes of that keep shipping, and neither is a syntax error, so luac and the
# harness both pass them:
#   * `foo()` where `local function foo` appears LATER in the same file — the earlier line reads a
#     global that does not exist. Dormant until that path runs. (MM_STRUM_MS and mm_rand in
#     PakettiMusicMouse.lua were both sitting like this.)
#   * `foo()` where nothing anywhere defines foo — a rename that missed a call site, or a menu
#     entry pointing at a deleted function. Throws the moment the user clicks it.
# Advisory, not a gate: the tree already carries a backlog of the second kind.
_KW = set("and break do else elseif end false for function goto if in local nil not or repeat "
          "return then true until while self".split())
_BUILTIN = set("assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile "
               "loadstring next pairs pcall print rawequal rawget rawlen rawset require select "
               "setfenv setmetatable tonumber tostring type unpack xpcall math table string os io "
               "coroutine debug bit renoise class ProcessSlicer".split())


def _strip_lua(text):
    """Blank out comments and string literals so menu paths and prose cannot look like calls."""
    text = re.sub(r'--\[\[.*?\]\]', '', text, flags=re.S)
    text = re.sub(r'\[\[.*?\]\]', '""', text, flags=re.S)
    out = []
    for line in text.split('\n'):
        line = re.sub(r'"(\\.|[^"\\])*"', '""', line)
        line = re.sub(r"'(\\.|[^'\\])*'", "''", line)
        out.append(re.sub(r'--.*$', '', line))
    return out


def _undeclared_calls(root):
    paths = [p for p in glob.glob(os.path.join(root, '**', '*.lua'), recursive=True)
             if '/.git/' not in p and '/.spine/' not in p]
    code = {}
    for p in paths:
        try:
            code[p] = _strip_lua(open(p, encoding='utf-8', errors='ignore').read())
        except OSError:
            pass
    tool_globals = set()
    for lines in code.values():
        joined = '\n'.join(lines)
        tool_globals |= set(re.findall(r'^\s*function\s+(' + _IDENT + r')\s*[\(.:]', joined, re.M))
        tool_globals |= set(re.findall(r'^\s*(' + _IDENT + r')\s*=', joined, re.M))
    out = []
    for p, lines in code.items():
        joined = '\n'.join(lines)
        declared = {}
        for i, line in enumerate(lines, 1):
            for m in re.finditer(r'\blocal\s+(?:function\s+)?(' + _IDENT +
                                 r'(?:\s*,\s*' + _IDENT + r')*)', line):
                for name in m.group(1).split(','):
                    name = name.strip()
                    if name and name not in declared:
                        declared[name] = i
        params = set()
        for m in re.finditer(r'function\s*[\w.:]*\s*\(([^)]*)\)', joined):
            params |= {x.strip() for x in m.group(1).split(',')
                       if x.strip() and x.strip() != '...'}
        for i, line in enumerate(lines, 1):
            for m in re.finditer(r'(?<![\w.:])(' + _IDENT + r')\s*\(', line):
                name = m.group(1)
                if name in _KW or name in _BUILTIN or name in params or name in tool_globals:
                    continue
                rel = os.path.relpath(p, root)
                if name in declared:
                    if i < declared[name]:
                        out.append((rel, i, name, "declared later in this file (line %d) — this "
                                    "line reads an undeclared global" % declared[name]))
                else:
                    out.append((rel, i, name, "never declared anywhere in the tool"))
    return out


def _malformed_keybindings(names):
    """Renoise keybinding names are `Context:Topic:Name`.
    Subcategories must be flattened into the final name part instead of adding
    extra colons."""
    out = []
    for name in names:
        parts = str(name).split(":")
        if len(parts) != 3 or not all(parts):
            out.append(str(name))
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


def _local_headroom():
    """Files running out of Lua's 200-locals-per-chunk budget. The probe asks the real
    compiler (append N dummy locals, see if it still builds), so the number is exact.
    Returns [] if no Lua interpreter is available — this is advisory, never a hard gate."""
    lj = shutil.which("luajit") or shutil.which("lua")
    if not lj or not os.path.exists(LOCALROOM):
        return []
    subprocess.run([lj, LOCALROOM, ROOT, str(LOCALROOM_WARN), LOCALROOM_OUT],
                   timeout=300, check=False, stdout=subprocess.DEVNULL)
    try:
        with open(LOCALROOM_OUT) as f:
            rows = json.load(f)
        os.unlink(LOCALROOM_OUT)
    except (OSError, ValueError):
        return []
    return sorted(rows, key=lambda r: r["headroom"])


def main():
    d = run()
    dups = d.get("duplicates", {})
    dup_mi = dups.get("midi_mapping", [])
    dup_kb = dups.get("keybinding", [])
    brittle = [f for f in d.get("files", []) if not f.get("ok")]
    fs = d["file_stats"]
    selfref = _self_ref_violations(ROOT)
    tight = _local_headroom()
    undecl = _undeclared_calls(ROOT)
    malformed_kb = _malformed_keybindings(d.get("names", {}).get("keybinding", []))

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
    if malformed_kb:
        fail = True
        print(f"\n❌ {len(malformed_kb)} MALFORMED KEYBINDING NAME(S) — Renoise keybindings "
              "must be exactly `Context:Topic:Name`:")
        for n in malformed_kb:
            print(f"   • {n}")
        print("       fix: remove extra ':' characters from the name part; use spaces, /, or - "
              "for subcategories.")
    if brittle:
        fail = True
        print(f"\n❌ {len(brittle)} BRITTLE FILE(S) (errored during registration):")
        for f in brittle:
            print(f"   • {f['module']} — {f.get('err','')[:160]}")

    if undecl:
        print(f"\n⚠️  {len(undecl)} CALL(S) TO SOMETHING NOT DECLARED — Renoise strict globals "
              "throw on these at runtime, and neither luac nor the harness catches them:")
        late = [r for r in undecl if "declared later" in r[3]]
        gone = [r for r in undecl if r not in late]
        for label, rows in (("used before it is declared", late), ("no definition anywhere", gone)):
            if not rows:
                continue
            print(f"   {label}: {len(rows)}")
            for f, ln, name, why in rows[:12]:
                print(f"     • {f}:{ln}  {name}()  — {why}")
            if len(rows) > 12:
                print(f"     … and {len(rows) - 12} more")
        print("       fix: move the definition above its first use, or restore the missing function.")

    if tight:
        print(f"\n⚠️  {len(tight)} FILE(S) LOW ON LOCAL-VARIABLE HEADROOM (Lua allows 200 per "
              "chunk; over the line the file will not compile and the whole tool load dies):")
        for r in tight:
            print(f"   • {r['file']} — room for {r['headroom']} more top-level `local`s")
        print("       fix: fold groups of constants into one table, wrap a self-contained")
        print("       section in `do ... end` so its locals go out of scope, promote")
        print("       prefixed helpers to plain globals (the PakettiEightOneTwenty style),")
        print("       or split the module. Not a build failure — yet.")

    try:
        os.unlink(OUT)
    except OSError:
        pass

    if fail:
        print("\nFAILED — fix the above before this can ship. Each of these aborts the whole "
              "tool load in real Renoise: a duplicate add_midi_mapping/add_keybinding, a file "
              "that errors at load, a malformed keybinding name, or a global read before it is "
              "declared (strict-globals).")
        return 1
    print("\n✅ clean — no duplicate registrations, no brittle files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
