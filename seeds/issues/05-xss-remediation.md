---
title: "Security: sanitise the fulfilment note on the order detail page (CF-SEC-011)"
labels: "security,codeql,remediation,frontend"
---

CodeQL raises `js/xss` against `app/src/web-next/src/app/orders/[id]/page.tsx`. The `note`
query parameter is written into the DOM through `dangerouslySetInnerHTML` with no escaping:

```
/orders/1001?note=<img src=x onerror=alert(document.cookie)>
```

> **Demo sequencing:** Beat 6 remediation task. Do not merge before the alert has been shown.

### Why this one is worth dwelling on

React escapes interpolated content by default, so this bug cannot happen by accident — a
developer had to reach for the API whose name literally contains the word "dangerously". It
got through because the requirement was "warehouse staff need to bold things in fulfilment
notes", and rendering HTML is the shortest path to that.

That is the realistic shape of most XSS: not ignorance, but a formatting requirement met the
quickest way.

### Acceptance criteria

Pick **one** and justify it in the PR description:

**Option A — render as plain text (preferred if formatting is not truly required).**
- [ ] Replace `dangerouslySetInnerHTML` with `{note}` and let React escape it.
- [ ] Preserve line breaks with CSS (`white-space: pre-wrap`), not with `<br>` injection.

**Option B — allow a narrow subset of formatting.**
- [ ] Sanitise with a maintained library configured as an **allow-list**, not a deny-list.
- [ ] Permit only `b`, `i`, `em`, `strong`, `br`, `p`. No attributes at all — no `href`,
      no `style`, no `class`.
- [ ] Sanitise on the **server**, before the value reaches the client.

Either way:
- [ ] A test proving `<img src=x onerror=...>` is neutralised.
- [ ] A test proving `javascript:` URLs cannot be introduced.
- [ ] CodeQL no longer reports `js/xss` for this file.

### Do not

Do not write your own regex-based HTML sanitiser. It will be wrong, and every reviewer who
has seen this go badly will say so. If Option B is chosen, use a maintained library.
