package com.localai.chat.chat.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import java.util.Map;

@Controller
@RequiredArgsConstructor
public class TypingController {

    private final SimpMessagingTemplate messagingTemplate;

    /** Client sends to /app/conversations/{id}/typing, subscribers listen on /topic/conversations/{id}/typing. */
    @MessageMapping("/conversations/{conversationId}/typing")
    public void typing(@DestinationVariable String conversationId, Map<String, Object> payload) {
        messagingTemplate.convertAndSend("/topic/conversations/" + conversationId + "/typing", payload);
    }
}
