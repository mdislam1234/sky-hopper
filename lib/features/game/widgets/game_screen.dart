import 'dart:math';
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../config/game_config.dart';
import '../sky_hopper_game.dart';
import '../systems/game_state.dart';
import '../systems/run_save_controller.dart';
import '../systems/environment_system.dart';
import '../models/game_result.dart';
import 'game_hud.dart';
import '../../skins/models/skin.dart';
import '../../settings/data/game_settings_store.dart';
import '../../settings/settings_controller.dart';
import '../audio/game_audio_service.dart';
import '../audio/game_feedback_controller.dart';
import '../audio/haptics_service.dart';
import 'game_over_overlay.dart';
import '../../ads/ad_service.dart';
import '../../ads/monetization_controller.dart';
import '../../ads/rewarded_bonus_claim.dart';
import '../../ads/rewarded_offer.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.onHome,
    this.submitGameResult,
    this.preview = false,
    this.appearance = SkinAppearance.defaultSkin,
    this.personalBestScore = 0,
    this.feedbackFactory,
    this.seed,
    this.modeLabel,
    this.monetization,
    this.rewardedEligible = false,
    this.claimRewardedBonus,
    super.key,
  });
  final VoidCallback onHome;
  final SubmitGameResult? submitGameResult;
  final bool preview;
  final SkinAppearance appearance;
  final int personalBestScore;
  final GameFeedbackFactory? feedbackFactory;
  final int? seed;
  final String? modeLabel;
  final MonetizationController? monetization;
  final bool rewardedEligible;
  final ClaimRewardedRunBonus? claimRewardedBonus;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late SkyHopperGame _game;
  late RunSaveController _save;
  late final GameFeedbackController _feedback;
  final _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  final Map<int, int> _pointers = {};
  bool _normalRunRecorded = false;
  bool _rewardAdConsumed = false;
  bool _rewardClaimPending = false;
  RewardedClaimGate _rewardClaimGate = RewardedClaimGate();
  bool _rewardBusy = false;
  bool _breakBusy = false;
  String? _rewardStatus;
  String? _lastRewardDebugSummary;
  @override
  void initState() {
    super.initState();
    _feedback =
        widget.feedbackFactory?.call() ??
        GameFeedbackController(
          settings: SettingsController(MemoryGameSettingsStore()),
          audio: const SilentGameAudioService(),
          haptics: const SilentHapticsService(),
        );
    _game = SkyHopperGame(
      seed: widget.seed ?? Random().nextInt(1 << 30),
      appearance: widget.appearance,
      personalBestScore: widget.personalBestScore,
    );
    _save = RunSaveController(
      submit: widget.submitGameResult,
      preview: widget.preview,
    );
    _save.addListener(_onSaveChanged);
    _game.status.addListener(_onRunChanged);
    _game.feedbackEvents.addListener(_onFeedback);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_feedback.start());
  }

  void _onFeedback() => _feedback.handle(_game.feedbackEvents.value);

  void _onSaveChanged() {
    if (_save.phase == SavePhase.saved &&
        widget.rewardedEligible &&
        !_normalRunRecorded) {
      _normalRunRecorded = true;
      widget.monetization?.recordCompletedRun(_save.runId, isNormalMode: true);
    }
    if (mounted) setState(() {});
  }

  void _onRunChanged() {
    if (_game.state.phase == RunPhase.gameOver) {
      unawaited(
        _save.complete(
          score: _game.state.score,
          maximumHeight: _game.state.progress.maximumHeight,
          coinsCollected: _game.state.coinsCollected,
          perfectLandings: _game.state.perfectLandings,
          bestPerfectStreak: _game.state.bestPerfectStreak,
          nearMisses: _game.state.nearMisses,
          movingPlatformLandings: _game.state.movingPlatformLandings,
          highestBiome: _game.state.environment.biome.index,
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
    unawaited(_feedback.pause());
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
    if (event is KeyDownEvent) _feedback.userGesture();
    if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    } else {
      _keys.add(event.logicalKey);
    }
    _updateInput();
    return KeyEventResult.handled;
  }

  void _continue() {
    _feedback.uiTap();
    _clearInput();
    if (_game.state.phase == RunPhase.paused) {
      _game.resumeRun();
      unawaited(_feedback.resume());
    } else {
      final previous = _game;
      previous.status.removeListener(_onRunChanged);
      previous.feedbackEvents.removeListener(_onFeedback);
      final previousSave = _save;
      previousSave.removeListener(_onSaveChanged);
      previous.pauseEngine();
      setState(() {
        _game = SkyHopperGame(
          seed: widget.seed ?? Random().nextInt(1 << 30),
          appearance: widget.appearance,
          personalBestScore: widget.personalBestScore,
        );
        _game.visualMotion = !MediaQuery.disableAnimationsOf(context);
        _save = RunSaveController(
          submit: widget.submitGameResult,
          preview: widget.preview,
        );
        _save.addListener(_onSaveChanged);
        _normalRunRecorded = false;
        _rewardAdConsumed = false;
        _rewardClaimPending = false;
        _rewardClaimGate = RewardedClaimGate();
        _rewardBusy = false;
        _rewardStatus = null;
        _lastRewardDebugSummary = null;
        _game.status.addListener(_onRunChanged);
        _game.feedbackEvents.addListener(_onFeedback);
      });
      unawaited(_feedback.restart());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.disposeStatus();
        previousSave.dispose();
      });
    }
    _focus.requestFocus();
  }

  void _home() {
    _feedback.uiTap();
    _pause();
    unawaited(_feedback.leaveGame());
    widget.onHome();
  }

  Future<void> _continueAfterBreak() async {
    if (_breakBusy) return;
    if (_game.state.phase == RunPhase.paused || !widget.rewardedEligible) {
      _continue();
      return;
    }
    _breakBusy = true;
    try {
      await widget.monetization?.showInterstitialAtBreak();
      if (mounted) _continue();
    } finally {
      _breakBusy = false;
    }
  }

  Future<void> _homeAfterBreak() async {
    if (_breakBusy) return;
    if (_game.state.phase == RunPhase.paused || !widget.rewardedEligible) {
      _home();
      return;
    }
    _breakBusy = true;
    try {
      await widget.monetization?.showInterstitialAtBreak();
      if (mounted) _home();
    } finally {
      _breakBusy = false;
    }
  }

  Future<void> _watchRewarded() async {
    final monetization = widget.monetization;
    if (_rewardBusy ||
        _rewardAdConsumed ||
        _save.phase != SavePhase.saved ||
        monetization == null ||
        !monetization.rewardedAvailable) {
      return;
    }
    setState(() {
      _rewardBusy = true;
      _rewardAdConsumed = true;
      _rewardStatus = 'Opening bonus video…';
    });
    unawaited(_feedback.pause());
    final outcome = await monetization.showRewarded();
    if (!mounted) return;
    switch (outcome) {
      case RewardedAdOutcome.earned:
        _rewardClaimPending = true;
        await _claimRewardedBonus();
        return;
      case RewardedAdOutcome.dismissed:
        setState(() {
          _rewardBusy = false;
          _rewardStatus = 'Video closed before the reward was earned.';
        });
        return;
      case RewardedAdOutcome.unavailable:
      case RewardedAdOutcome.failed:
        setState(() {
          _rewardBusy = false;
          _rewardAdConsumed = false;
          _rewardStatus = 'Bonus video is unavailable. You can try again.';
        });
        return;
    }
  }

  Future<void> _claimRewardedBonus() async {
    final saved = _save.savedResult;
    final claim = widget.claimRewardedBonus;
    if (!_rewardClaimPending || !_rewardClaimGate.tryStart()) return;
    if (saved == null || claim == null) {
      _rewardClaimGate.releaseForRetry();
      if (mounted) {
        setState(() {
          _rewardBusy = false;
          _rewardStatus = 'Bonus confirmation is unavailable.';
        });
      }
      return;
    }
    setState(() {
      _rewardBusy = true;
      _rewardStatus = 'Confirming bonus…';
    });
    try {
      final result = await claim(saved.runId);
      if (!mounted) return;
      _rewardClaimGate.complete();
      setState(() {
        _rewardClaimPending = false;
        _rewardBusy = false;
        _rewardStatus = result.alreadyClaimed
            ? 'Bonus already claimed · ${result.totalCoins} total coins'
            : 'Bonus +${result.bonusCoins} · ${result.totalCoins} total coins';
      });
    } catch (_) {
      _rewardClaimGate.releaseForRetry();
      if (!mounted) return;
      setState(() {
        _rewardBusy = false;
        _rewardStatus =
            'Bonus earned, but confirmation failed. Retry the claim.';
      });
    }
  }

  int get _estimatedBonus =>
      ((_game.state.coinsCollected + 1) ~/ 2).clamp(1, 25);

  bool get _rewardRunEligible {
    return widget.monetization?.isRewardedRunEligible(
          isNormalMode: widget.rewardedEligible,
          runSaved:
              _game.state.phase == RunPhase.gameOver &&
              _save.phase == SavePhase.saved,
          coinsCollected: _game.state.coinsCollected,
          alreadyConsumed: _rewardAdConsumed,
        ) ==
        true;
  }

  RewardedOfferPresentation get _rewardOffer =>
      RewardedOfferPresentation.resolve(
        eligible: _rewardRunEligible,
        claimPending: _rewardClaimPending,
        busy: _rewardBusy,
        adState:
            widget.monetization?.rewardedState ?? RewardedAdState.unsupported,
        estimatedBonus: _estimatedBonus,
      );

  Future<void> _retryRewarded() async {
    if (_rewardBusy || !_rewardRunEligible) return;
    setState(() => _rewardStatus = 'Checking for a bonus video…');
    await widget.monetization?.retryRewarded();
    if (mounted &&
        widget.monetization?.rewardedState == RewardedAdState.unavailable) {
      setState(() => _rewardStatus = 'Bonus video is still unavailable.');
    }
  }

  void _logRewardOffer(RewardedOfferPresentation offer) {
    if (!kDebugMode ||
        widget.monetization == null ||
        _game.state.phase != RunPhase.gameOver) {
      return;
    }
    final state = widget.monetization?.rewardedState.name ?? 'unsupported';
    final button = !offer.visible
        ? 'hidden'
        : offer.retryable
        ? 'unavailable'
        : offer.loading
        ? 'loading'
        : offer.enabled
        ? 'enabled'
        : 'disabled';
    final summary =
        'normalMode=${widget.rewardedEligible} '
        'saved=${_save.phase == SavePhase.saved} '
        'positiveCoins=${_game.state.coinsCollected > 0} '
        'consumed=$_rewardAdConsumed eligible=$_rewardRunEligible '
        'adState=$state button=$button';
    if (_lastRewardDebugSummary == summary) return;
    _lastRewardDebugSummary = summary;
    debugPrint('[Ads] Game Over $summary');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.pauseEngine();
    _game.status.removeListener(_onRunChanged);
    _game.feedbackEvents.removeListener(_onFeedback);
    _save.removeListener(_onSaveChanged);
    _save.dispose();
    _game.disposeStatus();
    unawaited(_feedback.dispose());
    _focus.dispose();
    super.dispose();
  }

  Widget _control(int direction) => Semantics(
    container: true,
    label: direction < 0 ? 'Hold to move left' : 'Hold to move right',
    child: Listener(
      onPointerDown: (event) {
        _feedback.userGesture();
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

  String? _causeMessage(GameOverCause? cause) => switch (cause) {
    GameOverCause.fall => 'Missed the platform!',
    GameOverCause.spikes => 'Hit the spikes!',
    GameOverCause.lightning => 'Struck by lightning!',
    null => null,
  };

  Widget _biomeNotice(Biome biome) => IgnorePointer(
    child: Align(
      alignment: const Alignment(0, -0.66),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.deepBlue.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cloud.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            'ENTERING ${biome.label}',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Colors.white, letterSpacing: 1.4),
          ),
        ),
      ),
    ),
  );

  Widget _feedbackNotice(String message) => IgnorePointer(
    child: Align(
      alignment: const Alignment(0, -0.42),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.deepBlue.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              message,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
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
                  ValueListenableBuilder<GameStatus>(
                    valueListenable: _game.status,
                    builder: (context, value, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: GameHud(
                            score: value.score,
                            bestScore: value.bestScore,
                            coins: value.coins,
                            animateFeedback: _game.visualMotion,
                            onPause: () {
                              _feedback.uiTap();
                              _pause();
                            },
                          ),
                        ),
                        if (widget.modeLabel case final label?)
                          Positioned(
                            top: 58,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.deepBlue,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ),
                          ),
                        if (value.biomeNotice case final biome?)
                          _biomeNotice(biome),
                        if (value.feedbackNotice case final message?)
                          _feedbackNotice(message),
                        if (value.phase == RunPhase.playing)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [_control(-1), _control(1)],
                            ),
                          ),
                        if (value.phase != RunPhase.playing)
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _save,
                              if (widget.monetization != null)
                                widget.monetization!,
                            ]),
                            builder: (context, _) {
                              final offer = _rewardOffer;
                              _logRewardOffer(offer);
                              return GameOverOverlay(
                                score: value.score,
                                coins: value.coins,
                                paused: value.phase == RunPhase.paused,
                                causeMessage: _causeMessage(value.cause),
                                newPersonalBest: value.newPersonalBest,
                                previousBest: widget.personalBestScore,
                                savePhase: _save.phase,
                                onRetry: _save.retry,
                                rewardActionLabel: offer.label,
                                rewardActionEnabled: offer.enabled,
                                rewardLoading: offer.loading,
                                onRewardRetry: offer.retryable
                                    ? () => unawaited(_retryRewarded())
                                    : null,
                                onReward: _rewardClaimPending
                                    ? () => unawaited(_claimRewardedBonus())
                                    : () => unawaited(_watchRewarded()),
                                rewardBusy: _rewardBusy,
                                rewardStatus: _rewardStatus,
                                onContinue: () =>
                                    unawaited(_continueAfterBreak()),
                                onHome: () => unawaited(_homeAfterBreak()),
                              );
                            },
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
