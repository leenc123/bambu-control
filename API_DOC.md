# BambuLabs API - Python API 功能文档

> Bambu Lab (拓竹) 3D 打印机的 Python API，支持通过 MQTT / FTP / 摄像头 三种协议控制打印机。
>
> 仓库: https://github.com/acse-ci223/bambulabs_api

---

## 目录

- [快速开始](#快速开始)
- [项目架构](#项目架构)
- [核心类](#核心类)
- [功能清单](#功能清单)
  - [连接管理](#1-连接管理)
  - [打印控制](#2-打印控制)
  - [温度控制](#3-温度控制)
  - [温度读取](#4-温度读取)
  - [风扇控制](#5-风扇控制)
  - [灯光控制](#6-灯光控制)
  - [G-code 发送](#7-g-code-发送)
  - [AMS 耗材系统](#8-ams-耗材系统)
  - [摄像头](#9-摄像头)
  - [FTP 文件管理](#10-ftp-文件管理)
  - [校准](#11-校准)
  - [固件管理](#12-固件管理)
  - [打印机信息读取](#13-打印机信息读取)
  - [状态监控](#14-状态监控)
  - [其他功能](#15-其他功能)
- [枚举类型参考](#枚举类型参考)
- [支持的打印机型号](#支持的打印机型号)
- [依赖](#依赖)

---

## 快速开始

```python
import bambulabs_api as bl

# 创建打印机实例
printer = bl.Printer(
    ip_address="192.168.1.200",
    access_code="12347890",
    serial="AC12309BH109"
)

# 连接打印机（启动 MQTT + 摄像头）
printer.connect()

# 获取状态
print(printer.get_state())          # 打印状态
print(printer.get_percentage())     # 打印进度
print(printer.get_bed_temperature())    # 热床温度
print(printer.get_nozzle_temperature()) # 喷嘴温度

# 断开连接
printer.disconnect()
```

---

## 项目架构

```
bambulabs_api/
├── client.py            # Printer 主客户端类（统一入口）
├── mqtt_client.py       # MQTT 通信客户端（命令收发、状态订阅）
├── camera_client.py     # 摄像头客户端（实时图像获取）
├── ftp_client.py        # FTP 客户端（文件上传/下载）
├── ams.py               # AMS 自动换料系统 数据模型
├── filament_info.py     # 耗材信息（类型枚举、料盘数据）
├── printer_info.py      # 打印机硬件信息（型号、喷嘴类型等）
├── states_info.py       # 状态枚举（打印状态、G-code 状态）
├── logger.py            # 日志模块
└── __init__.py          # 包入口，统一导出
```

**通信协议:**

| 协议 | 端口 | 用途 |
|------|------|------|
| MQTT (TLS) | 8883 | 命令发送、状态订阅、实时数据 |
| FTPS (隐式 TLS) | 990 | 文件上传/下载/管理 |
| 自定义 TCP (TLS) | 6000 | 摄像头实时画面 |

---

## 核心类

### `Printer` (client.py)

主入口类，整合 MQTT / 摄像头 / FTP 三个客户端，提供统一的高层 API。

```python
printer = bl.Printer(ip_address, access_code, serial)
```

### `PrinterMQTTClient` (mqtt_client.py)

底层 MQTT 通信类，处理与打印机的所有消息收发。

### `PrinterCamera` (camera_client.py)

摄像头连接类，通过 TLS socket 获取实时 JPEG 帧。

### `PrinterFTPClient` (ftp_client.py)

FTP 客户端类，用于文件上传/下载/目录浏览。

---

## 功能清单

### 1. 连接管理

| 方法 | 说明 |
|------|------|
| `connect()` | 连接打印机（同时启动 MQTT + 摄像头） |
| `disconnect()` | 断开打印机连接 |
| `mqtt_start()` | 单独启动 MQTT 客户端 |
| `mqtt_stop()` | 停止 MQTT 客户端 |
| `camera_start()` | 单独启动摄像头 |
| `camera_stop()` | 停止摄像头 |
| `mqtt_client_connected()` | 检查 MQTT 是否已连接 |
| `mqtt_client_ready()` | 检查 MQTT 是否就绪 |
| `camera_client_alive()` | 检查摄像头线程是否运行 |

### 2. 打印控制

| 方法 | 说明 |
|------|------|
| `start_print(filename, plate_number, use_ams, ams_mapping, skip_objects, flow_calibration)` | 开始打印 3MF 文件 |
| `stop_print()` | 停止打印 |
| `pause_print()` | 暂停打印 |
| `resume_print()` | 恢复打印 |
| `skip_objects(obj_list)` | 打印过程中跳过指定对象 |
| `get_skipped_objects()` | 获取已跳过的对象列表 |
| `set_print_speed(speed_lvl)` | 设置打印速度等级 (0-3: 最慢/慢/快/最快) |
| `get_print_speed()` | 获取当前打印速度 |
| `set_auto_step_recovery(enable)` | 设置自动断步恢复 |

### 3. 温度控制

| 方法 | 说明 |
|------|------|
| `set_bed_temperature(temperature)` | 设置热床温度 (°C) |
| `set_nozzle_temperature(temperature)` | 设置喷嘴温度 (°C) |

> 注意: P1 系列固件 >= 01.06 不支持 M140，改用 M190（设定并等待温度）。低于 40°C 时默认不执行，需设置 `override=True`。

### 4. 温度读取

| 方法 | 说明 | 返回类型 |
|------|------|----------|
| `get_bed_temperature()` | 获取热床当前温度 | `float` |
| `get_nozzle_temperature()` | 获取喷嘴当前温度 | `float` |
| `get_chamber_temperature()` | 获取箱体温度 | `float` |

> MQTT 底层还有 `get_bed_temperature_target()` 和 `get_nozzle_temperature_target()` 可获取目标温度。

### 5. 风扇控制

| 方法 | 说明 |
|------|------|
| `set_part_fan_speed(speed)` | 设置模型风扇速度 (int: 0-255 或 float: 0.0-1.0) |
| `set_aux_fan_speed(speed)` | 设置辅助风扇速度 |
| `set_chamber_fan_speed(speed)` | 设置箱体风扇速度 |

> MQTT 底层还有 `get_part_fan_speed()` / `get_aux_fan_speed()` / `get_chamber_fan_speed()` 读取风速。

### 6. 灯光控制

| 方法 | 说明 |
|------|------|
| `turn_light_on()` | 开灯 |
| `turn_light_off()` | 关灯 |
| `get_light_state()` | 获取灯光状态 ("on" / "off" / "unknown") |

### 7. G-code 发送

| 方法 | 说明 |
|------|------|
| `gcode(gcode, gcode_check)` | 发送 G-code 命令（单条 `str` 或列表 `list[str]`） |
| `home_printer()` | 自动回零 (G28) |
| `move_z_axis(height)` | 移动 Z 轴到指定高度 |

> G-code 验证默认开启 (`gcode_check=True`)，会校验格式是否合法。

### 8. AMS 耗材系统

| 方法 | 说明 |
|------|------|
| `ams_hub()` | 获取所有 AMS 单元信息（返回 `AMSHub`） |
| `vt_tray()` | 获取外部料盘信息（返回 `FilamentTray`） |
| `set_filament_printer(color, filament, ams_id, tray_id)` | 设置打印机耗材（颜色 + 材料类型） |
| `load_filament_spool()` | 加载耗材 |
| `unload_filament_spool()` | 卸载耗材 |
| `retry_filament_action()` | 重试当前耗材操作 |

**AMS 数据模型:**

- `AMSHub` - 管理多个 AMS 单元，类似字典，按索引访问
- `AMS` - 单个 AMS 单元，包含湿度、温度、料盘列表
- `FilamentTray` - 料盘数据（材料型号、颜色、温度范围、重量等）
- `Filament` - 耗材类型枚举（内置 50+ 种 Bambu 及通用耗材参数）
- `AMSFilamentSettings` - 耗材设置数据类

### 9. 摄像头

| 方法 | 说明 |
|------|------|
| `get_camera_frame()` | 获取当前帧（Base64 编码字符串） |
| `get_camera_image()` | 获取当前帧（Pillow `Image.Image` 对象） |

> 摄像头通过独立 TLS 连接，后台线程持续拉取 JPEG 帧。

### 10. FTP 文件管理

| 方法 | 说明 |
|------|------|
| `upload_file(file, filename)` | 上传文件到打印机 |
| `delete_file(file_path)` | 删除打印机上的文件 |

**FTP 底层方法 (PrinterFTPClient):**

| 方法 | 说明 |
|------|------|
| `list_directory(path)` | 列出指定目录内容 |
| `list_images_dir()` | 列出 image 目录 |
| `list_cache_dir()` | 列出 cache 目录 |
| `list_timelapse_dir()` | 列出 timelapse 目录 |
| `list_logger_dir()` | 列出 logger 目录 |
| `download_file(file_path)` | 下载文件（返回 BytesIO） |
| `last_image_print()` | 获取最近一次打印的预览图（Pillow Image） |

### 11. 校准

| 方法 | 说明 |
|------|------|
| `calibrate_printer(bed_level, motor_noise_calibration, vibration_compensation)` | 启动打印机校准（可分别控制各校准项） |

校准选项:
- `bed_level` - 热床调平
- `motor_noise_calibration` - 电机噪声消除
- `vibration_compensation` - 振动补偿

### 12. 固件管理

| 方法 (MQTT 层) | 说明 |
|------|------|
| `firmware_version()` | 获取当前固件版本 |
| `new_printer_firmware()` | 检查是否有新固件可用 |
| `upgrade_firmware(override)` | 升级固件（>= 1.08 版本需要 override=True） |
| `downgrade_firmware(firmware_version)` | 降级到指定历史版本 |
| `get_firmware_history()` | 获取固件版本历史 |
| `request_firmware_history()` | 请求打印机上报固件历史 |

### 13. 打印机信息读取

| 方法 | 说明 | 返回类型 |
|------|------|----------|
| `get_file_name()` | 当前/上次打印文件名 | `str` |
| `subtask_name()` | 当前子任务名称 | `str` |
| `gcode_file()` | 当前 G-code 文件名 | `str` |
| `print_type()` | 打印来源类型 ("cloud"/"local") | `str` |
| `print_error_code()` | 打印错误码 (0=正常) | `int` |
| `nozzle_type()` | 喷嘴类型 (不锈钢/硬化钢) | `NozzleType` |
| `nozzle_diameter()` | 喷嘴直径 (mm) | `float` |
| `current_layer_num()` | 当前打印层数 | `int` |
| `total_layer_num()` | 总层数 | `int` |
| `wifi_signal()` | WiFi 信号强度 (dBm) | `str` |

### 14. 状态监控

| 方法 | 说明 | 返回类型 |
|------|------|----------|
| `get_state()` | 获取 G-code 状态 (IDLE/RUNNING/PAUSE/FINISH/FAILED) | `GcodeState` |
| `get_current_state()` | 获取详细打印状态（36 种状态） | `PrintStatus` |
| `get_percentage()` | 打印进度百分比 | `int \| str \| None` |
| `get_time()` | 剩余时间（分钟） | `int \| str \| None` |
| `mqtt_dump()` | 导出所有 MQTT 原始数据 | `dict` |

**GcodeState 枚举值:**

| 状态 | 说明 |
|------|------|
| `IDLE` | 空闲 |
| `PREPARE` | 准备中（文件上传） |
| `RUNNING` | 打印中 |
| `PAUSE` | 暂停 |
| `FINISH` | 完成 |
| `FAILED` | 失败 |
| `UNKNOWN` | 未知 |

**PrintStatus 详细状态** (36 种)，包括:
- 打印中 / 自动调平 / 热床预热 / 扫描 XY 机械模式
- 换料 / 暂停（多种原因：用户暂停、断料、温度异常、堵头等）
- 加热喷嘴 / 校准挤出 / 扫描热床 / 检查首层
- 校准 LiDAR / 归零 / 清洁喷嘴 / 冷却箱体
- 加载/卸载耗材 / 校准电机噪声 / 空闲 等

### 15. 其他功能

| 方法 | 说明 |
|------|------|
| `reboot()` | 重启打印机（需要手动重新连接） |
| `set_onboard_printer_timelapse(enable)` | 启用/禁用打印机自带延时摄影 |
| `set_nozzle_info(nozzle_type, nozzle_diameter)` | 设置喷嘴信息（类型 + 直径） |
| `request_access_code()` | 请求打印机访问码 |
| `get_access_code()` | 获取本地访问码 |

---

## 枚举类型参考

### `Filament` - 耗材类型枚举

内置 50+ 种耗材，每种包含:
- `tray_info_idx`: 料盘信息索引
- `nozzle_temp_min`: 最低喷嘴温度
- `nozzle_temp_max`: 最高喷嘴温度
- `tray_type`: 材料类型

<details>
<summary>常用耗材列表</summary>

| 名称 | 类型 | 温度范围 |
|------|------|----------|
| BAMBU_PLA_Basic | PLA | 190-250°C |
| BAMBU_PLA_Matte | PLA | 190-250°C |
| BAMBU_ABS | ABS | 240-270°C |
| BAMBU_PETG_HF | PETG | 230-260°C |
| BAMBU_TPU_95A | TPU | 200-250°C |
| BAMBU_PA_CF | PA-CF | 270-300°C |
| BAMBU_PC | PC | 260-280°C |
| BAMBU_ASA | ASA | 240-270°C |
| BAMBU_PVA | PVA | 220-250°C |
| SUPPORT_W (水溶支撑) | PLA-S | 190-250°C |
| SUPPORT_G (通用支撑) | PA-S | 190-250°C |

</details>

### `NozzleType` - 喷嘴类型

| 值 | 说明 |
|----|------|
| `STAINLESS_STEEL` | 不锈钢喷嘴 |
| `HARDENED_STEEL` | 硬化钢喷嘴 |

### `PrinterType` - 打印机型号

| 值 | 说明 |
|----|------|
| `P1S` | Bambu Lab P1S |
| `P1P` | Bambu Lab P1P |
| `A1` | Bambu Lab A1 |
| `A1_MINI` | Bambu Lab A1 Mini |
| `X1C` | Bambu Lab X1 Carbon |
| `X1E` | Bambu Lab X1E |

---

## 支持的打印机型号

- Bambu Lab X1 Carbon
- Bambu Lab X1E
- Bambu Lab P1S
- Bambu Lab P1P
- Bambu Lab A1
- Bambu Lab A1 Mini

---

## 依赖

| 包 | 用途 |
|----|------|
| `paho-mqtt` | MQTT 通信 |
| `Pillow` | 图像处理 (摄像头帧/打印预览图) |

---

## 使用示例

### 监控打印状态

```python
import time
import bambulabs_api as bl

printer = bl.Printer("192.168.1.200", "12347890", "AC12309BH109")
printer.connect()

try:
    while True:
        time.sleep(5)
        print(f"状态: {printer.get_state()}")
        print(f"进度: {printer.get_percentage()}%")
        print(f"热床: {printer.get_bed_temperature()}°C")
        print(f"喷嘴: {printer.get_nozzle_temperature()}°C")
        print(f"剩余: {printer.get_time()} 分钟")
finally:
    printer.disconnect()
```

### 上传并打印

```python
import bambulabs_api as bl

printer = bl.Printer("192.168.1.200", "12347890", "AC12309BH109")
printer.connect()

# 上传 3MF 文件
with open("model.3mf", "rb") as f:
    printer.upload_file(f, "model.3mf")

# 开始打印 (plate 1)
printer.start_print("model.3mf", 1)
```

### 获取摄像头画面

```python
import bambulabs_api as bl

printer = bl.Printer("192.168.1.200", "12347890", "AC12309BH109")
printer.connect()

image = printer.get_camera_image()
image.save("snapshot.png")
```

### 发送 G-code

```python
# 单条命令
printer.gcode("G28")  # 回零

# 多条命令
printer.gcode(["G90", "G0 X100 Y100 Z50 F3000"])
```
