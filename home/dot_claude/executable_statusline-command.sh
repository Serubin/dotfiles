#!/usr/bin/env bash
# Claude Code statusLine
# Format: cwd (branch) [tsh:cluster] model ctx:X% period:Y% t:Z%|ink/outk
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""' | grep -oiE 'sonnet|opus|haiku|claude' | head -1 | tr '[:upper:]' '[:lower:]')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

# Compute elapsed% of the 5-hour rate-limit window from resets_at (epoch seconds)
rate_elapsed=""
if [ -n "$resets_at" ]; then
  now=$(date +%s)
  window=18000  # 5 * 3600
  secs_until=$(( resets_at - now ))
  if [ "$secs_until" -lt 0 ]; then secs_until=0; fi
  if [ "$secs_until" -gt "$window" ]; then secs_until=$window; fi
  elapsed_pct=$(( (window - secs_until) * 100 / window ))
  rate_elapsed="$elapsed_pct"
fi

# Get git branch for the current working directory
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  branch_str=$(printf ' \033[00;35m(%s)\033[00m' "$branch")
else
  branch_str=""
fi

# Build context string: model + ctx:X% [period:Y%]
# cyan segment: ctx:X% and optional period:Y%
cyan_parts=""
if [ -n "$used" ]; then
  cyan_parts=$(printf 'ctx:%.0f%%' "$used")
fi
if [ -n "$rate_elapsed" ]; then
  if [ -n "$cyan_parts" ]; then
    cyan_parts=$(printf '%s period:%d%%' "$cyan_parts" "$rate_elapsed")
  else
    cyan_parts=$(printf 'period:%d%%' "$rate_elapsed")
  fi
fi

if [ -n "$cyan_parts" ]; then
  ctx_str=$(printf '\033[00;33m%s\033[00m \033[00;36m%s\033[00m' "$model" "$cyan_parts")
else
  ctx_str=$(printf '\033[00;33m%s\033[00m' "$model")
fi

# cyan token segment: t:[five_hr%|]ink/outk
if [ -n "$total_in" ] && [ -n "$total_out" ]; then
  in_k=$(printf '%.0f' "$(echo "$total_in / 1000" | bc -l)")
  out_k=$(printf '%.0f' "$(echo "$total_out / 1000" | bc -l)")
  if [ -n "$five_hr" ]; then
    ctx_str=$(printf '%s \033[00;36mt:%.0f%%|%sk/%sk\033[00m' "$ctx_str" "$five_hr" "$in_k" "$out_k")
  else
    ctx_str=$(printf '%s \033[00;36mt:%sk/%sk\033[00m' "$ctx_str" "$in_k" "$out_k")
  fi
fi

# Get active tsh cluster
tsh_cluster=$(grep '^cluster:' "$HOME/.tsh/profile.yaml" 2>/dev/null | head -1 | awk '{print $2}')
if [ -n "$tsh_cluster" ]; then
  tsh_str=$(printf ' \033[00;32m[tsh:%s]\033[00m' "$tsh_cluster")
else
  tsh_str=""
fi

home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"
printf '\033[01;34m%s\033[00m%s%s\n%s' "$short_cwd" "$branch_str" "$tsh_str" "$ctx_str"
