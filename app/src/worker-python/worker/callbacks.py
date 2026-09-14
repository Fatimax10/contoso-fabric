"""Outbound completion callbacks.

CF-SEC-013: :func:`notify` fetches a caller-controlled URL with no allow-list, so the worker
can be pointed at internal endpoints such as the instance metadata service. Planted so CodeQL
raises ``py/ssrf``. See seeds/FINDINGS.md.
"""

from __future__ import annotations

import json
import urllib.request
from urllib.parse import urlparse

ALLOWED_CALLBACK_HOSTS = frozenset(
    {
        "contoso-fabric-api",
        "api.contoso-fabric.internal",
    }
)


def notify(callback_url: str, payload: dict[str, object], timeout: float = 10.0) -> int:
    """POST ``payload`` to ``callback_url`` and return the HTTP status code."""
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        callback_url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    # CF-SEC-013: `callback_url` is never validated against ALLOWED_CALLBACK_HOSTS.
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
        return response.status


def is_allowed_callback(callback_url: str) -> bool:
    """Return whether ``callback_url`` targets an approved host over HTTPS or plain HTTP.

    The correct guard, kept as the reference the remediation task should converge on.
    :func:`notify` deliberately does not call it yet.
    """
    parsed = urlparse(callback_url)

    if parsed.scheme not in ("http", "https"):
        return False

    return parsed.hostname in ALLOWED_CALLBACK_HOSTS
