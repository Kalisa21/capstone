import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _kProfileImagePathKey = 'user_profile_image_path';
  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kProfileImagePathKey);
    if (path != null) {
      final f = File(path);
      if (await f.exists()) setState(() => _profileImageFile = f);
    }
  }

  Future<void> _pickProfileImage() async {
    // Desktop & web: go straight to file picker
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: 'Select profile image',
      );
      if (result == null || result.files.isEmpty) {
        _notify('No file selected');
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _notify('Invalid file');
        return;
      }
      await _saveImage(File(path));
      return;
    }

    // Mobile bottom sheet options
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery / Photos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Files'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'files') {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) {
        _notify('No file selected');
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _notify('Invalid file');
        return;
      }
      await _saveImage(File(path));
      return;
    }

    // Camera / Gallery via image_picker
    final picker = ImagePicker();
    final src = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked = await picker.pickImage(
        source: src,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) {
        _notify('No image captured');
        return;
      }
      await _saveImage(File(picked.path));
    } catch (e) {
      _notify('Failed: $e');
    }
  }

  Future<void> _saveImage(File original) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = File(
      '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    try {
      await original.copy(target.path);
    } catch (_) {
      // fallback to original if copy fails
    }
    final toStore = await target.exists() ? target : original;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileImagePathKey, toStore.path);
    if (mounted) setState(() => _profileImageFile = toStore);
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get user info from Supabase
    final user = SupabaseService.currentUser;
    final bool loggedIn = SupabaseService.isAuthenticated;
    final name =
        user?.userMetadata?['name']?.toString() ??
        user?.email?.split('@')[0] ??
        'User';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
          child: loggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              backgroundImage: _profileImageFile != null
                                  ? FileImage(_profileImageFile!)
                                  : null,
                              child: _profileImageFile == null
                                  ? Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 26,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: InkWell(
                                onTap: _pickProfileImage,
                                borderRadius: BorderRadius.circular(20),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.accent,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Admin sign-in UI removed as requested.
                    ..._buildListTileOptions(context),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        await SupabaseService.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/signin');
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'SIGN OUT',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/signin'),
                    child: const Text('LOG IN OR SIGN UP'),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildListTileOptions(BuildContext context) {
    final items = [
      {
        'title': 'Privacy and safety',
        'body':
            'Manage your data, security, and visibility settings for a safer experience.',
      },
      {
        'title': 'Permissions',
        'body':
            'Control app permissions such as notifications, camera, and storage.',
      },
      {
        'title': 'Invite friends',
        'body':
            'Share the app with friends and colleagues to collaborate and learn together.',
      },
      {
        'title': 'Rate us',
        'body':
            'Tell us what you think. Your feedback helps improve the experience.',
      },
      {
        'title': 'Manage profile',
        'body':
            'Update your personal info, change password, and customize preferences.',
      },
    ];

    final theme = Theme.of(context).copyWith(
      dividerColor: Colors.transparent,
      splashColor: Colors.white12,
      highlightColor: Colors.white10,
    );

    return items
        .map(
          (e) => Theme(
            data: theme,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                collapsedIconColor: Colors.white70,
                iconColor: Colors.white70,
                textColor: Colors.white,
                collapsedTextColor: Colors.white70,
                title: Text(
                  e['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text(
                    e['body'] as String,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }
}
