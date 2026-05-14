import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/school.dart';

class SchoolService {
  List<ProvinceGroup>? _cache;
  List<School>? _flatList;

  Future<List<ProvinceGroup>> loadSchools() async {
    if (_cache != null) return _cache!;

    final jsonStr = await rootBundle.loadString('assets/schools/schools.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final provinces = data['provinces'] as Map<String, dynamic>;

    final result = <ProvinceGroup>[];
    final flat = <School>[];
    for (final entry in provinces.entries) {
      final schools = (entry.value as List)
          .map((e) => School.fromJson(e as Map<String, dynamic>))
          .toList();
      result.add(ProvinceGroup(name: entry.key, schools: schools));
      flat.addAll(schools);
    }
    _cache = result;
    _flatList = flat;
    return result;
  }

  Future<List<School>> search(String query) async {
    if (_flatList == null) await loadSchools();
    if (query.isEmpty) return _flatList!;
    final q = query.toLowerCase();
    return _flatList!
        .where(
          (s) => s.name.toLowerCase().contains(q) || s.systemLabel.contains(q),
        )
        .toList();
  }

  int get totalSchools {
    return _flatList?.length ?? 0;
  }
}
