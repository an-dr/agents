# Problem levels

This skill is the HTML implementor of `an-dr-concept-dark-cockpit`, which owns the ladder and its rules.

- Each finding carries one level class on its badge (`ck-badge`), its block (`ck-item`), or its table row.
- `embed-cockpit.ps1` inlines the stylesheet and does nothing without a `ck-` class, so every page renders the same way.

| Level      | Class         | Look                                      |
| ---------- | ------------- | ----------------------------------------- |
| `critical` | `ck-critical` | red, filled badge, tinted background, `✖` |
| `high`     | `ck-high`     | amber, solid edge, `▲`                    |
| `notice`   | `ck-notice`   | full ink, no hue, dashed edge, `◆`        |
| `info`     | `ck-info`     | secondary ink, no edge                    |
| `ok`       | `ck-ok`       | low-contrast grey, no hue, no edge        |

- `ok` items collapse into a closed `<details class="ck-quiet">`.
- Normal content sits on an off-white page, never pure white; only lit `notice` and `high` items lift to the white `--ck-lift` surface; `critical` keeps its red tint. Dark themes: the lift is the lightest panel.
- The script is idempotent and places `assets/dark-cockpit.css` before the page's styles; it owns light and dark palettes. Page styles may use `--ck-*` tokens but define no level colour.

## Branded reports

When the reader asks for a branded report, the brand is the neutral layer:

- Brand colours replace neutral chrome: headings, rules, layout. A desaturated brand tint may carry `ok` and `info`; the brand accent may carry `notice`.
- `high` and `critical` never take a brand colour.
- A red or orange brand stays in the chrome: its accent does not carry `notice`, and inside a finding colours only underlined links, never a fill, edge, or badge. `critical` stays red, told apart by filled badge, tint, and glyph.
- Branding defines `--brand-ok`, `--brand-info`, `--brand-notice`; the stylesheet reads them in place of its greys in either embedding order. `assets/brand.css` defines them for every report.
- Alarm tokens have no brand input; a page never overrides a `--ck-high*` or `--ck-critical*` token.
