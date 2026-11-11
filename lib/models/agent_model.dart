import 'package:flutter/material.dart';

class AgentModel {
  final String id;
  final String name;
  final String description;
  final String providerId; // معرف مزود الخدمة المرتبط به
  final String modelName;  // اسم الموديل للعرض فقط
  final String systemPrompt; // شخصية الوكيل
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

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    providerId: json['providerId'],
    modelName: json['modelName'],
    systemPrompt: json['systemPrompt'],
    icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
    color: Color(json['colorValue']),
    isConnected: json['isConnected'] ?? true,
  );
}