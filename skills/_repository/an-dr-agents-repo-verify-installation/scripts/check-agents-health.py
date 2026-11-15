"""Diagnose why an agent is not following the policy in a given repository.

Layer 1 (machine) is delegated to an-dr-agents-repo-install's verify-agents.py, which
already owns the managed blocks and junctions. Layer 2 (repository) is checked
here: whether this repository reaches the policy at all, by submodule or by a
root instruction file, and whether an opt-in trigger is present. Layer 3 --
whether a bot actually loaded what is wired -- cannot be observed from disk
and is left to the skill's own procedure.

Prints a Markdown result table and exits non-zero when any check fails.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


POLICY_REFERENCE = re.compile(r"agents[\\/]AGENTS\.md")
COMMIT_SCOPES = re.compile(r"(?m)^##\s+Commit scopes\s*$")
STATUS_GLYPH = re.compile(r"[^a-z]")
RANK = {"fail": 0, "warn": 1, "info": 2, "pass": 3}
MARK = {"fail": "▲ **fail**", "warn": "◆ warn", "info": "info", "pass": "pass"}


class Results:
    def __init__(self) -> None:
        self.rows: list[dict[str, str]] = []

    def add(self, scope: str, check: str, status: str, detail: str = "") -> None:
        self.rows.append({"Scope": scope, "Check": check, "Status": status, "Detail": detail})

    def count(self, scope_prefix: str, status: str) -> int:
        return sum(1 for row in self.rows if row["Scope"].startswith(scope_prefix) and row["Status"] == status)

    def has(self, scope: str, check: str, status: str) -> bool:
        return any(row["Scope"] == scope and row["Check"] == check and row["Status"] == status for row in self.rows)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return ""


def skill_count(folder: Path) -> int:
    if not folder.is_dir():
        return 0
    return sum(
        1
        for category in folder.iterdir()
        if category.is_dir()
        for skill in category.iterdir()
        if skill.is_dir() and (skill / "SKILL.md").is_file()
    )


def use_utf8_output() -> None:
    """Print UTF-8 whatever the console code page is; Windows cannot encode the table marks."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def read_workflow(wip_script: Path, repo: Path, field: str) -> object:
    result = subprocess.run(
        [
            sys.executable,
            str(wip_script),
            "get",
            "--section",
            "workflow",
            "--field",
            field,
            "--reader",
            "an-dr-agents-repo-verify-installation",
            "--root",
            str(repo),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "wip.py get failed")
    return json.loads(result.stdout)


def repository_layer(results: Results, repo: Path) -> tuple[Path, bool, bool, list[Path]]:
    """Fill the repository rows and return what the verdict needs."""
    git_root = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if git_root.returncode == 0 and git_root.stdout.strip():
        top = os.path.abspath(git_root.stdout.strip().replace("/", os.sep)).rstrip("\\/")
        if os.path.normcase(top) != os.path.normcase(str(repo)):
            # Instruction files are read from the repository root, not the subdirectory.
            results.add("repo", "root", "info", f"checking repository root {top} (invoked from {repo})")
            repo = Path(top)
        else:
            results.add("repo", "root", "info", str(repo))
    else:
        results.add("repo", "root", "warn", f"{repo} is not a git repository; a flow cannot branch or commit here")

    # The agents clone is its own policy: it needs no reference and no submodule.
    is_agents_clone = (repo / "AGENTS.md").is_file() and (
        repo / "skills/_repository/an-dr-agents-repo-install/SKILL.md"
    ).is_file()

    root_instructions = [repo / name for name in ("AGENTS.md", "CLAUDE.md") if (repo / name).is_file()]
    has_submodule_policy = (repo / "agents/AGENTS.md").is_file()

    # A reference is any mention of the policy file, by submodule path or absolute path.
    referencing_files = []
    for file in root_instructions:
        content = read_text(file)
        if not content:
            continue
        if POLICY_REFERENCE.search(content):
            referencing_files.append(file.name)

    if is_agents_clone:
        results.add("repo", "instructions", "pass", "this is the agents clone; its own AGENTS.md is the policy")
    elif not root_instructions:
        results.add(
            "repo", "instructions", "fail", "no root AGENTS.md or CLAUDE.md; nothing tells a tool this repository opts in"
        )
    elif not referencing_files:
        names = ", ".join(file.name for file in root_instructions)
        results.add("repo", "instructions", "fail", f"{names} exist but none references agents/AGENTS.md")
    else:
        results.add("repo", "instructions", "pass", f"{', '.join(referencing_files)} reference the policy")

    # Claude Code reads CLAUDE.md; the other tools read AGENTS.md. One without the
    # other is the classic "works in one tool, ignored in another" case.
    has_agents_md = (repo / "AGENTS.md").is_file()
    has_claude_md = (repo / "CLAUDE.md").is_file()
    if is_agents_clone:
        # Nothing embeds the clone, so it needs no per-tool instruction file of its own.
        pass
    elif has_agents_md and not has_claude_md:
        results.add(
            "repo", "per-tool", "warn",
            "AGENTS.md only; Claude Code reads CLAUDE.md and will not see it from the repository",
        )
    elif has_claude_md and not has_agents_md:
        results.add(
            "repo", "per-tool", "warn",
            "CLAUDE.md only; Codex, Copilot, opencode, and DeepSeek Harness read AGENTS.md and will not see it from the repository",
        )
    elif has_agents_md and has_claude_md:
        results.add("repo", "per-tool", "pass", "AGENTS.md and CLAUDE.md both present")

    if is_agents_clone:
        own_skills = skill_count(repo / "skills")
        results.add("repo", "policy", "pass", f"the clone's own AGENTS.md, {own_skills} skills")
    elif has_submodule_policy:
        count = skill_count(repo / "agents/skills")
        if count > 0:
            results.add("repo", "policy", "pass", f"agents/AGENTS.md present, {count} skills")
        else:
            results.add("repo", "policy", "fail", "agents/AGENTS.md present but agents/skills holds no SKILL.md")
    elif (repo / "agents").exists():
        # An uninitialised submodule is an empty directory: the reference dangles.
        results.add(
            "repo", "policy", "fail", "agents/ exists but has no AGENTS.md; run git submodule update --init --recursive"
        )
    elif referencing_files:
        results.add(
            "repo", "policy", "fail", "root instructions reference agents/AGENTS.md but no agents/ directory exists"
        )
    else:
        results.add("repo", "policy", "info", "no agents/ submodule; the policy must come from a global install")

    # --- Commit scopes, which an-dr-git-modify-history's checker requires ---
    if root_instructions:
        scope_source = [file for file in root_instructions if COMMIT_SCOPES.search(read_text(file))]
        if scope_source:
            names = ", ".join(file.name for file in scope_source)
            results.add("repo", "commit-scopes", "pass", f"declared in {names}")
        else:
            results.add(
                "repo", "commit-scopes", "warn",
                'no "## Commit scopes" section; an-dr-git-modify-history will reject every scoped subject',
            )

    return repo, is_agents_clone, has_submodule_policy, referencing_files


def workflow_layer(results: Results, wip_script: Path, repo: Path) -> bool:
    flow = None
    try:
        flow = read_workflow(wip_script, repo, "flow")
    except (RuntimeError, ValueError, OSError):
        flow = None
    if flow:
        phase = None
        try:
            phase = read_workflow(wip_script, repo, "phase")
        except (RuntimeError, ValueError, OSError):
            phase = None
        results.add(
            "repo", "workflow-state", "pass",
            f"tmp-agent-wip.json holds a workflow ({flow} at {phase}); this repository opts in on its own",
        )
        return True
    results.add("repo", "workflow-state", "info", "no workflow in tmp-agent-wip.json; no flow in progress")
    return False


def install_layer(results: Results, agents_root: Path | None, tools: list[str], skip: bool) -> None:
    if skip:
        results.add("install", "verify", "info", "skipped by -SkipInstallCheck")
        return
    verify = Path(__file__).resolve().parents[2] / "an-dr-agents-repo-install/scripts/verify-agents.py"
    if not verify.is_file():
        results.add(
            "install", "verify", "warn",
            "an-dr-agents-repo-install/scripts/verify-agents.py not found next to this skill",
        )
        return
    command = [sys.executable, str(verify)]
    if agents_root:
        command += ["--agents-root", str(agents_root)]
    if tools:
        command += ["--tools", *tools]
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
    except OSError as error:
        raise RuntimeError(f"the install verifier could not run: {error}") from error

    # Re-emit the verifier's own rows so one table answers the whole question.
    for line in f"{result.stdout}\n{result.stderr}".splitlines():
        text = line.strip()
        if not text.startswith("|"):
            continue
        if re.match(r"^\|\s*Scope\s*\|", text) or re.match(r"^\|\s*-{2,}", text):
            continue
        cells = text.strip("|").split("|")
        if len(cells) < 4:
            continue
        # The verifier marks problem statuses with a glyph and bold; keep the word alone.
        status = STATUS_GLYPH.sub("", cells[2])
        if status not in ("pass", "fail", "warn", "info"):
            status = "info"
        results.add(f"install/{cells[0].strip()}", cells[1].strip(), status, cells[3].strip())

    if result.returncode and not results.count("install/", "fail"):
        results.add("install", "verify", "fail", "verify-agents.py exited non-zero; run it directly for the reason")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repository-path", "-RepositoryPath", type=Path, default=Path.cwd())
    parser.add_argument("--agents-root", "-AgentsRoot", type=Path)
    parser.add_argument("--tools", "-Tools", nargs="+")
    parser.add_argument("--skip-install-check", "-SkipInstallCheck", action="store_true")
    # an-dr-ai-use-wip-data's folder: the live workflow state is read through it.
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, type=Path)
    args = parser.parse_args()

    use_utf8_output()
    if not args.repository_path.exists():
        print(f"Repository path '{args.repository_path}' does not exist.", file=sys.stderr)
        return 1
    wip_script = args.wip_data_skill / "scripts/wip.py"
    if not wip_script.is_file():
        print(f"--wip-data-skill '{args.wip_data_skill}' has no scripts/wip.py.", file=sys.stderr)
        return 1
    repo = Path(os.path.abspath(str(args.repository_path)))
    tools = [item for value in args.tools or [] for item in value.split(",")]
    if args.agents_root:
        args.agents_root = args.agents_root.resolve()

    results = Results()
    repo, is_agents_clone, has_submodule_policy, referencing_files = repository_layer(results, repo)
    has_workflow_state = workflow_layer(results, wip_script, repo)
    try:
        install_layer(results, args.agents_root, tools, args.skip_install_check)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1

    install_broken = results.count("install/", "fail") > 0
    repo_policy_broken = results.has("repo", "policy", "fail")
    # A repository that names its own policy is not rescued by the global install:
    # the tool follows the nearer reference, and a dangling one silences everything.
    if is_agents_clone or has_submodule_policy:
        policy_reachable = True
    elif repo_policy_broken:
        policy_reachable = False
    else:
        policy_reachable = not install_broken
    opted_in = is_agents_clone or bool(referencing_files) or has_workflow_state

    if opted_in and policy_reachable:
        results.add(
            "verdict", "pickup", "pass",
            "wiring is correct; if the agent still ignores the policy the cause is pickup, not installation",
        )
    elif not opted_in:
        # Silence here is the guard working, not a fault; it is a fault only if the
        # user expected this repository to be opted in.
        results.add(
            "verdict", "pickup", "info",
            "this repository does not opt in, so the policy is deliberately silent here; wire it only if it should be governed",
        )
    else:
        results.add(
            "verdict", "pickup", "fail",
            "this repository opts in but the policy it points at does not resolve; the agent sees a dangling reference and ignores it",
        )

    # Finding levels (an-dr-ai-use-user-interface): problems first and marked, passing rows plain and last.
    print("| Scope | Check | Status | Detail |")
    print("| --- | --- | --- | --- |")
    for row in sorted(results.rows, key=lambda item: RANK[item["Status"]]):
        print(f"| {row['Scope']} | {row['Check']} | {MARK[row['Status']]} | {row['Detail']} |")
    print()

    failed = sum(1 for row in results.rows if row["Status"] == "fail")
    warned = sum(1 for row in results.rows if row["Status"] == "warn")
    if failed:
        print(f"{failed} check(s) failed, {warned} warning(s).")
        return 1
    print(f"All checks passed, {warned} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
