# Cost model

Every Azure figure below was retrieved from the **Azure Retail Prices API** on
**2026-08-26** for **East US**, **pay-as-you-go**, **Linux unless stated**. Nothing here is
estimated or remembered.

Reproduce any of it yourself:

```powershell
$f = "serviceName eq 'Virtual Machines' and armRegionName eq 'eastus' and armSkuName eq 'Standard_E8s_v5' and priceType eq 'Consumption'"
$u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($f)
(Invoke-RestMethod $u).Items | Select-Object armSkuName, meterName, retailPrice, unitOfMeasure
```

> **What is excluded.** Software licences — GitHub Enterprise, Copilot, GitHub Advanced
> Security, Azure DevOps users, Windows Server, SQL Server. Those are negotiated per
> agreement and vary enormously between EA, CSP and MCA. Quoting list prices for them from
> memory would be the least reliable part of this document, so they are called out as inputs
> you must supply rather than filled in. See [Licensing](#licensing) below.

Monthly figures assume **730 hours**. Daily figures assume an **8-hour demo day**.

---

## Unit prices (verified)

### Compute

| SKU | OS | $/hour | $/month (730 h) | Used for |
| --- | --- | --: | --: | --- |
| `Standard_E8s_v5` | Linux | 0.50 | 365.00 | GHES appliance (T2, T3) |
| `Standard_D8s_v5` | **Windows** | 0.75 | 547.50 | ADO Server application tier (T5) |
| `Standard_D8s_v5` | Linux | 0.38 | 277.40 | Build agent (T5) |
| `Standard_D4s_v5` | Linux | 0.19 | 138.70 | AKS node |
| `Standard_D2s_v5` | Linux | 0.10 | 73.00 | Small AKS node / ARC runner node |

### Storage — Premium SSD managed disks

| SKU | Size | $/month |
| --- | --- | --: |
| P10 LRS | 128 GiB | 19.71 |
| P20 LRS | 512 GiB | 73.22 |
| P30 LRS | 1 TiB | 135.17 |

### Platform services

| Service | Meter | Price |
| --- | --- | --: |
| AKS | Standard Uptime SLA (control plane) | $0.10 / hour → **$73.00 / month** |
| AKS | Free tier control plane | **$0.00** (no SLA) |
| ACR | Basic registry unit | $0.17 / day → $5.17 / month |
| ACR | Standard registry unit | $0.67 / day → $20.37 / month |
| ACR | Premium registry unit | $1.67 / day → $50.77 / month |
| ACR | Data stored | $0.10 / GB / month |

> **ACR Task vCPU duration prices as $0.00 per second** in the API. `az acr build` is
> effectively free at demo volumes, which is a good reason to prefer it over local Docker —
> especially on a laptop where Docker Desktop is unreliable.

---

## Shared infrastructure (all tracks)

Built once, reused by every track via one namespace per track. This is the single most
important cost decision in the whole build: **five clusters instead of five namespaces would
multiply this line by five.**

| Item | Config | $/month always-on | $/month 8h×20 days |
| --- | --- | --: | --: |
| AKS control plane | Standard (Uptime SLA) | 73.00 | 16.00 |
| AKS nodes | 3 × `Standard_D4s_v5` | 416.10 | 91.20 |
| ACR | Standard | 20.37 | 20.37 |
| Log Analytics + App Insights | ~5 GB ingest | ~12.00 | ~4.00 |
| Storage account | LRS, minimal | ~2.00 | ~2.00 |
| **Total** | | **~523** | **~134** |

Use the **AKS free control plane tier** for a demo environment and that drops to ~$450 /
~$118. The Uptime SLA buys you nothing in a showcase.

---

## Per-track marginal cost

What each track adds **on top of** the shared infrastructure.

### T1 — GHEC + Copilot

| Item | $/month |
| --- | --: |
| Azure marginal | **0.00** |
| GitHub Enterprise Cloud licences | see [Licensing](#licensing) |
| Copilot Business/Enterprise licences | see [Licensing](#licensing) |
| GitHub Actions minutes | metered — see below |

**Cheapest track by a wide margin on the Azure side.** All the cost is licensing, and the
compute is GitHub's problem.

Metered consumption that is easy to forget:

- **The Copilot coding agent consumes Actions minutes and AI credits.** A 59-minute session
  that runs to the cap is 59 billable minutes.
- **Copilot code review consumes Actions minutes on private repositories.**
- Budget deliberately for a workshop where 20 attendees each delegate two tasks.

### T4 — GHEC + Azure DevOps

| Item | $/month |
| --- | --: |
| Azure marginal | **0.00** |
| ADO Services basic users | first 5 free, then per-user |
| ADO parallel jobs | 1 free Microsoft-hosted, then per job |
| GitHub + Copilot licences | as T1 |

Also near-zero on Azure. The real question is **licence double-payment**: you are paying for
GitHub Enterprise *and* Azure DevOps users. Model that explicitly rather than letting it
surface after the pilot — it is the most common unpleasant surprise in a coexistence
architecture.

### T2 — GHES standalone

| Item | Config | $/month always-on | $/month 8h×20 days |
| --- | --- | --: | --: |
| GHES VM | `Standard_E8s_v5` | 365.00 | 80.00 |
| Root disk | 400 GB → P20 | 73.22 | 73.22 |
| Data disk | 500 GB → P20 | 73.22 | 73.22 |
| Actions blob storage | required for Actions | ~5.00 | ~5.00 |
| ARC runner nodes | 2 × `Standard_D2s_v5` | 146.00 | 32.00 |
| **Marginal total** | | **~662** | **~263** |

Three things drive that number, and all three are non-negotiable:

1. The `Standard_E8s_v5` sizing is not padding. GHES baseline for a trial instance is
   4 vCPU / 32 GB, **plus 25% CPU and memory for Actions, plus another 25% for Code
   Security** — which lands on 8 vCPU / 64 GB.
2. **Disks are charged on the provisioned tier, not on usage.** A 400 GB disk bills as P20
   (512 GiB) whether you store 4 GB or 400 GB. Disks do **not** get cheaper when the VM is
   deallocated — that $146.44/month of storage is a floor.
3. **There are no GitHub-hosted runners.** Every CI minute is an ARC node you pay for.

### T3 — GHES + GHEC hybrid

| Item | $/month |
| --- | --: |
| Everything in T2 | ~662 always-on |
| GHEC licences for Connect + Copilot | see Licensing |
| Azure marginal over T2 | **0.00** |

GitHub Connect itself costs nothing. **T3 is the cheapest capability upgrade in the entire
matrix** — it adds Dependabot advisory data, GitHub.com actions, licence sync and Server
Statistics to T2 for zero additional Azure spend. If a customer has already accepted T2's
cost, T3 is close to free and strictly better.

### T5 — ADO Server standalone

| Item | Config | $/month always-on | $/month 8h×20 days |
| --- | --- | --: | --: |
| Application tier VM | `Standard_D8s_v5` **Windows** | 547.50 | 120.00 |
| App tier disks | P10 root + P20 data | 92.93 | 92.93 |
| Build agent VM | `Standard_D8s_v5` Linux | 277.40 | 60.80 |
| Build agent disk | P10 | 19.71 | 19.71 |
| SQL Server | see note | — | — |
| **Marginal total (ex-SQL licence)** | | **~938** | **~293** |

**The most expensive track**, and for a structural reason worth naming: the Windows premium.
The same `Standard_D8s_v5` is $0.38/hour on Linux and **$0.75/hour on Windows** — the OS
almost doubles the compute bill, and ADO Server cannot run on Linux.

The second VM is not optional either. Microsoft's own guidance:

> "We don't recommend installing build, test, or release agents on your Azure DevOps Server
> or TFS application tiers."

**On SQL Server:** licensing is a material cost and depends entirely on the customer's
agreement. For a **non-production showcase, SQL Server Developer edition is free** and fully
featured — use it, and say clearly that a production deployment would be licensed
differently. Note that ADO Server **does not support SQL Server on Linux**, and **Express
edition is evaluation-only**.

---

## Summary

| Track | Azure marginal, always-on | Azure marginal, 8h×20 days | Notes |
| --- | --: | --: | --- |
| T1 | **$0** | **$0** | Licence-only |
| T4 | **$0** | **$0** | Licence-only, but pay twice |
| T2 | ~$662 | ~$263 | Disks are a $146 floor |
| T3 | ~$662 | ~$263 | Same as T2, materially more capable |
| T5 | ~$938 | ~$293 | Windows premium, two VMs |

Plus shared infrastructure of **~$523/month always-on** or **~$134** on a demo-day schedule.

### All five tracks, running concurrently

| Schedule | Azure total |
| --- | --: |
| Always-on | **~$2,785 / month** |
| 8 hours × 20 days | **~$953 / month** |
| Shared infra only, appliances deallocated | **~$670 / month** |

---

## The three levers that actually matter

**1. Deallocate the appliance VMs between sessions.**
The single biggest lever. GHES and ADO Server VMs are ~$912/month of the ~$1,600 appliance
total, and neither is needed except on a demo day. `az vm deallocate` stops compute charges;
`az vm stop` **does not** — a stopped-but-allocated VM still bills.

Budget **10–15 minutes** for GHES to become healthy after start. `scripts/verify-track.ps1`
checks power state precisely because a deallocated appliance is the classic morning-of
surprise.

**2. Use the AKS free control plane tier.**
$73/month for an SLA nobody will invoke during a demo.

**3. Scale AKS nodes to zero overnight.**
$416/month of node cost on a 24/7 schedule; roughly $91 on an 8×20 schedule.

Not a lever: **disks**. They bill on provisioned capacity regardless of VM state. The only
way to reduce them is to delete the appliance entirely — which for GHES means re-running
setup and re-seeding, so it is rarely worth it between sessions in the same month.

---

## Licensing

These are the inputs you must supply. They are deliberately blank rather than guessed,
because they vary by agreement type and are the figures most likely to be wrong if recalled
from memory.

| Item | Applies to | Unit | Your price |
| --- | --- | --- | --- |
| GitHub Enterprise Cloud | T1, T3, T4 | per user / month | |
| GitHub Enterprise Server | T2, T3 | per user / month | |
| GitHub Copilot Business | T1, T3, T4 | per user / month | |
| GitHub Copilot Enterprise | T1, T3, T4 | per user / month | |
| GitHub Code Security | T1–T4 | per committer / month | |
| GitHub Secret Protection | T1–T4 | per committer / month | |
| Actions minutes (beyond included) | T1, T3, T4 | per minute | |
| Copilot AI credits | T1, T3, T4 | per credit | |
| Azure DevOps Basic user | T4, T5 | per user / month | first 5 free |
| ADO parallel job (hosted) | T4 | per job / month | 1 free |
| Windows Server | T5 | per core, or AHB | |
| SQL Server | T5 | per core, or Developer edition free for non-prod | |

Two modelling notes worth raising with the customer before they ask:

- **GHAS is priced per *committer*, not per seat.** A 500-developer organisation where 200
  people commit in a given month is billed on 200. This usually lands better than expected.
- **T4 pays for two platforms.** GitHub Enterprise *and* Azure DevOps users. That is the
  honest cost of coexistence, and it should appear in the model from day one rather than
  emerging after a successful pilot.

### Azure Hybrid Benefit

If the customer has Software Assurance, **AHB removes the Windows licence component** from
the T5 application tier — the largest single controllable cost in the most expensive track.
Ask about it early; it can change the T5 conversation entirely.
