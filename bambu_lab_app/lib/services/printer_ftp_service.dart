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
  /// 返回 Metadata/plate_X.png 的字节数据
  Future<Uint8List?> fetchCoverImageFrom3mf(String subtaskName) async {
    if (_client == null) return null;
    try {
      // 1. 构建候选文件名（.3mf 或 .gcode.3mf）
      final candidates = <String>[
        if (subtaskName.endsWith('.3mf')) subtaskName,
        if (!subtaskName.endsWith('.3mf')) '$subtaskName.3mf',
        if (!subtaskName.endsWith('.3mf')) '$subtaskName.gcode.3mf',
      ];

      DebugLog.i('FTP', '搜索 .3mf 文件，候选: $candidates');

      // 2. 在 /cache 目录下查找匹配的 .3mf 文件
      final entries = await _client!.list('/cache');
      final modelEntry = entries.cast<FtpEntry?>().firstWhere(
            (e) =>
                e != null &&
                !e.isDir &&
                candidates.any((c) => e.name == c),
            orElse: () => null,
          );

      if (modelEntry == null) {
        _lastError = '未在 /cache 找到匹配的 .3mf 文件';
        DebugLog.i('FTP', _lastError!);
        return null;
      }

      DebugLog.i('FTP', '找到 .3mf 文件: ${modelEntry.name}');

      // 3. 下载 .3mf 文件到临时目录
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/${modelEntry.name}');

      // 如果临时文件已存在且大小匹配，跳过下载
      if (!localFile.existsSync() ||
          localFile.lengthSync() != (modelEntry.size ?? 0)) {
        await _client!.downloadFile('/cache/${modelEntry.name}', localFile);
        if (!localFile.existsSync()) {
          _lastError = '下载 .3mf 文件失败';
          return null;
        }
      }

      // 4. 读取 .3mf（ZIP 格式）并解析
      final bytes = localFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 5. 读取 slice_info.config 提取 plate 编号
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

      // 6. 读取 Metadata/plate_{plateNum}.png
      ArchiveFile? pngEntry;
      for (final f in archive) {
        if (f.name == 'Metadata/plate_$plateNum.png') {
          pngEntry = f;
          break;
        }
      }
      if (pngEntry == null) {
        _lastError = '.3mf 中未找到 Metadata/plate_$plateNum.png';
        return null;
      }

      final rawContent = pngEntry.content;
      if (rawContent is List<int>) {
        DebugLog.i('FTP', '从 .3mf 提取缩略图成功');
        return Uint8List.fromList(rawContent);
      }
      DebugLog.i('FTP', '从 .3mf 提取缩略图失败: content类型不是List<int>');
      return null;
    } catch (e) {
      _lastError = '从 .3mf 提取缩略图失败: $e';
      DebugLog.i('FTP', '提取缩略图失败: $e');
      return null;
    }
  }
}
