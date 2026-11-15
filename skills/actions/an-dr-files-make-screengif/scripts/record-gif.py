"""Record a Windows window or convert an existing video to an optimized GIF."""

import argparse
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def run(arguments: list[str]) -> None:
    result = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *arguments], check=False)
    if result.returncode:
        raise RuntimeError("ffmpeg failed to record or encode the GIF")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--window", "-Window")
    source.add_argument("--video", "-Video", type=Path)
    parser.add_argument("--out-file", "-OutFile", required=True, type=Path)
    parser.add_argument("--start", "-Start", type=float, default=0)
    parser.add_argument("--seconds", "-Seconds", type=float, default=8)
    parser.add_argument("--fps", "-Fps", type=int, default=12)
    parser.add_argument("--width", "-Width", type=int, default=800)
    parser.add_argument("--countdown", "-Countdown", type=int, default=3)
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        parser.error("ffmpeg was not found; install it before recording a GIF")
    if args.seconds <= 0 or args.fps <= 0 or args.width <= 0 or args.countdown < 0 or args.start < 0:
        parser.error("duration, frame rate, and width must be positive; start and countdown cannot be negative")
    output = args.out_file.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    filter_graph = f"fps={args.fps},scale={args.width}:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
    try:
        if args.window:
            if sys.platform != "win32":
                parser.error("window recording is available only on Windows; pass an existing recording with --video")
            with tempfile.TemporaryDirectory(prefix="record-gif-") as directory:
                raw = Path(directory) / "capture.mkv"
                for second in range(args.countdown, 0, -1):
                    print(f"Recording {args.window!r} in {second}...", flush=True)
                    time.sleep(1)
                print(f"Recording for {args.seconds} s.", flush=True)
                run(["-f", "gdigrab", "-framerate", "30", "-draw_mouse", "1", "-i", f"title={args.window}", "-t", str(args.seconds), "-c:v", "libx264rgb", "-crf", "0", "-preset", "ultrafast", str(raw)])
                run(["-i", str(raw), "-filter_complex", filter_graph, "-loop", "0", str(output)])
        else:
            if not args.video.is_file():
                parser.error(f"video does not exist: {args.video}")
            run(["-ss", str(args.start), "-t", str(args.seconds), "-i", str(args.video), "-filter_complex", filter_graph, "-loop", "0", str(output)])
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    size = round(output.stat().st_size / (1024 * 1024), 2)
    print(f"Saved {output} ({size} MB)")
    if size > 5:
        print("GIF exceeds 5 MB; lower --fps or --width, or shorten --seconds.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
