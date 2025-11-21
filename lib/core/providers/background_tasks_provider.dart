import 'package:flutter/foundation.dart';

class BackgroundTask {
  final String id;
  final String description;
  double progress; // 0.0 to 1.0
  bool isCompleted;
  DateTime startedAt;

  BackgroundTask({
    required this.id,
    required this.description,
    this.progress = 0.0,
    this.isCompleted = false,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  void updateProgress(double newProgress) {
    progress = newProgress.clamp(0.0, 1.0);
  }

  void complete() {
    progress = 1.0;
    isCompleted = true;
  }
}

class BackgroundTasksProvider extends ChangeNotifier {
  final List<BackgroundTask> _tasks = [];

  List<BackgroundTask> get tasks => List.unmodifiable(_tasks);

  int get activeTasksCount => _tasks.where((t) => !t.isCompleted).length;

  bool get hasActiveTasks => activeTasksCount > 0;

  void addTask(BackgroundTask task) {
    _tasks.add(task);
    notifyListeners();
  }

  void updateTask(String id, double progress) {
    final task = _tasks.firstWhere((t) => t.id == id);
    task.updateProgress(progress);
    notifyListeners();
  }

  void completeTask(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    task.complete();
    // Optionally remove after some time
    Future.delayed(const Duration(seconds: 3), () {
      removeTask(id);
    });
  }

  void removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((t) => t.isCompleted);
    notifyListeners();
  }
}