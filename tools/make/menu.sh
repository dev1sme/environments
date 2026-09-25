#!/usr/bin/env bash
# `mm menu`: giao dien kieu clack (┌ │ ◆ ◇ └), bash thuan, khong can fzf.
# Khong dung `set -e`: (( )) tra 1 khi ket qua = 0 se giet script giua chung.
set -uo pipefail

# Moi quy tac (bien, goi y) nam trong chu thich ## cua makefile — file nay
# khong gan voi repo nao. Chay o thu muc cua makefile (make tu cd vao do).
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$DIR/lib.sh"
: "${MM_FILE:?chạy qua mm}"

[ -t 0 ] && [ -t 1 ] || { echo "make menu cần terminal, dùng: make help"; exit 1; }

parse_makefile "$MM_FILE"
if (( ${#ERRORS[@]} )); then
	printf '%s sai cú pháp:\n' "$MM_FILE"; printf '  %s\n' "${ERRORS[@]}"
	echo "Chạy: make help-check"; exit 1
fi
(( ${#T_NAME[@]} )) || { echo "$MM_FILE chưa có target nào có ## — xem $DIR/README.md"; exit 1; }

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
BACK_OK=0    # 1: Esc = quay lai buoc truoc (widget tra 2); 0: Esc = thoat
DONE_LINES=3 # so dong 1 khoi ◇ cua done_step

# draw BUF: xoa khoi cu (DRAWN dong) roi in BUF (moi dong ket thuc bang \n).
draw() {
	(( DRAWN > 0 )) && printf '%s' "$E[${DRAWN}A"
	printf '\r%s%s' "$E[J" "$1"
	local only_nl=${1//[^$NL]/}
	DRAWN=${#only_nl}
}

# Chot buoc: thu gon thanh ◇ + gia tri (DONE_LINES dong). Cat theo be ngang
# de khong xuong dong — quay lai buoc truoc can biet chinh xac so dong de xoa.
done_step() {
	local cols; cols=$(stty size 2>/dev/null | cut -d" " -f2); cols=${cols:-80}
	draw "${GREEN}◇${RST}  $(trunc "$1" $(( cols - 4 )))${NL}$BAR  ${DIM}$(trunc "$2" $(( cols - 4 )))${RST}${NL}$BAR${NL}"
	DRAWN=0
}

# Xoa khoi ◇ ngay tren khoi dang hien — lan draw ke tiep ve de len do.
undo_step() { DRAWN=$(( DRAWN + DONE_LINES )); }

esc_hint() { (( BACK_OK )) && printf 'Esc quay lại · Ctrl-C thoát' || printf 'Esc thoát'; }

cancel() {
	draw "${RED}■${RST}  ${STEP}${NL}${GRAY}└${RST}  ${RED}Đã huỷ${RST}${NL}"
	exit 0
}

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
# select_ui TITLE CUSTOM [INIT]
#   Dung mang L_KEY/L_TAG/L_DESC/L_HINT. CUSTOM=1 cho phep dung chu da go.
#   INIT: gia tri chon san (co trong list -> dat con tro, khong -> dien vao o tim).
#   Ket qua: PICK (gia tri). Return 2 = quay lai.
select_ui() {
	local title=$1 custom=$2 init=${3:-} q="" cur=0 top=0 i k n buf line kw=0 tw=0 cols room
	local -a idx
	STEP=$title
	for i in "${!L_KEY[@]}"; do
		(( ${#L_KEY[i]} > kw )) && kw=${#L_KEY[i]}
		(( ${#L_TAG[i]} > tw )) && tw=${#L_TAG[i]}
		[[ -n $init && ${L_KEY[i]} == "$init" ]] && cur=$i
	done
	[[ -n $init && ${L_KEY[cur]:-} != "$init" ]] && q=$init

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
		buf+="${GRAY}└${RST}  ${DIM}↑/↓ chọn · gõ để lọc · Enter chọn · $(esc_hint)${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			up)    (( cur > 0 )) && cur=$(( cur - 1 )) ;;
			down)  (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
			esc)   (( BACK_OK )) && return 2; cancel ;;
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

# text_ui TITLE PLACEHOLDER OPTIONAL [INIT] -> PICK. Return 2 = quay lai.
text_ui() {
	local title=$1 ph=$2 opt=$3 q=${4:-} err="" buf hint
	STEP=$title
	hint="Enter xác nhận · $(esc_hint)"
	(( opt )) && hint="Enter để trống = bỏ qua · $(esc_hint)"
	while :; do
		buf="${CYAN}◆${RST}  ${BOLD}${title}${RST}${NL}"
		if [[ -n $q ]]; then buf+="$BAR  ${q}${INV} ${RST}${NL}"
		else buf+="$BAR  ${INV}${ph:0:1}${RST}${DIM}${ph:1}${RST}${NL}"; fi
		[[ -n $err ]] && buf+="${YELLOW}▲  ${err}${RST}${NL}"
		buf+="${GRAY}└${RST}  ${DIM}${hint}${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			esc)   (( BACK_OK )) && return 2; cancel ;;
			bs)    q=${q%?} ;;
			enter)
				if [[ -z $q ]] && (( ! opt )); then err="Bắt buộc nhập"; continue; fi
				PICK=$q; return ;;
			up|down|left|right|ignore) ;;
			*)     q+=$KEY; err="" ;;
		esac
	done
}

# confirm_ui TITLE DEFAULT(0|1) -> PICK=1|0. Return 2 = quay lai.
confirm_ui() {
	local title=$1 yes=$2 buf a b
	STEP=$title
	while :; do
		if (( yes )); then a="${GREEN}●${RST} Có"; b="${DIM}○ Không${RST}"
		else a="${DIM}○ Có${RST}"; b="${GREEN}●${RST} Không"; fi
		buf="${CYAN}◆${RST}  ${BOLD}${title}${RST}${NL}$BAR  $a ${DIM}/${RST} $b${NL}"
		buf+="${GRAY}└${RST}  ${DIM}←/→ chọn · Enter xác nhận · $(esc_hint)${RST}${NL}"
		draw "$buf"

		readkey
		case $KEY in
			left|right|up|down) yes=$(( 1 - yes )) ;;
			y|Y|c|C) yes=1 ;;
			n|N|k|K) yes=0 ;;
			esc)     (( BACK_OK )) && return 2; cancel ;;
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

# Buoc 0 = chon target, buoc 1..N = tung bien. Esc o buoc >= 1 lui lai.
# VAL[s]: gia tri da chon (dien san khi quay lai), ARG[s]: "ten=gia-tri" hoac rong,
# SHOWN[s]=1 neu buoc s dang co khoi ◇ tren man hinh (buoc skip thi khong).
step=0 target="" ti=0
TOKS=() VAL=() ARG=() SHOWN=()
while :; do
	if (( step == 0 )); then
		BACK_OK=0
		L_KEY=("${T_NAME[@]}") L_TAG=("${T_GROUP[@]}") L_DESC=("${T_DESC[@]}") L_HINT=("${T_SPEC[@]}")
		select_ui "Chọn lệnh" 0 "$target"
		# Doi target -> bo gia tri cu; giu target -> van dien san.
		[[ $PICK != "$target" ]] && VAL=() ARG=()
		target=$PICK
		for i in "${!T_NAME[@]}"; do [[ ${T_NAME[i]} == "$target" ]] && ti=$i; done
		read -ra TOKS <<<"${T_SPEC[ti]}"
		done_step "Chọn lệnh" "$target — ${T_DESC[ti]}"
		SHOWN[0]=1; step=1
		continue
	fi
	(( step > ${#TOKS[@]} )) && break

	tok=${TOKS[step - 1]}
	optional=0
	[[ $tok == \[* ]] && optional=1
	tok=${tok#[}; tok=${tok%]}
	name=${tok%%=*}; example=${tok#*=}
	find_var "$name" "$target"
	title=${VT:-$name}
	BACK_OK=1 SHOWN[step]=0 rc=0

	case $VS in
		skip)
			ARG[step]=""; step=$(( step + 1 )); continue ;;
		confirm)
			confirm_ui "$title" "${VAL[step]:-0}"; rc=$?
			if (( rc == 0 )); then
				VAL[step]=$PICK
				(( PICK )) && ARG[step]="$name=$example" || ARG[step]=""
				shown=$( (( PICK )) && echo Có || echo Không)
			fi ;;
		*)
			hints=""; [[ -n $VS ]] && hints=$(run_source "$VS")
			if [[ -n $hints ]]; then
				load_list <<<"$hints"
				select_ui "$title" 1 "${VAL[step]:-}"; rc=$?
			else
				ph=$example; [[ $ph == "..." ]] && ph=""
				(( optional )) || ph="vd: $ph"
				(( optional )) && ph="${ph:-bỏ trống = mặc định}"
				text_ui "$title" "$ph" "$optional" "${VAL[step]:-}"; rc=$?
			fi
			if (( rc == 0 )); then
				VAL[step]=$PICK
				[[ -n $PICK ]] && ARG[step]="$name=$PICK" || ARG[step]=""
				shown=${PICK:-(bỏ qua)}
			fi ;;
	esac

	if (( rc == 2 )); then
		# Lui ve buoc gan nhat co khoi ◇ (bo qua buoc skip), xoa khoi do.
		step=$(( step - 1 ))
		while (( step > 0 && ! ${SHOWN[step]:-0} )); do step=$(( step - 1 )); done
		undo_step; SHOWN[step]=0
		continue
	fi
	done_step "$title" "$shown"
	SHOWN[step]=1; step=$(( step + 1 ))
done

ARGS=()
for (( k = 1; k <= ${#TOKS[@]}; k++ )); do [[ -n ${ARG[k]:-} ]] && ARGS+=("${ARG[k]}"); done

MK=(make); [[ -n ${MM_F:-} ]] && MK+=(-f "$MM_FILE")
cmd="${MK[*]} $target${ARGS[*]:+ ${ARGS[*]}}"
printf '%s└%s  %s$ %s%s\n\n' "$GRAY" "$RST" "$CYAN" "$cmd" "$RST"
cleanup
trap - EXIT INT
exec "${MK[@]}" --no-print-directory "$target" "${ARGS[@]}"
