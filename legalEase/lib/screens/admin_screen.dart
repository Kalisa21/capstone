import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_topic.dart';
import '../routes.dart';
import '../services/admin_analytics_service.dart';
import '../services/legal_topics_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const String _topicsImageBucket = 'legal-topic-images';
  int _selectedIndex = 0;
  late final ValueNotifier<List<LegalTopic>> _topicsNotifier;
  List<LegalTopic> _topics = const [];
  final TextEditingController _topicSearchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _topicsNotifier = LegalTopicsService.instance.topicsNotifier;
    _topics = _topicsNotifier.value;
    _topicsNotifier.addListener(_handleTopicsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAdminAccess());
  }

  void _handleTopicsChanged() {
    if (!mounted) return;
    setState(() {
      _topics = _topicsNotifier.value;
    });
  }

  List<LegalTopic> _applyTopicFilters(List<LegalTopic> topics) {
    final query = _topicSearchController.text.trim().toLowerCase();
    return topics.where((topic) {
      final matchesQuery =
          query.isEmpty ||
          topic.title.toLowerCase().contains(query) ||
          topic.categoryLabel.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query);

      final matchesStatus = switch (_statusFilter) {
        'active' => topic.isActive,
        'inactive' => !topic.isActive,
        _ => true,
      };

      return matchesQuery && matchesStatus;
    }).toList();
  }

  Future<void> _ensureAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.home);
      return;
    }

    try {
      final result = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      final role = (result?['role'] as String?)?.toLowerCase();
      if (!mounted) return;
      if (role != 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required. Redirecting to user view.'),
          ),
        );
        Navigator.of(context).pushReplacementNamed(Routes.home);
      }
    } catch (error) {
      debugPrint('Failed to verify admin role: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify admin access. Returning home.'),
        ),
      );
      Navigator.of(context).pushReplacementNamed(Routes.home);
    }
  }

  @override
  void dispose() {
    _topicsNotifier.removeListener(_handleTopicsChanged);
    _topicSearchController.dispose();
    super.dispose();
  }

  void _showProfileScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ProfileScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _openTopicDialog({LegalTopic? topic}) async {
    final topicsService = LegalTopicsService.instance;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: topic?.title ?? '');
    final categoryController = TextEditingController(
      text: topic?.categoryLabel ?? '',
    );
    final descriptionController = TextEditingController(
      text: topic?.description ?? '',
    );
    final initialImage = topic?.imageUrl ?? '';
    final bool initialIsBase64 = initialImage.startsWith('data:image');
    final imageController = TextEditingController(
      text: initialIsBase64 ? '' : initialImage,
    );
    String? uploadedImageUrl = initialIsBase64 || initialImage.isEmpty
        ? null
        : initialImage;
    String? legacyBase64Image = initialIsBase64 ? initialImage : null;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final baseTheme = Theme.of(dialogContext);
        final dialogTheme = baseTheme.copyWith(
          dialogBackgroundColor: Colors.black87,
          textTheme: baseTheme.textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: Colors.white12,
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.lightBlueAccent),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        return Theme(
          data: dialogTheme,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            topic == null
                                ? Icons.add_circle_outline
                                : Icons.edit_outlined,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topic == null
                                    ? 'Add Legal Topic'
                                    : 'Edit Legal Topic',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                topic == null
                                    ? 'Create a new topic for the knowledge base'
                                    : 'Update topic information and settings',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: StatefulBuilder(
                      builder: (context, setModalState) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Basic Information Section
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Basic Information',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: titleController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Title',
                                    hintText: 'e.g. Land Lease Agreements',
                                    prefixIcon: const Icon(
                                      Icons.title,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Title is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: categoryController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    hintText: 'e.g. property, criminal, civil',
                                    prefixIcon: const Icon(
                                      Icons.category_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Category is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: descriptionController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    hintText:
                                        'Short summary that will appear on the user dashboard. This helps users understand what this topic covers.',
                                    prefixIcon: const Icon(
                                      Icons.description_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                  maxLines: 4,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Description is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                // Cover Image Section
                                Row(
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 18,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cover Image',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    if ((uploadedImageUrl != null &&
                                            uploadedImageUrl!.isNotEmpty) ||
                                        legacyBase64Image != null ||
                                        imageController.text.trim().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green.shade300,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Image set',
                                              style: TextStyle(
                                                color: Colors.green.shade300,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _TopicImagePreview(
                                  uploadedImageUrl: uploadedImageUrl,
                                  manualImage:
                                      legacyBase64Image ??
                                      imageController.text.trim(),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: const Text('Upload image'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final uploadResult =
                                        await _pickAndUploadImage(
                                          onUploadStarted: () {
                                            if (!context.mounted) return;
                                            setModalState(() {
                                              legacyBase64Image = null;
                                            });
                                          },
                                        );
                                    if (!context.mounted ||
                                        uploadResult == null) {
                                      return;
                                    }
                                    setModalState(() {
                                      uploadedImageUrl = uploadResult;
                                      legacyBase64Image = null;
                                      imageController.clear();
                                    });
                                  },
                                ),
                                if ((uploadedImageUrl != null &&
                                        uploadedImageUrl!.isNotEmpty) ||
                                    legacyBase64Image != null ||
                                    imageController.text.trim().isNotEmpty)
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Clear'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(
                                            color: Colors.redAccent,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          if (!context.mounted) return;
                                          setModalState(() {
                                            uploadedImageUrl = null;
                                            legacyBase64Image = null;
                                            imageController.clear();
                                          });
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Preview'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              Colors.lightBlueAccent,
                                          side: const BorderSide(
                                            color: Colors.lightBlueAccent,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final candidate =
                                              (uploadedImageUrl ??
                                                      legacyBase64Image ??
                                                      imageController.text)
                                                  .trim();
                                          if (candidate.isEmpty) return;

                                          final previewResult =
                                              await Navigator.of(
                                                context,
                                              ).push<String?>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      _TopicImagePreviewPage(
                                                        imageData: candidate,
                                                        title: titleController
                                                            .text
                                                            .trim(),
                                                      ),
                                                ),
                                              );
                                          if (!context.mounted ||
                                              previewResult == null) {
                                            return;
                                          }

                                          setModalState(() {
                                            if (previewResult.startsWith(
                                              'data:image',
                                            )) {
                                              legacyBase64Image = previewResult;
                                              uploadedImageUrl = null;
                                              imageController.clear();
                                            } else {
                                              uploadedImageUrl = previewResult;
                                              legacyBase64Image = null;
                                              imageController.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                // Manual URL/Asset Section
                                Row(
                                  children: [
                                    Icon(
                                      Icons.link_outlined,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Or enter image URL / asset path',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: imageController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Image URL or asset (optional)',
                                    hintText: 'assets/gavel.png or https://...',
                                    prefixIcon: const Icon(
                                      Icons.link,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  onChanged: (_) {
                                    if (!context.mounted) return;
                                    setModalState(() {
                                      uploadedImageUrl = null;
                                      legacyBase64Image = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          },
                          icon: Icon(
                            topic == null ? Icons.add_circle : Icons.save,
                            size: 20,
                          ),
                          label: Text(
                            topic == null ? 'Add Topic' : 'Save Changes',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldSave == true) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        titleController.dispose();
        categoryController.dispose();
        descriptionController.dispose();
        imageController.dispose();
        return;
      }

      final title = titleController.text;
      final category = categoryController.text;
      final description = descriptionController.text;
      final imageUrl =
          (uploadedImageUrl ?? legacyBase64Image ?? imageController.text)
              .trim();
      debugPrint(
        '[topics-dialog] Submitting topic ${topic?.id ?? '(new)'} → imageSource=${uploadedImageUrl != null ? 'storage-url' : (legacyBase64Image != null ? 'base64(${legacyBase64Image!.length} chars)' : (imageUrl.isEmpty ? 'none' : imageUrl))}',
      );

      try {
        if (topic == null) {
          await topicsService.addTopic(
            title: title,
            category: category,
            description: description,
            imageUrl: imageUrl,
            isActive: true,
          );
          _showSnackBar('Legal topic added');
        } else {
          await topicsService.updateTopic(
            id: topic.id,
            title: title,
            category: category,
            description: description,
            imageUrl: imageUrl,
            isActive: topic.isActive,
          );
          _showSnackBar('Legal topic updated');
        }
      } on PostgrestException catch (error) {
        _showErrorSnack(error.message);
      } catch (error) {
        _showErrorSnack('Failed to save legal topic. Please try again.');
      }
    }

    titleController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    imageController.dispose();
  }

  Future<void> _confirmDeleteTopic(LegalTopic topic) async {
    final topicsService = LegalTopicsService.instance;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete topic'),
        content: Text(
          'Are you sure you want to delete "${topic.title}"? This will remove it from user dashboards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await Future<void>.delayed(Duration.zero);
      try {
        await topicsService.deleteTopic(topic.id);
        _showSnackBar('Legal topic deleted');
      } on PostgrestException catch (error) {
        _showErrorSnack(error.message);
      } catch (error) {
        _showErrorSnack('Failed to delete legal topic.');
      }
    }
  }

  Future<String?> _pickAndUploadImage({VoidCallback? onUploadStarted}) async {
    try {
      final user = SupabaseService.currentUser;
      debugPrint(
        '[topics-upload] Starting upload → bucket=$_topicsImageBucket user=${user?.id ?? 'none'}',
      );
      String? profileRole;
      if (user != null) {
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('role')
              .eq('user_id', user.id)
              .maybeSingle();
          profileRole = profile?['role']?.toString();
        } catch (profileError) {
          debugPrint(
            '[topics-upload] Failed to load profile role for ${user.id}: $profileError',
          );
        }
      }
      debugPrint('[topics-upload] profileRole=$profileRole');

      Uint8List? bytes;
      String extension = 'png';
      String originalName = 'upload.png';

      if (kIsWeb ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final file = result.files.first;
        originalName = file.name;
        extension = (file.extension ?? 'png').toLowerCase();
        bytes =
            file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) return null;
        originalName = picked.name;
        extension = picked.name.split('.').last.toLowerCase();
        bytes = await picked.readAsBytes();
      }

      if (bytes == null) {
        _showErrorSnack('Unable to read image bytes.');
        return null;
      }

      debugPrint(
        '[topics-upload] File picked name="$originalName" size=${bytes.length} ext=$extension',
      );

      onUploadStarted?.call();

      final cleanedExt =
          extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isEmpty
          ? 'png'
          : extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final randomSuffix = Random().nextInt(0x3fffffff);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}-$randomSuffix.$cleanedExt';
      final path = 'topics/$fileName';

      final storageBucket = SupabaseService.client.storage.from(
        _topicsImageBucket,
      );

      await storageBucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$cleanedExt',
          upsert: true,
        ),
      );

      final publicUrl = storageBucket.getPublicUrl(path);
      debugPrint(
        '[topics-dialog] Uploaded image "$originalName" to "$path" (${bytes.length} bytes)',
      );
      return publicUrl;
    } on StorageException catch (error) {
      debugPrint(
        '[topics-upload] StorageException status=${error.statusCode} message=${error.message} error=$error',
      );
      _showErrorSnack('Failed to upload image: ${error.message}');
      return null;
    } catch (error) {
      debugPrint('[topics-upload] Unexpected upload error: $error');
      _showErrorSnack('Failed to upload image: $error');
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: AdminAnalyticsService.instance.getAdminStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? AdminStats.empty();
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WELCOME BACK',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => setState(() {}),
                          tooltip: 'Refresh',
                        ),
                      GestureDetector(
                        onTap: _showProfileScreen,
                        child: const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _MetricCard(
                    title: 'Total Users',
                    value: '${stats.totalUsers}',
                    subtitle: '${stats.newSignups} new this week',
                    color: Colors.blue,
                  ),
                  _MetricCard(
                    title: 'Active Users',
                    value: '${stats.activeUsers}',
                    subtitle: 'Last 7 days',
                    color: Colors.green,
                  ),
                  _MetricCard(
                    title: 'Total Queries',
                    value: '${stats.totalQueries}',
                    subtitle: '${stats.queriesLast7Days} in last 7 days',
                    color: Colors.red,
                  ),
                  _MetricCard(
                    title: 'Response Time',
                    value: '${stats.averageResponseTime.toStringAsFixed(1)}s',
                    subtitle: 'Average response time',
                    color: Colors.orange,
                  ),
                  _MetricCard(
                    title: 'Total Topics',
                    value: '${stats.totalTopics}',
                    subtitle: '${stats.activeTopics} active',
                    color: Colors.purple,
                  ),
                  _MetricCard(
                    title: 'Queries (30d)',
                    value: '${stats.queriesLast30Days}',
                    subtitle: 'Last 30 days',
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'POPULAR TOPICS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stats.popularTopics.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No topic data yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                ...stats.popularTopics.map((topic) => _AnalyticsItem(
                      icon: Icons.gavel,
                      title: topic['name'] as String? ?? 'Unknown',
                      subtitle: '${topic['count']} interactions',
                      progress: (topic['count'] as int) / 
                          (stats.popularTopics.first['count'] as int? ?? 1),
                      color: Colors.blue,
                    )),
              const SizedBox(height: 24),
              _AnalyticsChartCard(
                title: 'Model performance over time',
                trailing: _PeriodDropdown(),
                height: 220,
                child: _LineSalesChart(),
              ),
              const SizedBox(height: 16),
              _AnalyticsChartCard(
                title: 'Time spent on different legal topics',
                trailing: _PeriodDropdown(),
                height: 260,
                child: Column(
                  children: [
                    Expanded(child: _StackedBarProductChart()),
                    SizedBox(height: 6),
                    _ChartLegend(
                      items: [
                        _LegendItem('criminal', Colors.blue),
                        _LegendItem('taxation', Colors.lightBlue),
                        _LegendItem('business', Colors.orange),
                        _LegendItem('human rights', Colors.amber),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKnowledgeTab(BuildContext context, List<LegalTopic> topics) {
    final filteredTopics = _applyTopicFilters(topics);
    final hasSearch = _topicSearchController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEGAL TOPICS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage Knowledge Base',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: _topicSearchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                suffixIcon: hasSearch
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.black45),
                        onPressed: () {
                          _topicSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                hintText: 'Search by title, category, or description',
                hintStyle: const TextStyle(color: Colors.black45),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in const [
                ('all', 'All'),
                ('active', 'Active'),
                ('inactive', 'Inactive'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _statusFilter == entry.$1,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _statusFilter = entry.$1;
                    });
                  },
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _statusFilter == entry.$1
                        ? AppTheme.primary
                        : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: Colors.white.withOpacity(0.12),
                  side: BorderSide(
                    color: _statusFilter == entry.$1
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filteredTopics.isEmpty
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 16),
                        Text(
                          hasSearch
                              ? 'No topics match your filters.\nTry adjusting the search or status.'
                              : 'No legal topics yet.\nAdd your first topic to populate the user dashboard.',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (hasSearch) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset filters'),
                            onPressed: () {
                              _topicSearchController.clear();
                              setState(() {
                                _statusFilter = 'all';
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredTopics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    padding: const EdgeInsets.only(bottom: 12),
                    itemBuilder: (context, index) {
                      final topic = filteredTopics[index];
                      return _TopicAdminCard(
                        topic: topic,
                        onEdit: () => _openTopicDialog(topic: topic),
                        onDelete: () => _confirmDeleteTopic(topic),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openTopicDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add legal topic'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget tabContent = _selectedIndex == 0
        ? _buildDashboardTab(context)
        : _buildKnowledgeTab(context, _topics);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(child: tabContent),
            // Custom Bottom Navigation (now two items)
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TopNavItem(
                      icon: Icons.home,
                      label: 'Home',
                      isSelected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _TopNavItem(
                      icon: Icons.lightbulb_outline,
                      label: 'Knowledge',
                      isSelected: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicImagePreviewPage extends StatelessWidget {
  final String imageData;
  final String title;

  const _TopicImagePreviewPage({required this.imageData, required this.title});

  bool get _isBase64 => imageData.startsWith('data:image');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Preview Image',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildImage(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _isBase64
                        ? 'Embedded data URI (${imageData.length} chars)'
                        : imageData,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(imageData),
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Use this image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(null),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isBase64) {
      try {
        final bytes = base64Decode(imageData.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return _errorPlaceholder();
      }
    }

    if (imageData.startsWith('http')) {
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _errorPlaceholder(),
      );
    }

    return Image.asset(
      imageData,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.white12,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.redAccent,
        size: 48,
      ),
    );
  }
}

class _TopicAdminCard extends StatelessWidget {
  final LegalTopic topic;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TopicAdminCard({
    required this.topic,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = topic.isActive ? 'Active' : 'Inactive';
    final statusColor = topic.isActive ? Colors.green : Colors.redAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopicCardImage(topic: topic),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            topic.isActive
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        topic.categoryLabel.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (topic.imageUrl != null &&
                        topic.imageUrl!.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link,
                              size: 16,
                              color: Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                topic.imageUrl!,
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  topic.description,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.5,
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCardImage extends StatelessWidget {
  final LegalTopic topic;

  const _TopicCardImage({required this.topic});

  static const Map<String, String> _categoryCoverAssets = {
    'criminal law': 'assets/criminal.png',
    'civil law': 'assets/civil.png',
    'business law': 'assets/business.png',
    'business': 'assets/business.png',
    'tax law': 'assets/taxation.png',
    'taxation': 'assets/taxation.png',
    'personal injury': 'assets/pi.png',
    'pi': 'assets/pi.png',
    'general': 'assets/gavel.png',
  };

  @override
  Widget build(BuildContext context) {
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(20));
    final hasBase64 = topic.imageBase64?.trim().isNotEmpty ?? false;
    final base64Candidate = hasBase64 ? topic.imageBase64!.trim() : null;
    final urlCandidate = topic.imageUrl?.trim().isNotEmpty ?? false
        ? topic.imageUrl!.trim()
        : null;
    final candidate = base64Candidate ?? urlCandidate;

    Widget child;

    if (candidate != null && candidate.isNotEmpty) {
      if (candidate.startsWith('data:image')) {
        try {
          final bytes = base64Decode(candidate.split(',').last);
          child = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageFallback(),
          );
        } catch (_) {
          child = _imageFallback();
        }
      } else if (candidate.startsWith('http')) {
        child = Image.network(
          candidate,
          fit: BoxFit.cover,
          loadingBuilder: (context, image, loadingProgress) {
            if (loadingProgress == null) return image;
            return _imageFallback();
          },
          errorBuilder: (_, error, ___) {
            debugPrint(
              '[topics-card] Failed to load image "$candidate": $error',
            );
            return _imageFallback();
          },
        );
      } else {
        child = Image.asset(
          candidate,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageFallback(),
        );
      }
    } else {
      final fallbackAsset =
          _categoryCoverAssets[topic.categoryLabel.toLowerCase()] ??
          _categoryCoverAssets['general'];
      child = _imageFallback(assetPath: fallbackAsset);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    );
  }

  Widget _imageFallback({String? assetPath}) {
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientFallback(),
      );
    }
    return _gradientFallback();
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.9),
            AppTheme.primary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.photo_size_select_actual_outlined,
            color: Colors.white70,
            size: 34,
          ),
          SizedBox(height: 8),
          Text(
            'No cover image',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TopicImagePreview extends StatelessWidget {
  final String? uploadedImageUrl;
  final String? manualImage;

  const _TopicImagePreview({
    required this.uploadedImageUrl,
    required this.manualImage,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    Widget child = _placeholder(borderRadius);

    final candidate = (uploadedImageUrl ?? manualImage)?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      if (candidate.startsWith('data:image')) {
        final bytes = _decodeBase64(candidate);
        if (bytes != null) {
          child = ClipRRect(
            borderRadius: borderRadius,
            child: Image.memory(
              bytes,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _errorTile(borderRadius),
            ),
          );
        }
      } else if (candidate.startsWith('http')) {
        child = ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            candidate,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _errorTile(borderRadius),
          ),
        );
      } else {
        child = ClipRRect(
          borderRadius: borderRadius,
          child: Image.asset(
            candidate,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _errorTile(borderRadius),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  Uint8List? _decodeBase64(String dataUri) {
    try {
      final segments = dataUri.split(',');
      final payload = segments.length > 1 ? segments.last : dataUri;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  Widget _placeholder(BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: Colors.white.withOpacity(0.08),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.photo_size_select_actual_outlined,
              color: Colors.white54,
            ),
            SizedBox(height: 6),
            Text(
              'No image selected',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorTile(BorderRadius radius) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: Colors.redAccent.withOpacity(0.15),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image_outlined, color: Colors.redAccent),
            SizedBox(height: 6),
            Text(
              'Unable to load image',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary, // keep consistent with home screen
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  // Make Upgrade tappable and navigate to HomeScreen
                  InkWell(
                    onTap: () async {
                      // Sign out then go to sign-in screen
                      try {
                        await SupabaseService.client.auth.signOut();
                      } catch (e) {
                        debugPrint('Sign out error: $e');
                      }
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/signin',
                          (route) => false,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.diamond, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'SIGN OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 60),

              // Profile Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              SizedBox(height: 20),

              // Username
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '@willyk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.verified, color: Colors.grey, size: 20),
                ],
              ),
              SizedBox(height: 40),

              // Cards Section
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.phone_iphone,
                            color: Colors.blue,
                            size: 30,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Your plan',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.people, color: Colors.blue, size: 30),
                          SizedBox(height: 12),
                          Text(
                            'Referrals',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Invite & earn\nrewards',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),

              // Menu Items
              Expanded(
                child: Column(
                  children: [
                    _ProfileMenuItem(
                      icon: Icons.help_outline,
                      title: 'Help',
                      iconColor: Colors.red,
                    ),
                    _ProfileMenuItem(
                      icon: Icons.person_outline,
                      title: 'Account',
                      iconColor: Colors.blue,
                    ),
                    _ProfileMenuItem(
                      icon: Icons.description_outlined,
                      title: 'Documents & statements',
                      iconColor: Colors.grey,
                    ),
                    _ProfileMenuItem(
                      icon: Icons.lightbulb_outline,
                      title: 'Learn',
                      iconColor: Colors.orange,
                    ),
                    _ProfileMenuItem(
                      icon: Icons.inbox_outlined,
                      title: 'Inbox',
                      iconColor: Colors.blue,
                      hasNotification: true,
                      notificationCount: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final bool hasNotification;
  final int notificationCount;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.hasNotification = false,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (hasNotification)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  notificationCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green : Colors.grey,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final Color color;

  const _AnalyticsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final double height;
  const _AnalyticsChartCard({
    required this.title,
    required this.child,
    this.trailing,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // light card like attachment
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
          SizedBox(width: 6),
          Text('Monthly', style: TextStyle(color: Colors.black87)),
          SizedBox(width: 4),
          Icon(Icons.expand_more, size: 18, color: Colors.black54),
        ],
      ),
    );
  }
}

class _LineSalesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      const FlSpot(0, 6.2),
      const FlSpot(1, 5.8),
      const FlSpot(2, 7.8),
      const FlSpot(3, 5.4),
      const FlSpot(4, 6.0),
      const FlSpot(5, 6.1),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 8.5,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.black12, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (v, _) => Text(
                v == 0 ? '0' : '${v.toInt()}k',
                style: const TextStyle(color: Colors.black45, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (v < 0 || v > 5) return const SizedBox.shrink();
                return Text(
                  months[v.toInt()],
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: Colors.deepOrange,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepOrange.withOpacity(0.35),
                  Colors.deepOrange.withOpacity(0.05),
                ],
              ),
            ),
            dotData: FlDotData(show: false),
            spots: spots,
          ),
        ],
      ),
    );
  }
}

class _StackedBarProductChart extends StatelessWidget {
  const _StackedBarProductChart();

  @override
  Widget build(BuildContext context) {
    // Values per month for 4 categories (Food/Drink/Snack/Dessert)
    final data = [
      [2500.0, 1800.0, 900.0, 1200.0], // Jan
      [1800.0, 1500.0, 800.0, 1400.0], // Feb
      [3000.0, 2000.0, 900.0, 2100.0], // Mar
      [1200.0, 1000.0, 600.0, 900.0], // Apr
      [1600.0, 1700.0, 1100.0, 1500.0], // May
      [2200.0, 1600.0, 700.0, 1500.0], // Jun
    ];
    const colors = [Colors.blue, Colors.lightBlue, Colors.orange, Colors.amber];

    List<BarChartGroupData> groups = [];
    for (int i = 0; i < data.length; i++) {
      double start = 0;
      final stacks = <BarChartRodStackItem>[];
      for (int j = 0; j < data[i].length; j++) {
        final end = start + data[i][j];
        stacks.add(BarChartRodStackItem(start, end, colors[j]));
        start = end;
      }
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: start,
              width: 16,
              rodStackItems: stacks,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 8500,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Colors.black12, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2000,
              getTitlesWidget: (v, _) => Text(
                v == 0 ? '0' : '${(v / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(color: Colors.black45, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (v < 0 || v > 5) return const SizedBox.shrink();
                return Text(
                  months[v.toInt()],
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final List<_LegendItem> items;
  const _ChartLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: items
          .map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}
