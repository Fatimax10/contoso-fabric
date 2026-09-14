# Track 3 - GitHub Enterprise Server plus GitHub Enterprise Cloud

**Duration:** 75 minutes demonstration or 3.5 hours hands-on  
**Positioning:** regulated hybrid. Code stays on GHES while GitHub Connect adds selected cloud services.

## Feature checklist

- [ ] GHES Issues and Projects planning
- [ ] Repository instruction files on GHES
- [ ] Copilot IDE access through a linked GHEC identity
- [ ] Coding-agent repository-location boundary demonstrated
- [ ] GHES secret scanning and push protection
- [ ] CodeQL on customer-managed runners
- [ ] Dependabot advisory data supplied through GitHub Connect
- [ ] GitHub.com actions consumed from GHES workflows
- [ ] Actions external storage and self-hosted runners
- [ ] SBOM and constrained provenance verification
- [ ] AKS deployment from the controlled runner network
- [ ] Azure observability
- [ ] Human hotfix for GHES-hosted code
- [ ] Licence sync, unified contributions/search, and Server Statistics
- [ ] Data-boundary evidence showing that repositories and PRs remain on GHES

## Prerequisites

- Everything required by [Track 2](track-2.md).
- GHEC organization and compatible enterprise account.
- GitHub Connect enabled between GHES and GitHub.com over outbound HTTPS 443.
- Copilot licences assigned through GHEC.
- GHES version compatible with the Connect features being demonstrated.

## Prepare the environment

1. Complete Track 2 provisioning and verify the standalone baseline first.
2. In GHES Management Console, enable GitHub Connect and register the enterprise account.
3. Enable licence sync and confirm licensed users appear on GHES.
4. Enable Dependabot data and GitHub.com action access through Connect.
5. Enable unified contributions and search if included in the customer scope.
6. Confirm Server Statistics is available. It is not supported when connecting to GHE.com instead of GitHub.com.
7. Link the developer's GHEC identity and verify Copilot in VS Code.
8. Keep the demonstration repository on GHES; moving it to GHEC would change the case being tested.
9. Run:

```powershell
./scripts/verify-track.ps1 -Track T3 -Organization <ghec-org> -ResourceGroup <rg> -ClusterName <aks>
```

## Browser tabs

Open the GHES repository, GHES Actions and Security, GHES Management Console Connect settings,
GHEC enterprise licensing, VS Code, Azure Portal, and the deployed application.

## Walkthrough

### 0. Frame the boundary

- [ ] Show the GHES repository URL and current commit.
- [ ] Draw the outbound Connect path over HTTPS 443.
- [ ] State explicitly that repository contents, issues, and pull requests are not copied to GHEC.

### 1. Plan

- [ ] Open the same seeded GHES project and acceptance criteria used in T2.
- [ ] Confirm planning data remains on GHES.
- [ ] Record that Connect does not move project-management data to the cloud.

### 2. Spec and context

- [ ] Show `AGENTS.md` and repository Copilot instructions on GHES.
- [ ] Open any permitted cloud Copilot Space separately.
- [ ] Distinguish repository-resident instructions from cloud-curated Spaces.

### 3. Code in the IDE

- [ ] Sign in to Copilot with the linked GHEC identity.
- [ ] Ask about `PricingCalculator` and verify repository instructions influence the answer.
- [ ] Make a small multi-file edit and run focused tests.
- [ ] Show that the repository remote remains the GHES hostname.

### 4. Delegate

- [ ] Try to assign the GHES-hosted issue to the Copilot coding agent.
- [ ] Record that delegation is unavailable for this repository location.
- [ ] Optionally show a separate GHEC-hosted repository where delegation works, clearly labelling it as a location change.

**Expected:** partial. Cloud licensing does not make a GHES repository agent-compatible.

### 5. Commit gate

- [ ] Inject and push the planted secrets.
- [ ] Confirm GHES push protection blocks the push.
- [ ] Show the historical custom-pattern alert.
- [ ] Revert the injection.
- [ ] Explain that Connect does not relocate this scanning operation.

### 6. Review

- [ ] Run CodeQL on the self-hosted runner and show four code findings.
- [ ] Open Dependabot alerts populated through GitHub Connect.
- [ ] Demonstrate that advisory data arrives without repository content leaving GHES.
- [ ] Record Copilot code review as unavailable for the GHES-hosted PR unless current licensed product support proves otherwise.

### 7. CI

- [ ] Run the same reusable CI workflows on self-hosted or ARC runners.
- [ ] Reference an action from GitHub.com rather than a vendored copy.
- [ ] Show the outbound retrieval and local job execution separately.
- [ ] Confirm Actions artifacts use the configured external storage.

### 8. Supply chain

- [ ] Generate the SBOM locally.
- [ ] Show container findings `CF-SUP-030` and `CF-SUP-031`.
- [ ] Verify provenance where approved connectivity exists.
- [ ] Record any external transparency-log dependency.

### 9. Deploy to AKS

- [ ] Approve the GHES environment deployment.
- [ ] Deploy through the controlled self-hosted runner.
- [ ] Verify Helm release, pods, and application health in the T3 namespace.
- [ ] Show that Connect is not in the deployment credential path.

### 10. Observe

- [ ] Show the release annotation, Azure Monitor alert, and Defender recommendations.
- [ ] Trace the annotation back to the GHES commit and workflow run.
- [ ] Record required outbound Azure connectivity.

### 11. Incident and hotfix

- [ ] Run the five-repeat flaky-test job.
- [ ] Create the GHES incident issue.
- [ ] Complete a human-led hotfix PR because the source repository is on GHES.
- [ ] Contrast this with the GHEC-only coding-agent flow.

### 12. Govern

- [ ] Show GHES rulesets and local audit events.
- [ ] Show licence synchronization.
- [ ] Show unified contributions/search if enabled.
- [ ] Show Server Statistics and record version prerequisites.
- [ ] Present the data-flow evidence required by the security review.

## Close and reset

Use this track when code must stay on-premises but outbound access to selected GitHub cloud
services is acceptable. Reset the repository as in Track 2, then verify Connect, advisory-data
freshness, licence sync, and runner health before the next session.
