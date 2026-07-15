# Local AI Chat — Backend (Phase 2)

Spring Boot 3 / Java 21 backend for the offline AI chat app. Talks to
MongoDB for persistence and to a local Ollama instance for inference.
Nothing here calls out to any cloud AI provider.

## Stack

- Java 21, Spring Boot 3.3, Gradle
- MongoDB (Spring Data MongoDB)
- Spring Security + JWT (access token + rotating opaque refresh token)
- WebClient (reactive) for streaming from Ollama's `/api/chat`
- SSE (`text/event-stream`) for streaming chat responses to the Flutter app
- STOMP/WebSocket for typing indicators (separate from the SSE chat stream)
- PDFBox / Apache POI for `/files` text extraction
- Bucket4j for per-IP rate limiting

## Running it

This sandbox can't reach Maven Central, so nothing here has been
compiled — you'll build it on your own machine.

```bash
cp .env.example .env
# edit .env — set a real JWT_SECRET

docker compose up --build
```

That starts MongoDB, Ollama, and the backend together. First time only,
pull the models you want into the Ollama container:

```bash
docker exec -it local-ai-chat-ollama ollama pull llama3.1:8b
docker exec -it local-ai-chat-ollama ollama pull gemma3:9b
docker exec -it local-ai-chat-ollama ollama pull qwen3:8b
```

The backend is then reachable at `http://localhost:8080/api`. Point the
Flutter app's `AppConfig.defaultBaseUrl` at that (or the host machine's LAN
IP for a physical device).

### Running without Docker (dev loop)

```bash
docker run -d -p 27017:27017 mongo:7
ollama serve   # assumes Ollama is installed locally
./gradlew bootRun
```

The Gradle wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`)
is included, so no local Gradle install is required — `./gradlew` will
download Gradle 8.9 itself on first run (needs internet access to
`services.gradle.org` the first time; cached after that).

## API surface

| Area | Endpoints |
|---|---|
| Auth | `POST /api/auth/register`, `/login`, `/refresh`, `/forgot-password`, `/logout` |
| Users | `GET/PUT /api/users/me`, `GET /api/users/me/export`, `DELETE /api/users/me` |
| Conversations | `GET/POST /api/chat/conversations`, `PATCH .../{id}`, `POST .../{id}/pin`, `/archive`, `/favorite`, `DELETE .../{id}` |
| Messages | `GET /api/chat/conversations/{id}/messages`, `.../search`, `POST /api/messages/{id}/favorite`, `DELETE /api/messages/{id}` |
| Streaming | `POST /api/chat/conversations/{id}/stream` (SSE — the core chat endpoint) |
| History | `GET /api/history` (alias for the conversation list) |
| Models | `GET /api/models` (live list from Ollama, falls back to configured list) |
| Settings | `GET/PUT /api/settings` |
| Files | `POST /api/files` (multipart upload + text extraction), `GET /api/files/{id}` |
| WebSocket | `/api/ws` (STOMP) — typing indicators on `/topic/conversations/{id}/typing` |

All endpoints except `/auth/*` and `/actuator/health` require
`Authorization: Bearer <accessToken>`.

### Streaming contract

`POST /chat/conversations/{id}/stream` with body `{"content": "..."}`
returns an `text/event-stream` response:

```
event: token
data: Hello

event: token
data:  there

event: done
data:
```

(or `event: error` with a message if Ollama fails mid-stream). The backend
persists the user message before streaming starts and the full assistant
reply once the stream completes, so a dropped connection never loses the
user's side of the conversation.

## What's stubbed / next

- `/auth/forgot-password` doesn't send an email yet — this app has no
  outbound internet access by design, so wire it to a local SMTP relay or
  an admin-issued reset flow.
- `/users/me/export` returns profile only; extend it to zip conversations,
  messages, and settings.
- Conversation "memory summary" field exists on the model but nothing
  populates it yet — add a scheduled job that summarizes old messages via
  Ollama once a conversation exceeds the context window.
- Rate limiting is in-memory per instance; fine for one backend replica.
- No test suite yet (JUnit + `spring-security-test` + embedded Mongo are
  already on the classpath, ready to write against).
