"""Install this agents clone globally: managed instruction blocks and one link per skill."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


# --- shared helpers begin ---
# Copied verbatim into install-agents.py and verify-agents.py; owner: this skill.
# Each script stays standalone, so neither imports the other.

SELF = Path(__file__).resolve()

BEGIN_MARKER = "<!-- BEGIN agents-install -->"
END_MARKER = "<!-- END agents-install -->"
BLOCK_PATTERN = re.compile(re.escape(BEGIN_MARKER) + r".*?" + re.escape(END_MARKER), re.DOTALL)


@dataclass(frozen=True)
class ToolTarget:
    """One tool's user-level instruction file and skills directory."""

    id: str
    name: str
    home: Path
    instructions: Path
    skills_dir: Path | None
    supports_import: bool


def default_agents_root() -> Path:
    """The clone holding this script: <root>/skills/<category>/<skill>/scripts/."""
    return SELF.parent.parent.parent.parent.parent


def resolve_agents_root(requested: str | None) -> Path:
    """Resolve the agents clone root, defaulting to the clone that holds this script."""
    candidate = Path(requested).expanduser() if requested else default_agents_root()
    if not candidate.exists():
        raise FileNotFoundError(f"Agents root '{candidate}' does not exist.")
    root = Path(os.path.abspath(candidate))
    for required in ("AGENTS.md", "skills"):
        if not (root / required).exists():
            raise FileNotFoundError(f"Agents root '{root}' has no '{required}'; point --agents-root at a clone of the agents repository.")
    return root


def tool_targets(only: Sequence[str] | None = None) -> list[ToolTarget]:
    """Describe the supported tools: those in `only`, else those whose home directory exists."""
    home = Path.home()
    all_targets = [
        ToolTarget("claude", "Claude Code", home / ".claude", home / ".claude" / "CLAUDE.md", home / ".claude" / "skills", True),
        ToolTarget("codex", "Codex", home / ".codex", home / ".codex" / "AGENTS.md", home / ".codex" / "skills", False),
        ToolTarget("copilot", "GitHub Copilot CLI", home / ".copilot", home / ".copilot" / "copilot-instructions.md", home / ".copilot" / "skills", False),
        ToolTarget("deepseek", "DeepSeek Harness", home / ".dsh", home / ".dsh" / "AGENTS.md", home / ".dsh" / "skills", False),
        ToolTarget("gemini", "Gemini CLI", home / ".gemini", home / ".gemini" / "GEMINI.md", None, False),
        ToolTarget("opencode", "opencode", home / ".config" / "opencode", home / ".config" / "opencode" / "AGENTS.md", None, False),
    ]
    if only:
        known = {target.id for target in all_targets}
        unknown = [name for name in only if name not in known]
        if unknown:
            raise ValueError(f"Unknown tool id(s): {', '.join(unknown)}. Known ids: {', '.join(target.id for target in all_targets)}.")
        return [target for target in all_targets if target.id in only]
    return [target for target in all_targets if target.home.exists()]


def skill_directories(agents_root: Path) -> list[Path]:
    """Every skill directory holding a SKILL.md, one level below a category folder."""
    found = (path for path in (agents_root / "skills").glob("*/*") if (path / "SKILL.md").is_file())
    return sorted(found, key=lambda path: path.name)


def build_block(agents_root: Path, supports_import: bool) -> str:
    """Build the managed instruction block for one tool."""
    policy = agents_root.as_posix() + "/AGENTS.md"
    if supports_import:
        reference = f"Base engineering policy: @{policy}"
    else:
        reference = f"Base engineering policy lives at `{policy}`. Read that file before\nstarting any task that changes files in an opted-in repository."
    return "\n".join(
        [
            BEGIN_MARKER,
            "## Global agent workflow",
            "",
            reference,
            "",
            "Engage that policy only when the current repository opts in \u2014 any of:",
            "",
            "- a root `AGENTS.md` or `CLAUDE.md` that references it;",
            "- an existing `tmp-agent-wip.json`;",
            "- the user naming a flow (Vibe, Spec, Supervised) or one of its skills.",
            "",
            "Otherwise its skills stay available on request, but do not propose a flow,",
            "create a branch, or write `tmp-agent-wip.json`.",
            END_MARKER,
        ]
    )


def read_text(path: Path) -> str:
    """Read a file as UTF-8 without dropping its BOM or its line endings."""
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return handle.read()


def write_text(path: Path, text: str) -> None:
    """Write UTF-8 without a BOM, keeping the line endings already in the text."""
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def set_managed_block(path: Path, block: str) -> str:
    """Write the managed block, replacing an existing block and leaving surrounding content alone."""
    if not path.parent.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        write_text(path, block + "\n")
        return "created"
    existing = read_text(path)
    match = BLOCK_PATTERN.search(existing)
    if match:
        if match.group(0) == block:
            return "current"
        write_text(path, BLOCK_PATTERN.sub(lambda _: block, existing, count=1))
        return "updated"
    write_text(path, existing.rstrip() + "\n\n" + block + "\n")
    return "created"


def remove_managed_block(path: Path) -> str:
    """Remove the managed block, keeping any other content."""
    if not path.exists():
        return "absent"
    existing = read_text(path)
    if not existing or not BLOCK_PATTERN.search(existing):
        return "absent"
    remainder = BLOCK_PATTERN.sub("", existing, count=1).strip()
    if remainder:
        write_text(path, remainder + "\n")
    else:
        path.unlink()
    return "removed"


def use_utf8_output() -> None:
    """Print UTF-8 whatever the console code page is; Windows cannot encode the table marks."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def link_target(path: Path) -> Path | None:
    """The target of a directory link, or None for a real directory or a missing path."""
    if not os.path.lexists(path) or not (os.path.isjunction(path) or path.is_symlink()):
        return None
    return Path(os.path.realpath(path))


def same_path(left: Path | str | None, right: Path | str | None) -> bool:
    """Compare two paths for equality, ignoring case and trailing separators."""
    if not left or not right:
        return False

    def normalise(path: Path | str) -> str:
        return os.path.normcase(os.path.abspath(str(path))).rstrip("\\/").casefold()

    return normalise(left) == normalise(right)


def create_directory_link(path: Path, target: Path) -> None:
    """Create the platform's directory link: a junction on Windows, a symbolic link elsewhere."""
    if os.name == "nt":
        command = [os.environ.get("COMSPEC", "cmd.exe"), "/c", "mklink", "/J", str(path), str(target)]
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        if result.returncode != 0:
            raise OSError(f"mklink /J failed for '{path}': {(result.stdout + result.stderr).strip()}")
        return
    path.symlink_to(target, target_is_directory=True)


def delete_directory_link(path: Path) -> None:
    """Delete the link itself, never what it points at."""
    if os.path.isjunction(path):
        os.rmdir(path)
        return
    try:
        os.unlink(path)
    except OSError:
        os.rmdir(path)


def set_directory_link(path: Path, target: Path, force: bool) -> str:
    """Point a directory link at a target; conflict when a real directory occupies the path."""
    if os.path.lexists(path):
        current = link_target(path)
        if current is not None:
            if same_path(current, target):
                return "current"
            delete_directory_link(path)
            create_directory_link(path, target)
            return "replaced"
        if not force:
            return "conflict"
        shutil.rmtree(path)
    if not path.parent.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
    create_directory_link(path, target)
    return "created"


def remove_directory_link(path: Path) -> str:
    """Delete a directory link, refusing to touch a real directory."""
    if not os.path.lexists(path):
        return "absent"
    if link_target(path) is None:
        return "not-a-link"
    delete_directory_link(path)
    return "removed"


def remove_stale_agents_link(skills_directory: Path, agents_root: Path, current: Sequence[str]) -> list[str]:
    """Delete links into the clone whose skill no longer exists; links pointing elsewhere stay."""
    if not skills_directory.exists():
        return []
    skills_root = os.path.normcase(os.path.abspath(agents_root / "skills"))
    removed = []
    for entry in sorted(skills_directory.iterdir(), key=lambda path: path.name):
        if entry.name in current:
            continue
        target = link_target(entry)
        if target is None:
            continue
        if not os.path.normcase(os.path.abspath(target)).startswith(skills_root):
            continue
        delete_directory_link(entry)
        removed.append(entry.name)
    return removed

# --- shared helpers end ---


def install(root: Path, targets: Sequence[ToolTarget], args: argparse.Namespace) -> int:
    """Write or remove the blocks and links for every target tool."""
    skills = skill_directories(root)
    conflicts: list[str] = []

    print(f"Agents root: {root}")
    print(f"Tools: {', '.join(target.name for target in targets)}")
    print()

    for tool in targets:
        print(f"## {tool.name}")

        if args.uninstall:
            print(f"  instructions  {remove_managed_block(tool.instructions)}  {tool.instructions}")
        else:
            block = build_block(root, tool.supports_import)
            print(f"  instructions  {set_managed_block(tool.instructions, block)}  {tool.instructions}")

        if args.skip_skills:
            print("  skills        skipped")
            print()
            continue
        if tool.skills_dir is None:
            print("  skills        unsupported  (no user-level skills directory for this tool)")
            print()
            continue

        counts: dict[str, int] = {}
        for skill in skills:
            link_path = tool.skills_dir / skill.name
            if args.uninstall:
                state = remove_directory_link(link_path)
            else:
                state = set_directory_link(link_path, skill, args.force)
            if state in ("conflict", "not-a-link"):
                conflicts.append(f"{tool.name}: {link_path} exists as a real directory ({state}).")
            counts[state] = counts.get(state, 0) + 1
        if not args.uninstall:
            stale = remove_stale_agents_link(tool.skills_dir, root, [skill.name for skill in skills])
            if stale:
                counts["stale-removed"] = len(stale)
                print(f"  pruned        {', '.join(stale)}")
        summary = " ".join(f"{key}={counts[key]}" for key in sorted(counts))
        print(f"  skills        {summary}  ->  {tool.skills_dir}")
        print()

    if conflicts:
        print("## Conflicts")
        for conflict in conflicts:
            print(f"  {conflict}")
        print()
        print("Resolve each conflict by hand, or re-run with --force to replace the directory.")
        return 2

    verb = "Uninstall" if args.uninstall else "Install"
    print(f"{verb} complete. Verify with:")
    print(f"  python {SELF.parent / 'verify-agents.py'}")
    return 0


def main() -> int:
    use_utf8_output()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agents-root", "-AgentsRoot", help="Clone to install from. Defaults to the clone holding this script.")
    parser.add_argument("--tools", "-Tools", nargs="+", metavar="ID", help="Limit to claude, codex, copilot, deepseek, gemini, opencode. Space- or comma-separated.")
    parser.add_argument("--skip-skills", "-SkipSkills", action="store_true", help="Write instruction blocks only, no links.")
    parser.add_argument("--force", "-Force", action="store_true", help="Replace a real directory occupying a skill link path.")
    parser.add_argument("--uninstall", "-Uninstall", action="store_true", help="Remove the managed blocks and the links.")
    args = parser.parse_args()
    tools = [name for value in (args.tools or []) for name in value.split(",") if name]
    try:
        root = resolve_agents_root(args.agents_root)
        targets = tool_targets(tools)
        if not targets:
            print("No supported tool found. Pass --tools to install for a tool whose home directory does not exist yet.", file=sys.stderr)
            return 1
        return install(root, targets, args)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
