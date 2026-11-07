---
name: an-dr-files-make-screengif
description: Record a short animated GIF of a website, GUI application, or game in action and store it as repository documentation media. Use only when the user explicitly asks for a GIF or an animation; a still image comes from an-dr-files-make-screenshot.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
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

```powershell
pwsh <skill>/scripts/record-gif.ps1 -Window <title> -OutFile docs/media/<name>.gif [-Seconds 8] [-Fps 12] [-Width 800]
pwsh <skill>/scripts/record-gif.ps1 -Video <recording.mp4> -OutFile docs/media/<name>.gif [-Start 2] [-Seconds 8] [-Fps 12] [-Width 800]
```

- `-Window`: records one window on Windows by exact title through ffmpeg after a countdown, while you or the user perform the planned actions.
- `-Video`: converts an existing recording (browser, game capture, OS recorder), trimmed with `-Start` and `-Seconds`.
- Both use ffmpeg's two-pass palette; missing ffmpeg → the script stops with the install command.
- Website → Claude in Chrome `gif_creator` records directly; pass its export through `-Video` only to trim or resize.

## Check

- Watch the GIF loop.
- Re-record when it starts mid-action, shows a purposeless wandering cursor, drops frames at the key moment, or exceeds about 5 MB; lower `-Fps` or `-Width` first.

## Output

- Path, duration, and size of every file written.
