# Sky Hopper

Sky Hopper is a Flutter/Flame endless jumping game with Google Login, user-specific Supabase data, collectible coins, retry-safe result saving, a leaderboard and cosmetic skins.

- Public source: https://github.com/mdislam1234/sky-hopper
- Live Web app: https://sky-hopper-blue.vercel.app
- Final assignment artifacts and current verification: see **Phase 9 submission** below. Earlier phase sections retain their historical verification checkpoints.
Splash resolves authentication before Login or Home. PLAY preserves the endless jumper and retry-safe result persistence. LEADERBOARD shows public best scores through a restricted RPC; SKINS supports server-priced unlocks and owned-skin selection. Live and offline verification are distinguished below.

## Toolchain

- Flutter 3.47.5 / Dart 3.13.4
- Flame 1.38.2; supabase_flutter 2.17.2; google_mobile_ads 9.1.0 (see pubspec.lock)
- SDK: `C:\Users\Admin\development\flutter`
- Android application ID: `com.skyhopper.game`
- Dart package: `sky_hopper`; display name: Sky Hopper

## Supabase database

The project-scoped `supabase` MCP connection was used for database inspection, the initial migration, and read-only verification.

- Project reference: `ittdhvlfrrjnsvdfpznl`
- URL: https://ittdhvlfrrjnsvdfpznl.supabase.co
- Migration: `supabase/migrations/20260920063222_initial_sky_hopper_schema.sql`
- Hosted migration: `20260920063222 / initial_sky_hopper_schema`
- Phase 6 migration: `supabase/migrations/20260920141703_submit_game_result_rpc.sql`, applied once through MCP with the matching hosted timestamp.
- Phase 7 migration: `supabase/migrations/20260921032356_leaderboard_and_skins.sql`, applied once through MCP.
- The hosted SQL and local migration MD5 both equal `2481c9a35392126533828fe88e2f0343`.
- The migration was applied once through MCP. The resumed work did not reapply it.
- No fake users, scores, or ownership rows were inserted. Phase 7 seeds five authoritative catalog definitions.

| Public table | Fields and constraints |
| --- | --- |
| profiles | Auth user UUID primary key; nullable display_name/avatar_url; nonnegative total_coins default 0; selected_skin default default; created_at/updated_at timestamps. |
| game_scores | Bigint identity primary key; Auth user UUID; nonnegative integer score, height, coins_collected; server timestamp played_at; nullable historical run_id UUID with unique (user_id, run_id). |
| user_skins | Composite primary key (user_id, skin_id); nonblank skin ID; unlocked_at timestamp. |
| skin_catalog | Text ID primary key; name, description, nonnegative cost, primary/secondary/accent hex colors, sort_order, is_active and created_at. |

All three user foreign keys reference auth.users(id) with ON DELETE CASCADE. A composite FK from profiles(id, selected_skin) to user_skins(user_id, skin_id) prevents selecting an unowned skin.

### Ownership and security

RLS is enabled on all four tables. The five original policies target only the authenticated role and match auth.uid() to the owner; the catalog has a separate authenticated active-entry SELECT policy:

- `profiles_select_own`: read own profile.
- `profiles_update_own`: update own profile, with ownership checked before and after.
- `game_scores_select_own`: read own scores.
- `game_scores_insert_own`: original owner-only insert policy retained; Phase 6 revokes direct client INSERT grants so new writes must use the RPC.
- `user_skins_select_own`: read own unlocked skins.

Column grants restrict direct profile updates to display_name and avatar_url. Phase 7 revokes direct selected_skin updates; selection must use the ownership-validating RPC. Clients cannot directly alter coin balances or timestamps, insert profiles or scores, unlock skins, edit the catalog, or update/delete scores. The authenticated result RPC remains the sole client path for inserting scores and incrementing coins. Anonymous roles have no application-table access.

The result RPC enforces ownership, validation, atomicity and duplicate protection; it cannot prove that client-reported gameplay actually occurred. Server-authoritative anti-cheat is not implemented. Phase 7's leaderboard RPC exposes only limited public ranking fields without widening owner-only table policies.

### Triggers and indexes

Private functions live in the non-client-accessible `sky_hopper_private` schema with explicitly empty search_path and no client EXECUTE grants.

- `initialize_user()`: SECURITY DEFINER; the `sky_hopper_auth_user_created` AFTER INSERT trigger on auth.users adds the default skin and profile with conflict-safe inserts. Display name uses full_name, then name metadata, otherwise null. Metadata grants no privileges.
- `set_updated_at()`: SECURITY INVOKER; the `sky_hopper_profile_updated` BEFORE UPDATE trigger refreshes profiles.updated_at.
- Indexes: the three primary-key indexes, `game_scores_user_recent_idx` (user_id, played_at DESC, id DESC), `game_scores_score_idx` (score DESC, played_at DESC, id DESC), and `game_scores_played_at_idx` (played_at DESC).

After the user's real Google signup, a read-only MCP query confirmed the matching profile and default skin row. No artificial Auth user was created for verification.

## Flutter configuration

`lib/core/config/supabase_config.dart` reads these compile-time Dart defines:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

When both are absent, bootstrap explicitly runs in UI-only mode and does not initialize Supabase. A partial or malformed configuration fails validation. A complete configuration initializes the SDK before runApp. Only HTTPS origins and the new `sb_publishable_` client-key format are accepted; privileged keys and legacy JWT-format keys are rejected. Format validation cannot establish whether a key belongs to the project.

SDK errors are not logged with configuration or token payloads. Initialization failures produce a sanitized error. OAuth callback handling and session-based navigation are implemented in Phase 4; see configuration and verification status below.

There is no embedded key, database password, service_role credential, personal access token, or MCP token in the application. Dart defines are compiled into client artifacts and must contain only public client configuration, never secrets. No actual publishable key is included in this README.

### Launch from PowerShell

Without backend configuration (current UI works):

```powershell
& 'C:\Users\Admin\development\flutter\bin\flutter.bat' run -d chrome --web-port 3000
```

With real public client configuration supplied by you:

```powershell
& 'C:\Users\Admin\development\flutter\bin\flutter.bat' run -d chrome --web-port 3000 `
  --dart-define=SUPABASE_URL=https://ittdhvlfrrjnsvdfpznl.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<YOUR_PUBLISHABLE_KEY>
```

Replace the key placeholder before running. If Flutter is on PATH, use `flutter run -d chrome --web-port 3000` with the same arguments. Build commands need the same defines for configured artifacts; verification builds in this phase omit them intentionally.

## Data layer

- Models: Profile, GameScore, UserSkin in their feature's models folder. Manual JSON parsing handles nullable fields, defaults, required values, numeric validation, and UTC timestamps. Full-row toJson methods are not write payloads.
- ProfileRepository: fetch current profile, update display name, select an owned skin.
- GameScoreRepository: submitGameResult calls the atomic RPC, fetchRecent reads paginated own scores, and fetchBest reads the user's best score. The old direct insert method was replaced.
- SkinRepository: fetch active catalog and current ownership, unlock via RPC, and select via RPC. ProfileRepository's existing selection method also delegates to the secure RPC.
- LeaderboardRepository: bounded best-score leaderboard RPC reads. LeaderboardEntry deliberately has no email, account UUID or auth metadata fields.
- Repositories receive a SupabaseClient and derive identity from its auth.currentUser. They accept no arbitrary user IDs. A missing user produces DataException(unauthenticated) before any request.
- Shared DataException hides raw database/network error details. Authenticated Home receives the loaded profile; guest placeholders are limited to explicit offline preview tests.
- Android's main manifest declares INTERNET for future configured builds.

## Validation

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

Use the SDK's bin/flutter.bat and bin/dart.bat explicitly if not on PATH.

Existing widget tests cover startup timing/disposal, route replacement, all menu actions, rapid taps, six viewport sizes, and large text. Data tests cover absent/partial/invalid configuration, model parsing/round trips/defaults, invalid values, UTC conversion, signed-out repository guards, and sanitized errors. They do not initialize a live client, require credentials, or create signed-in users.

## Scope

Gameplay/GameWidget mounting is implemented in Phase 5. Phase 6 adds coin collection and authenticated atomic score/coin persistence. Phase 7 adds the leaderboard, skin catalog, unlock/selection and cosmetic rendering. Phase 8 adds Web manifest/icons, startup recovery, visual/accessibility polish and production-output verification. Publishing/deployment and release packaging remain future work; audio and extra gameplay systems are not implemented.


## Phase 3 verification results

- `flutter pub get`: passed; compatible versions locked.
- `dart format .`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 21 tests passed (11 data-layer tests and 10 preserved UI tests).
- `flutter build web`: passed, including the compiler's Wasm dry run.
- Final read-only MCP verification: three application tables, all with RLS; five owner policies; four FKs; six indexes; two enabled triggers and two private functions. All application tables are empty. Hosted/local migration SQL hashes match.
- No MCP advisor/lint endpoint was exposed. PostgreSQL catalog and privilege checks verified the Phase 3 access configuration instead.
- No live Flutter-to-Supabase network/authentication test was performed. No publishable key was supplied, and the builds use intentional UI-only mode. Authenticated CRUD and signup-trigger execution will need real-user verification in the authentication phase.
- No privileged credential pattern was found in the 65 source/configuration files scanned. Matches for credential terminology were documentation, validation logic, and clearly synthetic test inputs. No service_role key, database password, MCP token, or real client key was added.
- This folder is not a Git repository; no commit was created, and historical commits cannot be audited here.
- Pub reports newer versions of four transitive packages outside the current constraints; dependency resolution succeeds.
- `flutter build apk --debug`: passed; output is build/app/outputs/flutter-apk/app-debug.apk. Gradle emitted a Java native-access warning but completed successfully. No application compiler/analyzer warnings remain.


## Phase 4 authentication

### Implemented in code

- Browser-based Google OAuth through Supabase `signInWithOAuth(OAuthProvider.google)`, using PKCE and the existing supabase_flutter package. No google_sign_in or state-management package was added.
- SupabaseAuthService exposes current identity, current SDK session, auth changes, bounded expired-session refresh, Google launch, and sign-out.
- AuthController uses Flutter ChangeNotifier and injected services/profile loader for deterministic offline tests. It handles startup, profile loading/retry, sanitized errors, sign-out, and stale asynchronous responses.
- Splash lasts two seconds; unresolved sessions remain on a loading screen. Signed-out sessions lead to Login; authenticated sessions load their existing profile before Home.
- Declarative built-in Navigator pages use centralized names. Auth identity/state changes replace the protected navigator so logout/back navigation cannot reveal the previous Home/Profile.
- Login matches the sky theme and offers Continue with Google. Repeated launches are disabled while pending. Cancel or a 60-second pending timeout restores the button; launch failures are sanitized. Cancel resets the local waiting UI, not Google's remote consent/session.
- Home reads display_name and total_coins from ProfileRepository. Null/blank names fall back to Player. Phase 5 connects PLAY to gameplay; LEADERBOARD and SKINS remain placeholders.
- Profile shows display name, available HTTPS avatar with fallback, Auth email, coins, selected skin, and SIGN OUT. Email is not copied to the database.
- No profile inserts or coin updates occur in Flutter. Google metadata synchronization is optional and is not performed here; the signup trigger already derives the initial display name. Actual provider metadata has not been inspected without a real login.
- SDK session persistence/recovery and callback handling are enabled. Expired sessions are refreshed before routing; restored-session and logout behavior are covered with fakes, not a live Google account.
- Missing Dart defines visibly disable sign-in. Partial/invalid configuration fails validation. `SkyHopperApp(offlinePreview: true)` is an explicit UI-test/development override; main.dart never enables it.

### External configuration — user action required

Provider settings are not exposed by this MCP connection. Real Web Google login was subsequently verified by the user; keep this checklist for fresh environments and future deployment.

1. In Google Auth Platform/Cloud, configure consent and create an OAuth client of type **Web application** for this hosted-browser flow.
2. Add `http://localhost:3000` under Authorized JavaScript origins.
3. Add this **Google Authorized Redirect URI**:
   `https://ittdhvlfrrjnsvdfpznl.supabase.co/auth/v1/callback`.
4. In Supabase Dashboard → Authentication → Providers → Google, enable Google and enter the Web Client ID and Client Secret. The secret belongs only in those dashboards, never Flutter, this repository, or chat.
5. If the consent app is in Testing mode, configure the Google account used for testing as an allowed test user where required.
6. In Supabase Authentication → URL Configuration, set the development Site URL to `http://localhost:3000` and allow both `http://localhost:3000/` and `com.skyhopper.game://login-callback/`.
7. Obtain the project's Publishable Key from the dashboard and supply it to Flutter via Dart defines. Do not commit it.
8. Production web origins and exact redirects must be added during deployment. No production URL or wildcard pattern has been guessed.

Current official references consulted via MCP:
- [Google provider setup](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Flutter setup/deep links](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter#setup-deep-links)

### Redirect architecture

Google returns to the Supabase callback first. Supabase then returns to the app's allowed redirect.

- **Web:** `Uri.base.origin` plus a trailing slash; localhost is not hard-coded in production logic. Deploy the app at the origin root and allow the exact production origin in Supabase when ready.
- **Android:** `com.skyhopper.game://login-callback/`. The manifest adds a VIEW/DEFAULT/BROWSABLE intent filter with this scheme/host, preserving the launcher and application ID. Flutter's built-in deep-link handler is disabled so supabase_flutter's app_links handler receives the callback.
- SDK callback handling performs the PKCE code exchange. The app never logs tokens, reads provider tokens into UI, or handles Google passwords.

PowerShell local Web launch (replace the placeholder before running):

```powershell
& 'C:\Users\Admin\development\flutter\bin\flutter.bat' run -d chrome --web-port 3000 `
  --dart-define=SUPABASE_URL=https://ittdhvlfrrjnsvdfpznl.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<YOUR_PUBLISHABLE_KEY>
```

For Android, use the same defines with `flutter run -d <device-id>`. The exact Android callback must be allowlisted. A successful APK build does not verify browser return or Google consent on a device.

### Phase 4 verification

- Analysis: passed with no issues.
- Offline tests: 36 passed (all prior coverage retained, 15 auth tests added).
- Tests cover signed-out startup, restored-session routing, missing configuration, profile presentation/navigation, launch deduplication, cancellation/failure, missing-profile retry, late responses after logout, safe errors, protected-stack clearing, redirects, and large-text responsive layouts.
- MCP read-only readiness checks confirmed profiles/game_scores/user_skins with RLS enabled and the existing signup trigger. No schema, policy, migration, or Auth-user writes were performed.
- **Real Web Google login: subsequently verified by the user before Phase 5.**
- **Real Android Google login: not verified.**
- **Live session restoration: not verified** (offline state-routing tests pass).
- **Profile/default skin after real Google signup: subsequently verified through read-only MCP.**
- **Live logout: not verified** (offline logout/back-navigation tests pass).
- No runtime publishable key is stored in the repository. Configured builds still require public client Dart defines. Android OAuth and live session/logout checks remain separate from offline tests.

After configuration, verify Login → Google consent → callback → Home, real profile/coins, Profile → SIGN OUT, and refresh/session restoration. Only then use read-only MCP queries to confirm the real user's profile/default skin, without retrieving tokens or printing private values.

- Android plugin deep-link delegation follows the [official Flutter guidance](https://docs.flutter.dev/cookbook/navigation/set-up-app-links).
- Phase 4 source/configuration scan: no credential-pattern matches across 71 files; application logging contains only the static missing-configuration message. No credentials or tokens were introduced. The folder remains without Git metadata, so no commit/history audit is possible.
- Phase 4 Web production build: passed, including the compiler Wasm dry run. This does not establish live OAuth success.
- Phase 4 Android debug APK build: passed; build/app/outputs/flutter-apk/app-debug.apk. Gradle emitted a non-fatal Java native-access warning.
- Final Phase 4 MCP read-only check: all three application tables retain RLS, all five owner policies remain, signup trigger is enabled, and migration count remains one. No Phase 4 migration was applied.

## Phase 5 gameplay

### Implemented

- Flame GameWidget launched from authenticated Home; no new authentication flow or Supabase operations on entering gameplay.
- Original programmatic golden hopper, mint floating platforms, sky background and lightweight parallax clouds; no downloaded assets or new dependencies.
- Automatic bounce, acceleration, speed limit, release drag, full-body horizontal screen wrap, and one-way platform landings.
- Eight deterministic starting platforms followed by seeded procedural generation and cleanup below the camera.
- Upward-only camera tracking, maximum-height score, Flutter HUD, pause/resume, Game Over, Restart, and Home return.
- App background/focus loss pauses and clears held input. SafeArea contains HUD and touch controls.
- A fresh Flame instance per entry/restart disposes the old GameWidget, resets all components/camera/score, and prevents duplicate players or generators.

### Controls and layout

Desktop/Web: hold Left Arrow or A to move left; Right Arrow or D to move right. Escape or the pause icon opens Resume/Home. Mobile: hold either translucent arrow near the bottom corners. Opposite simultaneous inputs cancel; releasing or cancelling pointers clears movement.

The game uses a centered 400 x 720 logical viewport with preserved aspect ratio. A desktop window shows a portrait playfield rather than stretching the geometry or making jumps easier. Flutter overlays use screen-space touch targets within that playfield. Four representative viewport sizes are covered by widget tests: 360x800, 430x900, 1280x720, and 400x700.

### Physics and tuning

`lib/features/game/config/game_config.dart` centralizes physics, dimensions, generation, camera, and scoring values. `systems/game_state.dart` is a pure simulation with 120 Hz fixed steps. A frame contributes at most 100 ms to avoid catching up an entire background interval. Gravity is 1200 units/s², bounce speed is 600 units/s, theoretical jump height is 150 units (about 147.5 with discrete integration), and horizontal maximum speed is 240 units/s.

Generated gaps are 75–100 units, with 104-unit platforms. Horizontal placement derives its safe displacement from the descending flight time, subtracts acceleration time, reserves reaction/braking time, caps displacement at 90 units, and clamps platforms inside the world. Initial gaps are 80 units and their steering paths are tested with the actual simulation. Difficulty stays stable.

Collision checks sweep the player's feet across platform tops only while descending. Horizontal overlap is measured at the crossing time, before applying screen wrap, so a wrap cannot sweep across unrelated platforms. The earliest crossed surface wins. There are no underside or side bounces.

Camera tracking starts at world-screen y=280 and only moves upward. It follows the player's new highest position continuously, without snapping between platforms or tracking downward falls. Platforms are generated 180 units above the camera and removed 140 units below the visible region. Falling 80 units below the viewport ends the run. The final score is floor(maximum upward progress / 10); it never falls and is never persisted.

`SkyHopperGame` synchronizes the pure simulation with PlayerComponent, PlatformComponent and the fixed-resolution Flame camera. Flutter widgets own the score HUD, controls and pause/Game Over overlays. Status notifications occur only when the score or run phase changes. Paints are reused; active platform count is bounded. Debug drawing defaults to false.

### Offline gameplay preview

Production `lib/main.dart` still requires the existing authenticated flow. For development without credentials, use the separate, clearly labeled gameplay-only entry point; it neither fabricates an identity nor initializes a backend:

```powershell
& 'C:\Users\Admin\development\flutter\bin\flutter.bat' run -d chrome --web-port 3085 -t tool/game_preview.dart
```

Its Home button returns to the preview menu. Production Home returns to the same authenticated profile. Port 3085 was used during Phase 5 because port 3000 could not be bound. Browser automation used Flutter's web-server device and the in-app browser rather than launching a separate Chrome window.

### Scope and regression boundaries

Not implemented: coin collection, Supabase score saving, leaderboard, moving/breaking platforms, power-ups, enemies, sound/music, haptics, skin gameplay/store, production PWA or deployment. Existing profile balances are untouched. No schema, migrations, policies, triggers, repositories, configuration, OAuth service, or AuthController changes were made in Phase 5. AuthGate only gains a protected game page and removes it on auth loss.

The prior 36 tests remain intact. Gameplay tests cover maximum score, game-over freeze/reset, 10,000 generated gaps, actual initial reachability, edge/center/missed/underside/fast-fall collisions, wrap seam collisions, frame-rate consistency, movement acceleration/drag, camera/cleanup, four viewport sizes, keyboard/touch release, pause/resume, repeated component replacement, Home return, and sign-out while gameplay is active.

Camera integration follows the installed Flame 1.38.2 source and [official camera documentation](https://docs.flame-engine.org/latest/flame/camera.html).

### Phase 5 final verification — complete

- `flutter pub get` and `dart format .`: passed during implementation.
- `flutter analyze`: passed with no issues after the camera fix.
- `flutter test`: all **57 tests passed** (36 preserved tests plus 21 gameplay tests).
- Camera regression: the integration test in `test/game_test.dart` checks that the actual Flame viewfinder position matches the simulation camera within 0.001 units and moves above zero. The implementation assigns through the viewfinder position setter; mutating the getter's copied vector did not update the camera.
- `flutter build web`: passed after the camera fix.
- `flutter build apk --debug`: passed after the camera fix; artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- The user confirmed all four final analyze/test/Web/APK checks from PowerShell when resuming Phase 5. Completion work preserved those successful results and did not rerun the suite or builds unnecessarily.
- Browser gameplay verification passed using the offline preview: PLAY, automatic bounces, keyboard steering, reachable platforms, increasing score, corrected camera scrolling, pause, natural fall/Game Over, fresh Restart, and Home return. Layouts were inspected at 360x800, 430x900, 1280x720, and 400x700, alongside the widget checks.
- Authentication regression: all prior tests pass; the gameplay integration test covers authenticated PLAY, Home return, repeated restarts, and removal of gameplay on sign-out. Production `main.dart` does not import or enable the development preview. Live Google authentication was not repeated for Phase 5.
- Supabase/database changes: **NONE**. Gameplay does not import or call the existing score repository or any database client. The sole migration retains MD5 `2481c9a35392126533828fe88e2f0343`; no database files were changed and no migration was run.
- Source/configuration credential scan during implementation: no matching credential patterns. This directory has no Git metadata, so no commit-history comparison is available.
- Remaining validation/tuning: physical Android gameplay has not been verified. Device touch feel and longer play sessions may inform later tuning; no known blocking gameplay issue remains from current checks. APK compilation is separate from physical-device verification.

Phase 5 is complete. The section above records its scope and verification before the Phase 6 additions below.

## Phase 6 coins and persistence

Subsequent live verification: the user's real saved run was confirmed through read-only MCP on 2026-09-21: score 763, height 7630, coins_collected 32, played_at 2026-09-21 03:15:24.896259 UTC. Lifetime coins increased exactly 0 → 32, with one row for the non-null run UUID and no duplicate. The initial pending notes below describe the earlier verification snapshot. Physical Android persistence has not been verified.

### Gameplay and result capture

Original programmatic coins appear above every second platform, including a reachable opening coin. Placement uses the existing deterministic/seeded platform sequence, without changing its random number stream or the Phase 5 jump envelope. Coin radius, platform offset and density are centralized in GameConfig. Circle/rectangle overlap is checked inside the fixed-step simulation; a coin is marked collected and removed exactly once. Collected and out-of-view coins are cleaned up, and the run counter freezes at Game Over and resets on Restart.

The HUD shows current-run SCORE and COINS. Lifetime balance stays on Home/Profile. Score remains floor(maximum upward progress / 10). Game Over freezes a GameResult containing a cryptographically random UUID v4 runId, score, floor(maximum upward progress) as nonnegative integer height, and coinsCollected.

### Atomic database operation

Migration: `supabase/migrations/20260920141703_submit_game_result_rpc.sql`.

`public.submit_game_result(p_run_id uuid, p_score integer, p_height integer, p_coins_collected integer)` returns a minimal JSON result: run_id, game_score_id, saved_score, saved_height, coins_collected, new_total_coins, played_at and profile_updated_at. No user ID is accepted in the request, and no authentication fields are returned.

The SECURITY DEFINER function uses an empty search_path and schema-qualified relations. It derives ownership from auth.uid(), rejects absent authentication/null or negative inputs, locks the caller's existing profile, checks the owner/run UUID, and inserts the score plus increments lifetime coins in the same transaction. The original profile update trigger supplies updated_at. Missing profiles or integer-balance overflow abort the transaction.

A unique (user_id, run_id) constraint and per-owner row lock prevent duplicate credit even with concurrent retries. Repeating the same UUID and payload returns the saved row and current confirmed balance without a second increment. Reusing that UUID with different values fails. Historical rows may retain a null run_id. No historical data was rewritten.

Execution is granted to authenticated only among API roles; PUBLIC, anon and service_role execution grants are revoked. Direct authenticated score INSERT grants and sequence USAGE were revoked, while all five Phase 3 policies remain unchanged and all three tables retain RLS. Direct updates to profiles.total_coins remain forbidden. No original tables, policies, triggers or functions were recreated.

Implementation references: [Supabase database function security](https://supabase.com/docs/guides/database/functions) and [PostgreSQL row locking](https://www.postgresql.org/docs/17/explicit-locking.html).

### Save lifecycle and navigation

There are no score/coin writes during active play or pause. Game Over creates one immutable result and triggers one initial save. RunSaveController tracks notStarted, saving, saved, failed, and explicit preview states. Overlay rebuilds and repeated callbacks do not submit again. A successful run cannot be retried. Retry Save after a failure uses the same result/UUID and is guarded while in progress.

Saving has a 15-second client timeout. A timed-out HTTP request may already have committed; the UI therefore says it could not confirm the save, and retry is safe because the database is idempotent. SQL details, backend exceptions and tokens are never shown. Restart/Home remain usable while saving or after failure. Restart creates a new game, UUID and save controller. Leaving does not cancel an already-sent request; it may finish and update the same owner's confirmed Home balance. Failed runs are not queued across navigation or app restarts, so retry before leaving if needed.

The repository requires an authenticated user, calls only the RPC, validates the returned result against the frozen request, and maps errors through the existing sanitized DataException layer. Home and Profile read shared authenticated state. Phase 6 initially kept the highest confirmed total because coins only increased. Phase 7 replaces that production synchronization with canonical profile reads after saves and purchases, allowing spending while rejecting stale read responses. No speculative lifetime coins are granted after failed saves.

Auth loss is handled without anonymous persistence. Production entry remains authenticated Home, and its protected game page is removed on sign-out. Late responses cannot update a signed-out or different user's profile. Google OAuth configuration and callbacks are unchanged.

The separate `tool/game_preview.dart` entry point explicitly sets preview mode. It demonstrates coin collection and displays 'Preview — saving disabled'; it does not create an identity, initialize Supabase, call the RPC, or pretend a save succeeded. Production main.dart never enables it.

### Live verification gate

No runtime publishable key was available in the Codex environment or the pre-existing Web artifact. Automated tests use fakes and require no credentials. A configured authenticated browser run must still verify: note lifetime coins, collect at least one coin, reach Game Over, observe Saved, return Home, and confirm the exact coin increase. Then use read-only MCP to compare score, height, coins_collected, and resulting lifetime total. Do not insert artificial results through SQL.

Web/APK compilation and offline preview checks do not establish live persistence. Android physical-device gameplay/persistence remains unverified.

### Phase 6 initial verification snapshot (before the real run above)

- `flutter pub get` and `dart format .`: passed during implementation.
- `flutter test`: **82 tests passed**, including 25 Phase 6 tests and all 57 prior tests. Added coverage includes coin collection/reset/cleanup/reachable generation, immutable result capture, UUIDs, response validation, authenticated repository calls, duplicate callbacks, retry, timeout, disabled preview persistence, disposal, sign-out and server-confirmed balance updates. Tests require no real credentials.
- `flutter analyze`: passed with no issues.
- `flutter build web`: passed, including the Wasm dry run.
- `flutter build apk --debug`: passed; artifact: `build/app/outputs/flutter-apk/app-debug.apk`. Gradle's Java native-access warning was non-fatal. The artifact was confirmed during resumed verification; the successful build was not repeated.
- Offline browser coin verification: **passed**. The development preview visibly collected coins, advanced the HUD to 3 coins, and ended with `GAME OVER`, `Final Score: 46`, `Coins Collected: 3`, and `Preview — saving disabled`. This run made no persistence attempt.
- Real authenticated Web persistence: **PENDING**. No runtime publishable key or local Dart-defines file is available to this session. Earlier runtime configuration used command-line Dart defines. No live save success is claimed.
- Real Android persistence: **PENDING**; no authenticated physical-device run was verified. APK compilation alone does not verify persistence.
- Final read-only Supabase MCP inspection of project `ittdhvlfrrjnsvdfpznl`: both migrations are present; `submit_game_result(uuid, integer, integer, integer)` exists as SECURITY DEFINER with an empty search_path and auth.uid()-derived ownership. API execution is authenticated-only; anon and service_role execution are denied. RLS is enabled on profiles, game_scores and user_skins; all five original owner-only policies remain. Direct score inserts and direct total_coins updates remain blocked, and the unique (user_id, run_id) constraint is present.
- Live score rows: **0**; no real persistence test row exists to summarize. The most recently signed-in Google user's inspected lifetime total_coins is **0**, a baseline rather than evidence of a successful save. No artificial score rows were inserted for verification.
- Original Phase 3 migration unchanged: local and hosted MD5 `2481c9a35392126533828fe88e2f0343`. Phase 6 migration local/hosted MD5 matches `76966a13023ff70d041d3a2bd32060d3`. Resumed verification did not reapply either migration or recreate the function.
- Credential-pattern scan: no matches across 68 source/configuration files. This folder has no Git metadata, so no commit-history secret audit is possible.
- Existing gameplay, persistence code and successful checks were preserved. Resume work completed browser verification, read-only backend inspection, artifact/hash checks and this documentation; no Phase 7 feature was added.

Phase 6 implementation, automated checks, offline coin verification and read-only database verification are complete. Authenticated persistence was subsequently verified by the real run recorded at the start of this section; the initial snapshot above predates that run. Ownership and idempotency prevent cross-user writes and duplicate credit; they are not anti-cheat validation of client-reported gameplay. Failed saves are not retained across leaving/restarting the app; retry before leaving. Physical-device controls and longer play sessions may still inform tuning.

### Scope

Implemented: coins, run counter, frozen result, atomic result/coin RPC, Game Over persistence, duplicate protection, Retry Save and server-confirmed Home/Profile balance updates.

At the end of Phase 6, leaderboard and skins were deferred to Phase 7 below. Moving or breaking platforms, power-ups, enemies, audio, PWA customization, publishing/deployment, release signing and a final ZIP remain out of scope.

## Phase 7 leaderboard and skins

### Database and privacy

Migration: `supabase/migrations/20260921032356_leaderboard_and_skins.sql`. Applied once through Supabase MCP; continuation work did not reapply it or recreate any RPC.

`skin_catalog` contains id, name, description, cost, primary_color, secondary_color, accent_color, sort_order, is_active and created_at. Costs are nonnegative; colors have #RRGGBB constraints. Authenticated clients can read active definitions only. They cannot insert, update or delete catalog entries.

| ID | Name | Authoritative cost |
| --- | --- | ---: |
| default | Golden Hopper | 0 |
| sunset | Sunset Glow | 10 |
| mint | Mint Breeze | 25 |
| cosmic | Cosmic Drift | 50 |
| royal | Royal Blue | 100 |

`get_leaderboard(p_limit integer default 50)` accepts limits 1–100. A window query picks one best run per user by score descending, height descending, then earliest achievement time and score-row ID. A second window assigns deterministic ranks. The response contains only rank, display_name, avatar_url, best_score, best_height, played_at and is_current_user. Blank names become Player, never email. No account UUID, email, token or auth metadata is returned. Private profiles/game_scores SELECT policies remain owner-only.

`unlock_skin(p_skin_id text)` derives ownership from auth.uid(), verifies active catalog membership and the existing profile, locks the profile row, reads the server-side cost and atomically deducts coins plus grants ownership. It uses the same owner row lock as the unchanged Phase 6 result RPC. Already-owned skins return cost_charged=0 without another deduction. Insufficient funds leave both balance and ownership unchanged. Controlled errors become safe Flutter messages.

`select_skin(p_skin_id text)` derives ownership from auth.uid(), checks active catalog membership and user_skins ownership, then updates selected_skin. The original composite owned-skin foreign key is preserved. Phase 7 revokes direct client selected_skin UPDATE grants so selection cannot bypass the RPC's active-skin check.

All three new functions are SECURITY DEFINER with an empty search_path and schema-qualified relations. Among API roles, only authenticated has EXECUTE; PUBLIC, anon and service_role execution grants are revoked. Existing five owner policies, signup/default-skin behavior, protected coin balance, direct-score-insert restriction and run UUID uniqueness are preserved.

### Flutter behavior

- Authenticated Home opens real Leaderboard and Skins screens. Protected pages are removed on sign-out. Existing Google OAuth, restoration, Profile and PLAY routing remain.
- Leaderboard supports loading, empty, populated, sanitized error/retry and explicit refresh without polling. Rows show rank, safe avatar/fallback, display name, best score/height, and a gold YOU highlight. Content stays centered within the existing maximum width.
- Skins shows current lifetime coins, catalog previews/descriptions/costs, owned/selected/locked states and insufficient-funds feedback. Unlock requires a confirmation dialog. Pending actions are disabled to prevent rapid duplicate requests; the server also prevents double charging.
- Successful unlock/selection updates shared authenticated state. No speculative deduction or permanent selection occurs before server confirmation. Home reflects the balance; Profile reflects balance and selected_skin.
- SkinRepository reads catalog/ownership and calls unlock/select RPCs without arbitrary user IDs or client-provided prices. ProfileRepository's legacy selection method now delegates to select_skin. LeaderboardRepository and LeaderboardEntry provide bounded, validated public ranking data. Skin, SkinAppearance, SkinUnlock and SkinSelection parse catalog/results; malformed colors safely fall back.
- HopperArt draws both SkinPreview and PlayerComponent using identical body, secondary and accent colors. PLAY captures one appearance snapshot; it stays stable through the run/restarts. Future entries use the latest selection. Missing/invalid catalog appearance falls back to default without granting ownership. Player size, collisions, bounce physics, camera and procedural generation are unchanged.

### Balance compatibility with Phase 6

Production AuthController now re-reads the authoritative profile after confirmed saves, unlocks and selections. It no longer keeps max(oldBalance, savedBalance) when the skin store is configured. Newer requested reads supersede older reads, and auth/session guards reject responses for departed users. A delayed game-save response cannot restore already-spent coins. A failed profile refresh preserves confirmed state and shows safe retry guidance; reopening Skins retries the read. Result capture, UUID idempotency, Game Over save/retry lifecycle and the Phase 6 SQL function remain intact.

### Verification status

**AUTOMATED VERIFIED**

- flutter pub get and dart format . passed during implementation.
- All **114 tests passed**: the original 82 plus 32 Phase 7 tests. Added coverage includes parsing/privacy, limits, leaderboard loading/empty/error/retry/ranking/highlighting, signed-out guards, controlled errors, skin states, confirmation/cancellation, duplicate taps, insufficient funds, confirmed spending/selection, failed/locked selection, delayed saves, out-of-order reads, sign-out, renderer colors, fallback, Home/Profile integration and protected navigation.
- flutter analyze: **no issues**.
- Responsive widget tests cover 360x800, 430x900, 768x1024 and 1280x720.
- flutter build web: **passed**, 115.4 seconds, including Wasm dry run. Continuation confirmed the completed process and Phase 7 artifact without rebuilding.
- flutter build apk --debug: **passed**, 86.2 seconds; `build/app/outputs/flutter-apk/app-debug.apk`. Gradle emitted a non-fatal Java native-access warning. This is a debug compilation result, not physical-device or release-package verification.
- No implementation code changed during continuation; passing tests/analyzer were preserved without unnecessary reruns.
- Source/configuration scan: **81 files**, zero credential-pattern or assigned-secret matches. Checks covered privileged Supabase keys, database URLs/password patterns, Google client secrets, MCP tokens, access/refresh/provider token assignments, JWTs and private keys. No Git metadata exists, so a commit-history audit is unavailable.

**OFFLINE UI VERIFIED**

The explicitly labeled `tool/phase7_preview.dart` uses synthetic in-memory catalog/profile/rankings only; it creates no Supabase client and disables game persistence. Production main.dart does not import this harness.

At 360x800 and 1280x720, checked Home → Leaderboard → Home → Skins → Home → PLAY, readable rankings/current-user highlight, scrollable skin cards, usable confirmation dialog and buttons, insufficient demo balance, selected preview and normal gameplay. Demo Sunset unlock changed only the in-memory balance 32 → 22; selection rendered the coral player in the game. No real coins or ownership rows were changed. No overflow or clipped actions were observed.

**LIVE SUPABASE VERIFIED — final read-only MCP inspection**

After MCP re-authentication, final read-only inspection reconfirmed five active catalog definitions at the documented costs; all four tables have RLS; all five original owner policies remain unchanged; new RPC signatures, safe leaderboard output, auth.uid()-derived ownership, empty search_path and authenticated-only API execution are correct. Direct score inserts, coin updates, ownership inserts, selected_skin updates and catalog writes are blocked. Function-body inspection confirms authoritative catalog pricing, profile locking, atomic unlock/deduction, no second charge for existing ownership, and ownership/active-catalog checks before selection. This is database-state and function-definition verification, not an authenticated UI purchase test.

Migration integrity: Phase 3 MD5 `2481c9a35392126533828fe88e2f0343`; Phase 6 MD5 `76966a13023ff70d041d3a2bd32060d3`; Phase 7 MD5 `4f4a11cf557108c2372cae9306c2217e`. Final local/hosted hashes match and remain unchanged. The hosted submit_game_result definition hash remains `561d3ac80584b6a151a02d402f083c59`. The unique (user_id, run_id) constraint and composite owned-skin foreign key remain intact. No migrations, RPCs, grants or data were changed during final verification.

Final read-only test-profile snapshot: total_coins **157**, selected_skin **default**, owned skins **default only**; best saved run score **1972**, height **19724**, coins_collected **109**. This newer snapshot supersedes the earlier 32-coin baseline. No purchase or balance mutation was performed by this verification.

**PENDING**

- LIVE LEADERBOARD TEST: PENDING. Runtime Supabase Dart-defines are unavailable in this session.
- LIVE SKIN PURCHASE TEST: PENDING USER APPROVAL. No real coins were spent.
- LIVE SKIN SELECTION/GAME RENDER TEST: PENDING USER APPROVAL. Offline rendering tests do not establish a live purchase/selection.
- Physical Android verification and new live OAuth regression checks were not performed. Existing automated auth/session/logout/PLAY/persistence regression tests pass.

Skin purchases are cosmetic. Client-reported scores remain subject to the existing anti-cheat limitation. Catalog administration and long-session/device tuning are outside this phase.

At the end of Phase 7, PWA customization and production icons were deferred to Phase 8 (below). Moving/breaking platforms, enemies, power-ups, achievements, audio/music, GitHub publishing, Vercel/production deployment configuration, release signing, split-per-ABI final APK packaging and a final ZIP remain unimplemented.

## Phase 8 polish and Web readiness

### Branding, startup and PWA scope

- `web/manifest.json` uses Sky Hopper for both names, relative id/start_url/scope (`./`), standalone display, portrait-primary orientation, an English description, sky-blue theme and pale-sky background. Orientation is an install hint; browser layouts remain responsive.
- Original PNG artwork uses the shared HopperArt renderer: normal and maskable icons at 192x192 and 512x512, an Apple touch icon at 180x180, and a 32x32 favicon. Maskable artwork stays inside the central safe area. Each asset is under 19 KB. Reproduce them with `flutter test tool/generate_web_icons.dart`; this development generator is separate from the application test count.
- Web title, description, theme color, mobile/Apple metadata and icon links are branded. The source viewport allows zoom. Flutter may manage runtime viewport/theme metadata itself.
- HTML shows a lightweight branded loader, accessible loading status, JavaScript-disabled guidance, and a sanitized failure/slow-start message with Reload. The loader disappears on Flutter's first frame. AppStartup provides progress and safe Retry for initialization failures; partial Supabase initialization is cleaned up before retry. The existing two-second Flutter splash remains.
- Missing runtime configuration leaves production at Login with safe user-facing guidance. Production PLAY still requires authenticated Home. No offline preview is imported by production main.dart.

The inspected Flutter 3.47.5 SDK emits a **retirement service worker** that unregisters itself; it does not install a fetch handler or maintain an offline asset cache. The custom bootstrap uses current `_flutter.loader.load` initialization and the generated worker-version token so the SDK's old-worker cleanup behavior remains available. No legacy caching implementation, extra worker or deprecated PWA strategy was introduced. See Flutter's [Web FAQ](https://docs.flutter.dev/platform-integration/web/faq) and [initialization documentation](https://docs.flutter.dev/platform-integration/web/initialization).

**Manifest/assets verified; actual PWA installation is unverified. Offline shell availability is not guaranteed or verified.** A populated browser HTTP cache is not proof of offline support. Supabase sign-in, authoritative balances, result saving, leaderboard and skin operations require connectivity. Deployment/HTTPS and browser-specific installation checks remain later work; no install-success or offline-ready claim is shown to players.

### UI, gameplay and accessibility

Home and Profile retain their established layout, account state and navigation. Leaderboard/Skins retain their behavior with labeled loading indicators, announced error states and readable centered unlock labels. Existing loading, empty, retry and refresh flows remain covered.

Gameplay adds a cached sky gradient, a second slower cloud layer, subtle platform shadows and a cosmetic coin shimmer. Reduced-motion preferences disable the shimmer. The sky renders in `camera.backdrop`, behind the world: browser verification caught and corrected an opaque overlay regression, with a test assertion guarding this layer. Player physics, automatic bounce, collision dimensions, wrapping, camera movement, procedural reachability, scoring and persistence rules are unchanged.

HUD counters flex at large text sizes, Game Over save feedback is announced, and icon/text action targets have a minimum 48-pixel size. Keyboard/touch controls and explicit pause/resume behavior remain. Backgrounding clears held input and pauses play. Paints/gradient are reused; effects use simple canvas shapes, with no additional asset package, polling or database work. No measured frame-rate improvement is claimed.

### Verification

**AUTOMATED VERIFIED**

- `flutter pub get`: passed; no dependency additions.
- `dart format .`: passed, 60 files formatted/checked.
- `flutter analyze`: **no issues**, including after the backdrop correction.
- `flutter test`: **126 passed** (114 existing plus 12 Phase 8 tests), including the final backdrop assertion.
- `flutter build web`: **passed**, final production rebuild 155.2 seconds, including Wasm dry run.
- `flutter build apk --debug`: **passed**, final rebuild 73.5 seconds; artifact `build/app/outputs/flutter-apk/app-debug.apk`. The non-fatal Gradle Java native-access warning remains. This is a debug compilation result, not a release package or physical-device verification.
- New coverage includes manifest/PNG validation, Web metadata/fallbacks, initialization progress/failure/retry/disposal, all major screens at five sizes, large HUD text/touch targets, reduced motion and background input/pause behavior. The existing camera regression also passes.
- Splash, Login, Home, Profile, Leaderboard, Skins, gameplay and Game Over pass layout tests at **360x800, 390x844, 768x1024, 1280x720 and 1440x900**. An additional narrow HUD check uses 320-pixel width and 2x text scaling.
- Authentication, Phase 6 result freezing/retry/idempotency/sign-out, and Phase 7 leaderboard/skins/balance regressions remain green. Tests require no real Supabase credentials. Live OAuth, authenticated saves and purchases were not repeated; no runtime publishable key was available and no real coins were spent.

To inspect the actual production Web output locally:

```powershell
flutter build web
node tool/serve_web.mjs build/web 3088
```

Open `http://127.0.0.1:3088`. The helper serves static files on loopback only with explicit MIME types and no-cache headers; it is not deployment configuration. Supply your existing SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY Dart defines at build time for live sign-in. Never put privileged keys or tokens in source.

**LOCAL PRODUCTION WEB VERIFIED**

Production `build/web` was served over HTTP and reached Login after the branded loader without a blank screen. Manifest, favicon and all icon URLs returned HTTP 200 with correct types. Metadata and narrow Login rendering were checked; no console errors/warnings were observed. The corrected production Web and Android debug artifacts remain present. Continuation found no newer source changes and preserved the successful tests/builds without rerunning them.

**OFFLINE UI/DEMO VERIFIED**

Protected-page browser checks use a separate release-mode offline fixture (`flutter build web --output=build/phase8-preview -t tool/phase7_preview.dart`), served on another loopback port. This synthetic demo creates no Supabase client and disables persistence; its gameplay verification does not claim live authenticated production testing.

After the backdrop fix, final desktop navigation passed Home → Leaderboard → Home → Skins → Home → PLAY → pause/resume. Player, platforms and coins render above the sky; HUD and controls remain readable with no observed overflow or clipping. A synthetic Sunset unlock/selection changed only the in-memory demo balance (32 → 22), and the coral selected player rendered correctly during gameplay. No real coins were spent. Automatic bounce, coin counter, keyboard input and Escape pause were exercised. The demo console contained no errors/warnings. Earlier phone-width Home/Leaderboard/Skins checks remain valid. Game Over/restart remain covered by the passing automated suite and earlier gameplay verification; Game Over was not forced in this final browser session.

**LIVE SUPABASE VERIFIED — prior phases only**

The read-only Phase 7 database verification above is historical evidence, not a new Phase 8 authenticated test. No Supabase requests or database changes were made during this continuation. Google OAuth architecture, protected routing, Phase 6 persistence/submit_game_result/UUID idempotency, leaderboard backend and skin unlock/select RPCs remain unchanged.

**NOT VERIFIED / PENDING**

**PWA INSTALLABILITY: NOT FULLY VERIFIED.** No actual installation or offline shell support is claimed. New live OAuth, authenticated result saving, leaderboard and skin operations were not exercised in Phase 8. Physical Android, deployment and sustained device performance remain unverified.

### Integrity and remaining work

All three migration MD5 hashes remain exactly as recorded in Phase 7. Core game configuration, simulation, platform generation and coin-system file hashes remain unchanged. **Supabase/database changes: NONE.** No migrations, RPCs, grants, policies or database rows were changed in Phase 8.

Final source/configuration credential-pattern scan covered 93 files (including hidden configuration files) with zero matches. No Git metadata exists, so commit-history inspection is unavailable. No secrets were printed or added.

Phase 9 remains: GitHub setup/publishing, production hosting/deployment and HTTPS, final domain/OAuth configuration, live deployment/authentication checks, browser installation verification, any explicitly scoped offline caching strategy, release signing/final APK packaging and submission ZIP. Physical Android and sustained performance testing remain unverified. None of those tasks was started here.

## Phase 9 progress

Repository inspection confirmed the corrected Phase 8 artifacts and no newer application-source changes. The existing 126 passing tests and clean analyzer baseline are preserved without rerunning. All three migration hashes still match the values above; no database or product-code changes were made.

Git was initialized on `main`. Ignore rules now also exclude Vercel local state, local runtime configuration, private signing material, APKs and ZIPs. A pre-commit source/configuration scan checked 104 files with zero credential-pattern matches. GitHub CLI authentication and repository author identity are configured. The reviewed initial index contains 108 files; all 97 text files passed the credential-pattern scan, and no prohibited generated/private files are tracked.

Public repository: [mdislam1234/sky-hopper](https://github.com/mdislam1234/sky-hopper), default branch `main`. Initial commit `c63108bf850f50ba664f538092ffcfcf7b842ab2` was pushed and verified against GitHub; all 108 remote file paths matched the local index, with no prohibited generated/private files.

The local `dart_defines.local.json` was validated and remains ignored/untracked. The configured production Web build passed in 153.8 seconds, including Wasm dry run, using `flutter build web --dart-define-from-file=dart_defines.local.json`. The output is `build/web`; no privileged credentials are used.

Live production URL: [Sky Hopper](https://sky-hopper-blue.vercel.app). Vercel CLI 59.25.0 deployed the compiled static `build/web` directory to `azi-tech/sky-hopper`, with no remote Flutter installation or route rewrites. Deployment `dpl_4NPoBKVkEhYG3Pj4w1KCPk9q9PnD` reached READY and received the production alias above. The upload dry run included 40 static files and excluded Vercel local state and its generated `.env.local` file. Never copy that private local state into source or the submission ZIP.

Anonymous HTTPS checks returned 200 for root, manifest, favicon and all five icon files. The live app reaches branded Login with the Google action enabled and no blank screen. This does not yet establish successful production authentication. Installation and offline caching are not verified.

The user confirmed production authentication URLs were configured: Supabase Site URL/redirect `https://sky-hopper-blue.vercel.app/`, Google Web OAuth JavaScript origin `https://sky-hopper-blue.vercel.app`, and the preserved Supabase callback `https://ittdhvlfrrjnsvdfpznl.supabase.co/auth/v1/callback`. Local and Android redirects were to be retained. These dashboard edits were performed by the user; their complete settings lists were not independently re-inspected by the agent.

### Phase 9 submission

**Live verification:** the user's production tab already contained an authenticated Game Over showing Saved. Read-only MCP verified the matching latest run: score 1139, height 11393, coins 65, played_at `2026-09-22 06:11:18.818663+00`, a present run UUID and exactly one row for that user/run. Lifetime coins are 222, exactly the prior verified 157 plus 65. The profile has a Google identity, default selected and one owned skin. The UUID and sensitive auth fields are not published here.

Home and Profile both showed 222 coins. A browser refresh restored authenticated Home on the Vercel origin with no localhost redirect or loop. The agent observed the successful authenticated outcome and refresh; the original Google consent/redirect sequence was completed before the verification resumed and was not directly watched end-to-end.

Live Leaderboard loaded and refreshed, highlighted YOU, and showed server-confirmed best score 1972 / height 19724 without exposing private auth fields. Live Skins loaded the five correct catalog costs and owned/selected default state. No paid skin was purchased or real coins spent. A separate live visual run confirmed player/platforms/coins visible, bouncing, increasing HUD counters, keyboard input and Escape pause; it was exited to Home without saving an additional result. Camera regression coverage remains green; no physics, score, camera, auth, persistence or backend logic changed during Phase 9.

**PWA:** HTTPS manifest/icon requests passed and the document links the branded manifest/favicon. Standalone configuration and normal/maskable/Apple icons remain present. PWA INSTALLABILITY: NOT FULLY VERIFIED. Actual installation was not performed. The Flutter retirement worker does not provide offline asset caching; no full offline-support claim is made.

**Automated baseline:** 126 tests passed and flutter analyze reported no issues after the last application-code change in Phase 8. Phase 9 changed documentation/ignore rules only, so the baseline was preserved without rerunning tests. The production-configured Web build passed. All three migrations retain the exact hashes above. No schema, RPC, policy, grant or manual data changes were made; the legitimate user gameplay save is the only verified production data addition.

**Reproduce configured builds:** install the documented Flutter SDK, run `flutter pub get`, create an ignored local `dart_defines.local.json` with SUPABASE_URL and the public SUPABASE_PUBLISHABLE_KEY, then run:

```powershell
flutter build web --dart-define-from-file=dart_defines.local.json
flutter build apk --release --split-per-abi --dart-define-from-file=dart_defines.local.json
```

Client artifacts contain the publishable client key by design, never privileged credentials. The local defines file must stay out of Git and the submission ZIP. Deployment uploads only compiled `build/web` using Vercel CLI, linked to `azi-tech/sky-hopper`; do not deploy the repository root or upload generated `.env.local`/`.vercel` state. No Git-triggered Flutter build has been configured on Vercel.

**Signing/device limitations:** the existing Gradle release build uses the debug signing configuration. Assignment APKs are for testing/submission, not Play Store production distribution. No new signing key was created. PHYSICAL ANDROID TEST: NOT VERIFIED. Android Google deep-link return, device gameplay and persistence remain unverified on physical hardware.

**Final APKs:** release split build passed in 317.5 seconds. Each APK passed Android SDK signature verification and uses the Android Debug certificate:

| File in `release_apks/` | ABI | Bytes |
| --- | --- | ---: |
| app-armeabi-v7a-release.apk | armeabi-v7a | 14953417 |
| app-arm64-v8a-release.apk | arm64-v8a | 17544703 |
| app-x86_64-release.apk | x86_64 | 19044858 |

`release_apks/README.txt` explains architecture selection and signing. These binary deliverables are included in the local submission ZIP, not committed to GitHub. No universal APK was generated for the final package.

**Submission ZIP:** `Sky_Hopper_Final_Submission.zip` at the project root. It packages the tracked project source/documentation/configuration, all three applied migrations, Android Gradle wrapper files and `release_apks/`. It excludes `.git`, build output, `.dart_tool`, caches, local properties, environment/Dart-defines files, Vercel state and private signing material. Run `flutter pub get` after extracting; configure your own ignored runtime defines before rebuilding. Build artifacts already contain the public client configuration.

**Security review:** all 108 tracked files were inspected for inappropriate generated/private content; 97 text files passed the final credential-pattern scan with zero matches. Package members are checked against an explicit allowlist, read back and compared by SHA-256 with their source files. No privileged keys, tokens, local configuration or signing credentials are included.

**Assignment checklist:** Flutter/Flame 2D game, AI-assisted phased development, Supabase MCP, Google-backed authentication, user-specific data, public GitHub source, configured production Web build, HTTPS Vercel deployment and ABI-specific Android APKs are delivered. Branded PWA metadata/assets are verified; actual installation/offline caching and physical Android testing are explicitly unverified. The user's authenticated production run/save and the agent's session, screen and read-only database checks are distinguished above.

## Sky Hopper 2.0 — Phase 10

Phase 10 adds a centralized environment and hazard simulation while preserving the existing automatic-bounce controls, physics, camera, score, authentication, persistence, leaderboard and skin systems. Pure simulation state drives the Flame renderer, and a bounded difficulty director supplies tuneable generation probabilities and hazard intensity.

### Environments and transitions

The five altitude environments are configured in one place: Sunny from score 0, Sunset from 400, Storm from 800, Night from 1300 and Space/Upper Atmosphere from 1900. Lightweight transition bands blend sky colors, cloud tint, particle intensity and platform palettes instead of switching the scene abruptly. A short `Entering …` overlay announces each new biome.

- **Sunny:** light blue sky, soft clouds and bright green platforms.
- **Sunset:** orange, pink and purple sky tones with warmer clouds and platforms.
- **Storm:** dark blue-gray sky, denser clouds, rain and clear hazard-warning visuals.
- **Night:** deep blue sky, stars, moon and cool platform accents.
- **Space:** deep navy/black sky, stars, a subtle nebula gradient, distant celestial shapes and futuristic platform accents.

### Platforms, hazards and difficulty

Platforms have explicit normal, moving, crumbling and spike types. Moving platforms follow predictable horizontal paths within safe bounds. Crumbling platforms show cracks before landing, accept the first landing, then collapse after a centralized delay without reactivating. Spike platforms expose a smaller lethal region beside a safe landing section, and spike contact records a clear Game Over cause.

Wind zones visibly push the player with bounded force. Storm clouds move predictably and apply knockback with collision cooldowns. Lightning cycles through warning, strike and clear phases so its lethal area is telegraphed before activation. Pausing freezes the player, moving platforms, crumble timers, wind, clouds and lightning, and prevents hazard deaths. Restart resets the environment, difficulty, platform and hazard state, wind, lightning, crumble state, score, coins, camera and Game Over cause.

Difficulty rises through centralized, capped profiles rather than changing the established gravity, jump velocity, steering, wrapping, camera or score formula. Generation preserves reachable horizontal and vertical gaps, inserts regular safe recovery platforms, delays advanced hazards until later score ranges and prevents unfair airborne-hazard combinations. Riskier eligible platforms can receive sparse bonus coins while the existing alternating coin economy remains intact. Off-screen platforms, coins, wind zones, clouds, lightning objects and visual particles are cleaned up to keep component counts bounded.

### Verification

- `dart format .`: passed; 66 files checked and no changes required.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: **164 passed**. The original 126 tests remain green, with 38 Phase 10 tests covering environments, thresholds and transitions; all platform and hazard types; warning/strike timing; bounded difficulty; safe-route cadence; deterministic generation; pause/restart; cleanup; Game Over integration; and 360x800, 390x844 and 1280x720 layouts. The continuation baseline increased from 162 because two final GameScreen integration tests were added for spike Game Over and full restart reset.
- `flutter build web`: passed; the final production Web artifact was regenerated after all Phase 10 application-source changes, including the Wasm dry run.
- Android debug compilation and packaging passed, producing `build/app/outputs/flutter-apk/app-debug.apk`. Windows Application Control blocked the Flutter tool when it attempted to start its compiler, so the signed Flutter frontend compiler was invoked directly and Gradle completed `assembleDebug`; the APK's embedded kernel SHA-256 exactly matches that fresh compiler output.
- A development-only browser preview visibly verified all five environments, transition palettes, platform warning styles, rain, stars, celestial layers, wind, a moving storm cloud, the lightning warning/strike/clear cycle, automatic bouncing, coin progression, keyboard steering and pause. The actual GameScreen also verified gameplay, HUD progress, steering and pause. The preview has no authentication or persistence bypass in production.
- **Manual Game Over visual check: not performed in the final browser preview.** Automated GameScreen Game Over, cause text, persistence-disabled preview behavior and Restart coverage passed.

No Phase 6 persistence or Phase 7 leaderboard/skin behavior changed. All three Supabase migration files retain their recorded hashes, and **Supabase/database changes: NONE**.

At the Phase 10 checkpoint, sound, music, haptics and game-feel feedback remained for Phase 11; the later roadmap items remain listed below.

## Sky Hopper 2.0 — Phase 11

Phase 11 adds a centralized game-feel layer while preserving the Phase 10 physics, upward-progress score, coin economy, authenticated result persistence, leaderboard, skins, camera and hazard rules. Gameplay systems emit semantic feedback events; `GameFeedbackController` maps them to audio, haptics and short visual responses. Flame components do not create audio players or read preferences themselves.

### Sound, music and local settings

`flame_audio` provides reusable effect pools and two long-lived music players. Effects cover bounce, coin collection, perfect landings, near misses, crumbling platforms, wind, storm-cloud contact, lightning warning/strike, hazard impact, new personal best, Game Over and quiet UI taps. Priority cues stop or suppress lower-value effects so lightning, new-best and Game Over feedback do not become a noisy stack. Audio is preloaded once per game session; event playback does not load files or read preferences every frame.

Five short loops share one generated musical language for Sunny, Sunset, Storm, Night and Space. Biome changes crossfade between the two music players over 330 ms. Pause and lifecycle suspension pause music and suppress gameplay feedback; resume restores it, Game Over fades gameplay music before its one-shot cue, Restart selects the current biome again, and Home/disposal stops the players. Web startup tolerates an autoplay denial and retries audio after the first movement or pointer gesture without blocking gameplay.

Home now exposes a responsive Settings page with independent Music, Sound Effects and Haptics switches. `shared_preferences` stores these device-only preferences; nothing is written to Supabase. Haptics use Flutter's platform-safe feedback API and become a no-op when disabled or unsupported. The settings controller is injected, so tests use memory stores and fake audio/haptic services without real credentials, speakers or vibration hardware.

All 18 WAV files under `assets/audio/` are original, deterministic procedural assets generated by `tool/generate_phase11_audio.ps1` for this project. They use no copied recordings, samples or commercial-game material and require no third-party attribution. Their combined size is 1,091,032 bytes (about 1.04 MiB). The generator remains in the repository so the source and authorship of every sound are reviewable.

### Landing, danger and best-chase feedback

A perfect landing measures the player's horizontal center against the center of the platform's safe landing region, using a centralized 18% tolerance. Spike platforms therefore use the safe section rather than the full rectangle. Consecutive perfect landings show `PERFECT`, then `PERFECT ×2` through a visual cap of ×10. A normal landing, hazard contact or death resets the streak; ordinary airtime does not. Perfect landings add a short burst, sound and optional haptic without pausing play or changing saved score.

Spikes, moving storm clouds and active lightning can each emit one near miss per encounter when the player passes through a bounded margin without colliding. Collision and distance reject the event, pause freezes detection, and Restart clears encounter tracking. `CLOSE!`, a quiet cue and a small visual streak acknowledge the pass without granting score or coins.

The authenticated GameScreen loads the current leaderboard best once before a run; the development preview injects a fake best and never contacts Supabase. The compact HUD shows score, coins and best. One-shot notices fire at 100, 50 and 10 points remaining. Crossing the previous best emits `NEW BEST!` exactly once with a stronger cue, haptic, particles and restrained pulse. Game Over labels the run as a new personal best, while save failures continue to distinguish the local run result from the last server-confirmed best. The immutable `GameResult`, UUID idempotency, `submit_game_result` RPC and Retry Save flow are unchanged.

Coin sparkle and counter pulse, perfect/near-miss particles, lightning sparks and a bounded new-best celebration improve impact without obscuring the player. Screen shake is limited to strong hazard contact and Game Over; normal bounce never shakes. Reduced-motion mode disables shake, removes decorative near-miss motion and reduces particle counts while retaining readable text and independently controlled audio.

### Verification

- Phase 11 adds **37 tests**: 32 unit tests and five widget tests. Coverage includes defaults and all toggles, local persistence and controller recreation, disabled-output behavior, semantic audio/haptic routing, browser-gesture retry, pause/lifecycle/Home/Game Over/Restart transitions, perfect safe-region geometry and streak reset/cap, unique spike/cloud/lightning near misses, personal-best loading/thresholds/one-shot/new-run behavior, HUD and Game Over save wording, and reduced motion. The final test inventory is **201 tests** (the preserved 164-test Phase 10 baseline plus 37 new tests).
- `dart format .`: passed using the signed Dart runtime.
- Static analysis: passed with **No issues found** using the signed Dart analyzer.
- Windows Application Control blocked the standard Flutter launcher and its unsigned `flutter_tester` child, so the literal `flutter pub get`, `flutter analyze` and `flutter test` wrappers could not complete on this host. Dependency resolution succeeded through Flutter's bundled signed Dart pub entry point. The signed Flutter frontend/tester fallback ran all 32 new unit tests and each of the five new widget cases; all passed. This environment limitation means a single normal `flutter test` invocation remains to be repeated on an unrestricted host before release.
- The Web frontend compiler, Wasm dry run and release asset bundle completed with all 18 audio files. Windows Application Control then blocked only Flutter's `impellerc.exe` shader subprocess. The exact previously verified Phase 10 shader was reused; the development Web build loaded successfully in a browser with no console warning/error. A normal unrestricted-host `flutter build web` remains the final release confirmation.
- Android compiled a fresh Phase 11 kernel and asset bundle. The same blocked shader subprocess required the established Phase 10 fallback: the exact verified shader was retained and Gradle `assembleDebug` completed successfully. `build/app/outputs/flutter-apk/app-debug.apk` contains all 18 audio files, and its embedded kernel SHA-256 exactly matches the fresh Phase 11 kernel.
- The development-only browser preview exercised all biome stages plus `PERFECT ×3`, near miss, `NEW BEST!` and Game Over. Music and SFX toggles changed controller state, and Pause, Resume and Restart completed successfully. Storm and Space transitions were dispatched after user gestures, and the browser console remained clean. Audio requests, asset loading, settings routing and autoplay recovery were verified, but audible speaker output could not be independently heard by this agent; bounce, coin, lightning and the audible result of the other cues remain a human listening check. **PHYSICAL ANDROID AUDIO/HAPTICS TEST: NOT VERIFIED.**
- No obvious preview frame drop or unbounded feedback growth was observed. Audio uses pools/long-lived players, particles have short lifetimes, simultaneous cues are capped, and preferences are cached in the controller.

`DESIGN.md` records the durable colors, typography, shapes, components, motion and reduced-motion rules used by the Settings and gameplay feedback UI. No Supabase migration, schema, policy, RPC, grant or database row changed. The three migration MD5 hashes remain `2481c9a35392126533828fe88e2f0343`, `76966a13023ff70d041d3a2bd32060d3` and `4f4a11cf557108c2372cae9306c2217e`.

At the Phase 11 checkpoint, daily challenges, missions, achievements, and daily competition were still pending; the Phase 12 section below records their implementation. Seasonal events, AdMob, UMP, `app-ads.txt`, and the Play Store Sky Hopper 2.0 release remain outside the current scope.

## Sky Hopper 2.0 — Phase 12

Phase 12 adds the retention, competition, and progression layer while preserving normal endless `PLAY`, the existing primary score, authentication, coin persistence, skins, environments, hazards, audio, and game-feel systems.

### Daily challenge and competition

The Daily Challenge uses one deterministic seed derived from the authoritative UTC calendar date. A date's seed drives the existing seeded game generator, so players receive the same platform sequence, biome thresholds, hazard layout, and major coin route. Normal endless mode still creates its seed through the original random path and is unchanged.

Each authenticated player receives **three ranked Daily Challenge attempts per UTC day**. The server owns the date and attempt count. A successful ranked run consumes one attempt and may appear on the Daily leaderboard. Once all three attempts are used, the same deterministic course remains available as `PRACTICE DAILY`; practice runs explicitly disable persistence and never consume an attempt, award gameplay coins, update progression, or enter any leaderboard.

The leaderboard now has three scopes:

- **Daily:** each player's best ranked result for the current UTC challenge only.
- **Weekly:** each player's best saved score from the current UTC week, starting Monday 00:00 UTC and ending the following Monday.
- **All time:** each player's best saved score across the existing score history.

All scopes use the existing score as the primary metric, followed by height, earliest `played_at`, and row ID for stable tie-breaking. Responses expose only rank, display name, safe HTTPS avatar URL, score, height, played time, and current-user highlighting.

### Missions, achievements, rewards, and streaks

Three missions are materialized deterministically for each UTC date: a modest coin target, a reachable score target, and one style goal selected from perfect landings, perfect streak, near misses, moving-platform landings, or reaching Storm. Progress is batched into the authenticated Game Over submission rather than written every frame. Mission state survives restarts in Supabase and rolls over at 00:00 UTC.

The first achievement catalog contains eleven goals: First Flight, Cloud Climber, Storm Chaser, Night Rider, To the Stars, Perfectionist, Daredevil, Coin Collector, High Flyer, Daily Player, and Consistent. Progress uses saved-run metrics and server history. The Stormbound and Starlight cosmetics are granted automatically for Storm Chaser and To the Stars; they remain cosmetic and cannot be purchased to bypass their achievements.

Mission and achievement rewards are modest lifetime-coin grants. Claiming calls one authenticated RPC with only a reward type and catalog ID. The server resolves the date, completion state, configured reward, prior claim, and resulting balance while holding the profile row lock. Claims are idempotent and the client cannot supply a coin amount. The UI shows progress, `COMPLETE`, `CLAIM`, and `CLAIMED`, then refreshes the confirmed profile balance after a successful claim.

Any successfully persisted normal or Daily run qualifies the current UTC date for the lightweight return streak. Additional runs on the same date do not increment it; the next consecutive UTC date adds one, and a missed date restarts the current streak at one. Best streak is retained. Opening the app alone never qualifies, and no owned item can be lost.

### Database and security architecture

The new timestamped migration is `supabase/migrations/20260927235931_phase12_progression.sql`. Its filename matches the hosted migration version assigned by Supabase MCP. It adds:

- `achievement_catalog`
- `run_progression`
- `daily_challenge_results`
- `daily_missions`
- `user_achievements`
- `player_streaks`
- two achievement-linked `skin_catalog` rows and `unlock_achievement_id`
- authenticated `submit_progression_result`, `submit_daily_challenge_result`, `claim_progression_reward`, `get_progression_snapshot`, and `get_competition_leaderboard` RPCs

Every user-specific table has RLS and an owner-only select policy. Direct public, anonymous, and authenticated table mutations are revoked. Security-definer helpers are private and have no client execute grant. Public mutation RPCs derive ownership only from `auth.uid()`, use the server's UTC clock, validate bounded run metrics, serialize each user's balance/attempt mutations with the profile row lock, and retain the Phase 6 UUID retry model. Daily results additionally constrain one user/date/attempt and one user/run. Existing score and coin columns cannot be mutated directly by the client.

No previously applied migration was edited. Their MD5 hashes remain:

- Phase 3: `2481c9a35392126533828fe88e2f0343`
- Phase 6: `76966a13023ff70d041d3a2bd32060d3`
- Phase 7: `4f4a11cf557108c2372cae9306c2217e`

### Phase 12 verification

**AUTOMATED VERIFIED**

- `dart format .`: passed; 84 Dart files checked with no outstanding formatting change.
- `flutter analyze`: passed with **No issues found**.
- `flutter test --no-pub`: **229 tests passed**: the preserved 201-test Phase 11 baseline plus 28 focused Phase 12 tests.
- The new tests cover UTC seed rollover and reproducible generation, unchanged normal seeding, ranked/practice rules, UUID/progression payloads, deterministic missions, completion and claims, achievement thresholds, same/consecutive/missed-day streaks, RLS/RPC/date/leaderboard migration contracts, safe public data, Daily/Missions/Achievements UI, leaderboard scopes, current-user highlighting, and responsive layout.
- The existing authentication, persistence, skins, gameplay, audio/game-feel, camera, and responsive regressions remain green. The small Game Over layout correction keeps Restart and Home reachable before secondary failed-save details at 800×600.
- Configured `flutter build web --dart-define-from-file=dart_defines.local.json`: passed in 166.3 seconds, including the Wasm dry run; output `build/web`.
- Configured `flutter build apk --debug --dart-define-from-file=dart_defines.local.json`: passed without the shader fallback; output `build/app/outputs/flutter-apk/app-debug.apk`. Android SDK Platform 35 revision 2 was installed by Gradle. The existing non-fatal Java native-access warning remains.
- The ignored local Dart-defines file was used only at build time and was not printed or added to Git.

**DEVELOPMENT-ONLY DEMO VERIFIED**

`tool/phase12_preview.dart` creates no Supabase client and keeps all state in memory. Its browser build passed. Manual checks covered September 27 and 28 UTC seeds, one ranked attempt remaining, exhausted attempts with unsaved/unranked practice, Daily/Weekly/All Time tabs, current-user highlighting, mission progress and an in-memory claim, achievement progress, desktop layout, 360×800 layout, and a clean browser console. This fixture is not production authentication or live persistence evidence.

**LIVE SUPABASE VERIFIED**

Supabase MCP applied hosted migration `20260927235931_phase12_progression`. Read-only catalog verification confirmed all six new tables and RLS, the six expected authenticated-select policies, owner checks on every user table, eleven active achievements, both achievement cosmetics, and the expected daily constraints/indexes. There are no anonymous or authenticated direct write grants on the new tables. The five public RPCs are security-definer functions executable by `authenticated` only; anonymous and service-role execution is revoked. The three private helper functions have no client execute permission.

A controlled authenticated live test ran entirely inside explicit transactions followed by `ROLLBACK`. The snapshot returned the server UTC challenge date and seed, a three-attempt limit, three missions, and eleven achievements. RLS exposed only the selected test user's temporary mission/achievement/streak rows and zero other-user rows. Daily, weekly, and all-time leaderboard calls succeeded. A zero-coin Daily submission retried with the same generated run UUID returned the same attempt and score row, created only one temporary result, and left lifetime coins unchanged. Post-rollback verification found zero rows in every Phase 12 user table and preserved the existing 16 score rows and 3 profiles. No real reward was claimed, no existing attempt was consumed, and no existing coin balance or gameplay row changed.

### Development inspection

Build the synthetic progression inspector without credentials:

```powershell
flutter build web --no-pub --output=build/phase12-preview -t tool/phase12_preview.dart
node tool/serve_web.mjs build/phase12-preview 3092
```

Production still starts through `lib/main.dart`, initializes the configured Supabase client, requires authentication, and uses server-confirmed progression. The preview entry point is never imported by production code. The following Phase 13A section records the new monetization and release-preparation layer; production credentials, Play submission, and merging remain outside this phase.

## Sky Hopper 2.0 — Phase 13A

Phase 13A prepares restrained Android monetization, privacy controls, and Android release configuration without changing physics, scoring, progression, leaderboards, skins, or Daily Challenge rules. Flutter Web stays functional and ad-free.

### Android ads and consent

`google_mobile_ads` 9.1.0 is isolated behind `AdService`. Android creates `GoogleMobileAdsService`; Web and non-Android platforms resolve a no-op implementation through conditional imports; tests inject deterministic fakes. Startup asks Google's User Messaging Platform to update consent information, loads and displays Google's form when required, and starts ad loading only when `canRequestAds()` allows it. Cached permission may safely allow initialization while a refresh is in flight. SDK and ad initialization are guarded against duplicate calls.

Development and debug builds use only Google's official Android sample identifiers. Release Dart code has no test-ID fallback: supply `ADMOB_REWARDED_AD_UNIT_ID` and `ADMOB_INTERSTITIAL_AD_UNIT_ID` as compile-time Dart defines. A release build also requires a production `ADMOB_APP_ID` in the ignored `android/release.properties`; Gradle rejects the Google sample app ID. No real AdMob ID or publisher ID is committed.

At a successfully saved **normal-mode** Game Over, a player who collected coins may voluntarily watch one rewarded ad. The displayed estimate and server rule are `ceil(run coins / 2)`, bounded to 1–25 coins. Dismissal before Google's earned callback grants nothing. After the callback, Flutter sends only the immutable saved run UUID to `claim_rewarded_run_bonus`; the database derives `auth.uid()`, verifies ownership and normal mode, reads `coins_collected`, calculates the bonus, locks the profile, and records one idempotent claim per run. A failed confirmation can be retried without watching a second ad. The mobile earned callback is not cryptographic proof of viewing; AdMob Server-Side Verification is not implemented, so this design does not claim full anti-cheat security.

The additive migration is `supabase/migrations/20260928035631_phase13a_rewarded_bonus.sql`; its filename matches the hosted Supabase migration version. It adds `rewarded_ad_claims`, owner-only SELECT RLS, and the authenticated-only claim RPC. Direct anonymous/authenticated inserts, updates, and deletes remain revoked.

Interstitials are considered only after Game Over when Restart or Home is chosen. The centralized session policy never shows one on the first run, schedules around every third successfully saved normal run, enforces a two-minute full-screen cooldown, skips Daily Challenge and practice, suppresses the pending interstitial after a rewarded ad, and never blocks navigation after a load/show failure. There are no banners, app-open ads, Login ads, gameplay ads, pause ads, or Daily Challenge ads. Audio is already paused at Game Over and resumes through the existing Restart path after dismissal.

Settings shows Google's **Privacy Options** only when UMP reports that an entry point is required. There is no homemade consent dialog, fake disable-ads switch, or promise that every advertisement can be disabled. The Web privacy draft is at `/privacy/` (`web/privacy/index.html`) and preserves the Flutter app at `/`. It covers Google sign-in, Supabase profile/gameplay/progression records, advertising data, consent choices, retention, deletion requests, and age considerations without claiming legal compliance.

`docs/app-ads.txt.example` is documentation only and deliberately contains a placeholder. Do not copy it to `web/app-ads.txt` until AdMob supplies the real publisher ID. The final file must be at the root of the developer website, and that same website must be listed in Google Play.

### Android release setup

The Android application ID remains `com.skyhopper.game`. `compileSdk` and `targetSdk` are 36; the current Flutter toolchain resolves `flutter.minSdkVersion` to API 24, which is compatible with this Google Mobile Ads configuration. Debug builds use the official sample AdMob app ID. Release tasks fail clearly unless both private files are configured:

1. Copy `android/key.properties.example` to ignored `android/key.properties`, point it at the private Play upload keystore, and fill the passwords locally.
2. Copy `android/release.properties.example` to ignored `android/release.properties` and supply the real AdMob Android app ID.
3. Supply production public Supabase values plus production rewarded/interstitial unit IDs through an ignored Dart-defines file.
4. Run `flutter build appbundle --release --dart-define-from-file=<private-file>`.

No keystore, password, production ad ID, service-role key, or private key belongs in Git. Missing release credentials never fall back to debug signing. An upload-ready AAB remains pending until the developer creates the Play upload key and supplies real public runtime/AdMob configuration.

The Play Console and physical-device workflow is tracked in `PLAY_STORE_CHECKLIST.md`. On an Android phone, use only Google's test ads to verify initial consent, the conditional Privacy Options row, rewarded earn/dismiss behavior, one bonus per saved run, every-third-normal-run interstitial policy, background/resume, audio restoration, normal saving, and ad-free Daily Challenge. Never click live ads during testing.

### Phase 13A verification

- `dart format .`: passed with 93 Dart files checked and no outstanding change.
- `flutter analyze`: passed with **No issues found**.
- `flutter test`: **244 tests passed**, preserving the 229-test Phase 12 baseline and adding 15 focused monetization/privacy/release tests. A final focused rerun also passed after enforcing unconditional Google test units in debug builds.
- Configured `flutter build web --dart-define-from-file=dart_defines.local.json`: passed, including the Wasm dry run. `build/web/privacy/index.html` is present, and the compiled Web HTML/JavaScript contains no Mobile Ads identifier or SDK reference.
- Configured `flutter build apk --debug --dart-define-from-file=dart_defines.local.json`: passed; output `build/app/outputs/flutter-apk/app-debug.apk`. The merged manifest confirms package `com.skyhopper.game`, min/target API 24/36, and Google's official sample AdMob app ID.
- A direct Gradle release dry check failed intentionally before assembly with the explicit missing `android/key.properties` message. It did not fall back to the debug signing key.
- Supabase MCP applied hosted migration `20260928035631 / phase13a_rewarded_bonus`. Read-only verification confirmed RLS, one owner-only authenticated SELECT policy, authenticated-only RPC execution, and no authenticated direct INSERT/UPDATE/DELETE privileges.
- A controlled live RPC test used an eligible saved normal run inside a transaction and rolled back. It confirmed server-derived bonus math, one balance increment, and idempotent second-call behavior. Post-rollback verification found zero reward-claim rows, so no real balance or game data changed.
- Existing Phase 3, 6, 7, and 12 migration files are unchanged. Their MD5 values remain `2481c9a35392126533828fe88e2f0343`, `76966a13023ff70d041d3a2bd32060d3`, `4f4a11cf557108c2372cae9306c2217e`, and `4fc9a94dd5381cb3a5c558f8441caa6a`.
- The source/config scan found no real credential, private key, keystore, signing file, production AdMob value, or privileged Supabase key. Matches were documentation and synthetic validation-test strings. Ignored private Dart defines were used without printing their contents.
- **Physical Android consent/ad/audio verification: pending.** The APK and manifest are verified, but no connected physical phone was available to observe Google's `Test Ad` presentation, region-specific UMP form, or audible restoration.
