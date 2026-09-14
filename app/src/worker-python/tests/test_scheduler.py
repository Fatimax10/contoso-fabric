from __future__ import annotations

from datetime import datetime

import pytest

from worker.scheduler import BatchCollector, next_window


@pytest.mark.parametrize(
    ("now", "interval", "expected"),
    [
        (datetime(2026, 8, 26, 9, 0, 0), 15, datetime(2026, 8, 26, 9, 15, 0)),
        (datetime(2026, 8, 26, 9, 7, 30), 15, datetime(2026, 8, 26, 9, 15, 0)),
        (datetime(2026, 8, 26, 9, 14, 59), 15, datetime(2026, 8, 26, 9, 15, 0)),
        (datetime(2026, 8, 26, 9, 15, 0), 15, datetime(2026, 8, 26, 9, 30, 0)),
        (datetime(2026, 8, 26, 9, 59, 59), 15, datetime(2026, 8, 26, 10, 0, 0)),
        (datetime(2026, 8, 26, 23, 58, 0), 5, datetime(2026, 8, 27, 0, 0, 0)),
    ],
)
def test_next_window_aligns_to_the_hour(now, interval, expected):
    assert next_window(now, interval) == expected


@pytest.mark.parametrize("interval", [0, -5])
def test_next_window_rejects_non_positive_intervals(interval):
    with pytest.raises(ValueError, match="must be positive"):
        next_window(datetime(2026, 8, 26, 9, 0, 0), interval)


@pytest.mark.parametrize("interval", [7, 45, 90])
def test_next_window_rejects_intervals_that_do_not_divide_an_hour(interval):
    with pytest.raises(ValueError, match="divide 60"):
        next_window(datetime(2026, 8, 26, 9, 0, 0), interval)


def test_flush_returns_and_clears_pending_items():
    flushed: list[list[object]] = []
    collector = BatchCollector(interval_seconds=60, on_flush=flushed.append)

    collector.add("a")
    collector.add("b")
    assert collector.pending() == 2

    batch = collector.flush()

    assert batch == ["a", "b"]
    assert collector.pending() == 0
    assert flushed == [["a", "b"]]


def test_flush_with_no_items_does_not_invoke_the_callback():
    flushed: list[list[object]] = []
    collector = BatchCollector(interval_seconds=60, on_flush=flushed.append)

    assert collector.flush() == []
    assert flushed == []


@pytest.mark.flaky
def test_timer_flushes_the_batch_before_the_deadline():
    """CF-QUA-050: intermittently failing on purpose - this is the Beat 11 incident.

    The test thread and the collector's timer thread wait for almost the same duration: the
    test allows a 3 ms grace period, which is far smaller than the ~15 ms timer granularity
    on Windows. Which thread wins is therefore decided by the OS scheduler. That is a genuine
    race, not a seeded coin flip.

    Measured locally at roughly 1 failure in 6 runs, and it fails more often on a loaded CI
    runner - which is precisely what makes a real flaky test so expensive to chase down: it
    is green on the developer's laptop and red in the pipeline.

    Deselected locally by the `-m 'not flaky'` default in pyproject.toml; CI opts back in.
    """
    import time

    deadline_seconds = 0.05
    grace_seconds = 0.003

    flushed: list[list[object]] = []
    collector = BatchCollector(interval_seconds=deadline_seconds, on_flush=flushed.append)
    collector.add("event")
    collector.start()

    time.sleep(deadline_seconds + grace_seconds)
    collector.stop()

    assert flushed == [["event"]]
