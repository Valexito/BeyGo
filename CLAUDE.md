# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

BeyGo — Flutter app (Dart 3.7+) to find and reserve nearby parking spots in real time. Firebase backend (Auth, Firestore, Storage, Cloud Functions, FCM, App Check, Crashlytics), Google Maps/Places/Directions, Riverpod for state management.

## Commands

```bash
flutter pub get                        # install deps
flutter run                            # run on connected device/emulator
flutter analyze                        # static analysis
flutter test                           # run all tests
flutter test test/widget_test.dart     # run a single test file
```

Local setup required before running: `android/local.properties` needs `MAPS_API_KEY=<key>` (injected into `AndroidManifest.xml` via `build.gradle.kts`, also reused for Places).

**Analyzer note:** `analysis_options.yaml` does not currently exist (only a disabled `analysis_options.yaml.bak`), so `flutter analyze` runs with bare Dart defaults, not the `flutter_lints` ruleset declared in `pubspec.yaml`'s dev_dependencies.

### Release build (Android)

Release signing needs `key.properties` at the repo root (gitignored) — see `android/key.properties.template` for the format and the `keytool` command to generate the keystore. Gradle fails the release build immediately if `key.properties` is missing.

### Shorebird (code push)

This app ships updates via [Shorebird](https://shorebird.dev) so pure-Dart fixes don't need a new Play Store review. `shorebird.yaml` (checked in, non-secret) holds the `app_id`.

```bash
export PATH="$HOME/.shorebird/bin:$PATH"

# One-time per store submission: builds a new patchable baseline.
# Pin --flutter-version to the project's actual Flutter version (see .metadata) —
# Shorebird defaults to latest stable, which can require a newer Gradle/AGP than
# this project's wrapper supports.
shorebird release android --flutter-version=3.29.3

# Ship a Dart-only fix to everyone already on a given release, no store review:
shorebird patch android --release-version=<version>
```

Every `shorebird release` needs its own `pubspec.yaml` `version` build-number bump (Play Store version codes cannot repeat), same as a normal Flutter release. `shorebird patch` does not bump the version — it targets an already-published `--release-version`.

`minSdk` is pinned to `23` explicitly in `android/app/build.gradle.kts` (not left as `flutter.minSdkVersion`) because Shorebird's forked Flutter build defaults that to `21`, which conflicts with `com.google.android.libraries.places` (requires 23).

### Firebase / backend

```bash
# From this repo (backend only — see project separation below):
firebase deploy --only functions,firestore,storage

# Cloud Functions (from functions/):
npm run serve      # emulator
npm run logs        # tail deployed function logs
npm run deploy       # deploy functions only

# Grant/revoke the `admin` custom claim on a Firebase Auth user (from functions/):
npm run set-admin-claim -- <uid> [true|false]
```

**Project separation:** this repo owns the Flutter app and backend (`beygo-app-prod`: Firestore, Storage, Functions, Auth). The public website, Firebase Hosting, and the internal admin web panel are a **separate repo, `beygo-site`**, not present here — only its compiled output lives under `site-dist/`. Never run a hosting deploy from this repo.

## Architecture

### Feature-module layout

`lib/features/{auth,core,owner,reservations,users}/`, each internally split into `pages/`, `providers/`, `components/` or `widgets/`, and `models/` where relevant. Each feature exposes one barrel file (`auth.dart`, `core.dart`, `owner.dart`, `reservations.dart`, `users.dart`) that re-exports its public surface — import that instead of individual files when consuming another feature. These barrels are hand-maintained (marked "Auto-generado" but there is no generator script in the repo — update them by hand when adding a new public file). `lib/beygo.dart` re-exports everything and is documented as prototyping-only; production code should import per-feature barrels to keep tree-shaking effective. `lib/common/` holds cross-feature services (geolocation, Google Directions/Places, notifications, app preferences) and shared UI.

### State management (Riverpod)

Base Firebase handles live in `lib/features/core/providers/firebase_providers.dart` (`firebaseAuthProvider`, `firestoreProvider`, `authStateChangesProvider`, `storageProvider`). Almost every other provider wraps a Firestore stream via `StreamProvider`/`StreamProvider.family`.

**Auth-lifecycle gotcha (load-bearing):** a `StreamProvider` that opens a `.snapshots()` listener but is not `.autoDispose` and does not `ref.watch` an auth-state provider will survive a sign-out. If the underlying listener is still open when Firebase Auth revokes the token, Firestore returns a one-time `permission-denied`, and Riverpod caches that as the provider's terminal state — inside the single, process-lifetime `ProviderScope` created once in `main.dart`. A later sign-in returns the same cached error instead of a fresh stream; only killing the app clears it. `userReservationsProvider`/`ownerAllReservationsProvider` (`lib/features/reservations/providers/reservations_providers.dart`) do this correctly by watching auth state. When adding a new Firestore-backed `StreamProvider`, make it `.autoDispose` (as `reservationChatMessagesProvider`, `reservationChatBlockStateProvider`, and `ownerWalkInHistoryProvider` now are) and/or have it watch auth state — don't rely on manual `ref.invalidate` lists in the sign-out flow (`lib/features/auth/providers/auth_providers.dart` `_AuthActions._performSignOut()`, `lib/features/auth/pages/auth_gate.dart` `_clearProvidersForUid()`) to cover every provider.

### Role-based routing

`UserRole` (`user` / `provider` / `admin` / `unknown`) drives navigation, sourced from `myRoleStreamProvider`. `HomeSwitch` (`lib/features/core/pages/home_switch.dart`) routes `provider`/`admin` to `OwnerHomePage` and everyone else to the regular `HomePage`. `RoleRedirect`/`OwnerOnly`/`UserOnly` (`lib/features/core/roles/role_utils.dart`) guard individual pages the same way. `AuthGate` (`lib/features/auth/pages/auth_gate.dart`) is the top-level gate: it watches `authStateChangesProvider`, then `canEnterAppProvider(uid)` to decide between `CompleteProfilePage` and `HomeSwitch`, and clears the previous user's cached providers on sign-out or account switch.

### Firestore data model & security

`firestore.rules` is the source of truth for authorization — read it before changing any Firestore access pattern. Key points:

- Admin access is `request.auth.token.admin == true` (the Firebase Auth custom claim), not any client-side check.
- Parking ownership resolves through `get()` lookups; reservation ownership (`reservationOwnerUidFromData`) supports both a legacy `ownerID` field and the current `ownerId` field, falling back to the parking doc's `ownerID` — don't assume only one field name is present on old documents.
- Reservation lifecycle fields: `state` (`pending` → `active` → `completed`, or `rejected` / `cancellation_requested`), `providerApprovalStatus` (`pending`/`approved`/`rejected`), `exitStatus` (`none`/`requested`/`approved`/`rejected`). See `lib/features/reservations/models/reservation.dart` for the corresponding getters.
- Chat lives at `reservations/{resId}/messages` and is only writable while the reservation is `pending`/`active`/`cancellation_requested` and neither participant has blocked the other (`reservations/{resId}/chat_blocks/{blockerUid}`).

### Two separate "admin" mechanisms — do not conflate them

1. **Web panel login gate** — a hardcoded email/UID allowlist compiled into the `beygo-site` panel bundle (source not in this repo; only `site-dist/` here). Controls who can even attempt to sign into the internal panel.
2. **Firebase custom claim `admin`** — the actual authorization used by `firestore.rules`, `storage.rules`, and `functions/index.js` (`request.auth.token.admin` / `request.auth?.token?.admin`). Set/cleared via `functions/scripts/set_admin_claim.js` (`npm run set-admin-claim -- <uid> [true|false]` from `functions/`, requires `firebase-admin` application-default credentials for `beygo-app-prod`). A user must sign out/in (or force-refresh their ID token) after this changes before the new claim takes effect client-side.

### Cloud Functions (`functions/index.js`, ~1700 lines)

`onCall` functions: owner revenue PIN OTP request/verify, force-finalizing a reservation, sending an owner history report (on-demand and scheduled monthly via `onSchedule`), account deletion (self and admin-driven). Firestore triggers (`onDocumentCreated`/`onDocumentWritten`): support report creation, provider request creation, reservation state changes, chat message creation (drives push notifications), parking review writes. PDF report generation uses `pdfkit`; emailing uses `nodemailer`. There are no automated tests for functions or for the Flutter app beyond the default `test/widget_test.dart` counter-app boilerplate (not reflective of the real app).
