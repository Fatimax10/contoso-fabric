---
title: "Add unit test coverage for PricingCalculator"
labels: "good first issue,copilot-agent,testing"
---

`Contoso.Fabric.SharedLib.PricingCalculator` is the only component in the solution with **zero
test coverage**, and it is the one that decides what customers are charged. Every other
project has tests; this one was written under time pressure and never got any.

**Agent-sized. This is the Beat 4 task — assign it to the Copilot coding agent.**

### Why this one is a good delegation target

It is the ideal shape for autonomous work, and it is worth saying why out loud rather than
just showing the result:

- **Pure functions.** No I/O, no clock, no database, no network. The agent cannot get stuck
  on environment setup.
- **The rules are fully specified below.** The agent does not have to guess business intent.
- **Verifiable.** Success is unambiguous: tests exist, they pass, and they cover the branches.
- **Self-contained.** One project, one file, no cross-cutting refactor.

Tasks that are vague, cross-repository, or require a judgement call about product behaviour
are exactly the tasks the agent handles badly. Delegating well is a skill, not a switch.

### The rules the calculator implements

Read `PricingCalculator.cs` for the authoritative version. Summarised:

| Rule | Behaviour |
| --- | --- |
| Loyalty discount | Per `LoyaltyTier` — see `DiscountRateFor` |
| Bulk discount | Breaks at 50 / 20 / 10 units → 15% / 10% / 5% |
| Stacking | Loyalty and bulk stack **additively**, capped at **25% total** |
| Tax | Applied to the **discounted** subtotal, never the gross |
| Shipping | Free at ≥ 75.00, otherwise 6.95 |
| Rounding | `Math.Round(value, 2, MidpointRounding.AwayFromZero)` |

### Acceptance criteria

- [ ] A new `Contoso.Fabric.SharedLib.Tests` xUnit project, added to `ContosoFabric.sln`.
- [ ] Coverage for every `LoyaltyTier` value.
- [ ] Coverage for each bulk break **and the boundaries either side** (9/10, 19/20, 49/50).
- [ ] A test proving the 25% combined cap actually binds — pick a tier and quantity whose
      uncapped sum would exceed 25%.
- [ ] A test proving tax is charged on the discounted subtotal, not the gross.
- [ ] Both shipping cases, including the 75.00 boundary exactly.
- [ ] At least one rounding test that would fail under banker's rounding, so the
      `AwayFromZero` choice is actually pinned down.
- [ ] Empty and null line collections handled.
- [ ] `dotnet test ContosoFabric.sln` passes.

### Out of scope

Do not change `PricingCalculator.cs` itself. If a test reveals what looks like a bug, write
the test to document the **current** behaviour and raise it in the PR description instead.
Changing the implementation and the tests in the same PR removes the only evidence that the
tests were written against real behaviour.

Do not touch any other planted finding — see `seeds/FINDINGS.md`.
