package com.localai.chat.chat.controller;

import com.localai.chat.chat.dto.ChatDtos.GenerationSettings;
import com.localai.chat.chat.dto.ChatDtos.SendMessageRequest;
import com.localai.chat.chat.model.Conversation;
import com.localai.chat.chat.model.Message;
import com.localai.chat.chat.service.ChatService;
import com.localai.chat.ollama.OllamaService;
import com.localai.chat.ollama.dto.OllamaDtos.OllamaMessage;
import com.localai.chat.security.AppUserPrincipal;
import com.localai.chat.settings.UserSettings;
import com.localai.chat.settings.UserSettingsRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;

import java.util.List;

/**
 * The whole point of this app: user message in, tokens streamed back from
 * a local Ollama model, nothing ever leaving the machine/network the
 * backend runs on.
 */
@RestController
@RequestMapping("/chat/conversations/{conversationId}")
@RequiredArgsConstructor
@Slf4j
public class StreamController {

    private static final int CONTEXT_WINDOW_MESSAGES = 30;

    private final ChatService chatService;
    private final OllamaService ollamaService;
    private final UserSettingsRepository userSettingsRepository;

    @PostMapping(path = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> stream(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String conversationId,
            @Valid @RequestBody SendMessageRequest request
    ) {
        String userId = principal.getId();
        Conversation conversation = chatService.getOwned(userId, conversationId);

        // Persist the user's message first so it survives even if streaming fails.
        chatService.appendMessage(userId, conversationId, Message.Role.USER, request.content(), request.attachmentIds());

        List<OllamaMessage> context = buildContext(conversation, conversationId);

        StringBuilder accumulated = new StringBuilder();

        Flux<String> tokens = ollamaService.streamChat(context, conversation.getModelName(), generationSettingsFor(userId))
                .doOnNext(accumulated::append)
                .doOnComplete(() -> {
                    if (!accumulated.isEmpty()) {
                        chatService.appendMessage(userId, conversationId, Message.Role.ASSISTANT, accumulated.toString(), null);
                        chatService.touch(conversationId);
                    }
                })
                .doOnError(err -> log.error("Streaming failed for conversation {}: {}", conversationId, err.getMessage()));

        return tokens
                .map(delta -> ServerSentEvent.builder(delta).event("token").build())
                .concatWith(Flux.just(ServerSentEvent.<String>builder("").event("done").build()))
                .onErrorResume(err -> Flux.just(
                        ServerSentEvent.<String>builder(err.getMessage() == null ? "Generation failed" : err.getMessage())
                                .event("error")
                                .build()));
    }

    private List<OllamaMessage> buildContext(Conversation conversation, String conversationId) {
        List<Message> history = chatService.recentHistory(conversationId, CONTEXT_WINDOW_MESSAGES);

        List<OllamaMessage> messages = new java.util.ArrayList<>();
        if (conversation.getMemorySummary() != null && !conversation.getMemorySummary().isBlank()) {
            messages.add(new OllamaMessage("system",
                    "Summary of earlier conversation: " + conversation.getMemorySummary()));
        }
        for (Message m : history) {
            messages.add(new OllamaMessage(m.getRole().name().toLowerCase(), m.getContent()));
        }
        return messages;
    }

    private GenerationSettings generationSettingsFor(String userId) {
        UserSettings settings = userSettingsRepository.findByUserId(userId)
                .orElseGet(() -> UserSettings.builder().userId(userId).build());
        return new GenerationSettings(
                settings.getTemperature(),
                settings.getTopP(),
                settings.getTopK(),
                settings.getMaxTokens()
        );
    }
}
