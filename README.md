# Local — Flutter client (Phase 3: wired to the backend)
A fully offline AI chat app: this Flutter client, a Spring Boot backend, and
Ollama running local models. No cloud AI APIs, no API keys, ever.

Phases 1 (UI skeleton) and 2 (Spring Boot + Ollama backend) are done. This
phase replaces the placeholder/simulated data with real calls to that
backend — auth, conversations, message history, and streaming replies all
go over the wire now, with Hive used as an offline cache rather than as
the source of truth.

## What changed in this phase

- **`ChatRepository`** (`features/chat/data/chat_repository.dart`) — talks
  to `/chat/conversations`, `/chat/conversations/{id}/messages`, and
  `/models`.
- **`SseClient`** (`core/network/sse_client.dart`) — a small Server-Sent
  Events parser built on Dio's streamed responses, used to consume
  `/chat/conversations/{id}/stream`.
- **`ConversationListNotifier`** and **`ChatSessionNotifier`**
  (`features/chat/providers/chat_providers.dart`) — now load from Hive
  cache instantly on start, then refresh from the backend in the
  background. Every mutation (rename/pin/archive/favorite/delete/send)
  writes through to the backend and updates the cache; if the backend is
  unreachable, `backendReachabilityProvider` flips to `false` and the chat
  list shows the "using cached data" banner from Phase 1.
- Auth (`features/auth/*`) was already wired to real endpoints since
  Phase 1 — no changes needed there.

## Known limitations (by design, for now)

- **Regenerate** resends the last user message as a *new* turn rather than
  truly replacing the last assistant reply in place, because the backend's
  `/stream` endpoint always appends a fresh user message. A dedicated
  `/regenerate` endpoint that skips that step would clean this up.
- **Offline writes don't sync later.** If you create/edit something while
  the backend is unreachable, the optimistic local change sticks around in
  Hive but isn't queued for replay once you're back online. True offline
  sync (a mutation outbox + conflict resolution) is a follow-up.
- **File upload** UI button exists but isn't wired to `POST /files` yet.
- **Settings screen** sliders/switches aren't wired to `GET/PUT /settings`
  yet — still cosmetic.

## Running it

Same as before — this sandbox can't reach pub.dev, so verify on your
machine:

```bash
flutter pub get
flutter run
```

Make sure the backend stack is up first (`docker compose up` from the
backend project) and that `lib/core/config/app_config.dart` points at it.

