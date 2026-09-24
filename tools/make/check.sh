#!/usr/bin/env bash
# `make help-check`: kiem tra targets.txt — cu phap + dong bo voi makefile.
# Exit 1 khi co loi (■); canh bao (▲) khong lam fail.
set -uo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
FILE="$DIR/targets.txt"
. "$DIR/lib.sh"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	E=$'\033'; R="$E[0m" B="$E[1m" D="$E[2m" G="$E[90m" RED="$E[31m" Y="$E[33m" OK="$E[32m"
else
	R= B= D= G= RED= Y= OK=
fi

parse_targets "$FILE"
errs=("${ERRORS[@]}") warns=()

# Target thuc te cua make (tinh ca include). Dong sau "# Not a target:" la file, bo qua.
mapfile -t made < <(make -pRrq : 2>/dev/null | awk '
	/^# Not a target/ { skip = 1; next }
	/^[A-Za-z0-9][A-Za-z0-9_.-]*:([^=]|$)/ { if (!skip) { sub(/:.*/, ""); print } }
	{ skip = 0 }' | sort -u)

declare -A in_make=() in_file=() in_hide=() has_var=()
for t in "${made[@]}";   do in_make[$t]=1; done
for t in "${T_NAME[@]}"; do in_file[$t]=1; done
for t in "${HIDDEN[@]}"; do in_hide[$t]=1; done
for v in "${V_NAME[@]}"; do has_var[$v]=1; done

for t in "${T_NAME[@]}"; do
	[[ -n ${in_make[$t]:-} ]] || errs+=("'$t' có trong targets.txt nhưng makefile không có")
	[[ -n ${in_hide[$t]:-} ]] && warns+=("'$t' vừa khai báo vừa !hide")
done
for t in "${made[@]}"; do
	[[ -n ${in_file[$t]:-} || -n ${in_hide[$t]:-} ]] \
		|| warns+=("'$t' có trong makefile nhưng chưa mô tả (thêm vào targets.txt hoặc !hide)")
done
for t in "${HIDDEN[@]}"; do
	[[ -n ${in_make[$t]:-} ]] || warns+=("!hide '$t' nhưng makefile không có")
done

# Nguon 1 tu, khong phai keyword va khong phai lenh -> nhieu kha nang go nham.
for i in "${!V_NAME[@]}"; do
	src=${V_SRC[i]}
	[[ -z $src || $src == *[[:space:]]* || $src == confirm || $src == skip ]] && continue
	command -v "$src" >/dev/null || errs+=("!var ${V_NAME[i]}: nguồn '$src' không phải confirm/skip/lệnh")
done

# Bien dung trong target ma khong co !var -> menu hoi nhap tay voi tieu de tho.
declare -A noted=()
for i in "${!T_NAME[@]}"; do
	for tok in ${T_SPEC[i]}; do
		tok=${tok#[}; v=${tok%%=*}
		[[ -n ${has_var[$v]:-} || -n ${noted[$v]:-} ]] && continue
		noted[$v]=1
		warns+=("biến '$v' (${T_NAME[i]}) chưa có !var — menu sẽ hỏi nhập tay")
	done
done

printf '%s┌%s  %s%s%s %s· make help-check%s\n%s│%s\n' "$G" "$R" "$B" "$(basename "$PWD")" "$R" "$D" "$R" "$G" "$R"
for m in "${errs[@]}";  do printf '%s■%s  %s\n' "$RED" "$R" "$m"; done
for m in "${warns[@]}"; do printf '%s▲%s  %s\n' "$Y" "$R" "$m"; done
(( ${#errs[@]} + ${#warns[@]} )) && printf '%s│%s\n' "$G" "$R"

summary="${#T_NAME[@]} target, ${#V_NAME[@]} !var, ${#HIDDEN[@]} ẩn"
if (( ${#errs[@]} )); then
	printf '%s└%s  %s%d lỗi%s, %d cảnh báo · %s\n' "$G" "$R" "$RED" "${#errs[@]}" "$R" "${#warns[@]}" "$summary"
	exit 1
fi
printf '%s└%s  %sOK%s, %d cảnh báo · %s\n' "$G" "$R" "$OK" "$R" "${#warns[@]}" "$summary"
