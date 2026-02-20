import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.unlocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      category: json['category'] as String? ?? 'special',
      unlocked: json['unlocked'] as bool? ?? false,
    );
  }

  Achievement copyWith({bool? unlocked}) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: category,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  /// Map icon string keys to Material icons.
  IconData get iconData {
    switch (icon) {
      case 'sword':
        return Icons.sports_martial_arts_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'trophy':
        return Icons.emoji_events_rounded;
      case 'rocket':
        return Icons.rocket_launch_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'flame':
        return Icons.whatshot_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'dollar':
        return Icons.attach_money_rounded;
      case 'money_bag':
        return Icons.savings_rounded;
      case 'whale':
        return Icons.water_rounded;
      case 'moon':
        return Icons.nightlight_rounded;
      case 'chart':
        return Icons.candlestick_chart_rounded;
      case 'chart_up':
        return Icons.show_chart_rounded;
      case 'trending':
        return Icons.trending_up_rounded;
      case 'play':
        return Icons.play_circle_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }
}

class AchievementsState {
  final List<Achievement> achievements;
  final bool isLoading;
  final int unlockedCount;
  final int totalCount;

  const AchievementsState({
    this.achievements = const [],
    this.isLoading = false,
    this.unlockedCount = 0,
    this.totalCount = 0,
  });

  AchievementsState copyWith({
    List<Achievement>? achievements,
    bool? isLoading,
    int? unlockedCount,
    int? totalCount,
  }) {
    return AchievementsState(
      achievements: achievements ?? this.achievements,
      isLoading: isLoading ?? this.isLoading,
      unlockedCount: unlockedCount ?? this.unlockedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
