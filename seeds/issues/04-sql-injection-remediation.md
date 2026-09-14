---
title: "Security: parameterise the SQL in OrdersRepository (CF-SEC-010)"
labels: "security,codeql,remediation"
---

CodeQL raises `cs/sql-injection` against
`app/src/api-dotnet/Contoso.Fabric.Api/Data/OrdersRepository.cs`. Both `SearchAsync` and
`GetByIdAsync` build SQL by string interpolation from caller-supplied input.

> **Demo sequencing:** this is the Beat 6 remediation task. Do **not** merge a fix before the
> Beat 6 CodeQL alert has been shown, or the alert disappears from the security tab and the
> demonstration has nothing to point at. `scripts/reset-demo.ps1` restores the vulnerable
> version between runs.

### The vulnerability

```csharp
var sql = $"SELECT {Columns} FROM dbo.Orders " +
          $"WHERE Customer LIKE '%{searchTerm}%' OR Sku LIKE '%{searchTerm}%' " +
          $"ORDER BY CreatedUtc DESC";
```

`searchTerm` reaches the database as SQL text. `SearchTerm.TryNormalize` limits length and
collapses whitespace, which is why this is easy to mistake for "already validated" — but
length validation is not escaping, and a 64-character payload is more than enough.

### Acceptance criteria

- [ ] Both methods use `SqlParameter` with explicit `SqlDbType` and size, not interpolation.
- [ ] The `LIKE` wildcards are applied to the **parameter value**, not concatenated into the
      SQL text.
- [ ] `%`, `_`, and `[` in user input are escaped so they are treated as literals, with an
      explicit `ESCAPE` clause. Getting this wrong is the usual half-fix.
- [ ] `Columns` stays a compile-time constant — it is not user input and does not need
      parameterising. Say so in a comment so the next reader does not have to re-derive it.
- [ ] A test proving `'; DROP TABLE dbo.Orders; --` is treated as a literal search term.
- [ ] A test proving a search for `%` returns only orders literally containing `%`.
- [ ] CodeQL no longer reports `cs/sql-injection` for this file.

### Do not

Do not "fix" this by tightening `SearchTerm` validation. Input validation is a useful second
layer, but it is not the fix, and presenting it as one is how this class of bug survives code
review for years.
