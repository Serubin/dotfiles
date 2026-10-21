#!/usr/bin/env bash
# Fold real per-account agents/ dirs into ~/.claude/agents before chezmoi links them there.
set -euo pipefail

# Must stay run_BEFORE_: chezmoi deletes a real directory when it writes a symlink over it.

shared="$HOME/.claude/agents"
accounts="$HOME/.claude-personal $HOME/.claude-work"

needs_merge=0
for acct in $accounts; do
	if [ -d "$acct/agents" ] && [ ! -L "$acct/agents" ]; then needs_merge=1; fi
done
[ "$needs_merge" -eq 1 ] || exit 0

stamp=$(date +%Y%m%d%H%M%S)
backup="$HOME/.claude-split-backup-$stamp"
mkdir -p "$shared"

for acct in $accounts; do
	src="$acct/agents"
	[ -d "$src" ] && [ ! -L "$src" ] || continue
	name=${acct##*/.claude-}
	find "$src" -type f | while IFS= read -r f; do
		rel=${f#"$src"/}
		target="$shared/$rel"
		if [ -e "$target" ] || [ -L "$target" ]; then
			echo "agents: kept shared $rel; the $name copy is in $backup/$name/agents" >&2
		else
			mkdir -p "$(dirname "$target")"
			cp -p "$f" "$target"
		fi
	done
	mkdir -p "$backup/$name"
	mv "$src" "$backup/$name/agents"
done

echo "agents: per-account agents merged into ~/.claude/agents; originals in $backup"
