import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const CustomSearchBar({
    super.key,
    this.placeholder = 'Search',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity, // respects parent SizedBox height (56)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black54, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              cursorColor: Colors.black87,
              style: const TextStyle(color: Colors.black87),
              onChanged: (v) {
                setState(() {}); // update clear button visibility
                widget.onChanged?.call(v);
              },
              onSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: const TextStyle(color: Colors.black45),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              icon: const Icon(Icons.close, size: 18, color: Colors.black45),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged?.call('');
              },
            ),
        ],
      ),
    );
  }
}
