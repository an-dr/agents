"""Run evaluation validator regression tests."""

import subprocess
import sys
from pathlib import Path


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    for test in sorted(folder.glob("test-*.py")):
        result = subprocess.run([sys.executable, str(test)], check=False)
        if result.returncode:
            sys.exit(result.returncode)
