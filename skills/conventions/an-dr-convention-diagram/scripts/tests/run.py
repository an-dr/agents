"""Run diagram script tests."""

import subprocess
import sys
from pathlib import Path

def main() -> int:
    return subprocess.call([sys.executable, str(Path(__file__).with_name("test-check-diagrams.py"))])

if __name__ == "__main__":
    sys.exit(main())
