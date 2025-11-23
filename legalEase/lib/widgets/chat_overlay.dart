import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatOverlay extends StatelessWidget {
  final bool open;
  final VoidCallback onClose;
  final String selectedLanguage;
  final Function(String) onLanguageSelected;
  final VoidCallback? onNewChat;

  const ChatOverlay({
    super.key,
    required this.open,
    required this.onClose,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onClose,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: open ? 1.0 : 0.0,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 70),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Options',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Languages',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _LanguageButton(
                          code: 'en',
                          label: 'En 🇬🇧',
                          isSelected: selectedLanguage == 'en',
                          onTap: () {
                            onLanguageSelected('en');
                            onClose();
                          },
                        ),
                        const SizedBox(width: 8),
                        _LanguageButton(
                          code: 'rw',
                          label: 'Rw 🇷🇼',
                          isSelected: selectedLanguage == 'rw',
                          onTap: () {
                            onLanguageSelected('rw');
                            onClose();
                          },
                        ),
                        const SizedBox(width: 8),
                        _LanguageButton(
                          code: 'fr',
                          label: 'Fr 🇫🇷',
                          isSelected: selectedLanguage == 'fr',
                          onTap: () {
                            onLanguageSelected('fr');
                            onClose();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (onNewChat != null) ...[
                      TextButton.icon(
                        onPressed: () {
                          onNewChat?.call();
                          onClose();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Chat'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Chat History',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your chat history is saved automatically',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String code;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.code,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

