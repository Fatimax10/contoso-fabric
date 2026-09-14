"""Report file access.

CF-SEC-012: :func:`read_report` joins caller-supplied input straight onto the report root with
no canonicalisation, so ``../../etc/passwd`` escapes the directory. This is planted so CodeQL
raises ``py/path-injection``. Do not fix it unless the task asks - see seeds/FINDINGS.md.
"""

from __future__ import annotations

import os
from pathlib import Path

from worker.config import DEFAULT_REPORT_ROOT


def read_report(name: str, report_root: str = DEFAULT_REPORT_ROOT) -> str:
    """Return the contents of a generated report by file name."""
    # CF-SEC-012: no traversal check on `name`.
    path = os.path.join(report_root, name)
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def list_reports(report_root: str = DEFAULT_REPORT_ROOT) -> list[str]:
    """Return the names of every report currently on disk, newest first."""
    root = Path(report_root)
    if not root.is_dir():
        return []

    entries = [p for p in root.iterdir() if p.is_file()]
    entries.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return [p.name for p in entries]


def safe_report_path(name: str, report_root: str = DEFAULT_REPORT_ROOT) -> Path:
    """Resolve ``name`` inside ``report_root``, rejecting anything that escapes it.

    This is the correct implementation, kept here as the reference the remediation task
    should converge on. :func:`read_report` deliberately does not use it yet.
    """
    root = Path(report_root).resolve()
    candidate = (root / name).resolve()

    if not candidate.is_relative_to(root):
        raise ValueError(f"Report name {name!r} escapes the report root.")

    return candidate
