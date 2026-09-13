import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final focusColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A);
    final mutedIconColor = isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: mutedIconColor,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search, color: mutedIconColor, size: 20),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.cancel, color: mutedIconColor, size: 18),
                      tooltip: 'Очистить',
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: focusColor, width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
            ),
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}
