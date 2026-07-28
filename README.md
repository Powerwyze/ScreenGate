# Questime

Questime turns time into quests with AI verification, personalized Handler coaching, and social accountability.

This repository is pivoting from the TaskAssassin prototype. The Flutter package name is still `taskassassin` for now to avoid a risky mechanical import rewrite during the product pivot.

## What Changed In The Pivot

- Product-facing app name is Questime.
- Android and web metadata now use Questime branding.
- Android application ID is prepared as `com.powerwyze.questime`.
- iOS display metadata now uses Questime branding.
- The Flutter app no longer packages `.env` as an asset.
- ChatGPT/OpenAI calls are routed through the Supabase `chatgpt-chat` Edge Function.
- OpenAI API keys belong in Supabase Edge Function secrets, never in the Flutter client.
- Push notifications are disabled by default until Firebase is registered for the final app IDs.

## Mobile Release Path

See [docs/mobile-release.md](docs/mobile-release.md) for the Android and iOS release checklist, signing requirements, Firebase setup, Supabase CLI deployment, and store metadata tasks.

## Flutter Build Configuration

Release builds can override app configuration with Dart defines:

```sh
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://gbwzsxjromwefuopvzfg.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ENABLE_PUSH=false
```

## Supabase Edge Function Deployment

Deploy the ChatGPT-backed Edge Function with the Supabase CLI after linking the project:

```sh
supabase link --project-ref gbwzsxjromwefuopvzfg
supabase secrets set OPENAI_API_KEY=... OPENAI_MODEL=gpt-5.6-luna ALLOWED_ORIGIN=*
supabase functions deploy chatgpt-chat
```

`ALLOWED_IMAGE_HOSTS` is optional and defaults to the Supabase project host.

## Required Server-Side Secrets

Configure these in Supabase Edge Function secrets:

```text
OPENAI_API_KEY=
OPENAI_MODEL=gpt-5.6-luna
ALLOWED_ORIGIN=*
MAX_REQUEST_BYTES=12000
MAX_IMAGE_BYTES=5242880
MAX_OUTPUT_TOKENS=900
OPENAI_TIMEOUT_MS=45000
```

## Local Checks

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build web --release
flutter build appbundle --release
flutter build ios --release --no-codesign
```

GitHub Actions verifies web, Android app bundle, iOS no-codesign, and Supabase Edge Function checks for pull requests.

## Security Notes

Revoke any old AI provider key that was previously committed to repository history. Before production, add Supabase migrations for RLS and Storage policies so the backend security model is versioned with the app.
