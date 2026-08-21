#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# gen-status.py -- compute STATUS.md from the @grade tags in the .feature cards.
#
# The CARDS ARE THE SOURCE OF TRUTH; the status table is DERIVED, never
# hand-typed. This is the Convey principle: tests ARE the features, features
# become the index, so nobody can hand-type "runtime-verified" into a list that
# then drifts and lies.
#
# Portable: no dependencies, works in any repo. Run manually:
#     python3 gen-status.py [--cards-dir <dir>]
# or let the pre-commit hook run it whenever a *.feature is staged.
#
# Card home resolution: --cards-dir  >  $REPORT_CARDS_DIR  >  this script's dir.
#
# Optional `cards.conf` next to the cards:
#     exclude         = meta-card.feature,day-rollup.feature
#     runtime_label   = Runtime (DOSBox)
#     hardware_label  = Hardware
#     status_note     = Runtime = emulation. Hardware = real metal.
#
# Deterministic: output is a pure function of the cards (NO timestamp embedded),
# so it only changes when a card's grades change -- no commit churn.
# -----------------------------------------------------------------------------
import glob, os, sys


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


def load_conf(cards_dir):
    conf = {}
    p = os.path.join(cards_dir, 'cards.conf')
    if os.path.exists(p):
        for line in open(p, encoding='utf-8'):
            s = line.strip()
            if not s or s.startswith('#') or '=' not in s:
                continue
            k, v = s.split('=', 1)
            conf[k.strip().lower()] = v.strip()
    return conf


def card_tags(path, gmap):
    """(scenario_count, set_of_grade_tags) from a .feature card.

    gmap translates a repo's OWN grade vocabulary into the canonical tiers, so a
    project keeps the words that mean something to it (@untested-in-renoise) and
    still gets a correct matrix. Both the original and the mapped tag are kept:
    the matrix reads the canonical one, "Grades present" shows the real one.
    """
    scn, tags = 0, set()
    for line in open(path, encoding='utf-8'):
        s = line.lstrip()
        if s.startswith('Scenario'):
            scn += 1
        elif s.startswith('@'):
            for tok in s.split():
                if tok.startswith('@'):
                    tags.add(tok)
                    if tok in gmap:
                        tags.add(gmap[tok])
    return scn, tags


def load_grade_map(conf):
    """cards.conf:  grade_map = @their-tag:@canonical-tag, @other:@canonical"""
    gmap = {}
    for pair in conf.get('grade_map', '').split(','):
        pair = pair.strip()
        if ':' in pair:
            k, v = pair.split(':', 1)
            gmap[k.strip()] = v.strip()
    return gmap


def mark(yes, no, unknown='—'):
    return '✓' if yes else ('✗' if no else unknown)


def main():
    args = sys.argv[1:]
    cards_dir = resolve_cards_dir(args)
    conf = load_conf(cards_dir)
    exclude = {x.strip() for x in conf.get('exclude', '').split(',') if x.strip()}
    gmap = load_grade_map(conf)
    rt_label = conf.get('runtime_label', 'Runtime')
    hw_label = conf.get('hardware_label', 'Hardware')

    rows = []
    n_build = n_rt_full = n_rt_partial = n_hw = n_hw_un = 0
    for path in sorted(glob.glob(os.path.join(cards_dir, '*.feature'))):
        name = os.path.basename(path)
        if name in exclude:
            continue
        scn, t = card_tags(path, gmap)
        if not scn:
            continue
        build = ('@build-verified' in t) or ('@code-verified' in t)
        rt_v = '@runtime-verified' in t
        rt_u = '@runtime-untested' in t
        hw_v = '@hw-verified' in t
        hw_u = '@hw-untested' in t
        # runtime: ✓ all verified / ~ partial (verified AND untested) / ✗ only untested
        if rt_v and rt_u:
            runtime = '~ partial'; n_rt_partial += 1
        elif rt_v:
            runtime = '✓'; n_rt_full += 1
        elif rt_u:
            runtime = '✗'
        else:
            runtime = '—'
        if build: n_build += 1
        if hw_v: n_hw += 1
        elif hw_u: n_hw_un += 1
        rows.append((name.replace('.feature', ''), scn, mark(build, not build),
                     runtime, mark(hw_v, hw_u), ' '.join(sorted(t))))

    out = []
    out.append('# Feature Test Status — GENERATED, DO NOT EDIT BY HAND')
    out.append('')
    out.append('> Computed by `gen-status.py` from the `@grade` tags in `*.feature`.')
    out.append('> The cards are the source of truth; this table is derived. The pre-commit')
    out.append('> hook regenerates it whenever a card changes, so nobody hand-types')
    out.append('> "runtime-verified" into an index again. Hand edits here will be')
    out.append("> overwritten -- change the card's tags instead.")
    note = conf.get('status_note')
    if note:
        out.append('>')
        out.append('> ' + note)
    out.append('>')
    out.append('> `~ partial` = some scenarios verified, some still untested.')
    out.append('')
    out.append(f'| Card | Scn | Build | {rt_label} | {hw_label} | Grades present |')
    out.append('|------|----:|:-----:|:----------:|:--------:|----------------|')
    for name, scn, b, rt, hw, grades in rows:
        out.append(f'| {name} | {scn} | {b} | {rt} | {hw} | {grades} |')
    out.append('')
    out.append('## Tally (computed)')
    out.append(f'- Cards: {len(rows)}')
    out.append(f'- Build-verified: {n_build}')
    out.append(f'- Runtime-verified: {n_rt_full} full + {n_rt_partial} partial')
    out.append(f'- **Hardware-verified: {n_hw}**  ·  hardware-untested: {n_hw_un}')
    out.append('')
    text = '\n'.join(out) + '\n'

    dst = os.path.join(cards_dir, 'STATUS.md')
    old = open(dst, encoding='utf-8').read() if os.path.exists(dst) else ''
    if text != old:
        open(dst, 'w', encoding='utf-8').write(text)
        print('[gen-status] STATUS.md regenerated')
    else:
        print('[gen-status] STATUS.md already current')
    return 0


if __name__ == '__main__':
    sys.exit(main())
