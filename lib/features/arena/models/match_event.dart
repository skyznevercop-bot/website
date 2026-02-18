import 'package:flutter/material.dart';

/// Types of live events generated during a match.
enum EventType {
  leadChange,
  opponentTrade,
  bigMove,
  milestone,
  phaseChange,
  liquidation,
  streak,
  tradeResult,
}

/// A single live event in the match event feed.
class MatchEvent {
  final String id;
  final EventType type;
  final String message;
  final DateTime timestamp;
  final IconData? icon;
  final Color? color;

  const MatchEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.icon,
    this.color,
  });
}
