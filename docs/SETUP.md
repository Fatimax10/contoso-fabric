# Setup

Provisioning order, prerequisites, and the decisions you must make before anything is
deployed. Read this before running `scripts/bootstrap-t1.ps1`.

---

## 1. Prerequisites

### Tooling

| Tool | Minimum | Install | Needed for |
| --- | --- | --- | --- |
| .NET SDK | 9.0 | `winget install Microsoft.DotNet.SDK.9` | API, shared library |
| Node.js | 20 LTS | `winget install OpenJS.NodeJS.LTS` | Storefront |
| Python | 3.12 | `winget install Python.Python.3.12` | Worker |
| Git | any recent | `winget install Git.Git` | Everything |
| Azure CLI | 2.60+ | `winget install Microsoft.AzureCLI` | All Azure provisioning |
| Terraform | 1.9+ | `winget install Hashicorp.Terraform` | All infrastructure |
| GitHub CLI | 2.50+ | `winget install GitHub.cli` | Tracks 1, 3, 4 |
| Helm | 3.14+ | `winget install Helm.Helm` | AKS deployment |
| kubectl | 1.29+ | ships with Docker Desktop, or `az aks install-cli` | AKS deployment |

Verify with:

```powershell
./scripts/verify-local.ps1
```

That builds and tests all three services. It must be green before you provision anything —
debugging an application failure through a CI pipeline you have just stood up is the slowest
possible way to find it.

### Corporate proxy note

If `npm install` fails with `ERESOLVE ... Found: react@undefined`, that is **not** a
dependency problem. It means a package metadata fetch failed and npm filled the gap with
`undefined`. Retry. Do not "fix" it with `--legacy-peer-deps` or by changing versions.

### Accounts and licences

| Track | What you must already hold |
| --- | --- |
| T1 | GHEC organisation, Copilot Business or Enterprise licences, Azure subscription |
| T2 | **GHES licence file (`.ghl`)**, Azure subscription |
| T3 | Both of the above, plus GitHub Connect enabled |
| T4 | GHEC organisation, Azure DevOps Services organisation, Azure subscription |
| T5 | **Azure DevOps Server licence**, Windows Server + SQL Server licences, Azure subscription |

> The two licence files gate Tracks 2, 3 and 5 completely. There is no trial path that can be
> scripted around. Confirm you hold them **before** planning a workshop that includes those
> tracks.

---

## 2. Build order

Tracks are built in this order deliberately — maximum reuse first, hardest and least
reusable last.

```
T1  →  T4  →  T2  →  T3  →  T5
```

| Order | Track | Why here |
| --- | --- | --- |
| 1 | T1 (GHEC) | Everything else reuses its app, workflows, Helm chart and AKS cluster |
| 2 | T4 (GHEC + ADO) | Reuses T1's repositories wholesale; only adds an ADO project |
| 3 | T2 (GHES) | First on-premises appliance; slowest to provision |
| 4 | T3 (hybrid) | Just T2 plus GitHub Connect — cheap once T2 exists |
| 5 | T5 (ADO Server) | Shares nothing with the others; build last |

---

## 3. Terraform stacks

Applied in ascending order, destroyed in descending order.

| Stack | Contains | Needed by |
| --- | --- | --- |
| `00-shared` | Resource group, ACR, Log Analytics, App Insights, storage (CF-IAC-040) | All |
| `10-aks` | AKS cluster, node pools, namespaces (CF-IAC-041) | All |
| `20-ghes` | GHES appliance VM, data disk, NSG | T2, T3 |
| `30-ado-server` | Windows Server VM, SQL Server, ADO Server | T5 |
| `40-github` | GitHub org config, repositories, rulesets, environments | T1, T3, T4 |
| `50-ado` | ADO project, boards, service connections | T4, T5 |

```powershell
cd infra/terraform/00-shared
terraform init
terraform apply
```

Teardown reverses the order automatically:

```powershell
./scripts/teardown.ps1 -ExpectedSubscriptionNameLike '<part of your subscription name>'
```

That `-ExpectedSubscriptionNameLike` argument is a mandatory safety interlock. The script
refuses to destroy anything if the active subscription's name does not contain the string.

---

## 4. GHES sizing (Track 2 and 3)

These figures are from GitHub's published requirements, not estimates.

**Baseline** for a trial / demo / up-to-10-light-users instance:

| Resource | Value |
| --- | --- |
| vCPU | 4 |
| RAM | 32 GB |
| Root disk | 400 GB |
| Attached data disk | 500 GB |
| Root disk IOPS | 600 |

**Then add capacity for the features this showcase uses:**

- **+25% CPU and memory for GitHub Actions**
- **+25% CPU and memory again for GitHub Code Security**

Which takes 4 vCPU / 32 GB to 8 vCPU / 64 GB, so the recommended VM is:

```
Standard_E8s_v5
```

Memory-optimised, and the `s` suffix is **required** — GHES needs premium storage.

### Things that will surprise you

1. **Azure VM extensions are not supported.** GHES uses a customised `waagent` with a
   restricted `walinuxagent`. That means **no Azure Monitor Agent, no Azure Backup, and no
   Azure Disk Encryption.** If your organisation mandates those on every VM, raise it early —
   it is an exception request, not a configuration problem.
2. **A separate persistent data disk is mandatory.** Minimum 150 GiB for non-production, and
   it must be attached with `--caching ReadWrite`.
3. **The root filesystem shows 200 GB of a 400 GB root disk.** The other 200 GB is reserved
   for upgrades. This is normal; do not "reclaim" it.
4. **Actions on GHES requires external blob storage.** Azure Blob in this build. Actions will
   not enable without it.

### Provisioning

```bash
# Find the current appliance image
az vm image list --all -f GitHub-Enterprise | grep '"urn": "GitHub:' | sort -V

az vm create -n <VM_NAME> -g <RG> --size Standard_E8s_v5 -l <REGION> \
  --image <APPLIANCE_IMAGE> --storage-sku Premium_LRS

az vm disk attach --vm-name <VM_NAME> -g <RG> --sku Premium_LRS \
  --new -z 500 --name ghe-data.vhd --caching ReadWrite
```

### Ports

| Port | Purpose |
| --- | --- |
| 22 | Git over SSH |
| 25 | SMTP |
| 80 | HTTP (redirects to HTTPS) |
| 122 | Instance shell SSH |
| 161/UDP | SNMP |
| 443 | HTTPS |
| 1194/UDP | High-availability replication VPN |
| 8080 | Management console (plain HTTP) |
| 8443 | Management console (HTTPS) |
| 9418 | Git protocol |

---

## 5. Azure DevOps Server sizing (Track 5)

| Component | Requirement |
| --- | --- |
| ADO Server 2022 | Windows Server 2022 or 2019, SQL Server 2022 or 2019 |
| Latest ADO Server | Windows Server 2025 or 2022, SQL Server 2025 or 2022 |
| Single-server tier | One octa-core processor, 16 GB RAM, SSD |

That single-server sizing supports roughly 250 users **for core source control and work item
tracking only**. Microsoft's own wording is unambiguous:

> "Extensive use of automated build, test, or release likely will cause performance issues."

And separately:

> "We don't recommend installing build, test, or release agents on your Azure DevOps Server
> or TFS application tiers."

So Track 5 needs **at least two VMs**: the application tier, and a separate build agent. A
CI/CD demo that runs agents on the app tier will be slow in a way that is not representative,
and an experienced ADO administrator in the room will notice.

Other constraints:

- **SQL Server on Linux is not supported.**
- **SQL Express is evaluation-only.**
- **Azure SQL Database and SQL Managed Instance are supported only when using Azure VMs** —
  which is our case, so it is an option.
- **Code Search should run on a separate server.**

---

## 6. Actions Runner Controller (Track 1, 2, 3)

```bash
helm install arc \
  --namespace arc-systems --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

helm install arc-runner-set \
  --namespace arc-runners --create-namespace \
  --set githubConfigUrl="https://github.com/<org>/<repo>" \
  --set githubConfigSecret.github_token="<PAT>" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

Four things that account for most first-time failures:

1. `runs-on:` must be the **Helm installation name** (`arc-runner-set`) — not a label you
   invent.
2. Runner pods must be in a **different namespace** from the controller pods.
3. The PAT needs `repo` **and** `admin:org` scopes.
4. Use a Kubernetes secret rather than passing the token on the Helm command line. The
   command above is the documented quick-start form; do not ship it.

---

## 7. Copilot coding agent (Beat 4)

Confirm all of these before demonstrating, in this order:

- [ ] **Admin policy enabled.** Off by default for Copilot Business and Enterprise. This is
      the most common reason Beat 4 fails.
- [ ] Repository is hosted on **GHEC**. The agent does not work with GHES-hosted repositories
      at all.
- [ ] Actions minutes and AI credits available — the agent consumes both.
- [ ] If any ruleset restricts commit authors, **Copilot is added as a bypass actor**.
      Otherwise the agent's push is rejected and it appears to do nothing, with no error the
      developer can see.
- [ ] [`copilot-setup-steps.yml`](../.github/workflows/copilot-setup-steps.yml) is on the
      default branch and its job is named exactly `copilot-setup-steps`.

Session limit is **59 minutes**, hard. You can lower it with `timeout-minutes` in
`copilot-setup-steps.yml` but you cannot raise it.

---

## 8. Order of operations that is easy to get wrong

**Push the seed repository before defining the custom secret scanning pattern.**

`scripts/bootstrap-t1.ps1` enforces this and will refuse to run if the preconditions are
wrong, but it is worth understanding why rather than trusting the guard:

1. Push the repository. CF-SEC-003 (`ctso_live_…`) goes in unnoticed, because nothing on the
   server yet knows what that prefix means.
2. Define the custom pattern at **organisation** level.
3. Run a **backfill scan**. CF-SEC-003 surfaces in already-merged history.

Reverse steps 1 and 2 and push protection blocks the bootstrap push, so the repository can
never be seeded at all — and you lose the more interesting half of Beat 5.

Full explanation: [`seeds/secret-patterns.md`](../seeds/secret-patterns.md).

---

## 9. Cost control

- **One AKS cluster, one namespace per track.** Five clusters is the single most expensive
  mistake available here.
- The GHES and ADO Server VMs are the dominant line items. **Deallocate them between
  sessions** — deallocated VMs stop compute charges; stopped-but-allocated do not.
- Run `scripts/teardown.ps1` when a track is finished, then verify:
  ```powershell
  az resource list --query "[].{name:name,type:type,rg:resourceGroup}" -o table
  ```
  Terraform only destroys what it created. Anything created by hand during a demo survives.

See [`docs/cost-model.md`](cost-model.md) for the per-track model.
