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
