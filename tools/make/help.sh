#!/usr/bin/env bash
# `mm help`: liet ke target co ##, cung style voi menu. Mau tu tat khi khong phai TTY hoac NO_COLOR.
set -uo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$DIR/lib.sh"
: "${MM_FILE:?chạy qua mm}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	E=$'\033'; B="$E[1m" C="$E[36m" Y="$E[33m" D="$E[2m" G="$E[90m" K="$E[32m" R="$E[0m"
else
	B= C= Y= D= G= K= R=
fi

parse_makefile "$MM_FILE"

kw=0 sw=0
for i in "${!T_NAME[@]}"; do
	(( ${#T_NAME[i]} > kw )) && kw=${#T_NAME[i]}
	(( ${#T_SPEC[i]} > sw )) && sw=${#T_SPEC[i]}
done

printf '%s┌%s  %s%s%s %s· make help%s\n' "$G" "$R" "$B" "$(basename "$PWD")" "$R" "$D" "$R"
prev=-
for i in "${!T_NAME[@]}"; do
	if [[ ${T_GROUP[i]} != "$prev" ]]; then
		prev=${T_GROUP[i]}
		printf '%s│%s\n' "$G" "$R"
		[[ -n $prev ]] && printf '%s◇%s  %s%s%s\n' "$K" "$R" "$B" "$prev" "$R"
	fi
	d=${T_DESC[i]}; [[ $d == ⚠* ]] && d="$Y$d$R"
	printf '%s│%s  %s%s%s  %s%s%s  %s\n' "$G" "$R" "$C" "$(pad "${T_NAME[i]}" "$kw")" "$R" \
		"$Y" "$(pad "${T_SPEC[i]}" "$sw")" "$R" "$d"
done

printf '%s│%s\n' "$G" "$R"
(( ${#ERRORS[@]} )) && printf '%s│%s  %s▲ %d lỗi cú pháp ##, chạy: make help-check%s\n%s│%s\n' \
	"$G" "$R" "$Y" "${#ERRORS[@]}" "$R" "$G" "$R"
printf '%s└%s  %smake menu%s %schọn lệnh bằng giao diện ·%s make %s<target>%s %s[biến=giá-trị]%s\n' \
	"$G" "$R" "$C" "$R" "$D" "$R" "$C" "$R" "$Y" "$R"
