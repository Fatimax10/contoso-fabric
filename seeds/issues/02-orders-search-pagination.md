---
title: "Add pagination to the orders search endpoint"
labels: "enhancement,copilot-agent,api"
---

`GET /orders/search?q=` returns every match in one response. With five seeded orders that is
fine; with a realistic catalogue it is a denial-of-service vector against our own API.

**Agent-sized.** Use this as a second delegation if the room wants to see the agent handle
something with a little more surface area than a pure-function test task.

### Acceptance criteria

- [ ] Accept `page` (1-based, default 1) and `pageSize` (default 20, maximum 100).
- [ ] Reject `page < 1`, `pageSize < 1`, and `pageSize > 100` with `400` and a problem detail
      that names the offending parameter.
- [ ] Response shape becomes `{ "items": [...], "page": n, "pageSize": n, "totalCount": n }`.
- [ ] `IOrdersRepository.SearchAsync` gains paging parameters, and **both** implementations
      are updated — `InMemoryOrdersRepository` and `OrdersRepository`.
- [ ] New tests in `Contoso.Fabric.Api.Tests` covering first page, last partial page, a page
      beyond the end (empty items, correct `totalCount`), and each validation failure.
- [ ] Existing tests still pass.

### Important constraint

`OrdersRepository` builds its SQL by string interpolation. **That is planted finding
CF-SEC-010 and it must stay exactly as it is** — it is the Beat 6 CodeQL demonstration.

Add the paging clause in the same style as the surrounding code. Do not take the opportunity
to parameterise the query, and do not "tidy" it. If that instruction feels wrong: it is, and
that is the point — see `seeds/FINDINGS.md`. Remediating CF-SEC-010 has its own issue.
