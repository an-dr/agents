"""Run this skill's top-level Python tests in fresh processes."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests-path", "-TestsPath", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    if not args.tests_path.is_dir():
        parser.error(f"Tests folder not found: {args.tests_path}")
    tests = sorted(args.tests_path.glob("test-*.py"))
    if not tests:
        parser.error(f"No script tests found in {args.tests_path}.")
    failures = 0
    print("| Script test | Result |\n| --- | --- |")
    for test in tests:
        result = subprocess.run([sys.executable, str(test)], capture_output=True, text=True, check=False)
        failures += result.returncode != 0
        status = "pass" if result.returncode == 0 else f"FAIL (exit {result.returncode})"
        print(f"| `{test.name}` | {status} |")
        if result.returncode:
            print(f"```text\n{result.stdout}{result.stderr}```")
    print(f"{len(tests) - failures} of {len(tests)} script test(s) passed. No agent evaluations ran.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
