"""Exercise every supported reply form through the public parser."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "read-answers.py"


class ReplyTests(unittest.TestCase):
    def test_replies(self) -> None:
        with tempfile.TemporaryDirectory(prefix="answers-") as temporary:
            root = Path(temporary)
            questions = root / "questions.json"
            questions.write_text(json.dumps({"questions": [
                {"id": "Q1", "question": "Storage?", "options": [{"label": "SQLite file (Recommended)"}, {"label": "In-memory map"}, {"label": "Redis"}]},
                {"id": "Q2", "question": "Refresh on?", "multiSelect": True, "options": [{"label": "File change"}, {"label": "Timer"}, {"label": "Manual command"}]},
                {"id": "Q3", "question": "Delete build/?", "kind": "confirm", "options": [{"label": "No — keep them"}, {"label": "Yes — delete them"}]},
            ]}), encoding="utf-8")
            single = root / "single.json"
            single.write_text(json.dumps({"questions": [{"id": "Q1", "kind": "confirm", "question": "Push?", "options": [{"label": "Yes — push"}, {"label": "No — stay local"}]}]}), encoding="utf-8")
            cases = (
                ("compact", questions, "1a 2bc 3b", ("answered:a", "answered:b,c", "answered:b")),
                ("commas", questions, "1a, 2b, 3a", ("answered:a", "answered:b", "answered:a")),
                ("positional", questions, "b a", ("answered:b", "answered:a", "open:")),
                ("colon-and-q", questions, "Q1: c Q3 y", ("answered:c", "open:", "answered:b")),
                ("label", questions, "1: redis 3: no", ("answered:c", "open:", "answered:a")),
                ("native-label", questions, "1: SQLite file (Recommended)", ("answered:a", "open:", "open:")),
                ("custom-text", questions, "2: only on Mondays", ("open:", "custom:", "open:")),
                ("two-for-single", questions, "1ab", ("ambiguous:", "open:", "open:")),
                ("unknown-key", questions, "1z", ("custom:", "open:", "open:")),
                ("empty", questions, "", ("open:", "open:", "open:")),
                ("single-yes", single, "yes", ("answered:a",)),
                ("single-n", single, "n", ("answered:b",)),
            )
            for name, source, reply, expected in cases:
                with self.subTest(name=name):
                    output = root / f"{name}.answers.json"
                    result = subprocess.run([sys.executable, str(SCRIPT), "--questions", str(source), "--reply", reply, "--out", str(output)], capture_output=True, text=True, check=False)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    answers = json.loads(output.read_text(encoding="utf-8"))["answers"]
                    actual = tuple(f"{answer['status']}:{','.join(answer['choices'])}" for answer in answers)
                    self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
