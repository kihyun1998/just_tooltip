# Reach-aware semantic yield

Nested `JustTooltip`s yield their screen-reader text structurally: an outer tooltip is silent while
any tooltip inside its child would be heard. The yield does not ask whether a screen reader can
actually reach that inner tooltip, and it will not.

## What it costs

An inner tooltip under `ExcludeSemantics`, `Offstage`, `Visibility(maintainState: true)` or on a
hidden `IndexedStack` child is never heard, yet it still silences the tooltip around it, so nothing
is heard at all:

```dart
JustTooltip(
  message: 'Outer',
  child: IndexedStack(
    index: 0,
    children: [
      const Text('shown'),
      JustTooltip(message: 'Inner', child: ...), // hidden, and the outer is silent
    ],
  ),
)
```

The way out is the consumer's: set `excludeFromSemantics: true` on the inner tooltip that cannot be
reached.

## Why this is out of scope

Whether a descendant reached the semantics tree is not knowable through Flutter's public API. A
hidden child's render object still has `describeSemanticsConfiguration` called (measured on Flutter
3.41.9), so it cannot tell from there that it was dropped. The only signal is the assembled
semantics tree after a flush: the core would have to inspect it, then re-mark the outer tooltip and
wait for the next frame. That is a frame of wrong output on every change, and a dependency on how
Flutter assembles semantics, which is not a contract. The structural rule is exact for every tree a
screen reader can walk, and the hidden case has a one-line fix where the consumer knows the subtree
is hidden.

Recorded in ADR-0009's consequences; the territory note is `docs/map/territory/semantic-tooltip.md`.

## Prior requests

- #94: "A tooltip a screen reader cannot reach still silences the tooltip around it"
