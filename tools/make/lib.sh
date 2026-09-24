# Doc targets.txt — dung chung cho menu.sh va check.sh (source, khong chay rieng).
#
# Sau parse_targets FILE:
#   T_NAME T_GROUP T_SPEC T_DESC   target, theo thu tu trong file
#   V_NAME V_PAT V_TITLE V_SRC     khai bao !var (V_PAT rong = moi target)
#   HIDDEN                         ten trong !hide
#   ERRORS                         "dòng N: ..." — file sai cu phap

trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

parse_targets() {
	local file=$1 raw line n=0 group="" a b c name tok
	local -A seen=()
	T_NAME=() T_GROUP=() T_SPEC=() T_DESC=()
	V_NAME=() V_PAT=() V_TITLE=() V_SRC=()
	HIDDEN=() ERRORS=()

	while IFS= read -r raw || [[ -n $raw ]]; do
		n=$(( n + 1 ))
		line=$(trim "$raw")
		[[ -z $line || $line == \#* ]] && continue

		case $line in
			@*)
				group=$(trim "${line#@}")
				[[ -z $group ]] && ERRORS+=("dòng $n: tên nhóm rỗng")
				;;
			'!var '*)
				# read: bien cuoi nhan phan con lai, nen lenh co `|` van nguyen ven.
				IFS='|' read -r a b c <<<"${line#!var }"
				a=$(trim "$a")
				name=${a%%@*}
				if [[ ! $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
					ERRORS+=("dòng $n: tên biến không hợp lệ: '$name'"); continue
				fi
				V_NAME+=("$name"); V_TITLE+=("$(trim "$b")"); V_SRC+=("$(trim "$c")")
				[[ $a == *@* ]] && V_PAT+=("${a#*@}") || V_PAT+=("")
				;;
			'!hide '*)
				read -ra a <<<"${line#!hide }"
				HIDDEN+=("${a[@]}")
				;;
			'!'*)
				ERRORS+=("dòng $n: lệnh lạ '${line%% *}' (chỉ có !var, !hide)")
				;;
			*)
				if [[ $line != *'|'*'|'* ]]; then
					ERRORS+=("dòng $n: cần dạng 'target | biến | mô tả'"); continue
				fi
				IFS='|' read -r a b c <<<"$line"
				name=$(trim "$a")
				if [[ ! $name =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
					ERRORS+=("dòng $n: tên target không hợp lệ: '$name'"); continue
				fi
				[[ -n ${seen[$name]:-} ]] && ERRORS+=("dòng $n: '$name' khai báo 2 lần (dòng ${seen[$name]})")
				seen[$name]=$n
				for tok in $b; do
					[[ $tok =~ ^\[?[A-Za-z_][A-Za-z0-9_]*=[^]]*\]?$ ]] \
						|| ERRORS+=("dòng $n: biến '$tok' sai dạng (cần x=vd hoặc [x=vd])")
				done
				[[ -z $group ]] && ERRORS+=("dòng $n: '$name' nằm ngoài nhóm (@Tên)")
				T_NAME+=("$name"); T_GROUP+=("$group"); T_SPEC+=("$(trim "$b")"); T_DESC+=("$(trim "$c")")
				;;
		esac
	done < "$file"
}

# find_var NAME TARGET -> VT (tieu de), VS (nguon). !var dau tien khop thang.
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
