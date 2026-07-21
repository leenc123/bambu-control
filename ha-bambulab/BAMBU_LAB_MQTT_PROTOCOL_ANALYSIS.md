# Bambu Lab 3D 打印机 MQTT 协议分析文档

> 基于 `pybambu`（HomeAssistant 集成）全面逆向分析  
> 适用语言：**Android (Kotlin)**  
> 适用打印机：A1 / A1 Mini / A2L / P1P / P1S / P2S / X1 / X1C / X1E / X2D / H2C / H2D / H2D Pro / H2S

---

## 目录

1. [架构总览](#一架构总览)
2. [连接方式](#二连接方式)
3. [MQTT 协议细节](#三mqtt-协议细节)
4. [数据模型 & 报文解析](#四数据模型--报文解析)
5. [所有控制指令](#五所有控制指令)
6. [AMS 系统详解](#六ams-系统详解)
7. [云端 REST API](#七云端-rest-api)
8. [功能特性矩阵](#八功能特性矩阵)
9. [摄像头协议](#九摄像头协议)
10. [FTP 文件传输](#十ftp-文件传输)
11. [Android 架构建议](#十一android-架构建议)

---

## 一、架构总览

```
┌──────────────────────────────────────────┐
│          Android App (你的 UI 层)          │
├──────────────────────────────────────────┤
│         PrinterRepository (数据仓库)       │
├──────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ MQTT     │  │ Cloud    │  │ Camera │  │
│  │ Client   │  │ REST API │  │ Thread │  │
│  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│       │              │            │        │
│  ┌────▼──────────────▼────────────▼────┐  │
│  │         Data Model / Parser          │  │
│  │  Device / PrintJob / AMSList / ...   │  │
│  └─────────────────────────────────────┘  │
└──────────────────────────────────────────┘

         │                    │
    ┌────▼────┐         ┌────▼────┐
    │ 打印机   │◄────────│Bambu    │
    │ (局域网) │  MQTT   │Cloud    │
    └─────────┘  8883   │ MQTT    │
                         └─────────┘
```

**核心思想**：Android App 通过 MQTT 与打印机（或 Bambu 云端 MQTT Broker）通信，所有打印机状态以 JSON 报文实时推送，控制指令也是 JSON 格式发布。

---

## 二、连接方式

打印机支持两种连接模式，二选一：

### 2.1 局域网模式 (Local MQTT)

| 参数 | 值 |
|------|-----|
| 协议 | MQTT v3.1.1 over TLS |
| 地址 | 打印机 IP（局域网内） |
| 端口 | **8883** |
| 用户名 | `bblp`（固定） |
| 密码 | `access_code`（打印机屏幕上的访问码） |
| TLS | 双向证书认证（加载 certs/ 目录下所有 `.cert` 文件） |
| 适用场景 | 局域网内直连，无云端依赖 |

```
connect("192.168.1.100", 8883, TLS)
  → username = "bblp"
  → password = access_code
  → clientId = "ha-bambulab-{uuid}"
```

### 2.2 云端模式 (Bambu Cloud MQTT)

| 参数 | 值 |
|------|-----|
| 协议 | MQTT v3.1.1 over TLS |
| 地址 | `us.mqtt.bambulab.com`（海外）或 `cn.mqtt.bambulab.com`（中国） |
| 端口 | **8883** |
| 用户名 | Bambu 账号用户名 (`u_123456`) |
| 密码 | JWT `auth_token` |
| TLS | 标准证书链 |
| 适用场景 | 远程访问，不在同一局域网 |

> 云端模式下，云端 MQTT 会代理打印机推送。收到 `client.connected` / `client.disconnected` 事件表明打印机上线/离线。

---

## 三、MQTT 协议细节

### 3.1 Topic

| Topic | 方向 | QoS | 说明 |
|-------|------|-----|------|
| `device/{serial}/report` | **订阅 (Subscribe)** | 0 | 打印机→App，所有状态上报 |
| `device/{serial}/request` | **发布 (Publish)** | 0 | App→打印机，所有控制指令 |

### 3.2 连接建立流程

```
[初始化]
  │
  ├── 创建 MQTT Client (Paho / 原生)
  │     clientId = "ha-bambulab-{uuid4}"
  │     protocol = MQTT v3.1.1
  │     cleanSession = true
  │
  ├── 配置 TLS（局域网：加载本地证书 | 云端：标准 CA）
  ├── 设置用户名/密码
  ├── keepAlive = 5 秒
  ├── automaticReconnect = true
  │     minDelay = 1s, maxDelay = 30s
  │
  └── connect(host, 8883)

[onConnect 成功]
  │
  ├── subscribe("device/{serial}/report", 0)
  │
  ├── publish → GET_VERSION
  │     {"info": {"sequence_id": "0", "command": "get_version"}}
  │
  └── publish → PUSH_ALL
        {"pushing": {"sequence_id": "0", "command": "pushall"}}

[收到第一个有效数据后]
  │
  ├── 设备确认 (_on_device_confirmed)
  ├── 启动 Watchdog（60 秒无数据则重新请求）
  └── 启动摄像头拉取线程（如启用）
```

### 3.3 Watchdog 机制

- 60 秒内无任何数据到达 → 发送 `START_PUSH`
- 重新收到数据后重置计时器

```
START_PUSH = {"pushing": {"sequence_id": "0", "command": "start"}}
```

### 3.4 重要：断开码说明

| 断开码 | 含义 |
|--------|------|
| 0 | 正常断开 |
| 5 | **访问被拒绝** — 检查 serial / access_code / IP |

> 断线码 5 不会自动重连，避免死循环。

---

## 四、数据模型 & 报文解析

所有状态更新都走 `device/{serial}/report` Topic，`on_message` 回调中按 JSON 结构分发。

### 4.1 报文路由逻辑

```
onMessage(payload)
  │
  ├── payload 有 "event" 字段？
  │   ├── event == "client.connected"    → 打印机上线
  │   └── event == "client.disconnected" → 打印机离线
  │
  └── payload 有 "print" 字段？
      ├── print.command ≠ push_status  → 直接更新
      └── print.command == push_status →
            ├── msg == 0 → 首次全量推送完成
            └── 更新所有子模型

  └── payload 有 "info" 且 command == "get_version"？
      └── 更新版本信息

  └── payload 有 "system" 且 command == "ledctrl"？
      └── 更新热床灯状态
```

### 4.2 打印机信息（get_version 响应）

**请求**：
```json
{"info": {"sequence_id": "0", "command": "get_version"}}
```

**响应**：
```json
{
  "info": {
    "command": "get_version",
    "sequence_id": "20004",
    "module": [
      {"name": "ota",    "project_name": "C12", "sw_ver": "01.08.00.00", "hw_ver": "OTA",  "sn": "..."},
      {"name": "esp32",  "project_name": "C12", "sw_ver": "01.11.35.43", "hw_ver": "AP04", "sn": "..."}
    ]
  }
}
```

**解析规则**：

| 字段 | 来源 |
|------|------|
| `device_type` | 从 `product_name` 或 `hw_ver` + `project_name` 推断 |
| `sw_ver` | `module` 中 `name == "ota"` 的 `sw_ver` |
| `hw_ver` | `module` 中 `name == "esp32"` / `"rv1126"` / `"ap"` 的 `hw_ver` |
| `ams/x` | `module` 中 `name` 以 `ams/`、`ams_f1/`、`n3f/`、`n3s/` 开头的条目 |

**打印机型号推断表**：

| `hw_ver` | `project_name` | `product_name` | 型号 |
|----------|---------------|----------------|------|
| AP04 | C11 | - | **P1P** |
| AP04 | C12 | Bambu Lab P1S | **P1S** |
| AP05 | N2S | Bambu Lab A1 | **A1** |
| AP04/AP05/AP07 | N1 | Bambu Lab A1 mini | **A1 Mini** |
| AP05 | (空) | - | **X1C** |
| AP02 | - | - | **X1E** |
| - | - | Bambu Lab H2D | **H2D** |

### 4.3 打印状态（print / push_status）

这是**最核心**的报文，包含打印进度、温度、AMS、灯光等全部状态。

```json
{
  "print": {
    "gcode_state": "RUNNING",
    "mc_percent": 75,
    "mc_remaining_time": 45,
    "gcode_file": "/data/Metadata/plate_1.gcode",
    "subtask_name": "My Print",
    "print_type": "cloud",
    "layer_num": 12,
    "total_layer_num": 50,
    "print_error": 0,
    "wifi_signal": "-53dBm",
    "gcode_start_time": "1681479206",
    "home_flag": -1066934785,
    "ams_mapping": [0, -1, 1],
    "s_obj": [],
    "gcode_file_prepare_percent": 100,

    "upgrade_state": {
      "new_version_state": 2,
      "new_ver_list": [
        {"name": "ota", "cur_ver": "01.02.03.00", "new_ver": "01.03.00.00"}
      ]
    },

    "lights_report": [
      {"node": "chamber_light", "mode": "on"},
      {"node": "work_light", "mode": "flashing"}
    ],

    "device": {
      "bed": {"info": {"temp": 6553700}, "state": 2},
      "ctc": {"info": {"temp": 43}, "state": 0},
      "fan": {"fan1_speed": 0, "fan2_speed": 0, "fan3_speed": 0},
      "extruder": {
        "info": [
          {"id": 0, "temp": 14418140, "snow": 259},
          {"id": 1, "temp": 5767327, "snow": 3}
        ],
        "state": 2
      },
      "nozzle": {
        "info": [
          {"id": 0, "diameter": "0.4", "type": "HS01"},
          {"id": 1, "diameter": "0.4", "type": "HS01"}
        ]
      },
      "airduct": {
        "modeCur": 0,
        "modeList": [{"modeId": 0}, {"modeId": 1}, {"modeId": 2}]
      }
    },

    "ipcam": {
      "ipcam_dev": "1",
      "ipcam_record": "enable",
      "resolution": "1080p",
      "rtsp_url": "rtsps://192.168.1.64/streaming/live/1",
      "timelapse": "disable"
    },

    "ams": {
      "ams": [{...}],
      "ams_exist_bits": "1",
      "tray_exist_bits": "f",
      "tray_now": "255",
      "tray_is_bbl_bits": "f",
      "tray_read_done_bits": "f",
      "tray_tar": "255",
      "version": 3
    },

    "speed_profile": 2,
    "mc_print_stage": 1,
    "hw_switch_state": 1,
    "nozzle_diameter": "0.4",
    "nozzle_type": "hardened_steel",
    "stat": "46258008",
    "net": {
      "conf": 16,
      "info": [{"ip": 1594493450, "mask": 16777215}]
    }
  }
}
```

#### 4.3.1 gcode_state 枚举

| 值 | 含义 |
|----|------|
| `"idle"` | 空闲 |
| `"prepare"` | 准备中（下载文件） |
| `"running"` | 打印中 |
| `"pause"` | 暂停 |
| `"finish"` | 打印完成 |
| `"failed"` | 打印失败 |
| `"init"` | 初始化 |
| `"offline"` | 离线 |
| `"slicing"` | 切片中 |
| `"unknown"` | 未知 |

#### 4.3.2 print_type 枚举

| 值 | 含义 |
|----|------|
| `"cloud"` | 云端打印 |
| `"local"` | 局域网打印 |
| `"idle"` | 空闲 |
| `"system"` | 系统 |

#### 4.3.3 print_error 特殊值

| 值 | 含义 |
|----|------|
| `50348044` | **用户取消打印** |

#### 4.3.4 温度解析（重要！）

**新固件格式**（H2D 等双喷嘴打印机）：

```json
"device": {
  "bed": {"info": {"temp": 6553700}},      // 低16位=当前, 高16位=目标
  "ctc": {"info": {"temp": 43}},           // 腔室温度
  "extruder": {
    "info": [
      {"id": 0, "temp": 14418140, "snow": 259},  // snow: 高8位=AMS索引, 低4位=槽位
      {"id": 1, "temp": 5767327,  "snow": 3}
    ],
    "state": 2   // 低4位=挤出机数, 次低4位=活跃挤出机
  }
}
```

**温度编码**：
```kotlin
fun parseTemp(raw: Int): Pair<Int, Int> {
    val current = raw and 0xFFFF
    val target = (raw shr 16) and 0xFFFF
    return Pair(current, target)
}
```

**旧固件兼容字段**：`bed_temper`、`bed_target_temper`、`nozzle_temper`、`nozzle_target_temper`、`chamber_temper`

#### 4.3.5 home_flag 位标志（X1 系列）

`home_flag` 是一个 32 位整数，按位解析：

| 位 | 掩码 | 含义 |
|----|------|------|
| 0 | `0x0001` | X 轴已回零 |
| 1 | `0x0002` | Y 轴已回零 |
| 2 | `0x0004` | Z 轴已回零 |
| 3 | `0x0008` | 电压 220V |
| 4 | `0x0010` | XCAM 自动恢复步进丢失 |
| 5 | `0x0020` | 摄像头正在录制 |
| 7 | `0x0080` | AMS 已校准剩余量 |
| 8 | `0x0100` | SD 卡存在 |
| 9 | `0x0200` | SD 卡异常 |
| 10 | `0x0400` | AMS 自动切换 |
| 17 | `0x20000` | XCAM 允许提示音 |
| 18 | `0x40000` | 有线网络连接 |
| 19 | `0x80000` | 支持缠料检测 |
| 20 | `0x100000` | 缠料检测触发 |
| 21 | `0x200000` | 支持电机校准 |
| 23 | `0x800000` | **门打开** |
| 26 | `0x4000000` | 已安装 Plus |
| 27 | `0x8000000` | 已支持 Plus |

#### 4.3.6 stat 字段（H2 系列门状态）

```kotlin
// stat 是十六进制字符串，如 "46258008"
val statValue = stat.toInt(16)
val doorOpen = (statValue and 0x00800000) != 0
```

#### 4.3.7 noozle 数据结构

**新格式（H2D 等）**：
```json
"nozzle": {
  "info": [
    {"id": 0, "diameter": "0.4", "type": "HS01"},
    {"id": 1, "diameter": "0.4", "type": "HS01"}
  ]
}
```

**旧格式（X1C）**：
```json
"nozzle": {"0": {"info": 8, "temp": 23}, "info": 69}
// 或
"nozzle_diameter": "0.4",
"nozzle_type": "hardened_steel"
```

**喷嘴类型编码**：

| 码 | 含义 |
|----|------|
| `XX00` | 不锈钢 (Stainless Steel) |
| `XX01` | 硬化钢 (Hardened Steel) |
| `XX05` | 碳化钨 (Tungsten Carbide) |
| `XHXX` | 高流量 |
| `XHXX` 其中 H→E | 高流量（已停产） |
| `XUXX` | TPU 高流量 |

#### 4.3.8 风扇定义

| 风扇 | 枚举值 | GCode 标识 |
|------|--------|-----------|
| 部件冷却 (Part Cooling) | 1 | `P1` |
| 辅助风扇 (Auxiliary) | 2 | `P2` |
| 腔室循环 (Chamber) | 3 | `P3` |
| 热端散热 (Heatbreak) | 4 | - |
| 次辅助风扇 (Secondary Aux) | 5 | `P10` |

风扇速度 0-15 PWM 步进 → 百分比转换：
```kotlin
fun fanToPercentage(raw: Int): Int {
    return ceil(raw / 15.0 * 100 / 10) * 10  // 取整到 10% 的倍数
}
```

#### 4.3.9 速度档位

| 值 | 名称 |
|----|------|
| 1 | Silent（静音） |
| 2 | Standard（标准） |
| 3 | Sport（运动） |
| 4 | Ludicrous（疯狂） |

#### 4.3.10 风道模式（airduct）

| modeId | 含义 |
|--------|------|
| 0 | Cooling（冷却） |
| 1 | Heating（加热） |
| 2 | Laser（激光） |

### 4.4 事件回调清单

App 内部应暴露这些事件给 UI 层：

| 事件 | 触发时机 |
|------|---------|
| `PRINTER_READY` | 首次完整数据就绪（push_all + get_version 都到位） |
| `PRINTER_DATA_UPDATE` | 任何数据更新 |
| `PRINTER_INFO_UPDATE` | 版本信息更新 |
| `PRINT_STARTED` | 打印开始 |
| `PRINT_FINISHED` | 打印完成 |
| `PRINT_FAILED` | 打印失败 |
| `PRINT_CANCELED` | 打印取消 |
| `LIGHT_UPDATE` | 灯状态变化 |
| `CAMERA_DISABLED` | 摄像头被禁用 |

---

## 五、所有控制指令

所有指令发布到 Topic `device/{serial}/request`。

### 5.1 基础打印控制

```json
// 暂停
{"print": {"sequence_id": "0", "command": "pause"}}

// 恢复
{"print": {"sequence_id": "0", "command": "resume"}}

// 停止
{"print": {"sequence_id": "0", "command": "stop"}}
```

### 5.2 灯控制

```json
// 舱灯开
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "chamber_light", "led_mode": "on",
             "led_on_time": 500, "led_off_time": 500, "loop_times": 0, "interval_time": 0}}

// 舱灯关
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "chamber_light", "led_mode": "off",
             "led_on_time": 500, "led_off_time": 500, "loop_times": 0, "interval_time": 0}}

// 舱灯2 (H2/X2系列)
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "chamber_light2", "led_mode": "on", ...}}
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "chamber_light2", "led_mode": "off", ...}}

// 热床灯 (H2D)
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "heatbed_light", "led_mode": "on",
             "led_on_time": 0, "led_off_time": 0, "loop_times": 0, "interval_time": 0}}
{"system": {"sequence_id": "0", "command": "ledctrl", "led_node": "heatbed_light", "led_mode": "off", ...}}
```

### 5.3 速度设置

```json
{"print": {"sequence_id": "0", "command": "print_speed", "param": "1"}}
// param: 1=静音 2=标准 3=运动 4=疯狂
```

### 5.4 GCode 指令（万能方式）

```json
{"print": {"sequence_id": "0", "command": "gcode_line", "param": "M104 S200\n"}}
```

**常用 GCode 模板**：

| 功能 | GCode |
|------|-------|
| 设喷嘴温度 | `M104 S{temp}\n` |
| 设热床温度 | `M140 S{temp}\n` |
| 设腔室温度 (普通) | `M141 S{temp}\n` |
| 设腔室温度 + 加热模式 | `M145 P1\nM141 S{temp}\n` |
| 设腔室温度 + 冷却模式 | `M141 S{temp}\nM145 P0\n` |
| 部件冷却风扇 | `M106 P1 S{speed}\n` (speed=0-255) |
| 辅助风扇 | `M106 P2 S{speed}\n` |
| 腔室风扇 | `M106 P3 S{speed}\n` |
| 次辅助风扇 | `M106 P10 S{speed}\n` |
| 移动轴 (相对) | `G91\nG1 {axis}{distance} F{speed}\n` |
| 回零 | `G28\n` |
| 挤出 | `M83\nG0 E{distance} F900\n` |
| 读取 RFID | `M620 R{global_tray_index}\n` |
| 禁用软限位 | `M211 S\nM211 X1 Y1 Z1\nM1002 push_ref_mode\n...\nM1002 pop_ref_mode\nM211 R\n` |

> **速度设100%的公式**: `speed = ceil(255 * percentage / 100)`，其中 percentage 是 10 的倍数（0-100）。

### 5.5 AMS 切换料盘

```json
{"print": {
  "command": "ams_change_filament",
  "sequence_id": "0",
  "ams_id": 0,
  "slot_id": 1,
  "target": 255,
  "curr_temp": 0,
  "tar_temp": 0
}}
```

- `ams_id`: AMS 索引号
- `slot_id`: 该 AMS 中的槽位号 (0-3)
- `target`: 目标挤出机 (默认 `255`)
- `curr_temp` / `tar_temp`: 当前/目标温度

### 5.6 AMS 料盘配置（编辑 AMS）

```json
{"print": {
  "command": "ams_filament_setting",
  "sequence_id": "0",
  "ams_id": 0,
  "tray_id": 0,
  "tray_info_idx": "GFA01",
  "tray_color": "FFFF00FF",
  "nozzle_temp_min": 190,
  "nozzle_temp_max": 240,
  "tray_type": "PLA"
}}
```

| 字段 | 说明 | 示例 |
|------|------|------|
| `tray_info_idx` | Bambu  filament ID | `"GFA01"` = Bambu PLA Matte |
| `tray_color` | RGBA 色值（16进制） | `"FFFF00FF"` = 纯黄不透明 |
| `nozzle_temp_min` | 最低喷嘴温度 | `190` |
| `nozzle_temp_max` | 最高喷嘴温度 | `240` |
| `tray_type` | 耗材类型 | `"PLA"`, `"ABS"`, `"PETG"` |

### 5.7 AMS 读取 RFID

```json
{"print": {
  "command": "ams_get_rfid",
  "sequence_id": "0",
  "ams_id": 0,
  "slot_id": 0
}}
```

### 5.8 AMS 灯丝烘干（AMS 2 Pro / AMS HT）

```json
{"print": {
  "command": "ams_filament_drying",
  "sequence_id": "0",
  "ams_id": 0,
  "temp": 45,
  "cooling_temp": 0,
  "duration": 2,
  "humidity": 0,
  "mode": 0,
  "rotate_tray": false
}}
```

| 字段 | 说明 | 范围 |
|------|------|------|
| `temp` | 烘干温度 | AMS 2: max 65°C, AMS HT: max 85°C |
| `duration` | 烘干时长 (小时) | 1-24 |
| `rotate_tray` | 是否旋转料盘 | true/false |
| `cooling_temp` | 冷却目标温度 | 通常 0 |
| `mode` | 模式 | 0=标准 |
| `humidity` | 湿度设定 | 0 |

**停止烘干**：发送相同命令，`duration=0` 或实现自己的停止逻辑。

### 5.9 加载/卸载/重试耗材

```json
// 重试加载外部耗材
{"print": {"sequence_id": "0", "command": "ams_control", "param": "resume"}}

// 加载完成确认
{"print": {"sequence_id": "0", "command": "ams_control", "param": "done"}}
```

### 5.10 打印项目文件

```json
{"print": {
  "sequence_id": 0,
  "command": "project_file",
  "param": "Metadata/plate_1.gcode",
  "url": "ftp://192.168.1.100/cache/my_model.3mf",
  "bed_type": "auto",
  "timelapse": false,
  "bed_leveling": true,
  "flow_cali": true,
  "vibration_cali": true,
  "layer_inspect": true,
  "use_ams": false,
  "ams_mapping": [0],
  "subtask_name": "",
  "profile_id": "0",
  "project_id": "0",
  "subtask_id": "0",
  "task_id": "0"
}}
```

### 5.11 跳过打印对象

```json
{"print": {
  "sequence_id": "0",
  "command": "skip_objects",
  "obj_list": [409, 1463]
}}
```

`obj_list` 中的 ID 来自 `s_obj` 字段和 `printable_objects` 属性。

### 5.12 声音控制

```json
// A1 / H2D 提示音
{"print": {"sequence_id": "0", "command": "print_option", "sound_enable": true}}
{"print": {"sequence_id": "0", "command": "print_option", "sound_enable": false}}

// H2D 蜂鸣器
{"print": {"sequence_id": "0", "command": "buzzer_ctrl", "mode": 0, "reason": ""}}  // 静音
{"print": {"sequence_id": "0", "command": "buzzer_ctrl", "mode": 1, "reason": ""}}  // 火警
{"print": {"sequence_id": "0", "command": "buzzer_ctrl", "mode": 2, "reason": ""}}  // 蜂鸣提示
```

### 5.13 风道模式设置

```json
{"print": {"sequence_id": "0", "command": "set_airduct", "modeId": 0, "submode": -1}}
// modeId: 0=Cooling, 1=Heating, 2=Laser
```

### 5.14 强制刷新

```json
{"pushing": {"sequence_id": "0", "command": "pushall"}}
{"pushing": {"sequence_id": "0", "command": "start"}}
```

### 5.15 固件升级确认

```json
{"upgrade": {
  "command": "upgrade_confirm",
  "module": "ota",
  "reason": "",
  "result": "success",
  "sequence_id": "0",
  "src_id": 2,
  "upgrade_type": 4,
  "url": "https://public-cdn.bblmw.com/upgrade/device/{model}/{version}/product/{hash}/{stamp}.json.sig",
  "version": "{version}"
}}
```

---

## 六、AMS 系统详解

### 6.1 AMS 数据模型

```
AMSList
  └── data: Map<Int, AMSInstance>       ← key = AMS 索引号
        ├── index: Int                   ← AMS 索引 (0,1,2,...)
        ├── model: String                ← "AMS" / "AMS Lite" / "AMS 2 Pro" / "AMS HT"
        ├── serial: String
        ├── sw_version: String
        ├── hw_version: String
        ├── humidity_index: Int          ← 1-5（干燥剂级别）
        ├── humidity: Int                ← 0-100（实时湿度%）
        ├── temperature: Float           ← 0-100（内部温度°C）
        ├── remaining_drying_time: Int   ← 剩余烘干时间（分钟）
        ├── drying_temperature: Int      ← 烘干设定温度
        ├── drying_duration: Int         ← 烘干设定时长
        ├── drying_filament: String      ← 烘干耗材类型
        ├── active: Boolean              ← 是否正在使用
        │
        └── tray: List<AMSTray>[4]
              ├── id: Int                ← 槽位号 (0-3)
              ├── empty: Boolean         ← 是否空槽
              ├── active: Boolean        ← 当前是否激活
              ├── name: String           ← 人类可读名称
              ├── type: String           ← 耗材类型 (PLA, ABS...)
              ├── sub_brands: String     ← 子品牌
              ├── color: String          ← RRGGBBAA 十六进制
              ├── idx: String            ← filament ID (GFL99...)
              ├── k: Float               ← K 值（P1P 特有）
              ├── tag_uid: String        ← RFID tag UID
              ├── tray_uuid: String      ← 料盘 UUID
              ├── remain: Int            ← 剩余百分比 (0-100, -1=未知)
              ├── nozzle_temp_min: Int
              ├── nozzle_temp_max: Int
              ├── tray_weight: Int       ← 料盘重量
              ├── dry_temp: Int          ← 烘干温度
              ├── dry_time: Int          ← 烘干时间
              ├── bed_temp: Int          ← 热床温度
              └── cols: List<String>     ← 颜色列表 (多色)
```

### 6.2 AMS 连接外部料盘

**外部料盘 1 (ExternalSpool)**：通过 `vt_tray` 字段（旧）或 `vir_slot[].id==254`（新 H2D）上报。

**外部料盘 2**：通过 `vir_slot[].id==253` 上报。

```json
// 旧格式
"vt_tray": {
  "id": "254",
  "tray_info_idx": "GFB99",
  "tray_type": "ABS",
  "tray_color": "000000FF",
  ...
}

// 新格式 (H2D)
"vir_slot": [
  {"id": "254", "tray_type": "PLA", ...},
  {"id": "253", "tray_type": "PETG", ...}
]
```

### 6.3 AMS 型号识别

**来自版本报文**（`module[].name`）：

| name 前缀 | 型号 |
|-----------|------|
| `ams/0`, `ams/1`, ... | AMS (标准 4 槽) |
| `ams_f1/0`, `ams_f1/1` | AMS Lite |
| `n3f/0` | AMS 2 Pro |
| `n3s/0` | AMS HT |

### 6.4 tray_now 编码

`tray_now` 表示当前哪个料盘被选中：

```kotlin
fun decodeTrayNow(trayNow: String): Pair<Int /*amsIndex*/, Int /*trayIndex*/> {
    val value = trayNow.toInt()
    return when {
        value == 255  -> Pair(255, 255)    // 无选中
        value == 254  -> Pair(255, 0)      // 外部料盘
        value >= 80   -> Pair(value, 0)    // AMS HT (索引≥128)
        else          -> Pair(value shr 2, value and 0x3)  // 标准 AMS
    }
}
```

**新固件**（双喷嘴打印机）：通过 `device.extruder.info[].snow` 解析：
```kotlin
fun decodeSnow(snow: Int): Pair<Int, Int> {
    return Pair(snow shr 8, snow and 0x3)
}
```

### 6.5 AMS 槽位状态标志

`state` 字段的低 5 位：

| 位 | 掩码 | 含义 |
|----|------|------|
| 0 | `0x01` | 有料盘 (SPOOL) |
| 1 | `0x02` | 有元数据 (METADATA) |
| 2 | `0x04` | 运动中 (MOTION) |
| 3 | `0x08` | 稳定 (STEADY) |
| 4 | `0x10` | RFID 已读 |

**料盘就绪判定**：
```kotlin
fun isSpoolLoaded(state: Int): Boolean {
    if (state and 0x01 == 0) return false           // 没料盘
    if (state <= 3) return state == 3               // 旧版：3=已加载
    return (state and 0x08) != 0                    // 新版：STEADY 位
}
```

### 6.6 AMS 湿度等级

| `humidity` 值 | 说明 |
|---------------|------|
| 1 | 干燥 |
| 2 | 干燥剂良好 |
| 3 | 稍潮 |
| 4 | 潮湿 |
| 5 | 非常潮湿 |

---

## 七、云端 REST API

### 7.1 BambuCloud 类

Base URL: `https://api.bambulab.com`（中国 → `https://api.bambulab.cn`）

### 7.2 接口列表

| 端点 | 方法 | 功能 | URL |
|------|------|------|-----|
| LOGIN | POST | 密码登录 | `/v1/user-service/user/login` |
| EMAIL_CODE | POST | 请求邮箱验证码 | `/v1/user-service/user/sendemail/code` |
| SMS_CODE | POST | 请求短信验证码（中国） | `/v1/user-service/user/sendsmscode` |
| TFA_LOGIN | POST | 2FA 登录 | `/api/sign-in/tfa` |
| BIND | GET | 获取绑定设备列表 | `/v1/iot-service/api/user/bind` |
| SLICER_SETTINGS | GET | 获取切片器设置 | `/v1/iot-service/api/slicer/setting?version=1.10.0.89` |
| TASKS | GET | 获取打印任务列表 | `/v1/user-service/my/tasks` |
| PROJECTS | GET | 获取项目列表 | `/v1/iot-service/api/user/project` |
| PREFERENCE | GET | 获取用户偏好 | `/v1/design-user-service/my/preference` |

### 7.3 请求头

```json
{
  "User-Agent": "bambu_network_agent/01.09.05.01",
  "X-BBL-Client-Name": "OrcaSlicer",
  "X-BBL-Client-Type": "slicer",
  "X-BBL-Client-Version": "01.09.05.51",
  "X-BBL-Language": "en-US",
  "X-BBL-OS-Type": "Android",
  "X-BBL-OS-Version": "14.0",
  "X-BBL-Agent-Version": "01.09.05.01",
  "X-BBL-Agent-OS-Type": "android",
  "Authorization": "Bearer {auth_token}",
  "Content-Type": "application/json",
  "Accept-Encoding": "gzip, deflate"
}
```

### 7.4 登录流程

```
[步骤1] POST /v1/user-service/user/login
  Body: {"account": "email@example.com", "password": "***"}

  ┌── 响应 200:
  │   ├── accessToken: "jwt..."   → ✅ 直接登录成功
  │   ├── loginType: "verifyCode" → 需要邮箱验证码 (跳步骤2)
  │   └── loginType: "tfa"        → 需要2FA (跳步骤3)
  │
  ├── 响应 403 + "cloudflare" → 被 Cloudflare 拦截
  └── 响应 429 + "cloudflare" → 限频

[步骤2] 验证码登录
  POST /v1/user-service/user/sendemail/code
    Body: {"email": "...", "type": "codeLogin"}

  POST /v1/user-service/user/login
    Body: {"account": "...", "code": "..."}
    → 返回 accessToken

[步骤3] 2FA 登录
  POST /api/sign-in/tfa
    Body: {"tfaKey": "...", "tfaCode": "..."}
    → Cookie 中取 `token`

[最终] 从 JWT 中解析 username
  // JWT payload 中有 {"username": "u_123456"}
```

### 7.5 获取设备列表

`GET /v1/iot-service/api/user/bind`

```json
{
  "message": "success",
  "devices": [
    {
      "dev_id": "SERIAL_NUMBER",
      "name": "Bambu P1S",
      "online": true,
      "print_status": "SUCCESS",
      "dev_model_name": "C12",
      "dev_product_name": "P1S",
      "dev_access_code": "12345678",
      "nozzle_diameter": 0.4
    }
  ]
}
```

### 7.6 获取任务列表

`GET /v1/user-service/my/tasks`

```json
{
  "total": 531,
  "hits": [
    {
      "id": 35237965,
      "title": "My Print",
      "status": 4,
      "startTime": "2023-12-21T19:02:16Z",
      "endTime": "2023-12-21T19:02:35Z",
      "weight": 34.62,
      "costTime": 10346,
      "deviceId": "SERIAL",
      "amsDetailMapping": [
        {"ams": 4, "sourceColor": "F4D976FF", "targetColor": "F4D976FF", "filamentId": "GFL99", "filamentType": "PLA"}
      ],
      "deviceModel": "P1P",
      "deviceName": "Bambu P1P",
      "bedType": "textured_plate"
    }
  ]
}
```

---

## 八、功能特性矩阵

按打印机型号 + 固件版本判定，`supports_feature()` 逻辑：

### 8.1 硬件功能

| 特性 | A1 | A1M | A2L | P1P | P1S | P2S | H2C | H2D | H2S | X1 | X1C | X1E | X2D |
|------|:--:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:--:|:---:|:---:|:---:|
| AUX_FAN | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CHAMBER_FAN | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CHAMBER_TEMP | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CAMERA_RTSP | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CAMERA_IMAGE | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| DOOR_SENSOR | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | FW≥1.7 | FW≥1.7 | FW≥1.1.2 | ✓ |
| DUAL_NOZZLES | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ |
| HEATBED_LIGHT | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| CHAMBER_LIGHT_2 | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |
| AIRDUCT_MODE | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |
| ACTIVE_CHAMBER_HEATER | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ |
| FIRE_ALARM_BUZZER | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| PROMPT_SOUND | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |

> ✓ = 支持，✗ = 不支持，FW≥X.Y = 固件版本达到才支持

### 8.2 AMS 特性（依赖固件版本）

| 特性 | 最低版本要求 |
|------|------------|
| AMS_SWITCH | A1: 01.06.00 / P1: 01.02.99.10 / X1: 01.05.06.01 |
| AMS_READ_RFID | A1: 01.06.00 / P1: 01.08.01.00 / X1: 01.09.00.00 |
| AMS_HUMIDITY | A1: 01.06.10.33 / P1: 01.07.50.18 / X1: 01.08.50.18 |
| AMS_DRYING | A1: 01.06.10.33 / P1: 01.07.50.18 / X1: 01.08.50.18 |
| AMS_TEMPERATURE | A1: 01.06.10.33 / P1: 01.07.50.18 / X1: ✓ |
| AMS_FILAMENT_REMAINING | A1: 01.06.10.33 / 其它: ✓ |
| AMS_DRYING_SETTINGS | P2S: 01.01.50.40 / H2C: 01.01.50.00 |

### 8.3 特性检测代码逻辑参考

```kotlin
fun supportsFeature(feature: Features, device: Device): Boolean {
    val model = device.info.deviceType
    return when (feature) {
        Features.AUX_FAN -> model !in listOf("A1", "A1MINI", "A2L")
        Features.AMS -> device.ams.data.isNotEmpty()
        Features.DUAL_NOZZLES -> model in listOf("H2C", "H2D", "H2DPRO", "X2D")
        // ...其他同理
    }
}
```

---

## 九、摄像头协议

### 9.1 RTSP 流（X1/X1C/X1E/P2S/H2/X2）

通过 `ipcam.rtsp_url` 字段获取 RTSP URL，例如：
```
rtsps://192.168.1.64/streaming/live/1
```

### 9.2 JPEG 帧拉取（A1/P1/A2L）

通过 TCP 端口 **6000** 建立 TLS 连接，发送 68 字节认证数据包，然后持续接收 JPEG 帧。

**认证数据包格式**（68 字节）：

| 偏移 | 字节数 | 内容 |
|------|--------|------|
| 0-3 | 4 | `0x40` (`@`) 小端 |
| 4-7 | 4 | `0x3000` 小端 |
| 8-11 | 4 | `0x00000000` |
| 12-15 | 4 | `0x00000000` |
| 16-47 | 32 | 用户名 `bblp` (ASCII)，末尾补 0 |
| 48-67 | 20 | access_code (ASCII)，末尾补 0 |

**JPEG 帧格式**（每次接收一个完整的帧）：

| 偏移 | 字节内容 | 说明 |
|------|---------|------|
| 0-3 | payload_size (小端 uint32) | JPEG 数据大小（不含这16字节头） |
| 4-7 | `0x00000000` | |
| 8-11 | `0x00000001` | |
| 12-15 | `0x00000000` | |
| 16-19 | `0xFF 0xD8 0xFF 0xE0` | JPEG SOI + APP0 起始标记 |
| 20..payload_size-2 | JPEG 数据 | |
| payload_size-2..end | `0xFF 0xD9` | JPEG EOI 结束标记 |

**接收流程**：
1. TCP 连接到 `{ip}:6000`
2. 包装为 TLS socket（使用局域网证书）
3. 发送 68 字节认证数据
4. 设为非阻塞模式，循环 `recv(4096)`
5. `SSLWantReadError` 时等待 1 秒后重试
6. 收到 16 字节 → 解析 payload_size，准备接收 JPEG
7. 后续数据追加到 `img` 缓冲区，直到 `img.size == payload_size`

---

## 十、FTP 文件传输

### 10.1 连接

```kotlin
val ftp = ImplicitFTP_TLS()
ftp.connect(ip, 990)        // 隐式 FTPS，端口 990
ftp.login("bblp", accessCode)
ftp.protP()                 // 数据通道也加密
```

> **注意**：需要自定义 SSL 包装，标准 `FTP_TLS` 的 `storbinary` 可能超时，需跳过 `conn.unwrap()`。

### 10.2 下载模型文件 (3MF)

打印机将 gcode/3mf 文件存在以下路径（因型号而异）：

| 型号 | 文件路径 |
|------|---------|
| X1 局域网打印 | `/data/Metadata/plate_1.gcode` |
| P1 局域网打印 | `/{subtask_name}.gcode.3mf` |
| X1/P1 云打印 | `/cache/{subtask_name}.3mf` |

**下载策略**：
1. 尝试 `/cache/{subtask_name}.3mf`
2. 尝试 `/{subtask_name}.3mf`
3. 遍历 FTP 查找最新 .3mf 文件

### 10.3 上传打印文件

```kotlin
// 上传 3mf/gcode 文件到打印机
ftp.storbinaryNoUnwrap("STOR /cache/{filename}.3mf", fileStream)
// 然后发送 project_file 指令触发打印
```

### 10.4 文件缓存

Android 本地缓存路径：`{app_cache_dir}/prints/` + `{fileSize}-{filename}`

---

## 十一、Android 架构建议

### 11.1 推荐模块划分

```
com.example.bambuapp/
│
├── mqtt/                       ← MQTT 连接层
│   ├── MqttManager.kt          ← 连接管理（Paho Android Service）
│   ├── MqttCallback.kt         ← 全局回调
│   ├── CommandFactory.kt       ← 指令 JSON 构造器
│   └── TlsHelper.kt            ← TLS 证书加载
│
├── cloud/                      ← 云端 API
│   ├── BambuCloudApi.kt        ← Retrofit 接口
│   ├── BambuCloudService.kt    ← 认证逻辑
│   └── model/                  ← 响应 DTO
│
├── data/                       ← 数据层
│   ├── model/                  ← 数据模型
│   │   ├── Device.kt
│   │   ├── PrinterInfo.kt
│   │   ├── PrintJob.kt
│   │   ├── Temperature.kt
│   │   ├── AMSInstance.kt
│   │   ├── AMSTray.kt
│   │   ├── ExternalSpool.kt
│   │   ├── Lights.kt
│   │   ├── Fans.kt
│   │   ├── Camera.kt
│   │   ├── HMSNotification.kt
│   │   └── HomeFlag.kt
│   │
│   ├── parser/                 ← JSON 报文解析
│   │   ├── PrintDataParser.kt
│   │   ├── AMSDataParser.kt
│   │   ├── InfoDataParser.kt
│   │   └── FeatureDetector.kt
│   │
│   └── repository/
│       └── PrinterRepository.kt   ← 单一数据源
│
├── service/
│   ├── PrinterService.kt       ← 前台服务（保持连接）
│   └── CameraService.kt        ← 摄像头帧拉取服务
│
├── ui/                         ← UI 层
│   ├── dashboard/              ← 主面板
│   ├── printer/                ← 打印机详情
│   ├── ams/                    ← AMS 编辑
│   ├── print/                  ← 打印控制
│   └── settings/               ← 设置
│
└── util/
    ├── Extensions.kt
    ├── Constants.kt
    └── CertManager.kt
```

### 11.2 MQTT 关键实现要点 (Kotlin)

```kotlin
// 1. 使用 Paho Android Service
class PrinterMqttService : Service() {
    
    private lateinit var mqttClient: MqttAndroidClient
    
    fun connect(host: String, port: Int, username: String, 
                password: String, serial: String, tlsContext: SSLContext?) {
        
        val serverUri = "ssl://$host:$port"
        val clientId = "bambu-app-${UUID.randomUUID()}"
        
        mqttClient = MqttAndroidClient(this, serverUri, clientId)
        
        val options = MqttConnectOptions().apply {
            this.userName = username
            this.password = password.toCharArray()
            keepAliveInterval = 5
            isAutomaticReconnect = true
            socketFactory = tlsContext?.socketFactory
            mqttVersion = MqttConnectOptions.MQTT_VERSION_3_1_1
            isCleanSession = true
        }
        
        mqttClient.setCallback(object : MqttCallbackExtended {
            override fun connectComplete(reconnect: Boolean, serverURI: String) {
                subscribe("device/$serial/report", 0)
                publish("device/$serial/request", 
                    """{"info":{"sequence_id":"0","command":"get_version"}}""", 0, false)
                publish("device/$serial/request",
                    """{"pushing":{"sequence_id":"0","command":"pushall"}}""", 0, false)
            }
            
            override fun messageArrived(topic: String, message: MqttMessage) {
                onMqttMessage(JSONObject(String(message.payload)))
            }
            
            override fun connectionLost(cause: Throwable?) { /* 处理断线 */ }
            override fun deliveryComplete(token: IMqttDeliveryToken) {}
        })
        
        mqttClient.connect(options)
    }
    
    private fun onMqttMessage(json: JSONObject) {
        when {
            json.has("event") -> handleCloudEvent(json.getJSONObject("event"))
            json.has("print") -> handlePrintData(json.getJSONObject("print"))
            json.has("info") -> handleInfoData(json.getJSONObject("info"))
            json.has("system") -> handleSystemData(json.getJSONObject("system"))
        }
    }
}
```

### 11.3 TLS 证书加载（局域网模式）

```kotlin
fun createLocalTlsContext(context: Context): SSLContext {
    val keyStore = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
        load(null, null)
        val certFiles = listOf(
            R.raw.bambu, R.raw.bambu_h2c_251122,
            R.raw.bambu_p2s_250626, R.raw.bambu_x2c_260425
        )
        certFiles.forEachIndexed { index, resId ->
            context.resources.openRawResource(resId).use { stream ->
                val cert = CertificateFactory.getInstance("X509")
                    .generateCertificate(stream)
                keyStore.setCertificateEntry("bambu_$index", cert)
            }
        }
    }
    
    val trustManager = TrustManagerFactory.getInstance("X509").apply {
        init(keyStore)
    }
    
    return SSLContext.getInstance("TLS").apply {
        init(null, trustManager.trustManagers, null)
    }
}
```

### 11.4 指令发送辅助函数

```kotlin
object Commands {
    fun pause() = """{"print":{"sequence_id":"0","command":"pause"}}"""
    fun resume() = """{"print":{"sequence_id":"0","command":"resume"}}"""
    fun stop() = """{"print":{"sequence_id":"0","command":"stop"}}"""
    
    fun setSpeed(level: Int) = 
        """{"print":{"sequence_id":"0","command":"print_speed","param":"$level"}}"""
    
    fun chamberLight(on: Boolean) = 
        """{"system":{"sequence_id":"0","command":"ledctrl","led_node":"chamber_light","led_mode":"${if(on)"on"else"off"}",...}}"""
    
    fun sendGcode(gcode: String) = 
        """{"print":{"sequence_id":"0","command":"gcode_line","param":"$gcode\n"}}"""
    
    fun setTemperature(nozzle: Int? = null, bed: Int? = null): String {
        val cmds = mutableListOf<String>()
        nozzle?.let { cmds.add("M104 S$it") }
        bed?.let { cmds.add("M140 S$it") }
        return sendGcode(cmds.joinToString("\\n"))
    }
    
    fun amsSwitchFilament(amsId: Int, slotId: Int) = 
        """{"print":{"command":"ams_change_filament","sequence_id":"0","ams_id":$amsId,"slot_id":$slotId,"target":255,"curr_temp":0,"tar_temp":0}}"""
    
    fun amsEditFilament(amsId: Int, trayId: Int, infoIdx: String, 
                         color: String, type: String, minTemp: Int, maxTemp: Int) = 
        """{"print":{"command":"ams_filament_setting","sequence_id":"0","ams_id":$amsId,"tray_id":$trayId,"tray_info_idx":"$infoIdx","tray_color":"$color","nozzle_temp_min":$minTemp,"nozzle_temp_max":$maxTemp,"tray_type":"$type"}}"""
}
```

### 11.5 数据流设计

```
[MQTT on_message]
       │
       ▼
  MqttManager (线程安全)
       │ emit(data: DataFrame)
       ▼
  PrinterRepository (LiveData / Flow)
       │
       ├── printerState: StateFlow<PrinterState>
       ├── amsState: StateFlow<AMSState>
       ├── printJobState: StateFlow<PrintJobState>
       ├── connectionState: StateFlow<ConnectionState>
       │
       ▼
  ViewModel
       │
       ▼
  UI (Compose / XML)
```

---

> **协议来源**：本文档基于 HomeAssistant Bambu Lab 集成 (`pybambu` 库) 的完整逆向分析，版本匹配至 H2D 固件。如有协议更新，请参考 Bambu Lab 官方固件变更。
