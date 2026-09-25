#!/usr/bin/env bash
# In services.yaml cho homepage tu tools/proxy/conf.d/*.conf + conf.d/vhosts/*.conf.
# Goi boi `make home-gen` (trong `make up` / `make reload`), khong chay tay.
#
# App (vhosts/) va tool (conf.d/) tach 2 nhom. Status: homepage ping ten
# upstream qua env-net. Khong dung siteMonitor: HTTP status cua upstream khong
# noi len app song hay chet (icms / tra 404, homepage chan Host la).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../proxy/conf.d" || exit 1

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

rows=$(parse)

echo "# SINH TU DONG boi \`make reload\` tu tools/proxy/conf.d — dung sua tay."
echo "# Link viet tay: bookmarks.yaml"
for group in Apps Tools; do
	echo "- $group:"
	printf '%s\n' "$rows" | while IFS=$'\t' read -r name up file; do
		[ -n "$name" ] || continue
		case "$file" in vhosts/*) g=Apps ;; *) g=Tools ;; esac
		[ "$g" = "$group" ] || continue
		echo "    - ${name%%.*}:"
		echo "        href: \"https://$name\""
		case "$up" in
			static:*) echo "        description: \"static ${up#static:}\"" ;;
			-)        echo "        description: \"$file\"" ;;
			*)        echo "        description: \"$up\""
			          # http://name:port/path -> name
			          echo "        ping: \"$(printf %s "$up" | sed -E 's#^[a-z]+://##; s#[:/].*##')\"" ;;
		esac
	done
done
