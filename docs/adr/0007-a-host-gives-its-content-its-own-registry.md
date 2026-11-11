# 0007 — A host gives its content its own registry

- **Status:** Accepted
- **Date:** 2026-10-24
- **Context issue:** [#84](https://github.com/kihyun1998/just_tooltip/issues/84) (a tooltip inside another tooltip's content closes its host on the shared registry)

## Context

A `JustTooltip` inside another tooltip's `tooltipBuilder` content took part in the same app-global [Tooltip Registry](../../GLOSSARY.md#tooltip-registry) as its host. When it showed, the registry's one-visible rule dismissed the host, and the inner tooltip went with the host's content: nothing was left on screen. Nesting could not prevent this, because content is cut off from nesting (ADR-0005).

Measured on Flutter 3.47.1 with the host shown by its controller or by hover, and the mouse moving from the host child to the host body and then onto the inner child:

| inner registry | host | inner |
|---|---|---|
| shared (default) | gone | gone |
| `TooltipRegistry()` | shown | shown |

The same happened to a touch tap on a `claim` tooltip in the content, and to a tooltip nested inside a content tooltip. Flutter's `RawTooltip` behaves the same with a `RawTooltip` in another's `tooltipBuilder`. Its rule of keeping hovered tooltips open does not cover the case, because `_ExclusiveMouseRegion` delivers the enter to the inner region only.

## Decision

Each tooltip owns a `TooltipRegistry` for the tooltips in its own content and hands it down through the private `_TooltipScope` as `contentRegistry`.

- The scope around the overlay child carries the host's registry.
- The scope around the child carries whatever registry this tooltip inherited, so a tooltip nested inside a content tooltip stays in the same content.

A tooltip resolves its registry as `widget.registry ?? inherited content registry ?? shared`.

- **Amended 2026-11-11 (#114), the maintainer's call: a tooltip whose registry changes while it is shown moves at once.** It leaves the old registry — which, if the tooltip held the place there, revives the tooltips it evicted — and joins the new one, dismissing the tooltip that held the place there, as a show does. Before, the registry was re-resolved on every read, so the show registered in the old registry and its end was reported to the new one: the old registry kept dismissing the tooltip, and (since #113) kept the tooltips it had evicted waiting for another show there to end. Shown two widget-test repros (Flutter 3.47.1): T shown in `r1`, rebuilt with `registry: r2`, and X's show in `r1` dismissed T; A hover-shown in `r1`, evicted by X, X rebuilt with `registry: r2`, and `x.hide()` left A hidden (A came back on efd4042, before #113). The alternative was to release in the registry the show registered with and use the new one from the next show; it fixes the second repro only. The cost they were told: changing only the `registry` parameter can dismiss a tooltip shown in the new registry. This is a judgement, not a derivation; it is the maintainer's to reverse.
  - It holds for both ways the resolved registry changes: `widget.registry` (in `didUpdateWidget`) and the inherited content registry (re-read in `_readScope`). The second changes only when the tooltip moves in the tree by a `GlobalKey`, which ends its show first, so for that path it is the evicted case below that applies. One such move is missed altogether — a tooltip moved together with an enclosing tooltip keeps its old content registry (predates #114; [tooltip-registry](../map/territory/tooltip-registry.md), Known holes).
  - The implementer's derivation, not the call: a tooltip evicted in the old registry waits in the new one — revived when no tooltip holds the place there, otherwise once that one leaves. "Evicted" means a tooltip in its own registry holds the place; after the move that question is asked of the registry it now belongs to, and a revival asks it again when it runs, so a group of tooltips moved together by one rebuild keeps its holder. A shown tooltip joins only through `_show`'s gates (not fading out, with content, not Covered); a tooltip fading out on its own hide leaves the old registry and does not join the new one, since its show is ending. The dismissal a join causes runs after the build, not inside it.

Maintainer's call (2026-10-24), chosen over two options it was shown, with the measurements above and a prototype:

- **The registry spares tooltips under the pointer** (Flutter's rule). A touch sends no hover, so the touch case stays broken, and any hovered tooltip anywhere would survive another's show.
- **Documenting "give content tooltips their own registry."** A consumer who misses the documentation still gets a silent blank.

ADR-0003's ruling stands. The `TooltipRegistry` class gains no notion of ancestry. Which registry a tooltip uses is decided in the widget tree, where the tree structure already lives. ADR-0005's cut stands too: a content tooltip still has no ancestor tooltips, and the scope still carries `state: null`.

## Consequences

- **Positive:** a tooltip in the content shows beside its host, whether shown by hover, a tap or touch, and so does a tooltip nested inside it. This automates the workaround of giving it a separate registry.
- **Kept:** tooltips in the same content are still one at a time. An unrelated tooltip's show still dismisses the host, and the content goes with it.
- **Kept:** an explicit `registry` still wins, including inside content.
- **Accepted:** a content tooltip no longer dismisses tooltips outside its host. While the host is shown on the shared registry, the only other tooltip one could dismiss is on a registry of its own.
- **Cost:** every tooltip allocates one empty `TooltipRegistry` (a `Set`).
