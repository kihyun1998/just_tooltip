# A scope carries only what its place fixes

## The fact

A `_TooltipScope` widget holds, as fields, only what is fixed for the place it is built in: a
tooltip's scope (`_TooltipScope.tooltip`) holds that tooltip's `state`, and a content scope
(`_TooltipScope.content`) holds no state and its host's `final` `_contentRegistry`. Anything an
enclosing tooltip can change for itself is read from its State, not from the scope widget: a
tooltip scope's `contentRegistry` getter returns `state._inheritedContentRegistry`. Checkable:
the two constructors in `lib/src/just_tooltip.dart` are the only ways to build the scope, and
`_readScope` is the only reader (`git grep -n "getInheritedWidgetOfExactType<_TooltipScope>" -- lib`).

## Why it is cross-cutting

During a `GlobalKey` move the moved subtree is activated top-down (`Element._activateRecursively`
in Flutter's `widgets/framework.dart`, read on 3.41.9): an enclosing tooltip's `activate` runs
first and re-reads its own scope, and `StatefulElement.activate` only marks it dirty. A tooltip
inside it is activated next and reads the enclosing scope widget as it was built in the old place;
the rebuild that would refresh it comes later, and `_readScope` registers no dependency, so nothing
reads it again. A field that the enclosing tooltip re-resolves in its `activate` is out of date
for that read. Three territories read the same scope at that moment.

## Territories it holds in

- [tooltip-registry](../territory/tooltip-registry.md) — `contentRegistry`, read into `_inheritedContentRegistry` and resolved by `_syncRegistry`.
- [nesting-suppression](../territory/nesting-suppression.md) — `state`, read into `_ancestor`; a scope's tooltip is the one that built it, fixed for its place.
- [semantic-tooltip](../territory/semantic-tooltip.md) — the screen-reader yield walks the same `_ancestor` chain from `_readScope`.

## What a violation looks like

A tooltip moved together with the tooltip around it acts on what that tooltip had in its old place.
#119: the tooltip scope carried `contentRegistry: _inheritedContentRegistry` as a field; A wrapping
T moved into host H's content left T on the shared registry, so `t.show()` dismissed H and T with
it, and moved back out, T stayed in H's content registry (`test/just_tooltip_registry_change_test.dart`,
group *a tooltip moved by a GlobalKey with the tooltip around it*).

## Discovery history

- #119 — the tooltip scope's registry became a getter over the State; found as F1 of #114's lens.

## Where it will recur

Any new field on `_TooltipScope`, and any new value a tooltip re-resolves in `activate` that
the tooltips inside it read through the scope. A claim a tooltip leaves in another tooltip's State
is outside this fact: moved together with its nearest ancestor, a tooltip still holds its
suppression claims on the ones above it ([nesting-suppression](../territory/nesting-suppression.md), Known holes).
