/// 耗材枚举 - 对应 Python Filament + AMSFilamentSettings
///
/// 50+ 种耗材类型，包含喷嘴温度范围和材料类型
library;

/// 耗材设置数据类
class AMSFilamentSettings {
  const AMSFilamentSettings({
    required this.trayInfoIdx,
    required this.nozzleTempMin,
    required this.nozzleTempMax,
    required this.trayType,
  });

  final String trayInfoIdx;
  final int nozzleTempMin;
  final int nozzleTempMax;
  final String trayType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AMSFilamentSettings &&
          trayInfoIdx == other.trayInfoIdx &&
          nozzleTempMin == other.nozzleTempMin &&
          nozzleTempMax == other.nozzleTempMax &&
          trayType == other.trayType;

  @override
  int get hashCode => Object.hash(
        trayInfoIdx,
        nozzleTempMin,
        nozzleTempMax,
        trayType,
      );
}

/// 耗材枚举 - 包含 Bambu 官方和通用耗材
enum Filament {
  // Bambu 品牌耗材
  polylitePla('GFL00', 190, 250, 'PLA'),
  polyterraPla('GFL01', 190, 250, 'PLA'),
  bambuAbs('GFB00', 240, 270, 'ABS'),
  bambuPaCf('GFN03', 270, 300, 'PA-CF'),
  bambuPc('GFC00', 260, 280, 'PC'),
  bambuPlaBasic('GFA00', 190, 250, 'PLA'),
  bambuPlaMatte('GFA01', 190, 250, 'PLA'),
  supportG('GFS01', 190, 250, 'PA-S'),
  supportW('GFS00', 190, 250, 'PLA-S'),
  bambuTpu95a('GFU01', 200, 250, 'TPU'),
  bambuAsaAero('GFB02', 240, 280, 'ASA'),
  bambuPlaMetal('GFA02', 190, 230, 'PLA'),
  bambuPetgTranslucent('GFG01', 230, 260, 'PETG'),
  bambuPlaMarble('GFA07', 190, 230, 'PLA'),
  bambuPlaWood('GFA16', 190, 240, 'PLA'),
  bambuPlaSilkPlus('GFA06', 210, 240, 'PLA'),
  bambuPetgHf('GFG02', 230, 260, 'PETG'),
  bambuTpuForAms('GFU02', 230, 230, 'TPU'),
  bambuSupportForAbs('GFS06', 190, 220, 'Support'),
  bambuPcFr('GFC01', 260, 280, 'PC'),
  bambuPlaGalaxy('GFA15', 190, 230, 'PLA'),
  bambuPa6Gf('GFN08', 260, 290, 'PA6'),
  bambuPlaAero('GFA11', 220, 260, 'PLA'),
  bambuAsaCf('GFB51', 250, 280, 'ASA'),
  bambuPetgCf('GFG50', 240, 270, 'PETG'),
  bambuSupportForPaPet('GFS03', 280, 300, 'Support'),
  bambuPlaSparkle('GFA08', 190, 230, 'PLA'),
  bambuAbsGf('GFB50', 240, 270, 'ABS'),
  bambuPahtCf('GFN04', 260, 290, 'PAHT'),
  bambuPlaBasic2('GFA00', 190, 230, 'PLA'),
  bambuPlaMatte2('GFA01', 190, 230, 'PLA'),
  bambuPa6Cf('GFN05', 260, 290, 'PA6'),
  bambuPlaSilk('GFA05', 210, 230, 'PLA'),
  bambuPva('GFS04', 220, 250, 'PVA'),
  bambuPlaCf('GFA50', 210, 240, 'PLA'),
  bambuSupportForPlaPetg('GFS05', 190, 220, 'Support'),
  bambuTpu95aHf('GFU00', 230, 230, 'TPU'),
  bambuPpaCf('GFN06', 280, 310, 'PPA'),
  bambuAsa('GFB01', 240, 270, 'ASA'),
  bambuPlaGlow('GFA12', 190, 230, 'PLA'),

  // 通用耗材
  abs('GFB99', 240, 270, 'ABS'),
  asa('GFB98', 240, 270, 'ASA'),
  pa('GFN99', 270, 300, 'PA'),
  paCf('GFN98', 270, 300, 'PA'),
  pc('GFC99', 260, 280, 'PC'),
  petg('GFG99', 220, 260, 'PETG'),
  pla('GFL99', 190, 250, 'PLA'),
  plaCf('GFL98', 190, 250, 'PLA'),
  pva('GFS99', 190, 250, 'PVA'),
  tpu('GFU99', 200, 250, 'TPU');

  const Filament(
    this.trayInfoIdx,
    this.nozzleTempMin,
    this.nozzleTempMax,
    this.trayType,
  );

  final String trayInfoIdx;
  final int nozzleTempMin;
  final int nozzleTempMax;
  final String trayType;

  /// 转换为 AMSFilamentSettings
  AMSFilamentSettings get settings => AMSFilamentSettings(
        trayInfoIdx: trayInfoIdx,
        nozzleTempMin: nozzleTempMin,
        nozzleTempMax: nozzleTempMax,
        trayType: trayType,
      );

  /// 从 tray_info_idx 查找耗材
  static Filament? fromTrayInfoIdx(String idx) {
    for (final f in Filament.values) {
      if (f.trayInfoIdx == idx) return f;
    }
    return null;
  }

  /// 中文显示名称
  String get displayName {
    final name = toString().split('.').last;
    return name
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .toUpperCase();
  }
}
