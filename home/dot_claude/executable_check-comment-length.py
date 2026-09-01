#!/usr/bin/env python3
"""Flag comment runs longer than two lines in a file Claude just edited.

PostToolUse hook on Edit|Write, wired in .chezmoitemplates/claude-settings-merge.py.

usage: check-comment-length.py   (hook JSON on stdin; exit 2 reports back to Claude)
"""

import json
import os
import re
import subprocess
import sys

MAX_LINES = 2

C_LIKE = {"line": ("//",), "doc": ("///", "//!"), "open": "/*", "close": "*/", "doc_open": "/**"}
HASH = {"line": ("#",), "doc": (), "open": None, "close": None, "doc_open": None}
DASH = {"line": ("--",), "doc": ("---",), "open": None, "close": None, "doc_open": None}
SEMI = {"line": (";",), "doc": (), "open": None, "close": None, "doc_open": None}
PERCENT = {"line": ("%",), "doc": (), "open": None, "close": None, "doc_open": None}

SYNTAX = {}
for _exts, _syntax in (
    (".py .pyi .sh .bash .zsh .fish .rb .pl .pm .r .jl .nix .tf .tfvars .yaml .yml"
     " .toml .cmake .mk .conf .service", HASH),
    (".c .h .cc .cpp .cxx .hpp .hh .java .js .jsx .mjs .cjs .ts .tsx .go .rs .swift"
     " .kt .kts .scala .cs .php .m .mm .zig .dart .proto .gradle .groovy .css .scss"
     " .less", C_LIKE),
    (".sql .lua .hs .elm .adb .ads", DASH),
    (".el .lisp .clj .cljs .cljc .scm .ini", SEMI),
    (".erl .tex", PERCENT),
):
    for _ext in _exts.split():
        SYNTAX[_ext] = _syntax
SYNTAX["makefile"] = HASH
SYNTAX["dockerfile"] = HASH

HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


def syntax_for(path):
    name = os.path.basename(path).lower()
    _, ext = os.path.splitext(name)
    return SYNTAX.get(ext) or SYNTAX.get(name)


def git(args, cwd):
    return subprocess.run(
        ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5
    )


def added_lines(path):
    """1-indexed lines the working tree adds over HEAD, or None to count every line."""
    try:
        top = git(["rev-parse", "--show-toplevel"], os.path.dirname(path) or ".")
        if top.returncode != 0:
            return None
        # Pathspecs are resolved against the real toplevel, so an absolute path
        # reached through a symlink (/tmp, /var on macOS) reads as outside the repo.
        root = top.stdout.strip()
        rel = os.path.relpath(os.path.realpath(path), root)
        if git(["ls-files", "--error-unmatch", "--", rel], root).returncode != 0:
            return None
        diff = git(["diff", "HEAD", "-U0", "--no-color", "--", rel], root)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    if diff.returncode != 0:
        return None
    added = set()
    for line in diff.stdout.splitlines():
        match = HUNK.match(line)
        if match:
            start = int(match.group(1))
            count = 1 if match.group(2) is None else int(match.group(2))
            added.update(range(start, start + count))
    return added


def classify(line, syntax):
    """One of "doc", "comment", or "" for a stripped line's role."""
    for prefix in syntax["doc"]:
        if line.startswith(prefix):
            return "doc"
    for prefix in syntax["line"]:
        if line.startswith(prefix):
            return "comment"
    return ""


def comment_runs(lines, syntax):
    """Yield 1-indexed (start, end) spans of consecutive comment lines."""
    index = 0
    total = len(lines)
    while index < total:
        stripped = lines[index].strip()
        # A shebang is not a comment, so a script's header run starts on line 2.
        if index == 0 and stripped.startswith("#!"):
            index += 1
            continue
        if syntax["open"] and stripped.startswith(syntax["open"]):
            start = index
            is_doc = syntax["doc_open"] and stripped.startswith(syntax["doc_open"])
            while index < total and syntax["close"] not in lines[index]:
                index += 1
            index = min(index + 1, total)
            if not is_doc:
                yield start + 1, index
            continue
        if classify(stripped, syntax) == "comment":
            start = index
            while index < total and classify(lines[index].strip(), syntax) == "comment":
                index += 1
            yield start + 1, index
            continue
        index += 1


def header_line(lines):
    """Where a file header would start: past a shebang and any leading blanks."""
    index = 1 if lines and lines[0].startswith("#!") else 0
    while index < len(lines) and not lines[index].strip():
        index += 1
    return index + 1


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
        return 0
    path = (payload.get("tool_input") or {}).get("file_path")
    if not path:
        return 0
    path = os.path.abspath(path)
    if not os.path.isfile(path):
        return 0
    syntax = syntax_for(path)
    if syntax is None:
        return 0
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return 0

    added = added_lines(path)
    header = header_line(lines)
    offenders = []
    for start, end in comment_runs(lines, syntax):
        if end - start + 1 <= MAX_LINES or start == header:
            continue
        if added is not None and not any(n in added for n in range(start, end + 1)):
            continue
        offenders.append((start, end))
    if not offenders:
        return 0

    shown = path
    try:
        relative = os.path.relpath(path)
        if not relative.startswith(".."):
            shown = relative
    except ValueError:
        pass
    print('CLAUDE.md "Code comments": a comment is one or two lines.', file=sys.stderr)
    print(file=sys.stderr)
    for start, end in offenders:
        print("  %s:%d-%d  (%d lines)" % (shown, start, end, end - start + 1), file=sys.stderr)
    print(file=sys.stderr)
    print(
        "Keep the single fact a reader needs in order to not break this code. Rejected\n"
        "alternatives, provenance, and background go in the commit message instead.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
