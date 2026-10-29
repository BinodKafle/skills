#!/usr/bin/env python3
"""Check that the repo's skills, manifests, READMEs and changelog agree. Exits 1 on any problem."""

from __future__ import annotations
from pathlib import Path
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PROMOTED_BUCKETS = ("engineering",)
NON_PROMOTED_BUCKETS = ("in-progress",)
MAX_SKILL_LINES = 500
SKILL_DIRS = ("references", "templates", "scripts")
SKIP_DIRS = {".git", ".idea", "node_modules", "__pycache__"}


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def load_json(path: Path, problems: list[str]) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        problems.append(f"{rel(path)}: {error}")
        return {}


def frontmatter(text: str) -> dict[str, str] | None:
    """Top-level `key: value` pairs of a SKILL.md frontmatter block, or None if there is no block."""
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        return None
    return dict(re.findall(r"^([a-z][a-z-]*):\s*(.*)$", match.group(1), re.MULTILINE))


def semver(version: str) -> tuple[int, ...] | None:
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", version if isinstance(version, str) else "")
    return tuple(int(part) for part in match.groups()) if match else None


def invocation_label(readme_text: str, link: str) -> str | None:
    """The "User-invoked"/"Model-invoked" label over the item linking to the skill, within its section, or None."""
    item = re.search(rf"^\s*[-*] \[[^\]]*\]{re.escape(link)}", readme_text, re.MULTILINE)
    if not item:
        return None
    before = readme_text[:item.start()]
    section = re.split(r"^#+ (?!(?:User|Model)-invoked).*$", before, flags=re.MULTILINE)[-1]
    labels = {label: section.rfind(label) for label in ("User-invoked", "Model-invoked")}
    label, found_at = max(labels.items(), key=lambda item: item[1])
    return label if found_at >= 0 else None


def is_hidden(parts: tuple[str, ...]) -> bool:
    """Dotfiles (.DS_Store, editor swap files) aren't part of a skill."""
    return any(part.startswith(".") for part in parts)


def check_skill_files(folder: Path, text: str) -> list[str]:
    """Files SKILL.md names must exist, and every file beside SKILL.md must be named in it."""
    problems = []
    # Skip matches inside a longer path or URL (`tools/scripts/x.sh`, `https://.../scripts/x.sh`).
    pattern = rf"(?<![\w/.:-])(?:\./)?((?:{'|'.join(SKILL_DIRS)})/[\w./-]+\.\w+)"
    for reference in sorted(set(re.findall(pattern, text))):
        if not (folder / reference).is_file():
            problems.append(f"{rel(folder)}: SKILL.md mentions {reference}, which doesn't exist")
    for path in sorted(folder.rglob("*")):
        parts = path.relative_to(folder).parts
        if not path.is_file() or path.parent == folder or SKIP_DIRS.intersection(parts) or is_hidden(parts):
            continue
        relative = str(path.relative_to(folder))
        if relative not in text:
            problems.append(f"{rel(folder)}: {relative} is never named in SKILL.md (say when to read it)")
    for path in folder.iterdir():
        if path.is_file() and path.name not in ("SKILL.md", "README.md") and not is_hidden((path.name,)):
            problems.append(f"{rel(folder)}: {path.name} beside SKILL.md; put it in {', '.join(SKILL_DIRS)}/")
    return problems


def check_skills(readme: str, shipped: set[str]) -> tuple[list[str], int, int]:
    problems = []
    skills = sorted(ROOT.glob("skills/*/*/SKILL.md"))
    promoted = set()
    promoted_readmes = {bucket: read(ROOT / "skills" / bucket / "README.md") for bucket in PROMOTED_BUCKETS}

    for skill_md in skills:
        folder = skill_md.parent
        relative = rel(folder)
        bucket = folder.parent.name
        text = skill_md.read_text(encoding="utf-8")
        meta = frontmatter(text)
        if meta is None:
            problems.append(f"{relative}/SKILL.md: no frontmatter block")
            meta = {}
        if meta.get("name") != folder.name:
            problems.append(f"{relative}: frontmatter name {meta.get('name')!r} differs from folder {folder.name!r}")
        if not meta.get("description"):
            problems.append(f"{relative}: missing description")
        problems += check_skill_files(folder, text)
        lines = len(text.splitlines())
        if lines > MAX_SKILL_LINES:
            problems.append(f"{relative}: SKILL.md has {lines} lines (max {MAX_SKILL_LINES})")

        user_invoked = meta.get("disable-model-invocation", "").strip() == "true"
        wanted_label = "User-invoked" if user_invoked else "Model-invoked"
        if bucket in PROMOTED_BUCKETS:
            promoted.add(relative)
            bucket_readme = folder.parent / "README.md"
            for readme_path, readme_text, link in (
                (ROOT / "README.md", readme, f"(./{relative}/SKILL.md)"),
                (bucket_readme, promoted_readmes[bucket], f"(./{folder.name}/SKILL.md)"),
            ):
                if link not in readme_text:
                    problems.append(f"{relative}: not linked from {rel(readme_path)}")
                elif invocation_label(readme_text, link) != wanted_label:
                    problems.append(f"{relative}: {rel(readme_path)} doesn't list it under {wanted_label!r}")
        elif bucket in NON_PROMOTED_BUCKETS:
            if f"{relative}/" in readme:
                problems.append(f"{relative}: non-promoted skill is linked from README.md")
            for promoted_bucket, text_of_readme in promoted_readmes.items():
                if f"{bucket}/{folder.name}/" in text_of_readme:
                    problems.append(f"{relative}: non-promoted skill is linked from skills/{promoted_bucket}/README.md")
        else:
            problems.append(f"{relative}: unknown bucket {bucket!r}")

    for missing in sorted(promoted - shipped):
        problems.append(f"{missing}: promoted but not in plugin.json skills")
    for extra in sorted(shipped - promoted):
        problems.append(f"{extra}: in plugin.json skills but not a promoted skill folder")
    return problems, len(skills), len(promoted)


def check_manifests(plugin: dict, marketplace: dict) -> list[str]:
    problems = []
    entries = [entry for entry in marketplace.get("plugins") or [] if entry.get("name") == plugin.get("name")]
    if not entries:
        problems.append(f"marketplace.json: no plugin entry named {plugin.get('name')!r}")
    for entry in entries:
        if "description" in entry and entry["description"] != plugin.get("description"):
            problems.append("marketplace.json: plugin description differs from plugin.json (omit it to inherit)")
    if semver(plugin.get("version", "")) is None:
        problems.append(f"plugin.json: version {plugin.get('version')!r} isn't MAJOR.MINOR.PATCH")
    return problems


def check_changelog(version: str) -> list[str]:
    heading = re.search(r"^## (\S+)", read(ROOT / "CHANGELOG.md"), re.MULTILINE)
    if not heading or heading.group(1) != version:
        found = heading.group(1) if heading else "none"
        return [f"CHANGELOG.md: newest entry is {found}, but plugin.json version is {version}"]
    return []


def check_version_bump(version: str) -> list[str]:
    """If shipped files changed since the last v* tag, the version must be above the tag's."""
    tag = git("describe", "--tags", "--abbrev=0", "--match", "v*")
    if tag.returncode != 0:
        if os.environ.get("CI"):
            return ["no v* release tag found, so the version bump can't be checked (fetch tags, or tag a release)"]
        print("note: no v* release tag found, so the version-bump check was skipped")
        return []
    tag_name = tag.stdout.strip()
    tagged = semver(tag_name.removeprefix("v"))
    current = semver(version)
    if tagged is None or current is None:
        return [f"can't compare version {version!r} with tag {tag_name!r}"]
    if current < tagged:
        return [f"plugin.json version {version} is lower than the last release tag {tag_name}"]
    shipped_paths = [f"skills/{bucket}/" for bucket in PROMOTED_BUCKETS] + [".claude-plugin/", "hooks/"]
    changed = git("diff", "--quiet", tag_name, "--", *shipped_paths).returncode != 0
    if changed and current == tagged:
        return [f"shipped files changed since {tag_name}, but plugin.json version is still {version}"]
    return []


def markdown_files() -> list[Path]:
    """The repo's .md files, skipping SKIP_DIRS and symlinks."""
    found = []
    for folder, subfolders, files in os.walk(ROOT):
        subfolders[:] = [name for name in subfolders if name not in SKIP_DIRS]
        found += [Path(folder, name) for name in files if name.endswith(".md") and not Path(folder, name).is_symlink()]
    return sorted(found)


def check_em_dashes() -> list[str]:
    problems = []
    for markdown in markdown_files():
        for number, line in enumerate(markdown.read_text(encoding="utf-8").splitlines(), 1):
            if "—" in line:
                problems.append(f"{rel(markdown)}:{number}: em-dash")
    return problems


def main() -> int:
    problems: list[str] = []
    plugin = load_json(ROOT / ".claude-plugin/plugin.json", problems)
    marketplace = load_json(ROOT / ".claude-plugin/marketplace.json", problems)
    shipped = {entry.removeprefix("./").rstrip("/") for entry in plugin.get("skills", [])}
    version = plugin.get("version", "")

    skill_problems, skill_count, promoted_count = check_skills(read(ROOT / "README.md"), shipped)
    problems += skill_problems
    problems += check_manifests(plugin, marketplace)
    problems += check_changelog(version)
    problems += check_version_bump(version)
    problems += check_em_dashes()

    for problem in problems:
        print(f"FAIL {problem}")
    print(f"{skill_count} skills, {promoted_count} promoted, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
