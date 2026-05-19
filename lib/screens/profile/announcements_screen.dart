import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_sheet_helper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _readIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.get('/announcements');
    if (!mounted) return;
    setState(() {
      _items = res.isSuccess && res.data is List
          ? (res.data as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [];
      _loading = false;
    });
  }

  Future<void> _markRead(String id) async {
    if (_readIds.contains(id)) return;
    final res = await ref.read(apiServiceProvider).post('/announcements/$id/read');
    if (!mounted || !res.isSuccess) return;
    setState(() => _readIds.add(id));
  }

  Future<void> _openAnnouncement(Map<String, dynamic> item) async {
    final settings = ref.read(settingsProvider);
    final theme = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final primary = _solid(theme.orbPrimary);
    final secondary = _solid(theme.orbSecondary);
    final id = (item['id'] ?? '').toString();
    final summary = (item['summary'] ?? '').toString().trim();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => buildAppBottomSheetFrame(
        ctx,
        alignment: Alignment.center,
        left: 16,
        right: 16,
        top: 40,
        maxWidth: 560,
        maxHeightFactor: 0.78,
        bottomNavClearance: 72,
        child: GlassCard(
          borderRadius: 30,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          elevation: 1.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primary.withAlpha(110),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (item['title'] ?? '系统公告').toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColorTokens.textPrimary,
                      ),
                    ),
                    if (item['pinned'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: secondary.withAlpha(24),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: secondary.withAlpha(80)),
                        ),
                        child: Text(
                          '置顶',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: secondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatPublishedAt((item['published_at'] ?? item['publishedAt'])?.toString()),
                  style: const TextStyle(fontSize: 12, color: AppColorTokens.textTertiary),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColorTokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(110),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(140)),
                  ),
                  child: Text(
                    (item['content'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.72,
                      color: AppColorTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (id.isNotEmpty) {
      await _markRead(id);
    }
  }

  Color _solid(Color color) {
    return color.withAlpha(255);
  }

  String _formatPublishedAt(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '系统发布';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final primary = _solid(theme.orbPrimary);
    final secondary = _solid(theme.orbSecondary);

    return LiquidScaffold(
      appBar: AppBar(title: const Text('系统公告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColorTokens.primary))
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
                  elevation: 1.3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withAlpha(24),
                          border: Border.all(color: primary.withAlpha(70)),
                        ),
                        child: Icon(Icons.campaign_outlined, size: 36, color: primary),
                      ),
                      const SizedBox(height: 18),
                      const Text('暂时没有公告', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('有新公告时会在这里显示', style: TextStyle(fontSize: 13, color: AppColorTokens.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final id = (item['id'] ?? '').toString();
                  final isRead = _readIds.contains(id);
                  final summary = (item['summary'] ?? '').toString().trim();
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    borderRadius: 26,
                    padding: const EdgeInsets.all(18),
                    elevation: 1.1,
                    onTap: () => _openAnnouncement(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primary.withAlpha(22),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primary.withAlpha(70)),
                              ),
                              child: Icon(Icons.campaign_outlined, color: primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (item['title'] ?? '系统公告').toString(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isRead ? AppColorTokens.textSecondary : AppColorTokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (item['pinned'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: secondary.withAlpha(24),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '置顶',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: secondary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatPublishedAt((item['published_at'] ?? item['publishedAt'])?.toString()),
                                    style: const TextStyle(fontSize: 12, color: AppColorTokens.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(left: 10, top: 4),
                                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            summary,
                            style: const TextStyle(fontSize: 14, height: 1.55, color: AppColorTokens.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
