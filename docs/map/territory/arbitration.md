# Aggregate — arbitration

**This note owns no detail.** Two rules deciding which of several tooltips shows.

| Concept | Note |
|---|---|
| innermost with content wins, tree-local, before showing | [nesting-suppression](nesting-suppression.md) |
| one visible per registry, app-global, after showing | [tooltip-registry](tooltip-registry.md) |

## Why they sit together

Both answer "which tooltip?", and ADR-0003 keeps them orthogonal: suppression is **preventive**
(a suppressed tooltip never schedules), the registry is **reactive** (someone else showed, so I
hide). Neither reads the other's state.

## Why both remain

Before ADR-0003, innermost-wins was the registry's last-show-wins plus Flutter's outermost-first
enter order — a coincidence that a `waitDuration`, a release back onto the ancestor, or separate
registries each broke (ADR-0003 probes 1–3). Removing either rule re-opens one of those: drop
suppression and the probes fail again; drop the registry and siblings that are not nested show
together. ADR-0003 forbids re-proposing "let the registry handle nesting".
