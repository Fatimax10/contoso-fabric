"""Batching and scheduling for order-event processing."""

from __future__ import annotations

import threading
from collections.abc import Callable
from datetime import datetime, timedelta


def next_window(now: datetime, interval_minutes: int) -> datetime:
    """Return the next wall-clock boundary at or after ``now`` for a fixed interval.

    Windows are aligned to the top of the hour, so a 15-minute interval always yields
    :00, :15, :30 or :45 regardless of when the worker started.
    """
    if interval_minutes <= 0:
        raise ValueError("interval_minutes must be positive.")
    if 60 % interval_minutes != 0:
        raise ValueError("interval_minutes must divide 60 evenly.")

    top_of_hour = now.replace(minute=0, second=0, microsecond=0)
    elapsed = (now - top_of_hour).total_seconds() / 60
    windows_passed = int(elapsed // interval_minutes) + 1

    return top_of_hour + timedelta(minutes=windows_passed * interval_minutes)


class BatchCollector:
    """Accumulates items and flushes them once ``interval_seconds`` has elapsed.

    The timer is restarted on every flush, so a slow consumer delays subsequent batches
    rather than overlapping them.
    """

    def __init__(self, interval_seconds: float, on_flush: Callable[[list[object]], None]):
        self._interval = interval_seconds
        self._on_flush = on_flush
        self._items: list[object] = []
        self._lock = threading.Lock()
        self._timer: threading.Timer | None = None

    def start(self) -> None:
        self._timer = threading.Timer(self._interval, self._tick)
        self._timer.daemon = True
        self._timer.start()

    def stop(self) -> None:
        if self._timer is not None:
            self._timer.cancel()
            self._timer = None

    def add(self, item: object) -> None:
        with self._lock:
            self._items.append(item)

    def pending(self) -> int:
        with self._lock:
            return len(self._items)

    def flush(self) -> list[object]:
        with self._lock:
            batch, self._items = self._items, []

        if batch:
            self._on_flush(batch)

        return batch

    def _tick(self) -> None:
        self.flush()
        self.start()
