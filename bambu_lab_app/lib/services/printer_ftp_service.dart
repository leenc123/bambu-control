/// FTP 文件管理服务
///
/// 底层使用 [ImplicitFTPSClient]（非 ftpconnect），
/// 修复了响应读取竞态、数据通道 TLS 加密等问题。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:bambu_lab_app/services/ftp_client.dart';
import 'package:bambu_lab_app/utils/debug_log.dart';
import 'package:path_provider/path_provider.dart';

class FtpFile {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final DateTime? modified;

  const FtpFile({
    required this.name,
    required this.path,
    this.isDir = false,
    this.size = 0,
    this.modified,
  });

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PrinterFtpService {
  PrinterFtpService({
    required this.host,
    required this.accessCode,
    this.port = 990,
  });

  final String host;
  final int port;
  final String accessCode;
  ImplicitFTPSClient? _client;
  String? _lastError;

  bool get isConnected => _client?.isConnected ?? false;
  String? get lastError => _lastError;

  Future<bool> connect() async {
    try {
      _lastError = null;
      DebugLog.i('FTP', '--- 开始 FTP 连接 ---');
      DebugLog.i('FTP', '目标: $host:$port, 用户: bblp');

      final ftp = ImplicitFTPSClient(
        host: host,
        port: port,
        user: 'bblp',
        password: accessCode,
      );

      await ftp.connect();
      _client = ftp;

      DebugLog.i('FTP', '--- FTP 连接成功 ---');
      return true;
    } catch (e) {
      _lastError = 'FTP连接异常: $e';
      DebugLog.i('FTP', '连接失败: $e');
      _client = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _client?.quit();
    _client = null;
  }

  Future<List<FtpFile>> listDirectory([String dir = '/']) async {
    if (_client == null) return [];
    try {
      final entries = await _client!.list(dir);
      return entries.map((e) => FtpFile(
            name: e.name,
            path: '$dir/${e.name}'.replaceAll('//', '/'),
            isDir: e.isDir,
            size: e.size ?? 0,
            modified: e.modifyTime,
          )).toList();
    } catch (e) {
      _lastError = '列出目录失败: $e';
      DebugLog.i('FTP', '列出目录失败 ($dir): $e');
      return [];
    }
  }

  Future<List<FtpFile>> listCache() async => listDirectory('/cache');
  Future<List<FtpFile>> listImages() async => listDirectory('/image');
  Future<List<FtpFile>> listTimelapse() async => listDirectory('/timelapse');

  Future<bool> uploadFile(File file, String remoteName) async {
    // 暂不支持上传 — 需要 STOR 命令实现
    _lastError = '上传暂不支持';
    return false;
  }

  Future<bool> downloadFile(String remotePath, File localFile) async {
    if (_client == null) return false;
    try {
      DebugLog.i('FTP', '下载文件: $remotePath');
      await _client!.downloadFile(remotePath, localFile);
      DebugLog.i('FTP', '下载完成: $remotePath');
      return true;
    } catch (e) {
      _lastError = '下载失败: $e';
      DebugLog.i('FTP', '下载失败: $e');
      return false;
    }
  }

  Future<bool> deleteFile(String path) async {
    if (_client == null) return false;
    try {
      await _client!.delete(path);
      return true;
    } catch (e) {
      _lastError = '删除失败: $e';
      return false;
    }
  }

  /// 获取 /image 目录中最新的预览图片（PNG 格式）
  /// 返回图片的字节数据，用于显示预览
  Future<Uint8List?> getLatestPreviewImage() async {
    if (_client == null) return null;
    DebugLog.i('FTP', '--- getLatestPreviewImage 开始 ---');
    try {
      final entries = await _client!.list('/image');
      DebugLog.i('FTP', 'LIST /image 返回 ${entries.length} 个条目');

      // 过滤出 PNG 文件，按修改时间排序（最新的在前）
      final pngFiles = entries
          .where((e) => e.name.toLowerCase().endsWith('.png') && !e.isDir)
          .toList();

      if (pngFiles.isEmpty) {
        DebugLog.i('FTP', '/image 目录无 PNG 文件');
        return null;
      }

      pngFiles.sort((a, b) {
        final aTime = a.modifyTime ?? DateTime(1970);
        final bTime = b.modifyTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final latestFile = pngFiles.first;
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/preview_${latestFile.name}');

      await _client!.downloadFile('/image/${latestFile.name}', localFile);
      if (!localFile.existsSync()) return null;

      DebugLog.i('FTP', '--- getLatestPreviewImage 结束(成功) ---');
      return localFile.readAsBytes();
    } catch (e) {
      _lastError = '获取预览图片失败: $e';
      DebugLog.i('FTP', '获取预览图片失败: $e');
      DebugLog.i('FTP', '--- getLatestPreviewImage 结束(失败) ---');
      return null;
    }
  }

  /// 从 .3mf 文件中提取打印缩略图（封面图）
  ///
  /// [subtaskName] MQTT 推送的 subtask_name，用于匹配 .3mf 文件名
  /// [gcodeFile] MQTT 推送的 gcode_file，用作 fallback 文件名
  /// 返回 Metadata/plate_X.png 的字节数据
  Future<Uint8List?> fetchCoverImageFrom3mf(String subtaskName, {String? gcodeFile}) async {
    if (_client == null) return null;

    // 构建候选文件名 — 参考 ha-bambulab 的 _attempt_ftp_download 策略：
    //   先试 subtask_name，再试 gcode_file
    final candidates = <String>[];
    void addCandidates(String name) {
      if (name.isEmpty) return;
      if (name.endsWith('.3mf')) {
        candidates.add(name);
      } else {
        candidates.add('$name.3mf');
        candidates.add('$name.gcode.3mf');
      }
    }

    if (subtaskName.isNotEmpty) {
      addCandidates(subtaskName);
    }
    // gcode_file 可能是完整路径（如 /data/Metadata/plate_1.gcode），取文件名部分
    if (gcodeFile != null && gcodeFile.isNotEmpty && gcodeFile != subtaskName) {
      final gcodeBasename = gcodeFile.split('/').last;
      addCandidates(gcodeBasename);
    }

    DebugLog.i('FTP', '搜索 .3mf 文件，候选: $candidates');

    // 新打印开始时，打印机可能还没把 .3mf 写入，需要重试
    // X1 老机型在 RUNNING 后几秒才写完文件，参考 ha-bambulab 重试 13 次 × 5 秒
    const maxRetries = 13;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 有候选文件名时，按文件名匹配
        if (candidates.isNotEmpty) {
          final result = await _tryFetchCoverFrom3mf(candidates);
          if (result != null) return result;
        } else {
          // 没有候选文件名（如 subtask_name 为空）→ 降级到最新 .3mf 文件
          final latestPath = await _findLatest3mfFilePath();
          if (latestPath != null) {
            final result = await _downloadAndExtractCover(latestPath);
            if (result != null) return result;
          }
        }
      } catch (e) {
        _lastError = '重试 $attempt/$maxRetries 失败: $e';
        DebugLog.i('FTP', _lastError!);
      }
      if (attempt < maxRetries) {
        DebugLog.i('FTP', '等待 5 秒后重试 ($attempt/$maxRetries)');
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    _lastError = '重试 $maxRetries 次后仍未找到 .3mf 文件';
    DebugLog.i('FTP', _lastError!);
    return null;
  }

  /// 在 ['/cache', '/'] 两个路径下按候选文件名搜索 .3mf，找到则下载并提取缩略图
  Future<Uint8List?> _tryFetchCoverFrom3mf(List<String> candidates) async {
    const searchPaths = ['/cache', '/'];

    for (final searchPath in searchPaths) {
      try {
        final entries = await _client!.list(searchPath);
        final modelEntry = entries.cast<FtpEntry?>().firstWhere(
              (e) =>
                  e != null &&
                  !e.isDir &&
                  candidates.any((c) => e.name == c),
              orElse: () => null,
            );

        if (modelEntry == null) continue;

        final remotePath = '$searchPath/${modelEntry.name}'.replaceAll('//', '/');
        DebugLog.i('FTP', '找到 .3mf 文件: $remotePath');
        return await _downloadAndExtractCover(remotePath);
      } catch (_) {
        // 尝试下一个路径
        continue;
      }
    }

    _lastError = '未在 /cache 或 / 找到匹配的 .3mf 文件';
    return null;
  }

  /// 下载远程 .3mf 文件并提取 plate 缩略图
  Future<Uint8List?> _downloadAndExtractCover(String remotePath) async {
    final fileName = remotePath.split('/').last;

    final tempDir = await getTemporaryDirectory();
    final localFile = File('${tempDir.path}/$fileName');
    if (localFile.existsSync()) {
      DebugLog.i('FTP', '清除旧缓存: ${localFile.path}');
      await localFile.delete();
    }
    await _client!.downloadFile(remotePath, localFile);
    if (!localFile.existsSync()) {
      _lastError = '下载 .3mf 文件失败';
      return null;
    }

    // 读取 .3mf（ZIP 格式）并解析
    final bytes = localFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 读取 slice_info.config 提取 plate 编号（参考 ha-bambulab ElementTree 解析方式）
    ArchiveFile? configEntry;
    for (final f in archive) {
      if (f.name == 'Metadata/slice_info.config') {
        configEntry = f;
        break;
      }
    }
    if (configEntry == null) {
      _lastError = '.3mf 中未找到 Metadata/slice_info.config';
      return null;
    }

    final configXml = utf8.decode(configEntry.content as List<int>);
    final plateMatch =
        RegExp(r'key="index"\s+value="(\d+)"').firstMatch(configXml);
    final plateNum = plateMatch?.group(1);
    if (plateNum == null) {
      _lastError = '未能在 slice_info.config 中找到 plate 编号';
      return null;
    }

    DebugLog.i('FTP', '提取 plate $plateNum 缩略图');

    // 读取 Metadata/plate_{plateNum}.png
    for (final f in archive) {
      if (f.name == 'Metadata/plate_$plateNum.png') {
        final content = f.content;
        if (content is List<int>) {
          DebugLog.i('FTP', '从 .3mf 提取缩略图成功 ($remotePath)');
          return Uint8List.fromList(content);
        }
      }
    }
    _lastError = '.3mf 中未找到 Metadata/plate_$plateNum.png';
    return null;
  }

  /// 在 ['/cache', '/'] 中按时间戳找最新的 .3mf 文件，返回远程路径
  /// 当 subtask_name 为空时（如打印机重启后）用作 fallback
  Future<String?> _findLatest3mfFilePath() async {
    const searchPaths = ['/cache', '/'];

    final candidates = <_RemoteFile>[];

    for (final searchPath in searchPaths) {
      try {
        final entries = await _client!.list(searchPath);
        for (final e in entries) {
          if (e.isDir) continue;
          final lower = e.name.toLowerCase();
          if (lower.endsWith('.3mf') || lower.endsWith('.gcode.3mf')) {
            final remotePath =
                '$searchPath/${e.name}'.replaceAll('//', '/');
            candidates.add(_RemoteFile(
              path: remotePath,
              modifyTime: e.modifyTime ?? DateTime(1970),
            ));
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.modifyTime.compareTo(a.modifyTime));
    DebugLog.i('FTP', '降级到最新 .3mf: ${candidates.first.path}');
    return candidates.first.path;
  }
}

// ---- 内部辅助类型 ----

class _RemoteFile {
  final String path;
  final DateTime modifyTime;
  const _RemoteFile({required this.path, required this.modifyTime});
}
