#!/usr/bin/env python3

"""Prepare a Jekyll post for pasting into DEV.to."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import tempfile


ROOT_RELATIVE_IMAGE = re.compile(r"(!\[[^\]]*\]\()(/[^)\s]+)")


def config_value(config: str, key: str, default: str | None = None) -> str:
    """Read a simple top-level scalar from Jekyll's YAML configuration."""
    match = re.search(rf"^{re.escape(key)}:\s*(.*?)\s*(?:#.*)?$", config, re.MULTILINE)
    if match is None:
        if default is not None:
            return default
        raise ValueError(f"Missing {key!r} in _config.yml")

    value = match.group(1).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        value = value[1:-1]
    return value


def site_root(config_file: Path) -> str:
    config = config_file.read_text(encoding="utf-8")
    url = config_value(config, "url").rstrip("/")
    baseurl = config_value(config, "baseurl", "").strip("/")
    return f"{url}/{baseurl}" if baseurl else url


def adjust_image_links(
    markdown: str,
    root: str,
    image_extension: str | None = None,
) -> tuple[str, int]:
    extension = image_extension.lstrip(".") if image_extension else None

    def replace(match: re.Match[str]) -> str:
        path = match.group(2)
        if extension:
            path = re.sub(
                r"\.svg(?=$|[?#])",
                f".{extension}",
                path,
                flags=re.IGNORECASE,
            )
        return f"{match.group(1)}{root}{path}"

    return ROOT_RELATIVE_IMAGE.subn(
        replace,
        markdown,
    )


def write_atomically(output_file: Path, content: str) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=output_file.parent,
        prefix=f".{output_file.name}.",
        delete=False,
    ) as temporary:
        temporary.write(content)
        temporary_name = temporary.name
    os.replace(temporary_name, output_file)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Replace root-relative Markdown image links with absolute site URLs."
    )
    parser.add_argument("post_file", type=Path)
    parser.add_argument("output_file", type=Path)
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("_config.yml"),
        help="Jekyll configuration file (default: _config.yml)",
    )
    parser.add_argument(
        "--image-extension",
        help="Replace .svg image extensions, for example: png",
    )
    args = parser.parse_args()

    if not args.post_file.is_file():
        parser.error(f"post not found: {args.post_file}")
    if not args.config.is_file():
        parser.error(f"config not found: {args.config}")

    markdown = args.post_file.read_text(encoding="utf-8")
    adjusted, replacement_count = adjust_image_links(
        markdown,
        site_root(args.config),
        args.image_extension,
    )
    write_atomically(args.output_file, adjusted)

    print(
        f"Prepared {args.output_file} from {args.post_file} "
        f"({replacement_count} image link(s) adjusted)."
    )


if __name__ == "__main__":
    main()
