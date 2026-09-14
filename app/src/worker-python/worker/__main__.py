"""Worker entry point.

The ``sys.argv`` values below are the taint sources that let CodeQL trace CF-SEC-012
(path injection) and CF-SEC-013 (SSRF) through to their sinks. See seeds/FINDINGS.md.
"""

from __future__ import annotations

import sys

from worker.callbacks import notify
from worker.config import WorkerSettings
from worker.reports import read_report


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)

    if len(args) < 2:
        print("usage: python -m worker <report-name> <callback-url>", file=sys.stderr)
        return 2

    report_name, callback_url = args[0], args[1]
    settings = WorkerSettings.from_env()

    # CF-SEC-012: `report_name` reaches the filesystem without canonicalisation.
    contents = read_report(report_name, settings.report_root)

    # CF-SEC-013: `callback_url` reaches urlopen without an allow-list check.
    status = notify(callback_url, {"report": report_name, "bytes": len(contents)})

    print(f"delivered {report_name} ({len(contents)} bytes) -> HTTP {status}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
