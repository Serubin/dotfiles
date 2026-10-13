#!/usr/bin/env python3
"""Rank past Claude Code sessions against a ticket, PR, branch, title, or loose description.

usage: find-session.py QUERY... [--deep] [--days N] [--project SUBSTR] [--limit N] [--json]
       find-session.py --show SESSION_ID [--prompts N]
"""

import argparse
import collections
import datetime
import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys

UUID_RE = re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", re.I)
SID_PREFIX_RE = re.compile(r"^(?=[0-9a-f-]*\d)[0-9a-f]{8}(?:-[0-9a-f-]{0,27})?$")
CVE_RE = re.compile(r"(?<![A-Za-z0-9])CVE-\d{4}-\d{4,}(?!\d)", re.I)
TICKET_RE = re.compile(r"(?<![A-Za-z0-9])([A-Za-z][A-Za-z0-9]{1,9})-(\d+)(?![A-Za-z0-9])")
PR_RE = re.compile(r"(?:#|/pull/)(\d{3,})\b|(?<![\w.-])(\d{4,})(?![\w.-])")
YEAR_RE = re.compile(r"^(19|20)\d\d$")
# A lowercase key counts as a ticket only for these projects, so `rhel-9` stays a plain term.
KNOWN_PROJECTS = {"VULN", "LINK", "SEV", "RAIN", "ANEP", "AWLS2", "OPS", "LH", "ECO", "ECOHELP",
                  "PRES", "PSIRT", "INFRA"}
NOT_TICKETS = {"SHA", "UTF", "AES", "RFC", "ISO", "TLS", "SSL", "MD", "HTTP", "PEP", "ES",
               "RSA", "ECDSA", "UTC", "GMT", "IPV", "X", "BASE", "SEC", "PKCS", "CWE"}
STOPWORDS = set("""a an and are as at be by did do does for from had has have how i in into is it
its me my of on or our session sessions that the then this to was we were what when where which
while who why with work worked working one about find look looking resume chat conversation""".split())

# Weight per matched (identifier, plain term) by where it matched; deep is further log-scaled.
W = {"struct": (100, 30), "memory": (60, 20), "first": (40, 12), "prompt": (20, 6), "deep": (15, 5)}
DEEP_CAP = 25
MAX_PROMPTS = 20
MAX_PROMPT_CHARS = 20000

WANTED_HEAD = re.compile(rb'"type":"(user|custom-title|ai-title|last-prompt|pr-link|'
                         rb'worktree-state|relocated|continued-in)"')
TAIL_CWD = re.compile(rb'"cwd":"((?:[^"\\]|\\.)*)"')
TAIL_BRANCH = re.compile(rb'"gitBranch":"((?:[^"\\]|\\.)*)"')
TAIL_TS = re.compile(rb'"timestamp":"(\d{4}-\d\d-\d\dT[\d:.]+Z?)"')
WRAPPED = re.compile(r"^\s*<(task-notification|local-command-stdout|local-command-stderr|"
                     r"local-command-caveat|bash-stdout|bash-stderr|system-reminder)\b")
REMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.S)
CMD_NAME = re.compile(r"<command-name>\s*/?([^<\s]+)\s*</command-name>")
CMD_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)

SECRET_VALUE = r"(?:\"[^\"]*\"|'[^']*'|[^\s'\",}]+)"
REDACTIONS = [
    (re.compile(r"-----BEGIN [A-Z ]+-----.*?(?:-----END [A-Z ]+-----|$)", re.S), "[REDACTED-PEM]"),
    (re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"), "[REDACTED]"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"), "[REDACTED]"),
    (re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"), "[REDACTED]"),
    (re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"), "[REDACTED]"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*"), "[REDACTED-JWT]"),
    (re.compile(r"\b([a-z][a-z0-9+.-]*://[^/\s:@]+:)[^@\s/]+@"), r"\1[REDACTED]@"),
    (re.compile(r"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}"), r"\1 [REDACTED]"),
    (re.compile(r"(?i)\b([A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSWD|PWD|CREDENTIALS?)"
                r"[A-Z0-9_]*[\"']?\s*[:=]\s*)" + SECRET_VALUE), r"\1[REDACTED]"),
    (re.compile(r"(?i)\b(password\s+)(?![:=])" + SECRET_VALUE), r"\1[REDACTED]"),
    (re.compile(r"(?<!\S)-p(?=\S{4,})\S+"), "-p[REDACTED]"),
    (re.compile(r"(?<![0-9a-fA-F])[0-9a-fA-F]{32,}(?![0-9a-fA-F])"), "[REDACTED-HEX]"),
    (re.compile(r"(?<![A-Za-z0-9+/_-])(?=[A-Za-z0-9+/_-]*\d)(?=[A-Za-z0-9+/_-]*[A-Z])"
                r"(?=[A-Za-z0-9+/_-]*[a-z])[A-Za-z0-9+/_-]{24,}={0,2}"), "[REDACTED-B64]"),
]

Item = collections.namedtuple("Item", "label kind value rx deep_rx deep_core")


def claude_home():
    home = os.path.expanduser("~/.claude")
    if os.path.isdir(home):
        return home
    return os.environ.get("CLAUDE_CONFIG_DIR") or home


def slug(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def norm(text):
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def redact(text):
    for pattern, repl in REDACTIONS:
        text = pattern.sub(repl, text)
    return text


def clean(text, width=None):
    text = redact(" ".join(text.replace("\\n", " ").split()))
    return text if width is None or len(text) <= width else text[:width] + "…"


def iso_to_epoch(ts):
    try:
        return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def fmt_date(epoch):
    return datetime.datetime.fromtimestamp(epoch).strftime("%Y-%m-%d") if epoch else "?"


def is_self_search(text):
    head = text.lstrip()[:200]
    return head.startswith("/find-session") or "<command-name>/find-session" in head \
        or "<command-name>find-session" in head


def prompt_text(rec):
    """Return the human-typed text of a user record, or None for anything that is not a prompt."""
    if rec.get("isMeta") or rec.get("isCompactSummary") or rec.get("isSidechain") \
            or rec.get("isVisibleInTranscriptOnly"):
        return None
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, list):
        if any(isinstance(p, dict) and p.get("type") == "tool_result" for p in content):
            return None
        content = "\n".join(p.get("text", "") for p in content
                            if isinstance(p, dict) and p.get("type") == "text")
    if not isinstance(content, str) or WRAPPED.match(content):
        return None
    name = CMD_NAME.search(content)
    if name:
        args = CMD_ARGS.search(content)
        content = "/" + name.group(1) + (" " + args.group(1).strip() if args else "")
    content = REMINDER.sub("", content).strip()
    if not content or content.startswith("[Request interrupted") or is_self_search(content):
        return None
    return content[:MAX_PROMPT_CHARS]


def index_session(path):
    s = {"id": os.path.basename(path)[:-6], "path": path,
         "folder": os.path.basename(os.path.dirname(path)), "titles": [], "worktrees": [],
         "branches": [], "prs": {}, "prompts": [], "last_prompts": [], "last_prompt": None,
         "cwds": [], "first_ts": None, "last_ts": None, "turns": 0, "continued_in": None}

    def add(lst, value):
        if value and value not in lst:
            lst.append(value)

    with open(path, "rb") as fh:
        for line in fh:
            tail = line[-3000:]
            for rx, key in ((TAIL_CWD, "cwds"), (TAIL_BRANCH, "branches")):
                m = rx.search(tail)
                if m:
                    add(s[key], m.group(1).decode("utf-8", "replace"))
            m = TAIL_TS.search(tail)
            if m:
                ts = iso_to_epoch(m.group(1).decode())
                if ts:
                    s["first_ts"] = s["first_ts"] or ts
                    s["last_ts"] = ts
            m = WANTED_HEAD.search(line[:400])
            if not m or (m.group(1) == b"user" and b'"tool_result"' in line):
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            rtype = rec.get("type")
            if rtype == "user":
                text = prompt_text(rec)
                if text:
                    s["turns"] += 1
                    if len(s["prompts"]) < MAX_PROMPTS:
                        s["prompts"].append(text)
                    s["last_prompts"] = (s["last_prompts"] + [text])[-3:]
            elif rtype == "custom-title":
                add(s["titles"], rec.get("customTitle"))
            elif rtype == "ai-title":
                add(s["titles"], rec.get("aiTitle"))
            elif rtype == "last-prompt":
                lp = rec.get("lastPrompt")
                if lp and not is_self_search(lp):
                    s["last_prompt"] = lp
            elif rtype == "pr-link" and rec.get("prNumber"):
                s["prs"][str(rec["prNumber"])] = {"repo": rec.get("prRepository"),
                                                 "url": rec.get("prUrl")}
            elif rtype == "worktree-state":
                wt = rec.get("worktreeSession") or {}
                add(s["worktrees"], wt.get("worktreeName"))
                add(s["branches"], wt.get("worktreeBranch"))
                add(s["cwds"], wt.get("worktreePath"))
                add(s["cwds"], wt.get("originalCwd"))
            elif rtype == "relocated":
                add(s["cwds"], rec.get("relocatedCwd"))
            elif rtype == "continued-in":
                s["continued_in"] = rec.get("continuedInSessionId")

    s["last_ts"] = s["last_ts"] or os.path.getmtime(path)
    s["first_ts"] = s["first_ts"] or s["last_ts"]
    s["title"] = s["titles"][-1] if s["titles"] else None
    resume = next((c for c in s["cwds"] if slug(c) == s["folder"]), None)
    s["resume_dir"] = resume or (s["cwds"][0] if s["cwds"] else None)
    s["resume_dir_certain"] = resume is not None
    s["resume_dir_exists"] = bool(s["resume_dir"]) and os.path.isdir(s["resume_dir"])
    return s


def resume_line(s):
    cmd = f"claude --resume {s['id']}"
    if not s["resume_dir"]:
        return cmd + "  (no working dir recorded; run from the original project)"
    note = "" if s["resume_dir_exists"] else "  (dir no longer exists)"
    if not s["resume_dir_certain"]:
        note += "  (dir inferred, not confirmed)"
    return f"cd {s['resume_dir']} && {cmd}{note}"


def term_pattern(term):
    """Separator-tolerant core, so `autoincrement` also finds auto-increment and AutoIncrement."""
    return r"[-_ ./]?".join(re.escape(c) for c in term)


def make_item(kind, value):
    if kind == "term":
        core = term_pattern(value)
        rx = re.compile(r"(?<![a-z0-9])" + core, re.I)
        return Item(value, kind, value, rx, rx.pattern, core)
    if kind == "ticket":
        prefix, num = value.split("-")
        core = rf"{re.escape(prefix)}[-_ ]?{num}"
    elif kind == "cve":
        core = re.escape(value)
    elif kind == "pr":
        core = rf"(?:#|/pull/){value}"
    else:
        core = re.escape(value)
    text_rx = rf"(?<![A-Za-z0-9]){core}(?!\d)"
    if kind == "pr":
        text_rx = rf"(?:#|/pull/|\bPR\s*#?){value}\b"
        if len(value) >= 4:
            text_rx += rf"|(?<![\w.-]){value}(?![\w.-])"
    deep_rx = rf"(?:#|/pull/){value}\b" if kind == "pr" else rf"(?<![A-Za-z0-9]){core}(?!\d)"
    return Item(f"{kind}:{value}", kind, value, re.compile(text_rx, re.I), deep_rx, core)


def parse_query(words):
    rest = " ".join(words)
    items = []
    for m in UUID_RE.finditer(rest):
        items.append(make_item("session", m.group(0).lower()))
    rest = UUID_RE.sub(" ", rest)
    for m in CVE_RE.finditer(rest):
        items.append(make_item("cve", m.group(0).upper()))
    rest = CVE_RE.sub(" ", rest)
    for m in TICKET_RE.finditer(rest):
        prefix = m.group(1)
        if prefix.upper() in NOT_TICKETS or not (prefix.isupper() or prefix.upper() in KNOWN_PROJECTS):
            continue
        items.append(make_item("ticket", f"{prefix.upper()}-{m.group(2)}"))
        rest = rest.replace(m.group(0), " ")
    for m in PR_RE.finditer(rest):
        num = m.group(1) or m.group(2)
        if m.group(2) and YEAR_RE.match(num):
            continue
        items.append(make_item("pr", num))
        rest = rest.replace(m.group(0), " ", 1)
    for tok in rest.split():
        tok = tok.strip(".,;:!?()[]{}'\"`#")
        if SID_PREFIX_RE.match(tok.lower()):
            items.append(make_item("session", tok.lower()))
            continue
        n = norm(tok)
        if len(n) >= 3 and tok.lower() not in STOPWORDS and n not in {i.value for i in items}:
            items.append(make_item("term", n))
    seen, unique = set(), []
    for it in items:
        if it.label not in seen:
            seen.add(it.label)
            unique.append(it)
    return unique


class Matcher:
    def __init__(self, items):
        self.items = items

    def hits(self, text, idents_only=False):
        """Labels of the query items found in text."""
        if not text:
            return set()
        spaced = None
        found = set()
        for it in self.items:
            if it.kind == "term":
                if idents_only:
                    continue
                spaced = spaced or re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text)
                if it.rx.search(spaced) or (len(it.value) >= 6 and it.value in norm(text)):
                    found.add(it.label)
            elif it.rx.search(text):
                found.add(it.label)
        return found


def excerpt(text, matcher, width=200):
    text = clean(text)
    pos = next((m.start() for m in (it.rx.search(text) for it in matcher.items) if m), 0)
    start = max(0, pos - width // 3)
    snippet = text[start:start + width]
    return ("…" if start else "") + snippet + ("…" if start + width < len(text) else "")


def deep_counts(files, matcher):
    """Map file path -> {label: matching line count}, ignoring injected CLAUDE.md/memory/skill text."""
    candidates = {}
    rg = shutil.which("rg")
    for it in matcher.items:
        if rg:
            proc = subprocess.run([rg, "-l", "-i", "--no-messages", "-e", it.deep_core, "--", *files],
                                  capture_output=True, text=True)
            paths = proc.stdout.splitlines()
        else:
            paths = files
        for p in paths:
            candidates.setdefault(p, []).append(it)
    counts = {}
    for path, items in candidates.items():
        rxs = [(it.label, re.compile(it.deep_rx.encode(), re.I)) for it in items]
        with open(path, "rb") as fh:
            for line in fh:
                if b'"attachment":{' in line[:400] or b'"isMeta":true' in line:
                    continue
                for label, rx in rxs:
                    if rx.search(line):
                        c = counts.setdefault(path, {})
                        c[label] = c.get(label, 0) + 1
    return counts


def is_ident(label):
    return ":" in label


def score(matcher, struct, prompts, memories, deep, turns):
    """Score one session's evidence; struct is [(field, labels)], memories is {name: (head, body)}."""
    per_label, fields, excerpts = {}, {}, []

    def credit(labels, tier, field):
        for label in labels:
            w = W[tier][0 if is_ident(label) else 1]
            if w > per_label.get(label, (0, ""))[0]:
                per_label[label] = (w, tier)
        if labels:
            f = fields.setdefault(field, [set(), 0])
            f[0] |= labels
            f[1] += 1

    for field, labels in struct:
        credit(labels, "struct", field)
    for name, (head, body) in (memories or {}).items():
        credit(head, "memory", f"memory {name}")
        credit(body - head, "prompt", f"memory {name} (body)")
    for i, p in enumerate(prompts):
        labels = matcher.hits(p)
        if labels:
            credit(labels, "first" if i == 0 else "prompt", "first prompt" if i == 0 else "prompts")
            if len(excerpts) < 2:
                excerpts.append(excerpt(p, matcher))

    deep_total, deep_why = 0.0, []
    for label, n in (deep or {}).items():
        if label not in per_label:
            deep_total += W["deep"][0 if is_ident(label) else 1] * \
                min(1.0, math.log2(1 + n) / math.log2(21))
            deep_why.append(f"{label} in {n} full-text lines")
    matched = set(per_label) | set(deep or {})
    if not matched:
        return None
    total = sum(w for w, _ in per_label.values()) + min(deep_total, DEEP_CAP)
    total += 10 * len(matched) / max(1, len(matcher.items))
    total += min(6, 2 * (len(fields) + len(deep_why) - 1)) + min(4, math.log2(1 + turns))
    tiers = {t for _, t in per_label.values()}
    tier = next((name for key, name in (("struct", "structural"), ("memory", "memory"))
                 if key in tiers), "prompt" if tiers else "full-text")
    why = [f"{', '.join(sorted(labels))} in {field}" + (f" ×{n}" if n > 1 else "")
           for field, (labels, n) in fields.items()] + deep_why
    return {"score": round(total, 1), "tier": tier, "why": why, "excerpts": excerpts,
            "matched": sorted(matched)}


def score_session(s, matcher, deep, history_prompts, memories):
    struct = [("title", matcher.hits(s["title"]))]
    struct += [("earlier title", matcher.hits(t)) for t in s["titles"][:-1]]
    struct += [("worktree", matcher.hits(" ".join(s["worktrees"]))),
               ("branch", matcher.hits(" ".join(s["branches"]))),
               ("project dir", matcher.hits(s["folder"], idents_only=True))]
    pr_hits = {it.label for it in matcher.items if it.kind == "pr" and it.value in s["prs"]}
    pr_hits |= matcher.hits(" ".join(f"{p['repo']} {p['url']}" for p in s["prs"].values()))
    struct.append(("PR link", pr_hits))
    struct.append(("session id", {it.label for it in matcher.items
                                  if it.kind == "session" and s["id"].startswith(it.value)}))
    prompts = s["prompts"] + [p for p in history_prompts if p not in s["prompts"]]
    if s["last_prompt"]:
        prompts.append(s["last_prompt"])
    return score(matcher, struct, prompts, memories, deep, s["turns"])


def memory_hits(home, matcher):
    """Map originSessionId -> {memory name: (labels in name/description, labels in body)}."""
    hits = {}
    for path in glob.glob(os.path.join(home, "projects", "*", "memory", "*.md")):
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        sid = re.search(r"^\s*originSessionId:\s*([0-9a-f-]{36})", text, re.M)
        if not sid:
            continue
        name = os.path.basename(path)[:-3]
        head = " ".join([name] + re.findall(r"^(?:name|description):\s*(.*)$", text, re.M))
        head_hits = matcher.hits(head)
        body_hits = head_hits | matcher.hits(text, idents_only=True)
        if body_hits:
            hits.setdefault(sid.group(1), {})[name] = (head_hits, body_hits)
    return hits


def load_history(home, exclude):
    by_session = {}
    path = os.path.join(home, "history.jsonl")
    if not os.path.exists(path):
        return by_session
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            text = rec.get("display") or ""
            if not text or is_self_search(text):
                continue
            sid = rec.get("sessionId") or f"no-session-{rec.get('timestamp')}"
            if sid == exclude:
                continue
            h = by_session.setdefault(sid, {"prompts": [], "project": rec.get("project"),
                                            "ts": []})
            h["prompts"].append(text[:MAX_PROMPT_CHARS])
            if isinstance(rec.get("timestamp"), (int, float)):
                h["ts"].append(rec["timestamp"] / 1000)
    return by_session


def transcript_files(home, exclude):
    files = glob.glob(os.path.join(home, "projects", "*", "*.jsonl"))
    return [f for f in files if os.path.basename(f)[:-6] != exclude]


def public(s, result):
    return {"id": s["id"], "path": s["path"], "title": clean(s["title"] or ""),
            "titles": [clean(t) for t in s["titles"]], "score": result["score"],
            "tier": result["tier"], "why": result["why"], "excerpts": result["excerpts"],
            "first_active": fmt_date(s["first_ts"]), "last_active": fmt_date(s["last_ts"]),
            "turns": s["turns"], "worktrees": [clean(w) for w in s["worktrees"]],
            "branches": [clean(b) for b in s["branches"][:6]],
            "prs": [f"{p['repo']}#{n}" for n, p in s["prs"].items()],
            "continued_in": s["continued_in"], "resume_dir": s["resume_dir"],
            "resume_dir_exists": s["resume_dir_exists"], "resume": resume_line(s)}


def search(args, home, exclude):
    items = parse_query(args.query)
    if not items:
        sys.exit("find-session: nothing searchable in the query (terms need 3+ ASCII "
                 "letters/digits and must not be stopwords)")
    matcher = Matcher(items)
    files = transcript_files(home, exclude)
    history = load_history(home, exclude)
    deep = deep_counts(files, matcher) if args.deep else {}
    memories = memory_hits(home, matcher)
    cutoff = None if args.days is None else datetime.datetime.now().timestamp() - args.days * 86400

    live, live_ids, oldest = [], set(), None
    for f in files:
        s = index_session(f)
        live_ids.add(s["id"])
        oldest = min(oldest or s["first_ts"], s["first_ts"])
        if cutoff and s["last_ts"] < cutoff:
            continue
        if args.project and args.project.lower() not in \
                f"{s['folder']} {s['resume_dir'] or ''}".lower():
            continue
        r = score_session(s, matcher, deep.get(f),
                          history.get(s["id"], {}).get("prompts", []), memories.get(s["id"]))
        if r:
            live.append(public(s, r) | {"_ts": s["last_ts"]})
    live.sort(key=lambda r: (r["score"], r["_ts"]), reverse=True)

    pruned = []
    for sid in (set(history) | set(memories)) - live_ids - {exclude}:
        h = history.get(sid, {"prompts": [], "project": None, "ts": []})
        last = max(h["ts"], default=None)
        if cutoff and (last is None or last < cutoff):
            continue
        if args.project and args.project.lower() not in (h["project"] or "").lower():
            continue
        r = score(matcher, [], h["prompts"], memories.get(sid), None, len(h["prompts"]))
        if r:
            pruned.append({"id": sid, "project": h["project"], "score": r["score"],
                           "why": r["why"], "first_active": fmt_date(min(h["ts"], default=None)),
                           "last_active": fmt_date(last), "excerpts": r["excerpts"],
                           "_ts": last or 0})
    pruned.sort(key=lambda r: (r["score"], r["_ts"]), reverse=True)

    out = {"query": [it.label for it in items],
           "transcripts_searched": len(files),
           "searchable_since": fmt_date(oldest),
           "sessions": [{k: v for k, v in r.items() if not k.startswith("_")}
                        for r in live[:args.limit]],
           "pruned": [{k: v for k, v in r.items() if not k.startswith("_")}
                      for r in pruned[:args.limit]]}
    if args.json:
        json.dump(out, sys.stdout, indent=1)
        print()
        return
    print_text(out)


def print_text(out):
    print(f"query: {', '.join(out['query'])}  ({out['transcripts_searched']} transcripts, "
          f"since {out['searchable_since']})\n")
    if not out["sessions"]:
        print("No resumable session matched.\n")
    for i, r in enumerate(out["sessions"], 1):
        print(f"{i}. [{r['score']} · {r['tier']}] {r['title'] or '(untitled)'}")
        print(f"   {r['first_active']} → {r['last_active']} · {r['turns']} prompts · {r['id']}")
        if len(r["titles"]) > 1:
            print(f"   earlier titles: {'; '.join(r['titles'][:-1][-4:])}")
        if r["worktrees"]:
            print(f"   worktrees: {', '.join(r['worktrees'])}")
        if r["prs"]:
            print(f"   PRs: {', '.join(r['prs'])}")
        if r["continued_in"]:
            print(f"   continued in: {r['continued_in']}")
        print(f"   matched: {'; '.join(r['why'][:6])}")
        for e in r["excerpts"][:1]:
            print(f"   prompt: {e}")
        print(f"   resume: {r['resume']}\n")
    if out["pruned"]:
        print("Pruned (transcript gone, cannot resume):")
        for r in out["pruned"]:
            print(f"- [{r['score']}] {r['first_active']} → {r['last_active']} · "
                  f"{r['project'] or 'project unknown'} · {r['id']}")
            print(f"  matched: {'; '.join(r['why'][:4])}")
            for e in r["excerpts"][:1]:
                print(f"  prompt: {e}")


def show(args, home):
    files = [f for f in glob.glob(os.path.join(home, "projects", "*", "*.jsonl"))
             if os.path.basename(f).startswith(args.show)]
    if len(files) != 1:
        sys.exit(f"find-session: {len(files)} transcripts match id prefix {args.show!r}")
    s = index_session(files[0])
    print(f"session: {s['id']}")
    print(f"transcript: {s['path']}")
    print(f"titles (oldest → latest): {' | '.join(clean(t) for t in s['titles']) or '-'}")
    print(f"active: {fmt_date(s['first_ts'])} → {fmt_date(s['last_ts'])}, {s['turns']} prompts")
    print(f"worktrees: {', '.join(clean(w) for w in s['worktrees']) or '-'}")
    print(f"branches: {', '.join(clean(b) for b in s['branches'][:10]) or '-'}")
    print(f"PRs: {', '.join(p['url'] or n for n, p in s['prs'].items()) or '-'}")
    if s["continued_in"]:
        print(f"continued in: {s['continued_in']}")
    print(f"resume: {resume_line(s)}")
    print(f"\nfirst {min(args.prompts, len(s['prompts']))} prompts:")
    for p in s["prompts"][:args.prompts]:
        print(f"- {clean(p, 300)}")
    print("\nlast prompts:")
    for p in s["last_prompts"]:
        print(f"- {clean(p, 300)}")


def positive(value):
    n = int(value)
    if n < 1:
        raise argparse.ArgumentTypeError("must be >= 1")
    return n


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("query", nargs="*")
    ap.add_argument("--deep", action="store_true", help="also count raw full-text hits")
    ap.add_argument("--days", type=positive, help="only sessions active in the last N days")
    ap.add_argument("--project", help="substring of the project dir or resume dir")
    ap.add_argument("--limit", type=positive, default=8)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--show", metavar="SESSION_ID")
    ap.add_argument("--prompts", type=positive, default=6)
    args = ap.parse_args()
    home = claude_home()
    if args.show:
        show(args, home)
    elif args.query:
        search(args, home, os.environ.get("CLAUDE_CODE_SESSION_ID"))
    else:
        ap.error("give a QUERY or --show SESSION_ID")


if __name__ == "__main__":
    main()
