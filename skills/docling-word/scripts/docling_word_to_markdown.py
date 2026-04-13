#!/usr/bin/env python3
"""Convert a DOCX file to Markdown with Docling and normalize attachments."""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


IMAGE_LINK_RE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a .docx file with Docling and store assets in a sibling attachments folder."
    )
    parser.add_argument("input_docx", help="Path to the input .docx file")
    parser.add_argument(
        "--markdown-path",
        help="Target Markdown file path. Defaults to <input-stem>.md next to the input DOCX.",
    )
    parser.add_argument(
        "--attachments-dir-name",
        default="attachments",
        help="Sibling directory name used for extracted assets. Defaults to attachments.",
    )
    parser.add_argument(
        "--docling-bin",
        default="docling",
        help="Docling executable name or path. Defaults to docling.",
    )
    parser.add_argument(
        "--uv-bin",
        default="uv",
        help="uv executable name or path. Defaults to uv.",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)


def run_command(command: list[str]) -> None:
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as exc:
        fail(f"Command failed with exit code {exc.returncode}: {' '.join(command)}")
    except FileNotFoundError:
        fail(f"Command not found: {command[0]}")


def ensure_uv_and_docling(uv_bin: str, docling_bin: str) -> None:
    if shutil.which(uv_bin) is None:
        fail("uv is not available in PATH.")

    if shutil.which(docling_bin) is not None:
        return

    print("[INFO] docling is not installed. Installing via `uv tool install docling`...")
    run_command([uv_bin, "tool", "install", "docling"])

    if shutil.which(docling_bin) is None:
        fail("docling is still not available after `uv tool install docling`.")


def resolve_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    input_docx = Path(args.input_docx).expanduser().resolve()
    if not input_docx.exists():
        fail(f"Input file does not exist: {input_docx}")
    if input_docx.suffix.lower() != ".docx":
        fail(f"Only .docx is supported as direct input, got: {input_docx.suffix}")

    if args.markdown_path:
        markdown_path = Path(args.markdown_path).expanduser().resolve()
    else:
        markdown_path = input_docx.with_suffix(".md")

    attachments_dir = markdown_path.parent / args.attachments_dir_name
    return input_docx, markdown_path, attachments_dir


def pick_docling_markdown(temp_output_dir: Path, input_stem: str) -> Path:
    markdown_candidates = sorted(temp_output_dir.rglob("*.md"))
    if not markdown_candidates:
        fail("Docling did not generate a Markdown file.")

    exact_matches = [path for path in markdown_candidates if path.stem == input_stem]
    if exact_matches:
        return exact_matches[0]
    if len(markdown_candidates) == 1:
        return markdown_candidates[0]

    fail(
        "Docling generated multiple Markdown files and none matched the input stem: "
        + ", ".join(str(path) for path in markdown_candidates)
    )
    raise AssertionError("unreachable")


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def copy_with_dedup(source: Path, destination_dir: Path) -> Path:
    destination = destination_dir / source.name
    if destination.exists():
        if hash_file(destination) == hash_file(source):
            return destination

        counter = 2
        while True:
            candidate = destination_dir / f"{source.stem}-{counter}{source.suffix}"
            if not candidate.exists():
                destination = candidate
                break
            if hash_file(candidate) == hash_file(source):
                return candidate
            counter += 1

    shutil.copy2(source, destination)
    return destination


def collect_artifacts(temp_output_dir: Path, attachments_dir: Path) -> tuple[dict[str, str], int]:
    artifact_lookup: dict[str, str] = {}
    artifact_dirs = [path for path in temp_output_dir.iterdir() if path.is_dir() and path.name.endswith("_artifacts")]
    if not artifact_dirs:
        return artifact_lookup, 0

    attachments_dir.mkdir(parents=True, exist_ok=True)
    copied_count = 0

    for artifact_dir in artifact_dirs:
        for source in sorted(artifact_dir.rglob("*")):
            if not source.is_file():
                continue
            if source.name.startswith("."):
                continue
            destination = copy_with_dedup(source, attachments_dir)
            relative_target = f"{attachments_dir.name}/{destination.name}".replace("\\", "/")
            for variant in build_path_variants(source):
                artifact_lookup[variant] = relative_target
            copied_count += 1
    return artifact_lookup, copied_count


def build_path_variants(path: Path) -> set[str]:
    resolved = path.resolve()
    variants = {
        str(path),
        str(resolved),
        path.as_posix(),
        resolved.as_posix(),
        str(path).replace("/", "\\"),
        str(resolved).replace("/", "\\"),
    }
    return {variant.casefold() for variant in variants}


def rewrite_markdown(markdown_text: str, artifact_lookup: dict[str, str]) -> str:
    if not artifact_lookup:
        return markdown_text

    basename_lookup: dict[str, str] = {}
    for source_variant, relative_target in artifact_lookup.items():
        basename_lookup.setdefault(Path(source_variant).name.casefold(), relative_target)

    def replace_image_link(match: re.Match[str]) -> str:
        alt_text = match.group(1)
        raw_target = match.group(2).strip()
        normalized = raw_target.strip("<>").strip().casefold()
        new_target = artifact_lookup.get(normalized)
        if new_target is None:
            new_target = basename_lookup.get(Path(raw_target).name.casefold())
        if new_target is None:
            return match.group(0)
        return f"![{alt_text}]({new_target})"

    return IMAGE_LINK_RE.sub(replace_image_link, markdown_text)


def convert_with_docling(
    input_docx: Path,
    markdown_path: Path,
    attachments_dir: Path,
    docling_bin: str,
) -> tuple[Path, int]:
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    attachments_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="docling-word-") as temp_dir:
        temp_output_dir = Path(temp_dir)
        command = [
            docling_bin,
            "--from",
            "docx",
            "--to",
            "md",
            "--image-export-mode",
            "referenced",
            "--output",
            str(temp_output_dir),
            str(input_docx),
        ]
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            fail(f"Docling conversion failed with exit code {result.returncode}.")

        generated_markdown = pick_docling_markdown(temp_output_dir, input_docx.stem)
        artifact_lookup, copied_count = collect_artifacts(temp_output_dir, attachments_dir)
        rewritten = rewrite_markdown(generated_markdown.read_text(encoding="utf-8"), artifact_lookup)
        markdown_path.write_text(rewritten, encoding="utf-8", newline="\n")
        return markdown_path, copied_count


def main() -> None:
    args = parse_args()
    ensure_uv_and_docling(args.uv_bin, args.docling_bin)
    input_docx, markdown_path, attachments_dir = resolve_paths(args)
    output_markdown, artifact_count = convert_with_docling(
        input_docx=input_docx,
        markdown_path=markdown_path,
        attachments_dir=attachments_dir,
        docling_bin=args.docling_bin,
    )
    print(f"[OK] Markdown written to: {output_markdown}")
    print(f"[OK] Attachments directory: {attachments_dir}")
    print(f"[OK] Attachments handled: {artifact_count}")


if __name__ == "__main__":
    main()
