package com.localai.chat.chat.controller;

import com.localai.chat.chat.dto.ChatDtos.*;
import com.localai.chat.chat.service.ChatService;
import com.localai.chat.common.PageResponse;
import com.localai.chat.config.OllamaProperties;
import com.localai.chat.security.AppUserPrincipal;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/chat/conversations")
@RequiredArgsConstructor
public class ConversationController {

    private final ChatService chatService;
    private final OllamaProperties ollamaProperties;

    @GetMapping
    public PageResponse<ConversationDto> list(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @RequestParam(defaultValue = "false") boolean archived,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size);
        return chatService.listConversations(principal.getId(), archived, search, pageable);
    }

    @PostMapping
    public ResponseEntity<ConversationDto> create(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @RequestBody(required = false) CreateConversationRequest request
    ) {
        CreateConversationRequest safeRequest = request != null ? request : new CreateConversationRequest(null, null);
        ConversationDto dto = chatService.createConversation(principal.getId(), safeRequest, ollamaProperties.defaultModel());
        return ResponseEntity.status(HttpStatus.CREATED).body(dto);
    }

    @PatchMapping("/{id}")
    public ConversationDto rename(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String id,
            @Valid @RequestBody RenameConversationRequest request
    ) {
        return chatService.renameConversation(principal.getId(), id, request);
    }

    @PostMapping("/{id}/pin")
    public ConversationDto pin(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String id,
            @RequestParam(defaultValue = "true") boolean value
    ) {
        return chatService.setPinned(principal.getId(), id, value);
    }

    @PostMapping("/{id}/archive")
    public ConversationDto archive(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String id,
            @RequestParam(defaultValue = "true") boolean value
    ) {
        return chatService.setArchived(principal.getId(), id, value);
    }

    @PostMapping("/{id}/favorite")
    public ConversationDto favorite(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String id,
            @RequestParam(defaultValue = "true") boolean value
    ) {
        return chatService.setFavorite(principal.getId(), id, value);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String id
    ) {
        chatService.deleteConversation(principal.getId(), id);
        return ResponseEntity.noContent().build();
    }
}
