#!/usr/bin/env bash
# `make menu`: chon target bang fzf, hoi bien can thiet, roi chay make.
set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$DIR/../.." && pwd)
FILE="$DIR/targets.txt"
cd "$ROOT"

command -v fzf >/dev/null || { echo "can fzf (apt install fzf), hoac dung: make help"; exit 1; }

PROJECTS_ROOT=$(sed -n 's/^PROJECTS_ROOT=//p' .env 2>/dev/null || true)

# Moi dong: target \t bien \t mo ta \t dong hien thi
list=$(awk -F'|' '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
/^[ \t]*(#|$)/ { next }
/^@/           { g = substr($0, 2); next }
{
	t = trim($1); a = trim($2); d = trim($3)
	printf "%s\t%s\t%s\t%-12s \033[2m%-12s\033[0m %s\n", t, a, d, t, g, d
}' "$FILE")

sel=$(printf '%s\n' "$list" | fzf --ansi --reverse --height=70% \
	--delimiter=$'\t' --with-nth=4 --prompt='make > ' \
	--header='Enter: chay   Esc: thoat' \
	--preview='printf "\033[36mmake %s\033[0m \033[33m%s\033[0m\n\n%s\n" {1} {2} {3}' \
	--preview-window=down,4,wrap) || exit 0

# cut, khong dung `read`: IFS tab gop field rong lien tiep -> lech cot.
target=$(cut -f1 <<<"$sel")
spec=$(cut -f2 <<<"$sel")

# Chon gia tri bang fzf; go gia tri khac list thi lay chu da go.
pick() {
	local prompt=$1 out
	out=$(fzf --reverse --height=40% --print-query --prompt="$prompt > ") || [ $? -eq 1 ] || return 1
	printf '%s\n' "$out" | sed '/^$/d' | tail -n 1
}

# Nguon goi y cho tung bien.
choices() {
	case "$1" in
		n) docker compose config --services 2>/dev/null ;;
		f) ls -1t .data/dump/* 2>/dev/null ;;
		p) case "$target" in
			cg-*) [ -n "$PROJECTS_ROOT" ] && find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort ;;
			*)    find projects -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort ;;
		   esac ;;
	esac
}

args=()
for tok in $spec; do
	optional=0
	[[ $tok == \[* ]] && optional=1
	name=${tok#[}; name=${name%%=*}
	# cg-auth tu hoi password (an ky tu) — khong nhan o day.
	[ "$name" = pw ] && continue

	hints=$(choices "$name" || true)
	if [ -n "$hints" ]; then
		val=$(printf '%s\n' "$hints" | pick "$name") || exit 0
	else
		label="$name"; [ $optional -eq 1 ] && label="$name (Enter = bo qua)"
		read -rp "$label: " val
	fi

	if [ -z "$val" ]; then
		[ $optional -eq 1 ] && continue
		echo "thieu $name, huy."; exit 1
	fi
	args+=("$name=$val")
done

printf '\033[2m$ make %s %s\033[0m\n' "$target" "${args[*]:-}"
exec make --no-print-directory "$target" "${args[@]}"
