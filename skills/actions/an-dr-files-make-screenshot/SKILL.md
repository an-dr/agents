---
name: an-dr-files-make-screenshot
description: Capture a screenshot of a website or a running GUI application or game and store it as repository documentation media. Use when a README or document needs an image of visible output, or when the user asks for a screenshot of a page, app, or game.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-files-build-report
---

# Screenshot

Defers: scratch captures (only to check something) to a `screenshots` path with extension `png` from `an-dr-files-build-report`.

## Place the image

- A screenshot is repository content, committed with the document that shows it.
- Store in `docs/media/`, kebab-case name for what it shows (`main-window.png`); if the repository keeps images elsewhere, use that directory.
- Link relatively, with alt text saying what the reader sees, not "screenshot".

## Prepare the subject

Show realistic use, not an empty state or first-run dialog:

- Start the project with the command its README or manifest names; never invent one.
- Load sample data, an example scene, or a demo level the repository ships; say so when none exists.
- Remove personal data (user names, home-directory paths, tokens, e-mail addresses) before capturing.
- Size the window or viewport to 1280×720 unless the subject needs another shape.

## Capture

```powershell
pwsh <skill>/scripts/capture-screenshot.ps1 -Url <url> -OutFile docs/media/<name>.png [-Width 1280] [-Height 720] [-FullPage]
pwsh <skill>/scripts/capture-screenshot.ps1 -Window <process-or-title> -OutFile docs/media/<name>.png [-Method Screen|Print]
```

- `-Url`: headless Chromium through Playwright; local dev servers work. Stops with the install command when Node.js or the Playwright browser is missing.
- `-Window`: one top-level Windows window by process name or title substring. `Screen` (default) brings it forward and copies screen pixels, works for games and hardware-accelerated apps; `Print` asks the window to draw itself, works while covered, can be black for DirectX or OpenGL.
- macOS and Linux: the script names the native command to use instead.
- Page needs a signed-in session and Claude in Chrome tools are available → interact there; capture with the script against the same URL only if it needs no session, otherwise ask the user for the capture.

## Check

- Open the saved image before linking it.
- Recapture on a loading spinner, cropped window, black frame, personal data, or a state different from the surrounding text.
- Keep each image under about 500 KB; PNG for interfaces, JPEG only for photographic game scenes.

## Output

Path of every image written and what it shows.
