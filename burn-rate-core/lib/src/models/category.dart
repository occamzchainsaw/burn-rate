import 'package:burn_rate_shared/burn_rate_shared.dart';

class CategoryDraft {
  const CategoryDraft({required this.name, required this.type});

  final String name;
  final TransactionType type;

  Map<String, Object?> toJson() => {'name': name, 'type': type.name};
}

class Category {
  const Category({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final TransactionType type;

  factory Category.fromJson(Map<String, Object?> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    type: TransactionType.parse(json['type']),
  );
}
