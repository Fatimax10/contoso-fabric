# Custom secret scanning patterns

GitHub secret scanning ships with hundreds of **partner patterns** (AWS keys, Azure Storage
keys, SQL connection strings, and so on). Those cover credentials issued by *someone else*.
They cannot cover a credential format that **your own platform team invented** — and in most
enterprises that is exactly the credential that leaks.

This file defines the one custom pattern the showcase uses. It is the artifact you create
live in Beat 5.

---

## Pattern: Contoso Fabric platform API key

| Field | Value |
| --- | --- |
| **Name** | `Contoso Fabric API key` |
| **Secret format** | `ctso_(live\|test)_[A-Za-z0-9]{32}` |
| **Before secret** | `(^\|[^0-9A-Za-z])` |
| **After secret** | `([^0-9A-Za-z]\|$)` |
| **Test string (should match)** | `ctso_live_7Qx2mVn8dRk4Tp1LzYw6Bs3Ff9Hj5Cg0` |
| **Test string (should NOT match)** | `ctso_live_tooshort`, `ctso_prod_7Qx2mVn8dRk4Tp1LzYw6Bs3Ff9Hj5Cg0` |

### Where to define it

Define it at the **organization** level, not the repository level:

`Organization → Settings → Advanced Security → Secret scanning → Custom patterns → New pattern`

Organization scope is the point of the beat. A pattern defined once protects every current
and future repository in the org — including repositories that do not exist yet. Defining it
per-repository is the anti-pattern, and it is worth saying so out loud on stage.

### Options to enable

- **Push protection** — blocks a push that introduces a new match.
- **Dry run first** (recommended on stage) — shows what the pattern *would* have caught
  across the org without generating alerts, so you can prove the regex is not over-broad
  before you switch it on. This is the step most customers skip and then regret.

---

## Why this pattern is seeded differently from the other two secrets

The showcase plants three secrets, and they are deliberately introduced at different points
in the timeline. That is not an accident of authoring — it is the whole demo.

| ID | Secret | How it enters the repo | Capability demonstrated |
| --- | --- | --- | --- |
| CF-SEC-001 | SQL Server connection string | Injected at demo time by `scripts/inject-planted-secret.ps1` | **Prevent** — push protection blocks the push before the secret ever reaches the server |
| CF-SEC-002 | Storage account key | Injected at demo time by the same script | **Prevent** — second partner pattern in the same push |
| CF-SEC-003 | `ctso_live_…` platform key | **Committed** in `worker/config.py` from the very first bootstrap push | **Detect** — a custom pattern defined *later* finds a secret already sitting in history |

The ordering constraint this creates is load-bearing, so `scripts/bootstrap-t1.ps1` enforces
it:

1. Push the seed repository **first**, while the custom pattern does not yet exist.
   CF-SEC-003 sails through, because nothing on the server knows what `ctso_live_` means.
2. **Then** define the custom pattern (this file) at org level.
3. Run a **backfill scan**. CF-SEC-003 lights up — in a commit that is already merged,
   already reviewed, already deployed.

If you defined the pattern before the first push, step 1 would be blocked and you could never
seed the repository at all. More importantly you would lose the more uncomfortable half of
the story: push protection only guards the front door, and every organisation already has
secrets *behind* it.

### The line that lands

> Push protection stops tomorrow's leak. Backfill scanning tells you about the one you
> shipped last year. You need both, and only one of them is comfortable to look at.

---

## Verifying the pattern

`app/src/worker-python/tests/test_config.py` contains a guard test that asserts the planted
key still matches this regex:

```python
def test_planted_api_key_matches_the_custom_scanning_pattern():
    assert re.fullmatch(r"ctso_(live|test)_[A-Za-z0-9]{32}", CONTOSO_API_KEY)
```

If someone "helpfully" rotates or removes the planted key, that test fails loudly and the
Beat 5 demo is protected from silent bit-rot.

---

## Safety note

Every credential in this repository is fake. `ctso_live_…` authenticates nothing — there is
no Contoso Fabric platform. The connection string and storage key produced by
`scripts/inject-planted-secret.ps1` are randomly generated at injection time and point at
hosts that do not exist. See `seeds/FINDINGS.md` for the full manifest.
