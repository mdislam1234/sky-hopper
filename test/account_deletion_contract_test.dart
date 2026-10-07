import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account deletion backend contract', () {
    test(
      'every locally declared user-owned table cascades from auth.users',
      () {
        final migrations = Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .map((file) => file.readAsStringSync())
            .join('\n');
        for (final table in [
          'profiles',
          'user_skins',
          'game_scores',
          'run_progression',
          'daily_challenge_results',
          'daily_missions',
          'user_achievements',
          'player_streaks',
          'rewarded_ad_claims',
        ]) {
          final start = migrations.indexOf('create table public.$table');
          expect(start, greaterThanOrEqualTo(0), reason: table);
          final end = migrations.indexOf('\n);', start);
          expect(end, greaterThan(start), reason: table);
          final declaration = migrations.substring(start, end);
          expect(
            declaration,
            contains('references auth.users(id) on delete cascade'),
            reason: table,
          );
        }
      },
    );

    test(
      'Edge Function derives the caller and hard-deletes only that user',
      () {
        final source = File('supabase/functions/delete-account/index.ts')
            .readAsStringSync();
        final config = File('supabase/config.toml').readAsStringSync();
        expect(config, contains('[functions.delete-account]'));
        expect(config, contains('verify_jwt = true'));
        expect(source, contains('caller.auth.getUser(token)'));
        expect(source, contains('admin.auth.admin.deleteUser'));
        expect(source, contains('user.id'));
        expect(source, contains('false,'));
        expect(source, isNot(contains('request.json()')));
        expect(source, isNot(contains('user_id')));
        expect(source, contains('SUPABASE_SERVICE_ROLE_KEY'));
        expect(source, isNot(contains('service_role')));
      },
    );
  });

  group('public account deletion resources', () {
    test('external deletion page provides app and email request paths', () {
      final page = File('web/delete-account/index.html').readAsStringSync();
      expect(page, contains('Sky Hopper · AziTech Studio'));
      expect(page, contains('Profile'));
      expect(page, contains('Delete Account'));
      expect(page, contains('support.azitechstudio@gmail.com'));
      expect(page, contains('do not need to reinstall'));
      expect(page, contains('scores'));
      expect(page, contains('missions'));
      expect(page, contains('achievements'));
      expect(page, contains('streaks'));
    });

    test('privacy policy documents both deletion paths and actual scope', () {
      final policy = File('web/privacy/index.html').readAsStringSync();
      expect(policy, contains('Account deletion'));
      expect(policy, contains('/delete-account/'));
      expect(policy, contains('support.azitechstudio@gmail.com'));
      expect(policy, contains('rewarded-ad reward records'));
      expect(policy, contains('does not delete your Google Account'));
    });
  });
}
