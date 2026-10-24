import 'package:flutter/material.dart';
import '../../domain/models/category.dart';
import '../state/app_controller.dart';
import '../widgets/glass_widgets.dart';

class CategoriesScreen extends StatelessWidget {
  final AppController controller;

  const CategoriesScreen({super.key, required this.controller});

  static const List<int> _paletteColors = <int>[
    0xFF6366F1, // Indigo
    0xFF06B6D4, // Cyan
    0xFF8B5CF6, // Violet
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFFEF4444, // Red
    0xFF3B82F6, // Blue
    0xFF14B8A6, // Teal
  ];

  static final List<IconData> _paletteIcons = <IconData>[
    Icons.label_outline,
    Icons.person_outline,
    Icons.work_outline,
    Icons.school_outlined,
    Icons.favorite_border,
    Icons.shopping_bag_outlined,
    Icons.category_outlined,
    Icons.flight_takeoff_rounded,
    Icons.fitness_center_rounded,
    Icons.account_balance_wallet_outlined,
  ];

  Future<void> _showCreateOrEditDialog(
    BuildContext context, {
    ReminderCategory? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int selectedColor = existing?.colorValue ?? _paletteColors.first;
    int selectedIcon =
        existing?.iconCodePoint ?? _paletteIcons.first.codePoint;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                existing != null ? 'Edit Category' : 'New Custom Category',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category Name *',
                        hintText: 'e.g. Finance, Travel, Projects',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Color Accent',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _paletteColors.map((colorVal) {
                        final isChosen = selectedColor == colorVal;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => selectedColor = colorVal),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: isChosen
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: isChosen
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Icon',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _paletteIcons.map((ic) {
                        final isChosen = selectedIcon == ic.codePoint;
                        return IconButton.filledTonal(
                          onPressed: () =>
                              setDialogState(() => selectedIcon = ic.codePoint),
                          icon: Icon(
                            ic,
                            color: isChosen
                                ? Color(selectedColor)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final now = DateTime.now();
                    final category = ReminderCategory(
                      id: existing?.id ??
                          'custom_${now.millisecondsSinceEpoch}',
                      name: name,
                      colorValue: selectedColor,
                      iconCodePoint: selectedIcon,
                      isDefault: existing?.isDefault ?? false,
                      sortOrder:
                          existing?.sortOrder ?? controller.categories.length + 1,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );
                    await controller.saveCategory(
                      category,
                      isNew: existing == null,
                    );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSafeDeleteWithReassignmentDialog(
    BuildContext context,
    ReminderCategory categoryToDelete,
  ) async {
    final availableTargets = controller.categories
        .where((c) => c.id != categoryToDelete.id)
        .toList();
    String targetId = availableTargets
            .any((c) => c.id == 'other')
        ? 'other'
        : availableTargets.first.id;
    final affectedCount = controller.allReminders
        .where((r) => r.categoryId == categoryToDelete.id)
        .length;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Delete "${categoryToDelete.name}"?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    affectedCount > 0
                        ? 'There are $affectedCount reminder(s) assigned to "${categoryToDelete.name}". '
                            'Select a category below to safely reassign them before deletion:'
                        : 'No reminders are currently assigned to this category. Choose a fallback reassignment category to proceed:',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: targetId,
                    decoration: const InputDecoration(
                      labelText: 'Reassign Reminders To',
                    ),
                    items: availableTargets.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (String? v) {
                      if (v != null) {
                        setDialogState(() => targetId = v);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final reassigned =
                        await controller.deleteCategoryAndReassign(
                      categoryIdToDelete: categoryToDelete.id,
                      reassignToCategoryId: targetId,
                    );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Deleted "${categoryToDelete.name}" and safely reassigned $reassigned reminder(s).',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Reassign & Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final categories = controller.categories;
        return GlassScaffold(
          themeSettings: controller.themeSettings,
          appBar: AppBar(
            title: const Text('Categories & Reassignment'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateOrEditDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Category'),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: categories.length,
            itemBuilder: (BuildContext context, int index) {
              final cat = categories[index];
              final reminderCount = controller.allReminders
                  .where((r) => r.categoryId == cat.id)
                  .length;

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: cat.color, width: 1.5),
                      ),
                      child: Icon(cat.icon, color: cat.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (cat.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(fontSize: 10.5),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$reminderCount reminder(s) assigned',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit / Recolor',
                      onPressed: () =>
                          _showCreateOrEditDialog(context, existing: cat),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (!cat.isDefault)
                      IconButton(
                        tooltip: 'Safe Delete with Reassignment',
                        onPressed: () => _showSafeDeleteWithReassignmentDialog(
                          context,
                          cat,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
