import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/school.dart';
import '../services/school_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_scaffold.dart';

final schoolServiceProvider = Provider<SchoolService>((ref) => SchoolService());

String _getInitial(String name) {
  if (name.isEmpty) return '#';
  final c = name[0];
  if (RegExp(r'[a-zA-Z]').hasMatch(c)) return c.toUpperCase();
  const map = {
    '北': 'B',
    '上': 'S',
    '天': 'T',
    '重': 'C',
    '黑': 'H',
    '吉': 'J',
    '辽': 'L',
    '河': 'H',
    '山': 'S',
    '陕': 'S',
    '甘': 'G',
    '宁': 'N',
    '青': 'Q',
    '新': 'X',
    '内': 'N',
    '江': 'J',
    '浙': 'Z',
    '安': 'A',
    '福': 'F',
    '湖': 'H',
    '广': 'G',
    '海': 'H',
    '四': 'S',
    '贵': 'G',
    '云': 'Y',
    '西': 'X',
    '中': 'Z',
    '大': 'D',
    '东': 'D',
    '南': 'N',
    '武': 'W',
    '成': 'C',
    '长': 'C',
    '厦': 'X',
    '郑': 'Z',
    '哈': 'H',
    '兰': 'L',
    '太': 'T',
    '济': 'J',
    '合': 'H',
    '桂': 'G',
    '石': 'S',
    '三': 'S',
    '深': 'S',
    '苏': 'S',
    '沈': 'S',
    '昆': 'K',
  };
  return map[c] ?? '#';
}

class _SchoolGroup {
  final String initial;
  final List<School> schools;
  const _SchoolGroup(this.initial, this.schools);
}

class SchoolSelectScreen extends ConsumerStatefulWidget {
  const SchoolSelectScreen({super.key});

  @override
  ConsumerState<SchoolSelectScreen> createState() => _SchoolSelectScreenState();
}

class _SchoolSelectScreenState extends ConsumerState<SchoolSelectScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<_SchoolGroup> _groups = [];
  List<School> _results = [];
  List<String> _initials = [];
  bool _loading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(schoolServiceProvider);
    final provinceGroups = await svc.loadSchools();
    if (!mounted) return;
    final allSchools = provinceGroups.expand((g) => g.schools).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final grouped = <String, List<School>>{};
    for (final s in allSchools) {
      final init = _getInitial(s.name);
      grouped.putIfAbsent(init, () => []).add(s);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    setState(() {
      _groups = sortedKeys.map((k) => _SchoolGroup(k, grouped[k]!)).toList();
      _initials = sortedKeys;
      _loading = false;
    });
  }

  void _search(String q) async {
    final svc = ref.read(schoolServiceProvider);
    final results = await svc.search(q.trim());
    if (!mounted) return;
    setState(() {
      _isSearching = q.trim().isNotEmpty;
      _results = results;
    });
  }

  void _goImport(School school) {
    context.push(
      '/import/webview',
      extra: {
        'schoolName': school.name,
        'systemUrl': school.url,
        'systemType': school.type,
        'schoolId': school.schoolId ?? '',
      },
    );
  }

  void _scrollToInitial(String initial) {
    final idx = _groups.indexWhere((g) => g.initial == initial);
    if (idx >= 0 && _scrollCtrl.hasClients) {
      var offset = 78.0;
      for (var i = 0; i < idx; i++) {
        offset += 34 + _groups[i].schools.length * 76.0;
      }
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.read(schoolServiceProvider);
    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('选择学校'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${svc.totalSchools}所',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColorTokens.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: GlassCard(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              elevation: 0.8,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: '搜索学校名称...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColorTokens.primary),
              ),
            ),
          if (!_loading && _isSearching)
            Expanded(
              child: _results.isEmpty
                  ? const _EmptySearchState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _results.length,
                      itemBuilder: (context, i) => _SchoolTile(
                        school: _results[i],
                        onTap: () => _goImport(_results[i]),
                      ),
                    ),
            ),
          if (!_loading && !_isSearching)
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 28, 28),
                    itemCount: _groups.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(14),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColorTokens.warning,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '如果未找到您的学校，说明还未适配，请先使用 AI 拍照识别功能，您也可以参与适配',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColorTokens.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final group = _groups[idx - 1];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                            child: Text(
                              group.initial,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColorTokens.primary,
                              ),
                            ),
                          ),
                          ...group.schools.map(
                            (s) => _SchoolTile(
                              school: s,
                              onTap: () => _goImport(s),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Positioned(
                    right: 2,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColorTokens.surfaceGlass.withAlpha(160),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColorTokens.glassBorder.withAlpha(120),
                          ),
                        ),
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            final renderBox =
                                context.findRenderObject() as RenderBox?;
                            if (renderBox == null || _initials.isEmpty) {
                              return;
                            }
                            final localPos = renderBox.globalToLocal(
                              details.globalPosition,
                            );
                            final itemHeight =
                                (renderBox.size.height - 100) /
                                _initials.length.clamp(1, 30);
                            final idx = (localPos.dy / itemHeight)
                                .toInt()
                                .clamp(0, _initials.length - 1);
                            _scrollToInitial(_initials[idx]);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _initials
                                .map(
                                  (l) => GestureDetector(
                                    onTap: () => _scrollToInitial(l),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: Center(
                                        child: Text(
                                          l,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColorTokens.textTertiary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 50,
              color: AppColorTokens.textTertiary.withAlpha(120),
            ),
            const SizedBox(height: 12),
            const Text(
              '未找到匹配的学校',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColorTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolTile extends StatelessWidget {
  final School school;
  final VoidCallback onTap;

  const _SchoolTile({required this.school, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = school.maintainer != null && school.maintainer!.isNotEmpty
        ? '适配者: @${school.maintainer} · ${school.systemLabel}'
        : school.systemLabel;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 22,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColorTokens.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColorTokens.primary.withAlpha(48)),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppColorTokens.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColorTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColorTokens.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColorTokens.textTertiary,
          ),
        ],
      ),
    );
  }
}
