class School {
  final String name;
  final String type;
  final String url;
  final String? maintainer;
  final String? adapterId;
  final String? schoolId;

  const School({
    required this.name,
    required this.type,
    required this.url,
    this.maintainer,
    this.adapterId,
    this.schoolId,
  });

  factory School.fromJson(Map<String, dynamic> json) => School(
    name: json['name'] as String,
    type: json['type'] as String? ?? 'generic',
    url: json['url'] as String? ?? '',
    maintainer: json['maintainer'] as String?,
    adapterId: json['adapterId'] as String?,
    schoolId: json['schoolId'] as String?,
  );

  String get systemLabel {
    switch (type) {
      case 'zhengfang':
        return '正方教务';
      case 'qiangzhi':
        return '强智教务';
      case 'qingguo':
        return '青果教务';
      case 'urp':
        return 'URP教务';
      case 'jinzhi':
        return '金智教务';
      default:
        return '通用';
    }
  }
}

class ProvinceGroup {
  final String name;
  final List<School> schools;

  const ProvinceGroup({required this.name, required this.schools});
}
