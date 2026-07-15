package com.localai.chat.user;

import com.localai.chat.security.AppUserPrincipal;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;

    public record ProfileDto(String id, String name, String email, String avatarUrl, String theme, String language) {
    }

    public record UpdateProfileRequest(
            @NotBlank(message = "Name is required") String name,
            String avatarUrl,
            String theme,
            String language
    ) {
    }

    @GetMapping("/me")
    public ProfileDto me(@AuthenticationPrincipal AppUserPrincipal principal) {
        User user = principal.getUser();
        return new ProfileDto(user.getId(), user.getName(), user.getEmail(), user.getAvatarUrl(), user.getTheme(), user.getLanguage());
    }

    @PutMapping("/me")
    public ProfileDto updateMe(@AuthenticationPrincipal AppUserPrincipal principal, @RequestBody UpdateProfileRequest request) {
        User user = principal.getUser();
        user.setName(request.name());
        if (request.avatarUrl() != null) user.setAvatarUrl(request.avatarUrl());
        if (request.theme() != null) user.setTheme(request.theme());
        if (request.language() != null) user.setLanguage(request.language());
        user.setUpdatedAt(Instant.now());
        user = userRepository.save(user);
        return new ProfileDto(user.getId(), user.getName(), user.getEmail(), user.getAvatarUrl(), user.getTheme(), user.getLanguage());
    }

    /**
     * Full data export for the account — conversations/messages/settings are
     * intentionally NOT inlined here to keep this endpoint fast; wire it to
     * stream a zip from ChatService + UserSettingsRepository as a follow-up.
     */
    @GetMapping("/me/export")
    public Map<String, Object> exportData(@AuthenticationPrincipal AppUserPrincipal principal) {
        User user = principal.getUser();
        return Map.of(
                "user", new ProfileDto(user.getId(), user.getName(), user.getEmail(), user.getAvatarUrl(), user.getTheme(), user.getLanguage()),
                "exportedAt", Instant.now().toString(),
                "note", "Conversation/message export is streamed separately via GET /chat/conversations and /chat/conversations/{id}/messages"
        );
    }

    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteMe(@AuthenticationPrincipal AppUserPrincipal principal) {
        userRepository.deleteById(principal.getId());
        return ResponseEntity.noContent().build();
    }
}
