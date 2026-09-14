---
title: "Security: constrain report paths and callback URLs in the worker (CF-SEC-012, CF-SEC-013)"
labels: "security,codeql,remediation,worker"
---

CodeQL raises two alerts against the Python worker, both fed from the same taint source —
`sys.argv` in `worker/__main__.py`:

| Alert | Location | Sink |
| --- | --- | --- |
| `py/path-injection` (CF-SEC-012) | `worker/reports.py` → `read_report` | `os.path.join` + `open` |
| `py/ssrf` (CF-SEC-013) | `worker/callbacks.py` → `notify` | `urllib.request.urlopen` |

> **Demo sequencing:** Beat 6 remediation task. Do not merge before both alerts have been
> shown.

### The fixes are already in the files

This is the interesting part, and it is worth showing on screen. Both modules **already
contain the correct implementation**, sitting unused next to the vulnerable one:

- `reports.py` has `safe_report_path()`, which resolves the path and checks
  `is_relative_to(root)`.
- `callbacks.py` has `ALLOWED_CALLBACK_HOSTS` and `is_allowed_callback()`.

Somebody wrote the guards and never wired them up. That is a far more common failure than
nobody knowing the fix, and it is exactly the kind of thing static analysis is good at
catching that code review misses — a reviewer sees a correct-looking helper in the diff and
does not check whether anything calls it.

### Acceptance criteria

**CF-SEC-012 — path traversal**
- [ ] `read_report` routes through `safe_report_path`.
- [ ] Traversal raises a specific exception, not a bare `ValueError`.
- [ ] Symlinks that escape the root are rejected — resolve **before** comparing.
- [ ] Absolute paths passed as `name` are rejected.

**CF-SEC-013 — SSRF**
- [ ] `notify` rejects any URL failing `is_allowed_callback`.
- [ ] Only `https` is permitted.
- [ ] The **resolved IP** is checked, not just the hostname, so
      `http://attacker.example/` resolving to `169.254.169.254` is still blocked. Blocking on
      hostname alone is the classic incomplete SSRF fix — link-local, loopback, and private
      ranges must be rejected after resolution.
- [ ] Redirects are not followed, or are re-validated at each hop.
- [ ] An explicit timeout is set.

**Both**
- [ ] Tests for each rejection case.
- [ ] CodeQL reports neither alert for these files.

### One test must be updated, deliberately

`tests/test_reports.py::test_read_report_is_still_vulnerable_to_traversal` asserts that the
traversal **works**. It is a guard test whose job is to fail loudly if someone quietly
"fixes" CF-SEC-012 and silently breaks the Beat 6 demo.

This issue is the sanctioned fix, so invert that test: assert traversal is now **rejected**,
and rename it accordingly. Changing it in this PR is correct. Changing it in any other PR is
the bug it exists to catch.
