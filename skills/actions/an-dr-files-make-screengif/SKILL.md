---
name: an-dr-files-make-screengif
description: Record a short animated GIF of a website, GUI application, or game in action and store it as repository documentation media. Use only when the user explicitly asks for a GIF or an animation; a still image comes from an-dr-files-make-screenshot.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-files-make-screenshot
---

# GIF

Defers: storage, naming, subject preparation, and personal data to `an-dr-files-make-screenshot`.

## Decide

- Record only on the user's request; a GIF costs megabytes in every clone and page load.
- Default for visible output → screenshot from `an-dr-files-make-screenshot`.
- Still image cannot show the point (interaction, animation, gameplay) → offer a GIF and wait for the request.
- Output file: `docs/media/<name>.gif`, committed with the document that shows it.

## Plan the clip

- Write down the starting state, each action, and the end state before recording.
- One clip, one idea, 3 to 10 seconds.
- Start and end on a still frame that reads on its own; many viewers see only the first frame or a loop.

## Record

```sh
python <skill>/scripts/record-gif.py --window <title> --out-file docs/media/<name>.gif [--seconds 8] [--fps 12] [--width 800]
python <skill>/scripts/record-gif.py --video <recording.mp4> --out-file docs/media/<name>.gif [--start 2] [--seconds 8] [--fps 12] [--width 800]
```

- `--window`: records one window on Windows by exact title through ffmpeg after a countdown, while you or the user perform the planned actions.
- `--video`: converts an existing recording (browser, game capture, OS recorder), trimmed with `--start` and `--seconds`.
- Both use ffmpeg's two-pass palette; missing ffmpeg → the script stops with the install command.
- Website → Claude in Chrome `gif_creator` records directly; pass its export through `--video` only to trim or resize.

## Check

- Watch the GIF loop.
- Re-record when it starts mid-action, shows a purposeless wandering cursor, drops frames at the key moment, or exceeds about 5 MB; lower `--fps` or `--width` first.

## Output

- Path, duration, and size of every file written.
