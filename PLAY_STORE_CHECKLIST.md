# Sky Hopper Google Play Checklist

This inventory separates behavior confirmed in the repository from decisions and console answers that still require the developer. Recheck it against the final signed AAB and the current Google Play/Data safety wording before submission.

## Confirmed from code

- **Package and SDKs:** Android application ID `com.azitechstudio.skyhopper`; compile/target SDK 36; the current Flutter toolchain resolves the minimum SDK to 24.
- **Account:** production startup creates a Supabase anonymous account for Guest play and can optionally link it to Google without changing the user ID. The app can display the Google-provided name, HTTPS avatar, and Auth email after linking. Email is not copied into the public game tables.
- **Stored game data:** Supabase stores profile fields, scores, height, collected/lifetime coins, selected/unlocked cosmetics, run UUIDs, timestamps, Daily Challenge results/attempts, missions, achievements, and streaks.
- **Public competition data:** restricted RPCs may return display name, safe avatar URL, score, height, played time, rank, and a current-user flag. They do not return account UUID, email, tokens, or provider data.
- **Advertising:** Android uses Google Mobile Ads for voluntary Game Over rewarded ads and restrained post-Game-Over interstitials. Web is ad-free. There are no gameplay banners or app-open ads.
- **Consent:** Android uses Google's UMP SDK. Ads are requested only when its `canRequestAds()` state allows them. Settings exposes Google's Privacy Options form when required.
- **Reward data:** one authenticated server record may be stored for a rewarded claim, including user ID, run UUID, score-row reference, bounded bonus, and timestamp. The server calculates the amount; Flutter cannot submit an arbitrary amount.
- **Transport:** configured Supabase and Google endpoints use HTTPS. Android declares Internet access. Do not mark data as encrypted at rest solely from this code; confirm the current provider guarantees and Play's definition.
- **Credentials:** production Supabase public client values and ad unit IDs are compile-time configuration. Signing/ad configuration files are ignored. Service-role keys, OAuth client secrets, signing passwords, and private keys are not client configuration.
- **Privacy policy:** `web/privacy/index.html`, live at `https://sky-hopper-blue.vercel.app/privacy/`.
- **Account deletion:** Profile → Delete Account invokes the authenticated `delete-account` Edge Function, which derives the caller from the JWT and hard-deletes only that Supabase Auth user. Verified `ON DELETE CASCADE` constraints remove every user-owned game row. The external instructions and email request path are live at `https://sky-hopper-blue.vercel.app/delete-account/`.

## Developer confirmation required

- [ ] Decide the target audience and age ranges. Do not mark the app child-directed or enable COPPA/under-age treatment without this product decision.
- [ ] Complete the content rating questionnaire from the final game and store listing.
- [ ] Review the **Contains ads** declaration using the final build behavior.
- [ ] Complete Data safety from the final SDK versions and provider documentation. Review user identifiers, profile information, app activity/gameplay, advertising or device identifiers, diagnostics, purposes, sharing, retention, and optional versus required collection.
- [ ] Confirm Google Mobile Ads diagnostics/crash collection and personalized/non-personalized advertising behavior for every served region and consent choice.
- [ ] Confirm Supabase, Google, Vercel, and Google Play encryption, retention, and deletion behavior before answering console questions.
- [x] Provide a real support contact and a working account/data-deletion request mechanism; update the privacy page with both.
- [x] Host the privacy and account-deletion pages at stable public HTTPS URLs.
- [ ] Enter the live privacy-policy and account-deletion URLs in Google Play Console.
- [ ] Copy `docs/app-ads.txt.example` to ignored `web/app-ads.txt`, replace `<PUBLISHER_ID>` with the real publisher ID, then intentionally publish that real file at the developer website root and link the same website from the Play listing.
- [ ] Fill ignored `android/admob_config.local.json` with the real Android app, rewarded unit, and interstitial unit IDs. Never submit with Google's sample IDs.
- [ ] In AdMob App settings, update the app store/package association to `com.azitechstudio.skyhopper` after the new Play listing is available; preserve the existing production App ID and ad units.
- [ ] Create and securely back up the Play upload keystore. Populate private `android/key.properties`; never commit or share it.
- [ ] Pass both ignored configuration files to the release build: `dart_defines.local.json` for Supabase and `android/admob_config.local.json` for AdMob.
- [ ] Add `com.azitechstudio.skyhopper://login-callback/` to Supabase Auth allowed redirect URLs before native release testing. Preserve the production Web redirect and never use a service-role key in the app.
- [ ] Prepare Play app-access instructions explaining that reviewers can use the automatic Guest account without Google sign-in.
- [ ] Supply final store title, short/full descriptions, screenshots, feature graphic, icon, category, support email/site, and countries/regions.
- [ ] Review permissions and SDK declarations generated by the final merged manifest and signed AAB.
- [ ] Run Play pre-launch reports and test the final release on representative API 24 and API 36 devices.

## Physical Android test workflow

Use a debug/internal build with Google's official **Test Ad** identifiers. Never click a live production ad.

1. Clear app data or use a UMP test device to exercise consent where applicable. Confirm the Google form is provider-owned and the app remains usable if refresh fails.
2. Open Settings. Confirm Privacy Options appears only when UMP requires it, reopens Google's form, and does not claim to disable every ad.
3. Sign in, complete a normal run with coins, and wait for `Saved`. Confirm the voluntary reward action appears without obscuring Restart/Home.
4. Dismiss before the earned callback and confirm no bonus. On a new eligible saved run, complete a test rewarded ad and confirm one server-calculated bonus. Retry/reopen paths must not create a second claim for that run UUID.
5. Confirm the first normal run has no interstitial, approximately the third saved normal run can show one after choosing Restart/Home, a recent rewarded ad suppresses it, and a load/show failure still navigates.
6. Confirm ranked and practice Daily Challenges contain no rewarded or interstitial ads and retain their existing attempt/leaderboard rules.
7. Background and resume the app before, during, and after Game Over. Confirm gameplay pauses and music/SFX do not play loudly behind full-screen ads; Restart restores the normal audio state.
8. Confirm normal score/coin saving, missions, achievements, leaderboards, skins, Login, Settings, Game Over, Restart, and Home still work.
9. With a disposable Guest, earn a small amount of progress, use Profile → Delete Account, and confirm the Account Deleted screen. Choose Continue as Guest and confirm a different account starts with zero old progress.

## Final AAB gate

- [ ] `flutter analyze` and `flutter test` pass from a clean checkout.
- [ ] `flutter build web` passes and both `/privacy/` and `/delete-account/` are present in `build/web`.
- [ ] `flutter build apk --debug` passes using the ignored real App ID for UMP, while compiled rewarded/interstitial units remain Google's official test IDs.
- [ ] Secret scan is clean and ignored private configuration is absent from Git.
- [ ] `flutter build appbundle --release --dart-define-from-file=<private-file>` succeeds with production public configuration and release signing.
- [ ] Inspect the signed AAB/package name/version/manifest and upload it to an internal Play track before any wider release.
