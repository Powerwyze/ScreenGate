# Questime Mobile Release Path

Questime is a Flutter app. The same Dart codebase should ship native Android and iOS builds.

## Current Mobile Identifiers

- Android application ID: `com.powerwyze.questime`
- iOS target bundle ID to set in Xcode: `com.powerwyze.questime`
- App display name: `Questime`

## Build Configuration

Release builds can override app configuration with Dart defines:

```sh
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://gbwzsxjromwefuopvzfg.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ENABLE_PUSH=false

flutter build ios --release --no-codesign \
  --dart-define=SUPABASE_URL=https://gbwzsxjromwefuopvzfg.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ENABLE_PUSH=false
```

`ENABLE_PUSH` defaults to `false`. Do not enable it until Firebase is configured for the final Android and iOS bundle IDs.

## Supabase Backend Before App Testing

Use the Supabase CLI for the ChatGPT-backed Edge Function:

```sh
supabase login
supabase link --project-ref gbwzsxjromwefuopvzfg
supabase secrets set \
  OPENAI_API_KEY=... \
  OPENAI_MODEL=gpt-5.6-luna \
  ALLOWED_ORIGIN=* \
  MAX_REQUEST_BYTES=12000 \
  MAX_IMAGE_BYTES=5242880 \
  MAX_OUTPUT_TOKENS=900 \
  OPENAI_TIMEOUT_MS=45000
supabase functions deploy chatgpt-chat
```

`ALLOWED_IMAGE_HOSTS` is optional and defaults to the Supabase project host. Set it only if proof photos are served from additional trusted HTTPS hosts.

## Android Before Play Store Upload

1. Register `com.powerwyze.questime` in Firebase if push notifications are required.
2. Download a fresh `android/app/google-services.json` for that app.
3. Re-enable the Google Services Gradle plugin in `android/app/build.gradle`:

```gradle
id 'com.google.gms.google-services'
```

4. Create `android/key.properties` pointing to the release keystore.
5. Build the release bundle:

```sh
flutter build appbundle --release --dart-define=ENABLE_PUSH=true
```

The checked-in Gradle config falls back to debug signing only so CI can compile release artifacts without private signing material. Do not upload a debug-signed bundle to Google Play.

## iOS Before App Store/TestFlight Upload

1. In Xcode, set the Runner target bundle identifier to `com.powerwyze.questime` for Debug, Release, and Profile.
2. Select the Apple developer team for signing.
3. Register the App ID and enable capabilities needed for production.
4. If push notifications are required, add a Firebase iOS app for `com.powerwyze.questime`, download `ios/Runner/GoogleService-Info.plist`, and enable push/APNs in Apple Developer and Firebase.
5. Archive from Xcode or CI with valid signing credentials.

## Store Metadata Checklist

- Privacy policy URL
- Support URL and support email
- App icon and screenshots for required device sizes
- App Store privacy nutrition labels
- Google Play data safety form
- Age rating questionnaire
- Camera/photo usage disclosure
- AI-assisted verification disclosure

## CI Coverage

GitHub Actions should verify:

- `deno check supabase/functions/chatgpt-chat/index.ts`
- `flutter pub get`
- `flutter analyze --no-fatal-infos`
- `flutter test`
- `flutter build web --release`
- `flutter build appbundle --release`
- `flutter build ios --release --no-codesign` on macOS
