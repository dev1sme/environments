#!/bin/sh
# Render `make help` tu targets.txt, cung style voi `make menu`.
# Mau tu tat khi khong phai TTY hoac NO_COLOR.
set -eu

FILE="$(dirname "$0")/targets.txt"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	B=$(printf '\033[1m'); C=$(printf '\033[36m'); Y=$(printf '\033[33m')
	D=$(printf '\033[2m'); G=$(printf '\033[90m'); K=$(printf '\033[32m'); R=$(printf '\033[0m')
else
	B= C= Y= D= G= K= R=
fi

printf '%s┌%s  %s%s%s %s· make help%s\n' "$G" "$R" "$B" "$(basename "$PWD")" "$R" "$D" "$R"

# Cot target/bien la ASCII nen printf cua mawk (dem byte) van thang hang;
# mo ta co dau nam o cot cuoi, khong can pad.
awk -F'|' -v B="$B" -v C="$C" -v Y="$Y" -v G="$G" -v K="$K" -v R="$R" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
/^[ \t]*(#|!|$)/ { next }
/^@/             { printf "%s│%s\n%s◇%s  %s%s%s\n", G, R, K, R, B, substr($0, 2), R; next }
{
	d = trim($3); if (d ~ /^⚠/) d = Y d R
	printf "%s│%s  %s%-12s%s %s%-19s%s %s\n", G, R, C, trim($1), R, Y, trim($2), R, d
}' "$FILE"

printf '%s│%s\n' "$G" "$R"
printf '%s└%s  %smake menu%s %schọn lệnh bằng giao diện ·%s make %s<target>%s %s[biến=giá-trị]%s\n' \
	"$G" "$R" "$C" "$R" "$D" "$R" "$C" "$R" "$Y" "$R"
