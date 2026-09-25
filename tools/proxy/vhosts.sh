#!/usr/bin/env bash
# Liet ke domain -> upstream doc tu conf.d/*.conf + conf.d/vhosts/*.conf.
#   vhosts.sh          bang cho terminal (`make vhosts`)
#   vhosts.sh --yaml   services.yaml cho homepage (`make reload` goi)
#
# STATUS (che do bang) resolve upstream tu TRONG env-proxy — dung cai nginx thay:
#   up      resolve duoc tren env-net
#   down    khong resolve duoc (app chua chay)
#   static  vhost serve file tinh (root)
#   ?       proxy dang tat, khong kiem tra duoc
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/conf.d" || exit 1
PROXY=env-proxy
MODE=${1:-table}

# In: domain \t upstream \t file. Chi lay server block listen 443 — block 80
# chi redirect.
parse() {
	shopt -s nullglob
	local f
	for f in *.conf vhosts/*.conf; do
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
	done | sort
}

# http://name:port/path -> name
upstream_host() { sed -E 's#^[a-z]+://##; s#[:/].*##'; }

rows=$(parse)

# App (vhosts/) va tool (conf.d/) tach 2 nhom. Status: homepage ping ten
# upstream qua env-net. Khong dung siteMonitor: HTTP status cua upstream khong
# noi len app song hay chet (icms / tra 404, homepage chan Host la).
yaml() {
	echo "# SINH TU DONG boi \`make reload\` tu tools/proxy/conf.d — dung sua tay."
	echo "# Link viet tay: bookmarks.yaml"
	local group g label name up file
	for group in Apps Tools; do
		echo "- $group:"
		printf '%s\n' "$rows" | while IFS=$'\t' read -r name up file; do
			[ -n "$name" ] || continue
			case "$file" in vhosts/*) g=Apps ;; *) g=Tools ;; esac
			[ "$g" = "$group" ] || continue
			label=${name%%.*}
			echo "    - $label:"
			echo "        href: \"https://$name\""
			case "$up" in
				static:*) echo "        description: \"static ${up#static:}\"" ;;
				-)        echo "        description: \"$file\"" ;;
				*)        echo "        description: \"$up\""
				          echo "        ping: \"$(printf %s "$up" | upstream_host)\"" ;;
			esac
		done
	done
}

table() {
	[ -n "$rows" ] || { echo "khong tim thay server block 443 nao"; return; }

	local hosts proxy_up=1 resolved="" name up file st h
	hosts=$(printf '%s\n' "$rows" | cut -f2 | grep -v '^static:' | grep -v '^-$' \
		| upstream_host | sort -u)

	# 1 lan docker exec cho tat ca host, in ra cac host resolve duoc.
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
					h=$(printf '%s' "$up" | upstream_host)
					if [ $proxy_up = 0 ]; then st='?'
					elif printf '%s\n' "$resolved" | grep -qxF "$h"; then st=up
					else st=down
					fi ;;
			esac
			printf '%s\t%s\t%s\t%s\n' "$name" "$up" "$st" "$file"
		done
	} | column -t -s $'\t'

	[ $proxy_up = 1 ] || echo "(proxy $PROXY dang tat — STATUS khong kiem tra duoc)"
}

case "$MODE" in
	table)  table ;;
	--yaml) yaml ;;
	*) echo "dung: $0 [--yaml]" >&2; exit 2 ;;
esac
