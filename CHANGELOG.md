## 0.4.1

### Added

* `JustTooltipTheme.bare()` ([#30](https://github.com/kihyun1998/just_tooltip/issues/30)). A theme that draws no background, padding, shadow, border, or arrow — for a `tooltipBuilder` whose widget already draws its own surface, leaving the tooltip to contribute positioning and nothing else. Previously this meant zeroing `backgroundColor`, `padding`, and `elevation` by hand at every call site, where omitting any one of them silently reintroduced chrome.

### Fixed

* **Behaviour change.** `TooltipAnchor.child` now targets the visible part of the child rather than its whole rect ([#33](https://github.com/kihyun1998/just_tooltip/issues/33)). A child wider than the ancestor clipping it — a row inside a horizontal scroll viewport, say — had its tooltip aimed at a centre nobody could see. Measured: a 900px child in a 400px viewport placed its tooltip at `x = 450`, entirely outside the scroll view, with the cursor at `x = 200`.
  * `screenMargin` never helped: it confines the tooltip to the `Overlay`, usually the whole app, which an off-screen anchor satisfies.
  * A viewport reports a clip whenever `clipBehavior` is not `Clip.none`, so any `JustTooltip` inside a `ListView` or `SingleChildScrollView` may shift — always toward the visible part. An unclipped child is unaffected.
  * `TooltipAnchor.pointer` was never affected, which is why both known downstreams had independently adopted it as a workaround.
  * A child clipped away entirely — reachable only via `controller.show()`, since a hovering pointer proves a visible part exists — anchors at the clip edge the child lies beyond. Showing is not refused: a tooltip already on screen stays put when its child scrolls out of sight, so the same state is legal a frame later.
* A visible tooltip now tracks its child ([#35](https://github.com/kihyun1998/just_tooltip/issues/35)). The target was resolved once, when the tooltip appeared, so a scroll, a resize, a layout animation, or an insertion above the child left the tooltip pointing where the child used to be. It now re-aims after any frame that moves the child, and hides once the child is clipped away entirely — nothing to point at, no tooltip. `controller.show()` against an already-invisible child still anchors at the clip edge rather than refusing.
* The target rect now follows the child's paint transform. `Transform.scale` between the child and the `Overlay` previously produced a target whose origin was transformed but whose size was not, so a `2.0`-scaled 100×50 child yielded a 100×50 target at the origin and a `TooltipDirection.bottom` tooltip drawn on top of the child instead of below it.

## 0.4.0

### Added

* `JustTooltip.anchor` and `TooltipAnchor` ([#21](https://github.com/kihyun1998/just_tooltip/issues/21)). `TooltipAnchor.pointer` keeps the child as the hover region but anchors the tooltip at the cursor — for a child much wider than the pointer's neighbourhood (a table row, a wide card), whose centre is nowhere near where the user is looking. Defaults to `TooltipAnchor.child`, the existing behaviour.
  * The anchor is captured when the tooltip is shown and does not follow the pointer, so `interactive` tooltips stay reachable.
  * Tap-triggered tooltips anchor at the tap; a touch fires no hover events, so the tap-down supplies the position.
  * A programmatic `controller.show()` with no pointer present falls back to the child's rect.
  * Against a point there are no target edges to align to, so `alignment` says which of the tooltip's own edges lands on the pointer.

### Changed

* **Behaviour change for nested tooltips.** A `JustTooltip` containing the pointer now suppresses *every* enclosing `JustTooltip`, regardless of registry. If you relied on a nested tooltip and its ancestor being visible together (only reachable by giving them separate `TooltipRegistry` instances), that no longer happens. Suppression gates hover only — a programmatic `controller.show()` is unaffected.

### Fixed

* Nested `JustTooltip`s now reliably show only the innermost tooltip under the pointer ([#22](https://github.com/kihyun1998/just_tooltip/issues/22)). Previously this held only by coincidence — the "one tooltip at a time" registry dismissed the ancestor *after* it had shown — and broke in three ways:
  * an ancestor's `waitDuration` timer would fire while the pointer rested on a nested child, replacing the inner tooltip with the outer one;
  * moving from a nested child back onto its ancestor showed nothing at all, because the ancestor's hover region was never exited and so never re-entered;
  * tooltips scoped to separate `TooltipRegistry` instances showed both at once.

* The tooltip is now positioned against its target in the coordinate space of the `Overlay` it is laid out in, rather than the window's ([#24](https://github.com/kihyun1998/just_tooltip/issues/24)). The two coincide for a full-window `MaterialApp`, so nothing changes there — but a tooltip under a nested `Navigator`, an inset `Overlay`, or an embedded Flutter view was displaced by the Overlay's offset, and its direction flipping and `screenMargin` clamping were measured against the wrong bounds.

### Internal

* Pointer facts (`_pointerInside`, and the pointer's last position) are now retained and a *hover intent* boolean derived from them, coalesced into a microtask and handed to `TooltipVisibilityScheduler` on transition only. This makes hover behaviour independent of Flutter's `MouseTracker` dispatch order. See ADR-0003. The one collaborator that must observe a hover transition synchronously — the tooltip body's `onEnter`, which cancels the hover bridge — flushes the pending recomputation first.
* `TooltipVisibilityScheduler` and `TooltipRegistry` are unchanged.
* `JustTooltipPositionDelegate.targetRect` is documented as being in the `Overlay`'s coordinate space; the child rect and the pointer anchor both arrive in it.
* A second example entry point (`example/lib/spike_wide_row.dart`) exercises pointer anchoring, nested suppression, an inset `Overlay` and an interactive tooltip together.
* Test coverage: 125 tests. Every test added this release was mutation-checked — reverting the code it covers must make it fail.

## 0.3.0

### Breaking

* `JustTooltipController` is no longer a `ChangeNotifier`. It is now an attach-based command source (modeled on Flutter's `OverlayPortalController`): `show()`/`hide()`/`toggle()` drive the attached tooltip, which is the single source of truth for visibility.
  * removed the `shouldShow` getter — use `isShowing` (reflects the tooltip's live state) instead
  * removed `addListener`/`removeListener`/`dispose` (`ChangeNotifier` API) — observe visibility via the widget's `onShow`/`onHide` callbacks
  * removed the internal `resetShouldShow()`
* Narrowed the public API — `JustTooltipPositionDelegate`, `TooltipShapePainter`, and `JustTooltipOverlay` are no longer exported (they are internal implementation details). The public surface is now `JustTooltip`, `JustTooltipController`, `JustTooltipTheme`, `TooltipRegistry`, and the enums.

### Added

* An optional `registry` parameter and `TooltipRegistry` class to scope the "one tooltip visible at a time" policy — pass a shared `TooltipRegistry()` to a group of tooltips to isolate them (or a test); omitting it keeps the app-global default.

### Fixed

* `controller.show()` called before the `JustTooltip` mounts is now honoured (the queued show is applied once mounted); previously it was ignored.
* `slide` and `fadeSlide` animations now enter from the auto-flipped (resolved) direction — a tooltip that flips (e.g. `top` → `bottom` near a screen edge) slides in from the side it actually appears on, not the originally-requested one.

### Internal

* Extracted the hover/auto-hide timing into a dedicated `TooltipVisibilityScheduler` (timer cancellation collapsed into one place).
* Extracted the 7 show/hide animations into a dedicated `TooltipTransitions` module.
* Moved the single-visible-tooltip policy out of a static `Set` into the injectable `TooltipRegistry`.
* Test coverage raised to ~97% (scheduler, transitions, registry, controller, painter, and hover integration).

## 0.2.5

* **feat** add `TooltipAlignment.startTargetCenter` and `endTargetCenter` alignments where the arrow dynamically points to the center of the target widget
* **example** add `Top-StartTarget` and `Top-EndTarget` quick presets to playground

## 0.2.4

* **feat** add `hideOnEmptyMessage` parameter to suppress tooltip when `message` is empty (default: `true`)
* **example** add `hideOnEmptyMessage` toggle to Content section in playground

## 0.2.3

* **fix** `borderColor` not visible on non-arrow tooltips (`showArrow: false`) due to `Material` background covering `DecoratedBox` border

## 0.2.2

* **fix** rename `TooltipPositionDelegate` → `JustTooltipPositionDelegate` to resolve name conflict with Flutter SDK's `TooltipPositionDelegate` (introduced in Flutter 3.32)

## 0.2.1

* **feat** add `TooltipAnimation` enum with 7 animation types: `none`, `fade`, `scale`, `slide`, `fadeScale`, `fadeSlide`, `rotation`
* **feat** add `animation` and `animationCurve` parameters for animation type and curve selection
* **feat** add `fadeBegin`, `scaleBegin`, `slideOffset`, `rotationBegin` parameters for fine-tuning animations
* **docs** add Animation section to README with usage examples and API reference
* **example** add Animation section with type/curve dropdowns and parameter sliders

## 0.2.0

* **BREAKING** extract 12 visual styling parameters into `JustTooltipTheme` class
  * `backgroundColor`, `borderRadius`, `padding`, `elevation`, `boxShadow`, `borderColor`, `borderWidth`, `textStyle`, `showArrow`, `arrowBaseWidth`, `arrowLength`, `arrowPositionRatio` are now accessed via `theme` parameter
  * Migration: wrap style params in `theme: JustTooltipTheme(...)`
* **feat** add `JustTooltipTheme.copyWith()` for easy theme derivation
* **feat** `JustTooltipTheme` is a reusable data class with `==` / `hashCode` support

## 0.1.7

* **fix** controller `show()` not working after tooltip was dismissed by hover-out or auto-hide

## 0.1.6

* **feat** add `showArrow` parameter with unified path rendering (arrow integrated into tooltip shape)
* **feat** add `arrowBaseWidth` and `arrowLength` parameters for arrow size customization
* **feat** add `arrowPositionRatio` parameter to control arrow placement along the tooltip edge
* **feat** add `borderColor` and `borderWidth` parameters for tooltip outline (follows arrow shape)
* **feat** arrow auto-flips with tooltip direction when viewport space is insufficient
* **fix** tooltip not reappearing when re-hovering during fade-out animation

## 0.1.5

* **feat** add viewport overflow protection with auto direction flip and position clamping
* **feat** add `screenMargin` parameter to control minimum distance from screen edges
* **docs** `tooltipBuilder` now documents that content sizing is the caller's responsibility

## 0.1.4

* **fix** `interactive` mode now properly pauses auto-hide timer while cursor is on tooltip

## 0.1.3

* **feat** add `boxShadow` parameter for custom shadow control (color, blur, spread, offset)

## 0.1.2

* **feat** add `interactive` option to control whether tooltip stays visible on hover
* **feat** add `waitDuration` for delayed tooltip appearance on hover
* **feat** add `showDuration` for auto-hiding tooltip after a set time with timer reset on re-enter

## 0.1.1

* **feat** add `crossAxisOffset` parameter for shifting tooltip along the cross-axis

## 0.1.0

* **implement** JustTooltip core widget with direction (top/bottom/left/right) + alignment (start/center/end)
* **implement** JustTooltipController for programmatic show/hide/toggle
* **implement** tooltip position utils with 12-combination anchor mapping and RTL support
* **feat** hover and tap trigger modes
* **feat** fade animation with configurable duration
* **feat** custom tooltip content via `tooltipBuilder`
* **feat** single-instance enforcement (only one tooltip visible at a time)
* **feat** interactive playground example app with theme switching
