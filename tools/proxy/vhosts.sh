#!/usr/bin/env bash
# `make vhosts`: liet ke domain -> upstream doc tu conf.d/*.conf + conf.d/vhosts/*.conf.
# STATUS resolve upstream tu TRONG env-proxy — dung cai nginx thay:
#   up      resolve duoc tren env-net
#   down    khong resolve duoc (app chua chay)
#   static  vhost serve file tinh (root)
#   ?       proxy dang tat, khong kiem tra duoc
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/conf.d" || exit 1
PROXY=env-proxy

shopt -s nullglob
files=(*.conf vhosts/*.conf)
[ ${#files[@]} -gt 0 ] || { echo "khong co file .conf nao"; exit 0; }

# Chi lay server block listen 443 — block 80 chi redirect.
rows=$(for f in "${files[@]}"; do
	awk -v file="$f" '
		{ sub(/#.*/, "") }
		/listen[[:space:]]+443/          { ssl = 1 }
		/server_name[[:space:]]/         { gsub(/;/, ""); name = $2 }
		/set[[:space:]]+\$upstream[[:space:]]/ { gsub(/;/, ""); up = $3 }
		/proxy_pass[[:space:]]+http/ && !up    { gsub(/;/, ""); up = $2 }
		/^[[:space:]]*root[[:space:]]/ && !root { gsub(/;/, ""); root = $2 }
		{
			n = gsub(/{/, "{"); depth += n
			m = gsub(/}/, "}"); depth -= m
			if (m && depth == 0) {
				if (ssl && name) printf "%s\t%s\t%s\n", name, (up ? up : (root ? "static:" root : "-")), file
				ssl = 0; name = ""; up = ""; root = ""
			}
		}
	' "$f"
done | sort)

[ -n "$rows" ] || { echo "khong tim thay server block 443 nao"; exit 0; }

# Host upstream: http://name:port/path -> name
hosts=$(printf '%s\n' "$rows" | cut -f2 | grep -v '^static:' | grep -v '^-$' \
	| sed -E 's#^[a-z]+://##; s#[:/].*##' | sort -u)

# 1 lan docker exec cho tat ca host, in ra cac host resolve duoc.
proxy_up=1
resolved=""
if docker exec "$PROXY" true 2>/dev/null; then
	[ -n "$hosts" ] && resolved=$(docker exec "$PROXY" sh -c \
		'for h in "$@"; do getent hosts "$h" >/dev/null && echo "$h"; done' _ $hosts)
else
	proxy_up=0
fi

{
	printf 'DOMAIN\tUPSTREAM\tSTATUS\tFILE\n'
	printf '%s\n' "$rows" | while IFS=$'\t' read -r name up file; do
		case "$up" in
			static:*) st=static ;;
			-)        st=- ;;
			*)
				h=$(printf '%s' "$up" | sed -E 's#^[a-z]+://##; s#[:/].*##')
				if [ $proxy_up = 0 ]; then st='?'
				elif printf '%s\n' "$resolved" | grep -qxF "$h"; then st=up
				else st=down
				fi ;;
		esac
		printf '%s\t%s\t%s\t%s\n' "$name" "$up" "$st" "$file"
	done
} | column -t -s $'\t'

[ $proxy_up = 1 ] || echo "(proxy $PROXY dang tat — STATUS khong kiem tra duoc)"
