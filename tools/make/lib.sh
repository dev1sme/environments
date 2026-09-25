# Doc chu thich ## trong makefile — dung chung cho menu/help/check/doc (source, khong chay rieng).
# Cu phap: xem README.md cung thu muc.
#
# Sau parse_makefile FILE:
#   T_NAME T_GROUP T_SPEC T_DESC   target co ##, theo thu tu trong file
#   V_NAME V_PAT V_TITLE V_SRC     khai bao #!var (V_PAT rong = moi target)
#   HIDDEN                         target khong co ## (khong hien)
#   ERRORS                         "dòng N: ..." — chu thich sai cu phap

trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# pad S N: them space cho du N ky tu (${#} dem ky tu, khong dem byte).
pad() { local s=$1; printf '%s%*s' "$s" $(( $2 > ${#s} ? $2 - ${#s} : 0 )) ''; }

# trunc S N: cat S con toi da N ky tu.
trunc() { local s=$1; (( ${#s} > $2 )) && s="${s:0:$(( $2 - 1 ))}…"; printf '%s' "$s"; }

VAR_TOK='^\[?[A-Za-z_][A-Za-z0-9_]*=[^]]*\]?$'
TARGET_RE='^([A-Za-z0-9][A-Za-z0-9_./-]*)[[:space:]]*:([^=]|$)'

parse_makefile() {
	local file=$1 raw line n=0 group="" a b c name doc spec tok ok
	local -A seen=()
	T_NAME=() T_GROUP=() T_SPEC=() T_DESC=()
	V_NAME=() V_PAT=() V_TITLE=() V_SRC=()
	HIDDEN=() ERRORS=()

	while IFS= read -r raw || [[ -n $raw ]]; do
		n=$(( n + 1 ))
		[[ $raw == $'\t'* ]] && continue  # dong recipe

		if [[ $raw =~ ^##@ ]]; then
			group=$(trim "${raw#\#\#@}")
			[[ -z $group ]] && ERRORS+=("dòng $n: tên nhóm rỗng (##@ Tên)")
			continue
		fi

		if [[ $raw == '#!'* ]]; then
			(( n == 1 )) && [[ $raw != '#!var '* ]] && continue  # shebang kieu #!make
			if [[ $raw != '#!var '* ]]; then
				ERRORS+=("dòng $n: lệnh lạ '${raw%% *}' (chỉ có #!var)"); continue
			fi
			# read: bien cuoi nhan phan con lai, nen lenh co `|` van nguyen ven.
			IFS='|' read -r a b c <<<"${raw#\#!var }"
			a=$(trim "$a")
			name=${a%%@*}
			if [[ ! $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
				ERRORS+=("dòng $n: tên biến không hợp lệ: '$name'"); continue
			fi
			V_NAME+=("$name"); V_TITLE+=("$(trim "$b")"); V_SRC+=("$(trim "$c")")
			[[ $a == *@* ]] && V_PAT+=("${a#*@}") || V_PAT+=("")
			continue
		fi

		[[ $raw =~ $TARGET_RE ]] || continue
		name=${BASH_REMATCH[1]}
		line=${raw#*:}
		if [[ $line != *'##'* ]]; then
			HIDDEN+=("$name"); continue
		fi
		doc=$(trim "${line#*##}")

		# "x=vd [y=vd] | mo ta" -> co bien; khong co | -> chi mo ta.
		spec=""
		if [[ $doc == *'|'* ]]; then
			spec=$(trim "${doc%%|*}"); doc=$(trim "${doc#*|}")
			ok=1
			for tok in $spec; do
				[[ $tok =~ $VAR_TOK ]] && continue
				ERRORS+=("dòng $n: biến '$tok' sai dạng (cần x=vd hoặc [x=vd], mô tả đặt sau |)"); ok=0
			done
			(( ok )) || continue
		fi
		[[ -z $doc ]] && ERRORS+=("dòng $n: '$name' có ## nhưng mô tả rỗng")
		if [[ -n ${seen[$name]:-} ]]; then
			ERRORS+=("dòng $n: '$name' có ## 2 lần (dòng ${seen[$name]})"); continue
		fi
		seen[$name]=$n
		T_NAME+=("$name"); T_GROUP+=("$group"); T_SPEC+=("$spec"); T_DESC+=("$doc")
	done < "$file"
}

# find_var NAME TARGET -> VT (tieu de), VS (nguon). #!var dau tien khop thang.
find_var() {
	local i
	for i in "${!V_NAME[@]}"; do
		[[ ${V_NAME[i]} == "$1" ]] || continue
		# shellcheck disable=SC2053  # V_PAT la glob, co y khong quote
		[[ -z ${V_PAT[i]} || $2 == ${V_PAT[i]} ]] || continue
		VT=${V_TITLE[i]}; VS=${V_SRC[i]}
		return 0
	done
	VT="" VS=""
	return 1
}
