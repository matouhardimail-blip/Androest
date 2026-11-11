import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CloudProviderConfig {
  final String id;
  final String name;
  final String providerType; // "openai" أو "anthropic"
  final String apiKey;
  final String baseUrl;
  final String modelName;

  CloudProviderConfig({
    required this.id,
    required this.name,
    required this.providerType,
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'providerType': providerType,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'modelName': modelName,
  };

  factory CloudProviderConfig.fromJson(Map<String, dynamic> json) => CloudProviderConfig(
    id: json['id'],
    name: json['name'],
    providerType: json['providerType'],
    apiKey: json['apiKey'],
    baseUrl: json['baseUrl'],
    modelName: json['modelName'],
  );
}

class CloudConfigManager {
  static const String _key = 'cloud_providers_list';

  static Future<List<CloudProviderConfig>> loadProviders() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => CloudProviderConfig.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveProviders(List<CloudProviderConfig> providers) async {
    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(providers.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }
}