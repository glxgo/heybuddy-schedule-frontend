import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/bottom_sheet_helper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';
import '../../widgets/spring_button.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildAppBottomSheetFrame(
        ctx,
        alignment: Alignment.center,
        left: 18,
        right: 18,
        top: 40,
        maxWidth: 460,
        maxHeightFactor: 0.6,
        bottomNavClearance: 72,
        child: GlassCard(
          borderRadius: 28,
          padding: const EdgeInsets.all(22),
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
              const SizedBox(height: 22),
              const Text(
                '添加好友',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '输入对方手机号，发送好友请求',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColorTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: '好友手机号',
                  hintText: '请输入对方的手机号',
                  prefixIcon: Icon(Icons.phone_iphone_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              SpringButton(
                onTap: () async {
                  final phone = _phoneCtrl.text.trim();
                  if (phone.length != 11) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
                    return;
                  }
                  Navigator.pop(ctx);
                  final msg = await ref
                      .read(friendsProvider.notifier)
                      .addFriend(phone);
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: const Text('发送好友请求'),
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
    final state = ref.watch(friendsProvider);

    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('好友'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showAddDialog,
            tooltip: '添加好友',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColorTokens.primary),
            )
          : state.friends.isEmpty &&
                state.pendingRequests.isEmpty &&
                state.outgoingRequests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColorTokens.primary.withAlpha(28),
                          border: Border.all(
                            color: AppColorTokens.primary.withAlpha(70),
                          ),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          size: 38,
                          color: AppColorTokens.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '还没有好友',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '通过手机号添加好友，即可互相查看课表',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColorTokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SpringButton(
                        onTap: _showAddDialog,
                        child: const Text('添加好友'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
              children: [
                if (state.pendingRequests.isNotEmpty) ...[
                  const _SectionLabel('好友请求'),
                  ...state.pendingRequests.map(
                    (f) => _FriendCard(
                      friend: f,
                      subtitle: '请求添加你为好友',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final msg = await ref
                                  .read(friendsProvider.notifier)
                                  .rejectRequest(f.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                            child: const Text(
                              '拒绝',
                              style: TextStyle(
                                color: AppColorTokens.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final msg = await ref
                                  .read(friendsProvider.notifier)
                                  .acceptRequest(f.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                            child: const Text('接受'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.outgoingRequests.isNotEmpty) ...[
                  const _SectionLabel('已发送请求'),
                  ...state.outgoingRequests.map(
                    (f) => _FriendCard(
                      friend: f,
                      subtitle: '等待 ${f.nickname} 接受你的好友申请',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.friends.isNotEmpty) const _SectionLabel('我的好友'),
                ...state.friends.map(
                  (f) => _FriendCard(
                    friend: f,
                    subtitle: f.schoolName ?? '相伴课表好友',
                    onTap: () => context.push('/friend-home', extra: {
                      'friendshipId': f.id,
                      'friendId': f.friendId,
                      'friendName': f.nickname,
                      'originalNickname': f.originalNickname,
                      'avatarUrl': f.avatarUrl,
                      'schoolName': f.schoolName,
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColorTokens.textTertiary,
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendInfo friend;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _FriendCard({
    required this.friend,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 22,
      onTap: onTap,
      child: Row(
        children: [
          _Avatar(name: friend.nickname),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.nickname,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColorTokens.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing ??
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

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColorTokens.primary, AppColorTokens.primaryGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColorTokens.primary.withAlpha(38),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}


