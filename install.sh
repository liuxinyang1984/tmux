#!/bin/sh
# 个人安装（默认）：配置 symlink 到本仓；插件仍在 ~/.config/tmux/plugins
#   ./install.sh              # 默认 symlink
#   ./install.sh --copy       # 拷贝配置
#   ./install.sh --dev        # 同默认（兼容旧用法）
#   ./install.sh --plugins-only
# 仅个人安装，无 --system。
# kiosk 已迁至父仓: ./install.sh desktop:kiosk
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
INSTALL_DIR="${TMUX_INSTALL_DIR:-$CONFIG_HOME/tmux}"
PLUG_DIR="$INSTALL_DIR/plugins"
TPM_DIR="$PLUG_DIR/tpm"

MODE=link
DO_TMUX=0
DO_PLUGINS_ONLY=0

usage() {
	cat <<'EOF'
用法: ./install.sh [--copy|--dev] [tmux]...
      ./install.sh --plugins-only

  （默认，无组件名）  等同 ./install.sh tmux
  tmux                 配置 → ~/.config/tmux，并安装/更新 TPM 插件
  （默认）             配置文件 symlink 到本仓库
  --copy               拷贝配置（不链）
  --dev                同默认（兼容）
  --plugins-only       只装/更新插件（不写配置）
  -h, --help           显示本说明

仅个人安装，无 --system。tmux 会自动读 ~/.config/tmux/tmux.conf。

无 WM 全屏会话已迁出：父仓 ./install.sh desktop:kiosk
EOF
}

for arg in "$@"; do
	case "$arg" in
	--copy) MODE=copy ;;
	--dev) MODE=link ;;
	--plugins-only) DO_PLUGINS_ONLY=1 ;;
	tmux) DO_TMUX=1 ;;
	kiosk)
		echo "kiosk 已迁至: ~/git/dotfiles/config/x11/kiosk/" >&2
		echo "请运行: ~/git/dotfiles/install.sh desktop:kiosk" >&2
		exit 1
		;;
	-h|--help) usage; exit 0 ;;
	*)
		echo "未知参数: $arg（见 ./install.sh --help）" >&2
		exit 1
		;;
	esac
done

# 无组件名且非 --plugins-only → 默认装 tmux 配置
if [ "$DO_PLUGINS_ONLY" -eq 0 ] && [ "$DO_TMUX" -eq 0 ]; then
	DO_TMUX=1
fi

CONFIG_FILES="tmux.conf fcitx.conf fcitx-status.sh fcitx-watch.sh"

ensure_tpm() {
	mkdir -p "$PLUG_DIR"
	if [ -d "$TPM_DIR/.git" ]; then
		git -C "$TPM_DIR" fetch --depth 1 origin
		git -C "$TPM_DIR" reset --hard FETCH_HEAD
	else
		git clone --depth 1 https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
	fi
	echo "TPM → $TPM_DIR"
}

install_plugins() {
	ensure_tpm
	conf="$INSTALL_DIR/tmux.conf"
	if [ ! -f "$conf" ] && [ ! -L "$conf" ]; then
		conf="$ROOT/tmux.conf"
	fi
	if [ ! -x "$TPM_DIR/bin/install_plugins" ]; then
		echo "警告: 找不到 tpm install_plugins" >&2
		return 0
	fi
	echo "安装 TPM 插件（按 $conf 中的 @plugin）…"
	export TMUX_PLUGIN_MANAGER_PATH="$PLUG_DIR"
	"$TPM_DIR/bin/install_plugins" || {
		echo "警告: install_plugins 未完全成功（可稍后在 tmux 里 prefix+I）" >&2
		return 0
	}
}

link_or_copy_file() {
	src="$1"
	dest="$2"
	mode="$3"
	mkdir -p "$(dirname "$dest")"
	if [ "$mode" = link ]; then
		ln -sfn "$src" "$dest"
		echo "symlink $dest → $src"
	else
		[ -L "$dest" ] && rm -f "$dest"
		cp -f "$src" "$dest"
		case "$dest" in
		*.sh) chmod +x "$dest" ;;
		esac
		echo "copy $dest"
	fi
}

sync_config() {
	mkdir -p "$INSTALL_DIR"
	for f in $CONFIG_FILES; do
		if [ ! -f "$ROOT/$f" ]; then
			echo "缺少 $ROOT/$f" >&2
			exit 1
		fi
		link_or_copy_file "$ROOT/$f" "$INSTALL_DIR/$f" "$MODE"
	done
	chmod +x "$INSTALL_DIR/fcitx-status.sh" "$INSTALL_DIR/fcitx-watch.sh" 2>/dev/null || true
	echo "配置 → $INSTALL_DIR（mode=$MODE）"
}

chmod +x "$ROOT/fcitx-status.sh" "$ROOT/fcitx-watch.sh" "$ROOT/install.sh" 2>/dev/null || true

if [ "$DO_PLUGINS_ONLY" -eq 1 ]; then
	install_plugins
	exit 0
fi

if [ "$DO_TMUX" -eq 1 ]; then
	sync_config
	install_plugins
	echo "tmux 安装完成。新开终端或: tmux source-file $INSTALL_DIR/tmux.conf"
	echo "无 fcitx5 的机器会自动跳过输入法状态栏。"
fi
