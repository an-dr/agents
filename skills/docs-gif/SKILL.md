---
name: docs-gif
description: Record a short animated GIF of a website, GUI application, or game in action and store it as repository documentation media. Use only when the user explicitly asks for a GIF or an animation; a still image comes from docs-screenshot.
metadata:
  dependencies: docs-screenshot
---

# GIF

Record a GIF only on the user's request. A GIF costs megabytes in every clone and in every page load, so a screenshot from `docs-screenshot` is the default for showing visible output. When a still image cannot show the point — an interaction, an animation, gameplay — offer a GIF and wait for the user to ask.

Storage, naming, subject preparation, and personal-data rules are those of `docs-screenshot`: the file goes to `docs/media/<name>.gif` and is committed with the document that shows it.

## Plan the clip

Write the sequence down before recording: the starting state, each action, and the end state. One clip shows one idea in 3 to 10 seconds. Start and end on a still frame that reads on its own, because many viewers see only the first frame or a loop.

## Record

```powershell
pwsh <skill>/scripts/record-gif.ps1 -Window <title> -OutFile docs/media/<name>.gif [-Seconds 8] [-Fps 12] [-Width 800]
pwsh <skill>/scripts/record-gif.ps1 -Video <recording.mp4> -OutFile docs/media/<name>.gif [-Start 2] [-Seconds 8] [-Fps 12] [-Width 800]
```

- `-Window` records one window on Windows by its exact title through ffmpeg while you or the user perform the planned actions. The script counts down before it starts.
- `-Video` converts an existing recording — from a browser, a game's own capture, or the operating system's recorder — and trims it with `-Start` and `-Seconds`.
- Both use ffmpeg's two-pass palette, which keeps interface colours clean at a fraction of the size. The script stops with the install command when ffmpeg is missing.

For a website, the Claude in Chrome `gif_creator` tool records a browser interaction directly; export its file and pass it through `-Video` only when it needs trimming or resizing.

## Check

Open the GIF and watch it loop. Re-record when it starts mid-action, shows a cursor wandering without purpose, drops frames during the key moment, or exceeds about 5 MB; lower `-Fps` or `-Width` first. Report the path, duration, and size of every file written.
