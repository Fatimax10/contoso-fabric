# Planted findings manifest

Every defect below is **deliberate**. Each one exists to fire exactly one demo beat, on a
specific tool, producing a specific and predictable alert. If a finding stops firing, the
demo is broken — `scripts/verify-track.ps1` asserts these mechanically.

> [!WARNING]
> All credentials involved are **fake**, randomly generated, and point at resources that do not
> exist. They authenticate nothing. Never replace them with real values.

## Two secrets, two different stories — and why they are seeded differently

`CF-SEC-001` and `CF-SEC-002` are **not committed**. If they were, push protection would reject
the very first bootstrap push and the demo repository could never be seeded. Instead
`scripts/inject-planted-secret.ps1` writes them locally, live on stage, immediately before the
push. That is what makes Beat 5 real rather than a screenshot.

`CF-SEC-003` *is* committed, and demonstrates the opposite capability: the custom pattern is
defined **after** the initial push, and a backfill scan then surfaces the secret that was
already sitting in history. Push protection stops new leaks; backfill scanning finds the ones
you already have. Showing both is the point.

> [!IMPORTANT]
> Bootstrap ordering matters: push the repository **first**, then define the custom secret
> pattern and trigger the backfill scan. `scripts/bootstrap-t1.ps1` enforces this order.

## Manifest

| ID | Beat | Finding | Location | Detected by | Expected signal |
|----|------|---------|----------|-------------|-----------------|
| CF-SEC-001 | 5 | Hardcoded SQL connection string with password | *injected at demo time* → `appsettings.Development.json` | Push protection | Push **blocked**; "Azure SQL connection string" |
| CF-SEC-002 | 5 | Azure Storage account key | *injected at demo time* → `appsettings.Development.json` | Push protection | Push **blocked**; "Azure Storage account key" |
| CF-SEC-003 | 5 | Custom "Contoso API key" pattern (`ctso_live_…`) | `app/src/worker-python/worker/config.py` (committed) | Custom pattern + backfill scan | Historical alert, *not* a block |
| CF-SEC-010 | 6 | SQL injection via string interpolation | `app/src/api-dotnet/Contoso.Fabric.Api/Data/OrdersRepository.cs` | CodeQL (C#) | Rule `cs/sql-injection` |
| CF-SEC-011 | 6 | Reflected XSS via `dangerouslySetInnerHTML` | `app/src/web-next/src/app/orders/[id]/page.tsx` | CodeQL (JS/TS) | Rule `js/xss` |
| CF-SEC-012 | 6 | Path traversal on user-supplied report name | `app/src/worker-python/worker/reports.py` | CodeQL (Python) | Rule `py/path-injection` |
| CF-SEC-013 | 6 | Server-side request forgery on callback URL | `app/src/worker-python/worker/callbacks.py` | CodeQL (Python) | Rule `py/ssrf` |
| CF-DEP-020 | 6 | `Newtonsoft.Json` 12.0.1 — DoS advisory | `app/src/api-dotnet/Contoso.Fabric.Api/Contoso.Fabric.Api.csproj` | Dependabot | GHSA-5crp-9r3c-p9vr |
| CF-DEP-021 | 6 | `axios` 0.21.1 — SSRF / redirect advisories | `app/src/web-next/package.json` | Dependabot | GHSA-4w2v-q235-vp99 |
| CF-DEP-022 | 6 | `lodash` 4.17.11 — prototype pollution | `app/src/web-next/package.json` | Dependabot | GHSA-jf85-cpcp-j695 |
| CF-DEP-023 | 6 | `jinja2` 3.1.2 — sandbox escape / XSS | `app/src/worker-python/requirements.txt` | Dependabot | GHSA-h75v-3vvj-5mfj |
| CF-DEP-024 | 6 | `requests` 2.31.0 — `.netrc` credential leak | `app/src/worker-python/requirements.txt` | Dependabot | GHSA-9wx4-h78v-vm56 |
| CF-DEP-025 | 6 | `urllib3` 2.0.6 — redirect / proxy advisories | `app/src/worker-python/requirements.txt` | Dependabot | GHSA-34jh-p97f-mpxf |
| CF-DEP-026 | 6 | `next` 15.1.6 — see note below | `app/src/web-next/package.json` | Dependabot / npm | CVE-2025-66478 |
| CF-SUP-030 | 8 | Dockerfile uses floating `:latest` base tag | `app/src/api-dotnet/Dockerfile` | Container scanning / policy | Non-reproducible build finding |
| CF-SUP-031 | 8 | Container runs as `root`, no `HEALTHCHECK` | `app/src/worker-python/Dockerfile` | Defender for Containers | "Container running as root" |
| CF-IAC-040 | 8 | Storage account allows public blob access, TLS 1.0 | `infra/terraform/00-shared/storage.tf` | IaC scanning / Defender for Cloud | Public access + weak TLS |
| CF-IAC-041 | 8 | AKS cluster without diagnostic settings | `infra/terraform/10-aks/main.tf` | Defender for Cloud | Missing diagnostics |
| CF-QUA-050 | 11 | Genuinely flaky test (thread scheduling race) | `app/src/worker-python/tests/test_scheduler.py` | CI flake detection | Intermittent red build |
| CF-QUA-051 | 4 | `shared-lib` has **zero** test coverage | `app/src/shared-lib/` | Coverage gate | The Copilot cloud agent task |

## How each finding is used on stage

**Beat 5 — the commit gate.** Run `scripts/inject-planted-secret.ps1`, commit, push. Push
protection rejects the push at the git layer, before the secret ever reaches the server. This
is the single most visceral moment in the demo — always do it live, never from a slide. Then
contrast it with the `CF-SEC-003` historical alert to make the "prevent vs. detect" distinction.

**Beat 6 — the review gate.** Open the seeded PR. CodeQL has already annotated the four
injection findings inline; Dependabot has already opened its PRs; Copilot code review adds
the design-level comments that no scanner produces. Show Copilot Autofix on `CF-SEC-010` —
it generates the parameterised query as a suggested change you can commit from the PR.

**Beat 4 — the agent.** `CF-QUA-051` is the assignable task. `shared-lib` is pure calculation
with no I/O precisely so the agent can succeed at it inside the 59-minute session cap.

**Beat 11 — the incident.** `CF-QUA-050` fails roughly **one run in six** (measured over 12
consecutive local runs). Let it fail, let the alert fire, watch the issue get created, hand it
to Copilot.

Because 1-in-6 will not reliably go red in a single CI run, the workflows repeat the flaky
selection **five times** and report the failure count — see the `flaky-repeats` input on
`.github/workflows/build-python.yml` and the equivalent parameter in
`pipelines/templates/build-python.yml`. That gives roughly a 60% chance of at least one
failure per pipeline run. If you need a guaranteed red for a scripted slot, raise
`flaky-repeats` to 15.

## A note on the vulnerable dependency versions

The pinned versions were chosen under a constraint that is easy to miss: **they must still
install and import on the target runtime**, or CI fails for the wrong reason and the
Dependabot story never gets told.

The obvious choices do not work:

- `PyYAML` 5.3.1 / 5.4.1 fail to **build** on Python 3.12 (Cython 3 incompatibility).
- `requests` 2.19.1 does `from collections import Mapping`, removed in Python 3.10+.

So the Python pins are vulnerable-but-3.12-compatible pure-Python wheels with genuine
advisories. Additionally, **CI installs `requirements-dev.txt`, not `requirements.txt`**, so
the vulnerable pins remain a manifest finding that Dependabot reports without ever being
installed into the runner.

### CF-DEP-026 was not planted — and that is worth saying out loud

`next` 15.1.6 was pinned as a current release. npm now reports it as carrying
**CVE-2025-66478**. Nobody planted it; the advisory landed after the version was chosen.

Keep it, and use it. It is the most honest artifact in this repository: a dependency that was
current and clean when selected, and became a vulnerability while sitting untouched in the
lockfile. That is precisely the case Dependabot exists for, and it is far more persuasive than
the deliberately archaeological pins around it — because every person in the room has this
exact situation in their own codebase right now and does not know it yet.

When you upgrade the other findings' versions during maintenance, **do not upgrade this one
without checking whether a newer real advisory has replaced it.**

## Resetting

`scripts/reset-demo.ps1` restores every finding to its planted state, closes agent-authored
PRs, deletes their branches, and resets the project board. Run it between rehearsals and
before every live delivery.
