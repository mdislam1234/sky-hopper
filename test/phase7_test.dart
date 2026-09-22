import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sky_hopper/app.dart';
import 'package:sky_hopper/core/data/data_exception.dart';
import 'package:sky_hopper/features/auth/auth_controller.dart';
import 'package:sky_hopper/features/auth/login_screen.dart';
import 'package:sky_hopper/features/game/components/player_component.dart';
import 'package:sky_hopper/features/game/sky_hopper_game.dart';
import 'package:sky_hopper/features/game/models/game_result.dart';
import 'package:sky_hopper/features/game/systems/game_state.dart';
import 'package:sky_hopper/features/leaderboard/data/leaderboard_repository.dart';
import 'package:sky_hopper/features/leaderboard/leaderboard_screen.dart';
import 'package:sky_hopper/features/leaderboard/models/leaderboard_entry.dart';
import 'package:sky_hopper/features/profile/models/profile.dart';
import 'package:sky_hopper/features/skins/data/skin_repository.dart';
import 'package:sky_hopper/features/skins/models/skin.dart';
import 'package:sky_hopper/features/skins/models/user_skin.dart';
import 'package:sky_hopper/features/skins/skins_controller.dart';
import 'package:sky_hopper/features/skins/skins_screen.dart';
import 'package:sky_hopper/features/skins/widgets/skin_preview.dart';

import 'auth_test.dart' as fixture;
import 'phase6_test.dart' as phase6;

const stamp = '2026-09-21T04:00:00Z';
Map<String, dynamic> boardJson({int rank = 1, bool current = true}) => {
  'rank': rank,
  'display_name': 'Cloud Jumper',
  'avatar_url': null,
  'best_score': 763,
  'best_height': 7630,
  'played_at': stamp,
  'is_current_user': current,
};
Map<String, dynamic> skinJson(String id, int cost) => {
  'id': id,
  'name': id == 'default' ? 'Golden Hopper' : 'Sunset Glow',
  'description': 'Original sky colors.',
  'cost': cost,
  'primary_color': '#FF8B70',
  'secondary_color': '#C94C65',
  'accent_color': '#542344',
};
Map<String, dynamic> unlockJson({bool owned = false}) => {
  'skin_id': 'sunset',
  'already_owned': owned,
  'cost_charged': owned ? 0 : 10,
  'new_total_coins': 22,
  'unlocked_at': stamp,
  'profile_updated_at': stamp,
};
Profile profileWith({int coins = 32, String selected = 'default'}) =>
    Profile.fromJson({
      ...fixture.testProfile.toJson(),
      'total_coins': coins,
      'selected_skin': selected,
      'updated_at': stamp,
    });

class MemoryStore implements SkinStore {
  Profile serverProfile = profileWith();
  List<Skin> catalog = [
    Skin.fromJson(skinJson('default', 0)),
    Skin.fromJson(skinJson('sunset', 10)),
    Skin.fromJson({...skinJson('royal', 100), 'name': 'Royal Blue'}),
  ];
  Set<String> owned = {'default'};
  int unlockCalls = 0, selectCalls = 0;
  bool selectFails = false, loadFails = false;
  Completer<void>? pending;
  @override
  Future<List<Skin>> fetchCatalog() async {
    if (loadFails) throw Exception('private');
    return catalog;
  }

  @override
  Future<List<UserSkin>> fetchOwnedSkins() async => owned
      .map(
        (id) => UserSkin(
          userId: 'test-user',
          skinId: id,
          unlockedAt: DateTime.parse(stamp),
        ),
      )
      .toList();
  @override
  Future<SkinUnlock> unlockSkin(String id) async {
    unlockCalls++;
    await pending?.future;
    final alreadyOwned = owned.contains(id);
    final cost = catalog.singleWhere((skin) => skin.id == id).cost;
    if (!alreadyOwned && serverProfile.totalCoins < cost) {
      throw const DataException(DataError.insufficientCoins);
    }
    if (!alreadyOwned) {
      owned.add(id);
      serverProfile = profileWith(
        coins: serverProfile.totalCoins - cost,
        selected: serverProfile.selectedSkin,
      );
    }
    return SkinUnlock.fromJson({
      ...unlockJson(owned: alreadyOwned),
      'skin_id': id,
      'cost_charged': alreadyOwned ? 0 : cost,
      'new_total_coins': serverProfile.totalCoins,
    });
  }

  @override
  Future<SkinSelection> selectSkin(String id) async {
    selectCalls++;
    if (selectFails) throw Exception('private');
    if (!owned.contains(id)) throw const DataException(DataError.skinNotOwned);
    serverProfile = profileWith(coins: serverProfile.totalCoins, selected: id);
    return SkinSelection(id, DateTime.parse(stamp));
  }
}

class Harness {
  Harness() {
    service.signInEvent();
    auth = AuthController(
      service: service,
      skinStore: store,
      loadProfile: () async => store.serverProfile,
    );
    addTearDown(auth.dispose);
    addTearDown(service.events.close);
  }
  final service = fixture.FakeAuthService();
  final store = MemoryStore();
  late final AuthController auth;
  Future<SkinsController> controller() async {
    await auth.start();
    final result = SkinsController(auth, 'test-user');
    addTearDown(result.dispose);
    await result.load();
    return result;
  }
}

class FakeAuth extends Fake implements GoTrueClient {
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

class Response<T> extends Fake implements PostgrestFilterBuilder<T> {
  Response(this.result);
  final Future<T> result;
  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      result.then(onValue, onError: onError);
}

class Client extends Fake implements SupabaseClient {
  @override
  final FakeAuth auth = FakeAuth();
  Object? response;
  PostgrestException? failure;
  int calls = 0;
  String? name;
  Map<String, dynamic>? paramsSent;
  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    calls++;
    name = fn;
    paramsSent = params;
    return Response(
      Future<T>(() {
        if (failure != null) throw failure!;
        return response as T;
      }),
    );
  }
}

Future<void> screen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

Future<void> openApp(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(
    SkyHopperApp(
      authController: h.auth,
      loadLeaderboard: () async => [LeaderboardEntry.fromJson(boardJson())],
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  test('Leaderboard parses only safe fields and ignores private extras', () {
    final row = LeaderboardEntry.fromJson({
      ...boardJson(),
      'email': 'hidden',
      'user_id': 'hidden',
    });
    expect(row.rank, 1);
    expect(row.bestScore, 763);
    expect(row.bestHeight, 7630);
    expect(row.isCurrentUser, isTrue);
    expect(row.playedAt.isUtc, isTrue);
    expect(row.toString(), isNot(contains('hidden')));
  });
  test('Leaderboard rejects malformed rank score date and current flag', () {
    for (final patch in [
      {'rank': 0},
      {'best_score': -1},
      {'played_at': 'bad'},
      {'is_current_user': 1},
    ]) {
      expect(
        () => LeaderboardEntry.fromJson({...boardJson(), ...patch}),
        throwsFormatException,
      );
    }
  });
  test('Leaderboard blank name and unsafe avatar have safe fallbacks', () {
    final row = LeaderboardEntry.fromJson({
      ...boardJson(),
      'display_name': ' ',
      'avatar_url': 'javascript:bad',
    });
    expect(row.displayName, 'Player');
    expect(row.avatarUrl, isNull);
  });
  test(
    'Leaderboard repository validates limits and returns ranked data',
    () async {
      final c = Client()..response = [boardJson()];
      final repo = LeaderboardRepository(c);
      for (final limit in [0, 101]) {
        await expectLater(
          repo.fetchLeaderboard(limit: limit),
          throwsA(isA<DataException>()),
        );
      }
      expect(c.calls, 0);
      expect((await repo.fetchLeaderboard()).single.bestScore, 763);
      expect(c.name, 'get_leaderboard');
      expect(c.paramsSent, {'p_limit': 50});
    },
  );
  test(
    'Leaderboard repository accepts empty and sanitizes malformed responses',
    () async {
      final c = Client()..response = [];
      expect(await LeaderboardRepository(c).fetchLeaderboard(), isEmpty);
      c.response = [
        {'rank': 0},
      ];
      await expectLater(
        LeaderboardRepository(c).fetchLeaderboard(),
        throwsA(isA<DataException>()),
      );
    },
  );
  test('New repositories guard every signed-out operation', () async {
    final c = Client()..auth.signedIn = false;
    final skins = SkinRepository(c);
    for (final operation in <Future<dynamic> Function()>[
      () => LeaderboardRepository(c).fetchLeaderboard(),
      skins.fetchCatalog,
      skins.fetchOwnedSkins,
      () => skins.unlockSkin('sunset'),
      () => skins.selectSkin('default'),
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<DataException>().having(
            (e) => e.code,
            'code',
            DataError.unauthenticated,
          ),
        ),
      );
    }
    expect(c.calls, 0);
  });
  testWidgets('Leaderboard loading then empty state', (tester) async {
    final pending = Completer<List<LeaderboardEntry>>();
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(load: () => pending.future, onBack: () {}),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No scores yet. Be the first to climb!'), findsOneWidget);
  });
  testWidgets('Leaderboard sanitized error retry and current-user ranking', (
    tester,
  ) async {
    var calls = 0;
    await screen(
      tester,
      LeaderboardScreen(
        onBack: () {},
        load: () async {
          calls++;
          if (calls == 1) throw Exception('private SQL');
          return [
            LeaderboardEntry.fromJson(boardJson()),
            LeaderboardEntry.fromJson({
              ...boardJson(rank: 2, current: false),
              'display_name': 'Other Hopper',
            }),
          ];
        },
      ),
    );
    expect(find.textContaining('private SQL'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(
      tester.widget<Card>(find.byKey(const ValueKey('rank-1'))).color,
      const Color(0xFFFFE69A),
    );
    await tester.tap(find.byTooltip('Refresh leaderboard'));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });
  test('Skin catalog parses cost and safely falls back for invalid colors', () {
    final skin = Skin.fromJson(skinJson('sunset', 10));
    expect(skin.cost, 10);
    expect(skin.appearance.primary, const Color(0xFFFF8B70));
    final bad = Skin.fromJson({
      ...skinJson('default', 0),
      'primary_color': 'red',
      'secondary_color': '#123',
      'accent_color': null,
    });
    expect(bad.appearance.primary, SkinAppearance.defaultSkin.primary);
    expect(bad.appearance.secondary, SkinAppearance.defaultSkin.secondary);
    expect(bad.appearance.accent, SkinAppearance.defaultSkin.accent);
    expect(
      () => Skin.fromJson({...skinJson('default', 0), 'cost': -1}),
      throwsFormatException,
    );
  });
  test(
    'Unlock and select repository send only skin ID and parse confirmed result',
    () async {
      final c = Client()..response = unlockJson();
      final repo = SkinRepository(c);
      expect((await repo.unlockSkin('sunset')).totalCoins, 22);
      expect(c.name, 'unlock_skin');
      expect(c.paramsSent, {'p_skin_id': 'sunset'});
      c.response = {'selected_skin': 'sunset', 'profile_updated_at': stamp};
      expect((await repo.selectSkin('sunset')).skinId, 'sunset');
      expect(c.name, 'select_skin');
      expect(c.paramsSent, {'p_skin_id': 'sunset'});
    },
  );
  test('Already-owned RPC response has no second charge', () async {
    final c = Client()..response = unlockJson(owned: true);
    final result = await SkinRepository(c).unlockSkin('sunset');
    expect(result.alreadyOwned, isTrue);
    expect(result.costCharged, 0);
    expect(result.totalCoins, 22);
    expect(
      () =>
          SkinUnlock.fromJson({...unlockJson(owned: true), 'cost_charged': 10}),
      throwsFormatException,
    );
  });
  test('Skin RPC malformed and mismatched results are sanitized', () async {
    for (final value in [
      null,
      {},
      {...unlockJson(), 'skin_id': 'mint'},
    ]) {
      final c = Client()..response = value;
      await expectLater(
        SkinRepository(c).unlockSkin('sunset'),
        throwsA(isA<DataException>()),
      );
    }
    final c = Client()
      ..response = {'selected_skin': 'mint', 'profile_updated_at': stamp};
    await expectLater(
      SkinRepository(c).selectSkin('sunset'),
      throwsA(isA<DataException>()),
    );
  });
  test('Skin RPC maps controlled failures without raw SQL', () async {
    for (final code in ['SH001', 'SH002', 'XX000']) {
      final c = Client()
        ..failure = PostgrestException(message: 'private SQL', code: code);
      await expectLater(
        SkinRepository(c).unlockSkin('sunset'),
        throwsA(
          isA<DataException>().having(
            (e) => e.message,
            'safe',
            isNot(contains('private SQL')),
          ),
        ),
      );
    }
    final c = Client()
      ..failure = const PostgrestException(message: 'private', code: 'SH001');
    await expectLater(
      SkinRepository(c).unlockSkin('sunset'),
      throwsA(
        isA<DataException>().having(
          (e) => e.message,
          'balance',
          'Not enough coins.',
        ),
      ),
    );
  });
  test(
    'Controller distinguishes owned selected locked and insufficient states',
    () async {
      final h = Harness();
      final store = await h.controller();
      expect(store.owned, {'default'});
      expect(store.selected, 'default');
      expect(store.canUnlock(store.catalog[1]), isTrue);
      expect(store.canUnlock(store.catalog[2]), isFalse);
      await store.unlock(store.catalog[2]);
      expect(store.error, 'Not enough coins.');
      expect(h.store.unlockCalls, 0);
    },
  );
  test(
    'Confirmed unlock lowers shared balance and rapid taps are blocked',
    () async {
      final h = Harness();
      final store = await h.controller();
      h.store.pending = Completer<void>();
      final request = store.unlock(store.catalog[1]);
      await store.unlock(store.catalog[1]);
      expect(h.store.unlockCalls, 1);
      expect(store.busy, isTrue);
      expect(h.auth.profile!.totalCoins, 32);
      h.store.pending!.complete();
      await request;
      expect(h.auth.profile!.totalCoins, 22);
      expect(store.owned, contains('sunset'));
      await store.unlock(store.catalog[1]);
      expect(h.store.unlockCalls, 1);
    },
  );
  test(
    'Locked selection blocked and failed selection preserves previous skin',
    () async {
      final h = Harness();
      final store = await h.controller();
      await store.select(store.catalog[1]);
      expect(h.store.selectCalls, 0);
      await store.unlock(store.catalog[1]);
      h.store.selectFails = true;
      await store.select(store.catalog[1]);
      expect(h.auth.profile!.selectedSkin, 'default');
      expect(store.error, isNot(contains('private')));
    },
  );
  test('Successful selection updates shared profile and appearance', () async {
    final h = Harness();
    final store = await h.controller();
    await store.unlock(store.catalog[1]);
    await store.select(store.catalog[1]);
    expect(h.auth.profile!.selectedSkin, 'sunset');
    expect(h.auth.selectedAppearance.primary, const Color(0xFFFF8B70));
  });
  test(
    'Missing catalog selection falls back without granting ownership',
    () async {
      final h = Harness();
      await h.auth.start();
      h.auth.profile = profileWith(selected: 'missing');
      expect(h.auth.selectedAppearance, SkinAppearance.defaultSkin);
      expect(h.store.owned, {'default'});
    },
  );
  test(
    'Delayed game save response cannot restore coins spent on a skin',
    () async {
      final h = Harness();
      final store = await h.controller();
      final save = Completer<SavedGameResult>();
      final operation = h.auth.submitRunFor(
        'test-user',
        phase6.run,
        (_) => save.future,
      );
      await store.unlock(store.catalog[1]);
      expect(h.auth.profile!.totalCoins, 22);
      save.complete(phase6.savedFor(phase6.run, total: 32));
      await operation;
      expect(h.auth.profile!.totalCoins, 22);
    },
  );
  test(
    'Out-of-order canonical reads cannot overwrite a later balance',
    () async {
      final h = Harness();
      await h.auth.start();
      final first = Completer<Profile?>();
      final second = Completer<Profile?>();
      var reads = 0;
      final auth = AuthController(
        service: h.service,
        skinStore: h.store,
        loadProfile: () => ++reads == 1
            ? Future.value(profileWith())
            : reads == 2
            ? first.future
            : second.future,
      );
      addTearDown(auth.dispose);
      await auth.start();
      final a = auth.refreshConfirmedProfile('test-user');
      final b = auth.refreshConfirmedProfile('test-user');
      second.complete(profileWith(coins: 22));
      await b;
      first.complete(profileWith(coins: 32));
      await a;
      expect(auth.profile!.totalCoins, 22);
    },
  );
  test(
    'Sign-out while unlock is pending suppresses stale profile changes',
    () async {
      final h = Harness();
      final store = await h.controller();
      h.store.pending = Completer<void>();
      final request = store.unlock(store.catalog[1]);
      await h.service.signOut();
      h.store.pending!.complete();
      await request;
      expect(h.auth.profile, isNull);
      await expectLater(
        h.auth.selectSkinFor('test-user', 'sunset'),
        throwsA(isA<DataException>()),
      );
    },
  );
  test(
    'Player uses shared skin drawing with unchanged simulation geometry',
    () {
      final skin = Skin.fromJson(skinJson('sunset', 10));
      final state = GameState();
      final player = PlayerComponent(state, appearance: skin.appearance);
      expect(
        player.art.body.color.toARGB32(),
        skin.appearance.primary.toARGB32(),
      );
      expect(
        player.art.edge.color.toARGB32(),
        skin.appearance.secondary.toARGB32(),
      );
      expect(
        player.art.face.color.toARGB32(),
        skin.appearance.accent.toARGB32(),
      );
      final other = GameState();
      for (var i = 0; i < 100; i++) {
        state.advance(1 / 120);
        other.advance(1 / 120);
      }
      expect(state.x, other.x);
      expect(state.y, other.y);
      expect(
        SkinPreview(appearance: skin.appearance).appearance,
        player.appearance,
      );
    },
  );
  testWidgets(
    'Skins display default owned selected locked and insufficient controls',
    (tester) async {
      final h = Harness();
      await h.auth.start();
      await screen(tester, SkinsScreen(auth: h.auth, onBack: () {}));
      expect(find.text('Golden Hopper'), findsOneWidget);
      expect(find.text('OWNED'), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('action-royal')))
            .onPressed,
        isNull,
      );
      expect(find.text('Not enough coins.'), findsOneWidget);
    },
  );
  testWidgets(
    'Unlock confirmation cancel and confirm update balance then selection',
    (tester) async {
      final h = Harness();
      await h.auth.start();
      await screen(tester, SkinsScreen(auth: h.auth, onBack: () {}));
      final action = find.byKey(const ValueKey('action-sunset'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Unlock Sunset Glow for 10 coins?'), findsOneWidget);
      expect(h.store.unlockCalls, 0);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(h.store.unlockCalls, 0);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('UNLOCK'));
      await tester.pumpAndSettle();
      expect(h.store.unlockCalls, 1);
      expect(find.text('Coins: 22'), findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(h.auth.profile!.selectedSkin, 'sunset');
    },
  );
  testWidgets('Skins loading failure retry is sanitized', (tester) async {
    final h = Harness();
    h.store.loadFails = true;
    await h.auth.start();
    await screen(tester, SkinsScreen(auth: h.auth, onBack: () {}));
    expect(find.textContaining('private'), findsNothing);
    h.store.loadFails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Golden Hopper'), findsOneWidget);
  });
  testWidgets(
    'Home routes, profile balance and game appearance use confirmed skin',
    (tester) async {
      final h = Harness();
      await openApp(tester, h);
      await tester.ensureVisible(find.text('LEADERBOARD'));
      await tester.tap(find.text('LEADERBOARD'));
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SKINS'));
      await tester.tap(find.text('SKINS'));
      await tester.pumpAndSettle();
      expect(find.byType(SkinsScreen), findsOneWidget);
      await h.auth.unlockSkinFor('test-user', 'sunset');
      await h.auth.selectSkinFor('test-user', 'sunset');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Coins: 22'), findsOneWidget);
      await tester.ensureVisible(find.text('PROFILE'));
      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('Selected skin: sunset'), findsOneWidget);
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('PLAY'));
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final game = tester
          .widget<GameWidget<SkyHopperGame>>(
            find.byType(GameWidget<SkyHopperGame>),
          )
          .game!;
      expect(game.appearance.primary, const Color(0xFFFF8B70));
      await h.auth.selectSkinFor('test-user', 'default');
      expect(game.appearance.primary, const Color(0xFFFF8B70));
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final destination in ['LEADERBOARD', 'SKINS']) {
    testWidgets('Sign-out removes protected $destination page', (tester) async {
      final h = Harness();
      await openApp(tester, h);
      await tester.ensureVisible(find.text(destination));
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      await h.service.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(LeaderboardScreen), findsNothing);
      expect(find.byType(SkinsScreen), findsNothing);
    });
  }
  for (final size in [
    const Size(360, 800),
    const Size(430, 900),
    const Size(768, 1024),
    const Size(1280, 720),
  ]) {
    testWidgets('Phase 7 screens fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = Harness();
      await h.auth.start();
      await screen(
        tester,
        LeaderboardScreen(
          onBack: () {},
          load: () async => [LeaderboardEntry.fromJson(boardJson())],
        ),
      );
      expect(tester.takeException(), isNull);
      await screen(tester, SkinsScreen(auth: h.auth, onBack: () {}));
      expect(tester.takeException(), isNull);
    });
  }
}
