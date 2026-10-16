#!/usr/bin/env python3
"""Check that the repo's skills, manifests and READMEs agree. Exits 1 on any problem."""

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
PROMOTED_BUCKETS = ("engineering",)
NON_PROMOTED_BUCKETS = ("in-progress",)
MAX_SKILL_LINES = 500

problems: list[str] = []


def frontmatter(skill_md: Path) -> dict[str, str]:
    """Top-level `key: value` pairs of a SKILL.md frontmatter block."""
    text = skill_md.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        problems.append(f"{skill_md.relative_to(ROOT)}: no frontmatter block")
        return {}
    return dict(re.findall(r"^([a-z][a-z-]*):\s*(.*)$", match.group(1), re.MULTILINE))


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        problems.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


plugin = load_json(ROOT / ".claude-plugin/plugin.json")
load_json(ROOT / ".claude-plugin/marketplace.json")
shipped = {entry.removeprefix("./").rstrip("/") for entry in plugin.get("skills", [])}

readme = (ROOT / "README.md").read_text(encoding="utf-8")
skills = sorted(ROOT.glob("skills/*/*/SKILL.md"))
promoted = set()

for skill_md in skills:
    folder = skill_md.parent
    relative = str(folder.relative_to(ROOT))
    bucket = folder.parent.name
    meta = frontmatter(skill_md)
    if meta.get("name") != folder.name:
        problems.append(f"{relative}: frontmatter name {meta.get('name')!r} differs from folder {folder.name!r}")
    if not meta.get("description"):
        problems.append(f"{relative}: missing description")
    lines = len(skill_md.read_text(encoding="utf-8").splitlines())
    if lines > MAX_SKILL_LINES:
        problems.append(f"{relative}: SKILL.md has {lines} lines (max {MAX_SKILL_LINES})")
    link = f"(./{relative}/SKILL.md)"
    bucket_link = f"(./{folder.name}/SKILL.md)"
    bucket_readme = folder.parent / "README.md"
    bucket_text = bucket_readme.read_text(encoding="utf-8") if bucket_readme.exists() else ""
    if bucket in PROMOTED_BUCKETS:
        promoted.add(relative)
        if link not in readme:
            problems.append(f"{relative}: not linked from README.md")
        if bucket_link not in bucket_text:
            problems.append(f"{relative}: not linked from {bucket_readme.relative_to(ROOT)}")
    elif bucket in NON_PROMOTED_BUCKETS:
        if link in readme:
            problems.append(f"{relative}: non-promoted skill is linked from README.md")
    else:
        problems.append(f"{relative}: unknown bucket {bucket!r}")

for missing in sorted(promoted - shipped):
    problems.append(f"{missing}: promoted but not in plugin.json skills")
for extra in sorted(shipped - promoted):
    problems.append(f"{extra}: in plugin.json skills but not a promoted skill folder")

for markdown in ROOT.rglob("*.md"):
    if ".git" in markdown.parts:
        continue
    for number, line in enumerate(markdown.read_text(encoding="utf-8").splitlines(), 1):
        if "—" in line:
            problems.append(f"{markdown.relative_to(ROOT)}:{number}: em-dash")

for problem in problems:
    print(f"FAIL {problem}")
print(f"{len(skills)} skills, {len(promoted)} promoted, {len(problems)} problems")
sys.exit(1 if problems else 0)
