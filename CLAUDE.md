## Working discipline — `thegraph`

Build substantive changes (bug fixes, features, behavior changes) with **`thegraph`** — run
`/thegraph` when starting (the skill is human-only). This repo's own values — reference sources,
how to prove a change, gate blind spots, release rules — live in **`docs/agents/thegraph.md`**;
the war stories where each rule caught a real defect (#22, #30–#39, #48 …) live in
**`docs/agents/lessons.md`**. Read both before starting, and record any new war story in lessons.

## Identity / invariants (the boundary)

just_tooltip is **a core whose identity is its boundary** — a tooltip engine. It stays correct by
*not* absorbing its consumers' concerns. `boundary` calls are grounded here.

- **The core owns (mechanism):** Visible Rect computation (ancestor clip walk), the position
  delegate, anchor freezing, Target Tracking (per-frame re-aiming), nesting suppression, Hover
  Intent derivation, scheduler timing, shape painting — the things that are *only correct when
  you hold the whole tree and state*.
- **The consumer owns (policy):** anchor choice (`child`/`pointer`), theme values, when to call
  `show()`, content, enabling hover. This is not a workaround; it is the boundary.
- **Contracts (not defects):** `innermost wins` (when nested, the inner one suppresses its
  ancestors) and *a tooltip with no Content to draw does not show* — both are contracts #22
  introduced. When a downstream repo brings one as a "bug", the broken invariant may be theirs.
  Misdiagnosing a contract as a defect deletes the contract, not the workaround. (ADR-0001–0004
  and the `GLOSSARY.md` glossary are the source of truth.)

## Map — `docs/map/`

The hub is [`docs/map/README.md`](docs/map/README.md). **Read it before a change, write it after.**

- **Read — `read-it` (before the `boundary` call):** open the territory note you are entering,
  its `## Blast radius` and `## Cross-cutting invariants`. It is a checklist — opening one and
  finding nothing to do is a correct outcome.
- **Write — `sweep` (behavior-describing surfaces):** if the change falsifies a note's claim,
  its `## Code` or a blast edge, fix the note in the same change.
- **Promotion — at the first fix:** for the fact a fix revealed, ask with grep *"does this hold at
  every site that shares this assumption?"* If yes, the fix lands with a `docs/map/invariant/` note.

## Comment rule

A comment says what the code is. Why it is this way, what it deliberately leaves out, the trap
and the measured value go to the territory note under `docs/map/`. Where none seems to hold it,
search the folder and the code symbol first; only then start a new note, named for what the
system does there, not for the file. History goes to the commit message. Comments written before
this rule still carry the rest: never delete one whose content the map does not yet hold — move
it first (`decant`).

## Agent skills

- **Issue tracker** — this repo's GitHub Issues (`kihyun1998/just_tooltip`), managed with the
  `gh` CLI. External PRs are not triaged. `docs/agents/issue-tracker.md`.
- **Triage labels** — the default label strings for the five canonical roles (`needs-triage`,
  `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`).
  `docs/agents/triage-labels.md`.
- **Domain docs** — single context: `GLOSSARY.md` at the repo root + `docs/adr/`.
  `docs/agents/domain.md`.
