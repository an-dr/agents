"""Parse a reply against saved questions and write decisions as JSON."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


MARKER = re.compile(r"(?i)(?:^|(?<=[\s,;]))q?(\d+)\s*[:.)]?\s*")
RECOMMENDED = re.compile(r"\s*\(Recommended\)\s*$")


def plain_label(label: str) -> str:
    return RECOMMENDED.sub("", label).strip().lower()


def segments(reply: str, count: int) -> dict[int, str]:
    markers = [match for match in MARKER.finditer(reply) if 1 <= int(match.group(1)) <= count]
    if markers:
        return {
            int(match.group(1)): reply[match.end() : markers[index + 1].start() if index + 1 < len(markers) else len(reply)].strip(" \t\r\n,;")
            for index, match in enumerate(markers)
        }
    if count == 1:
        return {1: reply.strip()} if reply.strip() else {}
    words = [word for word in re.split(r"[\s,;]+", reply) if word]
    if words and all(re.fullmatch(r"[a-zA-Z]+", word) for word in words):
        return {index + 1: word for index, word in enumerate(words[:count])}
    if reply.strip():
        raise ValueError("A reply to several questions needs question numbers, like `1a 2b` or `2: text`.")
    return {}


def parse_questions(questions: list[dict], reply: str) -> list[dict]:
    replies = segments(reply, len(questions))
    answers = []
    for number, question in enumerate(questions, 1):
        options = question["options"]
        keys = [str(option.get("key") or chr(97 + index)).lower() for index, option in enumerate(options)]
        answer = {"id": question["id"], "status": "open", "choices": [], "labels": [], "text": None}
        raw = replies.get(number, "")
        if raw:
            value = plain_label(raw)
            picked: list[int] = []
            if question.get("kind") == "confirm" and value in ("y", "yes", "n", "no"):
                word = "yes" if value.startswith("y") else "no"
                picked = [index for index, option in enumerate(options) if plain_label(option["label"]).startswith(word)]
            elif re.fullmatch(r"[a-z]+", value) and all(letter in keys for letter in value):
                picked = list(dict.fromkeys(keys.index(letter) for letter in value))
            else:
                exact = [index for index, option in enumerate(options) if plain_label(option["label"]) == value]
                prefix = [index for index, option in enumerate(options) if len(value) >= 3 and plain_label(option["label"]).startswith(value)]
                picked = exact if exact else prefix if len(prefix) == 1 else []
                if not picked and len(prefix) > 1:
                    answer.update(status="ambiguous", text=raw)
            if len(picked) > 1 and not question.get("multiSelect"):
                answer.update(status="ambiguous", text=raw)
            elif picked:
                answer.update(status="answered", choices=[keys[index] for index in picked], labels=[options[index]["label"] for index in picked])
            elif answer["status"] != "ambiguous":
                answer.update(status="custom", text=raw)
        answers.append(answer)
    return answers


def echo(answer: dict) -> str:
    name = answer["id"]
    if answer["status"] == "answered":
        choices = "; ".join(f"{key}. {label}" for key, label in zip(answer["choices"], answer["labels"]))
        return f"{name} → {choices}"
    if answer["status"] == "custom":
        return f"{name} → custom: {answer['text']}"
    if answer["status"] == "ambiguous":
        return f"{name} → ambiguous: {answer['text']} (ask again)"
    return f"{name} → open"


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--questions", "-Questions", type=Path, required=True)
    parser.add_argument("--reply", "-Reply", required=True)
    parser.add_argument("--out", "-Out", type=Path)
    args = parser.parse_args()
    try:
        source = args.questions.resolve(strict=True)
        specification = json.loads(source.read_text(encoding="utf-8-sig"))
        questions = specification.get("questions") or []
        if not questions:
            raise ValueError(f"No questions in {source}.")
        for question in questions:
            if not question.get("id") or len(question.get("options") or []) < 2:
                raise ValueError(f"Question '{question.get('id')}' needs an id and at least 2 options.")
        answers = parse_questions(questions, args.reply)
        output = args.out or source.with_name(source.name.replace(".questions.json", ".answers.json") if source.name.endswith(".questions.json") else "answers.json")
        output.write_text(json.dumps({"questions": str(source), "reply": args.reply, "answers": answers}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for answer in answers:
            print(echo(answer))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
