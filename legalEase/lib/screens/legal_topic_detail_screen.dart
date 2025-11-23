import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/legal_topic.dart';
import 'dart:convert';

class LegalTopicDetailScreen extends StatelessWidget {
  final LegalTopic topic;

  const LegalTopicDetailScreen({super.key, required this.topic});

  String? _getImageUrl(LegalTopic topic) {
    if (topic.imageBase64 != null &&
        topic.imageBase64!.startsWith('data:image')) {
      return topic.imageBase64;
    }
    return topic.imageUrl;
  }

  Widget _buildCoverImage(String? imageUrl, String? imageBase64) {
    final borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(32),
    );

    if (imageBase64 != null && imageBase64.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageBase64.split(',').last);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackCover(borderRadius),
          ),
        );
      } catch (_) {
        return _buildFallbackCover(borderRadius);
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            imageUrl,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackCover(borderRadius),
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.asset(
            imageUrl,
            height: 280,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackCover(borderRadius),
          ),
        );
      }
    }

    return _buildFallbackCover(borderRadius);
  }

  Widget _buildFallbackCover(BorderRadius borderRadius) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.9),
            AppTheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel,
              size: 64,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(height: 16),
            Text(
              topic.title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl(topic);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: CustomScrollView(
        slivers: [
          // App Bar with cover image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primary,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverImage(imageUrl, topic.imageBase64),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                topic.categoryLabel.toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          topic.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Text(
                          topic.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87.withOpacity(0.8),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Divider
                        Divider(color: Colors.grey.shade200, thickness: 1),
                        const SizedBox(height: 24),
                        // Topic details section
                        Row(
                          children: [
                            Expanded(
                              child: _DetailCard(
                                icon: Icons.check_circle_outline,
                                title: 'Status',
                                value: topic.isActive ? 'Active' : 'Inactive',
                                color: topic.isActive
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DetailCard(
                                icon: Icons.label_outline,
                                title: 'Category',
                                value: topic.categoryLabel,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Additional content placeholder
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Topic Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This legal topic is part of the knowledge base. '
                                'Users can explore this topic to learn more about '
                                'legal matters related to ${topic.categoryLabel.toLowerCase()}.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87.withOpacity(0.7),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
