/// 打印机状态枚举 - 对应 Python PrintStatus
///
/// 36 种状态 + UNKNOWN + IDLE
enum PrintStatus {
  printing(0),
  autoBedLeveling(1),
  heatbedPreheating(2),
  sweepingXyMechMode(3),
  changingFilament(4),
  m400Pause(5),
  pausedFilamentRunout(6),
  heatingHotend(7),
  calibratingExtrusion(8),
  scanningBedSurface(9),
  inspectingFirstLayer(10),
  identifyingBuildPlateType(11),
  calibratingMicroLidar(12),
  homingToolhead(13),
  cleaningNozzleTip(14),
  checkingExtruderTemperature(15),
  pausedUser(16),
  pausedFrontCoverFalling(17),
  calibratingLidar(18),
  calibratingExtrusionFlow(19),
  pausedNozzleTemperatureMalfunction(20),
  pausedHeatBedTemperatureMalfunction(21),
  filamentUnloading(22),
  pausedSkippedStep(23),
  filamentLoading(24),
  calibratingMotorNoise(25),
  pausedAmsLost(26),
  pausedLowFanSpeedHeatBreak(27),
  pausedChamberTemperatureControlError(28),
  coolingChamber(29),
  pausedUserGcode(30),
  motorNoiseShowoff(31),
  pausedNozzleFilamentCoveredDetected(32),
  pausedCutterError(33),
  pausedFirstLayerError(34),
  pausedNozzleClog(35),
  idle(255),
  unknown(-1);

  const PrintStatus(this.value);

  final int value;

  static PrintStatus fromValue(int? value) {
    if (value == null) return unknown;
    for (final status in PrintStatus.values) {
      if (status.value == value) return status;
    }
    return unknown;
  }

  /// 是否正在打印中（非空闲、非暂停）
  bool get isActive => switch (this) {
        PrintStatus.printing ||
        PrintStatus.autoBedLeveling ||
        PrintStatus.heatbedPreheating ||
        PrintStatus.sweepingXyMechMode ||
        PrintStatus.changingFilament ||
        PrintStatus.heatingHotend ||
        PrintStatus.calibratingExtrusion ||
        PrintStatus.scanningBedSurface ||
        PrintStatus.inspectingFirstLayer ||
        PrintStatus.identifyingBuildPlateType ||
        PrintStatus.calibratingMicroLidar ||
        PrintStatus.homingToolhead ||
        PrintStatus.cleaningNozzleTip ||
        PrintStatus.checkingExtruderTemperature ||
        PrintStatus.calibratingLidar ||
        PrintStatus.calibratingExtrusionFlow ||
        PrintStatus.filamentUnloading ||
        PrintStatus.filamentLoading ||
        PrintStatus.calibratingMotorNoise ||
        PrintStatus.coolingChamber ||
        PrintStatus.motorNoiseShowoff =>
          true,
        _ => false,
      };

  /// 是否处于暂停状态
  bool get isPaused => switch (this) {
        PrintStatus.m400Pause ||
        PrintStatus.pausedFilamentRunout ||
        PrintStatus.pausedUser ||
        PrintStatus.pausedFrontCoverFalling ||
        PrintStatus.pausedNozzleTemperatureMalfunction ||
        PrintStatus.pausedHeatBedTemperatureMalfunction ||
        PrintStatus.pausedSkippedStep ||
        PrintStatus.pausedAmsLost ||
        PrintStatus.pausedLowFanSpeedHeatBreak ||
        PrintStatus.pausedChamberTemperatureControlError ||
        PrintStatus.pausedUserGcode ||
        PrintStatus.pausedNozzleFilamentCoveredDetected ||
        PrintStatus.pausedCutterError ||
        PrintStatus.pausedFirstLayerError ||
        PrintStatus.pausedNozzleClog =>
          true,
        _ => false,
      };

  /// 中文显示名称
  String get displayName => switch (this) {
        PrintStatus.printing => '打印中',
        PrintStatus.autoBedLeveling => '自动调平',
        PrintStatus.heatbedPreheating => '热床预热',
        PrintStatus.sweepingXyMechMode => 'XY 机械扫掠',
        PrintStatus.changingFilament => '换料中',
        PrintStatus.m400Pause => 'M400 暂停',
        PrintStatus.pausedFilamentRunout => '断料暂停',
        PrintStatus.heatingHotend => '热端加热',
        PrintStatus.calibratingExtrusion => '挤出校准',
        PrintStatus.scanningBedSurface => '床面扫描',
        PrintStatus.inspectingFirstLayer => '首层检测',
        PrintStatus.identifyingBuildPlateType => '识别构建板',
        PrintStatus.calibratingMicroLidar => '激光雷达校准',
        PrintStatus.homingToolhead => '归零',
        PrintStatus.cleaningNozzleTip => '清洁喷嘴',
        PrintStatus.checkingExtruderTemperature => '挤出温度检查',
        PrintStatus.pausedUser => '用户暂停',
        PrintStatus.pausedFrontCoverFalling => '前盖脱落暂停',
        PrintStatus.calibratingLidar => '激光雷达校准',
        PrintStatus.calibratingExtrusionFlow => '流量校准',
        PrintStatus.pausedNozzleTemperatureMalfunction => '喷嘴温度故障',
        PrintStatus.pausedHeatBedTemperatureMalfunction => '热床温度故障',
        PrintStatus.filamentUnloading => '退料中',
        PrintStatus.pausedSkippedStep => '丢步暂停',
        PrintStatus.filamentLoading => '进料中',
        PrintStatus.calibratingMotorNoise => '电机噪音校准',
        PrintStatus.pausedAmsLost => 'AMS 丢失',
        PrintStatus.pausedLowFanSpeedHeatBreak => '散热风扇低速',
        PrintStatus.pausedChamberTemperatureControlError => '箱体温控异常',
        PrintStatus.coolingChamber => '箱体冷却',
        PrintStatus.pausedUserGcode => 'G-code 暂停',
        PrintStatus.motorNoiseShowoff => '电机噪音展示',
        PrintStatus.pausedNozzleFilamentCoveredDetected => '喷嘴挂料检测',
        PrintStatus.pausedCutterError => '切刀错误',
        PrintStatus.pausedFirstLayerError => '首层错误',
        PrintStatus.pausedNozzleClog => '喷嘴堵塞',
        PrintStatus.idle => '空闲',
        PrintStatus.unknown => '未知',
      };
}
