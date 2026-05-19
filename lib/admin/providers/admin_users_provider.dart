import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../services/admin_api_service.dart';

class AdminUsersState {
  final bool isLoading;
  final bool hasLoaded;
  final List<AdminUserSummary> items;
  final int total;
  final int page;
  final int pageSize;
  final String query;
  final String? error;

  const AdminUsersState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.query = '',
    this.error,
  });

  AdminUsersState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    List<AdminUserSummary>? items,
    int? total,
    int? page,
    int? pageSize,
    String? query,
    String? error,
    bool clearError = false,
  }) {
    return AdminUsersState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  final AdminApiService _api;

  AdminUsersNotifier(this._api) : super(const AdminUsersState());

  Future<void> load({int? page, String? query}) async {
    final nextPage = page ?? state.page;
    final nextQuery = query ?? state.query;
    state = state.copyWith(
      isLoading: true,
      page: nextPage,
      query: nextQuery,
      clearError: true,
    );

    try {
      final result = await _api.fetchUsers(
        page: nextPage,
        pageSize: state.pageSize,
        query: nextQuery,
      );
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        items: result.items,
        total: result.total,
        page: result.page,
        pageSize: result.pageSize,
        query: nextQuery,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: e.toString(),
      );
    }
  }

  Future<void> search(String query) {
    return load(page: 1, query: query.trim());
  }

  Future<void> refresh() {
    return load(page: state.page, query: state.query);
  }

  Future<void> previousPage() async {
    if (state.isLoading || state.page <= 1) return;
    await load(page: state.page - 1);
  }

  Future<void> nextPage() async {
    if (state.isLoading || state.page * state.pageSize >= state.total) return;
    await load(page: state.page + 1);
  }
}

final adminUsersProvider = StateNotifierProvider<AdminUsersNotifier, AdminUsersState>(
  (ref) => AdminUsersNotifier(AdminApiService.instance),
);
