import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps orientation changes ordered when game routes are disposed/recreated.
abstract final class GameplayOrientation {
  static const _gameplayOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];
  static const _normalOrientations = <DeviceOrientation>[];

  static Future<void> _operations = Future<void>.value();
  static int _activeLeases = 0;

  static GameplayOrientationLease acquire() {
    _activeLeases += 1;
    if (_activeLeases == 1) {
      _enqueue(_gameplayOrientations);
    }
    return GameplayOrientationLease._();
  }

  static void _release() {
    if (_activeLeases == 0) return;
    _activeLeases -= 1;
    _enqueue(_activeLeases == 0 ? _normalOrientations : _gameplayOrientations);
  }

  static void _enqueue(List<DeviceOrientation> orientations) {
    _operations = _operations.then((_) async {
      try {
        await SystemChrome.setPreferredOrientations(orientations);
      } catch (error) {
        debugPrint('Unable to update gameplay orientation: $error');
      }
    });
  }
}

final class GameplayOrientationLease {
  GameplayOrientationLease._();

  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    GameplayOrientation._release();
  }
}
