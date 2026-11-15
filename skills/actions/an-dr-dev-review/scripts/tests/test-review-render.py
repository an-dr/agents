"""Check the review page's escaping, note numbering, and section shape."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
RENDER = runpy.run_path(str(SCRIPTS / "review-render.py"))
NOTE = runpy.run_path(str(SCRIPTS / "review-note.py"))


class ReviewHtmlTests(unittest.TestCase):
    def test_escaping_follows_the_page_contract(self) -> None:
        encode = RENDER["html_encode"]
        self.assertEqual(encode('<a href="x">&</a>'), "&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;")
        self.assertEqual(encode("it's"), "it&#39;s")
        # Latin-1 becomes a decimal entity, while text above it stays literal.
        self.assertEqual(encode("é — →"), "&#233; — →")
        self.assertEqual(encode("\U0001F600"), "&#128512;")

    def test_note_text_collapses_lines_and_marks_code(self) -> None:
        to_html = RENDER["convert_to_review_html"]
        self.assertEqual(to_html("  one\r\n\ntwo  "), "one two")
        self.assertEqual(to_html("the `value` is <kept>"), "the <code>value</code> is &lt;kept&gt;")

    def test_finding_section_marks_an_empty_section(self) -> None:
        section = RENDER["finding_section_html"]("High", "ck-high", [])
        self.assertEqual(section, ["<section><h2>High</h2>", '<p class="ck-quiet">None.</p>', "</section>"])

    def test_finding_section_carries_location_and_diagram(self) -> None:
        note = {
            "id": "CR.1",
            "file": "src/a&b.py",
            "line": 7,
            "text": "Breaks.",
            "recommendation": "Fix it.",
            "addedAt": "2026-11-15T20:00:00.0000000Z",
            "diagram": "flowchart LR\n  A --> B",
        }
        section = RENDER["finding_section_html"]("Critical", "ck-critical", [note])
        self.assertEqual(section[1], '<article class="finding ck-item ck-critical" id="CR.1">')
        self.assertEqual(
            section[2],
            '<div class="head"><span class="ck-badge ck-critical">CR.1</span>'
            '<span class="loc">src/a&amp;b.py:7</span></div>',
        )
        self.assertEqual(section[4], '<div class="diagram"><pre class="mermaid">flowchart LR\n  A --&gt; B</pre></div>')

    def test_next_note_id_takes_the_highest_number(self) -> None:
        next_id = NOTE["get_next_note_id"]
        self.assertEqual(next_id([], "CR"), "CR.1")
        self.assertEqual(next_id([{"id": "CR.1"}, {"id": "CR.3"}, {"id": "HI.9"}], "CR"), "CR.4")
        self.assertEqual(next_id([{"id": "CR.x"}], "CR"), "CR.1")


if __name__ == "__main__":
    unittest.main()
