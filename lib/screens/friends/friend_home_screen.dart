import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/anniversary.dart';
import '../../providers/anniversary_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_sheet_helper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';
import '../../widgets/spring_button.dart';

class FriendHomeScreen extends ConsumerStatefulWidget {
  final String friendshipId;
  final String friendId;
  final String friendName;
  final String? originalNickname;
  final String? avatarUrl;
  final String? schoolName;

  const FriendHomeScreen({
    super.key,
    required this.friendshipId,
    required this.friendId,
    required this.friendName,
    this.originalNickname,
    this.avatarUrl,
    this.schoolName,
  });

  @override
  ConsumerState<FriendHomeScreen> createState() => _FriendHomeScreenState();
}

class _FriendHomeScreenState extends ConsumerState<FriendHomeScreen> {
  late String _displayName;
  Map<String, dynamic>? _relationship;

  static const _relationLabels = {
    'couple': '情侣',
    'bestie': '闺蜜',
    'roommate': '室友',
    'classmate': '同学',
    'other': '好友',
  };

  String _labelFor(String type) => _relationLabels[type] ?? type;

  int? get _boundDays {
    if (_relationship == null || _relationship!['status'] != 'accepted') return null;
    final created = _relationship!['created_at'];
    if (created == null) return null;
    final boundAt = DateTime.tryParse(created.toString());
    if (boundAt == null) return null;
    return DateTime.now().difference(boundAt).inDays;
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.friendName;
    Future.microtask(() {
      ref.read(anniversaryProvider.notifier).loadForFriend(widget.friendId);
      _loadRelationship();
    });
  }

  Future<void> _loadRelationship() async {
    final res = await ref.read(apiServiceProvider).get('/friends/${widget.friendId}/relationship');
    if (mounted && res.isSuccess) {
      setState(() => _relationship = res.data is Map ? Map<String, dynamic>.from(res.data) : null);
    }
  }

  Future<void> _addAnniversary() async {
    final nameCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String visibility = 'shared';

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return buildAppBottomSheetFrame(
            ctx,
            alignment: Alignment.center,
            left: 18,
            right: 18,
            top: 48,
            maxWidth: 480,
            maxHeightFactor: 0.72,
            bottomNavClearance: 72,
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(22),
              elevation: 1.5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColorTokens.primary.withAlpha(90),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '添加纪念日',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '记录你们的专属纪念日',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColorTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '纪念日名称',
                        hintText: '例如：相恋纪念日',
                        prefixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheetState(() => date = picked);
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: AppColorTokens.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${date.year}年${date.month}月${date.day}日',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            '选择日期',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColorTokens.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          '可见性：',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('双方可见'),
                          selected: visibility == 'shared',
                          onSelected: (_) => setSheetState(() => visibility = 'shared'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('仅自己可见'),
                          selected: visibility == 'private',
                          onSelected: (_) => setSheetState(() => visibility = 'private'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SpringButton(
                      onTap: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('请输入纪念日名称')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                        final msg = await ref
                            .read(anniversaryProvider.notifier)
                            .add(widget.friendId, name, date, visibility: visibility);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      },
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editRemark() async {
    final ctrl = TextEditingController(
      text: widget.originalNickname == null ||
              widget.originalNickname!.isEmpty ||
              widget.originalNickname == _displayName
          ? _displayName
          : _displayName,
    );
    final remark = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改好友备注'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: widget.originalNickname?.isNotEmpty == true
                ? '原昵称：${widget.originalNickname}'
                : '请输入备注',
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('清除备注'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (remark == null) return;
    final msg = await ref
        .read(friendsProvider.notifier)
        .updateRemark(widget.friendshipId, remark);
    if (!mounted) return;
    final success = !msg.contains('不可用') && !msg.contains('不存在') && !msg.contains('异常');
    if (success) {
      setState(() {
        _displayName = remark.isEmpty
            ? ((widget.originalNickname?.isNotEmpty == true)
                  ? widget.originalNickname!
                  : widget.friendName)
            : remark;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteAnniversary(Anniversary anniversary) async {
    final msg = await ref
        .read(anniversaryProvider.notifier)
        .delete(widget.friendId, anniversary.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _editAnniversary(Anniversary anniversary) async {
    final nameCtrl = TextEditingController(text: anniversary.name);
    DateTime date = anniversary.targetDate;
    String visibility = anniversary.visibility;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return buildAppBottomSheetFrame(
            ctx,
            alignment: Alignment.center,
            left: 18,
            right: 18,
            top: 48,
            maxWidth: 480,
            maxHeightFactor: 0.78,
            bottomNavClearance: 72,
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(22),
              elevation: 1.5,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 38, height: 4,
                      decoration: BoxDecoration(
                        color: AppColorTokens.primary.withAlpha(90),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('编辑纪念日', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('修改纪念日信息', style: TextStyle(fontSize: 13, color: AppColorTokens.textSecondary)),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '纪念日名称',
                        prefixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 20, color: AppColorTokens.primary),
                          const SizedBox(width: 12),
                          Text('${date.year}年${date.month}月${date.day}日', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          const Text('选择日期', style: TextStyle(fontSize: 13, color: AppColorTokens.textTertiary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('可见性：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('双方可见'),
                          selected: visibility == 'shared',
                          onSelected: (_) => setSheetState(() => visibility = 'shared'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('仅自己可见'),
                          selected: visibility == 'private',
                          onSelected: (_) => setSheetState(() => visibility = 'private'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SpringButton(
                      onTap: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请输入纪念日名称')));
                          return;
                        }
                        Navigator.pop(ctx, true);
                        final msg = await ref.read(anniversaryProvider.notifier).update(
                          widget.friendId, anniversary.id, name, date,
                          visibility: visibility,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bindRelationship() async {
    final types = ['couple', 'bestie', 'roommate', 'classmate', 'other'];
    final labels = ['情侣', '闺蜜', '室友', '同学', '其他'];
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('选择关系类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ...List.generate(types.length, (i) => ListTile(
              title: Text(labels[i]),
              leading: Icon(i == 0 ? Icons.favorite : i == 1 ? Icons.people : Icons.star, color: AppColorTokens.primary),
              onTap: () => Navigator.pop(ctx, types[i]),
            )),
          ],
        ),
      ),
    );
    if (result == null) return;
    final api = ref.read(apiServiceProvider);
    final res = await api.post('/friends/${widget.friendId}/relationship', data: {'relationType': result});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.msg)));
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildAppBottomSheetFrame(
        ctx,
        alignment: Alignment.center,
        left: 18,
        right: 18,
        top: 80,
        maxWidth: 460,
        maxHeightFactor: 0.65,
        bottomNavClearance: 72,
        child: GlassCard(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          elevation: 1.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColorTokens.primary.withAlpha(90),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColorTokens.primary,
                  ),
                  title: const Text(
                    '修改备注',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editRemark();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: AppColorTokens.primary),
                  title: const Text('绑定关系', style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () { Navigator.pop(ctx); _bindRelationship(); },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColorTokens.primary,
                  ),
                  title: const Text(
                    '发消息',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/chat',
                      extra: {
                        'friendId': widget.friendId,
                        'friendName': _displayName,
                      },
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColorTokens.error,
                  ),
                  title: const Text(
                    '删除好友',
                    style: TextStyle(
                      color: AppColorTokens.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final msg = await ref
                        .read(friendsProvider.notifier)
                        .deleteFriend(widget.friendshipId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                    if (context.mounted) context.pop();
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        _displayName.isNotEmpty ? _displayName[0] : '?',
        style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anniState = ref.watch(anniversaryProvider);
    final anniversaryStateMatchesFriend =
        anniState.friendId.isEmpty || anniState.friendId == widget.friendId;
    final anniversaries = anniversaryStateMatchesFriend
        ? anniState.anniversaries
        : const <Anniversary>[];
    final showOriginalNickname =
        widget.originalNickname != null &&
        widget.originalNickname!.isNotEmpty &&
        widget.originalNickname != _displayName;

    return LiquidScaffold(
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addAnniversary,
            tooltip: '添加纪念日',
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: _showMenu,
            tooltip: '更多',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          GlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(18),
            elevation: 1.2,
            gradient: LinearGradient(
              colors: [
                AppColorTokens.surfaceGlassStrong,
                AppColorTokens.primary.withAlpha(18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.avatarUrl == null ? const LinearGradient(
                      colors: [AppColorTokens.primary, AppColorTokens.primaryGradientEnd],
                    ) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColorTokens.primary.withAlpha(40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: widget.avatarUrl != null
                      ? ClipOval(child: Image.network(widget.avatarUrl!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitial()))
                      : _buildInitial(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (showOriginalNickname) ...[
                        const SizedBox(height: 4),
                        Text(
                          '原昵称：${widget.originalNickname}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColorTokens.textSecondary,
                          ),
                        ),
                      ],
                      if (widget.schoolName != null &&
                          widget.schoolName!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.schoolName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColorTokens.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_relationship != null && _relationship!['status'] == 'accepted')
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 16, color: AppColorTokens.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${_labelFor(_relationship!['relation_type'] ?? 'friend')} · 已绑定 ${_boundDays ?? 0} 天',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColorTokens.primary),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _bindRelationship,
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text('绑定关系'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _EntryTile(
                  icon: Icons.calendar_view_week_rounded,
                  title: '好友课表',
                  subtitle: '查看 $_displayName 的完整周课表',
                  onTap: () => context.push(
                    '/friend-schedule',
                    extra: {
                      'friendId': widget.friendId,
                      'friendName': _displayName,
                    },
                  ),
                ),
                _EntryTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '发消息',
                  subtitle: '和 $_displayName 聊聊最近的课程安排',
                  onTap: () => context.push(
                    '/chat',
                    extra: {
                      'friendId': widget.friendId,
                      'friendName': _displayName,
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: _SectionLabel('纪念日')),
              TextButton.icon(
                onPressed: _addAnniversary,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增'),
              ),
            ],
          ),
          if (anniState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColorTokens.primary),
              ),
            )
          else if (anniState.error != null && anniversaries.isEmpty)
            GlassCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 28,
              ),
              child: Center(
                child: Text(
                  anniState.error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (anniversaries.isEmpty)
            GlassCard(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 28,
              ),
              child: const Center(
                child: Text(
                  '还没有纪念日，点击右上角 + 或“新增”来添加',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...anniversaries.map(
              (a) => _AnniversaryCard(
                anniversary: a,
                onDelete: a.canEdit ? () => _deleteAnniversary(a) : null,
                onEdit: a.canEdit ? () => _editAnniversary(a) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColorTokens.primary.withAlpha(16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColorTokens.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColorTokens.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColorTokens.textTertiary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColorTokens.textTertiary,
        ),
      ),
    );
  }
}

class _AnniversaryCard extends StatelessWidget {
  final Anniversary anniversary;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _AnniversaryCard({required this.anniversary, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final daysSince = anniversary.daysSince;
    final daysUntil = anniversary.daysUntilNext;
    final dateStr =
        '${anniversary.targetDate.year}年${anniversary.targetDate.month}月${anniversary.targetDate.day}日';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      elevation: 1.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColorTokens.primary,
                      AppColorTokens.primaryGradientEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColorTokens.primary.withAlpha(30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  anniversary.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColorTokens.textPrimary,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColorTokens.textTertiary),
                  onPressed: onEdit,
                  tooltip: '编辑纪念日',
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColorTokens.textTertiary,
                  ),
                  onPressed: onDelete,
                  tooltip: '删除纪念日',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                label: '已经',
                value: '$daysSince 天',
                color: AppColorTokens.primary,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: '还有',
                value: '$daysUntil 天',
                color: AppColorTokens.accent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                dateStr,
                style: const TextStyle(fontSize: 13, color: AppColorTokens.textSecondary),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: anniversary.visibility == 'private' ? AppColorTokens.warning.withAlpha(30) : AppColorTokens.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  anniversary.visibility == 'private' ? '仅自己可见' : '双方可见',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: anniversary.visibility == 'private' ? AppColorTokens.warning : AppColorTokens.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withAlpha(180),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
