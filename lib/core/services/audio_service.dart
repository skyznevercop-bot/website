import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Arcade-style audio service using the Web Audio API.
///
/// Generates punchy 8-bit sound effects with square/sawtooth waveforms,
/// fast arpeggios, and layered tones for a retro gaming feel.
/// Fire-and-forget — OscillatorNodes auto-dispose.
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  web.AudioContext? _ctx;
  bool _enabled = true;
  double _volume = 0.7;

  web.AudioContext get _audioCtx {
    _ctx ??= web.AudioContext();
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

  /// Snappy 8-bit chirp — position opened.
  void playTradeOpen() {
    // Quick ascending arpeggio: C5 → E5 → G5
    _playTone(frequency: 523, duration: 0.04, type: 'square', gain: 0.35);
    Future.delayed(const Duration(milliseconds: 40), () {
      _playTone(frequency: 659, duration: 0.04, type: 'square', gain: 0.30);
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      _playTone(frequency: 784, duration: 0.06, type: 'square', gain: 0.25);
    });
  }

  /// Quick descending chirp — position closed.
  void playTradeClose() {
    _playTone(frequency: 784, duration: 0.04, type: 'square', gain: 0.30);
    Future.delayed(const Duration(milliseconds: 40), () {
      _playTone(frequency: 587, duration: 0.05, type: 'square', gain: 0.25);
    });
  }

  /// Coin-collect chime — winning trade.
  void playWin() {
    // Classic coin sound: E6 → B6 with layered harmonics
    _playTone(frequency: 1319, duration: 0.06, type: 'square', gain: 0.25);
    _playTone(frequency: 659, duration: 0.06, type: 'square', gain: 0.15);
    Future.delayed(const Duration(milliseconds: 60), () {
      _playTone(frequency: 1976, duration: 0.10, type: 'square', gain: 0.25);
      _playTone(frequency: 988, duration: 0.10, type: 'square', gain: 0.15);
    });
  }

  /// 8-bit boop — losing trade.
  void playLoss() {
    // Short descending boop
    _playTone(
        frequency: 330, duration: 0.08, ramp: 165, type: 'square', gain: 0.30);
    _playTone(
        frequency: 220,
        duration: 0.10,
        ramp: 110,
        type: 'sawtooth',
        gain: 0.15);
  }

  /// Dramatic 8-bit alarm with tremolo — liquidation.
  void playLiquidation() {
    // Rapid alternating alarm: high-low-high-low
    const pairs = [
      [880.0, 0.25],
      [440.0, 0.25],
      [880.0, 0.20],
      [440.0, 0.20],
      [660.0, 0.15],
      [330.0, 0.15],
    ];
    for (var i = 0; i < pairs.length; i++) {
      Future.delayed(Duration(milliseconds: i * 55), () {
        _playTone(
          frequency: pairs[i][0],
          duration: 0.05,
          type: 'square',
          gain: pairs[i][1],
        );
      });
    }
  }

  /// Retro level-up jingle — phase change.
  void playPhaseChange() {
    // 4-note ascending: G5 → A5 → B5 → D6
    const notes = [784.0, 880.0, 988.0, 1175.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        _playTone(
          frequency: notes[i],
          duration: 0.07,
          type: 'square',
          gain: 0.25,
        );
      });
    }
  }

  /// Power-up sweep + chime — lead change.
  void playLeadChange() {
    // Fast sweep up
    _playTone(
        frequency: 220, duration: 0.15, ramp: 1320, type: 'square', gain: 0.3);
    // Accent chime at the top
    Future.delayed(const Duration(milliseconds: 120), () {
      _playTone(frequency: 1320, duration: 0.08, type: 'square', gain: 0.25);
      _playTone(frequency: 1760, duration: 0.10, type: 'square', gain: 0.15);
    });
  }

  /// Punchy metronome tick — countdown.
  void playCountdown() {
    // Short square burst with sub-bass layer
    _playTone(frequency: 880, duration: 0.03, type: 'square', gain: 0.35);
    _playTone(frequency: 220, duration: 0.04, type: 'square', gain: 0.20);
  }

  /// 8-bit fanfare — match start (FIGHT!).
  void playMatchStart() {
    // Staccato arpeggio: C5-E5-G5-C6 with harmony layer
    const melody = [523.0, 659.0, 784.0, 1047.0, 1319.0];
    const harmony = [262.0, 330.0, 392.0, 523.0, 659.0];
    for (var i = 0; i < melody.length; i++) {
      Future.delayed(Duration(milliseconds: i * 55), () {
        _playTone(
            frequency: melody[i], duration: 0.07, type: 'square', gain: 0.28);
        _playTone(
            frequency: harmony[i], duration: 0.07, type: 'square', gain: 0.14);
      });
    }
    // Final sustain chord
    Future.delayed(const Duration(milliseconds: 280), () {
      _playTone(frequency: 1047, duration: 0.15, type: 'square', gain: 0.22);
      _playTone(frequency: 784, duration: 0.15, type: 'square', gain: 0.14);
      _playTone(frequency: 523, duration: 0.15, type: 'square', gain: 0.10);
    });
  }

  /// Game-over style descending arpeggio — match end.
  void playMatchEnd() {
    const notes = [1047.0, 880.0, 784.0, 659.0, 523.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 70), () {
        _playTone(
          frequency: notes[i],
          duration: 0.08,
          type: 'square',
          gain: 0.25 - i * 0.02,
        );
      });
    }
  }

  /// Triumphant 8-bit victory jingle.
  void playVictory() {
    // Classic victory melody: C-E-G, C-E-G, C6 hold
    const melody = [
      [523.0, 0.08],
      [659.0, 0.08],
      [784.0, 0.08],
      [523.0, 0.06],
      [659.0, 0.06],
      [784.0, 0.06],
      [1047.0, 0.25],
    ];
    const delays = [0, 80, 160, 280, 340, 400, 500];
    for (var i = 0; i < melody.length; i++) {
      Future.delayed(Duration(milliseconds: delays[i]), () {
        _playTone(
          frequency: melody[i][0],
          duration: melody[i][1],
          type: 'square',
          gain: i == melody.length - 1 ? 0.30 : 0.25,
        );
        // Harmony on final note
        if (i == melody.length - 1) {
          _playTone(
              frequency: 659, duration: 0.25, type: 'square', gain: 0.15);
          _playTone(
              frequency: 784, duration: 0.25, type: 'square', gain: 0.12);
        }
      });
    }
  }

  /// Sad 8-bit melody (minor key) — defeat.
  void playDefeat() {
    // Descending minor: E4 → D4 → C4 → B3
    const notes = [330.0, 294.0, 262.0, 247.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        _playTone(
          frequency: notes[i],
          duration: 0.14,
          type: 'sawtooth',
          gain: 0.28 - i * 0.04,
        );
        // Sub octave for depth
        _playTone(
          frequency: notes[i] / 2,
          duration: 0.14,
          type: 'square',
          gain: 0.10,
        );
      });
    }
  }

  /// Achievement unlock chime — ROI milestone.
  void playMilestone() {
    // Bright ascending chime: A5 → C#6 → E6
    _playTone(frequency: 880, duration: 0.05, type: 'square', gain: 0.25);
    Future.delayed(const Duration(milliseconds: 50), () {
      _playTone(frequency: 1109, duration: 0.05, type: 'square', gain: 0.25);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _playTone(frequency: 1319, duration: 0.10, type: 'square', gain: 0.30);
      _playTone(frequency: 659, duration: 0.10, type: 'square', gain: 0.12);
    });
  }

  /// Combo streak — escalating staccato burst.
  void playStreak() {
    // Rapid ascending burst: getting higher and faster
    const notes = [523.0, 659.0, 784.0, 988.0, 1175.0];
    for (var i = 0; i < notes.length; i++) {
      Future.delayed(Duration(milliseconds: i * 40), () {
        _playTone(
          frequency: notes[i],
          duration: 0.04,
          type: 'square',
          gain: 0.20 + i * 0.03,
        );
      });
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _playTone({
    required double frequency,
    required double duration,
    String type = 'square',
    double? ramp,
    double? gain,
  }) {
    if (!_enabled) return;

    try {
      final ctx = _audioCtx;
      final now = ctx.currentTime;
      final effectiveGain = (gain ?? 0.3) * _volume;

      final osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.setValueAtTime(frequency, now);
      if (ramp != null) {
        osc.frequency.linearRampToValueAtTime(ramp, now + duration);
      }

      // Punchy envelope: fast attack, clean release.
      final gainNode = ctx.createGain();
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(effectiveGain, now + 0.005);
      gainNode.gain.setValueAtTime(effectiveGain, now + duration - 0.015);
      gainNode.gain.linearRampToValueAtTime(0, now + duration);

      osc.connect(gainNode);
      gainNode.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + duration + 0.01);
    } catch (_) {
      // Silently fail — audio is non-critical.
    }
  }
}
