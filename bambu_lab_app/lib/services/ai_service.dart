/// AI 推理服务客户端（YOLO 检测）
///
/// 服务地址可用 --dart-define=AI_SERVICE_URL=... 覆盖
/// （默认本机 kiosk 上的推理服务，端口 19530）。
///
/// 端点（对齐 Python 插件 inference_server/server.py）：
/// - GET  /health    健康检查
/// - POST /analyze   推理 → JSON（anomaly_detected / anomaly_type / confidence / description）
/// - POST /visualize 推理 + 画框 → 标注 JPEG
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const String kAiServiceUrl = String.fromEnvironment(
  'AI_SERVICE_URL',
  defaultValue: 'http://127.0.0.1:19530',
);

/// 模糊检测阈值（Laplacian 方差），对齐 Python snapshot.py BLUR_THRESHOLD=100
const double kBlurThreshold = 100;

/// 异常类型 → 中文标签（模型为单类别 spaghetti）
const Map<String, String> kAnomalyTypeLabels = {
  'spaghetti': '炒面',
  'none': '无异常',
  'other': '其他异常',
};

/// GET /health，返回 (可用?, 模型已加载?, 详情)。
///
/// 可用 = HTTP 200 且 body.status == "ok"。
Future<(bool, bool, String)> probeAiService({
  Duration connectTimeout = const Duration(seconds: 2),
  Duration responseTimeout = const Duration(seconds: 3),
}) async {
  final client = HttpClient()..connectionTimeout = connectTimeout;
  try {
    final req = await client.getUrl(Uri.parse('$kAiServiceUrl/health'));
    final resp = await req.close().timeout(responseTimeout);
    if (resp.statusCode != 200) {
      return (false, false, 'HTTP ${resp.statusCode}');
    }
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json is Map && json['status'] == 'ok') {
      return (true, json['model_loaded'] == true, 'ok');
    }
    return (false, false, 'status=${json is Map ? json['status'] : body}');
  } catch (e) {
    return (false, false, '$e');
  } finally {
    client.close();
  }
}

/// 一次 /analyze 的检测结果
class AiAnalyzeResult {
  const AiAnalyzeResult({
    required this.anomalyDetected,
    required this.anomalyType,
    required this.confidence,
    required this.description,
  });

  /// 是否检出异常（服务端 NMS 判定，阈值 0.25）
  final bool anomalyDetected;

  /// 异常类型：spaghetti / none / other
  final String anomalyType;

  /// 置信度 0~1
  final double confidence;

  /// 服务端描述（如"检测到 spaghetti (置信度: 85.3%)"）
  final String description;

  /// 中文类型标签（如 炒面 / 无异常）
  String get typeLabel => kAnomalyTypeLabels[anomalyType] ?? anomalyType;

  factory AiAnalyzeResult.fromJson(dynamic json) {
    if (json is! Map) {
      return AiAnalyzeResult.error('响应格式异常');
    }
    final type = (json['anomaly_type'] as String?) ?? 'none';
    return AiAnalyzeResult(
      anomalyDetected: json['anomaly_detected'] == true,
      anomalyType: type,
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      description: (json['description'] as String?) ?? '',
    );
  }

  /// 请求失败时的兜底结果
  factory AiAnalyzeResult.error(String message) => AiAnalyzeResult(
        anomalyDetected: false,
        anomalyType: 'none',
        confidence: 0,
        description: message,
      );
}

/// POST /analyze — 送检 JPEG，返回检测结果。
Future<AiAnalyzeResult> analyzeImage(
  Uint8List jpeg, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.postUrl(Uri.parse('$kAiServiceUrl/analyze'));
    req.headers.contentType = ContentType('application', 'octet-stream');
    req.contentLength = jpeg.length;
    req.add(jpeg);
    final resp = await req.close().timeout(timeout);
    if (resp.statusCode == 200) {
      final body = await resp.transform(utf8.decoder).join();
      return AiAnalyzeResult.fromJson(jsonDecode(body));
    }
    return AiAnalyzeResult.error('推理服务器返回 HTTP ${resp.statusCode}');
  } catch (e) {
    return AiAnalyzeResult.error('推理请求失败: $e');
  } finally {
    client.close();
  }
}

/// POST /visualize — 送检 JPEG，返回画好检测框的标注 JPEG；失败返回 null。
Future<Uint8List?> visualizeImage(
  Uint8List jpeg, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.postUrl(Uri.parse('$kAiServiceUrl/visualize'));
    req.headers.contentType = ContentType('application', 'octet-stream');
    req.contentLength = jpeg.length;
    req.add(jpeg);
    final resp = await req.close().timeout(timeout);
    if (resp.statusCode == 200) {
      final builder = BytesBuilder();
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// 检查图片是否清晰（Laplacian 方差，对齐 Python check_image_quality）。
///
/// 在后台 isolate 执行（compute），不阻塞 UI。
/// 返回方差：>= [kBlurThreshold] 视为清晰；解析失败返回正无穷（放行）。
Future<double> checkImageQuality(Uint8List jpeg) {
  return compute(_laplacianVariance, jpeg);
}

double _laplacianVariance(Uint8List jpeg) {
  try {
    final image = img.decodeImage(jpeg);
    if (image == null) return double.infinity;
    final g = img.grayscale(image);
    final w = g.width, h = g.height;
    final total = w * h;
    final vals = Float64List(total);

    // 3×3 Laplacian（PIL FIND_EDGES 近似核）：
    //   -1 -1 -1
    //   -1  8 -1
    //   -1 -1 -1
    // 边界像素按 0 处理（与 PIL 一致）
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final c = g.getPixel(x, y).r.toDouble();
        final lap = 8 * c -
            (g.getPixel(x - 1, y - 1).r +
                g.getPixel(x, y - 1).r +
                g.getPixel(x + 1, y - 1).r +
                g.getPixel(x - 1, y).r +
                g.getPixel(x + 1, y).r +
                g.getPixel(x - 1, y + 1).r +
                g.getPixel(x, y + 1).r +
                g.getPixel(x + 1, y + 1).r);
        vals[i] = lap;
      }
    }

    double sum = 0;
    for (var i = 0; i < total; i++) {
      sum += vals[i];
    }
    final mean = sum / total;
    double s2 = 0;
    for (var i = 0; i < total; i++) {
      final d = vals[i] - mean;
      s2 += d * d;
    }
    return s2 / total;
  } catch (_) {
    // 解析失败放行，不阻塞检测（对齐 Python check_image_quality）
    return double.infinity;
  }
}
