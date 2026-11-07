# Visual check

## Views

Four screenshots of the actual page after the final build: light and dark themes, each at desktop width and at a 390 CSS-pixel phone viewport.

- Open every screenshot and inspect text, tables, diagrams, and controls.
- Saving an image, parsing HTML, or measuring overflow is not an inspection.

## Viewport width

- A narrow headless Chrome window can keep a wider viewport and crop its screenshot; check the browser's actual viewport width.
- Use device emulation, or a fixed-width 390-pixel iframe inside a wider window.
- Record the inner viewport and document widths.

## Record

Kept with the report:

- final HTML hash;
- screenshot paths, with theme and viewport of each;
- which screenshots were opened;
- issues seen.

## Result

- Complete: all four views inspected and no layout defect remains.
- Blocked: no browser or image viewer; deliver the report with visual verification marked blocked and name the missing check.
- The renderer's success or a later reviewer's look does not replace the check.
