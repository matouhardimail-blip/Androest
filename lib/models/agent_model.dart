import 'package:flutter/material.dart';

class AgentModel {
  final String id;
  final String name;
  final String description;
  final String providerId;
  final String modelName;
  final String systemPrompt;
  final IconData icon;
  final Color color;
  final bool isConnected;

  AgentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.providerId,
    required this.modelName,
    required this.systemPrompt,
    required this.icon,
    required this.color,
    this.isConnected = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'providerId': providerId,
    'modelName': modelName,
    'systemPrompt': systemPrompt,
    'iconCode': icon.codePoint,
    'colorValue': color.value,
    'isConnected': isConnected,
  };

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    // حل مشكلة الأيقونات المتغيرة (Dynamic IconData)
    IconData safeIcon = Icons.smart_toy; // الافتراضي
    int? code = json['iconCode'];
    if (code == Icons.chat.codePoint) {
      safeIcon = Icons.chat;
    } else if (code == Icons.psychology.codePoint) {
      safeIcon = Icons.psychology;
    } else if (code == Icons.code.codePoint) {
      safeIcon = Icons.code;
    }

    return AgentModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      providerId: json['providerId'],
      modelName: json['modelName'],
      systemPrompt: json['systemPrompt'],
      icon: safeIcon,
      color: Color(json['colorValue']),
      isConnected: json['isConnected'] ?? true,
    );
  }
}