from __future__ import annotations

import pytest

from worker.reports import list_reports, read_report, safe_report_path


@pytest.fixture()
def report_root(tmp_path):
    (tmp_path / "daily-2026-08-01.csv").write_text("id,total\n1,10.00\n", encoding="utf-8")
    (tmp_path / "daily-2026-08-02.csv").write_text("id,total\n2,20.00\n", encoding="utf-8")
    return tmp_path


def test_read_report_returns_file_contents(report_root):
    contents = read_report("daily-2026-08-01.csv", str(report_root))

    assert contents.startswith("id,total")


def test_read_report_missing_file_raises(report_root):
    with pytest.raises(FileNotFoundError):
        read_report("nope.csv", str(report_root))


def test_list_reports_returns_newest_first(report_root):
    import os
    import time

    newest = report_root / "daily-2026-08-02.csv"
    os.utime(newest, (time.time() + 10, time.time() + 10))

    assert list_reports(str(report_root))[0] == "daily-2026-08-02.csv"


def test_list_reports_missing_root_returns_empty(tmp_path):
    assert list_reports(str(tmp_path / "absent")) == []


def test_safe_report_path_allows_names_inside_the_root(report_root):
    resolved = safe_report_path("daily-2026-08-01.csv", str(report_root))

    assert resolved.parent == report_root.resolve()


@pytest.mark.parametrize(
    "name",
    ["../secrets.env", "../../etc/passwd", "nested/../../escape.txt"],
)
def test_safe_report_path_rejects_traversal(report_root, name):
    with pytest.raises(ValueError, match="escapes the report root"):
        safe_report_path(name, str(report_root))


def test_read_report_is_still_vulnerable_to_traversal(report_root, tmp_path):
    """CF-SEC-012 guard test: asserts the planted vulnerability is still present.

    If this test starts failing, someone silently "fixed" the finding and Beat 6 is broken.
    Remediate it deliberately via the CodeQL alert, and delete this test in the same PR.
    """
    outside = tmp_path.parent / "outside.txt"
    outside.write_text("escaped", encoding="utf-8")

    assert read_report(f"../{outside.name}", str(report_root)) == "escaped"
