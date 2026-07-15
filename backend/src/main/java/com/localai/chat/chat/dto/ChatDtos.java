package com.localai.chat.chat.dto;

import com.localai.chat.chat.model.Message.Role;
import jakarta.validation.constraints.NotBlank;

import java.time.Instant;
import java.util.List;

public class ChatDtos {

    public record ConversationDto(
            String id,
            String title,
            String modelName,
            boolean pinned,
            boolean archived,
            boolean favorite,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record CreateConversationRequest(
            String title,
            String modelName
    ) {
    }

    public record RenameConversationRequest(
            @NotBlank(message = "Title is required") String title
    ) {
    }

    public record MessageDto(
            String id,
            String conversationId,
            Role role,
            String content,
            boolean favorite,
            List<String> attachmentIds,
            Instant createdAt
    ) {
    }

    public record SendMessageRequest(
            @NotBlank(message = "Message content is required") String content,
            List<String> attachmentIds
    ) {
    }

    public record GenerationSettings(
            Double temperature,
            Double topP,
            Integer topK,
            Integer maxTokens
    ) {
    }
}
