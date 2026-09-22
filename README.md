# Sky Hopper

Phases 1–8 complete. Phase 9 repository preparation is in progress; deployment and final packaging are pending.
Splash resolves authentication before Login or Home. PLAY preserves the endless jumper and retry-safe result persistence. LEADERBOARD shows public best scores through a restricted RPC; SKINS supports server-priced unlocks and owned-skin selection. Live and offline verification are distinguished below.

## Toolchain

- Flutter 3.47.5 / Dart 3.13.4
- Flame 1.38.2; supabase_flutter 2.17.2 (see pubspec.lock)
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

Production authentication configuration is pending dashboard access: Supabase URL Configuration redirected the verification browser to dashboard sign-in. The app's existing redirect is the current origin plus `/`, so the exact production redirect is `https://sky-hopper-blue.vercel.app/`. Set the production Site URL and allow that redirect while preserving local development and Android callbacks. In the existing Google Web OAuth client, verify/add authorized JavaScript origin `https://sky-hopper-blue.vercel.app` and preserve the Supabase callback `https://ittdhvlfrrjnsvdfpznl.supabase.co/auth/v1/callback`. Do not replace that callback with the Vercel origin or rotate credentials. No auth configuration changes were made by this run.

Resume after dashboard configuration/access is confirmed, then verify actual Google login, restoration, gameplay/save, leaderboard and read-only Skins behavior before release APK/ZIP packaging. Split release APKs and final submission ZIP remain pending. Application code, the 126-test baseline and database schema are unchanged.
