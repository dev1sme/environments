#!/usr/bin/env bash
# `make menu`: giao dien kieu clack (┌ │ ◆ ◇ └), bash thuan, khong can fzf.
# Khong dung `set -e`: (( )) tra 1 khi ket qua = 0 se giet script giua chung.
set -uo pipefail

# Moi quy tac (bien, goi y, an) nam trong targets.txt — file nay khong gan
# voi repo nao. Chay tu thu muc cua makefile (make tu cd vao do).
DIR=$(cd "$(dirname "$0")" && pwd)
FILE="$DIR/targets.txt"
. "$DIR/lib.sh"

[ -t 0 ] && [ -t 1 ] || { echo "make menu cần terminal, dùng: make help"; exit 1; }

parse_targets "$FILE"
if (( ${#ERRORS[@]} )); then
	printf '%s sai cú pháp:\n' "$FILE"; printf '  %s\n' "${ERRORS[@]}"
	echo "Chạy: make help-check"; exit 1
fi

VISIBLE=10  # so dong toi da cua 1 list

# ---------- mau + ky hieu ----------
E=$'\033'; NL=$'\n'
RST="$E[0m" BOLD="$E[1m" DIM="$E[2m" INV="$E[7m"
GRAY="$E[90m" CYAN="$E[36m" GREEN="$E[32m" YELLOW="$E[33m" RED="$E[31m"
BAR="${GRAY}│${RST}"

SAVED_STTY=$(stty -g)
cleanup() { printf '%s' "$E[?25h"; stty "$SAVED_STTY" 2>/dev/null; }
trap cleanup EXIT
trap cancel INT
stty -echo
printf '%s' "$E[?25l"

# ---------- ve ----------
DRAWN=0      # so dong cua khoi dang hien, de xoa va ve lai
STEP=""      # tieu de buoc hien tai, dung khi huy

# draw BUF: xoa khoi cu (DRAWN dong) roi in BUF (moi dong ket thuc bang \n).
draw() {
	(( DRAWN > 0 )) && printf '%s' "$E[${DRAWN}A"
	printf '\r%s%s' "$E[J" "$1"
	local only_nl=${1//[^$NL]/}
	DRAWN=${#only_nl}
}

# Chot buoc: thu gon thanh ◇ + gia tri, khoi nay khong bi xoa nua.
done_step() {
	draw "${GREEN}◇${RST}  $1${NL}$BAR  ${DIM}$2${RST}${NL}$BAR${NL}"
	DRAWN=0
}

cancel() {
	draw "${RED}■${RST}  ${STEP}${NL}${GRAY}└${RST}  ${RED}Đã huỷ${RST}${NL}"
	exit 0
}

# pad S N: them space cho du N ky tu (${#} dem ky tu, khong dem byte).
pad() { local s=$1; printf '%s%*s' "$s" $(( $2 > ${#s} ? $2 - ${#s} : 0 )) ''; }

# trunc S N: cat S con toi da N ky tu.
trunc() { local s=$1; (( ${#s} > $2 )) && s="${s:0:$(( $2 - 1 ))}…"; printf '%s' "$s"; }

# Doc 1 phim -> KEY: up|down|left|right|enter|esc|bs|<ky tu>
readkey() {
	local k rest
	IFS= read -rsn1 k
	case $k in
		$'\e')
			IFS= read -rsn2 -t 0.02 rest
			case $rest in
				'[A') KEY=up ;; '[B') KEY=down ;; '[C') KEY=right ;; '[D') KEY=left ;;
				'') KEY=esc ;; *) KEY=ignore ;;
			esac ;;
		'') KEY=enter ;;
		$'\x7f'|$'\b') KEY=bs ;;
		*) [[ $k == [[:print:]] ]] && KEY=$k || KEY=ignore ;;
	esac
}

# ---------- widget ----------
# select_ui TITLE CUSTOM
#   Dung mang L_KEY/L_TAG/L_DESC/L_HINT. CUSTOM=1 cho phep dung chu da go.
#   Ket qua: PICK (gia tri).
select_ui() {
	local title=$1 custom=$2 q="" cur=0 top=0 i k n buf line kw=0 tw=0 cols room
	local -a idx
	STEP=$title
	for i in "${!L_KEY[@]}"; do
		(( ${#L_KEY[i]} > kw )) && kw=${#L_KEY[i]}
		(( ${#L_TAG[i]} > tw )) && tw=${#L_TAG[i]}
	done

	while :; do
		# Khop ten truoc, khop tag/mo ta xep sau — "re" ra reup/reload, khong ra "coredns".
		idx=(); local -a rest=()
		for i in "${!L_KEY[@]}"; do
			if [[ ${L_KEY[i],,} == *"${q,,}"* ]]; then idx+=("$i")
			elif [[ "${L_TAG[i],,} ${L_DESC[i],,}" == *"${q,,}"* ]]; then rest+=("$i"); fi
		done
		idx+=("${rest[@]}")
		# Go chu khong trung han muc nao -> them dong "dung chu da go".
		if [[ $custom == 1 && -n $q ]]; then
			local exact=0
			for i in "${idx[@]}"; do [[ ${L_KEY[i]} == "$q" ]] && exact=1; done
			(( exact )) || idx+=(-1)
		fi
		n=${#idx[@]}
		(( cur >= n )) && cur=$(( n > 0 ? n - 1 : 0 ))
		(( cur < top )) && top=$cur
		(( cur >= top + VISIBLE )) && top=$(( cur - VISIBLE + 1 ))

		cols=$(stty size 2>/dev/null | cut -d" " -f2); cols=${cols:-80}
		buf="${CYAN}◆${RST}  ${BOLD}${title}${RST}${NL}"
		buf+="$BAR  ${DIM}Tìm:${RST} ${q}${INV} ${RST}${NL}"
		(( n == 0 )) && buf+="$BAR  ${DIM}Không có mục nào khớp${RST}${NL}"
		(( top > 0 )) && buf+="$BAR  ${DIM}  ↑ còn $top mục${RST}${NL}"
		for (( k = top; k < n && k < top + VISIBLE; k++ )); do
			i=${idx[k]}
			if (( i < 0 )); then
				line="dùng \"$q\""
				(( k == cur )) && buf+="$BAR  ${GREEN}●${RST} ${YELLOW}${line}${RST}${NL}" \
				               || buf+="$BAR  ${DIM}○ ${line}${RST}${NL}"
				continue
			fi
			room=$(( cols - 11 - kw - tw - ${#L_HINT[i]} ))  # 11 = "│  ● " + 2 khoang cach cot + 1 space truoc hint + 1 le phai
			(( room < 10 )) && room=10
			line="$(pad "${L_KEY[i]}" "$kw")"
			(( tw > 0 )) && line+="  ${DIM}$(pad "${L_TAG[i]}" "$tw")${RST}"
			if (( k == cur )); then
				local dc=""; [[ ${L_DESC[i]} == ⚠* ]] && dc=$YELLOW
				buf+="$BAR  ${GREEN}●${RST} ${CYAN}${line}${RST}  ${dc}$(trunc "${L_DESC[i]}" "$room")${RST} ${YELLOW}${L_HINT[i]}${RST}${NL}"
			else
				local dc=$DIM; [[ ${L_DESC[i]} == ⚠* ]] && dc=$YELLOW
				buf+="$BAR  ${DIM}○${RST} ${line}  ${dc}$(trunc "${L_DESC[i]}" "$room")${RST}${NL}"
			fi
		done
		(( top + VISIBLE < n )) && buf+="$BAR  ${DIM}  ↓ còn $(( n - top - VISIBLE )) mục${RST}${NL}"
		buf+="${GRAY}└${RST}  ${DIM}↑/↓ chọn · gõ để lọc · Enter chọn · Esc thoát${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			up)    (( cur > 0 )) && cur=$(( cur - 1 )) ;;
			down)  (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
			esc)   cancel ;;
			bs)    q=${q%?}; cur=0 ;;
			enter)
				(( n == 0 )) && continue
				i=${idx[cur]}
				if (( i < 0 )); then PICK=$q; else PICK=${L_KEY[i]}; fi
				return ;;
			left|right|ignore) ;;
			*)     q+=$KEY; cur=0 ;;
		esac
	done
}

# text_ui TITLE PLACEHOLDER OPTIONAL -> PICK
text_ui() {
	local title=$1 ph=$2 opt=$3 q="" err="" buf hint
	STEP=$title
	hint="Enter xác nhận · Esc thoát"
	(( opt )) && hint="Enter để trống = bỏ qua · Esc thoát"
	while :; do
		buf="${CYAN}◆${RST}  ${BOLD}${title}${RST}${NL}"
		if [[ -n $q ]]; then buf+="$BAR  ${q}${INV} ${RST}${NL}"
		else buf+="$BAR  ${INV}${ph:0:1}${RST}${DIM}${ph:1}${RST}${NL}"; fi
		[[ -n $err ]] && buf+="${YELLOW}▲  ${err}${RST}${NL}"
		buf+="${GRAY}└${RST}  ${DIM}${hint}${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			esc)   cancel ;;
			bs)    q=${q%?} ;;
			enter)
				if [[ -z $q ]] && (( ! opt )); then err="Bắt buộc nhập"; continue; fi
				PICK=$q; return ;;
			up|down|left|right|ignore) ;;
			*)     q+=$KEY; err="" ;;
		esac
	done
}

# confirm_ui TITLE DEFAULT(0|1) -> PICK=1|0
confirm_ui() {
	local title=$1 yes=$2 buf a b
	STEP=$title
	while :; do
		if (( yes )); then a="${GREEN}●${RST} Có"; b="${DIM}○ Không${RST}"
		else a="${DIM}○ Có${RST}"; b="${GREEN}●${RST} Không"; fi
		buf="${CYAN}◆${RST}  ${BOLD}${title}${RST}${NL}$BAR  $a ${DIM}/${RST} $b${NL}"
		buf+="${GRAY}└${RST}  ${DIM}←/→ chọn · Enter xác nhận · Esc thoát${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			left|right|up|down) yes=$(( 1 - yes )) ;;
			y|Y|c|C) yes=1 ;;
			n|N|k|K) yes=0 ;;
			esc)     cancel ;;
			enter)   PICK=$yes; return ;;
		esac
	done
}

# ---------- du lieu ----------
# Chay lenh nguon goi y cua !var: o thu muc repo, nap .env (KEY=VALUE).
run_source() {
	bash -c 'set -a; [ -f .env ] && . ./.env; set +a; eval "$1"' _ "$1" 2>/dev/null
}

load_list() {  # doc "gia tri \t tag" tu stdin vao L_*
	L_KEY=() L_TAG=() L_DESC=() L_HINT=()
	local v t
	while IFS=$'\t' read -r v t; do
		[[ -z $v ]] && continue
		L_KEY+=("$v"); L_TAG+=("${t:-}"); L_DESC+=(""); L_HINT+=("")
	done
}

# ---------- flow ----------
printf '%s┌%s  %s%s%s %s· make menu%s\n%s\n' "$GRAY" "$RST" "$BOLD" "$(basename "$PWD")" "$RST" "$DIM" "$RST" "$BAR"

L_KEY=("${T_NAME[@]}") L_TAG=("${T_GROUP[@]}") L_DESC=("${T_DESC[@]}") L_HINT=("${T_SPEC[@]}") ARGS=()

select_ui "Chọn lệnh" 0
target=$PICK
for i in "${!T_NAME[@]}"; do [[ ${T_NAME[i]} == "$target" ]] && ti=$i; done
done_step "Chọn lệnh" "$target — ${T_DESC[ti]}"

for tok in ${T_SPEC[ti]}; do
	optional=0
	[[ $tok == \[* ]] && optional=1
	tok=${tok#[}; tok=${tok%]}
	name=${tok%%=*}; example=${tok#*=}
	find_var "$name" "$target"
	title=${VT:-$name}

	case $VS in
		skip) continue ;;
		confirm)
			confirm_ui "$title" 0
			done_step "$title" "$( (( PICK )) && echo Có || echo Không)"
			(( PICK )) && ARGS+=("$name=$example")
			continue ;;
	esac

	hints=""; [[ -n $VS ]] && hints=$(run_source "$VS")
	if [[ -n $hints ]]; then
		load_list <<<"$hints"
		select_ui "$title" 1
	else
		ph=$example; [[ $ph == "..." ]] && ph=""
		(( optional )) || ph="vd: $ph"
		(( optional )) && ph="${ph:-bỏ trống = mặc định}"
		text_ui "$title" "$ph" "$optional"
	fi

	if [[ -z $PICK ]]; then
		done_step "$title" "(bỏ qua)"
		continue
	fi
	done_step "$title" "$PICK"
	ARGS+=("$name=$PICK")
done

cmd="make $target${ARGS[*]:+ ${ARGS[*]}}"
printf '%s└%s  %s$ %s%s\n\n' "$GRAY" "$RST" "$CYAN" "$cmd" "$RST"
cleanup
trap - EXIT INT
exec make --no-print-directory "$target" "${ARGS[@]}"
