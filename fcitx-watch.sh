#!/bin/sh
# 单实例循环刷新 fcitx5 状态到 tmux @fcitx_im
ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
lock=/tmp/tmux-fcitx-watch.lock
exec 9>"$lock"
flock -n 9 || exit 0

while tmux list-sessions >/dev/null 2>&1; do
  "$ROOT/fcitx-status.sh"
  sleep 1
done
