import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../services/admin_api_service.dart';

class AdminDashboardState {
  final bool isLoading;
  final bool hasLoaded;
  final AdminStats? stats;
  final String? error;

  const AdminDashboardState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.stats,
    this.error,
  });

  AdminDashboardState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    AdminStats? stats,
    String? error,
    bool clearError = false,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      stats: stats ?? this.stats,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  final AdminApiService _api;

  AdminDashboardNotifier(this._api) : super(const AdminDashboardState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final stats = await _api.fetchStats();
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        stats: stats,
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
}

final adminDashboardProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>(
      (ref) => AdminDashboardNotifier(AdminApiService.instance),
    );
