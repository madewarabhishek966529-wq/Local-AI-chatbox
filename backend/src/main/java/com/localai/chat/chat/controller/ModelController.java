package com.localai.chat.chat.controller;

import com.localai.chat.config.OllamaProperties;
import com.localai.chat.ollama.OllamaService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/models")
@RequiredArgsConstructor
public class ModelController {

    private final OllamaService ollamaService;
    private final OllamaProperties ollamaProperties;

    @GetMapping
    public Map<String, Object> list() {
        List<String> models = ollamaService.listAvailableModels();
        return Map.of(
                "models", models,
                "defaultModel", ollamaProperties.defaultModel()
        );
    }
}
