import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AdapterInfo {
  final String schoolId;
  final String adapterId;
  final String adapterName;
  final String importUrl;
  final String jsFile;
  final String maintainer;
  final String category;

  const AdapterInfo({
    required this.schoolId,
    required this.adapterId,
    required this.adapterName,
    required this.importUrl,
    required this.jsFile,
    required this.maintainer,
    required this.category,
  });

  factory AdapterInfo.fromJson(Map<String, dynamic> json) => AdapterInfo(
    schoolId: json['schoolId'] as String? ?? '',
    adapterId: json['adapterId'] as String? ?? '',
    adapterName: json['adapterName'] as String? ?? '',
    importUrl: json['importUrl'] as String? ?? '',
    jsFile: json['jsFile'] as String? ?? '',
    maintainer: json['maintainer'] as String? ?? '',
    category: json['category'] as String? ?? '',
  );
}

class AdapterService {
  static final AdapterService _instance = AdapterService._();
  factory AdapterService() => _instance;
  AdapterService._();

  List<AdapterInfo>? _index;
  final Map<String, String> _jsCache = {};

  Future<List<AdapterInfo>> loadIndex() async {
    if (_index != null) return _index!;
    final jsonStr = await rootBundle.loadString(
      'assets/adapters/schools_index.json',
    );
    final list = json.decode(jsonStr) as List<dynamic>;
    _index = list
        .map((e) => AdapterInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    return _index!;
  }

  Future<AdapterInfo?> findAdapter(String schoolId) async {
    final index = await loadIndex();
    try {
      return index.firstWhere((a) => a.schoolId == schoolId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> loadAdapterJs(String jsFile) async {
    final cached = _jsCache[jsFile];
    if (cached != null) return cached;
    try {
      final js = await rootBundle.loadString('assets/adapters/$jsFile');
      _jsCache[jsFile] = js;
      return js;
    } catch (_) {
      return null;
    }
  }
}
