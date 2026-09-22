import 'dart:math';
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../config/game_config.dart';
import '../sky_hopper_game.dart';
import '../systems/game_state.dart';
import '../systems/run_save_controller.dart';
import '../models/game_result.dart';
import 'game_hud.dart';
import '../../skins/models/skin.dart';
import 'game_over_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.onHome,
    this.submitGameResult,
    this.preview = false,
    this.appearance = SkinAppearance.defaultSkin,
    super.key,
  });
  final VoidCallback onHome;
  final SubmitGameResult? submitGameResult;
  final bool preview;
  final SkinAppearance appearance;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late SkyHopperGame _game;
  late RunSaveController _save;
  final _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  final Map<int, int> _pointers = {};
  @override
  void initState() {
    super.initState();
    _game = SkyHopperGame(
      seed: Random().nextInt(1 << 30),
      appearance: widget.appearance,
    );
    _save = RunSaveController(
      submit: widget.submitGameResult,
      preview: widget.preview,
    );
    _game.status.addListener(_onRunChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onRunChanged() {
    if (_game.state.phase == RunPhase.gameOver) {
      unawaited(
        _save.complete(
          score: _game.state.score,
          maximumHeight: _game.state.progress.maximumHeight,
          coinsCollected: _game.state.coinsCollected,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.visualMotion = !MediaQuery.disableAnimationsOf(context);
  }

  void _clearInput() {
    _keys.clear();
    _pointers.clear();
    _game.state.direction = 0;
  }

  void _pause() {
    _clearInput();
    _game.pauseRun();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _updateInput() {
    final left =
        _keys.contains(LogicalKeyboardKey.arrowLeft) ||
        _keys.contains(LogicalKeyboardKey.keyA) ||
        _pointers.containsValue(-1);
    final right =
        _keys.contains(LogicalKeyboardKey.arrowRight) ||
        _keys.contains(LogicalKeyboardKey.keyD) ||
        _pointers.containsValue(1);
    _game.state.direction = _game.state.phase == RunPhase.playing
        ? (right ? 1 : 0) - (left ? 1 : 0)
        : 0;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    const movement = <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
    ];
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        event is KeyDownEvent) {
      _pause();
      return KeyEventResult.handled;
    }
    if (!movement.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    } else {
      _keys.add(event.logicalKey);
    }
    _updateInput();
    return KeyEventResult.handled;
  }

  void _continue() {
    _clearInput();
    if (_game.state.phase == RunPhase.paused) {
      _game.resumeRun();
    } else {
      final previous = _game;
      previous.status.removeListener(_onRunChanged);
      final previousSave = _save;
      previous.pauseEngine();
      setState(() {
        _game = SkyHopperGame(
          seed: Random().nextInt(1 << 30),
          appearance: widget.appearance,
        );
        _game.visualMotion = !MediaQuery.disableAnimationsOf(context);
        _save = RunSaveController(
          submit: widget.submitGameResult,
          preview: widget.preview,
        );
        _game.status.addListener(_onRunChanged);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.disposeStatus();
        previousSave.dispose();
      });
    }
    _focus.requestFocus();
  }

  void _home() {
    _pause();
    widget.onHome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.pauseEngine();
    _game.status.removeListener(_onRunChanged);
    _save.dispose();
    _game.disposeStatus();
    _focus.dispose();
    super.dispose();
  }

  Widget _control(int direction) => Semantics(
    container: true,
    label: direction < 0 ? 'Hold to move left' : 'Hold to move right',
    child: Listener(
      onPointerDown: (event) {
        _focus.requestFocus();
        _pointers[event.pointer] = direction;
        _updateInput();
      },
      onPointerUp: (event) {
        _pointers.remove(event.pointer);
        _updateInput();
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _updateInput();
      },
      child: Container(
        width: 76,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.cloud.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          direction < 0
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          size: 36,
          color: AppColors.deepBlue,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paleSky,
    body: SafeArea(
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        onFocusChange: (focused) {
          if (!focused) _pause();
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: GameConfig.width / GameConfig.height,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GameWidget<SkyHopperGame>(
                    key: ObjectKey(_game),
                    game: _game,
                    autofocus: false,
                  ),
                  ValueListenableBuilder<(int, RunPhase, int)>(
                    valueListenable: _game.status,
                    builder: (context, value, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: GameHud(
                            score: value.$1,
                            coins: value.$3,
                            onPause: _pause,
                          ),
                        ),
                        if (value.$2 == RunPhase.playing)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [_control(-1), _control(1)],
                            ),
                          ),
                        if (value.$2 != RunPhase.playing)
                          ListenableBuilder(
                            listenable: _save,
                            builder: (context, _) => GameOverOverlay(
                              score: value.$1,
                              coins: value.$3,
                              paused: value.$2 == RunPhase.paused,
                              savePhase: _save.phase,
                              onRetry: _save.retry,
                              onContinue: _continue,
                              onHome: _home,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
