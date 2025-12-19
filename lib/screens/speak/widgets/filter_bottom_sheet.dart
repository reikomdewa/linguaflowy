import 'package:flutter/material.dart';

class FilterBottomSheet extends StatelessWidget {
  final String category;
  final List<String> options;
  final String? currentSelection;
  final Function(String?) onSelect;

  const FilterBottomSheet({
    super.key,
    required this.category,
    required this.options,
    this.currentSelection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Select $category", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (currentSelection != null)
                  TextButton.icon(
                    onPressed: () {
                      onSelect(null);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text("Reset"),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: options.map((opt) => ActionChip(
                label: Text(opt),
                backgroundColor: currentSelection == opt ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                onPressed: () {
                  onSelect(opt);
                  Navigator.pop(context);
                },
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}