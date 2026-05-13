#!/bin/bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
session_name=$(echo "$input" | jq -r '.session_name // .session_id // empty')
reset_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# --- ANSI colors ---
RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
MAGENTA=$'\e[35m'
CYAN=$'\e[36m'
GRAY=$'\e[90m'

# --- Star Wars lightsaber gradient: 0..100 → 24-bit color escape ---
# Stops: 0% Jedi blue(#00a0ff) → 50% Mace purple(#aa55f0) → 100% Sith red(#ff0a14)
gradient() {
  local p=$1
  [ "$p" -lt 0 ] && p=0
  [ "$p" -gt 100 ] && p=100
  local r g b
  if [ "$p" -le 50 ]; then
    local t=$(( p * 2 ))
    r=$(( 0 + 170 * t / 100 ))
    g=$(( 160 + (85 - 160) * t / 100 ))
    b=$(( 255 + (240 - 255) * t / 100 ))
  else
    local t=$(( (p - 50) * 2 ))
    r=$(( 170 + (255 - 170) * t / 100 ))
    g=$(( 85 + (10 - 85) * t / 100 ))
    b=$(( 240 + (20 - 240) * t / 100 ))
  fi
  printf '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

# --- Session title (bold cyan) ---
session_part=""
if [ -n "$session_name" ]; then
  session_part="${BOLD}${CYAN}${session_name}${RESET}  "
fi

# --- Directory: basename only (bold blue) ---
dir_basename=$(basename "$cwd")
dir_display="${BOLD}${BLUE}${dir_basename}${RESET}"

# --- Git branch + dirty marker (green clean / yellow dirty) ---
git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
git_part=""
if [ -n "$git_branch" ]; then
  git_status=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$git_status" ]; then
    git_part="  ${YELLOW}${git_branch}${RED}*${RESET}"
  else
    git_part="  ${GREEN}${git_branch}${RESET}"
  fi
fi

# --- Model (magenta) ---
model_part="  ${MAGENTA}${model}${RESET}"

# --- Context usage % (color by threshold) ---
ctx_pct_part=""
if [ -n "$used_pct" ]; then
  ctx_int=$(printf '%.0f' "$used_pct")
  if [ "$ctx_int" -ge 80 ]; then
    ctx_color="$RED"
  elif [ "$ctx_int" -ge 50 ]; then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  ctx_pct_part="  ${ctx_color}${ctx_int}%${RESET}"
fi

# --- Token count (context) + 5h-limit gradient bar ---
token_part=""
if [ -n "$total_tokens" ] && [ -n "$ctx_window_size" ]; then
  used_k=$(awk "BEGIN { printf \"%.0f\", $total_tokens / 1000 }")
  limit_k=$(awk "BEGIN { printf \"%.0f\", $ctx_window_size / 1000 }")
  ctx_fill_pct=$(awk "BEGIN { p = ($total_tokens / $ctx_window_size) * 100; if (p > 100) p = 100; printf \"%.0f\", p }")

  # Bar fill = % consumido del límite de 5h. Si no está disponible (no Pro/Max o
  # antes del primer API call), cae al fill del contexto.
  if [ -n "$five_hour_pct" ]; then
    bar_fill_pct=$(printf '%.0f' "$five_hour_pct")
    [ "$bar_fill_pct" -gt 100 ] && bar_fill_pct=100
    [ "$bar_fill_pct" -lt 0 ] && bar_fill_pct=0
  else
    bar_fill_pct="$ctx_fill_pct"
  fi

  bar_width=10
  filled=$(( bar_fill_pct * bar_width / 100 ))
  bar=""
  for ((i=0; i<bar_width; i++)); do
    if [ "$i" -lt "$filled" ]; then
      pos_pct=$(( i * 100 / (bar_width - 1) ))
      bar+="$(gradient "$pos_pct")█"
    else
      bar+="${GRAY}░"
    fi
  done
  bar+="$RESET"

  used_color=$(gradient "$ctx_fill_pct")
  token_part="  ${used_color}${used_k}k${RESET}${GRAY}/${limit_k}k${RESET} ${bar}"
fi

# --- Time until rate-limit reset (dim cyan) ---
reset_part=""
if [ -n "$reset_at" ]; then
  now=$(date +%s)
  diff_sec=$(( reset_at - now ))
  if [ "$diff_sec" -gt 0 ]; then
    diff_min=$(( diff_sec / 60 ))
    if [ "$diff_min" -ge 60 ]; then
      diff_h=$(( diff_min / 60 ))
      diff_rem=$(( diff_min % 60 ))
      reset_str="${diff_h}h${diff_rem}m"
    else
      reset_str="${diff_min}m"
    fi
    reset_part="  ${DIM}${CYAN}${reset_str}${RESET}"
  fi
fi

printf "%s%s%s%s%s%s%s" \
  "$session_part" \
  "$dir_display" \
  "$git_part" \
  "$model_part" \
  "$ctx_pct_part" \
  "$token_part" \
  "$reset_part"
