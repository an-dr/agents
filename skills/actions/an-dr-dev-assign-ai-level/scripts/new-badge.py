"""Print an ai-level.dev badge as Markdown and HTML."""

from __future__ import annotations

import argparse


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--level", "-Level", type=int, choices=range(5), required=True)
    parser.add_argument("--style", "-Style", choices=("standard", "compact"), default="standard")
    args = parser.parse_args()
    image = f"https://ai-level.dev/badge/{args.style}/{args.level}.svg"
    page = f"https://ai-level.dev/level-{args.level}"
    print(f"Markdown:\n[![AI Level {args.level}]({image})]({page})")
    print(f'HTML:\n<a href="{page}"><img src="{image}" alt="AI Level {args.level}" /></a>')


if __name__ == "__main__":
    main()
