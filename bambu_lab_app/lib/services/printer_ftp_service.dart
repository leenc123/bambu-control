/// FTP 文件管理服务
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
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
        // 使用隐式 FTPS（端口 990，TLS 从连接开始）。不要用 ftpes（显式），
        // 那需要先明文连接再 AUTH TLS 升级，和打印机不兼容。
        securityType: SecurityType.ftps,
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

      // 2. 在 /cache 目录下查找匹配的 .3mf 文件
      await _client!.changeDirectory('/cache');
      final entries = await _client!.listDirectoryContent();
      final modelEntry = entries.cast<FTPEntry?>().firstWhere(
        (e) => e != null && e.type != FTPEntryType.dir && candidates.any((c) => e.name == c),
        orElse: () => null,
      );

      if (modelEntry == null) {
        _lastError = '未在 /cache 找到匹配的 .3mf 文件';
        return null;
      }

      // 3. 下载 .3mf 文件到临时目录
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/${modelEntry.name}');

      // 如果临时文件已存在且大小匹配，跳过下载
      if (!localFile.existsSync() || localFile.lengthSync() != (modelEntry.size ?? 0)) {
        final ok = await _client!.downloadFile(modelEntry.name, localFile);
        if (!ok || !localFile.existsSync()) {
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
      final plateMatch = RegExp(r'key="index"\s+value="(\d+)"').firstMatch(configXml);
      final plateNum = plateMatch?.group(1);
      if (plateNum == null) {
        _lastError = '未能在 slice_info.config 中找到 plate 编号';
        return null;
      }

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
        return Uint8List.fromList(rawContent);
      }
      return null;
    } catch (e) {
      _lastError = '从 .3mf 提取缩略图失败: $e';
      // ignore: avoid_print
      print('[FTP] 提取缩略图失败: $e');
      return null;
    }
  }
}
