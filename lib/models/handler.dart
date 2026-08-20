class Handler {
  final String id;
  final String name;
  final String category;
  final String description;
  final String personalityStyle;
  final String avatar;
  final String greetingMessage;

  Handler({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.personalityStyle,
    required this.avatar,
    required this.greetingMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'personality_style': personalityStyle,
        'avatar': avatar,
        'greeting_message': greetingMessage,
      };

  factory Handler.fromJson(Map<String, dynamic> json) => Handler(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        personalityStyle: json['personality_style'] as String,
        avatar: json['avatar'] as String,
        greetingMessage: json['greeting_message'] as String,
      );

  Handler copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? personalityStyle,
    String? avatar,
    String? greetingMessage,
  }) =>
      Handler(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        description: description ?? this.description,
        personalityStyle: personalityStyle ?? this.personalityStyle,
        avatar: avatar ?? this.avatar,
        greetingMessage: greetingMessage ?? this.greetingMessage,
      );
}
