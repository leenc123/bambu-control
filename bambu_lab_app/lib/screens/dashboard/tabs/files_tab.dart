/// 文件管理 Tab（使用 flutter_neumorphism_ui）
library;

import 'package:flutter/material.dart';
import 'package:flutter_neumorphism_ui/flutter_neumorphism_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:bambu_lab_app/providers/printer_config_provider.dart';
import 'package:bambu_lab_app/services/printer_ftp_service.dart';
import 'package:bambu_lab_app/theme/neuo_theme.dart';

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
    setState(() {
      _connected = ok;
      _loading = false;
      if (!ok) _error = _ftp!.lastError ?? 'FTP连接失败';
    });
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
          FlutterNeumorphism(
            style: NeumorphismStyle(color: c.background, borderRadius: 40, depth: 5),
            padding: const EdgeInsets.all(22),
            child: Icon(LucideIcons.server, size: 44, color: c.textSecondary.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 16),
          Text('FTP 未连接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 6),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
            )
          else
            Text('需要连接打印机后使用', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 16),
          _ConnectBtn(onPressed: _connect, c: c),
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
              child: _DirBtn(path: d.$1, icon: d.$3, label: d.$2, selected: sel, onTap: () => _loadDir(d.$1), c: c),
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
                          child: _FileItem(file: f, onTap: f.isDir ? () => _loadDir(f.path) : null, onDelete: () => _confirmDelete(f), c: c),
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

// ---- 连接按钮 ----
class _ConnectBtn extends StatefulWidget {
  const _ConnectBtn({required this.onPressed, required this.c});
  final VoidCallback onPressed;
  final NeuoColors c;

  @override
  State<_ConnectBtn> createState() => _ConnectBtnState();
}

class _ConnectBtnState extends State<_ConnectBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 14,
          depth: _pressed ? 3 : 6,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text('连接', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.accent)),
      ),
    );
  }
}

// ---- 目录按钮 ----
class _DirBtn extends StatefulWidget {
  const _DirBtn({required this.path, required this.icon, required this.label, required this.selected, required this.onTap, required this.c});
  final String path;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final NeuoColors c;

  @override
  State<_DirBtn> createState() => _DirBtnState();
}

class _DirBtnState extends State<_DirBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 10,
          depth: _pressed ? 2 : (widget.selected ? 3 : 4),
          type: _pressed ? NeumorphismType.pressed : (widget.selected ? NeumorphismType.pressed : NeumorphismType.flat),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 14, color: widget.selected ? widget.c.accent : widget.c.textSecondary),
          const SizedBox(width: 4),
          Text(widget.label, style: TextStyle(fontSize: 12, color: widget.selected ? widget.c.accent : widget.c.textPrimary)),
        ]),
      ),
    );
  }
}

// ---- 文件条目 ----
class _FileItem extends StatefulWidget {
  const _FileItem({required this.file, required this.onTap, required this.onDelete, required this.c});
  final FtpFile file;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final NeuoColors c;

  @override
  State<_FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<_FileItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: FlutterNeumorphism(
        style: NeumorphismStyle(
          color: widget.c.background,
          borderRadius: 10,
          depth: _pressed ? 2 : 3,
          type: _pressed ? NeumorphismType.pressed : NeumorphismType.flat,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Icon(widget.file.isDir ? LucideIcons.folder : LucideIcons.file, size: 18,
              color: widget.file.isDir ? widget.c.accent : widget.c.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.file.name,
              style: TextStyle(fontSize: 12, color: widget.c.textPrimary),
              overflow: TextOverflow.ellipsis)),
          if (!widget.file.isDir) ...[
            Text(widget.file.sizeDisplay, style: TextStyle(fontSize: 11, color: widget.c.textSecondary)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: widget.onDelete,
              child: Icon(LucideIcons.trash2, size: 16, color: widget.c.textSecondary.withValues(alpha: 0.5)),
            ),
          ],
        ]),
      ),
    );
  }
}