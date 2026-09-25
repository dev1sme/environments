#!/usr/bin/env bash
# `mm doc`: sinh MAKE.md tu chu thich ## — de xem tren GitHub/IDE. Khong sua tay.
# MM_OUT: rong = MAKE.md canh makefile, "-" = stdout (check.sh dung de so sanh).
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

gen() {
	local repo i prev=- src
	repo=$(basename "$(cd "$(dirname "$MM_FILE")" && pwd)")
	printf '<!-- Sinh bởi `mm doc` từ %s — sửa chú thích ## trong %s rồi chạy `make help-doc`, không sửa file này. -->\n\n' \
		"$(basename "$MM_FILE")" "$(basename "$MM_FILE")"
	printf '# make · %s\n\n' "$repo"
	printf 'Chạy `make menu` để chọn lệnh bằng giao diện, hoặc `make <target> [biến=giá-trị]`.\n'
	printf 'Biến trong `[ ]` là tuỳ chọn.\n'

	for i in "${!T_NAME[@]}"; do
		if [[ ${T_GROUP[i]} != "$prev" ]]; then
			prev=${T_GROUP[i]}
			printf '\n## %s\n\n| Target | Biến | Mô tả |\n|---|---|---|\n' "${prev:-Khác}"
		fi
		printf '| %s | %s | %s |\n' "$(cell "${T_NAME[i]}" '`')" "$(code "${T_SPEC[i]}")" "$(cell "${T_DESC[i]}")"
	done

	(( ${#V_NAME[@]} )) || return 0
	printf '\n## Biến\n\nMenu lấy gợi ý từ lệnh nguồn (chạy ở thư mục repo, đã nạp `.env`).\n\n'
	printf '| Biến | Áp cho | Tiêu đề | Nguồn |\n|---|---|---|---|\n'
	for i in "${!V_NAME[@]}"; do
		case ${V_SRC[i]} in
			confirm) src="hỏi Có/Không" ;;
			skip)    src="không hỏi" ;;
			'')      src="nhập tay" ;;
			*)       src=$(cell "${V_SRC[i]}" '`') ;;
		esac
		printf '| %s | %s | %s | %s |\n' "$(cell "${V_NAME[i]}" '`')" "$(cell "${V_PAT[i]}" '`')" \
			"$(cell "${V_TITLE[i]}")" "$src"
	done
}

out=${MM_OUT:-$(dirname "$MM_FILE")/MAKE.md}
if [[ $out == - ]]; then gen; exit; fi
gen > "$out" && echo "wrote $out"
