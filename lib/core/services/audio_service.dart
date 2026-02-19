import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Lightweight audio service using the Web Audio API.
///
/// Generates short synthesized tones — no audio asset files required.
/// Each method is fire-and-forget; the OscillatorNode auto-disposes.
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  web.AudioContext? _ctx;
  bool _enabled = true;
  double _volume = 0.7;

  web.AudioContext get _audioCtx {
    _ctx ??= web.AudioContext();
    // Resume context if suspended (browsers require user gesture first).
    if (_ctx!.state == 'suspended') {
      _ctx!.resume().toDart.ignore();
    }
    return _ctx!;
  }

  void configure({bool? enabled, double? volume}) {
    if (enabled != null) _enabled = enabled;
    if (volume != null) _volume = volume.clamp(0.0, 1.0);
  }

  // ── Public sound methods ──────────────────────────────────────────────────

  /// Short ascending tone — position opened.
  void playTradeOpen() => _playTone(
        frequency: 520,
        duration: 0.08,
        ramp: 680,
        type: 'sine',
      );

  /// Short descending tone — position closed.
  void playTradeClose() => _playTone(
        frequency: 680,
        duration: 0.08,
        ramp: 520,
        type: 'sine',
      );

  /// Pleasant double-beep — winning trade.
  void playWin() {
    _playTone(frequency: 660, duration: 0.07, type: 'sine');
    Future.delayed(const Duration(milliseconds: 90), () {
      _playTone(frequency: 880, duration: 0.10, type: 'sine');
    });
  }

  /// Low buzz — losing trade.
  void playLoss() => _playTone(
        frequency: 220,
        duration: 0.15,
        type: 'sawtooth',
        gain: 0.3,
      );

  /// Warning alarm — liquidation.
  void playLiquidation() {
    _playTone(frequency: 440, duration: 0.08, type: 'square', gain: 0.4);
    Future.delayed(const Duration(milliseconds: 100), () {
      _playTone(frequency: 330, duration: 0.08, type: 'square', gain: 0.4);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _playTone(frequency: 220, duration: 0.15, type: 'square', gain: 0.4);
    });
  }

  /// Bell chime — phase change.
  void playPhaseChange() {
    _playTone(frequency: 784, duration: 0.06, type: 'sine');
    Future.delayed(const Duration(milliseconds: 70), () {
      _playTone(frequency: 1047, duration: 0.10, type: 'sine');
    });
  }

  /// Dramatic swoosh — lead change.
  void playLeadChange() => _playTone(
        frequency: 300,
        duration: 0.20,
        ramp: 900,
        type: 'sine',
        gain: 0.5,
      );

  /// Short tick — countdown.
  void playCountdown() => _playTone(
        frequency: 1000,
        duration: 0.04,
        type: 'sine',
        gain: 0.4,
      );

  /// Fanfare — match start.
  void playMatchStart() {
    const notes = [523.0, 659.0, 784.0, 1047.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        _playTone(frequency: notes[i], duration: 0.12, type: 'sine');
      });
    }
  }

  /// Finale tone — match end.
  void playMatchEnd() {
    _playTone(frequency: 784, duration: 0.10, type: 'sine');
    Future.delayed(const Duration(milliseconds: 120), () {
      _playTone(frequency: 659, duration: 0.10, type: 'sine');
    });
    Future.delayed(const Duration(milliseconds: 240), () {
      _playTone(frequency: 523, duration: 0.20, type: 'sine');
    });
  }

  /// Triumphant chord — victory.
  void playVictory() {
    const chord = [523.0, 659.0, 784.0];
    for (final freq in chord) {
      _playTone(frequency: freq, duration: 0.4, type: 'sine', gain: 0.35);
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      _playTone(frequency: 1047, duration: 0.5, type: 'sine', gain: 0.45);
    });
  }

  /// Somber tone — defeat.
  void playDefeat() {
    _playTone(frequency: 392, duration: 0.25, type: 'sine', gain: 0.4);
    Future.delayed(const Duration(milliseconds: 250), () {
      _playTone(frequency: 330, duration: 0.25, type: 'sine', gain: 0.35);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _playTone(frequency: 262, duration: 0.4, type: 'sine', gain: 0.3);
    });
  }

  /// Milestone chime — ROI boundary crossed.
  void playMilestone() {
    _playTone(frequency: 880, duration: 0.06, type: 'sine');
    Future.delayed(const Duration(milliseconds: 80), () {
      _playTone(frequency: 1100, duration: 0.08, type: 'sine');
    });
  }

  /// Streak sound — consecutive wins.
  void playStreak() {
    const notes = [660.0, 784.0, 880.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        _playTone(frequency: notes[i], duration: 0.08, type: 'sine');
      });
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _playTone({
    required double frequency,
    required double duration,
    String type = 'sine',
    double? ramp,
    double? gain,
  }) {
    if (!_enabled) return;

    try {
      final ctx = _audioCtx;
      final now = ctx.currentTime;
      final effectiveGain = (gain ?? 0.5) * _volume;

      // Create oscillator.
      final osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.setValueAtTime(frequency, now);
      if (ramp != null) {
        osc.frequency.linearRampToValueAtTime(ramp, now + duration);
      }

      // Create gain envelope (attack + release to avoid clicks).
      final gainNode = ctx.createGain();
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(effectiveGain, now + 0.01);
      gainNode.gain.setValueAtTime(effectiveGain, now + duration - 0.02);
      gainNode.gain.linearRampToValueAtTime(0, now + duration);

      // Connect and play.
      osc.connect(gainNode);
      gainNode.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + duration + 0.01);
    } catch (_) {
      // Silently fail — audio is non-critical.
    }
  }
}
