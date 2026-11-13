class WorkflowModel {
  final String id;
  final String taskTitle;
  final String status; 
  final DateTime timestamp;
  final String finalResult;
  final List<String> savedFiles;
  final List<Map<String, String>> conversationLog; // سجل المحادثة الجديد

  WorkflowModel({
    required this.id,
    required this.taskTitle,
    required this.status,
    required this.timestamp,
    required this.finalResult,
    required this.savedFiles,
    required this.conversationLog,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskTitle': taskTitle,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'finalResult': finalResult,
    'savedFiles': savedFiles,
    'conversationLog': conversationLog,
  };

  factory WorkflowModel.fromJson(Map<String, dynamic> json) => WorkflowModel(
    id: json['id'],
    taskTitle: json['taskTitle'],
    status: json['status'],
    timestamp: DateTime.parse(json['timestamp']),
    finalResult: json['finalResult'],
    savedFiles: List<String>.from(json['savedFiles'] ?? []),
    conversationLog: (json['conversationLog'] as List?)?.map((e) => Map<String, String>.from(e)).toList() ?? [],
  );
}