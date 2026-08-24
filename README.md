# ScreenGate

ScreenGate turns time into quests with AI verification, personalized Handler coaching, and social accountability.

This repository contains the ScreenGate Flutter app. The Dart package name is `screengate`.

## What Changed In The Pivot

- Product-facing app name is ScreenGate.
- Android and web metadata now use ScreenGate branding.
- Android application ID is prepared as `com.powerwyze.questime`.
- iOS display metadata now uses ScreenGate branding.
- The Flutter app no longer packages `.env` as an asset.
- AI calls are routed through the Supabase `ai-chat` Edge Function.
- OpenAI API keys belong in Supabase Edge Function secrets, never in the Flutter client.
- Push notifications are disabled by default until Firebase is registered for the final app IDs.

## Mobile Release Path

See [docs/mobile-release.md](docs/mobile-release.md) for the Android and iOS release checklist, signing requirements, Firebase setup, and store metadata tasks.

## Flutter Build Configuration

Release builds can override app configuration with Dart defines:

```sh
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://foplbkcnkrolglzxayjt.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ENABLE_PUSH=false
```

## Required Server-Side Secrets

Configure these in Supabase Edge Function secrets:

```text
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
ALLOWED_ORIGIN=*
MAX_REQUEST_BYTES=12000
MAX_IMAGE_BYTES=5242880
```

`ALLOWED_IMAGE_HOSTS` is optional and defaults to the Supabase project host.

## Local Checks

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build web --release
flutter build appbundle --release
flutter build ios --release --no-codesign
```

GitHub Actions now verifies web, Android app bundle, and iOS no-codesign builds for pull requests.

## Security Notes

Revoke any old provider key that was previously committed to repository history. Before production, add Supabase migrations for RLS and Storage policies so the backend security model is versioned with the app.
