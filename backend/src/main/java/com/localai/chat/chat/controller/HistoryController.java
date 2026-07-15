package com.localai.chat.chat.controller;

import com.localai.chat.chat.dto.ChatDtos.ConversationDto;
import com.localai.chat.chat.service.ChatService;
import com.localai.chat.common.PageResponse;
import com.localai.chat.security.AppUserPrincipal;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Alias for GET /chat/conversations. Kept as a separate, obviously-named
 * route since chat history browsing is a first-class flow in the client.
 */
@RestController
@RequestMapping("/history")
@RequiredArgsConstructor
public class HistoryController {

    private final ChatService chatService;

    @GetMapping
    public PageResponse<ConversationDto> history(
            @AuthenticationPrincipal AppUserPrincipal principal,
            @RequestParam(defaultValue = "false") boolean archived,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size);
        return chatService.listConversations(principal.getId(), archived, search, pageable);
    }
}
