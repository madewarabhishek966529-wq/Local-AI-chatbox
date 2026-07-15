package com.localai.chat.chat.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "messages")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Message {

    public enum Role { USER, ASSISTANT, SYSTEM }

    @Id
    private String id;

    @Indexed
    private String conversationId;

    @Indexed
    private String userId;

    private Role role;

    private String content;

    @Builder.Default
    private boolean favorite = false;

    /** IDs of attachments (uploaded files) referenced by this message, if any. */
    private java.util.List<String> attachmentIds;

    private Instant createdAt;
}
