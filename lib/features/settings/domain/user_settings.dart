class UserSettings {
  final String defaultModel;
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final bool streamingEnabled;
  final bool markdownEnabled;
  final bool animationsEnabled;
  final String theme;
  final String language;
  final String fontSize;

  const UserSettings({
    this.defaultModel = 'llama3.1:8b',
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.maxTokens = 2048,
    this.streamingEnabled = true,
    this.markdownEnabled = true,
    this.animationsEnabled = true,
    this.theme = 'system',
    this.language = 'en',
    this.fontSize = 'medium',
  });

  UserSettings copyWith({
    String? defaultModel,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    bool? streamingEnabled,
    bool? markdownEnabled,
    bool? animationsEnabled,
    String? theme,
    String? language,
    String? fontSize,
  }) {
    return UserSettings(
      defaultModel: defaultModel ?? this.defaultModel,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      maxTokens: maxTokens ?? this.maxTokens,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      markdownEnabled: markdownEnabled ?? this.markdownEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      defaultModel: json['defaultModel'] as String? ?? 'llama3.1:8b',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      topK: (json['topK'] as num?)?.toInt() ?? 40,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 2048,
      streamingEnabled: json['streamingEnabled'] as bool? ?? true,
      markdownEnabled: json['markdownEnabled'] as bool? ?? true,
      animationsEnabled: json['animationsEnabled'] as bool? ?? true,
      theme: json['theme'] as String? ?? 'system',
      language: json['language'] as String? ?? 'en',
      fontSize: json['fontSize'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultModel': defaultModel,
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'maxTokens': maxTokens,
        'streamingEnabled': streamingEnabled,
        'markdownEnabled': markdownEnabled,
        'animationsEnabled': animationsEnabled,
        'theme': theme,
        'language': language,
        'fontSize': fontSize,
      };
}
