# Rulesets

## `main-protection.json`

Applied to the default branch by `scripts/bootstrap-t1.ps1` via:

```
gh api --method POST repos/<org>/<repo>/rulesets --input seeds/rulesets/main-protection.json
```

What it enforces:

- No deletion of, and no force-push to, the default branch.
- One approving review, stale reviews dismissed on push, review threads must be resolved.
- The three CI contexts must pass, and branches must be up to date first
  (`strict_required_status_checks_policy`).
- Squash and merge commits allowed; rebase merges are not.

### The status-check context names are the fragile part

`required_status_checks[].context` must match the **check run name exactly**. For a caller
workflow that invokes a reusable workflow, the name GitHub reports is
`<caller job id> / <job name in the reusable workflow>` — hence `dotnet / build & test`
rather than just `build`.

If a required check never reports, pull requests block forever with "Expected — Waiting for
status to be reported", which on a demo day looks exactly like a broken platform. Verify
after the first CI run:

```
gh api "repos/<org>/<repo>/commits/main/check-runs" --jq '.check_runs[].name'
```

and reconcile any mismatch before presenting.

### Bypass actors and the Copilot coding agent

`bypass_actors` is deliberately empty here, which is the correct default. But note the
consequence for **Beat 4**: if you later add a rule that restricts who may push or author
commits, the Copilot coding agent's push is rejected and the agent appears to do nothing at
all — no error the developer can see.

If that happens, add Copilot as a bypass actor for the ruleset. This is the single most
common cause of "we tried the agent and it didn't work".
