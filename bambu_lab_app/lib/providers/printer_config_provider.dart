/// 打印机配置 Provider - 管理已保存的打印机列表
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:bambu_lab_app/db/database.dart';
import 'package:bambu_lab_app/db/printer_dao.dart';
import 'package:bambu_lab_app/models/printer_config.dart';

/// 打印机配置管理器 - CRUD + 选中状态 + 在线检测
class PrinterConfigProvider extends ChangeNotifier {
  PrinterConfigProvider(this._database) : _dao = PrinterDao(_database);

  final AppDatabase _database;
  final PrinterDao _dao;

  List<PrinterConfig> _printers = [];
  PrinterConfig? _selected;
  bool _isLoading = false;
  String? _error;

  /// 在线状态缓存（打印机ID -> 是否在线）
  final Map<int, bool> _onlineStatus = {};

  /// 定时检测 Timer
  Timer? _pingTimer;

  /// 所有已保存的打印机
  List<PrinterConfig> get printers => List.unmodifiable(_printers);

  /// 当前选中的打印机
  PrinterConfig? get selected => _selected;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 错误信息
  String? get error => _error;

  /// 获取指定打印机的在线状态
  bool isOnline(int? id) => _onlineStatus[id] ?? false;

  /// 启动定时在线检测（每5秒）
  void startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pingAll());
    // 立即执行一次
    _pingAll();
  }

  /// 停止定时检测
  void stopPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// 检测所有打印机在线状态
  Future<void> _pingAll() async {
    if (_printers.isEmpty) return;

    // 并行检测所有打印机
    final futures = _printers.map((p) => _pingPrinter(p));
    await Future.wait(futures);
    notifyListeners();
  }

  /// 检测单台打印机在线状态（Socket 连接测试）
  Future<void> _pingPrinter(PrinterConfig p) async {
    if (p.id == null) return;

    final port = p.port;
    final wasOnline = _onlineStatus[p.id] ?? false;

    try {
      // 尝试建立 Socket 连接（超时 2 秒）
      final socket = await Socket.connect(
        p.ip,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      _onlineStatus[p.id!] = true;

      // 状态变化时打印日志
      if (!wasOnline) {
        debugPrint('[PrinterConfigProvider] ${p.name} 上线');
      }
    } catch (e) {
      _onlineStatus[p.id!] = false;

      // 状态变化时打印日志
      if (wasOnline) {
        debugPrint('[PrinterConfigProvider] ${p.name} 下线');
      }
    }
  }

  /// 加载所有打印机
  Future<void> loadPrinters() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _printers = await _dao.getAllPrinters();
      // 自动选中第一个或之前选中的
      if (_selected == null && _printers.isNotEmpty) {
        _selected = _printers.first;
      }
    } catch (e) {
      _error = '加载打印机列表失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 监听打印机列表变化（响应式）
  Stream<List<PrinterConfig>> watchPrinters() => _dao.watchAllPrinters();

  /// 添加打印机
  Future<int?> addPrinter(PrinterConfig config) async {
    try {
      final id = await _dao.insertPrinter(config);
      await loadPrinters();
      return id;
    } catch (e) {
      _error = '添加打印机失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 更新打印机
  Future<bool> updatePrinter(PrinterConfig config) async {
    try {
      final ok = await _dao.updatePrinter(config);
      if (ok) {
        await loadPrinters();
        if (_selected?.id == config.id) {
          _selected = config;
        }
      }
      return ok;
    } catch (e) {
      _error = '更新打印机失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 删除打印机
  Future<bool> deletePrinter(int id) async {
    try {
      final ok = await _dao.deletePrinter(id);
      if (ok) {
        if (_selected?.id == id) {
          _selected = null;
        }
        await loadPrinters();
      }
      return ok;
    } catch (e) {
      _error = '删除打印机失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 选择打印机
  void selectPrinter(PrinterConfig config) {
    _selected = config;
    notifyListeners();
  }

  /// 更新最后连接时间
  Future<void> markConnected(int id) async {
    await _dao.updateLastConnected(id, DateTime.now());
  }

  @override
  void dispose() {
    stopPingLoop();
    _database.close();
    super.dispose();
  }
}
