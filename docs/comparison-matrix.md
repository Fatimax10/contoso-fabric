# Comparison matrix — 12 beats × 5 tracks

This is the scoring grid the whole showcase exists to fill in. Each of the 12 beats is
performed identically in every track that supports it; where a track cannot perform a beat,
the cell says so plainly and names the workaround.

**How to read it.** The matrix is not a scorecard where GitHub Enterprise Cloud "wins". It is
a decision aid. Several cells favour Azure DevOps, several favour GitHub Enterprise Server,
and a few capabilities simply do not exist in one configuration at any price. Presenting the
losses honestly is what makes the wins believable.

Legend:

| Symbol | Meaning |
| --- | --- |
| ✅ | Native, first-party, works out of the box |
| ⚙️ | Works, but requires configuration or additional infrastructure you must own |
| 🔶 | Partial — a materially reduced version of the capability |
| ❌ | Not available in this configuration at any price |

Tracks:

| | Track |
| --- | --- |
| **T1** | GitHub Enterprise Cloud + Copilot |
| **T2** | GitHub Enterprise Server (standalone, air-gapped) |
| **T3** | GHES + GHEC via GitHub Connect (hybrid) |
| **T4** | GHEC repositories + Azure DevOps Boards / Artifacts / Test Plans |
| **T5** | Azure DevOps Server (standalone) |

---

## The grid

| # | Beat | T1 | T2 | T3 | T4 | T5 |
| --- | --- | :-: | :-: | :-: | :-: | :-: |
| 1 | Plan | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2 | Spec & context | ✅ | 🔶 | ✅ | ✅ | ❌ |
| 3 | Code (IDE assistance) | ✅ | ⚙️ | ✅ | ✅ | ⚙️ |
| 4 | Delegate to the coding agent | ✅ | ❌ | 🔶 | 🔶 | ❌ |
| 5 | Commit gate (push protection) | ✅ | ⚙️ | ⚙️ | ✅ | ❌ |
| 6 | Review (SAST, SCA, AI review) | ✅ | ⚙️ | ⚙️ | ✅ | ❌ |
| 7 | CI | ✅ | ⚙️ | ⚙️ | ✅ | ⚙️ |
| 8 | Supply chain (SBOM, provenance) | ✅ | 🔶 | 🔶 | ✅ | ❌ |
| 9 | CD to AKS | ✅ | ⚙️ | ⚙️ | ✅ | ⚙️ |
| 10 | Observe | ✅ | ⚙️ | ⚙️ | ✅ | ⚙️ |
| 11 | Incident → hotfix | ✅ | 🔶 | 🔶 | ✅ | 🔶 |
| 12 | Govern | ✅ | 🔶 | ✅ | ✅ | 🔶 |

The grid is the summary. The reasoning below is what you actually present.

---

## Beat-by-beat

### Beat 1 — Plan

| Track | Detail |
| --- | --- |
| T1 | GitHub Issues + Projects v2. Custom fields, roadmap view, built-in iteration field. |
| T2 | Same, served locally. Projects v2 is available on GHES. |
| T3 | Same as T2; GitHub Connect does not move issues to the cloud. |
| T4 | Azure Boards. Richer hierarchy (Epic → Feature → User Story → Task), native capacity planning, sprint burndown. |
| T5 | Azure Boards on the local server. Same features, your hardware. |

**This beat favours Azure DevOps and you should say so.** Boards has work-item hierarchy,
capacity planning, and query-based reporting that GitHub Projects does not match. If the
customer's programme managers live in Boards, that is a legitimate reason to keep Boards —
which is precisely why Track 4 exists.

The trade to name out loud: Boards' traceability from work item to commit requires the ADO
service connection to GitHub in T4, and that link is one-directional in practice.

---

### Beat 2 — Spec & context

The artifact is [`AGENTS.md`](../AGENTS.md) plus
[`.github/copilot-instructions.md`](../.github/copilot-instructions.md).

| Track | Detail |
| --- | --- |
| T1 | Custom instructions, `AGENTS.md`, path-scoped `.instructions.md`, and Copilot Spaces for curated context. |
| T2 | `AGENTS.md` and repository custom instructions are files in the repo, so they exist. **Copilot Spaces is a GitHub.com surface and is not available on GHES.** |
| T3 | Developers use GHES for code and GHEC/Copilot for AI, so Spaces is reachable. |
| T4 | Code is in GHEC, so identical to T1. |
| T5 | No Copilot surface bound to the server at all. Instruction files exist but nothing consumes them from the platform. |

> The honest framing for T2: *the files are portable, the AI that reads them is not.*

---

### Beat 3 — Code (IDE assistance)

| Track | Detail |
| --- | --- |
| T1 | Copilot chat, completions, edits, agent mode in VS Code, all bound to a GHEC identity. |
| T2 | Copilot in the IDE requires a Copilot licence assigned through **GitHub.com**, not through the GHES instance. It works if the developer's workstation has internet access and a linked GHEC account — but that is an internet dependency you must design for, and in a genuinely air-gapped environment it is unavailable. |
| T3 | This is precisely what GitHub Connect is for. Code stays on GHES; the developer's Copilot licence is synced from GHEC. |
| T4 | Identical to T1. |
| T5 | Copilot has no relationship to ADO Server. Developers can still use Copilot with a personal/enterprise GitHub identity in the IDE, but nothing about it is governed by, or visible to, the ADO Server instance. |

⚙️ rather than ❌ for T2/T5 is deliberate: the IDE experience is a workstation concern, not
a server concern. Be precise about this or a knowledgeable customer will correct you.

---

### Beat 4 — Delegate to the Copilot coding agent

**This is the single sharpest differentiator in the entire showcase.**

The verified constraint: the Copilot coding agent **only works with repositories hosted on
GitHub.com / GHEC**. It is not available on GitHub Enterprise Server.

| Track | Detail |
| --- | --- |
| T1 | ✅ Assign issue CF-QUA-051 (zero-coverage `PricingCalculator`) to Copilot. It opens a branch, works for up to 59 minutes, and raises exactly one PR. |
| T2 | ❌ Not available. No workaround exists. |
| T3 | 🔶 Only for repositories that actually live in GHEC. A GHES-hosted repository cannot be delegated, so the hybrid answer is "for the repos you are willing to host in the cloud". |
| T4 | 🔶 The agent works (repos are in GHEC), but the **Azure Boards integration supports only "create a pull request directly"** — there is no research or plan mode from a Boards work item, unlike the Teams and Slack integrations. |
| T5 | ❌ Not available. |

Facts worth having on the slide, because they are the questions that get asked:

- Available on **all paid Copilot plans**; Copilot Business and Enterprise require an
  **admin policy to be enabled first** — it is off by default.
- Consumes **GitHub Actions minutes and AI credits**. It is not free-at-the-margin.
- **59-minute hard session cap**, configurable lower via `timeout-minutes` in
  [`copilot-setup-steps.yml`](../.github/workflows/copilot-setup-steps.yml).
- One repo, one branch, one PR per task. It cannot work across repositories.
- If a ruleset restricts who may author commits, **add Copilot as a bypass actor** or the
  agent's push is rejected. This is the number-one cause of "it silently did nothing".

---

### Beat 5 — Commit gate (push protection)

The artifacts are [`seeds/secret-patterns.md`](../seeds/secret-patterns.md) and
[`scripts/inject-planted-secret.ps1`](../scripts/inject-planted-secret.ps1).

| Track | Detail |
| --- | --- |
| T1 | ✅ Secret Protection. Partner patterns block CF-SEC-001/002 on push; the custom `ctso_live_…` pattern is defined at org level and a backfill scan finds CF-SEC-003 already in history. |
| T2 | ⚙️ Secret scanning and push protection are available on GHES with a **GitHub Secret Protection** licence, and custom patterns work. Partner-pattern *validity checks* (asking the provider whether a leaked credential is live) depend on outbound connectivity. |
| T3 | ⚙️ As T2. GitHub Connect does not change secret scanning; it governs Dependabot, Actions, licence sync, and search. |
| T4 | ✅ Code is in GHEC, so identical to T1. |
| T5 | ❌ GitHub Advanced Security **for Azure DevOps** provides secret scanning and push protection for Azure Repos, but Microsoft documents it as "only available for Azure DevOps Services". There is no version of **ADO Server** that has it — you are relying on third-party tooling or pre-commit hooks. See [Verification status](#verification-status). |

The two-part story — *prevent* (push protection) versus *detect* (backfill scan of history) —
is documented in [`seeds/secret-patterns.md`](../seeds/secret-patterns.md) and is the most
transferable idea in the whole deck.

---

### Beat 6 — Review

Planted findings: CF-SEC-010 `cs/sql-injection`, CF-SEC-011 `js/xss`,
CF-SEC-012 `py/path-injection`, CF-SEC-013 `py/ssrf`, plus CF-DEP-020…025.

| Track | Capability | Detail |
| --- | --- | --- |
| T1 | CodeQL ✅ · Dependabot ✅ · Dependency review ✅ · Copilot code review ✅ | Everything in one PR conversation. |
| T2 | CodeQL ⚙️ · Dependabot ⚙️ · Copilot review ❌ | CodeQL runs on GHES with a Code Security licence, but **you must supply the runners and keep the CodeQL bundle updated**, and in an air-gapped instance that is a deliberate sync process. Dependabot on GHES **requires GitHub Connect** for advisory data. |
| T3 | CodeQL ⚙️ · Dependabot ✅ · Copilot review 🔶 | This is exactly the problem GitHub Connect solves: Dependabot alerts *and* security updates flow to GHES **without any repository, issue, or pull request leaving the server**. |
| T4 | ✅ across the board | Code is in GHEC. |
| T5 | ❌ for SAST | No first-party CodeQL. GHAzDO's dependency scanning is an ADO **Services** feature. On ADO Server you are buying a third-party scanner. |

The GitHub Connect fact that consistently lands with security architects:

> **No repositories, issues, or pull requests are ever transmitted from GHES to GHEC.**
> The connection is HTTPS over 443, TLS-secured, and does not expose the server to the
> public internet.

Copilot code review also **consumes Actions minutes on private repositories** — budget for it.

---

### Beat 7 — CI

| Track | Detail |
| --- | --- |
| T1 | GitHub-hosted runners, plus Actions Runner Controller on AKS for the self-hosted comparison. |
| T2 | ⚙️ **There are no GitHub-hosted runners.** Every minute is yours to provision. Actions on GHES additionally **requires external blob storage** — Azure Blob in this build. |
| T3 | ⚙️ As T2 for compute, but GitHub Connect (GHES 3.20.6+ / 3.21.0+) allows workflows to **use actions from GitHub.com**, which removes the biggest day-to-day friction of a standalone GHES: no more vendoring `actions/checkout`. |
| T4 | ✅ Microsoft-hosted ADO agents, or the same ARC cluster. |
| T5 | ⚙️ Self-hosted agents only. Note Microsoft's own guidance: **"we don't recommend installing build, test, or release agents on your Azure DevOps Server application tiers."** Separate agent machines are not optional. |

ARC install, for the record:

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

Two details that cause most first-time failures:

- `runs-on:` must be the **Helm installation name** (`arc-runner-set`), not a label you
  invented.
- Runner pods belong in a **different namespace** from the controller pods.

---

### Beat 8 — Supply chain

| Track | Detail |
| --- | --- |
| T1 | ✅ SBOM export, `actions/attest-build-provenance`, immutable actions, artifact attestations verified with `gh attestation verify`. |
| T2 | 🔶 SBOM generation is just a workflow step, so it works. Attestation verification depends on transparency-log connectivity, which an air-gapped instance does not have. |
| T3 | 🔶 As T2. |
| T4 | ✅ Builds run in Actions, so identical to T1. |
| T5 | ❌ No first-party provenance story. ADO Artifacts is a good package feed; it is not a provenance system. |

This beat is where the planted Dockerfile findings pay off: CF-SUP-030 (moving `:latest`
base tag) and CF-SUP-031 (root user, no healthcheck) give the SBOM and container-scanning
discussion something concrete to point at.

---

### Beat 9 — CD to AKS

| Track | Detail |
| --- | --- |
| T1 | ✅ GitHub Environments, required reviewers, OIDC federated credentials — **no stored secret**. |
| T2 | ⚙️ Environments and approvals work. OIDC to Azure requires the GHES instance to be reachable by Entra ID for token exchange, which an air-gapped instance is not; fall back to a workload identity on a self-hosted runner. |
| T3 | ⚙️ As T2. |
| T4 | ✅ ADO environments with checks and approvals, and an ARM service connection using **Workload Identity Federation** — also secretless. |
| T5 | ⚙️ Same pipeline YAML, but the service connection is to your own network; secretless federation depends on the server being able to reach Entra ID. |

**Do not claim GitHub is uniquely secretless.** ADO's Workload Identity Federation is the
equivalent capability and it is mature. The real difference in T1 vs T4 is where approvals
are *defined*: GitHub environments are configured in repository settings and are readable
alongside the workflow, whereas ADO environment checks live in the ADO UI — less reviewable
in source control, but harder for a repository admin to weaken unilaterally.

---

### Beat 10 — Observe

Largely track-independent, because the observability is Azure's, not the SCM's.

| Track | Detail |
| --- | --- |
| T1 | ✅ App Insights release annotations from the deploy workflow, Azure Monitor alert, Defender for Cloud recommendation on the AKS cluster. |
| T2 | ⚙️ Same Azure telemetry, but the release annotation has to be pushed from a self-hosted runner with outbound access. |
| T3 | ⚙️ As T2. |
| T4 | ✅ Same, plus ADO's native deployment history. |
| T5 | ⚙️ Same Azure side; the correlation back to a work item is manual. |

CF-IAC-040 (public blob container + TLS 1.0) and CF-IAC-041 (AKS without diagnostic
settings) are the planted findings that make Defender for Cloud light up on cue.

---

### Beat 11 — Incident → hotfix

The trigger is CF-QUA-050, the genuine race condition in
`tests/test_scheduler.py::test_timer_flushes_the_batch_before_the_deadline`. It is
deselected locally by `-m 'not flaky'` in `pyproject.toml` and opted back into in CI — green
on the laptop, red in the pipeline, which is the entire pathology of a real flaky test.

| Track | Detail |
| --- | --- |
| T1 | ✅ Alert → issue → **re-delegate to the Copilot coding agent** → hotfix PR. The loop closes without a human writing the fix. |
| T2 | 🔶 Alert → issue → human fixes it. No agent. |
| T3 | 🔶 As T2 unless the repository is GHEC-hosted. |
| T4 | ✅ Agent available, **and** ADO Test Plans / Test Analytics natively detect and report flaky tests — a genuine ADO advantage GitHub does not match out of the box. |
| T5 | 🔶 Flaky-test analytics ✅, agent ❌. |

Beat 11 is the fairest beat in the deck: T4 arguably scores highest, because it combines the
agent with ADO's flaky-test analytics. Let that stand.

---

### Beat 12 — Govern

| Track | Detail |
| --- | --- |
| T1 | ✅ Org and enterprise rulesets, audit log streaming to Event Hubs / Storage, **Copilot usage metrics APIs**, cost attribution by cost centre. |
| T2 | 🔶 Rulesets ✅, audit log ✅ (local). **Server Statistics requires GitHub Connect**, and there are no Copilot metrics because there is no Copilot. |
| T3 | ✅ Adds Server Statistics and unified search/contributions across both. Note: connecting to **GHE.com** rather than GitHub.com **does not support Server Statistics**, and licence sync needs GHES 3.15+. |
| T4 | ✅ GitHub governance for code, ADO governance for work items and pipelines — two audit surfaces, which is a genuine cost. |
| T5 | 🔶 ADO Server has solid permissions and auditing; the enterprise-wide policy-as-code and streaming story is weaker. |

Enterprise and organisation admins can pull PR lifecycle metrics — including agent-authored
PRs — from the Copilot usage metrics APIs. That is how you answer "how would we prove this
is working?", which is always the last question.

---

## What each track is actually for

| Track | Choose it when |
| --- | --- |
| **T1** | You can host code in the cloud. Everything works, the agent works, the compliance story is strongest. This is the default recommendation. |
| **T2** | Code genuinely cannot leave the building. Accept: no coding agent, no hosted runners, you own CodeQL bundle updates and blob storage, and Dependabot needs Connect. |
| **T3** | Code must stay on-premises **but** you want cloud AI and current advisory data. The strongest regulated-industry answer, and the fact that no repository, issue, or PR ever leaves the server is what unblocks the security review. |
| **T4** | Boards is entrenched and re-training programme managers is not on the table. Keep Boards, move code to GHEC, get the full security and agent story anyway. Often the most *realistic* enterprise end-state. |
| **T5** | This is the "before" picture. Present it as the baseline the other four are measured against, not as a recommendation. |

---

## Verification status

Two claims here could not be confirmed from published documentation on the first research
pass. One is now settled; the other is narrowed but still needs a live check.

### 1. GHAzDO on Azure DevOps Server — resolved 2026-08-27

Microsoft Learn states it without qualification:

> GitHub Advanced Security for Azure DevOps is only available for Azure DevOps Services and
> specifically for code Git repositories.
>
> — [Configure GitHub Advanced Security for Azure DevOps features](https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops), page updated 2026-08-17

This covers the whole product — Secret Protection *and* Code Security — and it is a
product boundary, not a "not yet in your build" caveat. Two consequences were applied above:

- **Beat 5 / T5 moved from 🔶 to ❌.** It was the only cell claiming a partial capability on
  ADO Server for something that does not ship there at all, and it contradicted Beat 6 / T5,
  which already said ❌ on identical reasoning.
- **Assert the gap without hedging.** Do not offer to check the customer's version — there is
  no version of ADO Server that has it.

### 2. Copilot features in the GHES web UI — narrowed, still needs a live check

Still not authoritatively documented, and now we know why: `docs.github.com` serves **no
Copilot documentation under any `enterprise-server@3.x` version** — every path 404s. The
Copilot docs are GitHub.com-only, and the feature list describes Copilot Chat as available
"on the GitHub website, in GitHub Mobile, in supported IDEs, and in Windows Terminal". GHES
is not named either way.

The GHES release notes are the better source and establish three things:

| Finding | Source |
| --- | --- |
| Copilot **pull request summaries do exist on GHES** — a CVE describes "the Copilot pull request description diff summary endpoint" on the appliance | 3.20.4 security fixes, [CVE-2026-9132](https://www.cve.org/cverecord?id=CVE-2026-9132) |
| Copilot settings for **GitHub Apps are not supported on GHES** — a Copilot tab was shown in error and removed | 3.20.3 bug fixes |
| Copilot code review may be **partially plumbed** — editing a ruleset could fail with `Unexpected parameter automatic_copilot_code_review_enabled` after upgrading | 3.20.6 bug fixes |

The third is ambiguous: a leaked parameter name is not evidence a feature works. Beat 6 still
shows T2 as ❌ for Copilot review, and it should not be upgraded on the strength of a bug-fix
note.

**The check to run** on the Track 2 appliance, signed in as a user holding a Copilot licence:

1. Is there a Copilot Chat entry point anywhere in the web UI — global nav, repository page,
   or the `/copilot` path?
2. On a pull request, is a Copilot summary offered in the description box?
3. On a pull request, can Copilot be requested as a reviewer?
4. Under **Settings → Code security**, does an automatic Copilot code review toggle appear?

Answers to 1–3 correct Beats 2 and 3; answer 4 corrects Beat 6. Until then, present the IDE
story for T2 and say the web-UI surface is version-dependent — which is true, and is a better
answer than guessing.

Everything else in this document was verified against `docs.github.com` and
`learn.microsoft.com`. Where a number appears (59 minutes, 25% CPU uplift, GHES 3.20.6),
it came from the vendor's own documentation, not from estimation.
