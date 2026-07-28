# Bambu Lab App — Linux 部署指南（flutter-pi）

## 概述

本指南覆盖将 Bambu Lab App 通过 **flutter-pi** 编译部署到 Linux x86_64 服务器（VMware 虚拟机 / 物理机）的完整流程。

> **注意**：flutter-pi 通过 DRM/KMS 直刷帧缓冲，不依赖 X11/Wayland。需要 GPU 驱动（`/dev/dri/card0` 存在），VMware 虚拟机需勾选 **「加速 3D 图形」**。

---

## 1. 版本兼容性总览

| 组件 | 版本约束 | 原因 |
| --- | --- | --- |
| `sqlite3` | `^2.9.0` | 3.x 的 native assets 与 flutter-pi 不兼容 |
| `drift` | `>=2.22.0 <2.32.0` | 2.32.0+ 强制要求 sqlite3 3.x |
| `drift_dev` | `>=2.22.0 <2.32.0` | 与 drift 版本一致 |
| `sqlite3_flutter_libs` | `^0.5.28` | Android/iOS/Windows 提供 .so；Linux 上由系统 libsqlite3 提供 |

---

## 2. 目标服务器环境准备

### 2.1 系统依赖

```bash
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

### 2.2 安装 flutter-pi

```bash
# 源码编译（推荐，确保架构匹配）
git clone https://github.com/ardera/flutter-pi.git /opt/flutter-pi
cd /opt/flutter-pi
mkdir build && cd build
cmake .. && make -j$(nproc)
sudo cp flutter-pi /usr/local/bin/
```

### 2.3 用户权限

```bash
sudo usermod -aG video,input,render $USER
# 重新登录生效
```

### 2.4 确认 GPU 可用

```bash
ls /dev/dri/          # 应有 card0, renderD128
sudo apt-get install mesa-utils
glxinfo | grep "OpenGL renderer"   # 不应显示 llvmpipe（软件渲染）
```

> VMware 虚拟机需在设置 → 显示器 → 勾选 **「加速 3D 图形」**，否则软件渲染可能导致 Lottie 等组件失败。

---

## 3. 开发机构建

### 3.1 前置条件

- Flutter SDK ≥ 3.x
- **Android SDK command-line tools**（`flutter build bundle --debug` 需要它处理 native assets）

安装 Android SDK（最小化）：

```bash
sudo apt-get install -y openjdk-17-jdk
cd /opt
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
mkdir -p android-sdk/cmdline-tools
unzip commandlinetools-linux-11076708_latest.zip -d android-sdk/cmdline-tools
mv android-sdk/cmdline-tools/cmdline-tools android-sdk/cmdline-tools/latest
export ANDROID_HOME=/opt/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0"
echo 'export ANDROID_HOME=/opt/android-sdk' >> ~/.bashrc
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' >> ~/.bashrc
```

### 3.2 依赖配置

`pubspec.yaml` 关键配置：

```yaml
dependencies:
  drift: ^2.22.1
  sqlite3_flutter_libs: ^0.5.28

dependency_overrides:
  sqlite3: ^2.9.0
  drift: ">=2.22.0 <2.32.0"
  drift_dev: ">=2.22.0 <2.32.0"
```

### 3.3 构建步骤

```bash
cd bambu_lab_app

# 清理 + 获取依赖
flutter clean
flutter pub get

# 构建 bundle（推荐方式，需 Android SDK）
flutter build bundle --debug

# 备用：flutter build linux --debug（产物在 build/linux/x64/debug/bundle/data/）
```

产物在 `build/flutter_assets/`（或 `build/linux/x64/debug/bundle/data/flutter_assets/`）。

### 3.4 构建产物位置

```
build/linux/x64/debug/bundle/
├── bambu_lab_app                    # GTK 可执行文件（flutter-pi 不用）
└── data/
    ├── flutter_assets/              # → 传到目标服务器
    │   ├── AssetManifest.bin
    │   ├── kernel_blob.bin          # Dart 代码快照
    │   ├── assets/                  # pubspec.yaml 声明的资源
    │   ├── fonts/
    │   ├── packages/
    │   └── ...
    └── icudtl.dat                   # → 传到目标服务器
```

---

## 4. 部署到目标服务器

### 4.1 目标服务器目录结构

> **关键**：flutter-pi 的 bundle 根目录即资源根目录。`flutter_assets/` 内的文件需**平铺到 bundle 根目录**，不能嵌套。

flutter-pi 要求的布局：

```
/opt/bambu-control/
├── kernel_blob.bin           # Dart 代码快照
├── icudtl.dat                # ICU 数据
├── libflutter_engine.so      # Flutter 引擎（debug 版）
├── AssetManifest.bin         # ← 从 flutter_assets/ 移出
├── FontManifest.json         # ← 从 flutter_assets/ 移出
├── version.json              # ← 从 flutter_assets/ 移出
├── NOTICES.Z                 # ← 从 flutter_assets/ 移出
├── assets/                   # ← 从 flutter_assets/ 移出
│   └── bambu_control.json    # 注意：文件名不能有空格
├── fonts/                    # ← 从 flutter_assets/ 移出
├── packages/                 # ← 从 flutter_assets/ 移出
└── shaders/                  # ← 从 flutter_assets/ 移出
```

### 4.2 传输文件并平铺

```bash
# 从开发机传到目标服务器

# 方式 A：用 flutter build linux --debug
scp build/linux/x64/debug/bundle/data/flutter_assets/kernel_blob.bin \
  root@debian-cli:/opt/bambu-control/
scp build/linux/x64/debug/bundle/data/icudtl.dat \
  root@debian-cli:/opt/bambu-control/
scp -r build/linux/x64/debug/bundle/data/flutter_assets/ \
  root@debian-cli:/opt/bambu-control/

# 方式 B（推荐）：用 flutter build bundle --debug（需 Android SDK）
flutter build bundle --debug
scp build/flutter_assets/kernel_blob.bin root@debian-cli:/opt/bambu-control/
scp -r build/flutter_assets/ root@debian-cli:/opt/bambu-control/
```

然后在目标服务器上，把 `flutter_assets/` 内的文件**平铺到 bundle 根目录**：

```bash
# 在目标服务器（debian-cli）上
cd /opt/bambu-control

# 清掉旧目录（如果之前嵌套的还在）
rm -rf assets fonts packages shaders

# 将 flutter_assets 内容平铺出来
cp -r flutter_assets/* .

# 验证结构
ls -la
# 应看到 kernel_blob.bin、icudtl.dat、AssetManifest.bin、assets/、fonts/ 等都在同一层
```

### 4.3 获取 libflutter_engine.so

> Flutter 3.x 不再独立分发 `libflutter_engine.so`，引擎内嵌在 `libflutter_linux_gtk.so` 中。flutter-pi 需要独立的引擎文件。

在目标服务器上：

```bash
# 如果之前编译 flutter-pi 时产生了引擎（通常在 /usr/local/lib/）
cp /usr/local/lib/libflutter_engine.so /opt/bambu-control/

# 或者从 flutter-embedded-linux 获取
# https://github.com/sony/flutter-embedded-linux/releases
```

### 4.4 运行

```bash
cd /opt/bambu-control
pkill flutter-pi            # 停掉旧进程
flutter-pi /opt/bambu-control
```

---

## 5. SQLite 数据库说明

### 5.1 为什么需要特殊处理

flutter-pi **不支持标准 Flutter 插件系统**，`sqlite3_flutter_libs` 插件无法注册。因此：

- 目标服务器必须装系统级 `libsqlite3-0`
- `database.dart` 中 Linux 平台手动 `open.overrideFor` 指向系统库

### 5.2 代码改动

`lib/db/database.dart`：

```dart
import 'dart:ffi';
import 'package:sqlite3/open.dart';

static QueryExecutor _openConnection() {
  // flutter-pi 无插件系统，Linux 下手动指定系统 sqlite3 库
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

  return LazyDatabase(() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, 'bambu_lab_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

### 5.3 数据库文件位置

`$HOME/.local/share/bambu_lab_app/bambu_lab_app.sqlite`

---

## 6. 已知问题与处理

### 6.1 Asset 文件名不能有空格

Flutter 打包时会将空格编码为 `%20`，导致运行时找不到文件。

- ❌ `assets/bambu control.json`
- ✅ `assets/bambu_control.json`

### 6.2 Lottie 在软件渲染下可能失败

flutter-pi 在 llvmpipe（软件渲染）下 Lottie 动画解码可能失败。已添加降级处理：

```dart
Lottie.asset(
  'assets/bambu_control.json',
  errorBuilder: (_, __, ___) => Image.asset('bamboo_app_logo.png'),
  ...
)
```

### 6.3 中文乱码

Flutter 默认使用 Roboto 字体，不含中文字形。系统安装的字体对 Flutter 无效，必须打包进 app。

**解决**：

1. 下载中文字体（如 Noto Sans SC）放入 `assets/fonts/`：

```bash
mkdir -p assets/fonts
wget -O assets/fonts/NotoSansSC-Regular.ttf \
  "https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
```

2. `pubspec.yaml` 注册字体：

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: NotoSansSC
      fonts:
        - asset: assets/fonts/NotoSansSC-Regular.ttf
```

3. `app.dart` 主题设默认字体：

```dart
theme: ThemeData(
  fontFamily: 'NotoSansSC',
  // ...
),
darkTheme: ThemeData(
  fontFamily: 'NotoSansSC',
  // ...
),
```

### 6.4 退出后显示器黑屏

flutter-pi 进程退出后 DRM 未释放。切换 tty：

```
Ctrl + Alt + F2
```

---

## 7. 故障排查

### 7.1 sqlite3 相关错误

```bash
# 确认系统包已安装
dpkg -l | grep libsqlite3-0

# 确认 .so 存在
find /usr/lib -name "libsqlite3*"
```

### 7.2 flutter-pi 报 "failed to open DRM device"

```bash
groups $USER              # 确认在 video 组
ls -la /dev/dri/          # 确认 DRM 设备存在
```

### 7.3 asset 找不到

```bash
# 检查文件名（不能有空格或特殊字符）
ls -la /opt/bambu-control/flutter_assets/assets/

# 检查 manifest 是否更新
strings /opt/bambu-control/flutter_assets/AssetManifest.bin | grep bambu

# 确认 kernel_blob.bin 也是最新的
ls -la /opt/bambu-control/kernel_blob.bin
```

### 7.4 闪退无日志

```bash
flutter-pi -v /opt/bambu-control 2>&1 | tee app.log
```

---

## 8. systemd 自启动（可选）

```bash
sudo tee /etc/systemd/system/bambu-lab-app.service << 'EOF'
[Unit]
Description=Bambu Lab 3D Printer Control App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bambu-control
ExecStart=/usr/local/bin/flutter-pi /opt/bambu-control
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable bambu-lab-app
sudo systemctl start bambu-lab-app
```

---

## 9. 参考链接

- [flutter-pi GitHub](https://github.com/ardera/flutter-pi)
- [drift 文档](https://drift.simonbinder.eu/docs/)
- [sqlite3 pub.dev](https://pub.dev/packages/sqlite3)
