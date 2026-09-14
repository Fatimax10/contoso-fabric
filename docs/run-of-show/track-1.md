# Track 1 — GitHub Enterprise Cloud + Copilot

**Duration:** 75 minutes (technical deep-dive) · 3.5 hours (hands-on lab)
**Positioning:** cloud-native, AI-first. This is the north star every other track is measured against.

## Feature checklist

- [ ] GitHub Issues and Projects v2 planning
- [ ] Repository instructions with `AGENTS.md` and Copilot instructions
- [ ] Copilot Chat, edits, completions, and agent mode in VS Code
- [ ] Copilot coding-agent delegation from an issue
- [ ] Secret scanning, custom patterns, backfill scanning, and push protection
- [ ] CodeQL, Dependabot, dependency review, Copilot review, and Autofix
- [ ] Reusable GitHub Actions workflows and ARC runners on AKS
- [ ] SBOM generation and build-provenance attestations
- [ ] AKS deployment with environments, approval, and Azure OIDC
- [ ] Application Insights, Azure Monitor, and Defender for Cloud evidence
- [ ] Alert-to-issue-to-agent hotfix flow
- [ ] Rulesets, audit streaming, Copilot metrics, and cost attribution

---

## Before you walk in

```powershell
./scripts/verify-track.ps1 -Track T1 -Organization <org> -ResourceGroup <rg> -ClusterName <aks>
```

Everything must be PASS. Then confirm the four things that script cannot check:

- [ ] **Copilot coding agent policy is enabled.** Off by default on Business and Enterprise.
      This is the single most common cause of a failed Beat 4.
- [ ] **Copilot is a bypass actor** on any ruleset that restricts commit authors.
- [ ] **`appsettings.Development.json` is clean.** Beat 5 injects the secret live.
- [ ] **CodeQL has run and four alerts are open.** Alerts come from analysis, not from the
      reset script.

Browser tabs, pre-opened and logged in, in this order: repository → Issues → Actions →
Security → Insights → Azure Portal (AKS) → Application Insights.

> **Start Beat 4 early.** The agent takes 5–15 minutes. Kick it off at the top of Beat 3 and
> come back to it. Watching a progress spinner is the fastest way to lose a room.

---

## Run of show

| # | Beat | Time | Cumulative |
| --- | --- | --: | --: |
| 0 | Framing | 3 | 3 |
| 1 | Plan | 4 | 7 |
| 2 | Spec & context | 5 | 12 |
| 3 | Code | 8 | 20 |
| 4 | Delegate *(started during Beat 3)* | 6 | 26 |
| 5 | Commit gate | 7 | 33 |
| 6 | Review | 10 | 43 |
| 7 | CI | 6 | 49 |
| 8 | Supply chain | 5 | 54 |
| 9 | CD | 7 | 61 |
| 10 | Observe | 5 | 66 |
| 11 | Incident | 6 | 72 |
| 12 | Govern | 3 | 75 |

---

### Beat 0 — Framing (3 min)

Show `README.md` and the 12-beat table.

> "One application, one storyline, replayed five times on five different platform
> configurations. Everything you're about to see is real — the code builds, the tests run,
> the vulnerabilities are genuine. Nothing here is a screenshot."

Say explicitly that the findings are planted and why: *a demo with no defects proves nothing,
because the tools have nothing to find.*

---

### Beat 1 — Plan (4 min)

**Show:** Issues tab, then the Project board.

Open [`seeds/issues/01-pricing-calculator-tests.md`](../../seeds/issues/01-pricing-calculator-tests.md)
as the rendered issue. Walk the acceptance criteria.

**The point to land:** this issue is written well enough that a machine could act on it. Most
backlogs are not. The quality of your issues is now a *capability* constraint, not just a
hygiene one.

> **Concede early:** "If your programme managers live in Azure Boards, its hierarchy and
> capacity planning are genuinely better than this. That's Track 4, and it's a legitimate
> choice — not a consolation prize."

Saying that here buys you credibility you will spend later.

---

### Beat 2 — Spec & context (5 min)

**Show:** [`AGENTS.md`](../../AGENTS.md), then
[`.github/copilot-instructions.md`](../../.github/copilot-instructions.md).

These are the house rules — architecture, conventions, the "do not fix planted findings"
instruction. Point out that they are **files in the repository**, so they are reviewed,
versioned, and diffable like any other code.

Then Copilot Spaces: curated context for a domain, shared across a team.

> **Flag it now:** "Spaces is a GitHub.com surface. It does not exist on GitHub Enterprise
> Server. `AGENTS.md` travels anywhere; the AI that reads it does not. That distinction is
> the whole of Track 2 and Track 3."

---

### Beat 3 — Code (8 min)

**Start Beat 4 first.** Assign issue #1 to Copilot, confirm it has picked it up, then carry on.

**Show, in the IDE:**
1. Copilot chat answering a question about `PricingCalculator` — it knows the 25% cap because
   `AGENTS.md` told it.
2. Agent mode making a small multi-file edit.
3. Next-edit suggestions.

**The point:** inline assistance is table stakes now. The interesting shift is the *delegation*
you started 90 seconds ago and are not watching.

---

### Beat 4 — Delegate (6 min)

Return to the agent's pull request.

**Walk:** the session log → the plan it formed → the tests it wrote → the PR description.

Facts to state precisely, because these are the questions you will get:

- Works on **all paid Copilot plans**; Business/Enterprise need the **admin policy on**.
- Consumes **Actions minutes and AI credits**. Not free at the margin.
- **59-minute hard cap.** Lower it with `timeout-minutes`; you cannot raise it.
- One repo, one branch, one PR. It cannot work across repositories.
- **GHEC only.** It does not work with GHES-hosted repositories at all.

> **Be honest about task selection:** "This task was chosen because it's pure functions, fully
> specified, and verifiable. Hand it something vague or cross-cutting and you'll get
> confident nonsense. Delegating well is a skill your teams will have to learn."

If the agent produced something imperfect — **show it anyway**. A demo where the AI is
flawless is a demo nobody believes.

---

### Beat 5 — Commit gate (7 min) · *highest-impact beat*

Do this live at a terminal. Never from a slide.

```powershell
./scripts/inject-planted-secret.ps1
git add . ; git commit -m "Add local dev connection string" ; git push
```

**The push is rejected.** Read the block message aloud — the secret never reached the server.

Then the other half. Open Security → Secret scanning → the `ctso_live_…` alert.

> "That one is in `main`. It's been reviewed, merged, and deployed. Push protection didn't
> catch it, because when it was committed nobody had told GitHub what a Contoso API key looks
> like. We defined a custom pattern afterwards and backfilled the scan — and there it was."

Then:

> "Push protection stops tomorrow's leak. Backfill scanning tells you about the one you
> shipped last year. You need both, and only one of them is comfortable to look at."

Show [`seeds/secret-patterns.md`](../../seeds/secret-patterns.md) and mention the **dry run** —
the step most organisations skip and then regret.

Reset before moving on:

```powershell
./scripts/inject-planted-secret.ps1 -Revert
```

---

### Beat 6 — Review (10 min)

Open the seeded pull request. Four things are already waiting:

| Source | Finding |
| --- | --- |
| CodeQL | `cs/sql-injection`, `js/xss`, `py/path-injection`, `py/ssrf` |
| Dependabot | Newtonsoft.Json, axios, lodash, jinja2, requests, urllib3 |
| Dependency review | blocks the introduction of anything new |
| Copilot code review | the design-level comments no scanner produces |

**Show Copilot Autofix on `cs/sql-injection`** — it generates the parameterised query as a
committable suggestion.

Two moments worth slowing down for:

**The worker findings.** Open [`reports.py`](../../app/src/worker-python/worker/reports.py).
The *correct* implementation — `safe_report_path()` — is sitting right there, unused. Somebody
wrote the guard and never wired it up.

> "A reviewer skims this diff, sees a correct-looking helper, and approves. Static analysis
> follows the data and notices nothing calls it. That's the gap this closes."

**The Next.js advisory.** `next` 15.1.6 was current and clean when it was pinned. It now
carries CVE-2025-66478 — an advisory that landed while the file sat untouched.

> "Nobody planted that one. It rotted on its own, in a lockfile nobody opened. Everyone in
> this room has one of those right now."

---

### Beat 7 — CI (6 min)

**Show:** [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — twenty lines calling
reusable workflows the platform team owns.

Then the same job running on GitHub-hosted runners and on ARC-on-AKS. The only difference is
the `runs-on` input.

Gotchas worth mentioning while the run is live:

- `runs-on:` must be the **Helm installation name**, not an invented label.
- Runner pods belong in a **different namespace** from the controller.

---

### Beat 8 — Supply chain (5 min)

SBOM export → build provenance attestation → `gh attestation verify`.

Then the planted Dockerfile findings:

- **CF-SUP-030:** the API image builds `FROM …:latest`. The same commit can produce a
  different image tomorrow.
- **CF-SUP-031:** the worker runs as root with no healthcheck.

Then open [`values.yaml`](../../app/deploy/helm/values.yaml) and show `runAsNonRoot: true`.

> "The cluster policy compensates. The image is still wrong, and the next platform that runs
> it might not compensate. Defence in depth is not a fix."

---

### Beat 9 — CD (7 min)

Trigger the deploy. Show the **approval gate** on the `production` environment, then approve.

**Show `permissions: id-token: write`** and the absence of any stored credential.

> **Do not claim this is unique to GitHub.** "Azure DevOps has Workload Identity Federation
> and it's equally mature. The real difference is *where the approval lives*: here it's in
> repository settings, readable next to the workflow. In ADO it's on the environment object
> in the UI — less reviewable in source control, harder for a repo admin to quietly weaken.
> Both are defensible."

---

### Beat 10 — Observe (5 min)

App Insights release annotation on the deployment → Azure Monitor → Defender for Cloud
recommendations against the AKS cluster and the storage account (CF-IAC-040, CF-IAC-041).

---

### Beat 11 — Incident (6 min)

The flaky test. It passes locally — `pyproject.toml` deselects it — and fails in CI, which
opts back in.

> "Green on the laptop, red in the pipeline. That's not a broken test, that's the most
> expensive kind of test there is."

Show the CI step summary reporting *n* failures out of 5 repeats. Then: alert → issue →
delegate to Copilot → hotfix PR. The loop closes without a human writing the fix.

> **Concede:** "Azure DevOps Test Analytics detects and reports flaky tests natively. GitHub
> doesn't, out of the box — that's why the workflow repeats the test and counts failures by
> hand. Track 4 arguably wins this beat outright: the agent *and* the analytics."

---

### Beat 12 — Govern (3 min)

Rulesets at org level → audit log streaming → **Copilot usage metrics API**.

> "Last question every time: how would we prove any of this is working? Enterprise admins can
> pull PR lifecycle metrics, including agent-authored PRs, from the metrics APIs. You can
> measure it, not just feel it."

---

## Close

Pull up [`docs/comparison-matrix.md`](../comparison-matrix.md).

> "Everything you just saw works here because the code is in the cloud. Four beats break
> when it isn't — and for some of you it can't be. That's what the next four tracks are for."

---

## When it goes wrong

| Symptom | Cause | Do this |
| --- | --- | --- |
| Agent does nothing, no error | Ruleset restricts commit authors | Add Copilot as bypass actor. **Check before you start.** |
| Agent unavailable on the issue | Admin policy off | Enterprise/Org → Settings → Copilot → Policies |
| Push protection doesn't fire | Feature disabled, or secret didn't inject | `verify-track.ps1`; re-run the inject script |
| No CodeQL alerts | Analysis hasn't run since reset | Re-run the workflow and **wait**. This is why you check the night before. |
| PR blocked "waiting for status" | Required context name ≠ reported check name | `gh api repos/<slug>/commits/main/check-runs --jq '.check_runs[].name'` |
| Flaky test passes 5/5 | 1-in-6 failure rate, bad luck | Raise `flaky-repeats` to 15 before the session |
| AKS pods pending | Cluster scaled down overnight | Scale up and allow node warm-up |

**If the agent fails live:** do not hide it. Show the session log, explain what it got stuck
on, and move on. A room that watches you handle a failure honestly will trust everything else
you said.
