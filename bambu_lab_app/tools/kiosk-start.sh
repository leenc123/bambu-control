#!/bin/sh
# kiosk 会话启动脚本：推理服务 + 触摸键盘 + 应用
#
# 被 bambu-kiosk.service 的 ExecStart 调用（ExecStart 保持短行，
# 避免长命令在粘贴/编辑时折行导致 "bad unit file setting"）。
#
# 随 artifact 分发到 ~/bambu-lab-app-linux-arm64/，服务里路径要对应。

APP_DIR="$HOME/bambu-lab-app-linux-arm64"

# 1) YOLO 推理服务（AI 检测炒面/拉丝，端口 19530；首次运行自动建 venv 装依赖）
"$APP_DIR/inference_server/start_server.sh" &

# 2) 屏幕键盘（备用；应用内已有 flutter_onscreen_keyboard）
squeekboard &

# 3) 应用（前台，崩溃由 systemd Restart=always 兜底重启整个会话）
exec "$APP_DIR/run.sh"
