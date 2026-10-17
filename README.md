# tmux

个人 tmux 配置：Alt 键位、catppuccin 主题、TPM 插件；可选 fcitx5 输入法状态。

仓库与运行配置分开：默认把配置发布到 `~/.config/tmux`，插件装到 `~/.config/tmux/plugins`（不进 git）。仅支持个人安装。

## 依赖

- `tmux`、`git`
- 可选：`fcitx5`（有 `fcitx5-remote` 才启用状态栏模块）
- 状态栏图标需要 Nerd Font（如 Maple Mono NL NF）

Arch：

```bash
sudo pacman -S tmux git
```

Alpine：

```bash
doas apk add tmux git
```

## 安装

```bash
git clone git@github.com:liuxinyang1984/tmux.git ~/git/tmux
~/git/tmux/install.sh
```

默认会：

1. 拷贝 `tmux.conf` / `fcitx.*` → `~/.config/tmux`（不覆盖 `plugins/`）
2. clone/更新 TPM，并按 conf 里的 `@plugin` 安装插件

```bash
./install.sh --dev            # 配置文件 symlink 到本仓库（改完 tmux source-file 即生效）
./install.sh --plugins-only   # 只更新插件
./install.sh kiosk            # 无 WM 全屏 st+tmux → ~/.local/bin/kiosk-session.sh
./install.sh --dev kiosk      # kiosk 脚本 symlink 到本仓库
./install.sh --help
```

tmux ≥ 3.x 会自动读 `~/.config/tmux/tmux.conf`，不必再写 `~/.tmux.conf`。

已由 [dotfiles](https://github.com/liuxinyang1984/dotfiles) 登记为 `vendor/tmux`：`./install.sh tmux`。

## Kiosk（无 WM + 全屏 st + tmux）

给老本 / 单终端会话用：不启 dwm，用 `xdotool` 把 `st` 铺满一块物理屏，里面跑 tmux。

依赖：`st`、`tmux`、`xdotool`，以及 `xrandr` 或 `xdpyinfo`；建议有 `dbus-launch`（Alpine：`dbus-x11`），可选 `fcitx5`。

```bash
./install.sh kiosk
```

在 `~/.xinitrc` 里（可与 dwm 分支用参数切换）：

```sh
exec "$HOME/.local/bin/kiosk-session.sh"
```

可选环境变量：`KIOSK_OUTPUT`、`KIOSK_GEOM`、`KIOSK_SESSION`、`KIOSK_LOG`（见 `kiosk-session.sh` 头注释）。

## 键位摘要

| 键 | 作用 |
|----|------|
| Alt+Space | prefix |
| Alt+Enter / Alt+Shift+Enter | 左右 / 上下分屏 |
| Alt+h/j/k/l | 切面板 |
| Alt+H/J/K/L（及 M-S-h 等） | 调面板大小 |
| Alt+Shift+n | 新窗口 |
| Alt+1..9 | 切到对应窗口（`base-index` 从 1 起） |
| Alt+, / . | 上/下窗口 |
| Alt+v | 进入 copy-mode（vi：`v` 选择，`C-v` 矩形，`y` 复制） |
| Alt+q | 关闭当前 pane |
| Alt+Shift+q | 关闭当前窗口 |
| Alt+Shift+e | detach（kiosk 下退出 X，tmux 会话保留） |

SSH 下 Alt 失效时：先按 prefix，再用 h/j/k/l、`,` / `.`、`N`、`q` / `Q` / `E`。

## 插件

- [tpm](https://github.com/tmux-plugins/tpm)
- [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible)
- [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) / [tmux-battery](https://github.com/tmux-plugins/tmux-battery)（conf 里可按需打开 status）
- [catppuccin/tmux](https://github.com/catppuccin/tmux) v2.3.1 · flavor macchiato
