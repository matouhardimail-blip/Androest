import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// المتحكم في الثيم (متاح لجميع الشاشات)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

class SettingsManager {
  static const String _keyUserName = 'user_name';
  static const String _keyDefaultProvider = 'default_provider_id';
  static const String _keyThemeMode = 'theme_mode'; 

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? "مستخدم AI HUB";
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  static Future<String?> getDefaultProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultProvider);
  }

  static Future<void> setDefaultProviderId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultProvider, id);
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString(_keyThemeMode) ?? 'dark';
    return mode == 'dark';
  }

  static Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, isDark ? 'dark' : 'light');
  }

  static Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 

    try {
      Directory workspaceDir = Directory('/storage/emulated/0/Download/AgentPhoneProjects');
      if (await workspaceDir.exists()) {
        await workspaceDir.delete(recursive: true);
      }
    } catch (e) {
      print("Error deleting workspace: $e");
    }
  }
}