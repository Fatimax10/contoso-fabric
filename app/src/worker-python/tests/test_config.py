from __future__ import annotations

from worker.config import CONTOSO_API_KEY, WorkerSettings


def test_from_env_uses_container_defaults_when_unset():
    settings = WorkerSettings.from_env({})

    assert settings.api_base_url == "http://contoso-fabric-api:8080"
    assert settings.report_root == "/var/contoso/reports"
    assert settings.queue_name == "order-events"
    assert settings.service_bus_namespace is None
    assert settings.batch_interval_seconds == 5.0


def test_from_env_reads_overrides():
    settings = WorkerSettings.from_env(
        {
            "CONTOSO_API_BASE_URL": "https://api.example.test/",
            "CONTOSO_REPORT_ROOT": "/data/reports",
            "CONTOSO_SERVICEBUS_NAMESPACE": "sb-contoso",
            "CONTOSO_QUEUE_NAME": "priority-events",
            "CONTOSO_BATCH_INTERVAL": "0.5",
        }
    )

    assert settings.api_base_url == "https://api.example.test"
    assert settings.report_root == "/data/reports"
    assert settings.service_bus_namespace == "sb-contoso"
    assert settings.queue_name == "priority-events"
    assert settings.batch_interval_seconds == 0.5


def test_from_env_strips_trailing_slash_from_base_url():
    settings = WorkerSettings.from_env({"CONTOSO_API_BASE_URL": "https://x.test///"})

    assert not settings.api_base_url.endswith("/")


def test_planted_api_key_matches_the_custom_scanning_pattern():
    """CF-SEC-003 must keep its shape or the custom secret pattern stops matching."""
    import re

    assert re.fullmatch(r"ctso_(live|test)_[A-Za-z0-9]{32}", CONTOSO_API_KEY)
