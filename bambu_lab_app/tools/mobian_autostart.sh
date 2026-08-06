#!/bin/sh
# Bambu Lab App — Mobian 开机自启动脚本
#
# 配合 ~/.config/autostart/ 下的 .desktop 条目使用（Phosh 登录后自动执行）。
# 特性：
#   1. 等待 Wayland 会话就绪（Phosh 可能在 compositor 就绪前触发 autostart）
#   2. 应用崩溃后自动重启（连续 5 次 5 秒内崩溃则放弃，避免崩溃循环刷屏）
#   3. 日志写入 ~/.cache/bambu_lab_app/autostart.log
#
# 安装（在手机上执行，把 mobian_autostart.sh 放在 app 解压目录里）:
#   chmod +x mobian_autostart.sh
#   mkdir -p ~/.config/autostart
#   printf '%s\n' \
#     "[Desktop Entry]" \
#     "Type=Application" \
#     "Name=Bambu Lab" \
#     "Exec=<app目录>/mobian_autostart.sh" \
#     "Terminal=false" \
#     "X-GNOME-Autostart-enabled=true" \
#     > ~/.config/autostart/bambu-lab-app.desktop
#   然后重启或注销重新登录生效。
#
# 卸载：rm ~/.config/autostart/bambu-lab-app.desktop

# 脚本所在目录 = app 目录（解压到哪都能用，不写死 $HOME 路径）
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

LOG_DIR="$HOME/.cache/bambu_lab_app"
LOG="$LOG_DIR/autostart.log"
mkdir -p "$LOG_DIR"

log() {
    echo "$(date '+%F %T') $*" >> "$LOG"
}

# 1) 等 Wayland socket 就绪（最多 30 秒）
for _ in $(seq 1 30); do
    if [ -n "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        break
    fi
    sleep 1
done

log "=== autostart: WAYLAND_DISPLAY=$WAYLAND_DISPLAY ==="

# 2) 启动 + 崩溃自动重启
fail=0
while true; do
    log "launching $SCRIPT_DIR/run.sh"
    t0=$(date +%s)
    "$SCRIPT_DIR/run.sh" >> "$LOG" 2>&1
    code=$?
    t1=$(date +%s)
    runtime=$((t1 - t0))
    log "exited code=$code after ${runtime}s"

    if [ "$runtime" -lt 5 ]; then
        fail=$((fail + 1))
    else
        fail=0
    fi
    if [ "$fail" -ge 5 ]; then
        log "5 quick crashes in a row, giving up"
        exit 1
    fi
    sleep 3
done
