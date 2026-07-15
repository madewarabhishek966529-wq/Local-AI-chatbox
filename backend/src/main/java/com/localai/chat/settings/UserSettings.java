package com.localai.chat.settings;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "settings")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserSettings {

    @Id
    private String id;

    @Indexed(unique = true)
    private String userId;

    @Builder.Default private String defaultModel = "llama3.1:8b";
    @Builder.Default private double temperature = 0.7;
    @Builder.Default private double topP = 0.9;
    @Builder.Default private int topK = 40;
    @Builder.Default private int maxTokens = 2048;

    @Builder.Default private boolean streamingEnabled = true;
    @Builder.Default private boolean markdownEnabled = true;
    @Builder.Default private boolean animationsEnabled = true;

    @Builder.Default private String theme = "system"; // light | dark | system
    @Builder.Default private String language = "en";
    @Builder.Default private String fontSize = "medium"; // small | medium | large
}
