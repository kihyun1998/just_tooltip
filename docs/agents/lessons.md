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

- **#92 (measure the mechanism a decision assumes, before building on it).** Grilling settled
  "Escape is consumed only when it closed a tooltip", assuming a `HardwareKeyboard` handler can
  consume. One probe showed it cannot: a handler returning `true` still let a dialog's Escape
  through, because `KeyEventManager` feeds the focus system's `Shortcuts` regardless. A second
  probe showed a nearer `Actions` shadows the route's `DismissIntent` even while disabled. The
  maintainer re-decided on the measurement (a hybrid) at the confirm stop, not after the build.

- **#100 (read the method body, not the name of what it calls).** The confirm stop told the
  maintainer that a tooltip's own route popping notifies `isCurrent` dependents, because
  `ModalRoute.didPop` calls `changedInternalState`. It does, but only when it removes a
  local-history entry; a plain pop goes to `TransitionRoute.didPop`. The maintainer decided on
  that reading, and the build's first probe showed the tooltip getting no notice through the
  whole exit. The call was re-asked with the measurement. Reading the branch the call sat in
  would have taken a minute.

- **#92 (a framework flag is a proxy — measure what it means on every platform).** "Keyboard
  focus" was first read as `FocusManager.highlightMode == traditional`, the focus-ring condition.
  The completeness read measured that a desktop mouse click leaves it on, so a click opened the
  tooltip; the next proxy, "any key pressed", let a Shift-click and a dialog's restored focus
  through. What held was the cause itself: a focus-moving key (Tab, arrows) down when focus lands.

**Settle design calls before code — separate what can be derived from what must be asked**

- **#34 (pure mechanism → decide directly).** That `describeApproximatePaintClip` returns in the
  *parent's* coordinate system was in the `rendering/object.dart` comment ("Returns a rect in
  **this object's** coordinate system"); that the viewport narrows its parameter to
  `RenderSliver` was in `rendering/viewport.dart`. Both derivable from source — get them
  backwards and a minimal repro passes while only the real tree goes wrong.

- **#35 (contract or policy → ask).** "When the child is fully clipped, hide the tooltip or pin
  it to the edge?" had to be decided *before* writing the red test.

- **#156 (a call made on paths that share one hidden state covers only that state).** Triage
  decided "the pointer on the body wins over a focus suppressor" as docs only: both measured
  paths kept A shown, and the code explained why — suppression hides through show intent
  dropping, and A had none left. Both paths had dropped A's show intent before D took focus. The
  run's lens took the sibling state, focus moving straight from A's own button onto D, and A
  hid under the resting pointer (`[show A, show D, hide A]`, measured). The rule was general;
  the code held it only by accident of state. The maintainer, shown that, turned the docs-only
  call into a runtime fix. When a "no change needed" rests on *why the code already does it*,
  list the states that reason depends on and measure the one where it does not hold.

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

- **#111 (a positive test cannot catch a predicate that is too wide).** Reviving evicted
  tooltips on teardown only when the tooltip was shown or fading out: the three "A comes back"
  tests all passed with the revival made unconditional. Only the negative case — a tooltip that
  was never shown leaves the tree while B still holds A's place — went red, because the
  unconditional revival brought A back and A dismissed B. Pin the case the guard exists to
  refuse, not only the cases it lets through.

- **#122 (a reset clears facts that lean on each other).** The fix was to stop the teardown from
  clearing `_pointerInside`, so a tooltip moved by a `GlobalKey` under a resting pointer would
  show again. The same reset cleared `_dismissed`, and that line was only harmless because the
  pointer fact went with it: keeping the one fact alone would have brought back a tooltip the user
  had closed with Escape, against ADR-0010, while every test for the issue passed. A probe of the
  neighbours before the first test caught it (Escape-closed, then moved: `0` on the base), and the
  same probe showed the focus side already broken that way (`1`), since `_keyboardFocusInside` was
  never cleared. When a fix stops a reset from clearing one field, read what else the reset
  clears and what each of those relied on.

- **#106 (a default can remove the window a test asserts in).** The focus variant of "a trigger
  returning during the fade turns it back" passed on the unfixed tree. It left `interactive` at
  its default `true`, so blurring armed the 100 ms Hover Bridge, focus came back 60 ms later and
  cancelled it, and no fade ever started — the window the test was about never occurred. The probe
  it was copied from set `interactive: false`; the copy dropped it. Watching it fail on the base
  before the fix caught it; with `interactive: false` it went red.

- **#116 (`pump(duration)` moves the clock before it builds).** A test for "show intent an act
  set survives a configuration change during `waitDuration`" passed with the guard removed. It
  changed the configuration and then called `pump(250 ms)`, which advanced fake time first: the
  wait timer fired and showed the tooltip before the rebuild that was meant to interrupt it ran.
  A `pump()` for the rebuild frame, an assertion that the tooltip was still waiting, and only then
  the long pump turned the mutation red.

- **#69 (a teardown hook runs after the frame's semantics).** The first nested-yield test
  removed the inner tooltip and expected the outer text back the same frame; it stayed `''`.
  `drawFrame` runs build, then layout/paint/semantics, then `finalizeTree` — where removed
  states are disposed — so a release in `dispose` landed a frame late. It moved to `deactivate`.
  A red test taught a framework fact no summary of `State.dispose` states.

- **#113→#114 (moving state into an object reached through a recomputed address).** #113 moved
  the eviction record from one static set into the `TooltipRegistry`, while the State still
  re-resolved which registry it belonged to on every read. A tooltip whose `registry` changed
  while shown registered in one registry and ended its show in another; before #113 that was
  harmless for the revival (the static set revived on any end), after it the evicted tooltips
  waited (measured `A=1` → `A=0`). When state moves into an object, check every read of the
  address of that object: if it is recomputed, the state and its release can land in two places.
  The fix resolved the registry in one place and kept it in a field.

- **#138 (a clear of a field reaches every writer of it).** The fix cleared the pointer's last
  position when `enableHover` turns off, as #124 had cleared the pointer fact. The position had a
  second writer: a `claim` tap wrote it at `onTapDown`, and its `onTap` came after the clear, so a
  tap pressed across the change opened at the child's centre (x=350) instead of where it went
  down (x=80). The `observe` path, which writes at pointer-up, was unaffected. A test built on
  #122's "a tap survives enableHover changing while it is pressed", with a pointer anchor added,
  caught it before the commit. When a fix clears a field, list every site that writes it and
  when each write lands relative to the clear.

- **#143 (one test per predicate term).** The fix marks a wait as the revival's with
  `revival && !act`. The first test, the issue's own scenario, went red when the branch was
  removed, and the existing "new act's wait changes nothing" test stayed green. Dropping `revival`
  still survived, because `!act` alone separated that test. Dropping the clear in `_setPending`
  survived too, since a stale flag on a shown tooltip gives the same screen. Each term needed a
  case only it decides: a wait begun by the child returning from a clip (no act, no revival), a
  revival `keepsWaiting` turned back and then a Tab (revival and act), and lost content followed by
  `controller.hide()` (a stale flag on a hidden tooltip). For a compound guard, mutate each term on
  its own before trusting the tests. The lens then found a case none of these mutations could
  show. A Tab during the revival's wait reached a reconcile that returned early, because show
  intent was already set, so the flag set at the wait's start was never read again. A flag set at
  a transition also has to be revisited by every event that changes its meaning between
  transitions.

- **#159 (a flag for a gap ends at every exit from it).** `_revivalPending` covers the gap
  between the registry emptying its evicted set and the revival's microtask. The gap has two
  exits: the reconcile, and `keepsWaiting` turning the revival back. Only the first cleared it, and
  "leaving the flag set after the reconcile survives every test" was true and measured, which made
  the flag look harmless when stale. The turned-back exit differs: the tooltip goes back to the
  evicted set, and a show taking the place back leaves it without any reconcile, so the stale flag
  turned a later `controller.hide()` into a dismissal. The obvious fix, clearing on show, broke the
  gap itself (a `show()`/`hide()` before the microtask). A mutation that survives proves the flag
  is harmless only on the paths the tests take; list the exits from the state the flag stands for
  and clear it at each.

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

- **#69 (a review reading the module, not the hunk).** Every test was green and every
  mutation reddened, yet `activate` re-registered a `GlobalKey`-moved tooltip on its *old*
  ancestors and silenced them for good — `_ancestor` is read without a dependency, so nothing
  re-read it. The code reviewer found it by asking what the new registration does across the
  lifecycle hooks it did not touch; a red test then pinned it before the fix. The same read
  showed the old suppression chain had the same hole.

- **#92 (an opt-in that wraps every child is not opt-in).** `enableFocus` defaulted to off, yet
  the first cut put a `Focus` around every tooltip's child for Escape's sake, and the review
  measured `Focus.of(context)` inside any consumer's child returning the tooltip's node. All 876
  consumer tests stayed green, because none read `Focus.of` under a tooltip. Ask what the always-on
  part of an opt-in feature changes for a consumer who never opts in, and test that directly.

- **#100 (a dependency costs every instance; measure it on many).** The first cut read the route
  with `ModalRoute.isCurrentOf` in the tooltip's State. Every test passed and every mutation
  reddened. A cost check then pushed and popped a dialog over 300 tooltips: 59 ms against 23 ms
  without the change, because each route change rebuilt every tooltip. Moving the dependency
  onto a child that builds nothing brought it to 28 ms. The optimisation then let one mutation
  survive: with the reconcile skipped while covered, the show-intent gate had no case left to
  fail in, so a test had to create one.

- **#100 (the completeness read found the bug on the issue's own path).** The tests for #100's
  scenario passed while `onHide` ran inside a build there, since they only logged it. The lens
  agent asked which phase each callback ran in and measured `persistentCallbacks`. A callback test
  that records only that it ran cannot see when it ran.

- **#101 (a second way into a state resets what the first way resets).** The fix let
  `controller.show()` turn back a fade-out, re-registering and re-tracking as a fresh show does,
  but it kept `_sawVisibleTarget`, which a fresh show resets. Every test passed. The review read
  the two paths side by side, and a probe showed a caught tooltip over a child scrolled out of
  sight hidden again by the next layout, where a show after the fade waits at the clip edge. The
  first test for it passed anyway: the position is recomputed only on a layout, so the test had to
  scroll once more. A mutation of the anchor freeze survived for the same reason until the test
  forced a layout.

- **#102 (`activate` sees the old widget).** Attaching the controller in `activate` fixed the
  same-frame replacement, and every test passed. The review read `Element.inflateWidget`: a
  `GlobalKey` element is reactivated before it is updated, so `activate` reads the controller
  the widget is about to drop. A State moved and handed a new controller in one frame reattaches
  the old one first. Read the framework's call order before trusting `widget` in a lifecycle hook.

- **#109 (a guard judged harmless was load-bearing).** The rewind detaches the status listener.
  A mutation that kept it attached survived every test, and the run reported the line as affecting
  only a deferred revive path. The review traced a hover show: show intent is set before `_show`,
  the rewind's `dismissed` dropped it and marked the tooltip dismissed, and the tooltip stayed when
  the pointer left. The tests only opened by `controller.show()`, which has no show intent. A
  surviving mutation names a path no test drives; before calling it harmless, drive each path that
  reaches the line. The first cut also wrote the animation's `value` in `deactivate`, which
  notifies the overlay's transitions during the build.

- **#113 (a cost moved onto an out-of-scope neighbour reaches the user's record too).** Moving
  the eviction record into each registry fixed the issue, and the run measured that it made #114's
  path worse — a tooltip whose registry is replaced while shown left the old registry's evicted
  tooltips waiting. It went into the map's Known holes and the ADR amendment, inside the bullet
  recording the maintainer's call, and nowhere a consumer reads. The review asked who would hit it:
  a `TooltipRegistry()` built inside a parent's `build`, measured `A=1` before and `A=0` after. "Out
  of scope" means not fixed here, not unrecorded; the cost went into the CHANGELOG, and the ADR now
  says the maintainer was not shown it.

- **#116 (a mechanism standing in for the rule's words let in the case the words excluded).** The
  rule was "an evicted tooltip shows again on the pointer or focus moving onto it from a nested
  tooltip that was suppressing it". The first cut took any release by a moving trigger as that
  act. Every test passed and every mutation went red. The review and the completeness read each
  measured, independently, a focus-held A coming back over its holder when the pointer went from
  a nested tooltip straight out of A, while going out from A itself left A waiting: the same end
  state with opposite results. The repair encodes the two conditions the sentence names: the
  outer tooltip was suppressed, and the trigger that moved is still inside it. Where a rule's
  sentence has a condition, test the case that fails each condition, not only the case that meets
  them all.

- **#106 (a test at one timing pins one ordering of two clocks).** The first complement cancelled
  the waiting `waitDuration` timer where show intent dropped at `dismissed`, and its test — a
  `controller.show()` during the wait, then `hide()` 20 ms later — went red without it and green
  with it. The lens asked what happens when the hide comes later: `dismissed` arrives only when the
  fade ends, so a hide at 160 ms, whose fade outlasted the 300 ms wait, was turned back by the
  timer and the tooltip stayed (measured: shown 800 ms later), and `showDuration` counted from the
  end of the wait. Where a timer and an animation race, drive the test on both sides of their
  crossing. The cancel moved to the show, which no timing can outrun.

- **#117 (an inference moved to an earlier moment is a new claim).** `_onAnimationStatus` read
  "show intent still set at `dismissed`" as "a close the user made". The fix made `dismissTooltip`
  apply the same reading at any moment of a fade-out. Every test was green and every mutation
  reddened. The review and the lens each measured the case that broke it: content loss calls
  `_hide()` at once and drops show intent only in the reconcile microtask, so an eviction in the
  same frame marked the tooltip dismissed (A stayed closed where ddae36c showed it again). The
  same window had already been hiding a defect on the base: a zero-length fade ends inside
  `reverse()`, before that microtask. A reading that holds at one moment holds there because of
  what has run by then; before reusing it earlier, list what has not run yet.

- **#126 (the direction rejected for the whole fix came back at one site).** The fix chose to
  settle at every site that drops show intent, and rejected recording the dismissal when a close
  starts, because a turned-back fade would then have to undo it. For `controller.hide()` during an
  eviction's fade, which had no show intent left to settle, the first cut set `_dismissed` at once
  — the rejected direction, in one line, keyed on `isEvicted`. Every test was green and every
  mutation reddened. The review measured both costs the rejection had named: `a.show()` turning
  that fade back kept `_dismissed`, so a later eviction's revival left A closed; and a hide landing
  on a tooltip suppression had already taken out of wanting, then evicted, kept it closed. The
  repair gives show intent back instead, so the existing settle at `dismissed` decides. When a
  design rejects a direction for a reason, check each special case against that reason too.

- **#131 (a sweep by symbol misses a note that names the case in words).** The fix made
  `onProgrammaticShow` cancel the Hover Bridge, and the sweep grepped for `onProgrammaticShow` and
  `#131`. `content.md` said the content-loss reset mattered "only for a hover-bridge timer armed
  with show intent set and a `controller.show()` within its 100 ms" — the case the fix now covers
  without the reset — and named neither. The review found it. Grep for the behaviour as well:
  the timer's plain name, the trigger, the window.

- **#129 (one callback carried two meanings into a rule that names one).** The rule was "an
  explicit close of an evicted tooltip cancels its revival". The scheduler had a single `onHide`,
  shared by the tap and the auto-hide and by the trigger leaving and the Hover Bridge, and the
  first cut routed all of it through the new close on the reading that the trigger is outside
  whenever the latter two fire. Every test was green and every mutation reddened. The review
  measured the reading failing: the bridge running out after the child slid back under a resting
  pointer, an edge that is not an act, marked an evicted tooltip dismissed. The same cut set
  `_dismissed` on a hidden evicted tooltip without asking whether a new act had already given it
  show intent; the review and the lens each measured that tooltip shown by its wait timer with
  `_dismissed` set, and hidden by the next unrelated re-derivation. When a rule names a kind of
  event, split the channel that carries it rather than argue that the other events never meet the
  condition, and when a shortcut writes one half of a paired state, check the states the other
  half can be in. The re-review of the repair then found the same rule failing in a third place:
  the registry empties its evicted set a microtask before the revival reconciles, so a `hide()`
  from the holder's own `onHide` saw a tooltip that was neither evicted nor shown. A record that a
  rule reads (`isEvicted`) can be cleared before the act it stands for has happened.

- **#122 (keeping one render object by moving a widget hands the loss to its neighbour).** The
  review measured a `tap` change re-creating the child's `MouseRegion`, which left the pointer fact
  true with the pointer gone. The first repair moved the region outside the tap widget so it would
  survive. Every test was green, and the reasoning that hit results could not change was read in
  Flutter's source and held. A fresh re-review of just that move measured the cost: the region was
  now the widget an `enableHover` change swaps, so that change re-created the tap recognizer and
  lost a tap pressed across it. The repair kept the tree as it was and cleared the fact when the
  region is re-created, as #124 already did for `enableHover`. When a fix reorders widgets to keep
  one element alive, list every setting that changes a widget type in that chain and check which
  element each one now re-creates.

- **#136 (inverting the test that pinned a guard un-pins the guard).** The maintainer's call reversed
  #129's "a `hide()` during the wait marks no dismissal", so that test was inverted. It was the only
  test holding `_closeOnRequest`'s `!_showIntent` guard: with the cancel now in `hideTooltip`, the
  guard's mutation survived all 464 tests. The path left to it — an auto-hide left over from an
  earlier show firing during a new act's wait — shows only once `showDuration` has been removed
  meanwhile, since with it set the re-derivation hides nothing. When a test is inverted, run the
  mutations of the guards it used to hold, and re-pin each one on the path that still reaches it.

- **#130 (a gate set by an event stood in for a rule stated as a state).** The call was "a trigger
  does not show the tooltip while its child is clipped away", copied from Covered, which reads the
  route live. The first build set a flag only in the tooltip's own clip-away hide. Every test was
  green and every mutation reddened. The lens measured the tooltip left at the clip edge after a
  child visible for one frame, after a wait clipped meanwhile, and after a revival, content
  returning or uncovering while clipped; the review measured the watch callback multiplying, one
  more per layout during the fade (71 after a 600 ms `animateTo`), because it was started from a
  site that runs every layout. The redesign's own lens then found a new reader of an old function:
  `_resolveTarget` had only ever been asked about a shown tooltip's child, and a child a lazy list
  keeps alive off screen has a degenerate transform, a NaN rect and an intersection that is not
  empty, so the watch reopened the tooltip. When a rule names a state, gate on the state where the
  sibling does; when a self-re-arming callback starts from a per-layout site, guard it; when a new
  caller reads an old function, list the inputs the old caller never gave it.

- **#127 (a hold computed from the current fact, not from the movement the rule names).** The rule
  was "a dismissal is released only by the trigger moving away". The first cut set the pointer's
  hold from `_pointerInside` at the moment of the close. Every test was green and every mutation
  reddened, because each test began after the close's fade had ended. The lens measured the window
  #117 and #126 had already named: during the fade, a post-frame edge or `enableHover` turned off
  cleared the fact first, so the settle at the fade's end found no pointer to hold, and the
  tooltip came back. The review and the lens also measured a hold outliving a trigger turned off
  (focus that left while `enableFocus` was off kept its hold) and a hold of one trigger blocking
  another that arrived later. When a rule is stated in movements, find every site that clears the
  fact without a movement and settle there first, as #126 settles at every site that drops show
  intent.

- **#134 (a surviving mutation read as redundancy was a missing test).** The body's turn-back predicate
  began with `widget.enableHover &&`. Its mutation survived every test, and the run removed the term as
  redundant: the trigger term it fed already read `enableHover && pointerInside`. That term is an `||`
  with keyboard focus, so with focus inside it held without hover. The lens measured an eviction fade of
  an `enableHover: false` tooltip with focus inside turned back from its body, against the amendment's
  "with `enableHover` off it does not". A surviving mutation names an input no test set; before calling
  a guard redundant, write the case where every other term that could stand in for it is true.

- **#149 (a surviving mutation recorded against a tree that changed in the same commit).** #151's
  record said the `showDuration` guard on the child exit's `_exitLeftToCountdown` survived every test,
  since its only effect was a hole no test pinned, and #149's brief asked for a test for it. Run on
  bb75909 — the commit that landed #150 and #151 together — the mutation already reddened two of
  #150's body tests: the hover-on cross from the child set the flag, and the body's exit with hover
  off armed the bridge instead of hiding at once. The record had been written before #150's tests
  joined the tree. A recorded surviving mutation is a measurement of one tree; re-run it on the
  current one before building on it or rewriting the note that cites it.

- **#133 (a fact cleared with the show, while the thing it describes lives by the frame).** The pointer
  on the body was cleared in `_endShow`, on the reading that the body leaves with the show. Every test
  was green and every mutation reddened. The review and the lens each measured both sides of the gap:
  the overlay's region stays in the render tree until the next frame, so the pointer entering it after
  a zero-length fade's `hide()` set the fact with no exit to come (the next show never auto-hid), and
  `hide(); show();` in one frame keeps the same region under the pointer, so the cleared fact let the
  countdown run under it. The fact moved to the region's own lifetime. When a fact mirrors a render
  object's edges, clear it where that object leaves the tree, not where the logic that removes it runs.

- **#134 → #148 ("pre-existing" against a commit on the same branch).** #148's lens measured an outer
  tooltip whose nested tooltip held focus staying shown for good after the pointer left its body,
  `[show B, show A, hide B]`, and graded it as predating the change: "same on HEAD ada5e3e". ada5e3e
  was #134's commit on the same unpushed branch, and it had introduced the gap: the body turning a
  fade back left a tooltip the old body-exit guard (focus *inside*, not focus *holding* it) never hid.
  The run carried it for a new issue, as an older gap. Bisected to the branch base, fd0a9be and
  d844258 hid A and revived B. To grade a finding pre-existing, compare it with the tree before the
  branch (the merge base, or the released version), not with the parent commit on the branch itself.

- **#134's closers (a new way into a state, fixed one closer per lens).** The body turning a fade back
  showed a tooltip without show intent. 8893217 fixed one closer of that state (the pointer leaving
  the body with nested focus), and its lens found a second (focus leaving after an eviction fade).
  Each run had read the closers it was looking at. The closers run listed every closer of the state
  instead: 8 ways to begin the fade, focus in the tooltip or not, the pointer entering the body or the
  child, 3 places for the pointer to rest afterwards, and 15 closers. That made 1350 cases, about 35 s
  per tree, each body case set against its child case. It found 14 differing rows and one more in a
  separate probe, all from one root. The turn-back never re-derived show intent, though it had just
  taken the registry back. One line fixed all of them, and it changed no other row. When a change
  opens a new way into a state, list every closer of that state against the reference path before
  fixing the first one; a lens reports only the closer it happens to probe.

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
