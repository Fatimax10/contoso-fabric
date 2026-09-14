# Platform comparison lab - Azure DevOps and GitHub Enterprise

**Duration:** 90 minutes demonstration or 4 hours hands-on  
**Goal:** compare similar capabilities using identical inputs and observable evidence, rather
than comparing product names or marketing checklists.

This is a sixth case, not a deployment architecture. Run it after the individual tracks to
compare **GHEC**, **GHES**, **Azure DevOps Services**, and **Azure DevOps Server** side by side.

## Platforms under test

| Short name | Platform |
| --- | --- |
| GHEC | GitHub Enterprise Cloud |
| GHES | GitHub Enterprise Server |
| ADO Services | Azure DevOps Services |
| ADO Server | Azure DevOps Server |

## Fair-comparison rules

- [ ] Use the same source commit SHA on all repository platforms.
- [ ] Generate both backlogs from [`../../seeds/plan/plan.json`](../../seeds/plan/plan.json).
- [ ] Use the same acceptance criteria and work-item estimate.
- [ ] Run the same .NET, Node, and Python build/test commands.
- [ ] Use equivalent runner/agent sizes when measuring duration.
- [ ] Deploy the same image digests and Helm chart to separate namespaces on one AKS cluster.
- [ ] Use the same planted findings from [`../../seeds/FINDINGS.md`](../../seeds/FINDINGS.md).
- [ ] Separate licence capability from infrastructure capability.
- [ ] Record unavailable features as unavailable; do not silently substitute a third-party tool.
- [ ] Record every third-party or custom substitute and its operational owner.

## Similar-feature map

| Capability | GHEC | GHES | ADO Services | ADO Server |
| --- | --- | --- | --- | --- |
| Planning | Issues + Projects | Issues + Projects | Azure Boards | Azure Boards |
| Source control | GitHub repositories | GitHub repositories | Azure Repos or linked GitHub | Azure Repos |
| PR policy | Rulesets and branch protection | Rulesets and branch protection | Branch policies | Branch policies |
| IDE AI | Copilot, cloud identity | Conditional cloud-connected Copilot | Copilot via GitHub identity | External to server governance |
| Autonomous coding agent | GHEC repositories | Unavailable | Available only when repo is on GHEC | Unavailable |
| Secret push protection | GitHub Secret Protection | Licensed/configured | GHAzDO for Azure Repos | No first-party equivalent |
| SAST | CodeQL | CodeQL, self-hosted | GHAzDO CodeQL for Azure Repos | No first-party equivalent |
| Dependency alerts | Dependabot | Connect required for advisory data | GHAzDO dependency scanning | No first-party equivalent |
| CI | GitHub Actions hosted/self-hosted | Actions self-hosted only | Azure Pipelines hosted/self-hosted | Pipelines self-hosted only |
| Packages | GitHub Packages | GitHub Packages | Azure Artifacts | Azure Artifacts |
| Deployment approvals | GitHub Environments | GitHub Environments | ADO Environments/checks | ADO Environments/checks |
| Secretless Azure auth | OIDC | Connectivity-dependent | Workload identity federation | Connectivity/version-dependent |
| Test analytics | Workflow/test-report integrations | Workflow/test-report integrations | Native Test Analytics | Native Test Analytics |
| Provenance | GitHub artifact attestations | Partial/offline constraints | Custom pipeline tooling | Custom pipeline tooling |
| Audit/governance | Cloud audit streaming and metrics | Local audit; Connect adds statistics | ADO audit and policies | Server/version-dependent audit |

## Prepare the comparison

1. Complete the applicable individual track setup guides.
2. Record the source SHA:

```powershell
git rev-parse HEAD
```

3. Seed GitHub planning:

```powershell
./scripts/seed-github-plan.ps1 -Organization <github-org> -Stream product
```

4. Seed each ADO project from the same plan:

```powershell
./scripts/seed-ado-plan.ps1 -Organization https://dev.azure.com/<ado-org> -Project 'Contoso Fabric' -Stream product
./scripts/seed-ado-plan.ps1 -Organization https://<ado-server>/DefaultCollection -Project 'Contoso Fabric' -Stream product
```

5. Run `./scripts/verify-local.ps1` once to establish a platform-independent baseline.
6. Create namespaces `t1-ghec`, `t2-ghes`, `t4-ado-services`, and `t5-ado-server`.
7. Prepare a results sheet using the template at the end of this guide.

## Comparison walkthrough

### 1. Planning: Projects versus Boards

- [ ] Open the same product item in GitHub Projects and Azure Boards.
- [ ] Compare hierarchy, custom fields, iterations, roadmaps, capacity, queries, and burndown.
- [ ] Time creation of one child task and movement into the current sprint.
- [ ] Record traceability from item to commit and PR.

**Decision signal:** Azure Boards normally wins complex hierarchy and capacity planning;
GitHub Projects reduces context switching when engineering work already lives in GitHub.

### 2. Repository governance: rulesets versus branch policies

- [ ] Require a PR, two reviewers, passing CI, and no direct push on each platform.
- [ ] Attempt the same direct push.
- [ ] Compare policy inheritance, bypass actors, status-check naming, and audit evidence.
- [ ] Record whether policy configuration is API/IaC manageable.

### 3. Developer AI and delegation

- [ ] Run the same Copilot prompt against `PricingCalculator` from each repository context.
- [ ] Record identity, network, and policy dependencies.
- [ ] Attempt to delegate the same test-writing issue.
- [ ] Show that delegation follows repository location: GHEC works; GHES and Azure Repos do not.

### 4. Secret protection

- [ ] Inject the same fake SQL and storage secrets.
- [ ] Attempt a push to each isolated demo repository.
- [ ] Record block time, message quality, bypass workflow, alert ownership, and historical scanning.
- [ ] Label third-party controls separately from first-party controls.

### 5. Code and dependency security

- [ ] Run the native/configured scanner against all four code findings.
- [ ] Compare inline PR annotations, Autofix, suppression workflow, advisory freshness, and dashboards.
- [ ] Confirm detection against the canonical finding IDs rather than raw alert counts.
- [ ] Record bundle/feed maintenance required on server products.

### 6. CI execution

- [ ] Trigger GitHub Actions and Azure Pipelines from the same commit.
- [ ] Run .NET tests, Python tests and Ruff, then Next.js typecheck/build.
- [ ] Capture queue time, execution time, cache hit, artifact size, logs, retries, and runner owner.
- [ ] Distinguish hosted compute from customer-operated compute.

### 7. Packages and supply chain

- [ ] Publish one versioned package to GitHub Packages and Azure Artifacts.
- [ ] Generate the same SBOM in both pipelines.
- [ ] Produce and verify provenance where supported.
- [ ] Compare retention, immutability, upstream feeds, attestations, and offline verification.

### 8. Deployment controls

- [ ] Deploy the same image digest to each platform's AKS namespace.
- [ ] Require one approval and use secretless Azure authentication where supported.
- [ ] Compare where approvals are defined, who can weaken them, and how changes are audited.
- [ ] Verify rollout, health, rollback, and deployment history.

### 9. Test management and incidents

- [ ] Run the same flaky test five times in each pipeline.
- [ ] Compare native flake detection, trend views, failure-to-work-item automation, and reruns.
- [ ] Create the same incident and complete a hotfix.
- [ ] Record whether the fix can be delegated or must be human-authored.

### 10. Observability and traceability

- [ ] Send the same release annotation to Application Insights.
- [ ] Trace alert to deployment, pipeline run, commit, PR, and work item.
- [ ] Count manual joins and platform switches.
- [ ] Record which system remains authoritative for deployment history.

### 11. Governance and operations

- [ ] Compare audit export, retention, identity lifecycle, enterprise policy, and usage metrics.
- [ ] List servers, databases, storage, runners, backups, upgrades, and disaster recovery owned by the customer.
- [ ] Add cloud licences, duplicate licences, compute, storage, and operator time to the cost model.
- [ ] Review [`../cost-model.md`](../cost-model.md) using the customer's negotiated licence inputs.

## Results template

Use one row per capability and retain links to the evidence.

| Capability | Platform | Result | Setup effort | Run time | Customer-operated components | Evidence | Notes |
| --- | --- | --- | ---: | ---: | --- | --- | --- |
| Planning hierarchy | GHEC | Native/Configured/Partial/Unavailable | | | | | |
| Planning hierarchy | ADO Services | Native/Configured/Partial/Unavailable | | | | | |
| Secret push protection | GHES | Native/Configured/Partial/Unavailable | | | | | |
| Secret push protection | ADO Server | Native/Configured/Partial/Unavailable | | | | | |

## Decision summary

- Choose **GHEC** when cloud hosting is allowed and integrated AI, security, and supply-chain controls are priorities.
- Choose **GHES** when repository sovereignty outweighs hosted compute and coding-agent capability.
- Add **GitHub Connect** when GHES must remain authoritative but cloud licensing, advisories, and action access are acceptable.
- Choose **ADO Services with GHEC** when Azure Boards/Test Plans must remain while engineering moves to GitHub.
- Retain **ADO Server** where disconnection or existing investment requires it, with explicit third-party security and operational-cost plans.

Do not collapse the outcome into one universal score. Weight planning, sovereignty, AI,
security, operations, and cost according to the organization's actual constraints.
