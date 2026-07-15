package com.localai.chat.chat.controller;

import com.localai.chat.chat.dto.ChatDtos.MessageDto;
import com.localai.chat.chat.service.ChatService;
import com.localai.chat.common.PageResponse;
import com.localai.chat.security.AppUserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class MessageController {

    private final ChatService chatService;

    @GetMapping("/chat/conversations/{conversationId}/messages")
    public PageResponse<MessageDto> history(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String conversationId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size
    ) {
        Pageable pageable = PageRequest.of(page, size);
        return chatService.listMessages(principal.getId(), conversationId, pageable);
    }

    @GetMapping("/chat/conversations/{conversationId}/messages/search")
    public PageResponse<MessageDto> search(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String conversationId,
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size);
        return chatService.searchMessages(principal.getId(), conversationId, q, pageable);
    }

    @PostMapping("/messages/{messageId}/favorite")
    public MessageDto favorite(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String messageId,
            @RequestParam(defaultValue = "true") boolean value
    ) {
        return chatService.setMessageFavorite(principal.getId(), messageId, value);
    }

    @DeleteMapping("/messages/{messageId}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @PathVariable String messageId
    ) {
        chatService.deleteMessage(principal.getId(), messageId);
        return ResponseEntity.noContent().build();
    }
}
