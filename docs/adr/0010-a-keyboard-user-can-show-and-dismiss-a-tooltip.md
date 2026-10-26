# 0010 — A keyboard user can show and dismiss a tooltip

- **Status:** Accepted
- **Date:** 2026-10-26
- **Context issue:** [#92](https://github.com/kihyun1998/just_tooltip/issues/92) (a focused child does not show its tooltip, and nothing dismisses it with Escape)
- **Amends:** [0003 — Nesting suppression gates a derived hover intent](0003-nesting-suppression-gates-a-derived-hover-intent.md): hover intent becomes [Show Intent](../../GLOSSARY.md#show-intent), with a focus fact and a dismissal term.

## Context

A tooltip showed on hover, on tap and by `controller.show()`, never on focus, and no key closed it. Measured on Flutter 3.41.9 (#92's triage): a `TextButton` child given focus by `requestFocus()` showed nothing; a shown tooltip stayed open through Escape. Flutter's own `Tooltip` does not show on focus either, and neither `raw_tooltip.dart` nor `material/tooltip.dart` handles Escape, so this goes past the prior art and rests on its own reasons.

The yardstick is WCAG 2.1 SC 1.4.13, Content on Hover or Focus (w3.org/TR/WCAG21, read 2026-10-26). For content that pointer hover or keyboard focus makes visible, it asks that the content be **dismissible** "without moving pointer hover or keyboard focus", **hoverable**, and **persistent** "until the hover or focus trigger is removed, the user dismisses it, or its information is no longer valid". Its Note 2 names custom tooltips.

## Decision

Maintainer's calls (2026-10-26, grilling on #92's triage):

- **Focus is a core trigger, opt-in: `enableFocus: bool = false`**, beside `enableHover`. A consumer could already call `controller.show()` from `Focus(onFocusChange:)`, but that path bypasses nesting suppression (a programmatic show is not suppressed, ADR-0003) and the trigger-removal hide, which only a core trigger joins. Off by default, so no consumer's keyboard behaviour changes. Chosen over on-by-default and over leaving it to consumers.
- **Focus joins hover in one derived state, renamed Show Intent.** The focus fact sits beside the pointer fact; `waitDuration`, nesting suppression, the content gate and the hide on losing the trigger apply to both from one place. Chosen over a separate path like tap (ADR-0006), which would need suppression rebuilt for it.
- **Only keyboard focus counts** — focus inside the child while `FocusManager.highlightMode` is `traditional`, the condition for a focus ring. Otherwise a tap that focuses a text field would open its tooltip on every touch.
- **Escape dismisses, on by default.** Dismissal only ever closes, so turning it on cannot break a layout. A hover-shown tooltip's child need not have focus, so the core listens to the keyboard while a tooltip is shown; a consumer has no focus to attach a shortcut to.
  - It closes **the most recently shown** visible tooltip, one per press. More than one can be visible: a host and a tooltip in its content (ADR-0007), or tooltips on separate registries.
  - It **consumes the key only where it can**: when focus is inside the closed tooltip's child, the close runs as the `DismissIntent` action on the focus path, so a dialog behind waits for the next press. A tooltip shown with focus elsewhere — a hover — is closed from a `HardwareKeyboard` handler, and that cannot consume: measured on Flutter 3.41.9, a handler returning `true` still let the dialog's Escape through, so both close. Patching `KeyEventManager.keyMessageHandler` would consume, but it can never be reverted, so it was rejected. Grilling chose "consume only when closed" before this was measured; shown the measurement, the maintainer chose this hybrid over a global handler alone and over the focus path alone, which would leave a hovered tooltip undismissable (2026-10-26, #92's confirm stop).
  - With nothing to close, the focus-path action forwards to the enclosing `DismissIntent` action: a nearer `Actions` for an intent shadows the ancestor's even while disabled (measured), so a tooltip around a dialog's button would otherwise keep the dialog from closing.
  - It closes a tooltip **however it was opened**, `controller.show()` included: the user may always dismiss.
  - A dismissed tooltip stays closed **until its trigger leaves and returns** — the pointer leaves and re-enters the child, or focus leaves and comes back. A tap still toggles it.
- **The two existing opt-outs are documented, not changed.** `showDuration` breaks *persistent* and `interactive: false` breaks *hoverable*; their defaults (`null`, `true`) satisfy the criterion, and their dartdoc says so.

## Consequences

- **Accepted:** a tooltip shown by keyboard focus on a `waitDuration` tooltip waits like a hover does.
- **Accepted:** Escape reaches every tooltip, including ones a consumer meant to stay up; such a consumer re-shows it.
- **Not covered:** showing a tooltip from a screen reader's focus — that is [Semantic Tooltip](../../GLOSSARY.md#semantic-tooltip) (ADR-0009), which is heard without opening.
