"""Run GIF script tests."""

import subprocess
import sys
from pathlib import Path


if __name__ == "__main__":
    sys.exit(subprocess.call([sys.executable, str(Path(__file__).with_name("test-record-gif.py"))]))
