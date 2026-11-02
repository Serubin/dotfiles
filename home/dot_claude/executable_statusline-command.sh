#!/usr/bin/env bash
# Claude Code statusLine
# Format: cwd (branch) [tsh:cluster] [agent:name] model effort ctx:X% period:Y% t:Z%|ink/outk session
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""' | grep -oiE 'sonnet|opus|haiku|claude' | head -1 | tr '[:upper:]' '[:lower:]')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

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

model_str=$(printf '\033[00;33m%s\033[00m' "$model")
if [ -n "$effort" ]; then
  model_str=$(printf '%s \033[00;90m%s\033[00m' "$model_str" "$effort")
fi

if [ -n "$cyan_parts" ]; then
  ctx_str=$(printf '%s \033[00;36m%s\033[00m' "$model_str" "$cyan_parts")
else
  ctx_str="$model_str"
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

if [ -n "$session_id" ]; then
  ctx_str=$(printf '%s \033[00;90m%s\033[00m' "$ctx_str" "$session_id")
fi

# Get active tsh cluster
tsh_cluster=$(grep '^cluster:' "$HOME/.tsh/profile.yaml" 2>/dev/null | head -1 | awk '{print $2}')
if [ -n "$tsh_cluster" ]; then
  tsh_str=$(printf ' \033[00;32m[tsh:%s]\033[00m' "$tsh_cluster")
else
  tsh_str=""
fi

# This session's SendMessage address. Refreshed detached: Claude Code cancels a slow status line.
agent_name=""
if [[ "$session_id" =~ ^[0-9a-fA-F-]+$ ]]; then
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  cache_file="$cache_dir/addr-$session_id"
  mkdir -p -m 700 "$cache_dir" 2>/dev/null
  if [ -O "$cache_dir" ]; then
    write_addr() {
      local tmp
      tmp=$(mktemp "$cache_dir/.addr.XXXXXX" 2>/dev/null) || return
      { printf '%s\n%s\n' "$1" "$2" > "$tmp" && mv -f "$tmp" "$cache_file"; } || rm -f "$tmp"
    }
    now=$(date +%s)
    cached_at=""
    if [ -r "$cache_file" ]; then
      { read -r cached_at; read -r agent_name; } < "$cache_file"
    fi
    age=-1
    [[ "$cached_at" =~ ^[0-9]+$ ]] && age=$(( now - cached_at ))
    if [ "$age" -lt 0 ] || [ "$age" -ge 30 ]; then
      # Claim the refresh so concurrent runs within 30s don't spawn their own.
      write_addr "$now" "$agent_name"
      if command -v claude >/dev/null 2>&1; then
        to=()
        command -v timeout >/dev/null 2>&1 && to=(timeout 5)
        set -m 2>/dev/null
        (
          name=$("${to[@]}" claude agents --json 2>/dev/null \
            | jq -r --arg id "$session_id" 'first(.[] | select(.sessionId == $id) | .name) // empty' 2>/dev/null \
            | LC_ALL=C tr -cd '[:print:]')
          [ -n "$name" ] && write_addr "$(date +%s)" "$name"
          find "$cache_dir" \( -name 'addr-*' -mtime +7 -o -name '.addr.*' -mtime +1 \) -delete 2>/dev/null
        ) </dev/null >/dev/null 2>&1 &
        disown
        set +m 2>/dev/null
      fi
    fi
  fi
fi
agent_name=$(printf '%s' "$agent_name" | LC_ALL=C tr -cd '[:print:]')

if [ -n "$agent_name" ]; then
  agent_str=$(printf ' \033[00;95m[agent:%s]\033[00m' "$agent_name")
else
  agent_str=""
fi

home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"
printf '\033[01;34m%s\033[00m%s%s%s\n%s' "$short_cwd" "$branch_str" "$tsh_str" "$agent_str" "$ctx_str"
