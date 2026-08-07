#!/bin/sh
# YOLO 推理服务启动脚本（随 artifact 分发，kiosk 自启时一并拉起）
#
# 首次运行会自动创建 venv 并安装依赖（需联网，约 1-2 分钟）；
# 前置：系统需有 python3-venv
#   Debian/Mobian: sudo apt install -y python3.11-venv python3-full
#
# 用法:
#   ./inference_server/start_server.sh                    # 默认端口 19530
#   ./inference_server/start_server.sh --classes spaghetti
#   YOLO_PORT=19531 ./inference_server/start_server.sh    # 改端口

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SERVER="$SCRIPT_DIR/server.py"
MODEL="$SCRIPT_DIR/best.onnx"
PORT="${YOLO_PORT:-19530}"
VENV="$SCRIPT_DIR/.venv"
DEPS_OK="$VENV/.deps_ok"

if [ ! -f "$MODEL" ]; then
  echo "[yolo] 模型不存在: $MODEL（把 best.onnx 放到 inference_server/ 目录）" >&2
  exit 1
fi

# 首次运行：建 venv + 装依赖（幂等，成功后写 .deps_ok 标记，后续启动跳过）
if [ ! -x "$VENV/bin/python" ] || [ ! -f "$DEPS_OK" ]; then
  echo "[yolo] 初始化 venv + 安装依赖（首次运行，需联网）..."
  python3 -m venv "$VENV" || {
    echo "[yolo] venv 创建失败，先安装 python3-venv: sudo apt install -y python3.11-venv" >&2
    exit 1
  }
  # 优先国内源，失败回退默认源
  if ! "$VENV/bin/pip" install -q \
      --index-url https://pypi.tuna.tsinghua.edu.cn/simple \
      onnxruntime pillow numpy; then
    "$VENV/bin/pip" install -q onnxruntime pillow numpy || {
      echo "[yolo] 依赖安装失败" >&2
      exit 1
    }
  fi
  touch "$DEPS_OK"
  echo "[yolo] 依赖安装完成"
fi

echo "[yolo] 启动推理服务: port=$PORT model=$MODEL"
exec "$VENV/bin/python" "$SERVER" --port "$PORT" --model "$MODEL" "$@"
