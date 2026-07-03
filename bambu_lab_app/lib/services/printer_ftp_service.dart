/// FTP 文件管理服务
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';

class FtpFile {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final DateTime? modified;

  const FtpFile({required this.name, required this.path, this.isDir = false, this.size = 0, this.modified});

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PrinterFtpService {
  PrinterFtpService({required this.host, required this.accessCode, this.port = 990});

  final String host;
  final int port;
  final String accessCode;
  FTPConnect? _client;
  String? _lastError;

  bool get isConnected => _client != null;
  String? get lastError => _lastError;

  Future<bool> connect() async {
    try {
      _lastError = null;
      // 启用日志输出以便调试
      _client = FTPConnect(
        host,
        user: 'bblp',
        pass: accessCode,
        port: port,
        securityType: SecurityType.ftpes,
        timeout: 30, // 增加超时时间
        showLog: true, // 启用调试日志
      );
      final ok = await _client!.connect();
      if (!ok) {
        _lastError = 'FTP连接返回失败';
        _client = null;
      }
      return ok;
    } catch (e) {
      _lastError = 'FTP连接异常: $e';
      // ignore: avoid_print
      print('[FTP] 连接失败: $e');
      _client = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
  }

  Future<List<FtpFile>> listDirectory([String dir = '/']) async {
    if (_client == null) return [];
    try {
      await _client!.changeDirectory(dir);
      final entries = await _client!.listDirectoryContent();
      return entries.map((e) => FtpFile(
        name: e.name,
        path: '$dir/${e.name}'.replaceAll('//', '/'),
        isDir: e.type == FTPEntryType.dir,
        size: e.size ?? 0,
        modified: e.modifyTime,
      )).toList();
    } catch (e) {
      _lastError = '列出目录失败: $e';
      // ignore: avoid_print
      print('[FTP] 列出目录失败 ($dir): $e');
      return [];
    }
  }

  Future<List<FtpFile>> listCache() async => listDirectory('/cache');
  Future<List<FtpFile>> listImages() async => listDirectory('/image');
  Future<List<FtpFile>> listTimelapse() async => listDirectory('/timelapse');

  Future<bool> uploadFile(File file, String remoteName) async {
    try {
      return await _client?.uploadFile(file, sRemoteName: remoteName) ?? false;
    } catch (e) {
      _lastError = '上传失败: $e';
      return false;
    }
  }

  Future<bool> downloadFile(String remotePath, File localFile) async {
    try {
      return await _client?.downloadFile(remotePath, localFile) ?? false;
    } catch (e) {
      _lastError = '下载失败: $e';
      return false;
    }
  }

  Future<bool> deleteFile(String path) async {
    try {
      final name = path.split('/').last;
      return await _client?.deleteFile(name) ?? false;
    } catch (e) {
      _lastError = '删除失败: $e';
      return false;
    }
  }

  /// 获取 /image 目录中最新的预览图片（PNG 格式）
  /// 返回图片的字节数据，用于显示预览
  Future<Uint8List?> getLatestPreviewImage() async {
    if (_client == null) return null;
    try {
      // 进入 /image 目录
      await _client!.changeDirectory('/image');
      final entries = await _client!.listDirectoryContent();

      // 过滤出 PNG 文件，按修改时间排序（最新的在前）
      final pngFiles = entries
          .where((e) => e.name.toLowerCase().endsWith('.png') && e.type != FTPEntryType.dir)
          .toList();

      if (pngFiles.isEmpty) return null;

      // 按修改时间排序，获取最新的
      pngFiles.sort((a, b) {
        final aTime = a.modifyTime ?? DateTime(1970);
        final bTime = b.modifyTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final latestFile = pngFiles.first;

      // 下载到临时目录
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/preview_${latestFile.name}');

      // 下载文件
      final ok = await _client!.downloadFile(latestFile.name, localFile);
      if (!ok || !localFile.existsSync()) return null;

      // 读取并返回字节数据
      return localFile.readAsBytes();
    } catch (e) {
      _lastError = '获取预览图片失败: $e';
      // ignore: avoid_print
      print('[FTP] 获取预览图片失败: $e');
      return null;
    }
  }
}
