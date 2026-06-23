/// FTP 文件管理服务
library;

import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

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

  final String host; final int port; final String accessCode;
  FTPConnect? _client;

  bool get isConnected => _client != null;

  Future<bool> connect() async {
    try {
      _client = FTPConnect(host, user: 'bblp', pass: accessCode, port: port, securityType: SecurityType.ftpes, timeout: 10);
      await _client!.connect();
      return true;
    } catch (_) { _client = null; return false; }
  }

  Future<void> disconnect() async { await _client?.disconnect(); _client = null; }

  Future<List<FtpFile>> listDirectory([String dir = '/']) async {
    if (_client == null) return [];
    try {
      await _client!.changeDirectory(dir);
      final entries = await _client!.listDirectoryContent();
      return entries.map((e) => FtpFile(name: e.name, path: '$dir/${e.name}', isDir: e.type == FTPEntryType.dir, size: e.size ?? 0, modified: e.modifyTime)).toList();
    } catch (_) { return []; }
  }

  Future<List<FtpFile>> listCache() async => listDirectory('/cache');
  Future<List<FtpFile>> listImages() async => listDirectory('/image');
  Future<List<FtpFile>> listTimelapse() async => listDirectory('/timelapse');

  Future<bool> uploadFile(File file, String remoteName) async {
    return await _client?.uploadFile(file, sRemoteName: remoteName) ?? false;
  }

  Future<bool> downloadFile(String remotePath, File localFile) async {
    return await _client?.downloadFile(remotePath, localFile) ?? false;
  }

  Future<bool> deleteFile(String path) async {
    final name = path.split('/').last;
    return await _client?.deleteFile(name) ?? false;
  }
}
