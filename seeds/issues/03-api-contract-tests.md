---
title: "Add a health and readiness contract test for the API"
labels: "testing,copilot-agent,reliability"
---

The Helm chart points both the liveness and readiness probes at `GET /health`, but nothing
verifies that endpoint's contract. If someone changes the route or the response shape, the
first symptom is pods failing readiness in a live deployment — the most expensive possible
place to discover it.

**Agent-sized.** Small, well-bounded, and it closes a real gap between the app and the chart.

### Acceptance criteria

- [ ] Use `Microsoft.AspNetCore.Mvc.Testing` (`WebApplicationFactory<Program>`) so the test
      exercises the real pipeline rather than calling a handler directly.
- [ ] `GET /health` returns `200`.
- [ ] `GET /orders/search?q=Northwind` returns `200` and at least one order, proving the
      in-memory repository fallback engages when no connection string is configured. CI has
      no SQL Server, so this fallback is what keeps the suite hermetic.
- [ ] `GET /orders/999999` returns `404`.
- [ ] `GET /orders/1001/totals` returns `200` with a body containing the calculated totals.
- [ ] The probe paths asserted in the tests match those in
      `app/deploy/helm/templates/api.yaml`. Reference the chart in a comment so the coupling
      is explicit rather than accidental.

### Notes

`Program.cs` uses top-level statements. `WebApplicationFactory<Program>` needs `Program` to
be accessible, which usually means adding `public partial class Program { }` at the end of
the file or an `InternalsVisibleTo`. Either is acceptable; say which you chose in the PR.

Do not add a SQL Server dependency to the test suite. The whole point of the in-memory
fallback is that CI stays hermetic and fast.
