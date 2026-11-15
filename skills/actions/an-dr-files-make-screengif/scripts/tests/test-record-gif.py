"""Check argument validation without requiring ffmpeg or a display."""

import subprocess
import sys
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "record-gif.py"


def main() -> int:
    result = subprocess.run([sys.executable, str(SCRIPT), "--help"], capture_output=True, text=True)
    assert result.returncode == 0 and "--video" in result.stdout and "--window" in result.stdout
    result = subprocess.run([sys.executable, str(SCRIPT), "--out-file", "out.gif"], capture_output=True, text=True)
    assert result.returncode != 0 and "required" in result.stderr
    print("GIF argument checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
