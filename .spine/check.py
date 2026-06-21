#!/usr/bin/env python3
"""check.py — CI gate: fail the build if Paketti can't load cleanly.

Runs the registration harness (Paketti's real add_* code under a mocked Renoise)
and FAILS (exit 1) on anything that would crash or degrade a real Renoise load:

  • duplicate MIDI mappings  — Renoise throws "invalid midi mapping entry: 'X' was
    already added" and aborts the tool load (this shipped once and broke users).
  • duplicate keybindings    — same fatal duplicate guard.
  • brittle files            — a source file that errors during registration.

Run locally before committing, and in CI on every push / PR:

    python3 .spine/check.py [repo_root]
"""
import json, os, shutil, subprocess, sys

ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
HARNESS = os.path.join(ROOT, ".spine", "harness.lua")
OUT = os.path.join(ROOT, ".spine", "check.json")


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

    print(f"Paketti registration check — {d['unique']['keybinding']:,} keybindings · "
          f"{d['unique']['midi_mapping']:,} MIDI · {d['unique']['menu_entry']:,} menus · "
          f"{fs['loaded']}/{fs['total']} files loaded")

    fail = False
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
        print("\nFAILED — fix the above before this can ship. A duplicate add_midi_mapping/"
              "add_keybinding aborts the whole tool load in real Renoise.")
        return 1
    print("\n✅ clean — no duplicate registrations, no brittle files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
