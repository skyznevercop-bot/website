import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson_data.dart';

const _storageKey = 'solfight_completed_lessons';

/// Tracks which lessons the user has completed (persisted via SharedPreferences).
class LearnState {
  final Set<String> completedLessonIds;
  final bool isLoaded;

  const LearnState({
    this.completedLessonIds = const {},
    this.isLoaded = false,
  });

  int get totalLessons {
    int count = 0;
    for (final path in allLearningPaths) {
      count += path.lessons.length;
    }
    return count;
  }

  int get completedCount => completedLessonIds.length;

  double get progressPercent =>
      totalLessons > 0 ? completedCount / totalLessons : 0;

  bool isCompleted(String lessonId) => completedLessonIds.contains(lessonId);

  int completedInPath(LearningPath path) {
    int count = 0;
    for (final lesson in path.lessons) {
      if (completedLessonIds.contains(lesson.id)) count++;
    }
    return count;
  }

  LearnState copyWith({
    Set<String>? completedLessonIds,
    bool? isLoaded,
  }) {
    return LearnState(
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class LearnNotifier extends Notifier<LearnState> {
  @override
  LearnState build() {
    _loadFromStorage();
    return const LearnState();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_storageKey) ?? [];
      state = state.copyWith(
        completedLessonIds: ids.toSet(),
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> toggleLesson(String lessonId) async {
    final updated = Set<String>.from(state.completedLessonIds);
    if (updated.contains(lessonId)) {
      updated.remove(lessonId);
    } else {
      updated.add(lessonId);
    }
    state = state.copyWith(completedLessonIds: updated);
    _saveToStorage(updated);
  }

  Future<void> markCompleted(String lessonId) async {
    if (state.completedLessonIds.contains(lessonId)) return;
    final updated = {...state.completedLessonIds, lessonId};
    state = state.copyWith(completedLessonIds: updated);
    _saveToStorage(updated);
  }

  Future<void> _saveToStorage(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, ids.toList());
    } catch (_) {}
  }
}

final learnProvider =
    NotifierProvider<LearnNotifier, LearnState>(LearnNotifier.new);
