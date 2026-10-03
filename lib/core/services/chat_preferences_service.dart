import 'package:shared_preferences/shared_preferences.dart';

class ChatPreferencesService {
  static const _wallpaperPrefix = 'chat_pref_wallpaper_';
  static const _fontSizePrefix = 'chat_pref_font_size_';

  Future<String?> getWallpaper(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_wallpaperPrefix$chatId');
  }

  Future<void> setWallpaper(String chatId, String wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_wallpaperPrefix$chatId', wallpaper);
  }

  Future<double?> getFontSize(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_fontSizePrefix$chatId');
  }

  Future<void> setFontSize(String chatId, double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_fontSizePrefix$chatId', size.clamp(10.0, 24.0));
  }
}