# DevOps Showcase — 5 Demo Tracks

A **real, deployable POC** that replays one identical SDLC storyline across five platform
configurations, so the differences between them become self-evident rather than asserted.

| Track | Configuration | Positioning |
|-------|---------------|-------------|
| T1 | GitHub Enterprise Cloud + Copilot | Cloud-native, AI-first — the north star |
| T2 | GitHub Enterprise Server (standalone) | Sovereign / disconnected |
| T3 | GHES + GHEC via GitHub Connect | Regulated data + cloud AI |
| T4 | GHEC + Azure DevOps | Coexistence — Boards / Artifacts / Test Plans |
| T5 | Azure DevOps Server (standalone) | The "before" picture |

## The spine

One app — **Contoso Fabric**, a polyglot microservice set on AKS — and one 12-beat storyline.
Every track is scored against the same 12 beats. The comparison *is* the product.

| # | Beat | What the audience sees |
|---|------|------------------------|
| 1 | Plan | Work item created, sized, linked to an epic |
| 2 | Spec & context | Copilot Spaces / custom instructions / `AGENTS.md` set the house rules |
| 3 | Code | Copilot chat, agent mode, next-edit-suggestions in the IDE |
| 4 | Delegate | Issue assigned to the Copilot cloud agent → autonomous PR |
| 5 | Commit gate | Planted secret blocked by push protection |
| 6 | Review | Copilot code review + CodeQL + Dependabot + dependency review |
| 7 | CI | Matrix build on ARC runners on AKS + GitHub-hosted runners |
| 8 | Supply chain | SBOM, build provenance attestation, immutable actions |
| 9 | CD | Environments, approvals, OIDC (no secrets) → AKS blue/green |
| 10 | Observe | App Insights release annotation, Azure Monitor alert, Defender for Cloud |
| 11 | Incident | Alert → issue → re-delegated to Copilot → hotfix |
| 12 | Govern | Rulesets, audit log streaming, Copilot usage metrics, cost attribution |

## Layout

```
app/          Contoso Fabric — the demo application
  src/api-dotnet      .NET 9 orders API      (planted: SQL injection, hardcoded secrets)
  src/web-next        Next.js front-end      (planted: XSS)
  src/worker-python   Python worker          (planted: path traversal, flaky test)
  src/shared-lib      .NET class library     (planted: ZERO test coverage — agent task)
  deploy/helm         Helm chart for AKS
infra/terraform/      00-shared 10-aks 20-ghes 30-ado-server 40-github 50-ado
.github/workflows/    Reusable workflows (build-dotnet, build-node, build-python,
                      codeql, deploy-aks) plus the `ci` caller that consumes them
pipelines/            Azure DevOps YAML templates (T4/T5 parity)
seeds/                Planted-finding manifest, backlog issue bodies, and plan/plan.json
scripts/              bootstrap / seed-plan / verify / reset / teardown
docs/                 run-of-show per track, comparison matrix, cost model, labs
```

> Reusable workflows have to live in `.github/workflows/` to be callable via
> `uses: <org>/<repo>/.github/workflows/<file>.yml@<ref>`, so they are stored there rather
> than in a top-level `workflows/` folder.


## The plan lives in the platforms, not in this repository

[`seeds/plan/plan.json`](seeds/plan/plan.json) is the canonical delivery plan — 54 items,
four sprints, in two streams: the work of building the showcase, and the in-universe Contoso
Fabric product backlog that the audience sees during Beat 1.

It is not the place you read the plan. It is the place the plan is *defined*. Two scripts
project it into the platforms being compared:

```powershell
./scripts/seed-github-plan.ps1 -Organization contoso-showcase
./scripts/seed-ado-plan.ps1    -Organization https://dev.azure.com/contoso -Project 'Contoso Fabric'
```

GitHub gets labels, a milestone per sprint, issues linked into a real **sub-issue hierarchy**,
and a Projects v2 board carrying Type, Stream, Track, Beat and Estimate. Azure DevOps gets area
paths, dated iterations assigned to the team, and Epic → Feature → User Story with story points.
Both are idempotent, matched on exact title.

The single source matters more than either projection. If the two boards were maintained
separately they would drift within a week, and the Track 1 versus Track 4 comparison — which is
the whole point of Track 4 — would be comparing two different backlogs rather than two tools.

Edit the plan; re-seed. Edits made in a board and not in the plan are silently undone on the
next run, which is the intended direction of travel.


## Planted findings

Every seeded defect exists to fire **exactly one** demo beat. Nothing here is accidental —
see [seeds/FINDINGS.md](seeds/FINDINGS.md) for the full manifest mapping each finding to its
beat, the tool that should detect it, and the expected alert rule ID.

> [!WARNING]
> This repository contains **intentionally vulnerable code and fake credentials**.
> It is a demonstration harness. Never deploy it to a production environment, never
> reuse its code, and never point it at real data.

## Getting started

Prerequisites: .NET 9 SDK, Node 20+, Python 3.11+, Azure CLI, Terraform, `gh`, Helm, kubectl.

```powershell
./scripts/verify-local.ps1     # build + test all three services locally
./scripts/bootstrap-t1.ps1     # provision Track 1 (GHEC + Azure), which seeds the plan too
```

The `gh` token needs the `project` scope for the board step, which `gh auth login` does not
request by default:

```powershell
gh auth refresh -s project,read:org
```

See [docs/SETUP.md](docs/SETUP.md) for the full provisioning order and
[docs/comparison-matrix.md](docs/comparison-matrix.md) for the scoring grid.

## Walkthroughs

Follow the [run-of-show index](docs/run-of-show/README.md) for preparation and evidence rules,
then select a guided case:

- [Track 1 - GitHub Enterprise Cloud + Copilot](docs/run-of-show/track-1.md)
- [Track 2 - GitHub Enterprise Server standalone](docs/run-of-show/track-2.md)
- [Track 3 - GHES + GHEC through GitHub Connect](docs/run-of-show/track-3.md)
- [Track 4 - GHEC + Azure DevOps Services](docs/run-of-show/track-4.md)
- [Track 5 - Azure DevOps Server standalone](docs/run-of-show/track-5.md)
- [Platform comparison lab - ADO and GitHub Enterprise](docs/run-of-show/platform-comparison.md)
