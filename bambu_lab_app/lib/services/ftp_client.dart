/// 轻量 Implicit FTPS 客户端（适配 Bambu Lab 打印机）
///
/// 修复 ftpconnect 库的关键问题：
/// 1. 按行读取响应（\r\n 分割），不会把多条响应拼在一起
/// 2. 数据通道用 TLS 加密（复用 SecurityContext）
/// 3. 正确解析多行响应和 PASV 地址
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/* ------------------------------------------------------------------ */
/*  异常定义                                                          */
/* ------------------------------------------------------------------ */

class FtpException implements Exception {
  final String message;
  final int? code;
  FtpException(this.message, [this.code]);
  @override
  String toString() => 'FTP[$code] $message';
}

/* ------------------------------------------------------------------ */
/*  FTP 回复                                                          */
/* ------------------------------------------------------------------ */

class FtpReply {
  final int code;
  final String message;
  FtpReply(this.code, this.message);
  bool get isSuccess => code >= 200 && code < 300;
  @override
  String toString() => 'FtpReply($code) $message';
}

/* ------------------------------------------------------------------ */
/*  FTP 目录条目                                                      */
/* ------------------------------------------------------------------ */

class FtpEntry {
  final String name;
  final bool isDir;
  final int? size;
  final DateTime? modifyTime;

  FtpEntry({
    required this.name,
    this.isDir = false,
    this.size,
    this.modifyTime,
  });
}

/* ------------------------------------------------------------------ */
/*  行读取器 — 从 RawSecureSocket 流中按 \r\n 分割出文本行            */
/* ------------------------------------------------------------------ */

class _LineReader {
  final RawSecureSocket _socket;
  final List<int> _buffer = [];
  final List<Completer<String>> _pending = [];
  StreamSubscription<RawSocketEvent>? _sub;
  bool _done = false;

  _LineReader(this._socket) {
    // RawSocket 的 stream 事件只是「有数据可读」的信号
    // 实际数据通过 read() 拉取
    _sub = _socket.listen(
      (_) {
        while (_socket.available() > 0) {
          final chunk = _socket.read();
          if (chunk != null) _buffer.addAll(chunk);
        }
        _flush();
      },
      onDone: () {
        _done = true;
        _flush();
      },
      onError: (e) {
        for (final p in _pending) {
          if (!p.isCompleted) p.completeError(e);
        }
        _pending.clear();
      },
    );
  }

  void _flush() {
    while (_pending.isNotEmpty && _buffer.isNotEmpty) {
      int end = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0x0D && _buffer[i + 1] == 0x0A) {
          end = i;
          break;
        }
      }
      if (end < 0) break; // 还不完整

      final line = utf8.decode(_buffer.sublist(0, end));
      _buffer.removeRange(0, end + 2);
      _pending.removeAt(0).complete(line);
    }

    // Socket 已关闭且 buffer 读完 → 给剩余的 pending 发空行
    if (_done && _pending.isNotEmpty && _buffer.isEmpty) {
      for (final p in _pending) {
        if (!p.isCompleted) p.complete('');
      }
      _pending.clear();
    }
  }

  Future<String> readLine() {
    final c = Completer<String>();
    _pending.add(c);
    _flush();
    return c.future;
  }

  void dispose() {
    _sub?.cancel();
    for (final p in _pending) {
      if (!p.isCompleted) p.complete('');
    }
    _pending.clear();
  }
}

/* ------------------------------------------------------------------ */
/*  ImplicitFTPSClient                                                */
/* ------------------------------------------------------------------ */

class ImplicitFTPSClient {
  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final Duration _timeout;
  final bool _allowSelfSigned;

  RawSecureSocket? _controlSocket;
  _LineReader? _reader;
  SecurityContext? _context;
  bool _connected = false;

  ImplicitFTPSClient({
    required String host,
    int port = 990,
    required String user,
    required String password,
    Duration timeout = const Duration(seconds: 30),
    bool allowSelfSigned = true,
  })  : _host = host,
        _port = port,
        _user = user,
        _password = password,
        _timeout = timeout,
        _allowSelfSigned = allowSelfSigned;

  bool get isConnected => _connected;

  /// 连接并登录
  /// 流程：TLS 握手 → 220 问候 → USER → PASS → PBSZ 0 → PROT P
  Future<void> connect() async {
    _context = SecurityContext.defaultContext;

    _controlSocket = await RawSecureSocket.connect(
      _host,
      _port,
      timeout: _timeout,
      context: _context,
      onBadCertificate: _allowSelfSigned ? (_) => true : null,
    );

    _reader = _LineReader(_controlSocket!);

    // 问候
    await _expectCode(220);

    // USER
    await _send('USER $_user');
    final userResp = await _readResponse();

    if (userResp.code == 331) {
      await _send('PASS $_password');
      final passResp = await _readResponse();
      if (!passResp.isSuccess) {
        throw FtpException(
            '登录失败: ${passResp.code} ${passResp.message}', passResp.code);
      }
    } else if (userResp.code == 230) {
      // 已登录
    } else {
      throw FtpException(
          'USER 返回异常: ${userResp.code} ${userResp.message}', userResp.code);
    }

    // PBSZ + PROT P — 数据通道加密
    await _send('PBSZ 0');
    await _expectSuccess();
    await _send('PROT P');
    await _expectSuccess();

    _connected = true;
  }

  /// CWD — 切换目录
  Future<void> cwd(String path) async {
    await _send('CWD $path');
    await _expectSuccess();
  }

  /// PWD — 获取当前目录
  Future<String> pwd() async {
    await _send('PWD');
    final resp = await _readResponse();
    if (!resp.isSuccess) {
      throw FtpException('PWD 失败: ${resp.message}', resp.code);
    }
    final m = RegExp(r'"(.+)"').firstMatch(resp.message);
    return m?.group(1) ?? resp.message;
  }

  /// 向控制通道发送命令
  Future<void> _send(String cmd) async {
    final encoded = utf8.encode('$cmd\r\n');
    _controlSocket!.write(encoded);
  }

  /// 读取 FTP 多行响应
  Future<FtpReply> _readResponse() async {
    final first = await _reader!.readLine();
    final lines = <String>[first];

    if (first.length >= 4 && first[3] == '-') {
      final code = first.substring(0, 3);
      while (true) {
        final line = await _reader!.readLine();
        lines.add(line);
        if (line.length >= 4 &&
            line.startsWith(code) &&
            line[3] == ' ') {
          break;
        }
      }
    }

    final code = int.parse(first.substring(0, 3));
    return FtpReply(code, lines.join('\n'));
  }

  /// 期待特定响应码
  Future<FtpReply> _expectCode(int expected) async {
    final resp = await _readResponse();
    if (resp.code != expected) {
      throw FtpException('期望 $expected，收到 ${resp.code}: ${resp.message}',
          resp.code);
    }
    return resp;
  }

  /// 期待成功（2xx）
  Future<FtpReply> _expectSuccess() async {
    final resp = await _readResponse();
    if (!resp.isSuccess) {
      throw FtpException('命令失败: ${resp.code} ${resp.message}', resp.code);
    }
    return resp;
  }

  /* ---------- 数据通道 ---------- */

  /// 打开数据通道：PASV → 连 TCP → 升级 TLS
  Future<RawSecureSocket> _openDataChannel() async {
    await _send('PASV');
    final resp = await _expectSuccess();

    // 解析 (ip1,ip2,ip3,ip4,p1,p2)
    final m = RegExp(r'(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)')
        .firstMatch(resp.message);
    if (m == null) {
      throw FtpException('无法解析 PASV 响应: ${resp.message}');
    }

    final dataHost = '${m[1]}.${m[2]}.${m[3]}.${m[4]}';
    final dataPort = int.parse(m[5]!) * 256 + int.parse(m[6]!);

    // 先建明文 TCP，再升级为 TLS
    final plain = await RawSocket.connect(dataHost, dataPort,
        timeout: _timeout);
    final secure = await RawSecureSocket.secure(
      plain,
      context: _context,
      onBadCertificate: _allowSelfSigned ? (_) => true : null,
    );
    return secure;
  }

  /// 从数据通道读取全部字节（用于下载文件）
  Future<Uint8List> _readAllFromDataChannel(RawSecureSocket channel) async {
    final bytes = <int>[];
    final completer = Completer<void>();
    final sub = channel.listen(
      (_) {
        while (channel.available() > 0) {
          final chunk = channel.read();
          if (chunk != null) bytes.addAll(chunk);
        }
      },
      onDone: () => completer.complete(),
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );
    await completer.future;
    await sub.cancel();
    return Uint8List.fromList(bytes);
  }

  /// 从数据通道读取文本行（用于 MLSd/LIST）
  Future<List<String>> _readLinesFromDataChannel(
      RawSecureSocket channel) async {
    final lines = <String>[];
    final completer = Completer<void>();
    final sub = channel.listen(
      (_) {
        while (channel.available() > 0) {
          final chunk = channel.read();
          if (chunk == null) continue;
          int start = 0;
          for (int i = 0; i < chunk.length; i++) {
            if (chunk[i] == 0x0A) {
              final end = (i > 0 && chunk[i - 1] == 0x0D) ? i - 1 : i;
              lines.add(utf8.decode(chunk.sublist(start, end)));
              start = i + 1;
            }
          }
        }
      },
      onDone: () => completer.complete(),
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );
    await completer.future;
    await sub.cancel();
    return lines;
  }

  /* ---------- 业务方法 ---------- */

  /// SIZE — 获取文件大小
  Future<int> size(String path) async {
    await _send('SIZE $path');
    final resp = await _readResponse();
    if (!resp.isSuccess) {
      throw FtpException('SIZE 失败: ${resp.message}', resp.code);
    }
    return int.tryParse(resp.message.split(' ').first) ?? 0;
  }

  /// 下载文件到字节数组
  Future<Uint8List> downloadBytes(String remotePath) async {
    final dataChannel = await _openDataChannel();

    await _send('RETR $remotePath');
    final resp = await _readResponse();
    if (!resp.isSuccess) {
      await dataChannel.close();
      throw FtpException('RETR 失败: ${resp.message}', resp.code);
    }

    final data = await _readAllFromDataChannel(dataChannel);
    await dataChannel.close();

    await _readResponse(); // 传输完成 226
    return data;
  }

  /// 下载文件到本地文件
  Future<void> downloadFile(String remotePath, File localFile) async {
    final data = await downloadBytes(remotePath);
    await localFile.writeAsBytes(data);
  }

  /// 列出目录内容（优先 MLSD，回退 LIST）
  Future<List<FtpEntry>> list([String path = '']) async {
    if (path.isNotEmpty) {
      await cwd(path);
    }

    final dataChannel = await _openDataChannel();

    await _send('MLSD');
    var resp = await _readResponse();
    List<String> lines;

    if (!resp.isSuccess) {
      // MLSD 不支持 → 回退 LIST
      await dataChannel.close();
      final ch2 = await _openDataChannel();
      await _send('LIST');
      resp = await _readResponse();
      if (!resp.isSuccess) {
        await ch2.close();
        throw FtpException('LIST 失败: ${resp.message}', resp.code);
      }
      lines = await _readLinesFromDataChannel(ch2);
      await ch2.close();
    } else {
      lines = await _readLinesFromDataChannel(dataChannel);
      await dataChannel.close();
    }

    await _readResponse(); // 传输完成

    return _parseLines(lines, resp.code != 200 ? 'list' : 'mlsd');
  }

  List<FtpEntry> _parseLines(List<String> lines, String format) {
    if (format == 'mlsd') {
      return lines
          .where((l) => l.trim().isNotEmpty)
          .map((l) {
            final parts = l.split(';');
            String name = '';
            bool isDir = false;
            int? size;
            DateTime? modify;

            for (final part in parts) {
              final eq = part.indexOf('=');
              if (eq < 0) {
                name = part.trim();
                continue;
              }
              final key = part.substring(0, eq).trim().toLowerCase();
              final value = part.substring(eq + 1).trim();
              switch (key) {
                case 'type':
                  isDir = value == 'dir';
                case 'size':
                  size = int.tryParse(value);
                case 'modify':
                  modify = DateTime.tryParse(value);
                  if (modify == null && value.contains(' ')) {
                    modify = DateTime.tryParse(value.replaceFirst(' ', 'T'));
                  }
                case 'name':
                  name = value;
              }
            }
            if (name.isEmpty) return null;
            return FtpEntry(
                name: name, isDir: isDir, size: size, modifyTime: modify);
          })
          .whereType<FtpEntry>()
          .toList();
    } else {
      // LIST 格式（Unix ls -l 风格）
      // -rw-r--r-- 1 1000 1000 12345 Jan 01 12:34 filename
      return lines
          .where((l) => l.trim().isNotEmpty && !l.startsWith('total'))
          .map((l) {
            // 跳过权限位等固定头部，直接取最后一段为文件名
            final trimmed = l.trim();
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.length < 9) return null;
            final isDir = trimmed.startsWith('d');
            final size = int.tryParse(parts[4]) ?? 0;
            // 文件名从第 8 个字段开始（包含可能的空格）
            final nameStart =
                trimmed.indexOf(parts[8], trimmed.indexOf(parts[7]));
            final name = trimmed.substring(nameStart);
            return FtpEntry(name: name, isDir: isDir, size: size);
          })
          .whereType<FtpEntry>()
          .toList();
    }
  }

  /// 删除文件
  Future<void> delete(String path) async {
    final name = path.split('/').last;
    await _send('DELE $name');
    await _expectSuccess();
  }

  /// 退出
  Future<void> quit() async {
    try {
      await _send('QUIT');
      await _readResponse();
    } catch (_) {}
    await _controlSocket?.close();
    _reader?.dispose();
    _connected = false;
  }

  /// 断开（不发送 QUIT）
  Future<void> disconnect() async {
    _reader?.dispose();
    await _controlSocket?.close();
    _connected = false;
  }
}
