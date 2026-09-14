# Track 4 - GitHub Enterprise Cloud plus Azure DevOps Services

**Duration:** 80 minutes demonstration or 4 hours hands-on  
**Positioning:** coexistence. GitHub owns code and engineering automation; Azure DevOps retains planning, artifacts, and test management.

## Feature checklist

- [ ] Azure Boards Epic, Feature, User Story, sprint, and capacity planning
- [ ] GitHub links on Azure Boards work items
- [ ] GitHub repository instructions and Copilot Spaces
- [ ] Copilot IDE assistance
- [ ] Copilot coding-agent delegation for the GHEC repository
- [ ] GHEC push protection and historical secret scanning
- [ ] CodeQL, Dependabot, dependency review, and Copilot review
- [ ] GitHub Actions CI and optional Azure Pipelines parity run
- [ ] Azure Artifacts feed demonstration
- [ ] SBOM and GitHub artifact attestations
- [ ] Azure DevOps environment approval and workload identity federation
- [ ] Application Insights and ADO deployment history
- [ ] ADO Test Analytics flaky-test detection
- [ ] Agent-assisted hotfix
- [ ] GitHub and ADO governance surfaces shown together

## Prerequisites

- A GHEC organization with Copilot and required security licences.
- An Azure DevOps Services organization and project.
- Azure CLI with the `azure-devops` extension or `AZURE_DEVOPS_EXT_PAT` configured.
- A GitHub service connection in Azure DevOps.
- An Azure Resource Manager service connection using workload identity federation.
- Shared ACR, AKS, Log Analytics, and Application Insights resources.

## Prepare the environment

1. Bootstrap the GHEC repository:

```powershell
./scripts/bootstrap-t1.ps1 -Organization <github-org>
```

2. Create the Azure DevOps project and connect it to the GitHub repository.
3. Seed Azure Boards from the same plan used by GitHub:

```powershell
./scripts/seed-ado-plan.ps1 `
  -Organization https://dev.azure.com/<ado-org> `
  -Project 'Contoso Fabric' `
  -Process Agile
```

4. Import [`../../pipelines/azure-pipelines-ci.yml`](../../pipelines/azure-pipelines-ci.yml).
5. Create the ADO production environment and attach approval checks.
6. Configure the workload-identity-federated Azure service connection.
7. Run:

```powershell
./scripts/verify-track.ps1 -Track T4 -Organization <github-org> -ResourceGroup <rg> -ClusterName <aks>
```

## Browser tabs

Open Azure Boards, Sprints, Pipelines, Test Plans/Test Analytics, Artifacts, the GHEC repository,
GitHub Actions, Security, Copilot agent PR, Azure Portal, and Application Insights.

## Walkthrough

### 0. Frame ownership

- [ ] State that GitHub owns repositories, PRs, security, and optionally CI.
- [ ] State that ADO owns planning, testing, artifacts, and optionally deployment.
- [ ] Show the same plan item in both systems and name the authoritative source.

### 1. Plan in Azure Boards

- [ ] Navigate Epic to Feature to User Story.
- [ ] Show story points, area path, iteration, capacity, and burndown.
- [ ] Open the linked GitHub commit or PR from the work item.
- [ ] Explain why Boards is retained instead of forcing a planning migration.

### 2. Spec and context in GitHub

- [ ] Open `AGENTS.md`, path-scoped instructions, and Copilot instructions.
- [ ] Show a Copilot Space if configured.
- [ ] Link the repository context back to the Azure Boards acceptance criteria.

### 3. Code

- [ ] Use Copilot Chat and agent mode in VS Code.
- [ ] Include the Azure Boards work-item reference in the branch or PR workflow.
- [ ] Run the focused local tests before pushing.

### 4. Delegate

- [ ] Assign the GitHub issue to the Copilot coding agent.
- [ ] Show its session log, tests, branch, and PR.
- [ ] Link the resulting PR to the Azure Boards work item.
- [ ] Demonstrate the direct-PR limitation from Boards; research and plan modes are not equivalent to Teams or Slack integrations.

### 5. Commit gate

- [ ] Inject the two fake secrets and push.
- [ ] Show GHEC rejecting the push.
- [ ] Show the custom-pattern backfill alert.
- [ ] Revert the injected files.

### 6. Review

- [ ] Show CodeQL's four code findings.
- [ ] Show Dependabot and dependency-review results.
- [ ] Show Copilot code-review comments and Autofix.
- [ ] Show the Azure Boards link without duplicating review state into ADO.

### 7. CI

- [ ] Run GitHub Actions CI for .NET, Node, and Python.
- [ ] Run the equivalent Azure Pipeline from the same commit.
- [ ] Compare queue time, logs, cache behavior, artifacts, matrix support, and approval integration.
- [ ] Publish or consume one package from Azure Artifacts if it is in scope.

### 8. Supply chain

- [ ] Generate the SBOM in GitHub Actions.
- [ ] Create and verify the GitHub build-provenance attestation.
- [ ] Show immutable action references and the two planted container findings.
- [ ] Explain that Azure Artifacts is a package feed, not an equivalent provenance system.

### 9. Deploy to AKS

- [ ] Start the ADO deployment stage.
- [ ] Pause at the production environment approval.
- [ ] Approve and authenticate to Azure with workload identity federation.
- [ ] Deploy the Helm chart to the T4 namespace.
- [ ] Show where ADO environment checks live and compare that location with GitHub Environments.

### 10. Observe

- [ ] Show Application Insights release annotation.
- [ ] Show Azure Monitor and Defender findings.
- [ ] Show ADO deployment history and the linked work item.
- [ ] Trace one deployment back to the GitHub commit.

### 11. Incident and hotfix

- [ ] Run the flaky test repeatedly in Azure Pipelines.
- [ ] Show Test Analytics identifying or reporting the flaky test.
- [ ] Create or link the incident work item.
- [ ] Delegate the GitHub issue to Copilot and merge the verified hotfix PR.

**Expected:** this track is strongest here because it combines ADO test analytics with the GHEC coding agent.

### 12. Govern

- [ ] Show GitHub rulesets, audit streaming, and Copilot usage metrics.
- [ ] Show ADO permissions, audit events, branch or environment policies, and service connections.
- [ ] Identify duplicated users, licences, groups, approvals, and audit exports.
- [ ] Assign an owner for reconciliation between the two systems.

## Close and reset

Use this track when Azure Boards or Test Plans are strategically retained while code moves to
GitHub. Run `./scripts/reset-demo.ps1 -Organization <github-org>`, rerun CodeQL, and reseed
Azure Boards from the canonical plan if work items were modified during the demonstration.
