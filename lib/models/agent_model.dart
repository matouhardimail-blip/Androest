import 'package:flutter/material.dart';

class AgentModel {
  final String id;
  final String name;
  final String description;
  final String provider;
  final String model;
  final IconData icon;
  final Color color;
  final String category;
  bool isConnected; // تم إزالة final للسماح بالتعديل
  final List<String> capabilities;

  AgentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.provider,
    required this.model,
    required this.icon,
    required this.color,
    required this.category,
    this.isConnected = false,
    required this.capabilities,
  });
}