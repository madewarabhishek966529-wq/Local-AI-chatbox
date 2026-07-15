package com.localai.chat.settings;

import com.localai.chat.security.AppUserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/settings")
@RequiredArgsConstructor
public class SettingsController {

    private final UserSettingsRepository settingsRepository;

    @GetMapping
    public UserSettings get(@AuthenticationPrincipal AppUserPrincipal principal) {
        return settingsRepository.findByUserId(principal.getId())
                .orElseGet(() -> UserSettings.builder().userId(principal.getId()).build());
    }

    @PutMapping
    public UserSettings update(@AuthenticationPrincipal AppUserPrincipal principal, @RequestBody UserSettings incoming) {
        UserSettings existing = settingsRepository.findByUserId(principal.getId())
                .orElseGet(() -> UserSettings.builder().userId(principal.getId()).build());

        existing.setDefaultModel(incoming.getDefaultModel());
        existing.setTemperature(incoming.getTemperature());
        existing.setTopP(incoming.getTopP());
        existing.setTopK(incoming.getTopK());
        existing.setMaxTokens(incoming.getMaxTokens());
        existing.setStreamingEnabled(incoming.isStreamingEnabled());
        existing.setMarkdownEnabled(incoming.isMarkdownEnabled());
        existing.setAnimationsEnabled(incoming.isAnimationsEnabled());
        existing.setTheme(incoming.getTheme());
        existing.setLanguage(incoming.getLanguage());
        existing.setFontSize(incoming.getFontSize());

        return settingsRepository.save(existing);
    }
}
