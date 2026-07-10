# 0004 — Content gates showing, suppressing, and hiding

- **Status:** Accepted
- **Date:** 2026-07-10
- **Context issues:** [#46](https://github.com/kihyun1998/just_tooltip/issues/46) (a tooltip that cannot draw must not suppress its ancestors), [#47](https://github.com/kihyun1998/just_tooltip/issues/47) (a shown tooltip ignores config changes)
- **Amends:** [0003 — Nesting suppression gates a derived hover intent](0003-nesting-suppression-gates-a-derived-hover-intent.md)

## Context

ADR-0003 derived hover intent from three inputs:

```
hoverIntent = enableHover && pointerInside && !suppressed
```

A fourth input was already deciding the outcome — *does this tooltip have anything to draw* — but it was not state. It was a local judgement inside `_show()`:

```dart
if (widget.hideOnEmptyMessage &&
    widget.tooltipBuilder == null &&
    (widget.message == null || widget.message!.isEmpty)) {
  return;
}
```

Suppression, meanwhile, was claimed unconditionally from `MouseRegion.onEnter`. So a tooltip with an empty `message` took its ancestor's place and then drew nothing. Hovering it showed **neither** — the ancestor silenced by a descendant that never speaks. This is reachable from ordinary data: a cell tooltip whose text is `''` for "no description", inside a row-level tooltip.

Two downstream packages had independently grown the same local guard rather than report it, which is what a trap in an upstream default looks like.

## Decision

**Content is state, not a judgement.** It is derived from the widget and never cached, because `message` is data: it can arrive or leave while the pointer sits still.

```dart
bool get _hasContent => _hasContentOf(widget);

static bool _hasContentOf(JustTooltip w) =>
    w.tooltipBuilder != null ||
    !w.hideOnEmptyMessage ||
    (w.message?.isNotEmpty ?? false);
```

ADR-0003's formula gains a fourth term:

```
hoverIntent = enableHover && pointerInside && !suppressed && hasContent
```

Three commitments follow.

1. **Only a tooltip that can draw may suppress.** Suppression is claimed iff `pointerInside && hasContent`, and released otherwise. `hideOnEmptyMessage: false` asks for the empty bubble — such a tooltip draws, so it suppresses exactly as before.

   The claim stays **synchronous**, at the pointer edges, and is *not* moved into ADR-0003's reconcile microtask. Deferring it would let an ancestor reconcile before its descendant has claimed it, and an ancestor with no `waitDuration` would flash into view on its way to being suppressed.

2. **Content is re-derived on `didUpdateWidget`, not only at pointer edges.** A still cursor sends no `onEnter` to recompute from, and content is data. Without this, a `message` that arrives under a resting pointer is never noticed.

3. **Losing content is not a hover exit — and it cannot be routed through hover intent.**

   ADR-0003's commitment 4 says a suppressed-while-visible tooltip hides immediately, bypassing the scheduler's hide policy. Content loss now does the same, and for the same reason: a `showDuration` tooltip would otherwise keep a message it no longer has.

   But content loss cannot simply *reuse* that path. `_reconcileHoverIntent` opens with `if (wants == _hoverIntent) return;`. A tooltip shown by `controller.show()` never had hover intent — ADR-0003 closes by committing that "suppression gates hover only; a programmatic `controller.show()` is an explicit command" — so `wants` (false) equals `_hoverIntent` (false) and the function returns before reaching any hide branch. Such a tooltip would survive with nothing to draw.

   Content loss is therefore acted on **directly, in `didUpdateWidget`**, guarded by `_isShowing`. `_show()` refuses to open without content; closing owes it the same rule, whoever opened it. **The overlay exists only while there is something to draw.**

   That direct hide carries no `_scheduler.reset()`, unlike the hide branch in `_reconcileHoverIntent`. That branch also owns a pending hover-show timer; this one cannot. The only timer a programmatic show arms is the auto-hide, and every show path re-arms it through `startAutoHide()`, which cancels the previous one — so a stale timer can only fire while nothing is showing, where `_hide()` ignores it.

## Consequences

`TooltipRegistry` and `TooltipVisibilityScheduler` are unchanged. Suppression remains hover-only and tree-local; content gates all three of showing, suppressing, and hiding, on every path.

Reach is wide — every nested tooltip whose inner message can be empty — but the change only ever converts "nothing shows" or "stale text shows" into the correct tooltip. No correct behaviour changes, so this shipped as a patch (`0.4.4`), not a minor: on `0.x`, `^0.4.0` would not admit `0.5.0` and a minor would reach nobody.

Downstream packages that guard against building an empty-message `JustTooltip` may drop that guard.

A tooltip losing content starts its fade-out (`_hide()` reverses the animation) while `_markOverlayDirty()` still queues a rebuild, so the bubble spends its fade rendering empty rather than fading the old text. Accepted, not fixed: the alternative is `if (_hasContent) _markOverlayDirty()`, and no test can pin that without asserting the content of a frame mid-animation — an incidental this ADR does not want to make a contract. The overlay is gone at rest, which is what `hideOnEmptyMessage` promises.

## Alternatives rejected

- **Route content loss through `_reconcileHoverIntent` alone.** Correct for hover, silently wrong for `controller.show()`, where the early return is never passed. Measured: with the overlay following the widget (#47), the controller-shown tooltip redrew as an empty bubble in defiance of `hideOnEmptyMessage`.
- **Leave `_show()`'s guard as the only content check** and add `visibleChild`-style opt-ins. Rejected: two consumers had already worked around the default independently, which is evidence the default is the trap — not that the option was undiscovered.
- **Compare the fields the overlay renders before marking it dirty** (#47's suggested fix). Rejected: naming the fields the overlay happens to read today is how one added tomorrow goes stale, and `tooltipBuilder` is a fresh closure on nearly every parent rebuild, so the comparison would rarely say no.
