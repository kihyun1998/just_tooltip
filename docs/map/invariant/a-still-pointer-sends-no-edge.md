# A still pointer sends no edge

## The fact

`MouseRegion` reports edges (`onEnter` / `onExit`), and a pointer that has not moved sends none
while the tree under it stays put. When the tree under a resting pointer changes — a region
mounted under it, a child laid out away from it, a route's barrier removed — `MouseTracker`
sends the edge after the frame (`updateAllDevices`, the only caller being
`RendererBinding._scheduleMouseTrackerUpdate`; measured by probe, Flutter 3.47.1, #116). A state
change that moves nothing in the tree sends no edge at all. So any decision that would otherwise wait for "the next enter" must be made from retained facts,
at the moment its other inputs change. Checkable: for every condition combining a pointer fact with
anything else, there is a re-derivation on the non-pointer input's change, not only in an edge
handler.

## Why it is cross-cutting

Seven sites in two files depend on it independently:

- `_JustTooltipState._pointerInside` is retained so an ancestor released by a descendant can show
  again — it will never receive a second `onEnter` (`TooltipShowIntent._reconcile`).
- `TooltipVisibilityScheduler.onChildEnter` cancels `_hoverHideTimer`: a bridge armed by leaving
  the tooltip body would fire while the cursor rests on the child, and the fade-out could never be
  revived.
- `didUpdateWidget` re-derives content and calls `_syncSuppression` / `scheduleReconcile`: a
  `message` arriving under a still cursor is otherwise never noticed.
- `_hideImmediate` leaves `_pointerInside` as it is: a `GlobalKey` move keeps the child's
  `RenderMouseRegion`, and `MouseTracker` keys its edges on that object, so a pointer resting on the
  moved child sends no `onEnter` to set the fact again (#122). The other side of the same fact:
  `didUpdateWidget` clears it on a change of `tap`, which re-creates the region, since the old
  region detaches without `onExit`. The pointer's last position (`_anchorCandidate`, and the
  region's own `_regionPosition`, #141) is cleared with it (#138).
- `didUpdateWidget` clears `_pointerInside` when `enableHover` turns off: removing the region sends
  no `onExit` (a detached region is not `validForMouseTracker`), so the fact would outlive its
  source (#124). `_anchorCandidate` and `_regionPosition` go with it, or a pointer-anchored `controller.show()` anchors
  at a cursor that has left (#138).
- A dismissal's pointer hold (`_pointerHold`) is released only by an edge the pointer's movement
  caused (`_pointerMoved`): an edge after a frame is the tree changing — a route's barrier, the
  region re-created, the child moved — and the pointer may never have left (#127).
- A frozen pointer anchor's `clippedAway` (`_resolveTarget`) is `false` while `_pointerInside`
  holds. A child scrolled from under a resting pointer is clipped during layout, but the `onExit`
  that clears the fact arrives after that frame, so the layout read the stale `true` and nothing
  re-resolved; `onExit` therefore rebuilds while an anchor is frozen, so the overlay resolves
  again (#144).

They share no primitive — a retained bool, a timer cancel in another file, lifecycle hooks — and a
fix to one does not reach the others.

## Territories it holds in

- [show-intent](../territory/show-intent.md) — `_pointerInside`, `TooltipShowIntent._reconcile`.
- [visibility-scheduling](../territory/visibility-scheduling.md) — `onChildEnter`'s `_hoverHideTimer?.cancel()`.
- [content](../territory/content.md) — `didUpdateWidget`'s content re-derivation.
- [nesting-suppression](../territory/nesting-suppression.md) — release of an ancestor relies on `_pointerInside` having been kept, and on its being cleared when `enableHover` goes off (#124).
- [visibility-lifecycle](../territory/visibility-lifecycle.md) — the teardown keeps `_pointerInside` through a `GlobalKey` move (#122).
- [target-resolution](../territory/target-resolution.md) — `_anchorCandidate` is cleared with `_pointerInside` when the region goes away (#138).
- [target-tracking](../territory/target-tracking.md) — a frozen pointer anchor is exempt from the clip-away hide only while `_pointerInside` holds, and `onExit` re-resolves (#144).
- [show-intent](../territory/show-intent.md) — `_pointerMoved` tells an edge the pointer's movement caused from one sent after a frame for the tree changing, and only the first is a new trigger act for an evicted tooltip (#116) or releases a dismissal (#127).

## What a violation looks like

Correct while the cursor moves, wrong once it rests: a tooltip that never appears until the mouse
is jiggled, an ancestor that stays dark after the pointer slides off a nested child, an interactive
tooltip that fades out under a resting cursor and never returns. None throws.

## Discovery history

- #22 / ADR-0003 probe 2 — "releasing an ancestor is impossible": no second `onEnter` arrives.
- #43 — the bridge must be cancelled on the child side too (`GLOSSARY.md` → Hover Bridge; spike header item 3).
- #46 / ADR-0004 commitment 2 — content re-derived on `didUpdateWidget`.
- #122 — the teardown cleared `_pointerInside`, so a hover-shown tooltip moved by a `GlobalKey` under a resting pointer never came back.
- #124 — the opposite: turning `enableHover` off left `_pointerInside` set with no region to clear it, so a nested tooltip kept suppressing its ancestor.
- #127 — the reconcile released a dismissal whenever no trigger was inside, so the edges a dialog's barrier or an `enableHover` toggle sent under a resting pointer brought back a tooltip the user had closed.
- #144 — a focus-held pointer-anchored tooltip with `showDuration`, its child scrolled from under a resting pointer, stayed drawn until the auto-hide and then did not come back: the layout that clipped the child read `_pointerInside` before its `onExit`.
- #138 — the same for the pointer's position: `_anchorCandidate` outlived the region, so a pointer-anchored `controller.show()` anchored where the cursor had been.

## Where it will recur

Any new input mixed with a pointer fact — focus, enabled-ness, async content, a locale — and any
change that removes, replaces or keeps the child's `MouseRegion` while the State lives on. Ask: if this
input changed while the cursor did not move, would anything recompute?
