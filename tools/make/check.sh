#!/usr/bin/env bash
# `mm check`: kiem tra chu thich ## trong makefile + MAKEFILE.md con khop khong.
# Exit 1 khi co loi (■); canh bao (▲) khong lam fail.
set -uo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$DIR/lib.sh"
: "${MM_FILE:?chạy qua mm}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	E=$'\033'; R="$E[0m" B="$E[1m" D="$E[2m" G="$E[90m" RED="$E[31m" Y="$E[33m" OK="$E[32m"
else
	R= B= D= G= RED= Y= OK=
fi

parse_makefile "$MM_FILE"
errs=("${ERRORS[@]}") warns=()

# Nguon 1 tu, khong phai keyword va khong phai lenh -> nhieu kha nang go nham.
for i in "${!V_NAME[@]}"; do
	src=${V_SRC[i]}
	[[ -z $src || $src == *[[:space:]]* || $src == confirm || $src == skip ]] && continue
	command -v "$src" >/dev/null || errs+=("#!var ${V_NAME[i]}: nguồn '$src' không phải confirm/skip/lệnh")
done

# Bien dung trong ## ma khong co #!var -> menu hoi nhap tay voi tieu de tho.
declare -A used=() noted=()
for i in "${!T_NAME[@]}"; do
	for tok in ${T_SPEC[i]}; do
		tok=${tok#[}; v=${tok%%=*}
		used[$v]=1
		find_var "$v" "${T_NAME[i]}" && continue
		[[ -n ${noted[$v]:-} ]] && continue
		noted[$v]=1
		warns+=("biến '$v' (${T_NAME[i]}) chưa có #!var — menu sẽ hỏi nhập tay")
	done
done
for i in "${!V_NAME[@]}"; do
	[[ -n ${used[${V_NAME[i]}]:-} ]] || warns+=("#!var ${V_NAME[i]}: không target nào dùng")
done

# MAKEFILE.md chi kiem khi da co — project khong muon doc thi khong bat.
md=$(dirname "$MM_FILE")/MAKEFILE.md
if [[ -f $md ]] && (( ! ${#ERRORS[@]} )); then
	MM_OUT=- bash "$DIR/doc.sh" | cmp -s - "$md" \
		|| errs+=("$md cũ so với $(basename "$MM_FILE") — chạy: make help-doc")
fi

printf '%s┌%s  %s%s%s %s· make help-check%s\n%s│%s\n' "$G" "$R" "$B" "$(basename "$PWD")" "$R" "$D" "$R" "$G" "$R"
for m in "${errs[@]}";  do printf '%s■%s  %s\n' "$RED" "$R" "$m"; done
for m in "${warns[@]}"; do printf '%s▲%s  %s\n' "$Y" "$R" "$m"; done
(( ${#HIDDEN[@]} )) && printf '%s│%s  %sẩn (không ##): %s%s\n' "$G" "$R" "$D" "${HIDDEN[*]}" "$R"
printf '%s│%s\n' "$G" "$R"

summary="${#T_NAME[@]} target, ${#V_NAME[@]} #!var, ${#HIDDEN[@]} ẩn"
if (( ${#errs[@]} )); then
	printf '%s└%s  %s%d lỗi%s, %d cảnh báo · %s\n' "$G" "$R" "$RED" "${#errs[@]}" "$R" "${#warns[@]}" "$summary"
	exit 1
fi
printf '%s└%s  %sOK%s, %d cảnh báo · %s\n' "$G" "$R" "$OK" "$R" "${#warns[@]}" "$summary"
