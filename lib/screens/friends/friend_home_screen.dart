import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/anniversary.dart';
import '../../providers/anniversary_provider.dart';
import '../../providers/friends_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _displayName = widget.friendName;
    Future.microtask(() {
      ref.read(anniversaryProvider.notifier).loadForFriend(widget.friendId);
    });
  }

  Future<void> _addAnniversary() async {
    final nameCtrl = TextEditingController();
    DateTime date = DateTime.now();

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
                        prefixIcon: Icon(Icons.favorite_border_rounded),
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
                            .add(widget.friendId, name, date);
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

  @override
  Widget build(BuildContext context) {
    final anniState = ref.watch(anniversaryProvider);
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
                    gradient: const LinearGradient(
                      colors: [
                        AppColorTokens.primary,
                        AppColorTokens.primaryGradientEnd,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColorTokens.primary.withAlpha(40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0] : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
          else if (anniState.error != null && anniState.anniversaries.isEmpty)
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
          else if (anniState.anniversaries.isEmpty)
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
            ...anniState.anniversaries.map(
              (a) => _AnniversaryCard(
                anniversary: a,
                onDelete: a.canEdit ? () => _deleteAnniversary(a) : null,
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

  const _AnniversaryCard({required this.anniversary, this.onDelete});

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
                  Icons.favorite_rounded,
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
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 13,
              color: AppColorTokens.textSecondary,
            ),
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
