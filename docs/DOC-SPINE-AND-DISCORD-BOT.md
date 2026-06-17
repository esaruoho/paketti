# Paketti — one doc-spine, many faces (+ a Discord bot that can't lie)

*A proposal. How the same machine-extracted feature spine becomes (a) every doc you
publish and (b) a Discord bot that answers questions from facts, not vibes.*

---

## 0. The thing we already have

`.spine/` runs Paketti's **own registration code** under a mocked Renoise and captures
every keybinding / menu entry / MIDI mapping with its real, loop-expanded name. From
that, `.spine/features.py` already produces a **non-technical** view:

- **`docs/FEATURE-MAP.md`** — every capability as *a feature, in a place, reachable
  through one or more doors* (keyboard · MIDI · menu). 4,296 features, 91 groups.
- **`docs/MIDI-GAPS.md`** — features reachable by key/menu but not MIDI.

Crucially this is **truth from the code**, not a hand-written list that rots. That is the
spine everything else hangs off. No `.lua` ever leaks into it — it's "Transpose lives in
the Instrument Box, via menu + shortcut + MIDI", never "PakettiInstrumentTranspose.lua".

---

## 1. A feature is an ENTITY (the missing layer)

Right now the spine knows a feature's **name, place, doors**. To drive docs *and* a bot,
each feature needs three more facets — authored **once**, in a sidecar, never in code:

```yaml
# docs/feature-notes.yaml   (human-written; merged onto the auto-extracted spine)
"Instrument Transpose":
  status: stable            # stable | experimental | wip
  blurb: >                  # ONE non-technical sentence — what it does, for whom
    Shift the selected instrument up or down in semitones, from a key, a menu, or a knob.
  since: "3.1"              # first shipped (feeds the changelog face)
  tags: [pitch, instrument, performance]
```

The merge rule: **auto-extracted facts win for name/place/doors** (they're measured);
**human facts win for blurb/status/since** (they're judgement). A feature with no note
still renders — it just shows name + place + doors. So coverage can grow over time
without ever blocking a release. (This is the report-card triad applied to docs: the card
is the feature, graded by `status`, cited to its place + doors.)

---

## 2. One spine → five faces

`features.py` gains a `--render <target>` mode. Same data, target-specific template:

| Face | What it selects | Voice |
|---|---|---|
| **README.md** | the ~30 highest-signal groups, 1 line each + headline counts | "here's what Paketti is" |
| **manual.md** | every feature, grouped by place, with the door(s) to reach it | reference, exhaustive |
| **experimental.md** | only `status: experimental|wip` (+ the `Xperimental/WIP` group) | "here be dragons" |
| **Gumroad** | the blurbs of `status: stable`, benefit-first, no counts/jargon | marketing |
| **changelog** | features grouped by `since:`, diffed against the last tag via git | "what's new in X" |

Because the selection is **data-driven** (status, group, since, door-coverage), the five
faces can never silently drift from each other or from the actual shipped tool — they're
all functions of the one spine. Regenerate on every release in the existing
`package-spine` CI job; the text faces commit back `[skip ci]`, exactly like SPINE-TRUE.md
does today. The `.xrnx` never carries any of it (already `-x "docs/*" ".spine/*"`).

**Anti-rot guarantee:** add a feature in code → it appears in the spine on next push →
it shows up in manual.md automatically (name/place/doors), and shows up *with a blurb*
once someone writes one line in `feature-notes.yaml`. Nothing is ever documented by hand
from scratch.

---

## 3. The Discord bot — answers grounded in the spine, not hallucinated

The hard-won lesson (the HyperEdit incident): **a model answering from its own head about
Paketti produces confident garbage.** So the bot is **retrieval-grounded** — it may only
speak from the spine + the rendered docs. Design:

```
Discord question
   │  (pakettibot — already runs on the Mini via Cloudcity-Boot)
   ▼
1. RETRIEVE   embed the question (NLEmbedding, on-device, zero-token) and pull the
              top-K feature cards from the spine + the matching manual.md / changelog
              paragraphs.  (convey's DreamGraph already indexes exactly this.)
   ▼
2. GROUND     build a context = those K cards (name · place · doors · blurb · since).
   ▼
3. ANSWER     FoundationModels on the Mini (fm-submit), prompt: "Answer ONLY from the
              context below. If it's not there, say you don't know. Never invent a
              feature, a menu path, or a shortcut." Majority-vote N samples for stability.
   ▼
4. CITE       reply: the answer + "📍 <place> · reachable via <doors>" pulled verbatim
              from the card, + a link to the manual.md anchor.  No card → "I don't have
              that in Paketti's feature map" (honest miss, not a guess).
```

Why each piece is already on the shelf:
- **PakettiBot** is a Discord bot framework running on the Mini (Cloudcity-Boot pane) —
  no new hosting. A `paketti-docs` command/agent is one more handler.
- **NLEmbedding** (Apple, on-device) does the semantic retrieval with no API/token.
- **FoundationModels** via `fm-submit` is the on-device answer writer; the
  embed-to-narrow / vote-to-judge split keeps it stable.
- **convey graph** already ingests features → context; it's the retrieval index.

**The bot and the docs share one brain.** The bot answers from the same spine that renders
the manual — so if the bot says "Transpose is in the Instrument Box via menu/shortcut/MIDI",
that's because the *code registered it there*, and the manual says the identical thing.
A question the bot can't answer is a gap in the spine (or a missing blurb) — i.e. the bot's
misses become the doc TODO list. Self-improving.

**Scope guard (trustee pattern):** the bot answers questions and links docs. It does not
run shell, does not touch the repo, does not "do" anything in Renoise. Bounded source
(Discord message) → bounded scope (read spine, write reply).

---

## 4. What to build, in order

1. **`feature-notes.yaml`** + merge step in `features.py` (status/blurb/since overlay).
2. **`features.py --render readme|manual|experimental|gumroad|changelog`** templates.
3. Wire the five renders into the `package-spine` CI job (commit text back, never to xrnx).
4. **`paketti-docs` retrieval index**: `convey graph feed-features docs/FEATURE-MAP.md`.
5. **PakettiBot handler**: question → retrieve → ground → FM majority-vote → cited reply.
6. Seed `feature-notes.yaml` for the top ~100 features (the rest render bare until noted).

Steps 1–3 give you the five always-in-sync docs. Steps 4–6 give you the bot — on the same
spine, so it inherits the docs' truthfulness for free.
