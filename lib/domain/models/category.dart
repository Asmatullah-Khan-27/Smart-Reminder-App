import 'package:flutter/material.dart';

class ReminderCategory {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReminderCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.isDefault = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static final Map<int, IconData> _knownIcons = <int, IconData>{
    Icons.label_outline.codePoint: Icons.label_outline,
    Icons.person_outline.codePoint: Icons.person_outline,
    Icons.work_outline.codePoint: Icons.work_outline,
    Icons.school_outlined.codePoint: Icons.school_outlined,
    Icons.favorite_border.codePoint: Icons.favorite_border,
    Icons.shopping_bag_outlined.codePoint: Icons.shopping_bag_outlined,
    Icons.category_outlined.codePoint: Icons.category_outlined,
    Icons.flight_takeoff_rounded.codePoint: Icons.flight_takeoff_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.account_balance_wallet_outlined.codePoint:
        Icons.account_balance_wallet_outlined,
  };

  Color get color => Color(colorValue);

  IconData get icon => _knownIcons[iconCodePoint] ?? Icons.label_outline;

  void validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('Category id cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (name.trim().length > 48) {
      throw ArgumentError('Category name cannot exceed 48 characters.');
    }
  }

  ReminderCategory copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? iconCodePoint,
    bool? isDefault,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'isDefault': isDefault ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ReminderCategory.fromMap(Map<String, dynamic> map) {
    return ReminderCategory(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Category',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ??
          Icons.label_outline.codePoint,
      isDefault: ((map['isDefault'] as num?)?.toInt() ?? 0) == 1,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toBackupJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'isDefault': isDefault,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReminderCategory.fromBackupJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw const FormatException(
        'Invalid category record: missing id or name.',
      );
    }
    return ReminderCategory(
      id: id,
      name: name,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.label_outline.codePoint,
      isDefault: json['isDefault'] == true || json['isDefault'] == 1,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  static List<ReminderCategory> defaultCategories(DateTime timestamp) {
    return <ReminderCategory>[
      ReminderCategory(
        id: 'personal',
        name: 'Personal',
        colorValue: 0xFF6366F1, // Indigo
        iconCodePoint: Icons.person_outline.codePoint,
        isDefault: true,
        sortOrder: 1,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      ReminderCategory(
        id: 'work',
        name: 'Work',
        colorValue: 0xFF06B6D4, // Cyan
        iconCodePoint: Icons.work_outline.codePoint,
        isDefault: true,
        sortOrder: 2,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      ReminderCategory(
        id: 'study',
        name: 'Study',
        colorValue: 0xFF8B5CF6, // Violet
        iconCodePoint: Icons.school_outlined.codePoint,
        isDefault: true,
        sortOrder: 3,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      ReminderCategory(
        id: 'health',
        name: 'Health',
        colorValue: 0xFF10B981, // Emerald
        iconCodePoint: Icons.favorite_border.codePoint,
        isDefault: true,
        sortOrder: 4,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      ReminderCategory(
        id: 'shopping',
        name: 'Shopping',
        colorValue: 0xFFF59E0B, // Amber
        iconCodePoint: Icons.shopping_bag_outlined.codePoint,
        isDefault: true,
        sortOrder: 5,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      ReminderCategory(
        id: 'other',
        name: 'Other',
        colorValue: 0xFFEC4899, // Pink
        iconCodePoint: Icons.category_outlined.codePoint,
        isDefault: true,
        sortOrder: 6,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ];
  }
}
