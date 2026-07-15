package com.localai.chat.ollama;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.localai.chat.chat.dto.ChatDtos.GenerationSettings;
import com.localai.chat.config.OllamaProperties;
import com.localai.chat.exception.ApiException;
import com.localai.chat.ollama.dto.OllamaDtos.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.List;

/**
 * Talks to a locally running Ollama instance only. No other model provider
 * is wired in — swapping providers means swapping this class's HTTP calls,
 * not adding cloud credentials anywhere else in the app.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class OllamaService {

    private final WebClient ollamaWebClient;
    private final OllamaProperties ollamaProperties;
    private final ObjectMapper objectMapper;

    /**
     * Streams assistant reply tokens as they arrive from Ollama. Emits
     * content deltas (not full accumulated text) so callers can forward
     * them directly to an SSE client.
     */
    public Flux<String> streamChat(List<OllamaMessage> messages, String modelOverride, GenerationSettings settings) {
        String model = (modelOverride == null || modelOverride.isBlank())
                ? ollamaProperties.defaultModel()
                : modelOverride;

        OllamaOptions options = new OllamaOptions(
                settings != null ? settings.temperature() : null,
                settings != null ? settings.topP() : null,
                settings != null ? settings.topK() : null,
                settings != null ? settings.maxTokens() : null
        );

        OllamaChatRequest request = new OllamaChatRequest(model, messages, true, options);

        Flux<String> rawLines = ollamaWebClient.post()
                .uri("/api/chat")
                .bodyValue(request)
                .retrieve()
                .onStatus(status -> status.isError(), response ->
                        response.bodyToMono(String.class).defaultIfEmpty("").flatMap(body ->
                                Mono.error(ApiException.badRequest(
                                        "Ollama returned an error (is the '" + model + "' model pulled?): " + body))))
                .bodyToFlux(String.class);

        return splitOnNewlines(rawLines)
                .filter(line -> !line.isBlank())
                .mapNotNull(this::parseChunk)
                .takeUntil(OllamaChatResponseChunk::done)
                .map(chunk -> chunk.message() != null && chunk.message().content() != null
                        ? chunk.message().content()
                        : "")
                .filter(delta -> !delta.isEmpty())
                .onErrorMap(ex -> !(ex instanceof ApiException), ex ->
                        ApiException.badRequest("Lost connection to Ollama: " + ex.getMessage()));
    }

    public List<String> listAvailableModels() {
        try {
            OllamaTagsResponse response = ollamaWebClient.get()
                    .uri("/api/tags")
                    .retrieve()
                    .bodyToMono(OllamaTagsResponse.class)
                    .block();

            if (response == null || response.models() == null) {
                return ollamaProperties.availableModels();
            }
            return response.models().stream().map(OllamaModelInfo::name).toList();
        } catch (Exception e) {
            log.warn("Could not reach Ollama to list models, falling back to configured list", e);
            return ollamaProperties.availableModels();
        }
    }

    private OllamaChatResponseChunk parseChunk(String line) {
        try {
            return objectMapper.readValue(line, OllamaChatResponseChunk.class);
        } catch (Exception e) {
            log.warn("Skipping malformed Ollama stream line: {}", line);
            return null;
        }
    }

    /**
     * Ollama streams one JSON object per line over chunked transfer
     * encoding. WebClient's DataBuffer chunks don't always align to line
     * boundaries, so we buffer and split explicitly rather than assume
     * each network chunk is exactly one JSON object.
     */
    private Flux<String> splitOnNewlines(Flux<String> raw) {
        StringBuilder buffer = new StringBuilder();
        return raw.concatMapIterable(piece -> {
            buffer.append(piece);
            List<String> lines = new ArrayList<>();
            int newlineIndex;
            while ((newlineIndex = buffer.indexOf("\n")) >= 0) {
                lines.add(buffer.substring(0, newlineIndex));
                buffer.delete(0, newlineIndex + 1);
            }
            return lines;
        });
    }
}
