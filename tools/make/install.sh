#!/usr/bin/env bash
# Cai mm cho moi project: symlink, khong copy — sua o day la project nao cung nhan.
#   ~/.local/bin/mm                 -> mm
#   ~/.local/share/make-menu        -> thu muc nay (de makefile -include menu.mk)
# Go: rm ~/.local/bin/mm ~/.local/share/make-menu
set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
BIN=${XDG_BIN_HOME:-$HOME/.local/bin}
SHARE=${XDG_DATA_HOME:-$HOME/.local/share}/make-menu

link() {  # link SRC DST: khong ghi de file/thu muc that
	if [ -e "$2" ] && [ ! -L "$2" ]; then echo "bỏ qua: $2 đã tồn tại và không phải symlink"; return 1; fi
	ln -sfn "$1" "$2" && echo "$2 -> $1"
}

mkdir -p "$BIN" "$(dirname "$SHARE")"
link "$DIR/mm" "$BIN/mm"
link "$DIR" "$SHARE"

case ":$PATH:" in *":$BIN:"*) ;; *) echo "chú ý: $BIN chưa có trong PATH" ;; esac
echo
echo "Trong makefile của project:"
echo '  -include $(HOME)/.local/share/make-menu/menu.mk'
