import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_topic.dart';
import 'supabase_service.dart';

class LegalTopicsService {
  LegalTopicsService._();

  static final LegalTopicsService instance = LegalTopicsService._();

  final ValueNotifier<List<LegalTopic>> topicsNotifier =
      ValueNotifier<List<LegalTopic>>(<LegalTopic>[]);

  bool _initialized = false;
  bool _isFetching = false;

  Future<void> initialize() async {
    if (_initialized) {
      await refresh();
      return;
    }
    _initialized = true;
    await refresh();
  }

  List<LegalTopic> get topics => List.unmodifiable(topicsNotifier.value);

  Future<void> refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final response = await SupabaseService.client
          .from('legal_topics')
          .select()
          .order('order_index', ascending: true);

      final topics = (response as List<dynamic>)
          .map((row) => LegalTopic.fromMap(
                Map<String, dynamic>.from(row as Map),
              ))
          .where((topic) => topic.title.isNotEmpty)
          .toList();

      if (topics.isEmpty && topicsNotifier.value.isEmpty) {
        topicsNotifier.value = _fallbackTopics;
      } else {
        topicsNotifier.value = topics;
      }
    } on PostgrestException catch (error) {
      debugPrint('Supabase topics fetch failed: ${error.message}');
      if (topicsNotifier.value.isEmpty) {
        topicsNotifier.value = _fallbackTopics;
      }
      rethrow;
    } catch (error) {
      debugPrint('Unexpected error loading topics: $error');
      if (topicsNotifier.value.isEmpty) {
        topicsNotifier.value = _fallbackTopics;
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<LegalTopic> addTopic({
    required String title,
    required String description,
    String? category,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final payload = _buildPayload(
      title: title,
      description: description,
      category: category,
      imageUrl: imageUrl,
      isActive: isActive,
      orderIndex: _nextOrderIndex(),
    );

    debugPrint(
      '[topics] addTopic payload → title="$title", base64=${payload['image_base64'] != null}, iconUrl=${payload['icon_url']}',
    );

    final result = await SupabaseService.client
        .from('legal_topics')
        .insert(payload)
        .select()
        .single();

    final topic = LegalTopic.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
    debugPrint('[topics] addTopic success → id=${topic.id}');
    await refresh();
    return topic;
  }

  Future<void> updateTopic({
    required String id,
    required String title,
    required String description,
    String? category,
    String? imageUrl,
    bool? isActive,
  }) async {
    LegalTopic? existing;
    for (final topic in topicsNotifier.value) {
      if (topic.id == id) {
        existing = topic;
        break;
      }
    }
    if (existing == null) {
      throw StateError('Legal topic with id $id not found.');
    }

    final payload = _buildPayload(
      id: id,
      title: title,
      description: description,
      category: category,
      imageUrl: imageUrl,
      isActive: isActive ?? existing.isActive,
      orderIndex: existing.orderIndex,
    );

    debugPrint(
      '[topics] updateTopic(id=$id) payload → base64=${payload['image_base64'] != null}, iconUrl=${payload['icon_url']}',
    );

    await SupabaseService.client
        .from('legal_topics')
        .update(payload)
        .eq('id', id);

    await refresh();
  }

  Future<void> deleteTopic(String id) async {
    await SupabaseService.client.from('legal_topics').delete().eq('id', id);
    await refresh();
  }

  Map<String, dynamic> _buildPayload({
    String? id,
    required String title,
    required String description,
    String? category,
    String? imageUrl,
    bool? isActive,
    int? orderIndex,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedCategory = category?.trim();
    final trimmedImage = imageUrl?.trim();
    final slugSource =
        (trimmedCategory?.isNotEmpty ?? false) ? trimmedCategory! : trimmedTitle;
    final slug = _slugify(slugSource);

    final isBase64 = _isBase64(value: trimmedImage);

    final payload = <String, dynamic>{
      'name': trimmedTitle,
      'description': trimmedDescription,
      'slug': slug,
      'is_active': isActive ?? true,
      'color_hex': null,
      'icon_url': isBase64 ? null : _normalize(value: trimmedImage),
      'image_base64': isBase64 ? trimmedImage : null,
    };

    if (orderIndex != null) {
      payload['order_index'] = orderIndex;
    }

    if (id != null) {
      payload['id'] = id;
    }

    if (isBase64) {
      debugPrint(
        '[topics] payload prepared with base64 image (length=${trimmedImage?.length ?? 0})',
      );
    } else if (trimmedImage != null && trimmedImage.isNotEmpty) {
      debugPrint('[topics] payload prepared with iconUrl="$trimmedImage"');
    } else {
      debugPrint('[topics] payload prepared without image data');
    }

    return payload;
  }

  bool _isBase64({required String? value}) =>
      value != null && value.startsWith('data:image');

  String? _normalize({required String? value}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  int _nextOrderIndex() {
    if (topicsNotifier.value.isEmpty) return 1;
    return topicsNotifier.value
            .map((topic) => topic.orderIndex)
            .fold<int>(0, (prev, next) => max(prev, next)) +
        1;
  }

  String _slugify(String value) {
    final lower = value.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (RegExp(r'[\s_\-]+').hasMatch(char)) {
        if (buffer.isEmpty || buffer.toString().endsWith('-')) {
          continue;
        }
        buffer.write('-');
      }
    }
    final slug = buffer.toString();
    return slug.isEmpty ? 'topic-${DateTime.now().millisecondsSinceEpoch}' : slug;
  }

  List<LegalTopic> get _fallbackTopics => const [
        LegalTopic(
          id: 'topic-criminal',
          title: 'Criminal Law',
          description:
              'Procedures, rights, and penalties related to criminal offenses.',
          slug: 'criminal-law',
          category: 'criminal-law',
          imageUrl: 'assets/criminal.png',
          orderIndex: 1,
        ),
        LegalTopic(
          id: 'topic-civil',
          title: 'Civil Law',
          description:
              'Disputes between individuals or organizations regarding obligations and liabilities.',
          slug: 'civil-law',
          category: 'civil-law',
          imageUrl: 'assets/civil.png',
          orderIndex: 2,
        ),
        LegalTopic(
          id: 'topic-business',
          title: 'Business Law',
          description:
              'Regulations governing companies, contracts, and commercial transactions.',
          slug: 'business-law',
          category: 'business-law',
          imageUrl: 'assets/business.png',
          orderIndex: 3,
        ),
        LegalTopic(
          id: 'topic-human-rights',
          title: 'Human Rights',
          description: 'Human rights and freedoms.',
          slug: 'human-rights',
          category: 'human-rights',
          imageUrl: 'assets/gavel.png',
          orderIndex: 4,
        ),
        LegalTopic(
          id: 'topic-taxation',
          title: 'Taxation Law',
          description:
              'Guidance on tax obligations, incentives, and compliance processes.',
          slug: 'taxation-law',
          category: 'taxation-law',
          imageUrl: 'assets/taxation.png',
          orderIndex: 5,
        ),
      ];
}

