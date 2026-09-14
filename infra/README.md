# Infrastructure

## Decision: Terraform (resolves B1.0)

**Terraform, for all five tracks.**

Bicep describes the Azure resources perfectly well. It cannot reach the GitHub
organisation, repository rulesets, environments, or the Azure DevOps project — and those
are not incidental to this showcase, they *are* the showcase. Choosing Bicep would mean
roughly half of each track is configured by hand, which in turn means a track cannot be
destroyed and rebuilt reliably between customers. The demo's credibility rests on being
able to do exactly that.

`seeds/FINDINGS.md` already pins CF-IAC-040 and CF-IAC-041 to
`infra/terraform/00-shared/storage.tf` and `infra/terraform/10-aks/main.tf`, so the
collateral written before this decision assumed the same answer.

The counter-argument, stated fairly: if the customer is a Bicep shop, showing them
Terraform is a distraction. In that case the honest answer is Bicep for the Azure stacks
plus a separate Terraform stack for the platform providers — two languages, but still no
hand-configuration. Do not split it pre-emptively; only if asked.

## Layout

| Stack | Status | Provides |
| --- | --- | --- |
| `terraform/00-shared` | **built** | Resource group, Log Analytics, App Insights, ACR, storage. Plants CF-IAC-040. |
| `terraform/10-aks` | not started | AKS cluster and AcrPull role assignment. Plants CF-IAC-041. |
| `terraform/20-ghes` | not started | Track 2 GHES appliance. Blocked on the `.ghl` licence decision (B4.0). |
| `terraform/30-ado-server` | not started | Track 5 ADO Server. Blocked on the licence decision (B6.0). |
| `terraform/40-github` | **built** | Track 1 repository, ruleset, environments. |
| `terraform/50-ado` | not started | Track 4 Azure DevOps project. Blocked on the Track 4 shape decision (B3.0). |

Each stack is independent and holds its own local state. `00-shared` is applied first;
everything downstream consumes its outputs.

## Running a stack

```powershell
cd infra/terraform/00-shared
Copy-Item terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform plan
terraform apply
```

State is local on purpose. A remote backend needs a storage account that lives outside the
lifecycle everything else follows, and this environment is built to be thrown away. If more
than one person is driving the demo, add an `azurerm` backend block to `versions.tf` and
point it at a storage account you create by hand, once, outside these stacks.

## Two things that will bite you

**The custom secret-scanning pattern is deliberately not in Terraform.** The GitHub provider
has no resource for custom secret-scanning patterns, and even if it did the ordering is a
trap: the repository must be pushed *before* the `ctso_live_…` pattern exists, or push
protection rejects the seeding push and the repository can never be seeded at all. Create the
pattern by hand after seeding, per `seeds/secret-patterns.md`. Terraform's dependency graph
would not enforce that ordering on its own.

**`copilot_bypass_actor_id` defaults to null**, which creates the ruleset with no bypass
actors. The Copilot coding agent's push to its own branch is then rejected by the pull request
rule, and Beat 4 looks like the agent silently did nothing. This is the single most common
Track 1 failure. Get the ID with:

```bash
gh api "/orgs/<org>/installations" \
  --jq '.installations[] | select(.app_slug=="copilot-swe-agent") | .app_id'
```

The `copilot_bypass_configured` output exists so you can check this before presenting.

## Planted findings live here

`00-shared/storage.tf` contains CF-IAC-040, a storage account that permits anonymous blob
access, accepts cleartext HTTP, and sets a TLS 1.0 floor. It is a real, scannable
misconfiguration rather than a comment describing one, and it sits next to a correctly
configured account so that a scanner flagging one and not the other is visible. It is guarded
by `var.plant_iac_findings`. Do not "fix" it.
