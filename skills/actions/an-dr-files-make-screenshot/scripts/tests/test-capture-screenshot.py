"""Check argument validation without launching a browser or capturing a window."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


CAPTURE = Path(__file__).resolve().parents[1] / "capture-screenshot.py"


def run(*arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(CAPTURE), *arguments], capture_output=True, text=True)


def main() -> int:
    result = run("--help")
    assert result.returncode == 0, result.stderr
    for option in ("--url", "--window", "--out-file", "--method", "-Url", "-Window", "-OutFile"):
        assert option in result.stdout, option

    result = run("--window", "Code")
    assert result.returncode != 0 and "required" in result.stderr, result.stderr

    result = run("--url", "http://invalid", "--out-file", "shot.png", "--method", "Screen")
    assert result.returncode != 0 and "--method belongs to --window" in result.stderr, result.stderr

    result = run("--window", "Code", "--out-file", "shot.png", "--full-page")
    assert result.returncode != 0 and "--full-page belongs to --url" in result.stderr, result.stderr

    print("Screenshot argument checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
