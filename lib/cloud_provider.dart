import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum AgentCapability {
  textGeneration,    // LLM / Text Generation
  imageGeneration,   // Image Generation
  speechToText,      // Speech-to-Text
  textToSpeech,      // Text-to-Speech
  embeddings,        // Embeddings
  vision,            // Image Recognition / Vision
  videoGeneration,   // Video Generation
  audioGeneration,   // Music / Audio Generation
  translation,       // Translation
  summarization,     // Summarization / Extraction
  codeGeneration,    // Code Generation (Project Builder)
  search,            // Search / RAG
  moderation,        // Moderation / Safety
}

class CloudProviderConfig {
  final String id;
  final String name;
  final String providerType; // "openai", "anthropic", "custom"
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final List<AgentCapability> capabilities;

  CloudProviderConfig({
    required this.id,
    required this.name,
    required this.providerType,
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    required this.capabilities,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'providerType': providerType,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'modelName': modelName,
    'capabilities': capabilities.map((e) => e.name).toList(),
  };

  factory CloudProviderConfig.fromJson(Map<String, dynamic> json) {
    return CloudProviderConfig(
      id: json['id'],
      name: json['name'],
      providerType: json['providerType'],
      apiKey: json['apiKey'],
      baseUrl: json['baseUrl'],
      modelName: json['modelName'],
      capabilities: (json['capabilities'] as List?)?.map((e) {
            return AgentCapability.values.firstWhere(
              (cap) => cap.name == e,
              orElse: () => AgentCapability.textGeneration,
            );
          }).toList() ??
          [AgentCapability.textGeneration],
    );
  }
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