#!/usr/bin/env python3
"""
Writes the GitHub release description from the addon's own patch notes.

    python3 .github/scripts/release_notes.py <version> [previous-release-version] > notes.md

Takes every patch-notes entry newer than the previous release, up to and
including <version>, and groups the lines by section (New, Changed, Fixed),
newest first. With no previous release, only <version>'s entry is used.
Used by .github/workflows/release.yml; safe to run by hand to preview.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH_NOTES = ROOT / "Kain-UI-Forever" / "PatchNotes.lua"
REPO_URL = "https://github.com/Emu-Soft/Kain-UI-Forever"

STRING = r'"((?:[^"\\]|\\.)*)"'


def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def version_key(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def parse(text):
    """[(version, [(title, [items])])] in file order (newest first)."""
    start = text.index("local PATCH_NOTES = {")
    end = text.index("\n}", start)
    body = text[start:end]
    entries = []
    # Each entry starts at a 'version = "..."' (or 'heading = "..."', the old-history entry).
    marks = list(re.finditer(r'\n\t\t(version|heading) = ' + STRING, body))
    for i, m in enumerate(marks):
        chunk = body[m.end(): marks[i + 1].start() if i + 1 < len(marks) else len(body)]
        if m.group(1) != "version":
            continue
        sections = []
        for sm in re.finditer(r'title = ' + STRING + r',\s*items = \{(.*?)\}\s*\}', chunk, re.S):
            items = [unescape(x) for x in re.findall(STRING, sm.group(2))]
            sections.append((unescape(sm.group(1)), items))
        entries.append((m.group(2), sections))
    return entries


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: release_notes.py <version> [previous-release-version]")
    version = sys.argv[1].lstrip("v")
    previous = sys.argv[2].lstrip("v") if len(sys.argv) > 2 and sys.argv[2] else None

    entries = parse(PATCH_NOTES.read_text(encoding="utf-8"))
    known = {v for v, _ in entries}
    if version not in known:
        sys.exit("version %s has no patch-notes entry in PatchNotes.lua" % version)

    chosen = [
        (v, s) for v, s in entries
        if version_key(v) <= version_key(version)
        and (version_key(v) > version_key(previous) if previous else v == version)
    ]

    # Group by section title, keeping the order titles first appear (newest first).
    order, grouped = [], {}
    for _, sections in chosen:
        for title, items in sections:
            if title not in grouped:
                order.append(title)
                grouped[title] = []
            grouped[title].extend(items)

    out = []
    if not previous:
        out.append("The first release of K-UI: Forever on GitHub.\n")
    out.append("## Installing")
    out.append("1. Download the **Kain-UI-Forever** zip below.")
    out.append("2. Unzip it and put the `Kain-UI-Forever` folder in your WoW: Forever `Interface\\AddOns` folder.")
    out.append("3. Restart the game, then type `/kui` to open the settings.")
    out.append("")
    out.append("Updating from an earlier version? Replace the `Kain-UI-Forever` folder; your settings are kept.")
    out.append("")
    heading = {"New": "New in this version", "Changed": "Changed", "Fixed": "Fixed"}
    # New first, then Changed, then Fixed; any other section after those.
    rank = {"New": 0, "Changed": 1, "Fixed": 2}
    order.sort(key=lambda t: rank.get(t, 3))
    for title in order:
        out.append("## " + heading.get(title, title))
        for item in grouped[title]:
            out.append("- " + item)
        out.append("")
    out.append("The full list of features and commands is in the [README](%s#readme), and every change "
               "is in the patch notes in game (the blue gem in the bottom-left corner of `/kui`)." % REPO_URL)
    print("\n".join(out))


if __name__ == "__main__":
    main()
