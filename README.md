# Bambu Control — 拓竹 3D 打印机控制

> 跨平台拓竹打印机控制方案：Flutter 移动 App + Python API + Home Assistant 集成

---

## 项目结构

```
├── bambu_lab_app/           # Flutter 跨平台移动 App（主项目）
│   ├── lib/
│   │   ├── services/
│   │   │   ├── mqtt_client.dart       # MQTT 通信客户端（连接/命令/状态监听）
│   │   │   ├── printer_service.dart   # 打印机服务（高级 API 封装）
│   │   │   └── printer_ftp_service.dart # FTP 文件管理
│   │   ├── providers/
│   │   │   ├── printer_provider.dart   # 连接和状态管理
│   │   │   └── printer_config_provider.dart # 配置 CRUD
│   │   ├── models/
│   │   │   ├── printer_state.dart      # 状态聚合模型
│   │   │   ├── printer_config.dart     # 连接配置
│   │   │   ├── gcode_state.dart        # G-code 状态枚举
│   │   │   └── print_status.dart       # 打印状态枚举
│   │   ├── screens/
│   │   │   ├── connect/                # 连接配置页
│   │   │   ├── dashboard/              # 主仪表盘
│   │   │   └── settings/               # 设置页
│   │   ├── utils/
│   │   │   ├── debug_log.dart          # 全局调试日志
│   │   │   └── debug_log_viewer.dart   # 日志查看弹窗
│   │   └── theme/                      # Neumorphism 主题
│   └── tools/
│       ├── bambu_printer_simulator.py  # 打印机模拟器（MQTT + FTP）
│       └── mobian_autostart.sh         # Mobian 开机自启脚本
│
├── bambulabs_api/           # Python 打印机 API 库（参考实现）
│   └── bambulabs_api/
│       ├── mqtt_client.py   # Python MQTT 客户端
│       ├── client.py        # 高级 API 封装
│       ├── ftp_client.py    # FTP 客户端
│       └── camera_client.py # 摄像头客户端
│
├── ha-bambulab/             # Home Assistant 集成（参考实现）
│   └── custom_components/bambu_lab/
│       └── pybambu/
│           ├── bambu_client.py  # HA 版 MQTT+FTP 客户端
│           └── commands.py      # 命令模板
│
├── Best-Flutter-UI-Templates/  # Flutter UI 组件库（依赖）
│
└── API_DOC.md               # Python API 功能文档
```

---

## Flutter App（bambu_lab_app）

### 技术栈

| 组件 | 选型 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| MQTT | mqtt_client ^10.11 |
| FTP | ftpconnect ^2.0 |
| 状态管理 | Provider |
| 数据库 | drift (SQLite) |
| 主题 | Neumorphism（软拟物） |
| 目标平台 | Android / iOS / Windows / Linux ARM64（Mobian） |

### 功能

- ✅ MQTT 连接（局域网 TLS 8883 / 直连 1883）
- ✅ 实时状态监控（温度、进度、速度、灯光）
- ✅ 打印控制（开始/暂停/恢复/停止）
- ✅ 温度控制（热床/喷嘴）
- ✅ 风扇控制（部件/辅助/箱体）
- ✅ AMS 耗材管理
- ✅ 灯光控制
- ✅ 速度等级切换
- ✅ 校准、归位、G-code 发送
- ✅ FTP 文件浏览/下载/缩略图预览
- ✅ 打印机模拟器（MQTT + FTP 测试）

### 快速开始

```bash
cd bambu_lab_app
flutter pub get
flutter run
```

### 配置打印机

1. 获取打印机 IP（路由器后台或打印机屏幕）
2. 获取序列号（打印机底部标签）
3. 在打印机屏幕上开启 **LAN 模式**，获取**访问码**
4. App 中添加打印机，填入 IP / 序列号 / 访问码

| 环境 | MQTT 端口 | TLS | FTP 端口 | FTP 安全 |
|------|-----------|-----|----------|---------|
| 真实打印机 | 8883 | 开启 | 990 | 隐式 FTPS |
| 模拟器 | 1883 | 关闭 | 9991/9990 | TLS/明文 |

### 打印机模拟器

```bash
# 安装依赖
pip install paho-mqtt pyftpdlib

# 启动模拟器
python bambu_lab_app/tools/bambu_printer_simulator.py
```

启动后模拟器会自动：
- 连接本地 MQTT broker (127.0.0.1:1883)
- 启动 FTP 服务器（TLS 端口 9991 / 明文 9990）
- 模拟打印机状态推送和命令响应

---

## Python API（bambulabs_api）

独立的 Python 库，支持 MQTT / FTP / 摄像头控制。详见 [API_DOC.md](./API_DOC.md)。

```python
from bambulabs_api import Printer

printer = Printer("192.168.1.100", "12345678", "SERIAL001")
printer.connect()

print(printer.get_state())
print(printer.get_percentage())
```

---

## Home Assistant 集成（ha-bambulab）

基于 [greghesp/ha-bambulab](https://github.com/greghesp/ha-bambulab) 的 Home Assistant 自定义组件，通过 MQTT 将打印机接入 HA 智能家居平台。

---

## MQTT 协议参考

拓竹打印机使用私有 MQTT 协议（基于 MQTT 3.1.1），局域网直连：

| 主题 | 方向 | 说明 |
|------|------|------|
| `device/{SN}/report` | 打印机 → App | 状态推送（print.push_status） |
| `device/{SN}/request` | App → 打印机 | 控制命令 |

**关键点：**
- 一条 MQTT 消息只包含一个顶层命令（禁止合并 `pushall` + `get_version`）
- 所有命令必须包含 `sequence_id`
- 编码兼容性：偶发非 UTF-8 字节需 Latin-1 兜底
- Client ID 每次连接唯一，避免 session 残留

---

## Mobian 设备部署（Linux ARM64）

目标设备：Mobian（Debian 11，glibc 2.31）+ Phosh 图形界面（如红米 2 / WT88047）。
App 以标准 Flutter Linux GTK 桌面形式运行（非 flutter-pi），开机自启即全屏 kiosk。

### 构建（CI 自动打包）

- 推送代码后 GitHub Actions `build-linux-arm64.yml` 自动构建，产物
  `bambu-lab-app-linux-arm64.tar.gz`（Actions 页面 → Artifacts 下载）。
- **构建环境是 debian:bullseye 容器（glibc 2.31）**，与 Mobian 一致。
  不要改成更新的 runner 系统镜像——glibc 符号版本会超过手机，
  启动时报 `version GLIBC_2.3x not found`。

### 安装

```bash
cd ~
tar xzf bambu-lab-app-linux-arm64.tar.gz   # 必须用 tar 解压（GUI 解压会剥执行位）

# 依赖（Mobian 一般已装，缺了才装）
sudo apt install -y libgtk-3-0 libsqlite3-0

# 修复执行位（tar 解压一般无需，GUI 解压必需）
chmod +x ~/bambu-lab-app-linux-arm64/bambu_lab_app \
         ~/bambu-lab-app-linux-arm64/run.sh \
         ~/bambu-lab-app-linux-arm64/mobian_autostart.sh

# 手动启动（必须在 Phosh 图形界面终端里；SSH 无显示会话会段错误）
cd ~/bambu-lab-app-linux-arm64 && ./run.sh
```

窗口默认全屏无边框（kiosk 模式）。

### 开机自启动

```bash
mkdir -p ~/.config/autostart
printf '%s\n' \
  "[Desktop Entry]" \
  "Type=Application" \
  "Name=Bambu Lab" \
  "Exec=sh /home/mobian/bambu-lab-app-linux-arm64/mobian_autostart.sh" \
  "Terminal=false" \
  "X-GNOME-Autostart-enabled=true" \
  > ~/.config/autostart/bambu-lab-app.desktop
```

- 自启脚本行为：等 Wayland 就绪 → 应用 kiosk 设置（禁用锁屏 + 屏幕常亮，幂等）
  → 启动应用 → 崩溃自动重启
  （连续 5 次 5 秒内崩溃则放弃），日志：`~/.cache/bambu_lab_app/autostart.log`
- 卸载自启：`rm ~/.config/autostart/bambu-lab-app.desktop`

### 常见问题

| 现象 | 原因 | 对策 |
|------|------|------|
| `version GLIBC_2.3x not found` | 包不是 bullseye 容器构建 | 用最新 CI 产物 |
| 启动即段错误 | SSH 运行（无显示会话） | 在 Phosh 终端里跑 |
| `./run.sh: 权限不够` | 解压剥了执行位 | `chmod +x` 或改用 tar 解压 |
| DartWorker 线程 sqlite3 段错误 | 旧包（sqlite3 双副本 bug） | 重新下载最新包 |
| 自启没反应 | 脚本无执行位 / Exec 路径错 | `chmod +x`；检查 .desktop |

---

## 许可证

本项目仅供学习参考，使用拓竹打印机相关接口请遵守 [Bambu Lab 用户协议](https://bambulab.com/)。

---

## 相关资源

- [OpenBambuAPI](https://github.com/Doridian/OpenBambuAPI) — 社区维护的拓竹 API 文档
- [Bambu Lab Wiki](https://wiki.bambulab.com/) — 官方 Wiki
- [Bambu Studio](https://github.com/bambulab/BambuStudio) — 官方切片软件
