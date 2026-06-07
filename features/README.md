# Paketti features/ — hand-written Gherkin that feeds the DreamGraph

This folder is the **intent layer** for Paketti development. You write `.feature` files
saying *what Paketti does* (Given / When / Then); the DreamGraph reads them — zero token,
zero Claude — and wires each one to the code that implements it and the forum posts that
asked for it.

## Files
- `TEMPLATE.feature` — copy this. The header comment explains the conventions.
- `pattern-editor-example.feature` — a worked example.
- `generated/` — **machine-written** backfill: one `.feature` per Renoise context, every
  existing keybinding/MIDI-mapping/menu-entry as a Scenario, produced by
  `convey graph backfill ~/work/paketti`. Structure is from code; fill in the `Then …`.
  (These are starting points — prune/edit, don't treat as authored.)

## The loop
```bash
# one-shot: rebuild graph from code + features + forum, open the webpage
convey graph sync ~/work/paketti --graph ~/work/paketti/kb/graph

# leave running: re-syncs on any .lua / .feature change
convey graph watch ~/work/paketti --graph ~/work/paketti/kb/graph

# live, in-browser git grep + binding search
convey graph serve ~/work/paketti --graph ~/work/paketti/kb/graph
```

## Asking the graph
```bash
# where is the Instrument Box feature in a file?
convey graph bindings ~/work/paketti "Instrument Box"
convey graph neighbors "Pattern Editor" both --graph ~/work/paketti/kb/graph

# how many forum requests for X, and which Paketti bindings answer them?
convey graph requests ~/work/cc/vault/music/paketti/forum ~/work/paketti "render"
```

## Node colors in the viewer
🟢 module (.lua) · 🟡 context (Renoise location) · 🟣 feature (these files) ·
🟠 category (forum) · 🩷 forum request (indexed, not drawn at 11k scale).
