# Contoso Fabric — agent instructions

## What this repository is

A **demonstration harness** for a DevOps platform evaluation. It contains a polyglot
microservice application plus a set of *intentionally planted* defects. Read
`seeds/FINDINGS.md` before changing anything under `app/`.

## Critical rule: do not "fix" planted findings unless asked

Files and code paths listed in `seeds/FINDINGS.md` contain deliberate vulnerabilities that
exist to demonstrate a specific security tool. Removing them silently breaks the demo.

- If a task explicitly asks you to remediate a finding (e.g. "fix the SQL injection in
  OrdersRepository"), do it properly and reference the finding ID in the PR description.
- Otherwise, leave them alone — even if you notice them while working nearby.
- Never add new hardcoded credentials. The existing ones are fake and already catalogued.

## Architecture

| Service | Path | Stack | Responsibility |
|---------|------|-------|----------------|
| Orders API | `app/src/api-dotnet` | .NET 9 minimal API | Order CRUD + search, owns the SQL schema |
| Web | `app/src/web-next` | Next.js 15 / React 19 | Customer-facing storefront |
| Worker | `app/src/worker-python` | Python 3.12 | Consumes Service Bus, writes reports |
| Shared lib | `app/src/shared-lib` | .NET 9 classlib | Pricing/tax rules shared by API and worker |

The worker talks to the API over HTTP; it never touches the database directly.
`shared-lib` must stay free of I/O — it is pure calculation so it can be unit tested cheaply.

## Build and test

```powershell
dotnet build  app/src/ContosoFabric.sln
dotnet test   app/src/ContosoFabric.sln
npm --prefix app/src/web-next ci ; npm --prefix app/src/web-next run build
python -m pytest app/src/worker-python -q
```

`scripts/verify-local.ps1` runs all of the above. CI must be green before any PR merges.

## Conventions

- **C#**: file-scoped namespaces, `sealed` by default, `async`/`await` all the way down,
  no `.Result` or `.Wait()`. Nullable reference types are enabled — keep them clean.
- **TypeScript**: strict mode, no `any`, server components by default; add `"use client"`
  only when the component genuinely needs browser APIs.
- **Python**: type hints on every public function, `ruff` clean, no bare `except:`.
- **Tests**: xUnit + FluentAssertions (.NET), pytest (Python), Vitest (web). Name tests
  `MethodName_Scenario_ExpectedOutcome`.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`). Reference the
  issue number. For Track 4 also include the Azure Boards link (`AB#123`).

## Security expectations for new code

- Parameterise every SQL query. `Microsoft.Data.SqlClient` parameters, never interpolation.
- Validate and canonicalise any path derived from user input before touching the filesystem.
- Escape all user-controlled data rendered into HTML. Do not introduce
  `dangerouslySetInnerHTML`.
- Authenticate to Azure with `DefaultAzureCredential` / workload identity. No connection
  strings or keys in code, config, or workflow files.

## Infrastructure

Terraform under `infra/terraform` is the source of truth — including the GitHub org, repo
rulesets, and the Azure DevOps project. Never click-configure something that Terraform owns;
change the code and re-apply, or the demo's "reset" script will revert your change.
