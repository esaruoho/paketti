#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# gen-sessions.py -- plug the Claude CONVERSATIONS into the card tooling. Scans
# THIS repo's Claude transcripts and GENERATES SESSIONS.generated.md: every
# card-relevant session with its date span, a `claude --resume <id>` get-back
# command, and the card artifacts it touched. Conversation <-> tooling,
# auto-linked -- nobody hand-types the session list.
#
# This is what makes the ".session" leg of the triad recoverable: a card can
# always point back at the conversation that spawned it, by ID, clickably.
#
# Reads ONLY metadata + filename mentions; it never copies conversation content
# into the repo. Transcripts live OUTSIDE the repo and are machine-local, so this
# is defensive: if the transcripts dir is absent (another clone / CI) it leaves
# the existing generated file untouched and exits 0.
#
# Output is STABLE (date-level spans, sorted sets -- no minute timestamps or line
# counts) so it only changes when a new session appears or an existing one
# reaches a new day / touches a new artifact. No commit churn.
#
# Portable. Usage: python3 gen-sessions.py [--cards-dir <dir>]
# Card home: --cards-dir  >  $REPORT_CARDS_DIR  >  this script's dir.
# -----------------------------------------------------------------------------
import json, glob, os, re, sys

# Superset of every key the impulse-tracker original used, so migrating a repo
# onto this script can only ever ADD a session to the list, never drop one.
RELEVANCE = ('.feature', 'report card', 'report-card', 'convey', 'features/')
FEATURE_RE = re.compile(r'[A-Za-z0-9_./-]+\.feature')
TOOL_HINTS = ('gen-status.py', 'gen-sessions.py', 'print-card.py', 'STATUS.md',
              'INDEX.md', '.githooks/pre-commit', '.githooks/post-merge',
              'report-card-stamp.sh', 'cards.conf')


def resolve_cards_dir(args):
    if '--cards-dir' in args:
        i = args.index('--cards-dir')
        d = args[i + 1]
        del args[i:i + 2]
        return os.path.abspath(d)
    env = os.environ.get('REPORT_CARDS_DIR')
    if env:
        return os.path.abspath(env)
    return os.path.dirname(os.path.abspath(__file__))


def scan(path):
    """(first_date, last_date, touched_set) or None if not card-relevant."""
    first = last = None
    touched = set()
    relevant = False
    try:
        for line in open(path, encoding='utf-8'):
            try:
                o = json.loads(line)
            except Exception:
                continue
            ts = o.get('timestamp')
            if ts:
                d = ts[:10]
                if first is None or d < first: first = d
                if last is None or d > last: last = d
            lo = line.lower()
            if not relevant and any(k in lo for k in RELEVANCE):
                relevant = True
            for m in FEATURE_RE.findall(line):
                touched.add(m.split('/')[-1])
            for t in TOOL_HINTS:
                if t in line:
                    touched.add(t)
    except Exception:
        return None
    if not relevant or first is None:
        return None
    return first, last, touched


def main():
    args = sys.argv[1:]
    cards_dir = resolve_cards_dir(args)
    # repo root = parent of the cards dir (features/ lives at the repo top)
    root = os.path.dirname(cards_dir)

    # Output filename is configurable so a repo that already references a
    # different name (e.g. CONVEY-SESSIONS.generated.md) can migrate onto this
    # script without breaking every doc that links to it.
    #   cards.conf:  sessions_file = CONVEY-SESSIONS.generated.md
    conf = {}
    cpath = os.path.join(cards_dir, 'cards.conf')
    if os.path.exists(cpath):
        for line in open(cpath, encoding='utf-8'):
            s = line.strip()
            if s and not s.startswith('#') and '=' in s:
                k, v = s.split('=', 1)
                conf[k.strip().lower()] = v.strip()
    dst = os.path.join(cards_dir, conf.get('sessions_file', 'SESSIONS.generated.md'))

    # Where Claude keeps this project's transcripts. Two traps, both real:
    #  1. the dir name sanitises EVERY non-alphanumeric to '-' (dots, tildes and
    #     spaces included) -- not just '/'.
    #  2. a repo reached through a symlink (e.g. ~/work/paketti -> an iCloud
    #     folder) has TWO valid slugs, and sessions are split across them.
    # So: build candidates from the literal path AND the resolved path, plus any
    # extra paths named in cards.conf (project_dirs = /a/b,/c/d), and merge.
    base = os.path.expanduser('~/.claude/projects')
    cands, seen = [], set()
    paths = [os.path.abspath(root), os.path.realpath(root)]
    paths += [os.path.expanduser(p.strip())
              for p in conf.get('project_dirs', '').split(',') if p.strip()]
    for p in paths:
        slug = re.sub(r'[^A-Za-z0-9]', '-', p)
        d = os.path.join(base, slug)
        if d not in seen and os.path.isdir(d):
            seen.add(d)
            cands.append(d)
    if not cands:
        tried = ', '.join(sorted({re.sub(r'[^A-Za-z0-9]', '-', p) for p in paths}))
        print(f'[gen-sessions] no transcripts dir for this repo (tried: {tried}); '
              'leaving file as-is')
        return 0

    # Only count cards that ACTUALLY EXIST -- a conversation often mentions
    # example filenames (widget.feature, a.feature) that aren't real.
    real_cards = {os.path.basename(p) for p in glob.glob(os.path.join(cards_dir, '*.feature'))}
    rows = []
    done = set()
    for tx_dir in cands:
        for path in sorted(glob.glob(os.path.join(tx_dir, '*.jsonl'))):
            sid = os.path.basename(path)[:-6]
            if sid in done:      # same session id under two slugs — count once
                continue
            r = scan(path)
            if not r:
                continue
            done.add(sid)
            first, last, touched = r
            span = first if first == last else f'{first} → {last}'
            feats = sorted(t for t in touched
                           if t.endswith('.feature') and t in real_cards)
            tools = sorted(t for t in touched if not t.endswith('.feature'))
            rows.append((first, sid, span, feats, tools, tx_dir))
    rows.sort()

    out = []
    out.append('# Report-Card Sessions (GENERATED, DO NOT EDIT BY HAND)')
    out.append('')
    out.append("> Auto-discovered by `gen-sessions.py` from this machine's Claude")
    out.append('> transcripts. Every card-relevant conversation is plugged in here with a')
    out.append('> `claude --resume` get-back command and the artifacts it touched. This is')
    out.append('> the recoverable ".session" leg of the triad. Hand edits are overwritten.')
    out.append('>')
    out.append('> Metadata only -- no conversation content is copied into the repo. The list')
    out.append('> reflects the machine it was generated on (transcripts are local).')
    out.append('')
    out.append(f'**{len(rows)} card conversations** plugged in:')
    out.append('')
    for first, sid, span, feats, tools, txd in rows:
        out.append(f'### `{sid}`  ({span})')
        out.append(f'- Resume: `claude --resume {sid}`')
        out.append(f'- Transcript: file://{os.path.join(txd, sid)}.jsonl')
        if tools:
            out.append(f'- Tooling touched: {", ".join(tools)}')
        if feats:
            shown = ", ".join(feats[:14]) + (f' … (+{len(feats)-14})' if len(feats) > 14 else '')
            out.append(f'- Cards touched ({len(feats)}): {shown}')
        out.append('')
    text = '\n'.join(out)

    old = open(dst, encoding='utf-8').read() if os.path.exists(dst) else ''
    if text != old:
        open(dst, 'w', encoding='utf-8').write(text)
        print(f'[gen-sessions] {os.path.basename(dst)} regenerated ({len(rows)} sessions)')
    else:
        print(f'[gen-sessions] {os.path.basename(dst)} already current')
    return 0


if __name__ == '__main__':
    sys.exit(main())
