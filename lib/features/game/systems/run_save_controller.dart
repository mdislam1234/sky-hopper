import 'package:flutter/foundation.dart';

import '../models/game_result.dart';

enum SavePhase { notStarted, saving, saved, failed, preview }

class RunSaveController extends ChangeNotifier {
  RunSaveController({
    this.submit,
    this.preview = false,
    this.timeout = const Duration(seconds: 15),
  }) : runId = GameResult.newRunId();
  final SubmitGameResult? submit;
  final bool preview;
  final Duration timeout;
  final String runId;
  GameResult? _result;
  GameResult? get result => _result;
  SavePhase phase = SavePhase.notStarted;
  bool _disposed = false;

  Future<void> complete({
    required int score,
    required double maximumHeight,
    required int coinsCollected,
  }) async {
    if (_result != null || _disposed) return;
    _result = GameResult(
      runId: runId,
      score: score,
      height: maximumHeight.floor(),
      coinsCollected: coinsCollected,
    );
    if (preview) {
      phase = SavePhase.preview;
      notifyListeners();
      return;
    }
    await _save();
  }

  Future<void> retry() async {
    if (phase == SavePhase.failed && !_disposed) await _save();
  }

  Future<void> _save() async {
    if (_disposed ||
        _result == null ||
        phase == SavePhase.saving ||
        phase == SavePhase.saved) {
      return;
    }
    phase = SavePhase.saving;
    notifyListeners();
    try {
      final operation = submit;
      if (operation == null) throw StateError('Saving unavailable');
      final saved = await operation(_result!).timeout(timeout);
      saved.validateFor(_result!);
      if (!_disposed) phase = SavePhase.saved;
    } catch (_) {
      if (!_disposed) phase = SavePhase.failed;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
