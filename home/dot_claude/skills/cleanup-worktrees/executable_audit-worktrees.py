#!/usr/bin/env python3
"""Report which git worktrees hold work that already landed on the trunk.

Read-only by construction: nothing here removes a worktree, deletes a ref, or
writes to the working tree. Deciding what to delete belongs to a human -- this
script only gathers evidence and prints a verdict per worktree. See SKILL.md.

Landed-ness is decided from the diff, not from SHAs or PR bookkeeping, because
rebase-, squash-, and spr-style merges all rewrite the commit that lands. A
merged PR is never sufficient on its own: in a stacked-PR workflow the bottom
commit can be merged while a commit on top of it has no PR at all, so an
existence check would call the whole worktree landed.

The squash probe writes a throwaway commit object via `git commit-tree`. It is
unreferenced, GC-eligible, and given fixed author/committer dates so repeated
runs reuse the same object rather than accumulating garbage.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

# Fixed so the squash probe is reproducible; the object is never referenced.
PROBE_ENV = {
    "GIT_AUTHOR_NAME": "audit",
    "GIT_AUTHOR_EMAIL": "audit@localhost",
    "GIT_AUTHOR_DATE": "@0 +0000",
    "GIT_COMMITTER_NAME": "audit",
    "GIT_COMMITTER_EMAIL": "audit@localhost",
    "GIT_COMMITTER_DATE": "@0 +0000",
}

# Per-worktree sequencer state. A rebase whose conflicts are resolved but not
# --continue'd leaves `status --porcelain` empty while holding index-only work
# that exists nowhere else, so these are checked by path, not by status text.
IN_PROGRESS_PATHS = (
    "rebase-merge",
    "rebase-apply",
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "BISECT_LOG",
)

COMMIT_ID_RE = re.compile(r"^commit-id:\s*([0-9a-f]+)\s*$", re.MULTILINE)

MAX_LISTED_IGNORED = 20


class GitError(RuntimeError):
    pass


def git(cwd, *args, check=True, env=None):
    """Run git in `cwd`; return stdout. Raise GitError on failure when check."""
    full_env = None
    if env:
        full_env = dict(os.environ, **env)
    proc = subprocess.run(
        ("git", *args),
        cwd=cwd,
        capture_output=True,
        text=True,
        errors="replace",  # a path git can't decode must not abort the audit
        env=full_env,
    )
    if check and proc.returncode != 0:
        raise GitError(f"git {' '.join(args)}: {proc.stderr.strip()}")
    return proc.stdout


def git_ok(cwd, *args):
    """Run git for its exit status alone."""
    proc = subprocess.run(
        ("git", *args), cwd=cwd, capture_output=True, text=True, errors="replace"
    )
    return proc.returncode == 0


def parse_worktrees(porcelain):
    """Parse `git worktree list --porcelain` into a list of dicts."""
    entries, cur = [], {}
    for line in porcelain.splitlines():
        if not line.strip():
            if cur:
                entries.append(cur)
                cur = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            cur["path"] = value
        elif key == "HEAD":
            cur["head"] = value
        elif key == "branch":
            cur["branch"] = value.removeprefix("refs/heads/")
        elif key in ("bare", "detached"):
            cur[key] = True
        elif key in ("locked", "prunable"):
            cur[key] = value or "no reason given"
    if cur:
        entries.append(cur)
    return entries


def resolve_remote(repo, required):
    remotes = git(repo, "remote").split()
    if "origin" in remotes:
        return "origin"
    if len(remotes) == 1:
        return remotes[0]
    if not required:
        return None
    raise GitError(
        f"cannot pick a remote from {remotes or 'none'}; "
        "pass --trunk to compare against a local branch instead"
    )


def resolve_trunk(repo, remote, override):
    """Return the trunk branch name (not the remote-tracking ref)."""
    if override:
        return override
    head = git(repo, "symbolic-ref", "--short", f"refs/remotes/{remote}/HEAD", check=False)
    if head.strip():
        return head.strip().removeprefix(f"{remote}/")
    spr = os.path.join(repo, ".spr.yml")
    if os.path.exists(spr):
        with open(spr, encoding="utf-8") as fh:
            match = re.search(r"^githubBranch:\s*(\S+)\s*$", fh.read(), re.MULTILINE)
        if match:
            return match.group(1)
    for name in ("main", "master"):
        if git_ok(repo, "rev-parse", "--verify", "--quiet", f"refs/remotes/{remote}/{name}"):
            return name
    raise GitError("cannot resolve the trunk branch; pass --trunk")


def fetch_prs(repo, trunk):
    """All PRs, keyed by head branch, plus open PRs keyed by title.

    Returns None when gh cannot answer -- callers must then treat open-PR
    protection as unavailable rather than as "no open PR".
    """
    proc = subprocess.run(
        (
            "gh", "pr", "list", "--state", "all", "--limit", "200",
            "--json", "number,state,headRefName,url,title",
        ),
        cwd=repo,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None
    try:
        prs = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    by_head, open_by_title = {}, {}
    for pr in prs:
        by_head.setdefault(pr["headRefName"], []).append(pr)
        if pr["state"] == "OPEN":
            open_by_title.setdefault(pr["title"].strip(), []).append(pr)
    return {"by_head": by_head, "open_by_title": open_by_title, "trunk": trunk}


def lookup_prs(repo, index, branch, commit_ids, subjects):
    """Associate PRs with a worktree.

    Matches the branch name, then `spr/<trunk>/<commit-id>` for every commit-id
    trailer (spr's PR head branch never carries the local branch name), then
    open PR titles against commit subjects -- a regenerated commit-id would
    otherwise hide a live open PR.
    """
    heads = []
    if branch:
        heads.append(branch)
    heads += [f"spr/{index['trunk']}/{cid}" for cid in commit_ids]

    matched, seen = [], set()
    for head in heads:
        for pr in index["by_head"].get(head, []):
            if pr["number"] not in seen:
                seen.add(pr["number"])
                matched.append(pr)

    # The bulk list is capped at 200; ask directly before concluding "no PR".
    if not matched and branch:
        proc = subprocess.run(
            (
                "gh", "pr", "list", "--head", branch, "--state", "all",
                "--json", "number,state,headRefName,url,title",
            ),
            cwd=repo,
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0:
            try:
                for pr in json.loads(proc.stdout):
                    if pr["number"] not in seen:
                        seen.add(pr["number"])
                        matched.append(pr)
            except json.JSONDecodeError:
                pass

    for subject in subjects:
        for pr in index["open_by_title"].get(subject.strip(), []):
            if pr["number"] not in seen:
                seen.add(pr["number"])
                matched.append(pr)
    return matched


def ls_tree(cwd, rev, paths):
    """Map path -> "<mode> <type> <sha>" for `paths` at `rev`.

    Compares tree entries rather than blob bytes so gitlinks and symlinks are
    judged by what they point at, not by a byte-diff that cannot see it.
    """
    out = {}
    # Argument lists are bounded to keep long path lists off the command line.
    for i in range(0, len(paths), 200):
        chunk = paths[i : i + 200]
        for line in git(cwd, "ls-tree", "-r", "--full-tree", rev, "--", *chunk).splitlines():
            meta, _, path = line.partition("\t")
            out[path] = meta
    return out


def landed_evidence(wt, head, mb, trunk_ref, allow_content):
    """Which landed checks fire, strongest first."""
    evidence = []

    if git_ok(wt, "merge-base", "--is-ancestor", head, trunk_ref):
        evidence.append("ancestor")

    # `git cherry <upstream> <head>` marks '-' for commits whose patch-id is
    # already upstream: the whole range must be accounted for, not just one
    # commit, or a stacked commit with no PR of its own rides along.
    #
    # It also skips merge commits outright, so a conflict resolution or a file
    # added while merging is invisible to it and the range reads as fully
    # landed. Merges disqualify this check; the tree-based ones below don't
    # share the blind spot.
    has_merge = bool(git(wt, "rev-list", "--merges", f"{mb}..{head}", check=False).strip())
    cherry = git(wt, "cherry", trunk_ref, head, check=False).splitlines()
    if not has_merge and cherry and all(line.startswith("-") for line in cherry):
        evidence.append("patch-id")

    # A squash merge collapses the range into one patch-id that matches none of
    # the individual commits, so probe with a single synthetic commit.
    try:
        tree = git(wt, "rev-parse", f"{head}^{{tree}}").strip()
        probe = git(wt, "commit-tree", tree, "-p", mb, "-m", "squash-probe", env=PROBE_ENV).strip()
        squash = git(wt, "cherry", trunk_ref, probe, check=False).splitlines()
        if squash and all(line.startswith("-") for line in squash):
            evidence.append("squash")
    except GitError:
        pass

    if allow_content and not evidence:
        paths = [p for p in git(wt, "diff", "--name-only", mb, head).splitlines() if p]
        if paths and ls_tree(wt, head, paths) == ls_tree(wt, trunk_ref, paths):
            evidence.append("content")

    return evidence


def orphan_reflog(wt, head, trunk_ref):
    """Commits in this worktree's reflog reachable from neither HEAD nor trunk.

    HEAD's reflog is per-worktree and dies with the directory, so a commit that
    a `reset --hard` orphaned has no other pointer. Amends produce these
    routinely, so this is advisory, not a blocker.
    """
    shas = []
    for sha in git(wt, "reflog", "show", "HEAD", "--format=%H", check=False).splitlines():
        if sha and sha not in shas:
            shas.append(sha)
    if not shas:
        return 0
    out = git(wt, "rev-list", "--no-walk", *shas[:200], "--not", head, trunk_ref, check=False)
    return len([line for line in out.splitlines() if line])


def new_row(entry, pr_index):
    path = entry.get("path", "?")
    return {
        "path": path,
        "name": os.path.basename(path),
        "branch": entry.get("branch"),
        "head": entry.get("head"),
        "verdict": None,
        "reason": "",
        "evidence": [],
        "ignored": [],
        "ignored_count": 0,
        "reflog_orphans": 0,
        "stash": 0,
        "prs": [],
        "pr_data": pr_index is not None,
        "pr_uncertain": False,
    }


def audit_worktree(entry, repo, main_path, cwd, trunk, trunk_ref, pr_index, allow_content):
    row = new_row(entry, pr_index)

    def verdict(name, reason):
        row["verdict"], row["reason"] = name, reason
        return row

    if entry.get("bare"):
        return verdict("SKIP", "bare repository")
    real = os.path.realpath(entry["path"])
    if real == os.path.realpath(main_path):
        return verdict("SKIP", "main worktree")
    if cwd == real or cwd.startswith(real + os.sep):
        return verdict("SKIP", "this session is working here")
    if "prunable" in entry:
        return verdict("PRUNABLE", entry["prunable"])
    if "locked" in entry:
        return verdict("SKIP", f"locked: {entry['locked']}")
    # In a bare-repo + linked-worktrees layout there is no "main worktree" to
    # match on, so the trunk's own checkout would otherwise land in EMPTY.
    if entry.get("branch") == trunk:
        return verdict("SKIP", f"holds the trunk branch ({trunk})")

    wt = entry["path"]
    head = entry["head"]
    branch = entry.get("branch")

    status = git(wt, "status", "--porcelain").strip()
    in_progress = [
        name
        for name in IN_PROGRESS_PATHS
        if os.path.exists(git(wt, "rev-parse", "--git-path", name).strip())
    ]

    # `status --porcelain` excludes ignored files, but `worktree remove` deletes
    # them anyway -- name them so a human sees what removal actually destroys.
    for line in git(wt, "status", "--porcelain", "--ignored", check=False).splitlines():
        if line.startswith("!! "):
            row["ignored"].append(line[3:])
    row["ignored_count"] = len(row["ignored"])
    row["ignored"] = row["ignored"][:MAX_LISTED_IGNORED]

    if branch:
        stashes = git(repo, "stash", "list", "--format=%gs", check=False).splitlines()
        row["stash"] = sum(1 for line in stashes if f" {branch}:" in line or line.endswith(f" {branch}"))

    if status:
        return verdict("DIRTY", f"{len(status.splitlines())} uncommitted change(s)")
    if in_progress:
        return verdict("DIRTY", f"{', '.join(in_progress)} in progress")
    if row["stash"]:
        return verdict("DIRTY", f"{row['stash']} stash entr(y/ies) name this branch")

    mb = git(wt, "merge-base", head, trunk_ref).strip()
    if mb == head:
        return verdict("EMPTY", "no commits of its own")

    row["reflog_orphans"] = orphan_reflog(wt, head, trunk_ref)

    body = git(wt, "log", f"{mb}..{head}", "--format=%B")
    commit_ids = COMMIT_ID_RE.findall(body)
    subjects = git(wt, "log", f"{mb}..{head}", "--format=%s").splitlines()

    if pr_index is not None:
        row["prs"] = [
            {k: pr[k] for k in ("number", "state", "url", "title")}
            for pr in lookup_prs(repo, pr_index, branch, commit_ids, subjects)
        ]
        # A commit-id trailer with no PR behind it means the local trailer and
        # the live PR have drifted; the PR picture is incomplete, not empty.
        row["pr_uncertain"] = bool(commit_ids) and not row["prs"]

    open_prs = [pr for pr in row["prs"] if pr["state"] == "OPEN"]
    if open_prs:
        return verdict("KEEP_PR", ", ".join(f"PR #{pr['number']} open" for pr in open_prs))

    row["evidence"] = landed_evidence(wt, head, mb, trunk_ref, allow_content)
    merged = [pr for pr in row["prs"] if pr["state"] == "MERGED"]
    pr_note = ", ".join(f"PR #{pr['number']} merged" for pr in merged)

    strong = [e for e in row["evidence"] if e != "content"]
    if strong:
        return verdict("LANDED", ", ".join(filter(None, ["/".join(strong), pr_note])))
    if "content" in row["evidence"]:
        return verdict("LANDED?", "content matches trunk, no matching patch")

    closed = [pr for pr in row["prs"] if pr["state"] == "CLOSED"]
    if closed:
        return verdict("PR_CLOSED", ", ".join(f"PR #{pr['number']} closed unmerged" for pr in closed))
    ahead = len(subjects)
    return verdict("UNLANDED", f"{ahead} commit(s) not on {trunk_ref}")


def extras(row):
    bits = []
    if row["ignored_count"]:
        bits.append(f"ignored:{row['ignored_count']}")
    if row["reflog_orphans"]:
        bits.append(f"reflog:{row['reflog_orphans']}")
    if row["stash"]:
        bits.append(f"stash:{row['stash']}")
    if row["pr_uncertain"]:
        bits.append("pr:?")
    return " ".join(bits)


def elide(text, limit):
    return text if len(text) <= limit else text[: limit - 1] + "…"


def render(rows, trunk_ref, pr_state):
    cols = ("WORKTREE", "BRANCH", "VERDICT", "WHY", "EXTRAS")
    table = [
        (
            elide(row["name"], 40),
            elide(row["branch"] or "(detached)", 40),
            row["verdict"],
            row["reason"],
            extras(row),
        )
        for row in rows
    ]
    widths = [max(len(c), *(len(r[i]) for r in table)) if table else len(c) for i, c in enumerate(cols)]

    lines = [f"Worktrees audited against {trunk_ref}", ""]
    if pr_state != "ok":
        why = "gh returned no PR data" if pr_state == "failed" else "PR lookup skipped (--no-gh)"
        lines += [f"!! {why} -- open-PR protection is OFF for this run.", ""]
    lines.append("  ".join(c.ljust(w) for c, w in zip(cols, widths)).rstrip())
    lines.append("  ".join("-" * w for w in widths).rstrip())
    for r in table:
        lines.append("  ".join(v.ljust(w) for v, w in zip(r, widths)).rstrip())

    candidates = [r for r in rows if r["verdict"] in ("LANDED", "LANDED?", "EMPTY")]
    lines += ["", f"{len(candidates)} removal candidate(s); everything else stays."]
    for row in candidates:
        if row["ignored_count"]:
            shown = ", ".join(row["ignored"])
            more = "" if row["ignored_count"] <= MAX_LISTED_IGNORED else f", +{row['ignored_count'] - MAX_LISTED_IGNORED} more"
            lines.append(f"  {row['name']}: removal also deletes ignored file(s): {shown}{more}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", default=".", help="repository to audit (default: cwd)")
    parser.add_argument("--trunk", help="trunk branch name (default: autodetected)")
    parser.add_argument("--no-fetch", action="store_true", help="skip refreshing the trunk ref")
    parser.add_argument("--no-gh", action="store_true", help="skip PR lookup entirely")
    parser.add_argument("-o", "--json-out", help="also write the audit as JSON to this path")
    args = parser.parse_args()

    try:
        # A bare repo has no toplevel but still owns linked worktrees.
        repo = git(args.repo, "rev-parse", "--show-toplevel", check=False).strip()
        if not repo:
            common = git(args.repo, "rev-parse", "--git-common-dir").strip()
            repo = os.path.abspath(os.path.join(args.repo, common))
        remote = resolve_remote(repo, required=not args.trunk)
        if remote:
            trunk = resolve_trunk(repo, remote, args.trunk)
            trunk_ref = f"{remote}/{trunk}"
            if not args.no_fetch:
                git(repo, "fetch", "--quiet", remote, trunk, check=False)
        else:
            trunk = trunk_ref = args.trunk
        # A bare clone keeps its branches as local refs, with no remote-tracking
        # copy to prefix, so fall back to the bare name before giving up.
        if not git_ok(repo, "rev-parse", "--verify", "--quiet", trunk_ref):
            if git_ok(repo, "rev-parse", "--verify", "--quiet", trunk):
                trunk_ref = trunk
            else:
                raise GitError(f"{trunk_ref} does not exist")
        entries = parse_worktrees(git(repo, "worktree", "list", "--porcelain"))
    except (GitError, FileNotFoundError) as err:
        print(f"audit-worktrees: {err}", file=sys.stderr)
        return 2

    # A byte-match against a stale trunk says nothing about the real tip, so the
    # weakest check is withdrawn rather than trusted when the fetch is skipped.
    allow_content = not args.no_fetch
    pr_index = None if args.no_gh else fetch_prs(repo, trunk)
    pr_state = "skipped" if args.no_gh else ("ok" if pr_index else "failed")
    main_path = entries[0]["path"] if entries else repo
    cwd = os.path.realpath(os.getcwd())

    rows = []
    for entry in entries:
        try:
            rows.append(
                audit_worktree(
                    entry, repo, main_path, cwd, trunk, trunk_ref, pr_index, allow_content
                )
            )
        except Exception as err:  # one bad worktree must not sink the audit
            row = new_row(entry, pr_index)
            row["verdict"], row["reason"] = "ERROR", str(err)[:120]
            rows.append(row)

    print(render(rows, trunk_ref, pr_state))
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(rows, fh, indent=2)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
