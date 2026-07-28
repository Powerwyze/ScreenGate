# Questime Architecture

## Overview
Questime is a quest-based productivity app. It turns time and goals into concrete quests with AI verification, personalized Handler coaching, and social accountability.

The repo still keeps the Flutter package name `taskassassin` for now so existing Dart imports remain stable during the product pivot.

## Backend: Supabase
Questime uses Supabase for:
- Authentication: email/password and Google sign-in
- Database: PostgreSQL tables for users, quests, social graph, messages, notifications, and bug reports
- Storage: Supabase Storage for avatars and quest proof photos
- Edge Functions: server-side ChatGPT/OpenAI calls through `supabase/functions/chatgpt-chat`

## AI Boundary
OpenAI API calls must stay server-side. The Flutter client invokes the Supabase `chatgpt-chat` Edge Function and never ships `OPENAI_API_KEY` in `.env`, app assets, or source code.

Required Edge Function secrets:
- `OPENAI_API_KEY`
- `OPENAI_MODEL`, default `gpt-5.6-luna`
- `ALLOWED_ORIGIN` for web CORS, or `*` during development
- `MAX_REQUEST_BYTES`, optional, default `12000`
- `MAX_IMAGE_BYTES`, optional, default `5242880`
- `MAX_OUTPUT_TOKENS`, optional, default `900`
- `OPENAI_TIMEOUT_MS`, optional, default `45000`
- `ALLOWED_IMAGE_HOSTS`, optional, defaults to the Supabase project host

## Product Model
- Users create or receive quests.
- A quest has title, description, completion criteria, status, deadline, proof photos, stars, and AI feedback.
- Handler personalities coach users and help generate quest ideas.
- Friends can assign quests, message each other, and compare progress.

## Key Flutter Areas
- `lib/main.dart`: app initialization and routing
- `lib/providers/app_provider.dart`: global user, Handler, quest, and service state
- `lib/services/ai_service.dart`: client wrapper around the `chatgpt-chat` Edge Function
- `lib/services/mission_service.dart`: Supabase CRUD for quests/missions
- `lib/services/image_upload_service.dart`: Supabase Storage uploads
- `lib/screens/mission_detail_screen.dart`: quest proof upload and verification flow

## Security Notes
- Do not package `.env` as a Flutter asset.
- Revoke any API key that was previously committed to history.
- Version Supabase RLS and Storage policies in migrations before production release.
- The Edge Function validates Supabase auth, request size, action names, and image hosts before calling OpenAI.

## Current Pivot Scope
This branch changes product-facing naming to Questime and moves AI calls out of the Flutter client. A full internal package rename from `taskassassin` to `questime` should be a separate mechanical change because it touches every Dart package import and native bundle identifier.
