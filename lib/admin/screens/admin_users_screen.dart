import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_users_provider.dart';
import '../widgets/admin_shell.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() {
    return ref.read(adminUsersProvider.notifier).search(_searchCtrl.text);
  }

  String _formatDate(DateTime? value, {String empty = '—'}) {
    if (value == null) return empty;
    return _dateFormat.format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    final state = ref.watch(adminUsersProvider);
    if (auth.isAuthenticated && !state.hasLoaded && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminUsersProvider.notifier).load();
      });
    }
    final start = state.total == 0 ? 0 : (state.page - 1) * state.pageSize + 1;
    final end = state.total == 0 ? 0 : math.min(state.total, state.page * state.pageSize);

    return AdminShell(
      title: '用户列表',
      subtitle: '查看用户账号、邮箱、手机号、注册时间和最近一次登录时间',
      selectedIndex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _search(),
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: '按账号 / 邮箱 / 手机号搜索',
                    hintText: '支持输入部分账号、邮箱或手机号',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(adminUsersProvider.notifier).search('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: state.isLoading ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: const Text('搜索'),
              ),
              OutlinedButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(adminUsersProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '当前显示 $start - $end / 共 ${state.total} 位用户',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColorTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (state.isLoading && state.items.isNotEmpty) const LinearProgressIndicator(),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColorTokens.error.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColorTokens.error.withAlpha(45)),
              ),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColorTokens.textPrimary),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                ? const Center(
                    child: Text(
                      '还没有符合条件的用户数据',
                      style: TextStyle(color: AppColorTokens.textSecondary),
                    ),
                  )
                : Scrollbar(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 52,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 72,
                          columns: const [
                            DataColumn(label: Text('账号')),
                            DataColumn(label: Text('邮箱')),
                            DataColumn(label: Text('手机号')),
                            DataColumn(label: Text('昵称')),
                            DataColumn(label: Text('注册时间')),
                            DataColumn(label: Text('上次登录')),
                          ],
                          rows: state.items
                              .map(
                                (user) => DataRow(
                                  cells: [
                                    DataCell(Text(user.account ?? '—')),
                                    DataCell(Text(user.email ?? '—')),
                                    DataCell(Text(user.phone ?? '—')),
                                    DataCell(Text(user.nickname ?? '—')),
                                    DataCell(Text(_formatDate(user.registeredAt))),
                                    DataCell(
                                      Text(
                                        _formatDate(
                                          user.lastLoginAt,
                                          empty: '未记录',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: state.isLoading || state.page <= 1
                    ? null
                    : () => ref.read(adminUsersProvider.notifier).previousPage(),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('上一页'),
              ),
              OutlinedButton.icon(
                onPressed: state.isLoading || state.page * state.pageSize >= state.total
                    ? null
                    : () => ref.read(adminUsersProvider.notifier).nextPage(),
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('下一页'),
              ),
              Text(
                '第 ${state.page} 页 · 每页 ${state.pageSize} 条',
                style: const TextStyle(color: AppColorTokens.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
