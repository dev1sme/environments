#!/usr/bin/env bash
# `mm doc`: sinh MAKEFILE.md tu chu thich ## — de xem tren GitHub/IDE. Khong sua tay.
# MM_OUT: rong = MAKEFILE.md canh makefile, "-" = stdout (check.sh dung de so sanh).
set -uo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$DIR/lib.sh"
: "${MM_FILE:?chạy qua mm}"

parse_makefile "$MM_FILE"
if (( ${#ERRORS[@]} )); then
	printf '%s sai cú pháp:\n' "$MM_FILE" >&2; printf '  %s\n' "${ERRORS[@]}" >&2
	exit 1
fi

# Ô bảng markdown: `|` phải escape, ô rỗng giữ nguyên.
cell() { local s=${1//|/\\|}; [[ -n $s ]] && printf '%s' "${2:-}$s${2:-}"; }
code() { local t out=""; for t in $1; do out+="${out:+ }$(cell "$t" '`')"; done; printf '%s' "$out"; }

# table HEADER... : doc dong tu stdin (cot cach nhau \x1f), in bang markdown
# can cot giong prettier — de formatter cua IDE khong doi gi khi luu.
table() {
	local -a head=("$@") w rows row
	local i line
	for i in "${!head[@]}"; do w[i]=$(( ${#head[i]} > 3 ? ${#head[i]} : 3 )); done
	while IFS= read -r line; do
		rows+=("$line")
		IFS=$'\x1f' read -ra row <<<"$line"
		for i in "${!head[@]}"; do (( ${#row[i]} > w[i] )) && w[i]=${#row[i]}; done
	done
	trow() { local out="|" i; for i in "${!head[@]}"; do out+=" $(pad "${1:-}" "${w[i]}") |"; shift; done; printf '%s\n' "$out"; }
	trow "${head[@]}"
	line="|"; for i in "${!head[@]}"; do line+=" $(printf '%*s' "${w[i]}" '' | tr ' ' -) |"; done
	printf '%s\n' "$line"
	for line in "${rows[@]}"; do
		IFS=$'\x1f' read -ra row <<<"$line"
		trow "${row[@]}"
	done
}

gen() {
	local repo i src name
	name=$(basename "$MM_FILE")
	repo=$(basename "$(cd "$(dirname "$MM_FILE")" && pwd)")
	printf '<!-- Sinh bởi `mm doc` từ %s — sửa chú thích ## trong %s rồi chạy `make help-doc`, không sửa file này. -->\n\n' "$name" "$name"
	printf '# make · %s\n\n' "$repo"
	printf 'Chạy `make menu` để chọn lệnh bằng giao diện, hoặc `make <target> [biến=giá-trị]`.\n'
	printf 'Biến trong `[ ]` là tuỳ chọn.\n'

	# Gom dong theo nhom, gap nhom moi thi in bang cua nhom truoc.
	local rows="" group
	for i in "${!T_NAME[@]}"; do
		if [[ -z $rows || ${T_GROUP[i]} != "$group" ]]; then
			[[ -n $rows ]] && table Target Biến "Mô tả" <<<"${rows%$'\n'}"
			group=${T_GROUP[i]} rows=""
			printf '\n## %s\n\n' "${group:-Khác}"
		fi
		rows+="$(cell "${T_NAME[i]}" '`')"$'\x1f'"$(code "${T_SPEC[i]}")"$'\x1f'"$(cell "${T_DESC[i]}")"$'\n'
	done
	[[ -n $rows ]] && table Target Biến "Mô tả" <<<"${rows%$'\n'}"

	(( ${#V_NAME[@]} )) || return 0
	printf '\n## Biến\n\nMenu lấy gợi ý từ lệnh nguồn (chạy ở thư mục repo, đã nạp `.env`).\n\n'
	for i in "${!V_NAME[@]}"; do
		case ${V_SRC[i]} in
			confirm) src="hỏi Có/Không" ;;
			skip)    src="không hỏi" ;;
			'')      src="nhập tay" ;;
			*)       src=$(cell "${V_SRC[i]}" '`') ;;
		esac
		printf '%s\x1f%s\x1f%s\x1f%s\n' "$(cell "${V_NAME[i]}" '`')" "$(cell "${V_PAT[i]}" '`')" "$(cell "${V_TITLE[i]}")" "$src"
	done | table Biến "Áp cho" "Tiêu đề" Nguồn
}

out=${MM_OUT:-$(dirname "$MM_FILE")/MAKEFILE.md}
if [[ $out == - ]]; then gen; exit; fi
gen > "$out" && echo "wrote $out"
