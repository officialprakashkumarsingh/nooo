import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static SettingsService get instance => _instance;

  static const String _webSearchEnabledKey = 'web_search_enabled';

  bool _webSearchEnabled = false;
  bool get webSearchEnabled => _webSearchEnabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _webSearchEnabled = prefs.getBool(_webSearchEnabledKey) ?? false;
  }

  Future<void> setWebSearchEnabled(bool enabled) async {
    _webSearchEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_webSearchEnabledKey, enabled);
  }
}