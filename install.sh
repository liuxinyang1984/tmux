#!/bin/sh
# 个人安装（默认）：配置同步到 ~/.config/tmux，插件到 ~/.config/tmux/plugins
#   ./install.sh              # 拷贝配置，装/更新 TPM 插件
#   ./install.sh --dev        # 配置文件改为指向本仓库的 symlink（plugins 仍留在 ~/.config/tmux）
#   ./install.sh --plugins-only
#   ./install.sh kiosk        # 安装无 WM 全屏 st+tmux 会话脚本 → ~/.local/bin
#   ./install.sh --dev kiosk  # kiosk 脚本 symlink 到本仓库
# 仅个人安装，无 --system。
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
INSTALL_DIR="${TMUX_INSTALL_DIR:-$CONFIG_HOME/tmux}"
PLUG_DIR="$INSTALL_DIR/plugins"
TPM_DIR="$PLUG_DIR/tpm"
BIN_DIR="${TMUX_KIOSK_BIN:-$HOME/.local/bin}"

MODE=install
DO_TMUX=0
DO_KIOSK=0
DO_PLUGINS_ONLY=0

usage() {
    cat <<'EOF'
用法: ./install.sh [--dev] [tmux|kiosk]...
      ./install.sh --plugins-only

  （默认，无组件名）  等同 ./install.sh tmux
  tmux                 配置 → ~/.config/tmux，并安装/更新 TPM 插件
  kiosk                安装 kiosk-session.sh → ~/.local/bin
  --dev                上述目标改为 symlink 到本仓库
  --plugins-only       只装/更新插件（不写配置）
  -h, --help           显示本说明

仅个人安装，无 --system。tmux 会自动读 ~/.config/tmux/tmux.conf。

kiosk 依赖（需自行安装）：st、tmux、xdotool、xrandr 或 xdpyinfo；
可选 dbus-launch（dbus-x11）、fcitx5。
在 ~/.xinitrc 中：exec "$HOME/.local/bin/kiosk-session.sh"
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dev) MODE=dev ;;
        --plugins-only) DO_PLUGINS_ONLY=1 ;;
        tmux) DO_TMUX=1 ;;
        kiosk) DO_KIOSK=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "未知参数: $arg（见 ./install.sh --help）" >&2
            exit 1
            ;;
    esac
done

# 无组件名且非 --plugins-only → 默认装 tmux 配置
if [ "$DO_PLUGINS_ONLY" -eq 0 ] && [ "$DO_TMUX" -eq 0 ] && [ "$DO_KIOSK" -eq 0 ]; then
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
    if [ "$mode" = dev ]; then
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

install_kiosk() {
    if [ ! -f "$ROOT/kiosk-session.sh" ]; then
        echo "缺少 $ROOT/kiosk-session.sh" >&2
        exit 1
    fi
    mkdir -p "$BIN_DIR"
    link_or_copy_file "$ROOT/kiosk-session.sh" "$BIN_DIR/kiosk-session.sh" "$MODE"
    chmod +x "$BIN_DIR/kiosk-session.sh" 2>/dev/null || true

    missing=""
    for c in st tmux xdotool; do
        command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
    done
    if ! command -v xrandr >/dev/null 2>&1 && ! command -v xdpyinfo >/dev/null 2>&1; then
        missing="$missing xrandr|xdpyinfo"
    fi
    if [ -n "$missing" ]; then
        echo "警告: 未在 PATH 找到:$missing（kiosk 可能无法铺满或启动）" >&2
    fi
    command -v dbus-launch >/dev/null 2>&1 || \
        echo "提示: 无 dbus-launch 时 fcitx 可能异常（Arch: dbus；Alpine: dbus-x11）" >&2

    echo "kiosk → $BIN_DIR/kiosk-session.sh（mode=$MODE）"
    echo "在 ~/.xinitrc 中加入: exec \"$BIN_DIR/kiosk-session.sh\""
}

chmod +x "$ROOT/fcitx-status.sh" "$ROOT/fcitx-watch.sh" "$ROOT/kiosk-session.sh" "$ROOT/install.sh" 2>/dev/null || true

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

if [ "$DO_KIOSK" -eq 1 ]; then
    install_kiosk
fi
