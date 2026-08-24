# ScreenGate Architecture

## Overview
ScreenGate is a quest-based productivity app. It turns time and goals into concrete quests with AI verification, personalized Handler coaching, and social accountability.

The Flutter package name is `screengate`.

## Backend: Supabase
ScreenGate uses Supabase for:
- Authentication: email/password and Google sign-in
- Database: PostgreSQL tables for users, quests, social graph, messages, notifications, and bug reports
- Storage: Supabase Storage for avatars and quest proof photos
- Edge Functions: server-side OpenAI calls through `supabase/functions/ai-chat`

## AI Boundary
AI calls must stay server-side. The Flutter client invokes the Supabase `ai-chat` Edge Function and never ships `OPENAI_API_KEY` in `.env`, app assets, or source code.

Required Edge Function secrets:
- `OPENAI_API_KEY`
- `ALLOWED_ORIGIN` for web CORS, or `*` during development
- `MAX_REQUEST_BYTES`, optional, default `12000`
- `MAX_IMAGE_BYTES`, optional, default `5242880`
- `ALLOWED_IMAGE_HOSTS`, optional, defaults to the Supabase project host

## Product Model
- Users create or receive quests.
- A quest has title, description, completion criteria, status, deadline, proof photos, stars, and AI feedback.
- Handler personalities coach users and help generate quest ideas.
- Friends can assign quests, message each other, and compare progress.

## Key Flutter Areas
- `lib/main.dart`: app initialization and routing
- `lib/providers/app_provider.dart`: global user, Handler, quest, and service state
- `lib/services/ai_service.dart`: client wrapper around the `ai-chat` Edge Function
- `lib/services/mission_service.dart`: Supabase CRUD for quests/missions
- `lib/services/image_upload_service.dart`: Supabase Storage uploads
- `lib/screens/mission_detail_screen.dart`: quest proof upload and verification flow

## Security Notes
- Do not package `.env` as a Flutter asset.
- Revoke any API key that was previously committed to history.
- Version Supabase RLS and Storage policies in migrations before production release.
- The Edge Function validates Supabase auth and action names before calling OpenAI.

## Current Pivot Scope
ScreenGate routes OpenAI requests through Supabase so provider credentials remain outside the Flutter client. Store bundle identifiers and existing Supabase schema names remain stable for upgrade and data compatibility.
