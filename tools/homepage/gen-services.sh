#!/usr/bin/env bash
# In services.yaml cho homepage tu tools/proxy/conf.d/vhosts/*.conf.
# Goi boi `make home-gen` (trong `make up` / `make reload`), khong chay tay.
#
# Chi lay vhost cua app (conf.d/vhosts/) — vhost cua tool trong repo nay
# (assets, home, ...) khong hien. Status: homepage ping ten
# upstream qua env-net. Khong dung siteMonitor: HTTP status cua upstream khong
# noi len app song hay chet (icms / tra 404, homepage chan Host la).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../proxy/conf.d" || exit 1

# In: domain \t upstream \t file. Chi lay server block listen 443 — block 80
# chi redirect.
parse() {
	shopt -s nullglob
	local f
	for f in vhosts/*.conf; do
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

# Icon doan theo ten domain/upstream. mdi-* va *.png (dashboard-icons) homepage
# tai tu CDN. Khong khop gi -> mdi-web.
icon() {
	case "$1 $2" in
		*tomcat*)         echo apache-tomcat.png ;;
		*postgres*|*pg*)  echo postgres.png ;;
		*codegraph*)      echo mdi-graph-outline ;;
		*static:*)        echo mdi-folder-network-outline ;;
		*api*)            echo mdi-api ;;
		*)                echo mdi-web ;;
	esac
}

rows=$(parse)

echo "# SINH TU DONG boi \`make reload\` tu tools/proxy/conf.d — dung sua tay."
echo "# Link viet tay: bookmarks.yaml"
echo "- Apps:"
printf '%s\n' "$rows" | while IFS=$'\t' read -r name up file; do
	[ -n "$name" ] || continue
	# http://name:port/path -> name:port/path
	target=$(printf %s "$up" | sed -E 's#^[a-z]+://##')
	echo "    - ${name%%.*}:"
	echo "        href: \"https://$name\""
	echo "        icon: \"$(icon "$name" "$up")\""
	case "$up" in
		static:*) echo "        description: \"$name → static\"" ;;
		-)        echo "        description: \"$name → ? ($file)\"" ;;
		*)        echo "        description: \"$name → $target\""
		          echo "        ping: \"${target%%[:/]*}\"" ;;
	esac
done
