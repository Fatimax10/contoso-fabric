# Copilot instructions — Contoso Fabric

This repository is a DevOps demonstration harness containing **intentionally vulnerable code**.
Read `AGENTS.md` for the full contract; the essentials are repeated here.

## Do not remediate planted findings unless explicitly asked

`seeds/FINDINGS.md` catalogues deliberate defects that exist to demonstrate specific security
tooling. Do not remove them opportunistically. When a task *does* ask for remediation, fix the
root cause and cite the finding ID (e.g. `CF-SEC-001`) in the pull request description.

## When writing new code

- Parameterise SQL. Never build a query with string concatenation or interpolation.
- Escape user-controlled values before rendering. No new `dangerouslySetInnerHTML`.
- Canonicalise user-supplied paths and confirm they stay inside the intended root.
- Use `DefaultAzureCredential` / workload identity for Azure. Never add secrets to code,
  config, or workflows.
- Keep `app/src/shared-lib` pure — no I/O, no clock, no ambient state — so it stays trivially
  testable.

## Style

C#: file-scoped namespaces, `sealed` by default, nullable enabled, async all the way down.
TypeScript: strict, no `any`, server components unless browser APIs are needed.
Python: type hints on public functions, `ruff` clean, no bare `except:`.
Tests: `MethodName_Scenario_ExpectedOutcome`. Commits: Conventional Commits.

## Before you open a pull request

Run `scripts/verify-local.ps1` and make sure the .NET, Node, and Python suites all pass.
Explain *why* the change is shaped the way it is — the reviewers here are evaluating the
platform as much as the code.
