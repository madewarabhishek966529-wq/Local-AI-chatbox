package com.localai.chat.ollama.dto;

import java.util.List;

public class OllamaDtos {

    public record OllamaMessage(String role, String content) {
    }

    public record OllamaOptions(
            Double temperature,
            Double top_p,
            Integer top_k,
            Integer num_predict
    ) {
    }

    public record OllamaChatRequest(
            String model,
            List<OllamaMessage> messages,
            boolean stream,
            OllamaOptions options
    ) {
    }

    /** One line of Ollama's newline-delimited streaming response. */
    public record OllamaChatResponseChunk(
            String model,
            String created_at,
            OllamaMessage message,
            boolean done,
            String done_reason
    ) {
    }

    public record OllamaModelInfo(String name, String model, Long size) {
    }

    public record OllamaTagsResponse(List<OllamaModelInfo> models) {
    }
}
