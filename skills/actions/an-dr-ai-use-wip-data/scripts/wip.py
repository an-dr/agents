"""Read and write registered sections of tmp-agent-wip.json."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def root_path(argument: Path | None) -> Path:
    if argument:
        return argument.resolve()
    result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if result.returncode or not result.stdout.strip():
        raise ValueError("Run inside a git repository or pass --root.")
    return Path(result.stdout.strip()).resolve()


def read_data(file: Path) -> dict:
    if not file.exists():
        return {"schemaVersion": 1, "sections": {}}
    data = load_json(file)
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        raise ValueError(f"Unsupported tmp-agent-wip.json schema version '{data.get('schemaVersion') if isinstance(data, dict) else None}'.")
    if not isinstance(data.get("sections"), dict):
        raise ValueError("tmp-agent-wip.json sections must be an object.")
    return data


def write_data(file: Path, data: dict) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=".tmp-agent-wip-", suffix=".json", dir=file.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, file)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def operate(args: argparse.Namespace) -> str | None:
    root = root_path(args.root)
    file = root / "tmp-agent-wip.json"
    if args.command == "path":
        return str(file)
    register = load_json(Path(__file__).resolve().parent / "sections.json")
    if not args.section:
        raise ValueError(f"--section is required for {args.command}.")
    if args.section not in register:
        raise ValueError(f"Unknown section '{args.section}'; the register knows: {', '.join(register)}.")
    entry = register[args.section]
    if args.command == "get":
        if not args.reader:
            raise ValueError("--reader is required for get: the skill that reads.")
        if args.reader == entry["owner"]:
            allowed = entry["fields"]
        elif args.reader in entry["readers"]:
            allowed = entry["readers"][args.reader]
        else:
            raise ValueError(f"{args.reader} may not read section '{args.section}'.")
        if args.field and args.field not in allowed:
            raise ValueError(f"{args.reader} may not read '{args.section}.{args.field}'; it may read: {', '.join(allowed)}.")
        if not args.field and args.reader != entry["owner"]:
            raise ValueError(f"{args.reader} reads named fields of '{args.section}' only: {', '.join(allowed)}.")
        value = read_data(file)["sections"].get(args.section)
        if args.field:
            value = value.get(args.field) if isinstance(value, dict) else None
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if args.owner != entry["owner"]:
        raise ValueError(f"Section '{args.section}' belongs to {entry['owner']}; '{args.owner}' may not write it.")
    if args.command == "set":
        if not args.json_path:
            raise ValueError("--json-path is required for set: a file holding the section as JSON.")
        value = load_json(args.json_path)
        if not isinstance(value, dict):
            raise ValueError("A section must be a JSON object.")
        unknown = sorted(set(value) - set(entry["fields"]))
        if unknown:
            raise ValueError(f"Section '{args.section}' has no field(s) {', '.join(unknown)}; add them to the register first.")
        data = read_data(file)
        data["sections"][args.section] = value
        write_data(file, data)
    elif args.command == "remove":
        data = read_data(file)
        data["sections"].pop(args.section, None)
        if data["sections"]:
            write_data(file, data)
        else:
            file.unlink(missing_ok=True)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("get", "set", "remove", "path"))
    parser.add_argument("--section", "-Section")
    parser.add_argument("--field", "-Field")
    parser.add_argument("--owner", "-Owner")
    parser.add_argument("--reader", "-Reader")
    parser.add_argument("--json-path", "-JsonPath", type=Path)
    parser.add_argument("--root", "-Root", type=Path)
    args = parser.parse_args()
    try:
        output = operate(args)
        if output is not None:
            print(output)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
