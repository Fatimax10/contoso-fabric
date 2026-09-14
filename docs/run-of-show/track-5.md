# Track 5 - Azure DevOps Server standalone

**Duration:** 75 minutes demonstration or 3.5 hours hands-on  
**Positioning:** the on-premises baseline. Strong planning and test management, with customer-owned infrastructure and reduced modern security and AI capabilities.

## Feature checklist

- [ ] Azure Boards hierarchy, sprint, capacity, and query reporting
- [ ] Repository-hosted guidance files shown as documentation only
- [ ] Optional workstation Copilot tested as an external, separately governed service
- [ ] Coding-agent unavailability demonstrated
- [ ] Branch policies and human review
- [ ] First-party secret push-protection gap documented
- [ ] First-party CodeQL and dependency-scanning gaps documented
- [ ] Azure Pipelines on a separate self-hosted agent VM
- [ ] Azure Artifacts feed
- [ ] SBOM generated through an added pipeline tool
- [ ] First-party provenance gap documented
- [ ] Environment approval and AKS deployment
- [ ] Azure Monitor and Application Insights
- [ ] ADO Test Analytics flaky-test evidence
- [ ] Human-led hotfix
- [ ] Server permissions and audit evidence

## Prerequisites

- Azure DevOps Server licence.
- Supported Windows Server and SQL Server versions.
- A separate build-agent VM; do not install build agents on the application tier.
- Network access from the agent to package feeds, ACR, AKS, and Azure telemetry as required.
- Shared ACR, AKS, Log Analytics, and Application Insights resources.
- Third-party security tools if the comparison includes equivalent SAST, SCA, or secret scanning.

Follow the exact platform and sizing constraints in [`../SETUP.md`](../SETUP.md). SQL Server on
Linux is unsupported, and a realistic CI demonstration requires at least the application tier
and a separate agent machine.

## Prepare the environment

1. Provision `30-ado-server` after the shared and AKS stacks.
2. Install and configure Azure DevOps Server and its SQL database.
3. Register a separate self-hosted build agent.
4. Create the `Contoso Fabric` project and Azure Repos repository.
5. Push the same source commit used by the GitHub tracks.
6. Seed the plan against the collection URL:

```powershell
./scripts/seed-ado-plan.ps1 `
  -Organization https://<ado-server>/DefaultCollection `
  -Project 'Contoso Fabric' `
  -Process Agile
```

7. Import [`../../pipelines/azure-pipelines-ci.yml`](../../pipelines/azure-pipelines-ci.yml).
8. Configure branch policies, the production environment, approval checks, and the Azure service connection.
9. Run:

```powershell
./scripts/verify-track.ps1 -Track T5 -ResourceGroup <rg> -ClusterName <aks>
```

## Browser tabs

Open Azure Boards, Repos, Pipelines, Test Plans/Test Analytics, Artifacts, Project Settings,
Azure Portal, Application Insights, and the deployed application.

## Walkthrough

### 0. Frame the baseline

- [ ] Show the server version, collection, project, and repository commit.
- [ ] State which infrastructure and licences the customer owns.
- [ ] Explain that this is a baseline for comparison, not an intentionally weakened setup.

### 1. Plan

- [ ] Navigate Epic to Feature to User Story to Task.
- [ ] Show sprint capacity, burndown, queries, and dashboards.
- [ ] Open the pricing-calculator test story and its acceptance criteria.

**Expected:** one of this track's strongest areas.

### 2. Spec and context

- [ ] Open `AGENTS.md` as repository documentation.
- [ ] Show that ADO Server has no native Copilot surface that consumes it.
- [ ] Record the team's alternative for reusable engineering guidance.

### 3. Code

- [ ] Make a small code change in VS Code.
- [ ] If Copilot is enabled on the workstation, show that its identity and governance are external to ADO Server.
- [ ] Run focused tests and associate the commit with the ADO work item.

### 4. Delegate

- [ ] Inspect work-item assignment and repository automation options.
- [ ] Confirm there is no Copilot coding-agent delegation for Azure Repos on ADO Server.
- [ ] Assign the story to a developer and create the branch manually.

### 5. Commit gate

- [ ] Show branch policies and required reviewers.
- [ ] Attempt the secret-injection scenario only in the isolated demo repository.
- [ ] Record that GitHub Advanced Security for Azure DevOps is an ADO Services feature, not an ADO Server feature.
- [ ] Demonstrate an approved third-party or pre-commit control if one is part of the target architecture.

### 6. Review

- [ ] Open a pull request and show branch-policy enforcement.
- [ ] Record the absence of first-party CodeQL, Dependabot, dependency review, and Copilot review.
- [ ] Run the selected third-party SAST/SCA tools if configured.
- [ ] Compare their findings with the canonical `CF-SEC-*` and `CF-DEP-*` list.

### 7. CI

- [ ] Run the Azure Pipeline for all three stacks.
- [ ] Show the separate agent VM and its pool.
- [ ] Publish test results and build artifacts.
- [ ] Show agent patching, capacity, and queue ownership.

### 8. Supply chain

- [ ] Generate an SBOM with an explicitly added pipeline tool.
- [ ] Publish a package to Azure Artifacts.
- [ ] Show the planted Dockerfile findings if container scanning is configured.
- [ ] Record the absence of a first-party artifact-attestation and transparency-log workflow.

### 9. Deploy to AKS

- [ ] Start the release or multi-stage pipeline.
- [ ] Pause for the production environment approval.
- [ ] Authenticate using the approved service connection available to the server network.
- [ ] Deploy the Helm chart and verify the T5 namespace.

### 10. Observe

- [ ] Show Application Insights and Azure Monitor telemetry.
- [ ] Show the pipeline deployment record.
- [ ] Correlate the deployment manually to the work item and commit.
- [ ] Record any outbound network dependency.

### 11. Incident and hotfix

- [ ] Run the planted flaky test repeatedly.
- [ ] Show ADO Test Analytics identifying the unstable test.
- [ ] Create a bug work item and link the failed build.
- [ ] Complete a human-led hotfix branch, PR, and deployment.

### 12. Govern

- [ ] Show collection, project, repository, and branch permissions.
- [ ] Show audit events and retention settings available in the installed version.
- [ ] Show agent-pool and service-connection permissions.
- [ ] Record missing enterprise policy-as-code, streaming, and Copilot metrics capabilities.
- [ ] Include Windows, SQL, backup, upgrade, and disaster-recovery ownership in the final cost.

## Close and reset

Use this track for an existing disconnected ADO Server estate or as the modernization baseline.
Reset the repository branch, work-item states, pipeline artifacts, and test results according to
your server snapshot strategy. Restart deallocated VMs well before the next demonstration.
