"""Worker configuration.

CF-SEC-003: ``CONTOSO_API_KEY`` below is a planted, structurally-valid but entirely fake
credential. It matches the org-level custom secret-scanning pattern defined in
``seeds/secret-patterns.md`` and exists so the backfill scan has a historical secret to find.
It authenticates nothing. Do not remove it - see seeds/FINDINGS.md.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

# CF-SEC-003 (planted, fake) - matches the custom pattern `ctso_(live|test)_[A-Za-z0-9]{32}`.
CONTOSO_API_KEY = "ctso_live_7Qx2mVn8dRk4Tp1LzYw6Bs3Ff9Hj5Cg0"

DEFAULT_REPORT_ROOT = "/var/contoso/reports"
DEFAULT_API_BASE_URL = "http://contoso-fabric-api:8080"


@dataclass(frozen=True)
class WorkerSettings:
    """Runtime settings, resolved from the environment with sensible container defaults."""

    api_base_url: str
    report_root: str
    service_bus_namespace: str | None
    queue_name: str
    batch_interval_seconds: float

    @staticmethod
    def from_env(env: dict[str, str] | None = None) -> WorkerSettings:
        source = env if env is not None else dict(os.environ)
        return WorkerSettings(
            api_base_url=source.get("CONTOSO_API_BASE_URL", DEFAULT_API_BASE_URL).rstrip("/"),
            report_root=source.get("CONTOSO_REPORT_ROOT", DEFAULT_REPORT_ROOT),
            service_bus_namespace=source.get("CONTOSO_SERVICEBUS_NAMESPACE"),
            queue_name=source.get("CONTOSO_QUEUE_NAME", "order-events"),
            batch_interval_seconds=float(source.get("CONTOSO_BATCH_INTERVAL", "5")),
        )
