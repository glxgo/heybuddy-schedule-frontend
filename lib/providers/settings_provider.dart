import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class SettingsState {
  final String backgroundThemeId;
  final List<String> friendOrder;

  const SettingsState({
    this.backgroundThemeId = AppBackgroundThemes.defaultId,
    this.friendOrder = const [],
  });

  SettingsState copyWith({
    String? backgroundThemeId,
    List<String>? friendOrder,
  }) {
    return SettingsState(
      backgroundThemeId: backgroundThemeId ?? this.backgroundThemeId,
      friendOrder: friendOrder ?? this.friendOrder,
    );
  }

  List<String> applyFriendOrder(List<String> friendIds) {
    if (friendOrder.isEmpty) return friendIds;
    final ordered = <String>[];
    for (final id in friendOrder) {
      if (friendIds.contains(id)) ordered.add(id);
    }
    for (final id in friendIds) {
      if (!ordered.contains(id)) ordered.add(id);
    }
    return ordered;
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _backgroundThemeKey = 'background_theme_id';
  static const _friendOrderKey = 'daily_friend_order';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId =
        prefs.getString(_backgroundThemeKey) ?? AppBackgroundThemes.defaultId;
    final orderJson = prefs.getString(_friendOrderKey);
    final friendOrder = orderJson != null
        ? (jsonDecode(orderJson) as List).cast<String>()
        : <String>[];
    state = SettingsState(backgroundThemeId: themeId, friendOrder: friendOrder);
  }

  Future<void> setBackgroundTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundThemeKey, value);
    state = state.copyWith(backgroundThemeId: value);
  }

  Future<void> setFriendOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_friendOrderKey, jsonEncode(order));
    state = state.copyWith(friendOrder: order);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
