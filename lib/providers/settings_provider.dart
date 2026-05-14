import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class SettingsState {
  final String backgroundThemeId;

  const SettingsState({this.backgroundThemeId = AppBackgroundThemes.defaultId});

  SettingsState copyWith({String? backgroundThemeId}) {
    return SettingsState(
      backgroundThemeId: backgroundThemeId ?? this.backgroundThemeId,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const _backgroundThemeKey = 'background_theme_id';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId =
        prefs.getString(_backgroundThemeKey) ?? AppBackgroundThemes.defaultId;
    state = SettingsState(backgroundThemeId: themeId);
  }

  Future<void> setBackgroundTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundThemeKey, value);
    state = state.copyWith(backgroundThemeId: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
