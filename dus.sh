#!/usr/bin/env bash
export LC_ALL=C

BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; RESET=$'\033[0m'

bar() {
  local pct=$1 width=38
  local filled=$(( pct * width / 100 ))
  local b=""
  for ((i=0; i<filled; i++));     do b+="#"; done
  for ((i=filled; i<width; i++)); do b+="."; done
  echo "$b"
}

to_human() {
  local kb=$1
  if (( kb >= 1048576 )); then
    awk "BEGIN{printf \"%.2fGB\", $kb/1048576}"
  else
    awk "BEGIN{printf \"%.0fMB\", $kb/1024}"
  fi
}

echo

lsblk -rno NAME,TYPE,MODEL | awk '$2=="disk"' | while read -r disk type model; do
  model=$(printf '%b' "$model")
  total_kb=0
  used_kb=0
  has_root=0

  while read -r name mnt; do
    [[ -z "$mnt" || "$mnt" == "[SWAP]" ]] && continue
    [[ "$mnt" == "/" ]] && has_root=1

    read -r t u < <(df -k --output=size,used "$mnt" 2>/dev/null | tail -1)
    [[ -z "$t" ]] && continue

    total_kb=$(( total_kb + t ))
    used_kb=$(( used_kb + u ))
  done < <(lsblk -rno NAME,MOUNTPOINT "/dev/$disk" 2>/dev/null)

  [[ $total_kb -eq 0 ]] && continue

  # decimal for display
  pct=$(awk "BEGIN { printf \"%.1f\", ($used_kb * 100) / $total_kb }")

  # int for logic and bar
  pct_int=$(( used_kb * 100 / total_kb ))

  # fine touch
  if (( pct_int >= 90 )); then
    col=$RED
  elif (( pct_int >= 70 )); then
    col=$YELLOW
  else
    col=$GREEN
  fi

  used_h=$(to_human "$used_kb")
  total_h=$(to_human "$total_kb")
  bar_str=$(bar "$pct_int")

  if (( has_root )); then
    label="${DIM}/${RESET}"
  elif [[ -n "$model" && "$model" != " " ]]; then
    label="${DIM}${model}${RESET}"
  else
    label=""
  fi

  [[ -n "$label" ]] && label=" $label"

  printf "${BOLD}%-10s${RESET}%s\n" "$disk" "$label"
  printf "           ${col}[%s]${RESET}  %s/%s  (${col}%s%%${RESET})\n\n" \
    "$bar_str" "$used_h" "$total_h" "$pct"
done
