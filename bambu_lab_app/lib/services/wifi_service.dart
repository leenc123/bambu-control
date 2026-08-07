/// WiFi 服务 — 通过 NetworkManager 命令行 nmcli 管理无线网络
///
/// Linux (GTK) 下 Flutter 无现成 WiFi 插件（wifi_iot 等仅 Android/iOS），
/// Mobian/Phosh 默认 NetworkManager，直接调用 nmcli。
/// 连接不需要 root（桌面用户有 polkit 权限）。
library;

import 'dart:convert';
import 'dart:io';

/// 扫描结果中的单个网络
class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.security,
    required this.signal,
    required this.connected,
  });

  /// 网络名（隐藏网络为空，扫描时过滤）
  final String ssid;

  /// 加密方式：空 = 开放网络；WPA2 / WPA3 / WEP 等
  final String security;

  /// 信号强度 0-100
  final int signal;

  /// 是否当前已连接
  final bool connected;

  bool get isOpen => security.isEmpty;
}

/// 无线网络查询与连接（nmcli 封装，全部静态方法）
class WifiService {
  WifiService._();

  /// nmcli 是否可用（未安装 NetworkManager 时返回 false）
  static Future<bool> isAvailable() async {
    try {
      final res = await Process.run('nmcli', ['--version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 当前连接的 SSID；未连接返回 null
  static Future<String?> currentSsid() async {
    try {
      final res = await Process.run('nmcli', [
        '-t', '-f', 'active,ssid', 'dev', 'wifi',
      ], stdoutEncoding: utf8);
      if (res.exitCode != 0) return null;
      final lines = (res.stdout as String).split('\n');
      for (final line in lines) {
        final fields = _splitEscaped(line);
        if (fields.isNotEmpty && fields[0] == 'yes' && fields.length >= 2) {
          return fields[1];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 扫描 WiFi 列表；同 SSID 多个 BSSID 聚合取最强信号，已连接排最前。
  /// 失败返回空列表。
  static Future<List<WifiNetwork>> scan() async {
    final connected = await currentSsid();
    try {
      final res = await Process.run('nmcli', [
        '-t', '-f', 'SSID,SECURITY,SIGNAL,BSSID', 'dev', 'wifi',
        'list', '--rescan', 'yes',
      ], stdoutEncoding: utf8, stderrEncoding: utf8);
      if (res.exitCode != 0) return [];
      final lines = (res.stdout as String).split('\n');
      final bySsid = <String, WifiNetwork>{};
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final fields = _splitEscaped(line);
        if (fields.length < 4) continue;
        final ssid = fields[0];
        if (ssid.isEmpty) continue; // 隐藏网络不显示
        final security = fields[1];
        final signal = int.tryParse(fields[2]) ?? 0;
        final existing = bySsid[ssid];
        if (existing == null || signal > existing.signal) {
          bySsid[ssid] = WifiNetwork(
            ssid: ssid,
            security: security,
            signal: signal,
            connected: ssid == connected,
          );
        }
      }
      final list = bySsid.values.toList()
        ..sort((a, b) {
          if (a.connected != b.connected) return a.connected ? -1 : 1;
          return b.signal.compareTo(a.signal);
        });
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 连接 WiFi；成功返回 null，失败返回可读错误信息。
  ///
  /// [password] 为 null 或空时按开放网络处理。
  static Future<String?> connect(String ssid, {String? password}) async {
    try {
      final args = ['dev', 'wifi', 'connect', ssid];
      if (password != null && password.isNotEmpty) {
        args.addAll(['password', password]);
      }
      final res = await Process.run(
        'nmcli', args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) return null;
      final err = (res.stderr as String).trim();
      final out = (res.stdout as String).trim();
      return _friendlyError(err.isNotEmpty ? err : out);
    } catch (e) {
      return '执行 nmcli 失败: $e';
    }
  }

  /// 把 nmcli 原始报错转成用户可读信息
  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('password') ||
        lower.contains('psk') ||
        lower.contains('secret') ||
        lower.contains('incorrect')) {
      return '密码错误或网络拒绝连接，请检查密码';
    }
    if (lower.contains('not found') ||
        lower.contains('no network') ||
        lower.contains('no longer')) {
      return '未找到该网络，请重新扫描';
    }
    if (lower.contains('already')) {
      return '已连接到该网络';
    }
    return raw;
  }

  /// 按 : 分割 nmcli -t 行；SSID 中的冒号被转义为 \:，一并还原
  static List<String> _splitEscaped(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == r'\' && i + 1 < line.length) {
        buf.write(line[i + 1]);
        i++;
      } else if (ch == ':') {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }
}
