/// 文件管理 Tab
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/services/printer_ftp_service.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';
import 'package:bambu_lab_app/widgets/neuo_button.dart';
import 'package:bambu_lab_app/widgets/neuo_card.dart';

class FilesTab extends StatefulWidget {
  const FilesTab({super.key});
  @override State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  PrinterFtpService? _ftp;
  List<FtpFile> _files = [];
  bool _loading = false;
  String _currentDir = '/';
  String? _error;
  bool _connected = false;

  // 快捷目录
  static const _dirs = [
    ('/', '根目录', LucideIcons.folder),
    ('/cache', '缓存', LucideIcons.archive),
    ('/image', '图片', LucideIcons.image),
    ('/timelapse', '延时摄影', LucideIcons.video),
  ];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final cfg = context.read<PrinterConfigProvider>().selected;
    if (cfg == null) return;
    setState(() => _loading = true);
    _ftp = PrinterFtpService(host: cfg.ip, accessCode: cfg.accessCode);
    final ok = await _ftp!.connect();
    if (!mounted) return;
    setState(() { _connected = ok; _loading = false; });
    if (ok) await _loadDir();
  }

  Future<void> _loadDir([String? dir]) async {
    if (_ftp == null) return;
    setState(() => _loading = true);
    try {
      final files = await _ftp!.listDirectory(dir ?? _currentDir);
      if (!mounted) return;
      setState(() {
        _files = files..sort((a, b) {
          if (a.isDir && !b.isDir) return -1;
          if (!a.isDir && b.isDir) return 1;
          return a.name.compareTo(b.name);
        });
        if (dir != null) _currentDir = dir;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = NeuoTheme.of(context);

    if (!_connected && !_loading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          NeuoCard(shape: NeuoShape.convex, borderRadius: 40, depth: 5, intensity: 0.6, padding: const EdgeInsets.all(22),
              child: Icon(LucideIcons.server, size: 44, color: c.textSecondary.withValues(alpha: 0.35))),
          const SizedBox(height: 16),
          Text('FTP 未连接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('需要连接打印机后使用', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 16),
          NeuoButton(
            label: const Text('连接'), onPressed: _connect,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        ]),
      );
    }

    return Column(children: [
      // 快捷目录
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          itemCount: _dirs.length,
          itemBuilder: (_, i) {
            final d = _dirs[i];
            final sel = _currentDir == d.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: NeuoCard(
                onTap: () => _loadDir(d.$1),
                shape: sel ? NeuoShape.concave : NeuoShape.convex,
                borderRadius: 10, depth: sel ? 2 : 3, intensity: 0.4,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(d.$3, size: 14, color: sel ? c.accent : c.textSecondary),
                  const SizedBox(width: 4),
                  Text(d.$2, style: TextStyle(fontSize: 12, color: sel ? c.accent : c.textPrimary)),
                ]),
              ),
            );
          },
        ),
      ),
      // 当前路径
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Icon(LucideIcons.folder, size: 14, color: c.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text('/ $_currentDir', style: TextStyle(fontSize: 11, color: c.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
          if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
      ),
      // 文件列表
      Expanded(
        child: _error != null
            ? Center(child: Text(_error!, style: TextStyle(fontSize: 13, color: Colors.red)))
            : _files.isEmpty
                ? Center(child: Text('空目录', style: TextStyle(fontSize: 13, color: c.textSecondary)))
                : RefreshIndicator(
                    onRefresh: () => _loadDir(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _files.length,
                      itemBuilder: (_, i) {
                        final f = _files[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: NeuoCard(
                            onTap: f.isDir ? () => _loadDir(f.path) : null,
                            depth: 2, intensity: 0.4, borderRadius: 10,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(children: [
                              Icon(f.isDir ? LucideIcons.folder : LucideIcons.file, size: 18,
                                  color: f.isDir ? c.accent : c.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(f.name,
                                  style: TextStyle(fontSize: 12, color: c.textPrimary),
                                  overflow: TextOverflow.ellipsis)),
                              if (!f.isDir) ...[
                                Text(f.sizeDisplay, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _confirmDelete(f),
                                  child: Icon(LucideIcons.trash2, size: 16, color: c.textSecondary.withValues(alpha: 0.5)),
                                ),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }

  Future<void> _confirmDelete(FtpFile f) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除文件'), content: Text('确定删除 ${f.name} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      await _ftp?.deleteFile(f.path);
      _loadDir();
    }
  }
}
