"""Exercise check-weakening.py on saved diffs: each weakening kind, a clean diff, and a moved assertion."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-weakening.py"

WEAK = """diff --git a/src/app.ts b/src/app.ts
--- a/src/app.ts
+++ b/src/app.ts
@@ -10,0 +11,2 @@
+  // @ts-ignore
+  throw new Error("not implemented");
diff --git a/tests/test_app.py b/tests/test_app.py
--- a/tests/test_app.py
+++ b/tests/test_app.py
@@ -4,2 +4,1 @@
-    assert result == 3
-    assert result > 0
+@pytest.mark.skip(reason="flaky")
diff --git a/tests/test_old.py b/tests/test_old.py
deleted file mode 100644
--- a/tests/test_old.py
+++ /dev/null
@@ -1,1 +0,0 @@
-    assert True
"""

MOVED = """diff --git a/tests/test_app.py b/tests/test_app.py
--- a/tests/test_app.py
+++ b/tests/test_app.py
@@ -4,1 +4,1 @@
-    assert result == 3
+    assert result == 3, "sum"
"""


def check(diff: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="weakening-") as temporary:
        path = Path(temporary) / "change.diff"
        path.write_text(diff, encoding="utf-8")
        return subprocess.run([sys.executable, str(SCRIPT), "--diff-path", str(path)], capture_output=True, text=True, encoding="utf-8", check=False)


class WeakeningTests(unittest.TestCase):
    def test_flags_every_kind(self) -> None:
        result = check(WEAK)
        self.assertEqual(result.returncode, 1, result.stderr)
        for kind in ("suppression", "stub", "skipped test", "removed assertions", "deleted test file"):
            with self.subTest(kind=kind):
                self.assertIn(f"| {kind} |", result.stdout)
        self.assertIn("| suppression | `src/app.ts` | 11 |", result.stdout)

    def test_clean_and_moved_assertions_pass(self) -> None:
        for diff in ("", MOVED):
            with self.subTest(diff=diff[:20]):
                result = check(diff)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("No weakening", result.stdout)


if __name__ == "__main__":
    unittest.main()
