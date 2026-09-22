// Development-only visual harness: synthetic data, no Supabase client, no real
// identity, no persistent purchases or saves. Never imported by production main.
import 'package:flutter/material.dart';
import 'package:sky_hopper/core/theme/app_theme.dart';
import 'package:sky_hopper/features/auth/auth_controller.dart';
import 'package:sky_hopper/features/auth/services/auth_service.dart';
import 'package:sky_hopper/features/home/home_screen.dart';
import 'package:sky_hopper/features/game/widgets/game_screen.dart';
import 'package:sky_hopper/features/leaderboard/leaderboard_screen.dart';
import 'package:sky_hopper/features/leaderboard/models/leaderboard_entry.dart';
import 'package:sky_hopper/features/profile/models/profile.dart';
import 'package:sky_hopper/features/skins/data/skin_repository.dart';
import 'package:sky_hopper/features/skins/models/skin.dart';
import 'package:sky_hopper/features/skins/models/user_skin.dart';
import 'package:sky_hopper/features/skins/skins_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = _PreviewStore();
  final auth = AuthController(
    service: _PreviewIdentity(),
    skinStore: store,
    loadProfile: () async => store.profile,
  );
  await auth.start();
  runApp(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Banner(
        message: 'OFFLINE DEMO',
        location: BannerLocation.topEnd,
        child: child!,
      ),
      home: _Menu(auth),
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu(this.auth);
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) {
      void open(Widget child) =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => child));
      void back() => Navigator.of(context).pop();
      return HomeScreen(
        profile: auth.profile,
        onLeaderboard: () => open(
          LeaderboardScreen(
            onBack: back,
            load: () async => [
              LeaderboardEntry(
                rank: 1,
                displayName: 'Preview Hopper',
                bestScore: 123,
                bestHeight: 1230,
                playedAt: DateTime.utc(2026),
                isCurrentUser: true,
              ),
              LeaderboardEntry(
                rank: 2,
                displayName: 'Cloud Explorer',
                bestScore: 95,
                bestHeight: 950,
                playedAt: DateTime.utc(2026),
                isCurrentUser: false,
              ),
            ],
          ),
        ),
        onSkins: () => open(SkinsScreen(auth: auth, onBack: back)),
        onPlay: () => open(
          GameScreen(
            preview: true,
            appearance: auth.selectedAppearance,
            onHome: back,
          ),
        ),
      );
    },
  );
}

class _PreviewIdentity implements AuthService {
  @override
  AuthIdentity get currentUser => const AuthIdentity(id: 'offline-preview');
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<void> restoreSession() async {}
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<void> signOut() async {}
}

class _PreviewStore implements SkinStore {
  Profile profile = Profile(
    id: 'offline-preview',
    displayName: 'Preview Hopper',
    totalCoins: 32,
    selectedSkin: 'default',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final owned = {'default'};
  final catalog = [
    for (final entry in [
      ('default', 'Golden Hopper', 0, '#FFD45A', '#E9A834', '#123B69'),
      ('sunset', 'Sunset Glow', 10, '#FF8B70', '#C94C65', '#542344'),
      ('mint', 'Mint Breeze', 25, '#74E3B4', '#299C84', '#174C53'),
      ('cosmic', 'Cosmic Drift', 50, '#B29AFF', '#7552BD', '#35245C'),
      ('royal', 'Royal Blue', 100, '#72B8FF', '#326ABC', '#17365D'),
    ])
      Skin.fromJson({
        'id': entry.$1,
        'name': entry.$2,
        'cost': entry.$3,
        'description': 'Preview colors — no real purchase.',
        'primary_color': entry.$4,
        'secondary_color': entry.$5,
        'accent_color': entry.$6,
      }),
  ];
  @override
  Future<List<Skin>> fetchCatalog() async => catalog;
  @override
  Future<List<UserSkin>> fetchOwnedSkins() async => [
    for (final id in owned)
      UserSkin(userId: profile.id, skinId: id, unlockedAt: DateTime.utc(2026)),
  ];
  @override
  Future<SkinUnlock> unlockSkin(String skinId) async {
    final cost = catalog.singleWhere((s) => s.id == skinId).cost;
    final already = owned.contains(skinId);
    if (!already && profile.totalCoins < cost) {
      throw StateError('Preview balance');
    }
    if (!already) {
      owned.add(skinId);
      profile = Profile.fromJson({
        ...profile.toJson(),
        'total_coins': profile.totalCoins - cost,
      });
    }
    return SkinUnlock(
      skinId: skinId,
      alreadyOwned: already,
      costCharged: already ? 0 : cost,
      totalCoins: profile.totalCoins,
      unlockedAt: DateTime.utc(2026),
      profileUpdatedAt: profile.updatedAt,
    );
  }

  @override
  Future<SkinSelection> selectSkin(String skinId) async {
    if (!owned.contains(skinId)) throw StateError('Preview ownership');
    profile = Profile.fromJson({...profile.toJson(), 'selected_skin': skinId});
    return SkinSelection(skinId, profile.updatedAt);
  }
}
