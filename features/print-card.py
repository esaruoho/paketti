#!/usr/bin/env python3
"""print-card.py — turn report-card .feature files into printable/browsable output.

Portable: no dependencies (Apple-native python3), no regex backtracking risk
(plain prefix/string matching only). Works in ANY repo — behaviour is tuned by an
optional `cards.conf` sitting next to the cards.

For each input .feature (the comment-banner-wrapped report card) it writes into
<cards>/dist/:

  <name>.gherkin.feature   the PURE Gherkin test: banner-comment block stripped,
                           leaving Feature/Scenario/Given-When-Then (inline
                           `# cite:` traceability comments kept). The file a
                           Gherkin runner would consume.

  <name>.card.md           the printable REPORT CARD: title + narrative, then
                           every scenario with its grade tags and steps, plus a
                           grade tally. Render to RTF with `rtfc` to print/paste.

And a browsable reference for the whole set:

  <cards>/README.md        one section per card — "what it does" (intent +
                           behaviour scenarios) and "how it does it" (the
                           procs/files the behaviour is cited to), with grade +
                           commits. GENERATED — never hand-edit.

Usage:
  python3 print-card.py <cards>/foo.feature [...]   # per-card dist/ output
  python3 print-card.py --all                       # every card
  python3 print-card.py --readme                    # regenerate README.md
  python3 print-card.py --cards-dir <dir> --all     # explicit card home

Card home resolution (first hit wins):
  1. --cards-dir <dir>
  2. $REPORT_CARDS_DIR
  3. the directory this script lives in (drop it in features/ and it Just Works)

cards.conf (optional, key=value, `#` comments) next to the cards:
  title       = Foo Project — Feature Reference
  readme_file = CARDS.md          # target for --readme (default README.md;
                                  # set this if features/README.md is hand-written)
  source_ext  = .asm,.inc,.py,.lua,.c,.h,.ts
  meta_prefix = session-,day-
  readme_exclude = a-card-to-hide-entirely.feature

Note: `exclude` in cards.conf is gen-status.py's (the test matrix). The README
lists every card; rollups/meta ones are grouped by `meta_prefix`.
"""
import sys
import os

GRADE_TAGS = (
    "@shipped", "@build-verified", "@runtime-verified", "@runtime-untested",
    "@designed", "@built", "@sim-verified", "@hw-verified", "@hw-untested",
    "@untested", "@todo", "@stock", "@partial", "@code-verified",
)

DEFAULT_SOURCE_EXT = (".asm", ".inc", ".py", ".lua", ".c", ".h", ".cpp",
                      ".ts", ".js", ".rb", ".go", ".rs", ".swift", ".sch")


# ---------------------------------------------------------------------------
# config
# ---------------------------------------------------------------------------

def load_conf(cards_dir):
    conf = {}
    path = os.path.join(cards_dir, "cards.conf")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            s = line.strip()
            if not s or s.startswith("#") or "=" not in s:
                continue
            k, v = s.split("=", 1)
            conf[k.strip().lower()] = v.strip()
    return conf


def conf_list(conf, key, default):
    raw = conf.get(key)
    if not raw:
        return list(default)
    return [x.strip() for x in raw.split(",") if x.strip()]


# ---------------------------------------------------------------------------
# card parsing
# ---------------------------------------------------------------------------

def split_banner(lines):
    """(banner_lines, body_lines). Banner = leading `#`/blank block before the
    first `Feature:` line."""
    body_start = 0
    for i, ln in enumerate(lines):
        if ln.lstrip().startswith("Feature:"):
            body_start = i
            break
    return lines[:body_start], lines[body_start:]


def parse_scenarios(body):
    """[{tags, title, steps, cites}] — one entry per Scenario."""
    scenarios = []
    pending_tags = []
    cur = None
    for raw in body:
        s = raw.strip()
        if s.startswith("@"):
            pending_tags = [t for t in s.split() if t.startswith("@")]
            continue
        if s.startswith("Scenario"):
            if cur:
                scenarios.append(cur)
            # handles both "Scenario:" and "Scenario Outline:" — split on the
            # colon rather than assuming a fixed prefix length.
            cur = {"tags": pending_tags,
                   "title": (s.split(":", 1)[1].strip() if ":" in s else s),
                   "steps": [], "cites": []}
            pending_tags = []
            continue
        if cur is None:
            continue
        if s.startswith("# cite:"):
            cur["cites"].append(s[len("# cite:"):].strip())
            continue
        if s.startswith("#") or s == "":
            continue
        cur["steps"].append(s)
    if cur:
        scenarios.append(cur)
    return scenarios


def feature_title_and_narrative(body):
    title = ""
    narrative = []
    for ln in body:
        s = ln.strip()
        if s.startswith("Feature:"):
            title = s[len("Feature:"):].strip()
            continue
        if title and (s.startswith("@") or s.startswith("Scenario")):
            break
        if title and s and not s.startswith("#"):
            narrative.append(s)
    return title, narrative


def grade_of(tags):
    return [t for t in tags if t in GRADE_TAGS]


# ---------------------------------------------------------------------------
# per-card outputs
# ---------------------------------------------------------------------------

def write_gherkin(dist_dir, cards_rel, name, body):
    out = os.path.join(dist_dir, name + ".gherkin.feature")
    b = list(body)
    while b and b[0].strip() == "":
        b.pop(0)
    header = (
        "# Pure Gherkin test extracted from %s/%s.feature\n"
        "# (report-card banner stripped; inline # cite: traceability kept)\n"
        "# Regenerate: python3 print-card.py %s/%s.feature\n\n"
        % (cards_rel, name, cards_rel, name)
    )
    with open(out, "w", encoding="utf-8") as f:
        f.write(header)
        f.writelines(b)
    return out


def write_card(dist_dir, cards_rel, name, body):
    title, narrative = feature_title_and_narrative(body)
    scenarios = parse_scenarios(body)
    tally = {}
    for sc in scenarios:
        for g in grade_of(sc["tags"]):
            tally[g] = tally.get(g, 0) + 1
    out = os.path.join(dist_dir, name + ".card.md")
    L = []
    L.append("# Report Card — %s\n" % title)
    L.append("> Source: `%s/%s.feature` · printable rendering · "
             "regenerate with `python3 print-card.py`\n" % (cards_rel, name))
    if narrative:
        L.append("**Intent:** " + " ".join(narrative) + "\n")
    if tally:
        L.append("**Grades:** " +
                 " · ".join("%s × %d" % (g, n) for g, n in sorted(tally.items())) + "\n")
    L.append("**Scenarios: %d**\n" % len(scenarios))
    L.append("\n---\n")
    for i, sc in enumerate(scenarios, 1):
        gr = " ".join(sc["tags"]) if sc["tags"] else "(ungraded)"
        L.append("\n## %d. %s\n" % (i, sc["title"]))
        L.append("`%s`\n" % gr)
        if sc["steps"]:
            L.append("")
            for st in sc["steps"]:
                L.append("- %s" % st)
            L.append("")
        if sc["cites"]:
            L.append("<sub>cite: " + " · ".join(sc["cites"]) + "</sub>\n")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    return out


# ---------------------------------------------------------------------------
# README ("what it does" + "how it does it")
# ---------------------------------------------------------------------------

def _is_hex7(tok):
    return len(tok) >= 7 and all(c in "0123456789abcdef" for c in tok[:7].lower())


def extract_watch(banner):
    """The procs/symbols the card watches (its 'how' surface)."""
    for ln in banner:
        s = ln.strip()
        if s.startswith("#") and "WATCH:" in s:
            return s.split("WATCH:", 1)[1].strip().split()
    return []


def extract_commits(banner):
    """(hash, desc) for any banner line whose first token is a 7-hex hash."""
    out, seen = [], set()
    for ln in banner:
        toks = ln.strip().lstrip("#").strip().split()
        if toks and _is_hex7(toks[0]) and toks[0] not in seen:
            seen.add(toks[0])
            out.append((toks[0], " ".join(toks[1:])))
    return out


def extract_files(scenarios, source_ext):
    """Distinct source files named in the scenario cites (the 'how' innards)."""
    files = []
    for sc in scenarios:
        for c in sc["cites"]:
            for tok in c.replace(",", " ").split():
                low = tok.lower()
                if any(low.endswith(e) for e in source_ext) and tok not in files:
                    files.append(tok)
    return files


def build_readme(cards_dir, paths, conf):
    cards_rel = os.path.basename(os.path.abspath(cards_dir))
    title_txt = conf.get("title") or (
        os.path.basename(os.path.dirname(os.path.abspath(cards_dir)) or "Project")
        + " — Feature Reference")
    source_ext = [e if e.startswith(".") else "." + e
                  for e in conf_list(conf, "source_ext", DEFAULT_SOURCE_EXT)]
    meta_prefix = tuple(conf_list(conf, "meta_prefix", ("session-", "day-")))

    behaviour, meta = [], []
    for p in sorted(paths):
        name = os.path.splitext(os.path.basename(p))[0]
        with open(p, encoding="utf-8") as f:
            lines = f.readlines()
        banner, body = split_banner(lines)
        ftitle, narrative = feature_title_and_narrative(body)
        scenarios = parse_scenarios(body)
        tally = {}
        for sc in scenarios:
            for g in grade_of(sc["tags"]):
                tally[g] = tally.get(g, 0) + 1
        rec = {
            "name": name, "title": ftitle or name, "narrative": narrative,
            "scenarios": scenarios, "tally": tally,
            "watch": extract_watch(banner), "commits": extract_commits(banner),
            "files": extract_files(scenarios, source_ext),
            "has_session": os.path.exists(
                os.path.join(cards_dir, name + ".session.md")),
        }
        (meta if name.startswith(meta_prefix) else behaviour).append(rec)

    L = []
    L.append("# %s\n" % title_txt)
    L.append("> **Generated** from the Gherkin report cards in this folder by "
             "`python3 print-card.py --readme`. Do not hand-edit — edit the "
             "`.feature` card and regenerate. Each entry below = one card: "
             "*what it does* (intent + behaviour scenarios) and *how it does it* "
             "(the procs/files the behaviour is cited to).\n")
    L.append("Each card is a triad: the `.feature` spec, a `.session.md` (the "
             "conversation that produced it), and a RESULT-LOG of what shipped.\n")

    L.append("## Contents\n")
    for rec in behaviour:
        L.append("- [%s](#%s) — `%s.feature`" % (rec["title"], rec["name"], rec["name"]))
    L.append("")

    def emit(rec):
        L.append('\n<a id="%s"></a>' % rec["name"])
        L.append("## %s\n" % rec["title"])
        src = "`%s/%s.feature`" % (cards_rel, rec["name"])
        if rec["has_session"]:
            src += " · [session](%s.session.md)" % rec["name"]
        L.append("%s\n" % src)
        if rec["narrative"]:
            L.append("**What it does:** " + " ".join(rec["narrative"]) + "\n")
        if rec["scenarios"]:
            L.append("**Behaviour (%d scenario%s):**\n" %
                     (len(rec["scenarios"]), "" if len(rec["scenarios"]) == 1 else "s"))
            for sc in rec["scenarios"]:
                tags = " ".join(t for t in sc["tags"] if t in GRADE_TAGS)
                L.append("- %s%s" % (sc["title"], (" — `%s`" % tags) if tags else ""))
            L.append("")
        how = []
        if rec["watch"]:
            how.append("**Key procs:** " + ", ".join("`%s`" % w for w in rec["watch"]))
        if rec["files"]:
            how.append("**Source files:** " + ", ".join("`%s`" % f for f in rec["files"]))
        if how:
            L.append("**How it does it:** " + " · ".join(how) + "\n")
        if rec["tally"]:
            L.append("**Grade:** " +
                     " · ".join("%s ×%d" % (g, n) for g, n in sorted(rec["tally"].items())) + "\n")
        if rec["commits"]:
            L.append("**Commits:** " +
                     " · ".join("`%s` %s" % (h, d) for h, d in rec["commits"][:12]) + "\n")

    for rec in behaviour:
        emit(rec)

    if meta:
        L.append("\n---\n")
        L.append("## Meta / session cards\n")
        L.append("These document the report-card *process* itself, not a product "
                 "behaviour.\n")
        for rec in meta:
            L.append("- **%s** — `%s/%s.feature`%s" %
                     (rec["title"], cards_rel, rec["name"],
                      " · [session](%s.session.md)" % rec["name"] if rec["has_session"] else ""))
        L.append("")

    # Output name is configurable (cards.conf: readme_file = CARDS.md) so a repo
    # with a HAND-WRITTEN features/README.md never gets it clobbered by a
    # generated one. Default stays README.md for greenfield installs.
    out = os.path.join(cards_dir, conf.get("readme_file", "README.md"))
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    return out, len(behaviour), len(meta)


# ---------------------------------------------------------------------------

def resolve_cards_dir(args):
    if "--cards-dir" in args:
        i = args.index("--cards-dir")
        d = args[i + 1]
        del args[i:i + 2]
        return os.path.abspath(d)
    env = os.environ.get("REPORT_CARDS_DIR")
    if env:
        return os.path.abspath(env)
    return os.path.dirname(os.path.abspath(__file__))


def all_feature_paths(cards_dir, conf):
    # NOTE: `exclude` belongs to gen-status.py (the test matrix). The README is a
    # full reference and lists every card, including rollups/meta — those land in
    # the "Meta / session cards" section via meta_prefix. Use `readme_exclude`
    # only to hide a card from the README entirely.
    excl = set(conf_list(conf, "readme_exclude", ()))
    return [os.path.join(cards_dir, f) for f in sorted(os.listdir(cards_dir))
            if f.endswith(".feature") and f not in excl]


def main(argv):
    args = argv[1:]
    if not args:
        print(__doc__)
        return 1
    cards_dir = resolve_cards_dir(args)
    if not os.path.isdir(cards_dir):
        print("no such cards dir: %s" % cards_dir)
        return 1
    conf = load_conf(cards_dir)
    cards_rel = os.path.basename(cards_dir)
    dist_dir = os.path.join(cards_dir, "dist")

    if "--readme" in args:
        out, nb, nm = build_readme(cards_dir, all_feature_paths(cards_dir, conf), conf)
        print("wrote %s" % out)
        print("   %d behaviour cards, %d meta/session cards" % (nb, nm))
        args = [a for a in args if a != "--readme"]
        if not args:
            return 0
    if args == ["--all"]:
        args = all_feature_paths(cards_dir, conf)
    os.makedirs(dist_dir, exist_ok=True)
    for p in args:
        if not os.path.exists(p):
            print("skip (not found): %s" % p)
            continue
        name = os.path.splitext(os.path.basename(p))[0]
        with open(p, encoding="utf-8") as f:
            lines = f.readlines()
        _banner, body = split_banner(lines)
        g = write_gherkin(dist_dir, cards_rel, name, body)
        c = write_card(dist_dir, cards_rel, name, body)
        print("%s" % os.path.basename(p))
        print("   -> %s" % os.path.relpath(g, cards_dir))
        print("   -> %s" % os.path.relpath(c, cards_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
