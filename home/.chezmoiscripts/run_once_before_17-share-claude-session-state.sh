#!/usr/bin/env bash
# Fold the per-account Claude Code stores back into ~/.claude so both logins share one set
# of conversations, memory and history.
#
# The earlier split gave each account its own projects/, sessions/ and history, which meant
# a conversation started under one login was invisible to the other. ~/.claude is the
# shared root already (CLAUDE.md, skills/), so it becomes the single store for session
# state too and each account dir symlinks into it -- those symlinks are chezmoi entries
# written right after this script.
#
# run_BEFORE_ on purpose: chezmoi cannot write a symlink over a 58M real directory, so the
# merge and the move-aside have to happen before it writes files. Do not "fix" this to
# run_once_after_.
#
# Nothing is deleted. Drained copies move to ~/.claude-split-backup-<stamp>/ for the user
# to remove once satisfied; a merge that silently loses a transcript is unrecoverable.
set -euo pipefail

shared="$HOME/.claude"
accounts="$HOME/.claude-personal $HOME/.claude-work"

# Everything session-shaped. Deliberately excludes .claude.json (fuses oauthAccount with
# the project list), .credentials.json, and the org-pushed policy-limits.json /
# remote-settings.json -- sharing those would collapse the account boundary.
paths="projects sessions session-env history.jsonl file-history plans tasks teams
       shell-snapshots paste-cache settings.json settings.local.json"

[ -d "$shared" ] || exit 0

# Only real paths need draining; once they are symlinks this has already run.
needs_merge=0
for acct in $accounts; do
	for p in $paths; do
		if [ -e "$acct/$p" ] && [ ! -L "$acct/$p" ]; then needs_merge=1; break 2; fi
	done
done
[ "$needs_merge" -eq 1 ] || exit 0

stamp=$(date +%Y%m%d%H%M%S)
backup="$HOME/.claude-split-backup-$stamp"

# Union one tree into the shared store. Transcripts are per-session UUIDs, so paths rarely
# collide; when they do the newer copy is the fuller one, since Claude Code only appends.
merge_tree() {
	src=$1
	dst=$2
	find "$src" -type f | while IFS= read -r f; do
		rel=${f#"$src"/}
		target="$dst/$rel"
		if [ ! -e "$target" ] || [ "$f" -nt "$target" ]; then
			mkdir -p "$(dirname "$target")"
			cp -p "$f" "$target"
		fi
	done
}

# history.jsonl is the one file every store writes to, so newest-wins would silently drop
# the loser's prompts wholesale -- it is an append-only log, not a snapshot. Union by line
# instead, first occurrence winning so the existing order survives.
merge_log() {
	src=$1
	dst=$2
	if [ ! -f "$dst" ]; then
		cp -p "$src" "$dst"
		return
	fi
	tmp=$(mktemp)
	cat "$dst" "$src" | awk '!seen[$0]++' > "$tmp"
	cat "$tmp" > "$dst"   # preserve the inode: live sessions hold this file open
	rm -f "$tmp"
}

for acct in $accounts; do
	[ -d "$acct" ] || continue
	name=${acct##*/.claude-}
	for p in $paths; do
		src="$acct/$p"
		[ -e "$src" ] && [ ! -L "$src" ] || continue

		if [ -d "$src" ]; then
			mkdir -p "$shared/$p"
			merge_tree "$src" "$shared/$p"
		elif [ "$p" = "history.jsonl" ]; then
			merge_log "$src" "$shared/$p"
		elif [ ! -e "$shared/$p" ] || [ "$src" -nt "$shared/$p" ]; then
			cp -p "$src" "$shared/$p"
		fi

		mkdir -p "$backup/$name"
		mv "$src" "$backup/$name/$p"
	done
done

if [ -d "$backup" ]; then
	echo "shared: session state merged into ~/.claude; drained copies in $backup"
fi
