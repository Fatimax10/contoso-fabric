# Track 2 - GitHub Enterprise Server standalone

**Duration:** 75 minutes demonstration or 3.5 hours hands-on  
**Positioning:** sovereignty first. Code, metadata, CI, and audit records remain under customer control.

## Feature checklist

- [ ] GHES Issues and Projects planning
- [ ] Repository-level `AGENTS.md` and custom instruction files
- [ ] IDE assistance tested with and without outbound GitHub.com access
- [ ] Coding-agent unavailability demonstrated and documented
- [ ] Secret scanning, custom patterns, backfill scan, and push protection
- [ ] CodeQL on self-hosted runners with a locally maintained bundle
- [ ] Dependabot limitation without GitHub Connect demonstrated
- [ ] GitHub Actions backed by external blob storage
- [ ] Self-hosted or ARC runner execution
- [ ] Locally generated SBOM and offline provenance limitation
- [ ] AKS deployment using a self-hosted runner and approved identity
- [ ] Application Insights and Azure Monitor evidence
- [ ] Human-led incident hotfix
- [ ] GHES rulesets and local audit log
- [ ] Server Statistics limitation without GitHub Connect documented

## Prerequisites

- A valid GHES licence file and a supported GHES appliance.
- At least 8 vCPU, 64 GB RAM, premium root disk, and a separate persistent data disk for this feature set.
- External Azure Blob storage configured before enabling Actions.
- Self-hosted runners or Actions Runner Controller on AKS.
- GitHub Code Security and Secret Protection licences for Beats 5 and 6.
- A workstation path to GitHub.com only if IDE Copilot is intentionally part of the test.
- Shared ACR, AKS, Log Analytics, and Application Insights resources.

Follow the GHES sizing, unsupported VM-extension constraints, ports, and storage requirements in
[`../SETUP.md`](../SETUP.md). A genuinely air-gapped lab needs an approved process for importing
actions, CodeQL bundles, advisory data, container bases, and package dependencies.

## Prepare the environment

1. Provision the `20-ghes` Terraform stack after `00-shared` and `10-aks`.
2. Complete the GHES management-console setup and attach the required data disk.
3. Configure Actions external blob storage.
4. Create the `contoso-fabric` repository on GHES and push this repository to its hostname.
5. Seed the GitHub plan. If the script cannot target your GHES hostname, create the board from
   [`../../seeds/plan/plan.json`](../../seeds/plan/plan.json) and record that manual gap.
6. Install self-hosted runners or ARC and make the workflow `runs-on` value match the runner label.
7. Enable Secret Protection and Code Security, then upload or update the CodeQL bundle.
8. Configure the custom `ctso_(live|test)[_][A-Za-z0-9]{32}` secret pattern after the first push.
9. Configure the AKS deployment identity available to the runner. Do not store a cloud secret in source.
10. Run the readiness check:

```powershell
./scripts/verify-track.ps1 -Track T2 -ResourceGroup <rg> -ClusterName <aks>
```

## Browser tabs

Open GHES repository, Issues, Project, Actions, Security, Audit log, Azure Portal AKS,
Application Insights, and the deployed application.

## Walkthrough

### 0. Frame the constraint

- [ ] State that data residency is the primary requirement, not feature parity.
- [ ] Show the same commit and 12-beat scorecard used by the other tracks.
- [ ] Explain that runners, storage, upgrades, backups, and availability are customer-operated.

**Evidence:** GHES hostname, appliance version, repository commit SHA, and AKS namespace.

### 1. Plan

- [ ] Open the seeded Epic, Feature, and issue hierarchy in GHES Projects.
- [ ] Show iteration, status, estimate, track, and beat fields.
- [ ] Open the pricing-calculator test issue and review its acceptance criteria.

**Expected:** planning works locally. Compare its capacity planning later with Azure Boards.

### 2. Spec and context

- [ ] Open [`../../AGENTS.md`](../../AGENTS.md).
- [ ] Open [`../../.github/copilot-instructions.md`](../../.github/copilot-instructions.md).
- [ ] Explain that the files are portable, versioned context.
- [ ] Mark Copilot Spaces unavailable because it is a GitHub.com surface.

### 3. Code in the IDE

- [ ] On an internet-connected workstation, test Copilot using the linked cloud identity.
- [ ] Disconnect or use an isolated workstation and show that GHES alone does not provide Copilot.
- [ ] Record whether code-content egress is acceptable under the organization's policy.

**Expected:** IDE assistance is conditional on workstation connectivity and a cloud licence.

### 4. Delegate

- [ ] Open the GHES issue assignment controls.
- [ ] Confirm that the Copilot coding agent is not an available assignee.
- [ ] Assign the task to a human and create a branch manually.

**Expected:** unavailable. There is no coding-agent workaround for a GHES-hosted repository.

### 5. Commit gate

- [ ] Run `./scripts/inject-planted-secret.ps1`.
- [ ] Commit and push to GHES.
- [ ] Confirm push protection blocks `CF-SEC-001` and `CF-SEC-002`.
- [ ] Open the historical custom-pattern alert for `CF-SEC-003`.
- [ ] Run `./scripts/inject-planted-secret.ps1 -Revert` before continuing.

**Expected:** native with Secret Protection. Provider validity checks need outbound connectivity.

### 6. Review

- [ ] Run CodeQL on a self-hosted runner.
- [ ] Show SQL injection, XSS, path traversal, and SSRF alerts from
  [`../../seeds/FINDINGS.md`](../../seeds/FINDINGS.md).
- [ ] Show the installed CodeQL bundle version and update procedure.
- [ ] Demonstrate that Dependabot advisory data is absent or stale without GitHub Connect.
- [ ] Record Copilot code review as unavailable.

### 7. CI

- [ ] Run [the CI caller](../../.github/workflows/ci.yml).
- [ ] Show .NET, Node, and Python reusable workflows.
- [ ] Identify the self-hosted runner or ARC pod that executed each job.
- [ ] Show Actions blob storage and explain that GHES has no hosted-runner pool.

### 8. Supply chain

- [ ] Export an SBOM as a workflow artifact.
- [ ] Show `CF-SUP-030` and `CF-SUP-031` in the Dockerfiles.
- [ ] Attempt the selected provenance verification flow.
- [ ] Record any transparency-log or internet dependency that prevents offline verification.

### 9. Deploy to AKS

- [ ] Require an environment approval.
- [ ] Deploy the Helm chart from the self-hosted runner to the T2 namespace.
- [ ] Show the runner identity and explain whether it uses local workload identity or another approved mechanism.
- [ ] Verify deployment and application health.

### 10. Observe

- [ ] Show the Application Insights release annotation.
- [ ] Trigger or inspect the Azure Monitor alert.
- [ ] Show Defender findings for `CF-IAC-040` and `CF-IAC-041`.
- [ ] Identify the outbound path required for the GHES runner to publish telemetry.

### 11. Incident and hotfix

- [ ] Run the planted flaky test in CI with five repeats.
- [ ] Create an incident issue from the failure.
- [ ] Have a developer diagnose, patch, test, and open the hotfix PR.
- [ ] Record that no autonomous coding-agent handoff is available.

### 12. Govern

- [ ] Show repository or organization rulesets.
- [ ] Show the local GHES audit log and export destination.
- [ ] Record Server Statistics as unavailable without GitHub Connect.
- [ ] Record Copilot usage metrics as unavailable from standalone GHES.
- [ ] Discuss appliance patching, backup, disaster recovery, runner operations, and storage ownership.

## Close and reset

Use this track when source code cannot leave the controlled network and the organization accepts
the operational cost. Reset injected secrets locally, restore the seed branch, rerun CodeQL, and
confirm all four code-scanning findings are open before the next session.
