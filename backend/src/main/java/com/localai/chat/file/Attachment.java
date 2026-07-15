package com.localai.chat.file;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "attachments")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Attachment {

    @Id
    private String id;

    @Indexed
    private String userId;

    private String fileName;
    private String contentType;
    private long sizeBytes;

    /** Extracted plain text, used as context when the user asks questions about the file. */
    private String extractedText;

    private Instant createdAt;
}
