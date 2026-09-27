import 'dart:async';

import '../../settings/settings_controller.dart';
import '../systems/environment_system.dart';
import '../systems/game_feedback_event.dart';
import 'game_audio_service.dart';
import 'haptics_service.dart';

typedef GameFeedbackFactory = GameFeedbackController Function();

class GameFeedbackController {
  GameFeedbackController({
    required this.settings,
    required this.audio,
    required this.haptics,
  }) {
    settings.addListener(_settingsChanged);
  }

  final SettingsController settings;
  final GameAudioService audio;
  final HapticsService haptics;
  Biome _biome = Biome.sunny;
  bool _started = false;
  bool _audioReady = false;
  bool _starting = false;
  bool _paused = false;
  bool _disposed = false;
  final Map<SoundCue, DateTime> _lastPlayed = {};

  Future<void> start([Biome biome = Biome.sunny]) async {
    if (_disposed || _starting) return;
    _starting = true;
    _biome = biome;
    _started = true;
    try {
      await audio.preload();
      if (settings.value.musicEnabled && !_paused) {
        await audio.transitionTo(biome);
      }
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
      // Browser autoplay and unavailable audio devices must never stop play.
    } finally {
      _starting = false;
    }
  }

  /// Retries a browser-blocked audio start on the first gameplay gesture.
  void userGesture() {
    if (!_audioReady && !_paused && !_disposed) unawaited(start(_biome));
  }

  void handle(Iterable<GameFeedbackEvent> events) {
    if (_disposed || _paused) return;
    for (final event in events) {
      switch (event.type) {
        case GameFeedbackType.bounce:
          _sound(SoundCue.bounce, const Duration(milliseconds: 70));
          break;
        case GameFeedbackType.coinCollected:
          _sound(SoundCue.coin, const Duration(milliseconds: 35));
          _haptic(HapticCue.selection);
          break;
        case GameFeedbackType.perfectLanding:
          _sound(SoundCue.perfect, const Duration(milliseconds: 120));
          _haptic(HapticCue.light);
          break;
        case GameFeedbackType.crumble:
          _sound(SoundCue.crumble, const Duration(milliseconds: 180));
          break;
        case GameFeedbackType.windEntered:
          _sound(SoundCue.wind, const Duration(milliseconds: 500));
          break;
        case GameFeedbackType.stormCloudContact:
          _sound(SoundCue.cloud, const Duration(milliseconds: 300));
          _haptic(HapticCue.medium);
          break;
        case GameFeedbackType.lightningWarning:
          _sound(SoundCue.lightningWarning, const Duration(milliseconds: 500));
          break;
        case GameFeedbackType.lightningStrike:
          _sound(SoundCue.lightningStrike, const Duration(milliseconds: 180));
          break;
        case GameFeedbackType.spikeImpact:
          _sound(SoundCue.hazardImpact, const Duration(milliseconds: 250));
          _haptic(HapticCue.heavy);
          break;
        case GameFeedbackType.nearMiss:
          _sound(SoundCue.nearMiss, const Duration(milliseconds: 220));
          _haptic(HapticCue.light);
          break;
        case GameFeedbackType.biomeChanged:
          if (event.biome case final biome?) {
            _biome = biome;
            if (settings.value.musicEnabled) {
              unawaited(_guard(() => audio.transitionTo(biome)));
            }
          }
          break;
        case GameFeedbackType.approachingBest:
          break;
        case GameFeedbackType.newPersonalBest:
          _sound(SoundCue.newBest, const Duration(milliseconds: 700));
          _haptic(HapticCue.medium);
          break;
        case GameFeedbackType.gameOver:
          _sound(SoundCue.gameOver, const Duration(milliseconds: 700));
          _haptic(HapticCue.heavy);
          unawaited(_guard(audio.pauseMusic));
          break;
      }
    }
  }

  void uiTap() {
    _sound(SoundCue.uiTap, const Duration(milliseconds: 80));
  }

  Future<void> pause() async {
    _paused = true;
    await _guard(audio.pauseMusic);
  }

  Future<void> resume() async {
    _paused = false;
    if (_started && settings.value.musicEnabled) {
      await _guard(audio.resumeMusic);
    }
  }

  Future<void> restart() async {
    _paused = false;
    _biome = Biome.sunny;
    if (settings.value.musicEnabled) {
      await _guard(() => audio.transitionTo(_biome));
    }
  }

  Future<void> leaveGame() async {
    _paused = true;
    await _guard(audio.stopMusic);
  }

  void _settingsChanged() {
    if (_disposed || !_started) return;
    if (settings.value.musicEnabled && !_paused) {
      unawaited(_guard(() => audio.transitionTo(_biome)));
    } else {
      unawaited(_guard(audio.pauseMusic));
    }
  }

  void _sound(SoundCue cue, Duration cooldown) {
    if (!settings.value.soundEnabled) return;
    final now = DateTime.now();
    final last = _lastPlayed[cue];
    if (last != null && now.difference(last) < cooldown) return;
    _lastPlayed[cue] = now;
    unawaited(_guard(() => audio.play(cue)));
  }

  void _haptic(HapticCue cue) {
    if (!settings.value.hapticsEnabled) return;
    unawaited(_guard(() => haptics.trigger(cue)));
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Audio and haptics are optional feedback and must fail closed.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    settings.removeListener(_settingsChanged);
    await _guard(audio.dispose);
  }
}
