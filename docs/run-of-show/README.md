# Run-of-show guides

These guides replay one Contoso Fabric delivery story against the same 12 feature beats.
Use the same commit, backlog from [`seeds/plan/plan.json`](../../seeds/plan/plan.json), planted
findings from [`seeds/FINDINGS.md`](../../seeds/FINDINGS.md), and AKS target in every track.
That control is what makes the comparison meaningful.

> [!WARNING]
> The application contains deliberate vulnerabilities and fake credentials. Use an isolated
> demonstration environment only. Never connect it to production data.

## Choose a walkthrough

| Guide | Configuration | Primary question |
| --- | --- | --- |
| [Track 1](track-1.md) | GitHub Enterprise Cloud + Copilot | What is the complete cloud-native experience? |
| [Track 2](track-2.md) | GitHub Enterprise Server, standalone | What remains when code and automation must stay on-premises? |
| [Track 3](track-3.md) | GHES + GHEC through GitHub Connect | Can code stay on-premises while selected cloud capabilities are added? |
| [Track 4](track-4.md) | GHEC + Azure DevOps Services | Can engineering move to GitHub while planning and testing stay in ADO? |
| [Track 5](track-5.md) | Azure DevOps Server, standalone | What does the traditional on-premises baseline provide? |
| [Comparison lab](platform-comparison.md) | GHEC, GHES, ADO Services, ADO Server | How do equivalent features compare under one controlled scenario? |

## Shared preparation

1. Read [`../SETUP.md`](../SETUP.md) and confirm the required licences before provisioning.
2. Run `./scripts/verify-local.ps1` from the repository root.
3. Provision shared Azure resources once: ACR, AKS, Log Analytics, Application Insights, and storage.
4. Use one AKS namespace per track rather than one cluster per track.
5. Seed both planning platforms from the same JSON plan; do not maintain separate demo backlogs.
6. Run `./scripts/verify-track.ps1` on the morning of the demonstration.
7. Keep a clean browser profile for each identity and pre-open the tabs named by the selected guide.
8. Capture the same evidence for every beat: screenshot or URL, elapsed time, manual steps, failure, and workaround.

## Evidence result labels

- **Native:** first-party and available without extra infrastructure.
- **Configured:** first-party, but requires infrastructure or deliberate setup.
- **Partial:** a reduced workflow or only available for some repository locations.
- **Unavailable:** no first-party implementation in that configuration.
