# Lessons — just_tooltip war stories

A record of **what this repo missed**. The skills hold the rules; this file holds the evidence.
Rules on their own read as abstract, so the same mistake comes back — the incidents here give
those rules weight. Every one of them actually happened in this repo.

The index follows the four nodes of `thegraph` (`read-it` → `make-it` → `check-it` → `ask-it`).
Each entry names the skill that owns its rule. When a new substantive change skips a node and
pays for it, record the incident under that node with its `#issue-number`.

> An earlier edition was indexed by the retired `flutter_flow`'s Steps 1–10 (Step 6 was empty).
> Read "Step N" in old issue comments roughly as: 1–3 → `read-it`, 4–5 → `make-it`,
> 7–9 → `check-it`, 10 → `ask-it`. File:line citations refer to the tree of their time and are
> not updated — they are records describing the world when they were written.

---

## Two overriding laws

They apply at every node.

### No workarounds — fix it at the root layer (`boundary`)

- **#33 (the reverse signal).** folderview and table_plus each hard-coded
  `TooltipAnchor.pointer` (table_plus even wrote "use pointer for long ellipsized cells" into
  its theme dartdoc), and in the meantime nobody opened an upstream issue. Two or more consumers
  independently reaching the same workaround = evidence that the upstream default is a trap.
  That fact became the ground for rejecting the "add `visibleChild` and keep the default" plan.

- **#22 (never misdiagnose a contract as a defect).** A nested tooltip suppressing its ancestor
  (`innermost wins`) is not a defect but a contract #22 introduced on purpose. When table_plus
  brought "the cell tooltip kills the row card" (`table_plus#88`), the broken invariant was
  *theirs* — they built a tooltip with nothing to draw. That was the place to fix, and it was
  fixed there. Misdiagnosing the contract as a defect would have removed the contract instead
  of the workaround.

- **#38 (membrane propagation).** The clip walk required Flutter 3.13, which raised this
  package's `environment` floor, and since `^0.4.0` already resolves to 0.4.2 that floor
  **propagated straight downstream** (`table_plus#69` absorbed it). A dependency is not a wall
  but a membrane that leaks both ways.

---

## read-it — read before starting

**The issue first — measured numbers, rejected alternatives, negative results (`spine`)**

- **#30 (a negative result comes with its conditions).** When withdrawing the concern that
  `bare()`'s transparent `Material` would wrongly clip an `InkWell` splash, the comment stated
  the condition: *"but this reasoning breaks if `bare()` ever gains padding."* Dismissing it as
  "no problem here" without grounds would have had the next person repeat the same worry.

- **#33 (confirm a downstream bug, don't assume it).** It was written that `flutter_table_plus`
  had the same bug, but checking showed it didn't — the cell tooltip wraps
  `Text(overflow: ellipsis)`, so the rect cannot exceed the column width. Two minutes to check;
  without it, the issue would have carried a wrong follow-up item.

**Don't guess, read the real thing (`firsthand`)**

- **0.4.2 (look up external facts too).** A release strategy was built on *someone else's
  sentence*, "the latest on pub.dev is 0.4.0", trusted without checking — `0.4.1` had already
  been published. One `curl https://pub.dev/api/packages/just_tooltip` would have done it.

- **#31 (the grounds in a PR or issue body are also something to measure).** `surface: false`
  was rejected as "the contradiction of an arrow with no background to paint", but
  `tooltip_shape_painter.dart:59-73` fills, then strokes — transparent background +
  `borderColor` = a legitimate outlined tooltip. Corrected in a comment. Wrong grounds left in
  the repo record get trusted and acted on later.

**Settle design calls before code — separate what can be derived from what must be asked**

- **#34 (pure mechanism → decide directly).** That `describeApproximatePaintClip` returns in the
  *parent's* coordinate system was in the `rendering/object.dart` comment ("Returns a rect in
  **this object's** coordinate system"); that the viewport narrows its parameter to
  `RenderSliver` was in `rendering/viewport.dart`. Both derivable from source — get them
  backwards and a minimal repro passes while only the real tree goes wrong.

- **#35 (contract or policy → ask).** "When the child is fully clipped, hide the tooltip or pin
  it to the edge?" had to be decided *before* writing the red test.

---

## make-it — writing

**RED→GREEN vertical slices (`tdd`)**

- **#35 (designing the observation point).** The resize-tracking test passed **with no extra
  code** — evidence for the call to reject a `ScrollNotification` subscription in favor of a
  post-frame callback. Because it was written as "when the child moves" rather than "on
  scroll", resize, animation and reflow come for free.

- **#35 (when a test teaches the domain, put it in `GLOSSARY.md`).** A draft of that test showed
  the tooltip by hover and failed — not a bug but a domain fact: when the window shrinks, the
  child slides out from under a still cursor, and Flutter re-runs hit testing after layout and
  fires `onExit`.

**Test trust gate — discriminating power + passing for the right reason (`redden`)**

- **#34 (discriminating power).** Disabling the clip logic gives `450.0`; reverting the
  transform gives `50.0` — each of the five tests was checked for discriminating power. A
  passing test proves nothing on its own.

- **#39 (passing for the right reason).** `findsOneWidget` was true, but what made it true was
  an **ordering accident**: `forward()` covered a `reverse()` stuck at `0.0`. Only after also
  asserting that `onHide` was not called did the tracking-death bug surface.

- **#37 (a header comment is a spec — promise only what it can show).** The spike nearly said
  "scroll and watch it re-aim", but the row always covers the viewport, so `row ∩ clip` is
  constant (tooltip center `200.0` at offsets 0/1000/2600 alike).

---

## check-it — measure before calling it done

**A real downstream check is the strongest proof (`dependency_overrides`)**

- **#34 (a downstream test that froze the bug breaking is the strongest evidence).**
  folderview's `tooltip_offscreen_test.dart` (`"with the default anchor the tooltip is painted
  outside the view"`) failed with `Expected: > 400.0 / Actual: 170.0`, and the other 148
  passed = no regressions.

**Consistency sweep — the compiler doesn't catch surfaces that describe behavior (`sweep`)**

- **#38 (nobody catches the `environment` floor).** It declared `flutter: ">=3.10.0"` while
  using `RenderObject? get parent` (3.13+). `flutter analyze` checks only against the installed
  SDK, and pub.dev does not build at the floor.

- **#37 (the public dartdoc is the last to keep describing the bug as the contract).** Even
  after the code was fixed, `TooltipAnchor.child`'s dartdoc still described the bug as the
  contract.

- **#33 (missed glossary update).** The definition of Anchor changed without updating the
  `GLOSSARY.md` glossary, so for a whole release it kept saying "the child's rect".

- **Retiring stale grounds.** The `0.4.1` CHANGELOG justified not rejecting a clipped `show()`
  with *"a tooltip already showing stays even if the child leaves"*, which became false when
  #36 made tracking hide it. The grounds that survive are the transition rule (*you cannot lose
  a target you never had*).

**Gates · PRs · releases (`bare`)**

- **#48→#49 (stacked PRs + no `--delete-branch`).** Tying the delete to the merge CLOSED the
  child PR. It was barely untangled: restore the deleted base on the remote at its original
  SHA → reopen → `--base main` → `git rebase --onto origin/main <old base head>` → force-push →
  delete the temporary branch again. The safe order splits merge and delete in two.

- **#33 (blast radius = reach × size of change → patch).** The viewport reports a clip whether
  or not it overflows (`viewport.dart`), so every tooltip inside a `ListView` is in reach, but
  the move is always "toward the visible part", so *no correct position breaks* → patch, not
  minor. (In the 0.x range `^0.4.0` does not accept `0.5.0`, so a bug fix shipped as a minor
  reaches no one.)

- **#88→#89 (a floor raise changes the formatter; a merge gated by `;` is not gated).** Raising
  `environment.sdk` from 3.1 to 3.8 moved the package's language version past 3.7, so
  `dart format` switched to the tall style. The local format check ran before any
  `flutter pub get` and read the stale `package_config` (language 3.1), so it passed; CI did a
  fresh `pub get` and failed on 25 files, so its analyze and test never ran. The merge went
  through anyway, because `gh pr checks --watch; gh pr merge` merges whatever the checks say.
  `#89` reformatted and restored green. After touching `environment`, run `flutter pub get`
  before every gate, and merge only after reading the check result as a separate step.

---

## ask-it — handing off to a person · downstream migration

- **Don't store the consumer versions — derive them on the spot.** `grep -H "^  just_tooltip:"
  ../*/pubspec.yaml`. A stored snapshot rots: while `docs/downstream-consumers.md` said
  *"All four are on 0.3.0"*, they were actually on `^0.4.4`/`^0.4.4`/`^0.4.2`. A private repo
  (`acra_client`) isn't caught by grep, though, so the table itself stays.

- **Keep a workaround that is still right.** The row tooltip's `TooltipAnchor.pointer` is not a
  bug dodge but the original intent, "point next to the cursor" — don't remove it; leave the
  reason in a comment.
