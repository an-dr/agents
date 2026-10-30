---
name: docs-screenshot
description: Capture a screenshot of a website or a running GUI application or game and store it as repository documentation media. Use when a README or document needs an image of visible output, or when the user asks for a screenshot of a page, app, or game.
---

# Screenshot

A screenshot is repository content: it lands in the host repository next to the document that shows it and is committed with it. Scratch captures taken only to check something go to the `screenshots` directory `artifact-storage` gives you instead.

## Where the image goes

Store documentation media in `docs/media/`, named for what it shows in kebab case, such as `main-window.png` or `level-editor.png`. If the repository already keeps images somewhere else, use that directory. Reference the image with a relative link and alt text that says what the reader sees, not "screenshot".

## Prepare the subject

The capture shows the project at its best realistic use, not an empty state or a first-run dialog:

- start the project from the command its README or manifest names; never invent a launch command;
- load realistic sample data, an example scene, or a demo level the repository ships, and say so when none exists;
- remove personal data — user names, paths under a home directory, tokens, e-mail addresses — before capturing;
- size the window or viewport to 1280×720 unless the subject needs another shape, so captures across a document match.

## Capture

```powershell
pwsh <skill>/scripts/capture-screenshot.ps1 -Url <url> -OutFile docs/media/<name>.png [-Width 1280] [-Height 720] [-FullPage]
pwsh <skill>/scripts/capture-screenshot.ps1 -Window <process-or-title> -OutFile docs/media/<name>.png [-Method Screen|Print]
```

- `-Url` drives headless Chromium through Playwright, so a local development server works as well as a public site. The script stops with the install command when Node.js or the Playwright browser is missing.
- `-Window` captures one top-level window on Windows by process name or a substring of its title. `Screen` (default) brings the window forward and copies its pixels from the screen, which works for games and hardware-accelerated apps; `Print` asks the window to draw itself and works while it is covered, but can come out black for DirectX or OpenGL output.
- On macOS and Linux the script names the native command to use instead.

When the Claude in Chrome tools are available and the page needs a signed-in session, interact with it there, then capture with the script against the same URL only if it needs no session; otherwise ask the user for the capture.

## Check

Open the saved image and look at it before linking it. Recapture when it shows a loading spinner, a cropped window, a black frame, personal data, or a different state than the text around it describes. Keep each image under about 500 KB; prefer PNG for interfaces and JPEG only for photographic game scenes.

Report the path of every image written and what it shows.
