#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


START_MARKER = "    <!-- SNAKE_INLINE_START -->"
END_MARKER = "    <!-- SNAKE_INLINE_END -->"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_svg_payload(svg: str) -> tuple[str, str]:
    root_match = re.search(r"<svg\b([^>]*)>([\s\S]*)</svg>\s*$", svg.strip())
    if not root_match:
        raise ValueError("输入的贡献蛇文件不是有效 SVG")

    attrs = root_match.group(1)
    body = root_match.group(2).strip()

    view_box_match = re.search(r'viewBox="([^"]+)"', attrs)
    if not view_box_match:
        raise ValueError("贡献蛇 SVG 缺少 viewBox")

    return view_box_match.group(1), body


def build_inline_snake(snake_svg: str) -> str:
    view_box, body = extract_svg_payload(snake_svg)
    if "Generated with https://github.com/Platane/snk" not in body:
        raise ValueError("贡献蛇 SVG 不是 Platane/snk 产物")
    for marker in ('class="c ', 'class="u ', 'class="s '):
        if marker not in body:
            raise ValueError(f"贡献蛇 SVG 缺少动画标记: {marker}")

    return f"""{START_MARKER}
    <g id="snake-inline" data-source="Platane/snk">
      <svg x="0" y="-12" width="350" height="76" viewBox="{view_box}" preserveAspectRatio="xMidYMid meet" transform="rotate(90 24 24)">
        {body}
      </svg>
    </g>
{END_MARKER}"""


def inline_snake(dashboard: str, snake_svg: str) -> str:
    inline = build_inline_snake(snake_svg)
    pattern = re.compile(
        re.escape(START_MARKER) + r"[\s\S]*?" + re.escape(END_MARKER)
    )
    updated, count = pattern.subn(inline, dashboard, count=1)
    if count != 1:
        raise ValueError("dashboard.svg 缺少 SNAKE_INLINE_START/SNAKE_INLINE_END 占位标记")
    return updated


def main() -> None:
    parser = argparse.ArgumentParser(description="把真实贡献蛇 SVG 内联到 Dashboard")
    parser.add_argument("--dashboard", default="assets/dashboard.svg", type=Path)
    parser.add_argument("--snake", default="dist/github-contribution-grid-snake-dark.svg", type=Path)
    parser.add_argument("--output", default=None, type=Path)
    args = parser.parse_args()

    dashboard = read_text(args.dashboard)
    snake_svg = read_text(args.snake)
    updated = inline_snake(dashboard, snake_svg)

    output = args.output or args.dashboard
    output.write_text(updated, encoding="utf-8", newline="\n")
    print(output.resolve())


if __name__ == "__main__":
    main()
