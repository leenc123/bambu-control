/// 拓竹打印机摄像头抓帧（6000 端口 TLS 原始协议，Dart 移植版）
///
/// 协议（A1 Mini / A1 / A2L / P1P / P1S — 对应 ha-bambulab 的 CAMERA_IMAGE 机型）：
///   1. TCP 连接打印机 6000 端口
///   2. TLS 握手（自签名证书，跳过校验）
///   3. 发送 96 字节认证包：0x40 + 0x3000 + 0 + 0 + username(32) + access_code(32)
///   4. 读 16 字节头（前 4 字节 = JPEG 载荷长度，小端）
///   5. 读载荷，校验 JPEG 头尾（FF D8 ... FF D9）
///
/// 与旧版（每帧新建 TLS 连接）的差异——对齐 ha-bambulab 的
/// ChamberImageThread：连接后保持常驻，持续接收帧流（打印机约每
/// 1-2 秒推一帧），新帧到达即更新 [latestFrame] 并通知 [frameStream]，
/// 避免每帧重连的开销与延迟。断线自动退避重连；访问码错误
/// （连接后立即被拒）不会无限重连，见 [authRejected]。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class BambuCameraException implements Exception {
  BambuCameraException(this.message);
  final String message;
  @override
  String toString() => 'BambuCameraException: $message';
}

class BambuCamera {
  BambuCamera({
    required this.host,
    required this.accessCode,
    this.port = 6000,
    this.timeout = const Duration(seconds: 10),
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 12,
  });

  final String host;
  final String accessCode;
  final int port;
  final Duration timeout;

  /// 断线后的重连间隔
  final Duration reconnectDelay;

  /// 连续重连失败上限（对齐 ha-bambulab 的 12 次），超过后停止重连
  final int maxReconnectAttempts;

  SecureSocket? _socket;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _reconnectTimer;

  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();

  Uint8List? _latestFrame;
  String? _lastError;
  bool _started = false;
  bool _stopping = false;
  bool _authRejected = false;
  int _reconnectAttempts = 0;

  /// 是否已启动长连接
  bool get isStarted => _started;

  /// 访问码是否被打印机拒绝（拒绝后不会自动重连）
  bool get authRejected => _authRejected;

  /// 最近的错误信息（连接失败/访问码错误等）
  String? get lastError => _lastError;

  /// 最新一帧 JPEG；未收到过帧时为 null
  Uint8List? get latestFrame => _latestFrame;

  /// 新帧通知流（每收到一帧 JPEG 触发一次）
  Stream<Uint8List> get frameStream => _frameController.stream;

  /// 错误通知流（连接失败、访问码错误等）
  Stream<Object> get errorStream => _errorController.stream;

  /// 启动常驻连接并持续收帧（幂等）。
  ///
  /// 初始连接失败会抛 [BambuCameraException]，但内部仍会按
  /// [reconnectDelay] 退避重连，恢复后继续推帧；访问码错误除外
  /// （见 [authRejected]，不会重连）。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _stopping = false;
    _authRejected = false;
    _reconnectAttempts = 0;
    await _connect();
  }

  /// 停止长连接（幂等）。
  Future<void> stop() async {
    _stopping = true;
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    _socket?.destroy();
    _socket = null;
  }

  /// 释放资源（页面销毁时调用）。
  void dispose() {
    unawaited(stop());
    _frameController.close();
    _errorController.close();
  }

  /// 抓取一帧 JPEG；失败抛 [BambuCameraException]。
  ///
  /// 兼容旧的一次性 API：内部确保长连接已启动，等待【下一帧】
  /// 到达（打印机约 1-2 秒一帧），超时或出错则抛异常。
  Future<Uint8List> captureFrame({Duration? waitTimeout}) async {
    if (_authRejected) {
      throw BambuCameraException('连接被打印机拒绝（请检查访问码）');
    }
    if (!_started) {
      await start();
    }

    final completer = Completer<Uint8List>();
    late final StreamSubscription<Uint8List> frameSub;
    late final StreamSubscription<Object> errSub;
    final timer = Timer(waitTimeout ?? timeout, () {
      frameSub.cancel();
      errSub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          BambuCameraException('等待摄像头帧超时 ($host:$port)'),
        );
      }
    });
    frameSub = frameStream.listen((frame) {
      timer.cancel();
      frameSub.cancel();
      errSub.cancel();
      if (!completer.isCompleted) completer.complete(frame);
    });
    errSub = errorStream.listen((e) {
      timer.cancel();
      frameSub.cancel();
      errSub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          e is BambuCameraException ? e : BambuCameraException('$e'),
        );
      }
    });
    return completer.future;
  }

  // --- 连接与读帧 ---

  Future<void> _connect() async {
    if (_stopping) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: timeout,
        onBadCertificate: (_) => true, // 打印机自签名证书，跳过校验
      );
      if (_stopping) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _reconnectAttempts = 0;
      _lastError = null;
      socket.add(_buildAuthPacket());
      await socket.flush();
      _startReading(socket);
    } catch (e) {
      if (_stopping) return;
      _lastError = '摄像头连接失败 ($host:$port): $e';
      _errorController.add(BambuCameraException(_lastError!));
      _scheduleReconnect();
      throw BambuCameraException(_lastError!);
    }
  }

  /// 读帧状态机：16 字节头 → JPEG 载荷 → 循环。
  ///
  /// 使用单缓冲 + 消费游标，兼容任意分块到达（TCP 无消息边界），
  /// 载荷之后的剩余字节自动归属下一帧头。
  void _startReading(SecureSocket socket) {
    final buf = <int>[];
    var readPos = 0;
    int? payloadSize;
    var gotAnyData = false;

    void handlePayload(Uint8List payload) {
      // JPEG 头尾校验
      if (payload.length < 4 ||
          payload[0] != 0xff ||
          payload[1] != 0xd8 ||
          payload[payload.length - 2] != 0xff ||
          payload[payload.length - 1] != 0xd9) {
        _lastError = '收到非 JPEG 数据（${payload.length} 字节）';
        _errorController.add(BambuCameraException(_lastError!));
        return;
      }
      _latestFrame = payload;
      if (!_frameController.isClosed) _frameController.add(payload);
    }

    _socketSub = socket.listen(
      (chunk) {
        gotAnyData = true;
        buf.addAll(chunk);
        while (true) {
          if (payloadSize == null) {
            // 等满 16 字节头
            if (buf.length - readPos < 16) return;
            payloadSize = _readU32le(buf, readPos);
            readPos += 16;
            if (payloadSize! < 2 || payloadSize! > 500000) {
              _lastError = '非法载荷长度: $payloadSize';
              _errorController.add(BambuCameraException(_lastError!));
              _fail(socket, reconnect: true);
              return;
            }
          } else {
            // 等满载荷
            final avail = buf.length - readPos;
            if (avail < payloadSize!) return;
            final payload =
                Uint8List.fromList(buf.sublist(readPos, readPos + payloadSize!));
            readPos += payloadSize!;
            payloadSize = null;
            handlePayload(payload);
          }
          // 缓冲已全部消费则清空，避免无界增长
          if (readPos > 0 && readPos == buf.length) {
            buf.clear();
            readPos = 0;
          }
        }
      },
      onDone: () {
        if (!_stopping && _started && !gotAnyData) {
          // 连接建立后未收到任何数据即断开 → 访问码错误/被拒
          _authRejected = true;
          _started = false;
          _lastError = '连接被打印机拒绝（请检查访问码）';
          _errorController.add(BambuCameraException(_lastError!));
        } else {
          _handleDisconnect();
        }
      },
      onError: (Object e) {
        _lastError = '摄像头连接异常: $e';
        _errorController.add(BambuCameraException(_lastError!));
        _handleDisconnect();
      },
    );
  }

  void _fail(SecureSocket socket, {required bool reconnect}) {
    socket.destroy();
    _socket = null;
    _socketSub = null;
    if (reconnect) _scheduleReconnect();
  }

  void _handleDisconnect() {
    _socket = null;
    _socketSub = null;
    if (!_started || _stopping) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_stopping || !_started || _authRejected) return;
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _started = false;
      _lastError = '重连失败 $maxReconnectAttempts 次，已停止';
      _errorController.add(BambuCameraException(_lastError!));
      return;
    }
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () async {
      if (_stopping || !_started) return;
      try {
        await _connect();
      } catch (_) {
        // _connect 内部已再次安排重连
      }
    });
  }

  static int _readU32le(List<int> b, int off) =>
      b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24);

  // --- 认证包 ---

  /// 构建 96 字节认证包。
  Uint8List _buildAuthPacket() {
    final buf = BytesBuilder();
    void u32le(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      buf.add(b.buffer.asUint8List());
    }

    u32le(0x40);
    u32le(0x3000);
    u32le(0);
    u32le(0);
    buf.add(_pad32('bblp'.codeUnits));
    buf.add(_pad32(accessCode.codeUnits));
    return buf.takeBytes();
  }

  /// 填充到 32 字节（不足补 0）。
  List<int> _pad32(List<int> data) {
    final out = List<int>.filled(32, 0);
    for (var i = 0; i < data.length && i < 32; i++) {
      out[i] = data[i];
    }
    return out;
  }
}
