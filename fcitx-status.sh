#!/bin/sh
# 更新 @fcitx_im；拼 / 五 / En（获取不到也视为 En）
im=$(fcitx5-remote -n 2>/dev/null) || true
case "$im" in
  *pinyin*|*Pinyin*) text=' 拼' ;;
  *wbpy*|*wubi*|*Wubi*|*WBPY*) text=' 五' ;;
  *) text=' En' ;;
esac
tmux set-option -gq @fcitx_im "$text"
