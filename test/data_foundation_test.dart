import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sky_hopper/core/config/supabase_config.dart';
import 'package:sky_hopper/core/data/data_exception.dart';
import 'package:sky_hopper/core/data/repository_support.dart';
import 'package:sky_hopper/core/data/supabase_bootstrap.dart';
import 'package:sky_hopper/features/profile/models/profile.dart';
import 'package:sky_hopper/features/game/models/game_score.dart';
import 'package:sky_hopper/features/game/models/game_result.dart';
import 'package:sky_hopper/features/skins/models/user_skin.dart';
import 'package:sky_hopper/features/profile/data/profile_repository.dart';
import 'package:sky_hopper/features/game/data/game_score_repository.dart';
import 'package:sky_hopper/features/skins/data/skin_repository.dart';

// No SDK initialization, credentials, fake signed-in users, or network transport.
class SignedOutAuth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

class SignedOutClient extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth = SignedOutAuth();
}

void main() {
  const timestamp = '2026-09-20T06:00:00.000Z';
  const profileJson = <String, dynamic>{
    'id': 'profile-fixture',
    'display_name': 'Hopper',
    'avatar_url': null,
    'total_coins': 0,
    'selected_skin': 'default',
    'created_at': timestamp,
    'updated_at': timestamp,
  };
  const scoreJson = <String, dynamic>{
    'id': 1,
    'user_id': 'profile-fixture',
    'score': 120,
    'height': 80,
    'coins_collected': 3,
    'played_at': timestamp,
  };
  const skinJson = <String, dynamic>{
    'user_id': 'profile-fixture',
    'skin_id': 'default',
    'unlocked_at': timestamp,
  };

  test(
    'Missing configuration intentionally skips SDK initialization',
    () async {
      const config = SupabaseConfig(url: '', publishableKey: '');
      expect(config.isAbsent, isTrue);
      expect(config.isConfigured, isFalse);
      expect(await initializeSupabase(config: config), isNull);
    },
  );

  test('Partial configuration is rejected before SDK initialization', () async {
    for (final config in [
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: '',
      ),
      const SupabaseConfig(url: '', publishableKey: 'test-only'),
    ]) {
      await expectLater(
        initializeSupabase(config: config),
        throwsFormatException,
      );
    }
  });

  test('Only HTTPS origins and publishable client key format are accepted', () {
    // A format fixture only; never passed to Supabase.initialize.
    const formatOnlyKey = 'sb_publishable_format_test';
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: formatOnlyKey,
      ).validate,
      returnsNormally,
    );
    for (final url in [
      'http://example.com',
      'https://user:password@example.com',
      'https://example.com/path',
      'https://example.com?token=test',
      'not a URL',
    ]) {
      expect(
        SupabaseConfig(url: url, publishableKey: formatOnlyKey).validate,
        throwsFormatException,
      );
    }
    for (final key in ['sb_secret_test', 'eyJ.test.signature', 'invalid']) {
      expect(
        SupabaseConfig(
          url: 'https://example.supabase.co',
          publishableKey: key,
        ).validate,
        throwsFormatException,
      );
    }
  });

  test('Profile round trip and nullable presentation fields', () {
    final profile = Profile.fromJson(profileJson);
    expect(profile.displayName, 'Hopper');
    expect(profile.avatarUrl, isNull);
    expect(profile.createdAt.isUtc, isTrue);
    expect(profile.toJson(), profileJson);
    final defaults = Profile.fromJson({
      'id': 'profile-fixture',
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    expect(defaults.displayName, isNull);
    expect(defaults.totalCoins, 0);
    expect(defaults.selectedSkin, 'default');
  });

  test('Profile rejects malformed and negative values', () {
    for (final patch in [
      {'total_coins': -1},
      {'total_coins': 1.5},
      {'total_coins': 2147483648},
      {'display_name': 42},
      {'selected_skin': ''},
      {'created_at': 'invalid'},
      {'id': ''},
    ]) {
      expect(
        () => Profile.fromJson({...profileJson, ...patch}),
        throwsFormatException,
      );
    }
  });

  test('Score round trip and default coin count', () {
    expect(GameScore.fromJson(scoreJson).toJson(), scoreJson);
    final withoutCoins = Map<String, dynamic>.of(scoreJson)
      ..remove('coins_collected');
    expect(GameScore.fromJson(withoutCoins).coinsCollected, 0);
  });

  test('Scores reject missing or invalid numeric fields', () {
    for (final patch in [
      {'id': 0},
      {'score': -1},
      {'score': 1.5},
      {'height': null},
      {'coins_collected': -2},
      {'played_at': 'invalid'},
    ]) {
      expect(
        () => GameScore.fromJson({...scoreJson, ...patch}),
        throwsFormatException,
      );
    }
  });

  test('Skin round trip and nonempty identifiers', () {
    expect(UserSkin.fromJson(skinJson).toJson(), skinJson);
    expect(
      () => UserSkin.fromJson({...skinJson, 'skin_id': ''}),
      throwsFormatException,
    );
    expect(
      () => UserSkin.fromJson({...skinJson, 'user_id': null}),
      throwsFormatException,
    );
  });

  test('Timestamp offsets normalize to UTC', () {
    final skin = UserSkin.fromJson({
      ...skinJson,
      'unlocked_at': '2026-09-20T12:00:00+06:00',
    });
    expect(skin.unlockedAt, DateTime.parse(timestamp));
  });

  test(
    'Every current-user repository operation rejects signed-out access',
    () async {
      final client = SignedOutClient();
      final profile = ProfileRepository(client);
      final scores = GameScoreRepository(client);
      final skins = SkinRepository(client);
      final unauthenticated = throwsA(
        isA<DataException>().having(
          (e) => e.code,
          'code',
          DataError.unauthenticated,
        ),
      );
      for (final operation in <Future<dynamic> Function()>[
        profile.fetchCurrent,
        () => profile.updateDisplayName('Hopper'),
        () => profile.updateSelectedSkin('default'),
        () => scores.submitGameResult(
          GameResult(
            runId: GameResult.newRunId(),
            score: 0,
            height: 0,
            coinsCollected: 0,
          ),
        ),
        () => scores.fetchRecent(),
        scores.fetchBest,
        skins.fetchUnlocked,
      ]) {
        await expectLater(operation(), unauthenticated);
      }
    },
  );

  test(
    'Data layer sanitizes raw failures and preserves application errors',
    () async {
      await expectLater(
        dataOperation(
          () async =>
              throw const PostgrestException(message: 'private SQL details'),
        ),
        throwsA(
          isA<DataException>()
              .having((e) => e.code, 'code', DataError.unavailable)
              .having(
                (e) => e.toString(),
                'message',
                isNot(contains('private SQL')),
              ),
        ),
      );
      await expectLater(
        dataOperation(
          () async => throw const DataException(DataError.invalidInput),
        ),
        throwsA(
          isA<DataException>().having(
            (e) => e.code,
            'code',
            DataError.invalidInput,
          ),
        ),
      );
    },
  );
}
