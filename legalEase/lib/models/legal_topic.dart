class LegalTopic {
  final String id;
  final String title;
  final String description;
  final String slug;
  final bool isActive;
  final int orderIndex;
  final String? category;
  final String? imageUrl;
  final String? colorHex;
  final String? imageBase64;

  const LegalTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.slug,
    this.isActive = true,
    this.orderIndex = 0,
    this.category,
    this.imageUrl,
    this.colorHex,
    this.imageBase64,
  });

  String get categoryLabel {
    final source = category ?? slug;
    if (source.isEmpty) return 'General';
    return source
        .split(RegExp(r'[_\-\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            segment[0].toUpperCase() + segment.substring(1).toLowerCase())
        .join(' ');
  }

  LegalTopic copyWith({
    String? id,
    String? title,
    String? description,
    String? slug,
    bool? isActive,
    int? orderIndex,
    String? category,
    String? imageUrl,
    String? colorHex,
  }) {
    return LegalTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      isActive: isActive ?? this.isActive,
      orderIndex: orderIndex ?? this.orderIndex,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      colorHex: colorHex ?? this.colorHex,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }

  String? get effectiveImage =>
      imageBase64?.isNotEmpty == true ? imageBase64 : imageUrl;

  factory LegalTopic.fromMap(Map<String, dynamic> map) {
    return LegalTopic(
      id: map['id']?.toString() ?? '',
      title: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      isActive: map['is_active'] != false,
      orderIndex: map['order_index'] is int
          ? map['order_index'] as int
          : int.tryParse(map['order_index']?.toString() ?? '') ?? 0,
      category: map['category']?.toString() ??
          map['slug']?.toString() ??
          map['name']?.toString(),
      imageUrl: map['icon_url']?.toString(),
      colorHex: map['color_hex']?.toString(),
      imageBase64: map['image_base64']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': title,
      'description': description,
      'slug': slug,
      'is_active': isActive,
      'order_index': orderIndex,
      'category': category,
      'icon_url': imageUrl,
      'color_hex': colorHex,
      'image_base64': imageBase64,
    };
  }
}
