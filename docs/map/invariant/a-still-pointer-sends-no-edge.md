# A still pointer sends no edge

## The fact

`MouseRegion` reports edges (`onEnter` / `onExit`), and a pointer that has not moved sends none.
So any decision that would otherwise wait for "the next enter" must be made from retained facts,
at the moment its other inputs change. Checkable: for every condition combining a pointer fact with
anything else, there is a re-derivation on the non-pointer input's change, not only in an edge
handler.

## Why it is cross-cutting

Three sites in two files depend on it independently:

- `_JustTooltipState._pointerInside` is retained so an ancestor released by a descendant can show
  again — it will never receive a second `onEnter` (`_reconcileShowIntent`).
- `TooltipVisibilityScheduler.onChildEnter` cancels `_hoverHideTimer`: a bridge armed by leaving
  the tooltip body would fire while the cursor rests on the child, and the fade-out could never be
  revived.
- `didUpdateWidget` re-derives content and calls `_syncSuppression` / `_scheduleReconcile`: a
  `message` arriving under a still cursor is otherwise never noticed.

They share no primitive — one is a retained bool, one a timer cancel in another file, one a
lifecycle hook — and a fix to one does not reach the others.

## Territories it holds in

- [show-intent](../territory/show-intent.md) — `_pointerInside`, `_reconcileShowIntent`.
- [visibility-scheduling](../territory/visibility-scheduling.md) — `onChildEnter`'s `_hoverHideTimer?.cancel()`.
- [content](../territory/content.md) — `didUpdateWidget`'s content re-derivation.
- [nesting-suppression](../territory/nesting-suppression.md) — release of an ancestor relies on `_pointerInside` having been kept.

## What a violation looks like

Correct while the cursor moves, wrong once it rests: a tooltip that never appears until the mouse
is jiggled, an ancestor that stays dark after the pointer slides off a nested child, an interactive
tooltip that fades out under a resting cursor and never returns. None throws.

## Discovery history

- #22 / ADR-0003 probe 2 — "releasing an ancestor is impossible": no second `onEnter` arrives.
- #43 — the bridge must be cancelled on the child side too (`GLOSSARY.md` → Hover Bridge; spike header item 3).
- #46 / ADR-0004 commitment 2 — content re-derived on `didUpdateWidget`.

## Where it will recur

Any new input mixed with a pointer fact — focus, enabled-ness, async content, a locale. Ask: if this
input changed while the cursor did not move, would anything recompute?
