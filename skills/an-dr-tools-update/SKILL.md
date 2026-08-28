---
name: an-dr-tools-update
description: Keep the user's personal tool repositories current — register them in a JSON manifest, then pull, rebuild, and reinstall each one. Use when the user wants to set up that tool list, add a repository to it, or refresh every tool they maintain locally.
allowed-tools: PowerShell
---

# Tools update

Maintains a manifest of local tool repositories and refreshes them in one pass. The script owns the manifest format and the mechanical pull–build–install loop; the agent owns everything that needs judgement — which repositories belong in the list, what each one's build and install command actually is, and what a failure means.

## Manifest

One JSON file, by default `~/.an-dr/tools.json`, overridable with `-ManifestPath` or the `AN_DR_TOOLS_MANIFEST` environment variable.

```json
{
  "schemaVersion": 1,
  "tools": [
    {
      "name": "example",
      "path": "C:/@Code/an-dr/example",
      "build": "./build.ps1",
      "install": "./install.ps1 -Destination $env:AN_DR_TOOL_INSTALL_DIR",
      "installDir": "C:/tools/example"
    }
  ]
}
```

`build`, `install`, and `installDir` are optional; an empty string means that step is skipped. Each command runs through `pwsh -NoProfile -Command` with the tool's repository as the working directory and `AN_DR_TOOL_NAME`, `AN_DR_TOOL_PATH`, and `AN_DR_TOOL_INSTALL_DIR` in the environment. The manifest therefore holds executable commands: only register repositories the user trusts, and read back any command before writing it.

Never hand-edit the manifest. Use the script so its shape and sorting stay valid.

## First run

When the manifest does not exist, create it and then interview the user for its contents. Ask for the repositories one at a time — the path, and whether it needs a build step, an install step, and an install directory. Inspect each repository before asking: a build or install script in the tree, a `*.csproj`, `package.json`, `Cargo.toml`, or `pyproject.toml` usually tells you the command, so propose it and let the user correct it rather than asking from nothing.

```powershell
pwsh <skill>/scripts/tools.ps1 init
pwsh <skill>/scripts/tools.ps1 add -Name <name> -Path <repo> `
  -Build '<command>' -Install '<command>' -InstallDir '<dir>'
```

`add` rejects a path that is not inside a Git repository and a name that already exists, unless `-Force` replaces it. `remove -Name <name>` and `list` complete the set.

## Update run

```powershell
pwsh <skill>/scripts/tools.ps1 update [-Only <name>...] [-SkipPull]
```

For each selected tool the script pulls with `--ff-only`, runs the build command, creates `installDir` when set, and runs the install command. A repository with uncommitted changes is not pulled; it is still built and reported. The result table names every step's outcome, and the script exits non-zero when any tool failed.

Read the failures rather than rerunning blindly. A non-fast-forward pull, a build break, and a missing dependency each need a different answer — report which tools succeeded, diagnose the ones that did not, and ask before rewriting anyone's local history.
