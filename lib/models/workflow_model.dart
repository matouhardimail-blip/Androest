class WorkflowModel {
  final String id;
  final String taskTitle;
  final String status; // 'completed', 'failed', 'running'
  final DateTime timestamp;
  final String finalResult;
  final List<String> savedFiles;

  WorkflowModel({
    required this.id,
    required this.taskTitle,
    required this.status,
    required this.timestamp,
    required this.finalResult,
    required this.savedFiles,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskTitle': taskTitle,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'finalResult': finalResult,
    'savedFiles': savedFiles,
  };

  factory WorkflowModel.fromJson(Map<String, dynamic> json) => WorkflowModel(
    id: json['id'],
    taskTitle: json['taskTitle'],
    status: json['status'],
    timestamp: DateTime.parse(json['timestamp']),
    finalResult: json['finalResult'],
    savedFiles: List<String>.from(json['savedFiles'] ?? []),
  );
}