#!/bin/bash

input=$(cat)

command -v jq >/dev/null 2>&1 || { echo "⚠️ jq required for statusline"; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- ANSI colors ---
RESET=$'\e[0m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
MAGENTA=$'\e[35m'
CYAN=$'\e[36m'
GRAY=$'\e[90m'

# Star Wars lightsaber gradient: 0% Jedi blue(#00a0ff) → 50% Mace purple(#aa55f0) → 100% Sith red(#ff0a14)
gradient() {
  local p=$1
  [ "$p" -lt 0 ] && p=0
  [ "$p" -gt 100 ] && p=100
  local r g b t
  if [ "$p" -le 50 ]; then
    t=$(( p * 2 ))
    r=$(( 0 + 170 * t / 100 ))
    g=$(( 160 + (85 - 160) * t / 100 ))
    b=$(( 255 + (240 - 255) * t / 100 ))
  else
    t=$(( (p - 50) * 2 ))
    r=$(( 170 + (255 - 170) * t / 100 ))
    g=$(( 85 + (10 - 85) * t / 100 ))
    b=$(( 240 + (20 - 240) * t / 100 ))
  fi
  printf '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

# --- Native JSON fields ---
native=$(echo "$input" | jq '{
  cwd:              (.workspace.current_dir // .cwd // "unknown"),
  model:            (.model.display_name // "Claude"),
  version:          (.version // ""),
  session_id:       (.session_id // "default"),
  transcript:       (.transcript_path // ""),
  wall_ms:          (.cost.total_duration_ms // 0),
  api_ms:           (.cost.total_api_duration_ms // 0),
  lines_added:      (.cost.total_lines_added // 0),
  lines_removed:    (.cost.total_lines_removed // 0),
  ctx_input:        (.context_window.total_input_tokens // 0),
  ctx_output:       (.context_window.total_output_tokens // 0),
  ctx_size:         (.context_window.context_window_size // 200000),
  ctx_used_pct:     (.context_window.used_percentage // 0),
  cur_input:        (.context_window.current_usage.input_tokens // 0),
  cur_output:       (.context_window.current_usage.output_tokens // 0),
  cur_cache_read:   (.context_window.current_usage.cache_read_input_tokens // 0),
  cur_cache_create: (.context_window.current_usage.cache_creation_input_tokens // 0),
  reset_at:         (.rate_limits.five_hour.resets_at // 0),
  five_hour_pct:    (.rate_limits.five_hour.used_percentage // 0)
}' 2>/dev/null)

n() { echo "$native" | jq -r ".$1 // \"$2\"" 2>/dev/null; }
ni() { local v; v=$(echo "$native" | jq -r ".$1 // 0" 2>/dev/null); echo "${v%%.*}"; }

raw_cwd=$(n cwd "unknown")
current_dir=$(echo "$raw_cwd" | sed "s|^$HOME|~|")
model_name=$(n model "Claude")
cc_version=$(n version "")
session_id=$(n session_id "default")
transcript_path=$(n transcript "")

wall_ms=$(ni wall_ms)
api_ms=$(ni api_ms)
lines_added=$(ni lines_added)
lines_removed=$(ni lines_removed)

input_total=$(ni ctx_input)
output_total=$(ni ctx_output)
MAX_CONTEXT=$(ni ctx_size)
context_pct=$(ni ctx_used_pct)
[ "$context_pct" -gt 100 ] && context_pct=100

cur_input=$(ni cur_input)
cur_output=$(ni cur_output)
cache_read=$(ni cur_cache_read)
cache_create=$(ni cur_cache_create)
reset_at=$(ni reset_at)
five_hour_pct=$(ni five_hour_pct)
[ "$five_hour_pct" -gt 100 ] && five_hour_pct=100

tot_tokens=$(( input_total + output_total ))
actual_context_tokens=$(( cur_input + cache_read + cache_create ))

total_prompt_tokens=$(( cur_input + cache_read + cache_create ))
cache_hit_rate=0
[ "$total_prompt_tokens" -gt 0 ] && cache_hit_rate=$(( cache_read * 100 / total_prompt_tokens ))

# --- Per-session state (one file per session_id: several sessions can run at once) ---
STATE_DIR="${SCRIPT_DIR}/.statusline_state"
mkdir -p "$STATE_DIR" 2>/dev/null
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null
STATE_FILE="${STATE_DIR}/${session_id}"
CURRENT_TIME=$(date +%s)

if [ -f "$STATE_FILE" ]; then
  source "$STATE_FILE"
else
  SESSION_START_TIME=$CURRENT_TIME
  LAST_CONTEXT_TOKENS=0
  PEAK_CONTEXT=0
  COMPACTION_COUNT=0
  VELOCITY_CHECK_TIME=0
  VELOCITY_CHECK_TOKENS=0
  LAST_VELOCITY=0
fi
[ -z "$PEAK_CONTEXT" ] && PEAK_CONTEXT=0
[ -z "$COMPACTION_COUNT" ] && COMPACTION_COUNT=0
[ -z "$VELOCITY_CHECK_TIME" ] && VELOCITY_CHECK_TIME=0
[ -z "$VELOCITY_CHECK_TOKENS" ] && VELOCITY_CHECK_TOKENS=0
[ -z "$LAST_VELOCITY" ] && LAST_VELOCITY=0

[ "$actual_context_tokens" -gt "$PEAK_CONTEXT" ] && PEAK_CONTEXT=$actual_context_tokens
if [ "$LAST_CONTEXT_TOKENS" -gt 0 ] && [ "$actual_context_tokens" -gt 0 ] \
   && [ "$actual_context_tokens" -lt $(( LAST_CONTEXT_TOKENS / 2 )) ]; then
  COMPACTION_COUNT=$(( COMPACTION_COUNT + 1 ))
fi

if [ "$wall_ms" -gt 0 ]; then
  session_elapsed=$(( wall_ms / 1000 ))
else
  session_elapsed=$(( CURRENT_TIME - SESSION_START_TIME ))
fi
[ "$session_elapsed" -lt 1 ] && session_elapsed=1

# Velocity = growth SINCE THE LAST CHECKPOINT, not tokens-now / time-since-session-start.
# That average blows up right after the first turn, since the initial context (system
# prompt, tools, CLAUDE.md...) loads all at once and dividing it by a couple of minutes
# looks like a huge rate even though nothing has actually grown yet. A minimum 60s window
# also keeps two renders seconds apart from producing a spike from a tiny delta.
if [ "$VELOCITY_CHECK_TIME" -eq 0 ]; then
  VELOCITY_CHECK_TIME=$CURRENT_TIME
  VELOCITY_CHECK_TOKENS=$actual_context_tokens
  context_velocity=0
else
  elapsed_since_check=$(( CURRENT_TIME - VELOCITY_CHECK_TIME ))
  if [ "$elapsed_since_check" -ge 60 ]; then
    delta_tokens=$(( actual_context_tokens - VELOCITY_CHECK_TOKENS ))
    [ "$delta_tokens" -lt 0 ] && delta_tokens=0
    context_velocity=$(( delta_tokens * 60 / elapsed_since_check ))
    LAST_VELOCITY=$context_velocity
    VELOCITY_CHECK_TIME=$CURRENT_TIME
    VELOCITY_CHECK_TOKENS=$actual_context_tokens
  else
    context_velocity=$LAST_VELOCITY
  fi
fi

time_to_full="N/A"
if [ "$context_velocity" -gt 0 ]; then
  tokens_remaining=$(( MAX_CONTEXT - actual_context_tokens ))
  minutes_to_full=$(( tokens_remaining / context_velocity ))
  if [ "$minutes_to_full" -lt 1 ]; then time_to_full="<1m"
  elif [ "$minutes_to_full" -lt 60 ]; then time_to_full="${minutes_to_full}m"
  elif [ "$minutes_to_full" -lt 1440 ]; then time_to_full="$((minutes_to_full / 60))h $((minutes_to_full % 60))m"
  else time_to_full=">24h"
  fi
fi

{
  echo "SESSION_START_TIME=${SESSION_START_TIME}"
  echo "LAST_CONTEXT_TOKENS=$actual_context_tokens"
  echo "PEAK_CONTEXT=$PEAK_CONTEXT"
  echo "COMPACTION_COUNT=$COMPACTION_COUNT"
  echo "VELOCITY_CHECK_TIME=$VELOCITY_CHECK_TIME"
  echo "VELOCITY_CHECK_TOKENS=$VELOCITY_CHECK_TOKENS"
  echo "LAST_VELOCITY=$LAST_VELOCITY"
} > "$STATE_FILE" 2>/dev/null

# --- Git (only if the cwd is actually inside a repo — not every project here uses git) ---
git_part=""
if command -v git >/dev/null 2>&1 && git -C "$raw_cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$raw_cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$git_branch" ] && git_branch=$(git -C "$raw_cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    staged=$(git -C "$raw_cwd" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git -C "$raw_cwd" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git -C "$raw_cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    branch_color="$GREEN"
    [ "$staged" -gt 0 ] || [ "$modified" -gt 0 ] || [ "$untracked" -gt 0 ] && branch_color="$YELLOW"
    git_part="  🌿 ${branch_color}${git_branch}${RESET}"
    [ "$staged" -gt 0 ] && git_part="${git_part} ${GREEN}+${staged}${RESET}"
    [ "$modified" -gt 0 ] && git_part="${git_part} ${YELLOW}~${modified}${RESET}"
    [ "$untracked" -gt 0 ] && git_part="${git_part} ${RED}?${untracked}${RESET}"
  fi
fi

# --- JSONL parsing (tool/message stats) ---
message_count=0
tool_read=0; tool_edit=0; tool_bash=0; tool_write=0
tool_total=0; tool_errors=0; tool_success_rate=100; files_touched=0

session_file=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  session_file="$transcript_path"
fi

if [ -n "$session_file" ]; then
  tool_metrics=$(jq -s '{
    message_count: [.[] | select(.type == "user" or .type == "assistant")] | length,
    tool_read: [.[] | select(.message.content[]?.name == "Read")] | length,
    tool_edit: [.[] | select(.message.content[]?.name == "Edit")] | length,
    tool_bash: [.[] | select(.message.content[]?.name == "Bash")] | length,
    tool_write: [.[] | select(.message.content[]?.name == "Write")] | length,
    tool_total: [.[] | select(.message.content[]?.type == "tool_use")] | length,
    tool_errors: [.[] | .message.content[]? | select(.type == "tool_result" and .is_error == true)] | length,
    files_touched: [.[] | select(.message.content[]?.name == "Edit" or .message.content[]?.name == "Write") | .message.content[] | select(.name == "Edit" or .name == "Write") | .input.file_path] | unique | length
  }' "$session_file" 2>/dev/null)

  if [ -n "$tool_metrics" ]; then
    message_count=$(echo "$tool_metrics" | jq -r '.message_count // 0')
    tool_read=$(echo "$tool_metrics" | jq -r '.tool_read // 0')
    tool_edit=$(echo "$tool_metrics" | jq -r '.tool_edit // 0')
    tool_bash=$(echo "$tool_metrics" | jq -r '.tool_bash // 0')
    tool_write=$(echo "$tool_metrics" | jq -r '.tool_write // 0')
    tool_total=$(echo "$tool_metrics" | jq -r '.tool_total // 0')
    tool_errors=$(echo "$tool_metrics" | jq -r '.tool_errors // 0')
    files_touched=$(echo "$tool_metrics" | jq -r '.files_touched // 0')
  fi

  if [ "$tool_total" -gt 0 ]; then
    tool_success_rate=$(( (tool_total - tool_errors) * 100 / tool_total ))
    [ "$tool_success_rate" -lt 0 ] && tool_success_rate=0
  fi
fi

# ---------- Format helpers ----------
fmt_tokens() {
  local v=$1
  if [ "$v" -ge 1000000 ] 2>/dev/null; then
    LC_ALL=C awk -v n="$v" 'BEGIN { printf "%.1fM", n/1000000 }'
  elif [ "$v" -ge 1000 ] 2>/dev/null; then
    LC_ALL=C awk -v n="$v" 'BEGIN { printf "%.1fK", n/1000 }'
  else
    echo "$v"
  fi
}

# ---------- API time ----------
api_time_display="0s"
if [ "$api_ms" -gt 0 ]; then
  api_secs=$((api_ms / 1000))
  if [ "$api_secs" -lt 60 ]; then api_time_display="${api_secs}s"
  elif [ "$api_secs" -lt 3600 ]; then api_time_display="$((api_secs / 60))m $((api_secs % 60))s"
  else api_time_display="$((api_secs / 3600))h $((api_secs % 3600 / 60))m"
  fi
fi

# ---------- Session wall time ----------
session_time="$(( session_elapsed / 3600 ))h $(( (session_elapsed % 3600) / 60 ))m"

# ---------- 5h rate-limit reset (percentage colored with the same gradient
# as the context bar, formatted like the Context line: pct first, then time) ----------
reset_display=""
if [ "$reset_at" -gt 0 ]; then
  diff_sec=$(( reset_at - CURRENT_TIME ))
  if [ "$diff_sec" -gt 0 ]; then
    diff_min=$(( diff_sec / 60 ))
    if [ "$diff_min" -ge 60 ]; then
      reset_time_str="$((diff_min / 60))h $((diff_min % 60))m"
    else
      reset_time_str="${diff_min}m"
    fi
    five_h_color=$(gradient "$five_hour_pct")
    reset_display=" • 5h: ${five_h_color}${five_hour_pct}%${RESET} (${reset_time_str})"
  fi
fi

# ---------- Cache write/read imbalance warning ----------
# cache_create > cache_read means this turn wrote new cache instead of reusing it —
# usually a gap longer than the cache TTL between calls, content before the cache
# breakpoint changing (system prompt/tools), or several parallel/forked agents each
# seeding their own cache instead of sharing one.
cache_warning=""
if [ "$cache_create" -gt 0 ] && [ "$cache_create" -gt "$cache_read" ]; then
  cache_warning=$'\n'"${YELLOW}⚠️  Cache: más escrituras (${cache_create}) que lecturas (${cache_read}) — hueco largo entre turnos, contexto inicial cambiante o llamadas en paralelo; evita pausas largas y agrupa el trabajo en una sesión continua${RESET}"
fi

# ---------- Context bar ----------
width=10
filled=$(( context_pct * width / 100 ))
[ "$filled" -gt "$width" ] && filled=$width
empty=$(( width - filled ))
bar=""
[ "$filled" -gt 0 ] && bar=$(printf '▓%.0s' $(seq 1 $filled))
[ "$empty" -gt 0 ] && bar="${bar}$(printf '░%.0s' $(seq 1 $empty))"

tok_display=$(fmt_tokens "$tot_tokens")
context_tokens_display=$(fmt_tokens "$actual_context_tokens")
max_context_display=$(fmt_tokens "$MAX_CONTEXT")
velocity_display=$(fmt_tokens "$context_velocity")

# ---------- Status message ----------
status_msg=""
if [ "$context_pct" -ge 90 ]; then
  status_msg="🚨 Memory almost full (${context_pct}%) — Run /compact now or start a new session"
elif [ "$context_pct" -ge 75 ]; then
  status_msg="⚠️ Memory filling up (${context_pct}%) — Run /compact soon to free space"
elif [ "$context_velocity" -gt 8000 ] 2>/dev/null; then
  status_msg="⚡ Using memory fast ($(fmt_tokens $context_velocity)/min) — Break task into smaller steps"
elif [ "$COMPACTION_COUNT" -gt 3 ] 2>/dev/null; then
  status_msg="🔄 Compacted ${COMPACTION_COUNT}x — Session is long. Consider starting fresh (/clear)"
elif [ "$tool_success_rate" -lt 90 ] 2>/dev/null; then
  status_msg="⚠️ ${tool_success_rate}% tool success — Errors may be causing retries, check output"
else
  status_msg="✅ All good"
fi

# ---------- Render ----------
# Line 1: dir, model, version, git
printf "📁 %s  ${MAGENTA}🤖 %s${RESET}  📟 %s" "$current_dir" "$model_name" "${cc_version:-?}"
printf '%s' "$git_part"

# Line 2: context
printf '\n🧠 Context: %s/%s (%d%%) • Until compact: %s %s' \
  "$context_tokens_display" "$max_context_display" "$context_pct" "$time_to_full" "$bar"

# Line 4: session timing + cache + 5h reset (+ optional cache warning)
printf '\n⏱️  Session: %s (API: %s) • Cache: %d%%%s%s' \
  "$session_time" "$api_time_display" "$cache_hit_rate" "$reset_display" "$cache_warning"

# Line 5: tokens, messages, tools
printf '\n📊 %s tok • 💬 %d msgs • 🔧 R:%d E:%d B:%d W:%d' \
  "$tok_display" "$message_count" "$tool_read" "$tool_edit" "$tool_bash" "$tool_write"

# Line 6: files, velocity, success, code changes
printf '\n📂 %d files • ⚡ %s/min • ✅ %d%% tools • 📝 +%d/-%d lines' \
  "$files_touched" "$velocity_display" "$tool_success_rate" "$lines_added" "$lines_removed"

# Line 9: status
printf '\n%s\n' "$status_msg"
