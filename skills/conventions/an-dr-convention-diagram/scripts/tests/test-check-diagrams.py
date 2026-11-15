"""Regression cases for diagram budget measurement."""

import subprocess
import sys
import tempfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-diagrams.py"
CASES = [
    ("small-flow", ["flowchart TD", "A[Start] --> B[Do]", "B --> C[End]"], 0, ""),
    ("decision-outcomes-free", ["flowchart TD", "S([Task]) --> A{Design first?}", "A -- no --> V[Vibe]", "A -- yes --> C{Each increment?}", "C -- no --> D[Spec]", "C -- yes --> E[Supervised]"], 0, ""),
    ("too-many-items", ["flowchart TD", "A --> B", "B --> C", "C --> D", "D --> E", "E --> F", "F --> G", "G --> H"], 1, "items 8 > 7"),
    ("nested-group", ["stateDiagram-v2", "[*] --> A", "state A {", "B --> C", "}"], 1, "levels 2 > 1"),
    ("two-loops", ["stateDiagram-v2", "A --> B", "B --> A", "B --> C", "C --> A"], 1, "loops 2 > 1"),
    ("long-label", ["flowchart TD", "A -->|draft PR marked ready| B"], 1, "label 'draft PR marked ready'"),
    ("long-row", ["flowchart LR", "A --> B", "B --> C", "C --> D", "D --> E"], 1, "left-to-right with 5 nodes"),
    ("exempt", ["flowchart LR", "%% diagram-budget: exempt generated graph", "A --> B --> C --> D --> E --> F --> G --> H"], 0, "1 exempt"),
    ("other-type", ["sequenceDiagram", "A->>B: hi"], 0, "1 of other types not measured"),
]

def main() -> int:
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for name, body, expected_code, expected_text in CASES:
            file = root / f"{name}.md"
            file.write_text("# Case\n\n```mermaid\n" + "\n".join(body) + "\n```\n", encoding="utf-8")
            result = subprocess.run([sys.executable, str(CHECKER), "--path", str(file)], capture_output=True, text=True)
            output = result.stdout + result.stderr
            assert result.returncode == expected_code and expected_text in output, f"{name}: {output}"
        file = root / "page.html"
        file.write_text('<pre class="mermaid">flowchart LR\nA --&gt; B\nB --&gt; C\nC --&gt; D\nD --&gt; E</pre>', encoding="utf-8")
        result = subprocess.run([sys.executable, str(CHECKER), "--path", str(file)], capture_output=True, text=True)
        assert result.returncode == 1 and "left-to-right with 5 nodes" in result.stdout, result.stdout + result.stderr
    print("Diagram checks passed (10 cases).")
    return 0

if __name__ == "__main__":
    sys.exit(main())
