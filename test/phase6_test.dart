import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sky_hopper/app.dart';
import 'package:sky_hopper/core/data/data_exception.dart';
import 'package:sky_hopper/features/game/config/game_config.dart';
import 'package:sky_hopper/features/game/data/game_score_repository.dart';
import 'package:sky_hopper/features/game/models/game_result.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/systems/coin_system.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/game/systems/platform_generator.dart';
import 'package:sky_hopper/features/game/systems/run_save_controller.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/profile/profile_screen.dart';

import 'auth_test.dart' as auth_test;

const run = GameResult(
  runId: '550e8400-e29b-41d4-a716-446655440000',
  score: 12,
  height: 123,
  coinsCollected: 3,
);

Map<String, dynamic> responseFor(GameResult result, {int total = 45}) => {
  'run_id': result.runId,
  'game_score_id': 1,
  'saved_score': result.score,
  'saved_height': result.height,
  'coins_collected': result.coinsCollected,
  'new_total_coins': total,
  'played_at': '2026-09-20T14:00:00Z',
  'profile_updated_at': '2026-09-20T14:00:00Z',
};
SavedGameResult savedFor(GameResult result, {int total = 45}) =>
    SavedGameResult.fromJson(responseFor(result, total: total));

class _Auth extends Fake implements GoTrueClient {
  bool signedIn = true;
  @override
  User? get currentUser => signedIn
      ? User(
          id: 'test-user',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        )
      : null;
}

class _Response<T> extends Fake implements PostgrestFilterBuilder<T> {
  _Response(this.value);
  final Future<T> value;
  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      value.then(onValue, onError: onError);
}

class _Client extends Fake implements SupabaseClient {
  @override
  final _Auth auth = _Auth();
  Object? response = responseFor(run);
  bool fails = false;
  int calls = 0;
  String? rpcName;
  Map<String, dynamic>? arguments;
  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    calls++;
    rpcName = fn;
    arguments = params;
    return _Response(
      Future<T>(() {
        if (fails) {
          throw const PostgrestException(message: 'private SQL details');
        }
        return response as T;
      }),
    );
  }
}

Future<void> finish(RunSaveController save) =>
    save.complete(score: 12, maximumHeight: 123.9, coinsCollected: 3);

void main() {
  test('Coins start at zero and reset with each run', () {
    final state = GameState();
    expect(state.coinsCollected, 0);
    state.advance(GameConfig.fixedStep);
    expect(state.coinsCollected, 1);
    state.reset();
    expect(state.coinsCollected, 0);
  });
  test('Overlap collects exactly once and removes the component data', () {
    final system = CoinSystem();
    final coin = CoinData(110, 110);
    system.coins.add(coin);
    system.collectAt(100, 100);
    expect(coin.collected, isTrue);
    expect(system.coins, isEmpty);
    system.coins.add(coin);
    for (var i = 0; i < 10; i++) {
      system.collectAt(100, 100);
    }
    expect(system.collected, 1);
  });
  test('Missing the coin grants nothing', () {
    final system = CoinSystem()..coins.add(CoinData(110, 110));
    system.collectAt(200, 200);
    expect(system.collected, 0);
    expect(system.coins.length, 1);
  });
  test('Paused and Game Over runs cannot collect coins', () {
    for (final phase in [RunPhase.paused, RunPhase.gameOver]) {
      final state = GameState()..phase = phase;
      state.coinSystem.coins.add(CoinData(state.x, state.y));
      state.advance(0.1);
      expect(state.coinsCollected, 0);
    }
  });
  test('Generated coins are sparse, bounded and above reachable platforms', () {
    final generator = PlatformGenerator(Random(12));
    final coins = CoinSystem();
    var platform = generator.initial().first;
    for (var i = 0; i < 1000; i++) {
      final before = coins.coins.length;
      coins.addPlatform(platform);
      if (coins.coins.length > before) {
        final coin = coins.coins.last;
        expect(coin.x - GameConfig.coinRadius, greaterThanOrEqualTo(0));
        expect(
          coin.x + GameConfig.coinRadius,
          lessThanOrEqualTo(GameConfig.width),
        );
        expect(coin.x, platform.x + platform.width / 2);
        expect(
          platform.y - coin.y,
          closeTo(GameConfig.coinAbovePlatform, 1e-8),
        );
        expect(GameConfig.coinAbovePlatform, lessThan(GameConfig.jumpHeight));
        expect(coin.y + GameConfig.coinRadius, lessThan(platform.y));
      }
      platform = generator.next(platform);
    }
    expect(coins.coins.length, 500);
  });
  test(
    'Coins clean up below the camera and remain bounded during long climbs',
    () {
      final state = GameState();
      for (var i = 0; i < 2000; i++) {
        state.y = -i * 30.0;
        state.vy = -10;
        state.advance(GameConfig.fixedStep);
        expect(state.coinSystem.coins.length, lessThan(12));
        expect(
          state.coinSystem.coins.every(
            (c) =>
                c.y <=
                state.cameraTop + GameConfig.height + GameConfig.cleanupBuffer,
          ),
          isTrue,
        );
      }
    },
  );
  test('Run identifiers are distinct RFC 4122 version 4 UUIDs', () {
    final ids = List.generate(100, (_) => GameResult.newRunId());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      GameResult(runId: id, score: 0, height: 0, coinsCollected: 0).validate();
    }
  });
  test('RPC request contains only frozen gameplay values and run ID', () {
    expect(run.toRpcParams(), {
      'p_run_id': run.runId,
      'p_score': 12,
      'p_height': 123,
      'p_coins_collected': 3,
    });
  });
  test('RPC response parses non-sensitive saved values', () {
    final saved = savedFor(run);
    saved.validateFor(run);
    expect(saved.totalCoins, 45);
    expect(saved.gameScoreId, 1);
    expect(saved.playedAt.isUtc, isTrue);
  });
  test('Malformed and mismatched RPC responses are rejected', () {
    for (final value in <Object?>[
      null,
      [],
      {},
      {...responseFor(run), 'new_total_coins': -1},
      {...responseFor(run), 'game_score_id': 0},
    ]) {
      expect(() => SavedGameResult.fromJson(value), throwsFormatException);
    }
    expect(
      () =>
          SavedGameResult.fromJson({...responseFor(run), 'saved_score': 99})
              .validateFor(run),
      throwsFormatException,
    );
  });
  test('Repository calls the RPC once and never sends a user ID', () async {
    final client = _Client();
    final saved = await GameScoreRepository(client).submitGameResult(run);
    expect(client.calls, 1);
    expect(client.rpcName, 'submit_game_result');
    expect(client.arguments, run.toRpcParams());
    expect(saved.totalCoins, 45);
  });
  test('Repository rejects signed-out access before invoking RPC', () async {
    final client = _Client()..auth.signedIn = false;
    await expectLater(
      GameScoreRepository(client).submitGameResult(run),
      throwsA(
        isA<DataException>().having(
          (e) => e.code,
          'code',
          DataError.unauthenticated,
        ),
      ),
    );
    expect(client.calls, 0);
  });
  test(
    'Repository rejects invalid result values before invoking RPC',
    () async {
      final client = _Client();
      await expectLater(
        GameScoreRepository(client).submitGameResult(
          GameResult(runId: run.runId, score: -1, height: 0, coinsCollected: 0),
        ),
        throwsA(
          isA<DataException>().having(
            (e) => e.code,
            'code',
            DataError.invalidInput,
          ),
        ),
      );
      expect(client.calls, 0);
    },
  );
  test(
    'Repository sanitizes both backend and malformed-response errors',
    () async {
      for (final client in [
        _Client()..fails = true,
        _Client()..response = {},
      ]) {
        await expectLater(
          GameScoreRepository(client).submitGameResult(run),
          throwsA(
            isA<DataException>()
                .having((e) => e.code, 'code', DataError.unavailable)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('private')),
                ),
          ),
        );
      }
    },
  );
  test(
    'Game Over captures immutable result and deduplicates pending saves',
    () async {
      final pending = Completer<SavedGameResult>();
      var calls = 0;
      final save = RunSaveController(
        submit: (_) {
          calls++;
          return pending.future;
        },
      );
      addTearDown(save.dispose);
      final operation = finish(save);
      expect(save.phase, SavePhase.saving);
      expect(save.result!.height, 123);
      expect(save.result!.coinsCollected, 3);
      await save.complete(score: 999, maximumHeight: 999, coinsCollected: 999);
      await save.retry();
      expect(calls, 1);
      pending.complete(savedFor(save.result!));
      await operation;
      expect(save.phase, SavePhase.saved);
      await save.retry();
      await finish(save);
      expect(calls, 1);
    },
  );
  test(
    'Failed save retries exactly the same result; rapid Retry is guarded',
    () async {
      final sent = <GameResult>[];
      final retry = Completer<SavedGameResult>();
      final save = RunSaveController(
        submit: (result) async {
          sent.add(result);
          if (sent.length == 1) throw Exception('private SQL');
          return retry.future;
        },
      );
      addTearDown(save.dispose);
      await finish(save);
      expect(save.phase, SavePhase.failed);
      final operation = save.retry();
      await save.retry();
      expect(sent.length, 2);
      expect(identical(sent[0], sent[1]), isTrue);
      retry.complete(savedFor(sent[0]));
      await operation;
      expect(save.phase, SavePhase.saved);
    },
  );
  test('Timeout permits a safe retry with the same idempotency key', () async {
    final pending = Completer<SavedGameResult>();
    var calls = 0;
    final save = RunSaveController(
      timeout: const Duration(milliseconds: 10),
      submit: (result) {
        calls++;
        return calls == 1 ? pending.future : Future.value(savedFor(result));
      },
    );
    addTearDown(save.dispose);
    await finish(save);
    expect(save.phase, SavePhase.failed);
    final id = save.result!.runId;
    await save.retry();
    pending.complete(savedFor(save.result!));
    expect(save.phase, SavePhase.saved);
    expect(save.result!.runId, id);
  });
  test('Preview never calls persistence and never claims Saved', () async {
    var calls = 0;
    final save = RunSaveController(
      preview: true,
      submit: (r) async {
        calls++;
        return savedFor(r);
      },
    );
    addTearDown(save.dispose);
    await finish(save);
    expect(save.phase, SavePhase.preview);
    expect(calls, 0);
  });
  test('A new run has a fresh ID and lifecycle', () async {
    final old = RunSaveController(preview: true);
    final fresh = RunSaveController(preview: true);
    addTearDown(old.dispose);
    addTearDown(fresh.dispose);
    await finish(old);
    expect(fresh.runId, isNot(old.runId));
    expect(fresh.result, isNull);
    expect(fresh.phase, SavePhase.notStarted);
  });
  test(
    'Disposal during pending save suppresses stale UI notifications',
    () async {
      final pending = Completer<SavedGameResult>();
      final save = RunSaveController(submit: (_) => pending.future);
      final operation = finish(save);
      final result = save.result!;
      save.dispose();
      pending.complete(savedFor(result));
      await operation;
    },
  );
  test('Auth loss blocks save and never credits another account', () async {
    final service = auth_test.FakeAuthService()..signInEvent();
    final auth = auth_test.createAuth(service);
    await auth.start();
    final pending = Completer<SavedGameResult>();
    final operation = auth.submitRunFor(
      'test-user',
      run,
      (_) => pending.future,
    );
    await service.signOut();
    pending.complete(savedFor(run));
    await operation;
    expect(auth.profile, isNull);
    await expectLater(
      auth.submitRunFor('test-user', run, (r) async => savedFor(r)),
      throwsA(isA<DataException>()),
    );
  });
  test(
    'Out-of-order server responses cannot reduce confirmed balance',
    () async {
      final service = auth_test.FakeAuthService()..signInEvent();
      final auth = auth_test.createAuth(service);
      await auth.start();
      await auth.submitRunFor(
        'test-user',
        run,
        (r) async => savedFor(r, total: 50),
      );
      await auth.submitRunFor(
        'test-user',
        run,
        (r) async => savedFor(r, total: 45),
      );
      expect(auth.profile!.totalCoins, 50);
    },
  );
  for (final success in [true, false]) {
    testWidgets(
      'Home/Profile reflect only a confirmed save: success=$success',
      (tester) async {
        final service = auth_test.FakeAuthService()..signInEvent();
        final auth = auth_test.createAuth(service);
        final sent = <GameResult>[];
        await tester.pumpWidget(
          SkyHopperApp(
            authController: auth,
            submitGameResult: (result) async {
              sent.add(result);
              if (!success) throw Exception('private failure');
              return savedFor(result, total: 42 + result.coinsCollected);
            },
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PLAY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final game = tester
            .widget<GameWidget<SkyHopperGame>>(
              find.byType(GameWidget<SkyHopperGame>),
            )
            .game!;
        game.state.coinSystem.collected = 3;
        game.state.progress.observe(123);
        game.state.y = game.state.cameraTop + 900;
        game.update(1 / 60);
        await tester.pump();
        await tester.pump();
        expect(sent.length, 1);
        expect(sent.single.coinsCollected, 3);
        expect(find.text('COINS: 3'), findsOneWidget);
        expect(find.text('Coins Collected: 3'), findsOneWidget);
        expect(
          find.text(success ? 'Saved' : 'Could not confirm save. Try again.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('HOME'));
        await tester.tap(find.text('HOME'));
        await tester.pumpAndSettle();
        expect(find.text('Coins: ${success ? 45 : 42}'), findsOneWidget);
        await tester.ensureVisible(find.text('PROFILE'));
        await tester.tap(find.text('PROFILE'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.text('Coins: ${success ? 45 : 42}'), findsOneWidget);
        expect(sent.length, 1);
      },
    );
  }
  testWidgets('Preview shows coin HUD and explicit saving-disabled state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(preview: true, onHome: () {})),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final game = tester
        .widget<GameWidget<SkyHopperGame>>(
          find.byType(GameWidget<SkyHopperGame>),
        )
        .game!;
    game.state.y = 900;
    game.update(1 / 60);
    await tester.pump();
    expect(find.text('Preview — saving disabled'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
