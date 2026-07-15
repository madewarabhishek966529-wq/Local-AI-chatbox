package com.localai.chat.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.ollama")
public record OllamaProperties(
        String baseUrl,
        String defaultModel,
        List<String> availableModels,
        int requestTimeoutSeconds
) {
}
