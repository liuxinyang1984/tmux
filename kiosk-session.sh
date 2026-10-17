#!/bin/sh
# 无 WM 会话：fcitx5 + kitty(单屏铺满) + tmux
# POSIX sh（#!/bin/sh；勿用 /usr/bin/bash，Alpine 上不存在）
#
# 可选环境变量：
#   KIOSK_OUTPUT=eDP-1           指定 xrandr 输出
#   KIOSK_GEOM=1920x1080+0+0     直接指定 WxH+X+Y（Xephyr 可用）
#   KIOSK_SESSION=kiosk          tmux 会话名
#   KIOSK_LOG=$HOME/kiosk-session.log
#   KIOSK_TERM=kitty             终端：kitty（默认）或 st
#
# 由 ./install.sh kiosk 安装到 ~/.local/bin/kiosk-session.sh
# 在 ~/.xinitrc 末尾：exec "$HOME/.local/bin/kiosk-session.sh"

KIOSK_LOG="${KIOSK_LOG:-$HOME/kiosk-session.log}"
exec >>"$KIOSK_LOG" 2>&1
echo "===== $(date) DISPLAY=${DISPLAY:-} ====="

export PATH="/usr/local/bin:/usr/bin:/bin:${HOME}/.local/bin:${PATH:-}"

kiosk_sleep() {
	# $1 = 微秒；无 usleep 则至少睡 1 秒
	if command -v usleep >/dev/null 2>&1; then
		usleep "$1"
	else
		sleep 1
	fi
}

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
	export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
	mkdir -p "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
fi

export LC_CTYPE="${LC_CTYPE:-C.UTF-8}"
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
export SDL_IM_MODULE=fcitx

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	if command -v dbus-launch >/dev/null 2>&1; then
		eval "$(dbus-launch --sh-syntax)"
	else
		echo "WARN: no dbus-launch"
	fi
fi

fcitx5 -d --replace >/dev/null 2>&1 || fcitx5 -d >/dev/null 2>&1 || true
kiosk_sleep 300000

kiosk_geom() {
	_line=""
	_geom=""
	_dim=""

	if [ -n "${KIOSK_GEOM:-}" ]; then
		printf "%s\n" "$KIOSK_GEOM"
		return 0
	fi

	if [ -n "${KIOSK_OUTPUT:-}" ]; then
		_line="$(xrandr --current 2>/dev/null | awk -v o="$KIOSK_OUTPUT" '$1==o && / connected/{print; exit}')" || true
	fi
	if [ -z "$_line" ]; then
		_line="$(xrandr --current 2>/dev/null | awk '/ connected primary/{print; exit}')" || true
	fi
	if [ -z "$_line" ]; then
		_line="$(xrandr --current 2>/dev/null | awk '/ connected/{print; exit}')" || true
	fi
	echo "xrandr_line=${_line}" >&2

	_geom="$(printf "%s\n" "$_line" | grep -oE "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+" | head -n1)" || true
	if [ -n "$_geom" ]; then
		printf "%s\n" "$_geom"
		return 0
	fi

	_dim="$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2; exit}')" || true
	if [ -n "$_dim" ]; then
		printf "%s+0+0\n" "$_dim"
		return 0
	fi

	printf "%s\n" "1024x600+0+0"
}

SCREEN_GEOM="$(kiosk_geom)"
SCREEN_W="${SCREEN_GEOM%%x*}"
_rest="${SCREEN_GEOM#*x}"
SCREEN_H="${_rest%%+*}"
_rest="${_rest#*+}"
SCREEN_X="${_rest%%+*}"
SCREEN_Y="${_rest#*+}"
echo "geom=$SCREEN_GEOM (W=$SCREEN_W H=$SCREEN_H X=$SCREEN_X Y=$SCREEN_Y)"

SESSION_NAME="${KIOSK_SESSION:-kiosk}"
KIOSK_TERM="${KIOSK_TERM:-kitty}"

case "$KIOSK_TERM" in
kitty)
	if ! command -v kitty >/dev/null 2>&1; then
		echo "FATAL: kitty not found, fallback st" >&2
		KIOSK_TERM=st
	fi
	;;
esac

case "$KIOSK_TERM" in
kitty)
	# 程序参数跟在 kitty 后；配置见 ~/.config/kitty/kitty.conf
	kitty tmux new-session -A -s "$SESSION_NAME" &
	;;
*)
	st -e tmux new-session -A -s "$SESSION_NAME" &
	;;
esac
TERM_PID=$!
echo "term=$KIOSK_TERM pid=$TERM_PID"
kiosk_sleep 500000

if ! kill -0 "$TERM_PID" 2>/dev/null; then
	echo "FATAL: $KIOSK_TERM exited immediately"
	wait "$TERM_PID" || echo "term_status=$?"
	sleep 3
	exit 1
fi

if command -v xdotool >/dev/null 2>&1; then
	WID=""
	n=0
	while [ "$n" -lt 15 ]; do
		WID="$(xdotool search --pid "$TERM_PID" 2>/dev/null | tail -n1)" || true
		[ -n "$WID" ] && break
		# kitty 有时窗口在子进程上
		WID="$(xdotool search --class kitty 2>/dev/null | tail -n1)" || true
		[ -n "$WID" ] && break
		n=$((n + 1))
		kiosk_sleep 200000
	done
	echo "wid=$WID"
	if [ -n "$WID" ]; then
		xdotool windowmove "$WID" "$SCREEN_X" "$SCREEN_Y" || true
		xdotool windowsize "$WID" "$SCREEN_W" "$SCREEN_H" || true
		xdotool windowfocus "$WID" || true
		echo "maximized"
	else
		echo "WARN: no window for xdotool"
	fi
else
	echo "WARN: xdotool missing"
fi

wait "$TERM_PID"
echo "term_ended status=$?"
