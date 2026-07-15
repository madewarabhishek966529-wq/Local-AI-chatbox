package com.localai.chat.user;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "users")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    @Id
    private String id;

    private String name;

    @Indexed(unique = true)
    private String email;

    private String passwordHash;

    private String avatarUrl;

    @Builder.Default
    private String role = "USER";

    @Builder.Default
    private String theme = "system";

    @Builder.Default
    private String language = "en";

    private Instant createdAt;

    private Instant updatedAt;
}
