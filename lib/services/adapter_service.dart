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
    jsFile: map['asset_js_path'] as String? ?? '',
    maintainer: map['maintainer'] as String? ?? '',
    category: map['category'] as String? ?? '',
    resourceFolder: map['resource_folder'] as String? ?? '',
  );
}

class SchoolEntry {
  final String id;
  final String name;
  final String resourceFolder;

  const SchoolEntry({
    required this.id,
    required this.name,
    required this.resourceFolder,
  });
}

class AdapterService {
  static final AdapterService _instance = AdapterService._();
  factory AdapterService() => _instance;
  AdapterService._();

  List<SchoolEntry>? _schoolIndex;
  final Map<String, String> _jsCache = {};
  final Map<String, AdapterInfo> _adapterCache = {};

  Future<List<SchoolEntry>> loadIndex() async {
    if (_schoolIndex != null) return _schoolIndex!;
    final yamlStr = await rootBundle.loadString(
      'index/schools_index.yaml',
    );
    final doc = loadYaml(yamlStr) as Map<dynamic, dynamic>;
    final list = doc['schools'] as List<dynamic>;
    _schoolIndex = list.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return SchoolEntry(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        resourceFolder: m['resource_folder'] as String? ?? '',
      );
    }).toList();
    return _schoolIndex!;
  }

  Future<AdapterInfo?> loadAdapterYaml(String resourceFolder) async {
    final cached = _adapterCache[resourceFolder];
    if (cached != null) return cached;
    try {
      final yamlStr = await rootBundle.loadString(
        'resources/$resourceFolder/adapters.yaml',
      );
      final doc = loadYaml(yamlStr) as Map<dynamic, dynamic>;
      final adapters = doc['adapters'] as List<dynamic>;
      if (adapters.isEmpty) return null;
      final info = AdapterInfo.fromYaml(
        (adapters.first as Map<dynamic, dynamic>)..['resource_folder'] = resourceFolder,
      );
      _adapterCache[resourceFolder] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<AdapterInfo?> findAdapter(String schoolId) async {
    final index = await loadIndex();
    SchoolEntry? entry;
    try {
      entry = index.firstWhere((e) => e.id == schoolId);
    } catch (_) {
      return null;
    }
    return await loadAdapterYaml(entry.resourceFolder);
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
