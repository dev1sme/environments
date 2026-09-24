#!/bin/sh
# Render `make help` tu targets.txt. Mau tu tat khi khong phai TTY hoac NO_COLOR.
set -eu

FILE="$(dirname "$0")/targets.txt"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	B=$(printf '\033[1m'); C=$(printf '\033[36m'); Y=$(printf '\033[33m')
	D=$(printf '\033[2m'); R=$(printf '\033[0m')
else
	B= C= Y= D= R=
fi

printf '%sUsage:%s make %s<target>%s %s[bien=gia-tri]%s\n' "$B" "$R" "$C" "$R" "$Y" "$R"
printf '       make %smenu%s   %schon target bang fzf%s\n' "$C" "$R" "$D" "$R"

awk -F'|' -v B="$B" -v C="$C" -v Y="$Y" -v R="$R" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
/^[ \t]*(#|$)/ { next }
/^@/           { printf "\n%s%s%s\n", B, substr($0, 2), R; next }
{ printf "  %s%-12s%s %s%-19s%s %s\n", C, trim($1), R, Y, trim($2), R, trim($3) }
' "$FILE"
