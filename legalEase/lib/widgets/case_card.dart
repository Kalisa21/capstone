import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class CaseCard extends StatelessWidget {
  final String? imagePath;
  final String? title;
  final VoidCallback? onTap;

  const CaseCard({super.key, this.imagePath, this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final _ImageDisplay imageDisplay = _resolveImage(imagePath);
    final bool hasImage = imageDisplay.hasImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageDisplay.widget,
              if (title != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: hasImage
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black54,
                              ],
                            )
                          : null,
                      color:
                          hasImage ? null : Colors.white.withOpacity(0.92),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 6.0,
                    ),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: hasImage ? Colors.white : Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _ImageDisplay _resolveImage(String? path) {
    if (path == null || path.trim().isEmpty) {
      return const _ImageDisplay(_placeholderWidget, false);
    }

    final trimmed = path.trim();

    if (trimmed.startsWith('data:image')) {
      final bytes = _decodeBase64(trimmed);
      if (bytes != null) {
        return _ImageDisplay(
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholderWidget,
          ),
          true,
        );
      }
      return const _ImageDisplay(_placeholderWidget, false);
    }

    if (trimmed.startsWith('http')) {
      return _ImageDisplay(
        Image.network(
          trimmed,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderWidget,
        ),
        true,
      );
    }

    return _ImageDisplay(
      Image.asset(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderWidget,
      ),
      true,
    );
  }

  Uint8List? _decodeBase64(String dataUri) {
    try {
      final payload = dataUri.split(',').last;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  static const Widget _placeholderWidget = ColoredBox(
    color: Color(0xFFEAEAEA),
    child: Center(
      child: Icon(
        Icons.gavel,
        color: Colors.black54,
        size: 32,
      ),
    ),
  );
}

/// Simple fullscreen topic overlay
class TopicOverlay {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? imagePath,
    String? description,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildOverlayImage(imagePath),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description ??
                        'Introductory information about $title will appear here. Add a description in the admin panel to personalise this topic.',
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildOverlayImage(String? path) {
    if (path == null || path.isEmpty) {
      return _overlayPlaceholder();
    }

    if (path.startsWith('data:image')) {
      try {
        final payload = path.split(',').last;
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _overlayPlaceholder(),
        );
      } catch (_) {
        return _overlayPlaceholder();
      }
    }

    if (path.startsWith('http')) {
      return Image.network(
        path,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _overlayPlaceholder(),
      );
    }

    return Image.asset(
      path,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _overlayPlaceholder(),
    );
  }

  static Widget _overlayPlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_outlined,
        size: 48,
        color: Colors.black45,
      ),
    );
  }
}

class _ImageDisplay {
  final Widget widget;
  final bool hasImage;

  const _ImageDisplay(this.widget, this.hasImage);
}
