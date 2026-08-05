#!/usr/bin/env python3
"""
Bambu Lab 打印机模拟器
======================
连接到本地 MQTT broker，模拟打印机发布状态消息。
用于测试 Flutter App 的 UI 状态更新和 FTP 文件功能。

使用方法：
    pip install paho-mqtt pyftpdlib
    python tools/bambu_printer_simulator.py
    # 可选参数：
    #   --broker <地址>    MQTT broker 地址，默认 127.0.0.1（本机 mosquitto）
    #   --ip <地址>        对外广告的 IP（手机里填的打印机 IP），
    #                      默认自动检测本机局域网 IP
    #   示例: python tools/bambu_printer_simulator.py --ip 192.168.1.100

模拟器会：
    - 定期发布打印机状态（温度、进度、状态等）
    - 响应 App 的控制命令（暂停/继续/停止等）
    - 模拟 AMS 耗材信息
    - 模拟 get_version 设备信息
    - 启动 FTP 服务器（端口 9990），用于测试文件浏览/下载
"""

import argparse
import datetime
import ipaddress
import json
import os
import random
import shutil
import socket
import ssl
import tempfile
import time
import threading

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("需要安装 paho-mqtt: pip install paho-mqtt")
    exit(1)

try:
    from pyftpdlib.authorizers import DummyAuthorizer
    from pyftpdlib.handlers import FTPHandler, TLS_FTPHandler
    from pyftpdlib.servers import FTPServer
    HAS_FTP = True
except ImportError:
    HAS_FTP = False
    print("[注意] pyftpdlib 未安装，FTP 功能不可用: pip install pyftpdlib")

try:
    from cryptography import x509
    from cryptography.x509.oid import NameOID
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.backends import default_backend
    HAS_CRYPTO = True
except ImportError:
    HAS_CRYPTO = False

def _get_lan_ip() -> str:
    """自动检测本机局域网 IP（手机通过它访问模拟器）"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # 不实际发包：UDP connect 让内核选一条默认路由
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
        finally:
            s.close()
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass
    return "127.0.0.1"


def _parse_args():
    parser = argparse.ArgumentParser(description="Bambu Lab 打印机模拟器")
    parser.add_argument(
        "--broker", default="127.0.0.1",
        help="MQTT broker 地址（默认 127.0.0.1，即本机 mosquitto）"
    )
    parser.add_argument(
        "--port", type=int, default=1883,
        help="MQTT broker 端口（默认 1883）"
    )
    parser.add_argument(
        "--ip", default=None,
        help="对外广告的 IP（手机里填写的打印机 IP，默认自动检测本机局域网 IP）"
    )
    args = parser.parse_args()
    return args.broker, args.port, args.ip or _get_lan_ip()


# 配置
BROKER_HOST, BROKER_PORT, LAN_IP = _parse_args()
SERIAL_NUMBER = "TEST123456789"
PROJECT_NAME = "N1"  # A1 Mini


class PrinterSimulator:
    def __init__(self):
        self.client = mqtt.Client(client_id=f"simulator_{SERIAL_NUMBER}")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect

        # 打印机状态 - 模拟真机 push_status 结构
        self.print_state = {
            "upgrade_state": {
                "sequence_id": 0,
                "progress": "",
                "status": "IDLE",
                "consistency_request": False,
                "dis_state": 0,
                "err_code": 0,
                "force_upgrade": False,
                "message": "0%, 0B/s",
                "module": "",
                "new_version_state": 0,
                "cur_state_code": 0,
                "idx2": 2946424240,
                "new_ver_list": []
            },
            "ipcam": {
                "ipcam_dev": "1",
                "ipcam_record": "disable",
                "timelapse": "disable",
                "resolution": "1080P",
                "tutk_server": "disable",
                "mode_bits": 3
            },
            "xcam": {
                "buildplate_marker_detector": False
            },
            "upload": {
                "status": "idle",
                "progress": 0,
                "message": ""
            },
            "net": {
                "conf": 0,
                "info": [{"ip": 740272320, "mask": 16777215}]
            },
            "nozzle_temper": 27.1875,
            "nozzle_target_temper": 0,
            "bed_temper": 27.25,
            "bed_target_temper": 0,
            "chamber_temper": 5,
            "mc_print_stage": "1",
            "heatbreak_fan_speed": "0",
            "cooling_fan_speed": "0",
            "big_fan1_speed": "0",
            "big_fan2_speed": "0",
            "mc_percent": 0,
            "mc_remaining_time": 0,
            "ams_status": 0,
            "ams_rfid_status": 0,
            "hw_switch_state": 1,
            "spd_mag": 100,
            "spd_lvl": 2,
            "print_error": 0,
            "lifecycle": "product",
            "wifi_signal": "-45dBm",
            "gcode_state": "IDLE",
            "gcode_file_prepare_percent": "0",
            "queue_number": 0,
            "queue_total": 0,
            "queue_est": 0,
            "queue_sts": 0,
            "project_id": "0",
            "profile_id": "0",
            "task_id": "0",
            "subtask_id": "0",
            "subtask_name": "",
            "gcode_file": "",
            "stg": [],
            "stg_cur": 0,
            "print_type": "idle",
            "home_flag": 846022032,
            "mc_print_line_number": "0",
            "mc_print_sub_stage": 0,
            "sdcard": True,
            "force_upgrade": False,
            "mess_production_state": "active",
            "layer_num": 0,
            "total_layer_num": 0,
            "s_obj": [],
            "filam_bak": [],
            "fan_gear": 0,
            "nozzle_diameter": "0.4",
            "nozzle_type": "stainless_steel",
            "cali_version": 0,
            "k": "0.0000",
            "flag3": 15,
            "hms": [],
            "online": {
                "ahb": False,
                "rfid": False,
                "version": 350321425
            },
            "ams": {
                "ams": [
                    {
                        "id": "0",
                        "humidity": "5",
                        "temp": "26.5",
                        "tray": [
                            {"id": "0"},
                            {
                                "id": "1",
                                "remain": 100,
                                "k": 0.04,
                                "n": 1,
                                "cali_idx": -1,
                                "tag_uid": "0000000000000000",
                                "tray_id_name": "",
                                "tray_info_idx": "GFG00",
                                "tray_type": "PLA",
                                "tray_sub_brands": "",
                                "tray_color": "FF5733FF",
                                "tray_weight": "0",
                                "tray_diameter": "0.00",
                                "tray_temp": "0",
                                "tray_time": "0",
                                "bed_temp_type": "0",
                                "bed_temp": "0",
                                "nozzle_temp_max": "230",
                                "nozzle_temp_min": "190",
                                "xcam_info": "000000000000000000000000",
                                "tray_uuid": "00000000000000000000000000000000",
                                "ctype": 0,
                                "cols": ["FF5733FF"]
                            },
                            {
                                "id": "2",
                                "remain": 100,
                                "k": 0.04,
                                "n": 1,
                                "cali_idx": -1,
                                "tag_uid": "0000000000000000",
                                "tray_id_name": "",
                                "tray_info_idx": "GFG00",
                                "tray_type": "PETG",
                                "tray_sub_brands": "",
                                "tray_color": "F7D959FF",
                                "tray_weight": "0",
                                "tray_diameter": "0.00",
                                "tray_temp": "0",
                                "tray_time": "0",
                                "bed_temp_type": "0",
                                "bed_temp": "0",
                                "nozzle_temp_max": "270",
                                "nozzle_temp_min": "230",
                                "xcam_info": "000000000000000000000000",
                                "tray_uuid": "00000000000000000000000000000000",
                                "ctype": 0,
                                "cols": ["F7D959FF"]
                            },
                            {
                                "id": "3",
                                "remain": 100,
                                "k": 0.04,
                                "n": 1,
                                "cali_idx": -1,
                                "tag_uid": "0000000000000000",
                                "tray_id_name": "",
                                "tray_info_idx": "GFG00",
                                "tray_type": "PETG",
                                "tray_sub_brands": "",
                                "tray_color": "FFFFFFFF",
                                "tray_weight": "0",
                                "tray_diameter": "0.00",
                                "tray_temp": "0",
                                "tray_time": "0",
                                "bed_temp_type": "0",
                                "bed_temp": "0",
                                "nozzle_temp_max": "270",
                                "nozzle_temp_min": "230",
                                "xcam_info": "000000000000000000000000",
                                "tray_uuid": "00000000000000000000000000000000",
                                "ctype": 0,
                                "cols": ["FFFFFFFF"]
                            }
                        ]
                    }
                ],
                "ams_exist_bits": "1",
                "tray_exist_bits": "e",
                "tray_is_bbl_bits": "e",
                "tray_tar": "255",
                "tray_now": "255",
                "tray_pre": "255",
                "tray_read_done_bits": "e",
                "tray_reading_bits": "0",
                "version": 2,
                "insert_flag": True,
                "power_on_flag": False
            },
            "vt_tray": {
                "id": "254",
                "tag_uid": "0000000000000000",
                "tray_id_name": "",
                "tray_info_idx": "GFG00",
                "tray_type": "PETG",
                "tray_sub_brands": "",
                "tray_color": "174B35FF",
                "tray_weight": "0",
                "tray_diameter": "0.00",
                "tray_temp": "0",
                "tray_time": "0",
                "bed_temp_type": "0",
                "bed_temp": "0",
                "nozzle_temp_max": "270",
                "nozzle_temp_min": "230",
                "xcam_info": "000000000000000000000000",
                "tray_uuid": "00000000000000000000000000000000",
                "remain": 0,
                "k": 0.04,
                "n": 1,
                "cali_idx": -1
            },
            "lights_report": [
                {"node": "chamber_light", "mode": "on"}
            ],
            "command": "push_status",
            "msg": 0,
            "sequence_id": "0"
        }

        # 设备信息 - get_version 响应
        self.info_state = {
            "info": {
                "command": "get_version",
                "sequence_id": "",
                "module": [
                    {
                        "name": "ota",
                        "project_name": PROJECT_NAME,
                        "sw_ver": "01.04.00.00",
                        "hw_Ver": "OTA",
                        "sn": SERIAL_NUMBER,
                        "flag": 0
                    },
                    {
                        "name": "esp32",
                        "project_name": PROJECT_NAME,
                        "sw_ver": "01.11.33.52",
                        "hw_ver": "AP07",
                        "sn": SERIAL_NUMBER,
                        "flag": 0
                    },
                    {
                        "name": "mc",
                        "project_name": PROJECT_NAME,
                        "sw_ver": "00.00.29.76",
                        "loader_ver": "00.00.00.32",
                        "hw_ver": "MC02",
                        "sn": "03E06A5C3027006",
                        "flag": 0
                    },
                    {
                        "name": "ams_f1/0",
                        "project_name": "",
                        "sw_ver": "01.00.00.00",
                        "loader_ver": "00.00.00.00",
                        "ota_ver": "00.00.00.00",
                        "hw_ver": "AMS_F102",
                        "sn": "STUDYONLY",
                        "flag": 0
                    }
                ],
                "result": "success",
                "reason": ""
            }
        }

        self.connected = False
        self.printing = False
        self.sequence_id = 0
        self.light_on = True

        # FTP 服务器
        self.ftp_server = None
        self.ftp_server_thread = None
        self.ftp_temp_dir = None

    def on_connect(self, client, userdata, flags, rc):
        print(f"[OK] 已连接到 broker {BROKER_HOST}:{BROKER_PORT}")
        self.connected = True
        topic = f"device/{SERIAL_NUMBER}/request"
        client.subscribe(topic)
        print(f"[OK] 已订阅: {topic}")

        # 连接时先发送 get_version
        self.publish_info()

        # 启动状态发布循环
        threading.Thread(target=self.publish_loop, daemon=True).start()

    def on_disconnect(self, client, userdata, rc):
        print(f"[DISCONNECTED] rc={rc}")
        self.connected = False

    def on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
            print(f"  <- 收到命令: {payload}")
            self.handle_command(payload)
        except Exception as e:
            print(f"[ERR] 解析命令失败: {e}")

    def handle_command(self, payload):
        if "print" in payload:
            cmd = payload["print"].get("command")
            if cmd == "stop":
                self.stop_print()
            elif cmd == "pause":
                self.pause_print()
            elif cmd == "resume":
                self.resume_print()
            elif cmd == "gcode_line":
                self.handle_gcode(payload["print"].get("param", ""))
            elif cmd == "print_speed":
                self.set_speed(int(payload["print"].get("param", 2)))
        if "system" in payload:
            if "led_mode" in payload["system"]:
                self.set_light(payload["system"]["led_mode"] == "on")
        if "pushing" in payload:
            if payload["pushing"].get("command") == "pushall":
                self.publish_full_state()
        if "info" in payload:
            if payload["info"].get("command") == "get_version":
                self.publish_info()

    def handle_gcode(self, gcode):
        gcode = gcode.strip()
        if gcode.startswith("M140"):
            temp = self._extract_temp(gcode)
            self.print_state["bed_target_temper"] = temp
            print(f"  -> 热床目标温度设置为 {temp}C")
        elif gcode.startswith("M104"):
            temp = self._extract_temp(gcode)
            self.print_state["nozzle_target_temper"] = temp
            print(f"  -> 喷嘴目标温度设置为 {temp}C")
        elif gcode.startswith("M106"):
            speed = self._extract_fan_speed(gcode)
            self.print_state["cooling_fan_speed"] = str(speed)
            print(f"  -> 风扇速度设置为 {speed}")
        elif gcode == "G28":
            print("  -> 自动归位")

    def _extract_temp(self, gcode):
        try:
            for part in gcode.split():
                if part.startswith("S"):
                    return float(part[1:])
        except Exception:
            pass
        return 25.0

    def _extract_fan_speed(self, gcode):
        try:
            for part in gcode.split():
                if part.startswith("S"):
                    return int(part[1:])
        except Exception:
            pass
        return 0

    def start_print(self):
        self.printing = True
        self.print_state["gcode_state"] = "RUNNING"
        self.print_state["mc_percent"] = 0
        self.print_state["print_type"] = "printing"
        print("[PRINT] 开始打印")
        self.publish_full_state()

    def stop_print(self):
        self.printing = False
        self.print_state["gcode_state"] = "IDLE"
        self.print_state["mc_percent"] = 0
        self.print_state["mc_remaining_time"] = 0
        self.print_state["print_type"] = "idle"
        print("[PRINT] 停止打印")
        self.publish_full_state()

    def pause_print(self):
        if self.printing:
            self.print_state["gcode_state"] = "PAUSE"
            print("[PRINT] 暂停打印")
            self.publish_full_state()

    def resume_print(self):
        if self.printing:
            self.print_state["gcode_state"] = "RUNNING"
            print("[PRINT] 恢复打印")
            self.publish_full_state()

    def set_light(self, on):
        self.light_on = on
        self.print_state["lights_report"] = [
            {"node": "chamber_light", "mode": "on" if on else "off"}
        ]
        print(f"[LIGHT] {'ON' if on else 'OFF'}")
        self.publish_full_state()

    def set_speed(self, level):
        self.print_state["spd_lvl"] = level
        speeds = {1: "静音", 2: "标准", 3: "运动", 4: "狂暴"}
        print(f"[SPEED] {speeds.get(level, '标准')}")
        self.publish_full_state()

    def publish_loop(self):
        """模拟真机消息：有时只发 wifi，有时发完整状态"""
        counter = 0
        while self.connected:
            try:
                counter += 1

                # 更新打印进度
                if self.printing:
                    percent = self.print_state["mc_percent"]
                    if percent < 100:
                        self.print_state["mc_percent"] = percent + 1
                        self.print_state["mc_remaining_time"] = max(
                            0, (100 - percent - 1) * 2
                        )
                        self.print_state["bed_temper"] = (
                            60.0 + random.uniform(-0.5, 0.5)
                        )
                        self.print_state["nozzle_temper"] = (
                            220.0 + random.uniform(-1, 1)
                        )

                # 模拟真机：每 5 次只发 wifi，其他发完整状态
                if counter % 5 == 0:
                    self.publish_wifi_only()
                else:
                    self.publish_full_state()

                time.sleep(2)
            except Exception as e:
                print(f"[ERR] 发布失败: {e}")
                time.sleep(1)

    def publish_wifi_only(self):
        """模拟真机 wifi_signal 更新消息（不含其他状态）"""
        self.sequence_id += 1
        wifi_signal = f"-{random.randint(40, 50)}dBm"

        payload = {
            "print": {
                "wifi_signal": wifi_signal,
                "command": "push_status",
                "msg": 1,
                "sequence_id": str(self.sequence_id)
            }
        }

        topic = f"device/{SERIAL_NUMBER}/report"
        self.client.publish(topic, json.dumps(payload))
        print(f"  -> wifi_only: {wifi_signal}")

    def publish_full_state(self):
        """发布完整 push_status 消息"""
        self.sequence_id += 1
        self.print_state["sequence_id"] = str(self.sequence_id)
        self.print_state["wifi_signal"] = f"-{random.randint(40, 50)}dBm"

        topic = f"device/{SERIAL_NUMBER}/report"
        payload = {"print": self.print_state}
        self.client.publish(topic, json.dumps(payload))
        print(f"  -> push_status: gcode_state={self.print_state['gcode_state']}, percent={self.print_state['mc_percent']}%")

    def publish_info(self):
        """发布 get_version 设备信息"""
        topic = f"device/{SERIAL_NUMBER}/report"
        self.client.publish(topic, json.dumps(self.info_state))
        print(f"  -> get_version: {PROJECT_NAME}")

    @staticmethod
    def _select_model() -> str:
        """启动时让用户选择模拟的打印机型号"""
        models = [
            ("N1",  "A1 Mini"),
            ("N2S", "A1"),
            ("N9",  "A2L"),
            ("C11", "P1P"),
            ("C12", "P1S"),
            ("3DPrinter-X1",         "X1"),
            ("3DPrinter-X1-Carbon",  "X1-Carbon"),
            ("C13", "X1E"),
        ]
        print("=" * 50)
        print("选择要模拟的打印机型号:")
        for i, (_, name) in enumerate(models, 1):
            print(f"  {i}. {name}")
        print("=" * 50)
        while True:
            try:
                choice = input(f"请输入编号 (1-{len(models)}, 默认 1): ").strip()
                if not choice:
                    idx = 0
                else:
                    idx = int(choice) - 1
                if 0 <= idx < len(models):
                    project_name, display = models[idx]
                    print(f"\n已选择: {display} ({project_name})\n")
                    return project_name
            except (ValueError, IndexError):
                pass
            print(f"无效输入，请输入 1-{len(models)}")

    # --- FTP 服务器 ---

    def _create_ftp_test_files(self, base_dir: str):
        """创建模拟打印机目录结构及测试文件"""
        dirs = {
            "cache": [],
            "image": [],
            "timelapse": [],
            "Metadata": [],
        }
        for d in dirs:
            os.makedirs(os.path.join(base_dir, d), exist_ok=True)

        # cache 目录 — 模拟打印文件
        cache_dir = os.path.join(base_dir, "cache")
        for fname in ["test_print.3mf", "benchy.gcode.3mf", "calibration.gcode"]:
            path = os.path.join(cache_dir, fname)
            with open(path, "w") as f:
                f.write(f"// 模拟文件: {fname}\n")
            dirs["cache"].append(path)

        # image 目录 — 模拟预览图（生成一个 1x1 PNG）
        img_dir = os.path.join(base_dir, "image")
        # 最小的有效 PNG 文件（1x1 像素红色）
        png_bytes = bytes([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
            0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x00, 0x00,
            0x00, 0x04, 0x00, 0x01, 0x27, 0x34, 0x27, 0x8C,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,  # IEND chunk
            0xAE, 0x42, 0x60, 0x82,
        ])
        for fname in ["preview_1.png", "preview_2.png", "thumbs.png"]:
            path = os.path.join(img_dir, fname)
            with open(path, "wb") as f:
                f.write(png_bytes)

        # timelapse 目录 — 模拟延时摄影文件
        tl_dir = os.path.join(base_dir, "timelapse")
        for fname in ["print_1.mp4", "print_2.mp4"]:
            path = os.path.join(tl_dir, fname)
            with open(path, "w") as f:
                f.write(f"// 模拟延时摄影: {fname}\n")

        # Metadata 目录 — 模拟打印配置
        meta_dir = os.path.join(base_dir, "Metadata")
        for fname in ["plate_1.gcode", "plate_1.png", "slice_info.config"]:
            path = os.path.join(meta_dir, fname)
            with open(path, "w") as f:
                f.write("// 模拟元数据\n")

        return dirs

    @staticmethod
    def _generate_self_signed_cert(cert_path: str, key_path: str):
        """生成自签名 SSL 证书（用 cryptography 库）"""
        if not HAS_CRYPTO:
            return False

        key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend(),
        )

        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COUNTRY_NAME, "CN"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Bambu Simulator"),
            x509.NameAttribute(NameOID.COMMON_NAME, LAN_IP),
        ])

        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.datetime.now(datetime.timezone.utc))
            .not_valid_after(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365))
            .add_extension(
                x509.SubjectAlternativeName([
                    x509.IPAddress(ipaddress.ip_address(LAN_IP)),
                    x509.DNSName("localhost"),
                ]),
                critical=False,
            )
            .sign(key, hashes.SHA256(), backend=default_backend())
        )

        with open(key_path, "wb") as f:
            f.write(key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption(),
            ))
        with open(cert_path, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))

        return True

    def start_ftp_server(self):
        """启动 FTP 服务器供 App 测试。
        
        优先使用 TLS（端口 9991），如果 cryptography 不可用则回退到明文（端口 9990）。
        App 测试时需将 PrinterFtpService 的 port 改为对应端口。
        """
        if not HAS_FTP:
            print("[FTP] pyftpdlib 未安装，跳过 FTP 服务器启动")
            return

        if self.ftp_server is not None:
            return

        # 创建临时目录并填充测试文件
        self.ftp_temp_dir = tempfile.mkdtemp(prefix="bambu_sim_ftp_")
        self._create_ftp_test_files(self.ftp_temp_dir)

        # 配置用户认证
        authorizer = DummyAuthorizer()
        authorizer.add_anonymous(self.ftp_temp_dir, perm="elr")
        authorizer.add_user("bblp", "12345678", self.ftp_temp_dir, perm="elrafw")

        # 尝试 TLS 模式（匹配真实打印机的隐式 FTPS）
        use_tls = HAS_CRYPTO
        if use_tls:
            cert_path = os.path.join(self.ftp_temp_dir, "server.crt")
            key_path = os.path.join(self.ftp_temp_dir, "server.key")
            if not self._generate_self_signed_cert(cert_path, key_path):
                use_tls = False

        if use_tls:
            FTP_PORT = 9991
            handler = TLS_FTPHandler
            handler.certfile = cert_path
            handler.keyfile = key_path
            # 隐式 FTPS：连接即 TLS，不需要 AUTH TLS 命令
            handler.tls_control_required = True
            handler.tls_data_required = True
            sec_type = "ftps"
        else:
            FTP_PORT = 9990
            handler = FTPHandler
            sec_type = "plain"

        handler.authorizer = authorizer

        # 绑定 0.0.0.0：局域网内的手机也能访问（不再只服务本机）
        self.ftp_server = FTPServer(("0.0.0.0", FTP_PORT), handler)

        self.ftp_server_thread = threading.Thread(
            target=self.ftp_server.serve_forever,
            daemon=True,
            name="FTPServer",
        )
        self.ftp_server_thread.start()

        if use_tls:
            print(f"[FTP] TLS 服务器已启动: ftps://{LAN_IP}:{FTP_PORT}/")
            print(f"[FTP]   用户: bblp / 密码: 12345678")
            print(f"[FTP]   修改 PrinterFtpService: port = {FTP_PORT}, SecurityType.ftps")
        else:
            print(f"[FTP] 明文服务器已启动: ftp://{LAN_IP}:{FTP_PORT}/")
            print(f"[FTP]   用户: bblp / 密码: 12345678")
            print(f"[FTP]   修改 PrinterFtpService: port = {FTP_PORT}, SecurityType.ftp")

    def stop_ftp_server(self):
        """停止 FTP 服务器并清理临时文件"""
        if self.ftp_server is not None:
            print("[FTP] 服务器正在停止...")
            self.ftp_server.close_all()
            self.ftp_server = None
            self.ftp_server_thread = None

        if self.ftp_temp_dir is not None:
            shutil.rmtree(self.ftp_temp_dir, ignore_errors=True)
            self.ftp_temp_dir = None

    def run(self):
        global PROJECT_NAME
        PROJECT_NAME = self._select_model()

        # 根据型号更新设备信息中的 project_name
        for mod in self.info_state["info"]["module"]:
            if mod.get("name") in ("ota", "esp32", "mc"):
                mod["project_name"] = PROJECT_NAME

        # 根据机型调整初始温度：开放机型无 chamber_temp
        is_enclosed = PROJECT_NAME in ("3DPrinter-X1", "3DPrinter-X1-Carbon", "C13", "C12")
        if not is_enclosed:
            self.print_state.pop("chamber_temper", None)

        print("=" * 50)
        print("Bambu Lab 打印机模拟器")
        print("=" * 50)
        print(f"序列号: {SERIAL_NUMBER}")
        print(f"设备型号: {PROJECT_NAME}")
        print(f"本机局域网 IP: {LAN_IP}")
        print(f"Broker: {BROKER_HOST}:{BROKER_PORT}")
        print()
        print("在 App 中添加打印机（手机与电脑需在同一局域网）:")
        print(f"  IP:     {LAN_IP}")
        print(f"  序列号: {SERIAL_NUMBER}")
        print(f"  访问码: (任意)")
        print(f"  TLS:    关闭 (端口 1883)")
        print(f"  FTP:   端口 9991 (TLS) / 9990 (明文), 用户 bblp / 密码 12345678")
        print()
        print("注意: 本机 mosquitto 需监听 0.0.0.0 才能被手机访问")
        print("      (修改 mosquitto.conf: listener 1883 0.0.0.0)")
        print()
        print("命令: start / stop / pause / resume / light / ftp / quit")
        print("=" * 50)

        # 启动 FTP 服务器
        self.start_ftp_server()

        self.client.connect(BROKER_HOST, BROKER_PORT, 60)
        self.client.loop_start()

        try:
            while True:
                cmd = input().strip().lower()
                if cmd == "start":
                    self.start_print()
                elif cmd == "stop":
                    self.stop_print()
                elif cmd == "pause":
                    self.pause_print()
                elif cmd == "resume":
                    self.resume_print()
                elif cmd == "light":
                    self.set_light(not self.light_on)
                elif cmd == "ftp":
                    if HAS_FTP and self.ftp_server:
                        print(f"[FTP] 运行中: ftp://{LAN_IP}:9990/")
                        print(f"[FTP]   用户: bblp / 密码: 12345678")
                    else:
                        print("[FTP] 未启动（需要 pyftpdlib）")
                elif cmd in ("quit", "exit"):
                    break
        except KeyboardInterrupt:
            pass

        self.stop_ftp_server()
        self.client.loop_stop()
        self.client.disconnect()
        print("\n模拟器已停止")


if __name__ == "__main__":
    sim = PrinterSimulator()
    sim.run()