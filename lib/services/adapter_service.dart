import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class AdapterInfo {
  final String schoolId;
  final String adapterId;
  final String adapterName;
  final String importUrl;
  final String jsFile;
  final String maintainer;
  final String category;
  final String resourceFolder;

  const AdapterInfo({
    required this.schoolId,
    required this.adapterId,
    required this.adapterName,
    required this.importUrl,
    required this.jsFile,
    required this.maintainer,
    required this.category,
    required this.resourceFolder,
  });

  factory AdapterInfo.fromYaml(Map<dynamic, dynamic> map) => AdapterInfo(
    schoolId: map['school_id'] as String? ?? '',
    adapterId: map['adapter_id'] as String? ?? '',
    adapterName: map['adapter_name'] as String? ?? '',
    importUrl: map['import_url'] as String? ?? '',
    jsFile: map['js_file'] as String? ?? '',
    maintainer: map['maintainer'] as String? ?? '',
    category: map['category'] as String? ?? '',
    resourceFolder: map['resource_folder'] as String? ?? '',
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
    final yamlStr = await rootBundle.loadString(
      'index/schools_index.yaml',
    );
    final doc = loadYaml(yamlStr) as Map<dynamic, dynamic>;
    final list = doc['schools'] as List<dynamic>;
    _index = list
        .map((e) => AdapterInfo.fromYaml(e as Map<dynamic, dynamic>))
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

  Future<String?> loadAdapterJs(AdapterInfo adapter) async {
    final key = '${adapter.resourceFolder}/${adapter.jsFile}';
    final cached = _jsCache[key];
    if (cached != null) return cached;
    try {
      final js = await rootBundle.loadString('resources/$key');
      _jsCache[key] = js;
      return js;
    } catch (_) {
      return null;
    }
  }
}
