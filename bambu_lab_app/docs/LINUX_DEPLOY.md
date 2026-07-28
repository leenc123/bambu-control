# Bambu Lab App — Linux 部署指南（flutter-pi）

## 概述

本指南覆盖将 Bambu Lab App 编译并部署到 ARM Linux 服务器（树莓派等），通过 **flutter-pi** 作为 Flutter 引擎运行时。

> **注意**：flutter-pi 是为嵌入式 Linux（树莓派等）设计的 Flutter 引擎 embedder，直接通过 DRM/KMS 渲染，不依赖 X11/Wayland。这意味着它**不支持标准 Flutter Linux 插件系统**，需要额外处理原生库依赖。

---

## 1. 目标服务器环境准备

### 1.1 系统依赖

```bash
# Debian / Ubuntu / Raspberry Pi OS
sudo apt-get update
sudo apt-get install -y \
  libsqlite3-0 \
  libdrm2 \
  libgbm1 \
  libegl1-mesa \
  libgles2-mesa \
  libinput10 \
  libxkbcommon0 \
  libudev1
```

| 包名 | 用途 |
| --- | --- |
| `libsqlite3-0` | SQLite 原生库（drift 数据库依赖） |
| `libdrm2` / `libgbm1` | 图形缓冲管理 |
| `libegl1-mesa` / `libgles2-mesa` | OpenGL ES 渲染 |
| `libinput10` | 输入设备处理 |
| `libxkbcommon0` | 键盘映射 |
| `libudev1` | 设备管理 |

### 1.2 安装 flutter-pi

```bash
# 从 GitHub releases 下载预编译二进制（推荐）
# 根据目标架构选择 armv7（32位）或 arm64（64位）
ARCH=$(dpkg --print-architecture)  # armhf 或 arm64

# arm64 示例：
wget https://github.com/ardera/flutter-pi/releases/latest/download/flutter-pi_linux-aarch64.tar.gz
tar xzf flutter-pi_linux-aarch64.tar.gz
sudo cp flutter-pi /usr/local/bin/

# 或者从源码编译
# git clone https://github.com/ardera/flutter-pi.git
# cd flutter-pi && mkdir build && cd build
# cmake .. && make -j$(nproc)
# sudo cp flutter-pi /usr/local/bin/
```

### 1.3 用户权限

flutter-pi 需要访问 DRM 和输入设备：

```bash
# 将运行用户加入必要组
sudo usermod -aG video,input,render $USER
# 重新登录生效
```

---

## 2. 开发机编译 Flutter 应用

### 2.1 前提条件

- Flutter SDK ≥ 3.x（开发机上）
- 目标架构的交叉编译工具链

### 2.2 添加 Linux 平台支持（如果还没有）

```bash
cd bambu_lab_app
flutter create --platforms=linux .
```

### 2.3 编译 ARM64 版本

```bash
cd bambu_lab_app

# ARM64（树莓派 3B+/4/5，64 位系统）
flutter build linux --target-platform linux-arm64

# ARMv7（树莓派 2/3，32 位系统）
flutter build linux --target-platform linux-arm
```

编译产物在 `build/linux/arm64/release/bundle/`（或 `arm/release/bundle/`）。

### 2.4 编译产物结构

```
build/linux/arm64/release/bundle/
├── bambu_lab_app          # 应用二进制
├── data/
│   ├── flutter_assets/    # Flutter 资源
│   └── icudtl.dat         # ICU 数据
└── lib/
    ├── libflutter_engine.so
    ├── libflutter_linux_gtk.so  # flutter-pi 下不需要
    └── ...
```

---

## 3. 部署到目标服务器

### 3.1 传输文件

```bash
# 从开发机传到目标服务器
rsync -avz build/linux/arm64/release/bundle/ \
  user@target-server:/home/user/bambu_lab_app/

# 或者用 scp
scp -r build/linux/arm64/release/bundle/* \
  user@target-server:/home/user/bambu_lab_app/
```

### 3.2 运行

```bash
# 在目标服务器上
cd /home/user/bambu_lab_app

# 直接运行（需要显示器连接）
flutter-pi --release bambu_lab_app

# 指定像素比（高 DPI 屏幕）
flutter-pi --release --pixel_ratio=2 bambu_lab_app
```

### 3.3 配置 systemd 自启动（可选）

```bash
sudo tee /etc/systemd/system/bambu-lab-app.service << 'EOF'
[Unit]
Description=Bambu Lab 3D Printer Control App
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/bambu_lab_app
ExecStart=/usr/local/bin/flutter-pi --release /home/pi/bambu_lab_app/bambu_lab_app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable bambu-lab-app
sudo systemctl start bambu-lab-app
```

---

## 4. SQLite 数据库说明

本应用使用 `drift` + `NativeDatabase` 存储打印机配置和调试日志。相关改动已在 `lib/db/database.dart` 中完成：

```dart
// Linux 下显式指定 sqlite3 库路径
if (Platform.isLinux) {
  try {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  } catch (_) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so'),
    );
  }
}
```

数据库文件位置：`$HOME/.local/share/bambu_lab_app/bambu_lab_app.sqlite`

---

## 5. 故障排查

### 5.1 sqlite3.so 未找到

```bash
# 确认系统包已安装
dpkg -l | grep libsqlite3-0

# 确认 .so 存在
find /usr/lib -name "libsqlite3*"

# 如果装在非标准路径，添加到 LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### 5.2 flutter-pi 报 "failed to open DRM device"

```bash
# 确认用户在 video 组
groups $USER

# 确认 DRM 设备存在
ls -la /dev/dri/

# 如果没有，检查是否在用 HDMI 连接显示器
```

### 5.3 触摸/鼠标输入不响应

```bash
# 检查输入设备
ls -la /dev/input/

# 确认用户在 input 组
groups $USER
```

### 5.4 应用闪退无日志

```bash
# 加上日志参数运行
flutter-pi -v --release bambu_lab_app 2>&1 | tee app.log

# 或使用 strace 追踪
strace -f flutter-pi --release bambu_lab_app 2>&1 | grep -E "sqlite3|openat"
```

---

## 6. CI/CD 自动编译（GitHub Actions 示例）

```yaml
name: Build Linux ARM64

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: |
          sudo apt-get update
          sudo apt-get install -y libsqlite3-0
      - run: flutter pub get
        working-directory: bambu_lab_app
      - run: flutter build linux --target-platform linux-arm64
        working-directory: bambu_lab_app
      - uses: actions/upload-artifact@v4
        with:
          name: bambu-lab-app-arm64
          path: bambu_lab_app/build/linux/arm64/release/bundle/
```

---

## 7. 参考链接

- [flutter-pi GitHub](https://github.com/ardera/flutter-pi)
- [Flutter Linux 桌面支持](https://docs.flutter.dev/platform-integration/linux/building)
- [drift 数据库文档](https://drift.simonbinder.eu/docs/)
