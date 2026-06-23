/// G-code 状态枚举 - 对应 Python GcodeState
enum GcodeState {
  idle('IDLE'),
  prepare('PREPARE'),
  running('RUNNING'),
  pause('PAUSE'),
  finish('FINISH'),
  failed('FAILED'),
  unknown('UNKNOWN');

  const GcodeState(this.value);

  final String value;

  static GcodeState fromValue(String? value) {
    if (value == null) return unknown;
    for (final state in GcodeState.values) {
      if (state.value == value) return state;
    }
    return unknown;
  }

  /// 中文显示名称
  String get displayName => switch (this) {
        GcodeState.idle => '空闲',
        GcodeState.prepare => '准备中',
        GcodeState.running => '运行中',
        GcodeState.pause => '已暂停',
        GcodeState.finish => '已完成',
        GcodeState.failed => '失败',
        GcodeState.unknown => '未知',
      };

  /// 是否可以暂停/恢复
  bool get canPause => this == running;
  bool get canResume => this == pause;
  bool get canStop => this == running || this == pause;
}
