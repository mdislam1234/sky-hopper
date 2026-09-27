import 'package:flutter/services.dart';

enum HapticCue { selection, light, medium, heavy }

abstract interface class HapticsService {
  Future<void> trigger(HapticCue cue);
}

class SystemHapticsService implements HapticsService {
  const SystemHapticsService();

  @override
  Future<void> trigger(HapticCue cue) => switch (cue) {
    HapticCue.selection => HapticFeedback.selectionClick(),
    HapticCue.light => HapticFeedback.lightImpact(),
    HapticCue.medium => HapticFeedback.mediumImpact(),
    HapticCue.heavy => HapticFeedback.heavyImpact(),
  };
}

class SilentHapticsService implements HapticsService {
  const SilentHapticsService();

  @override
  Future<void> trigger(HapticCue cue) async {}
}
