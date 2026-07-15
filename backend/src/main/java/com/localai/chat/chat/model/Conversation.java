package com.localai.chat.chat.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "conversations")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Conversation {

    @Id
    private String id;

    @Indexed
    private String userId;

    private String title;

    @Builder.Default
    private String modelName = "llama3.1:8b";

    @Builder.Default
    private boolean pinned = false;

    @Builder.Default
    private boolean archived = false;

    @Builder.Default
    private boolean favorite = false;

    /** Rolling summary of older messages once the context window is exceeded. */
    private String memorySummary;

    private Instant createdAt;

    private Instant updatedAt;
}
