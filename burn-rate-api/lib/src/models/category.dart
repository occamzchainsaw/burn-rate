import 'transaction.dart';

import '../errors.dart';

class CategoryInput {
  const CategoryInput({required this.name, required this.type});

  final String name;
  final TransactionType type;

  static const maxNameLength = 50;

  factory CategoryInput.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const BadRequestException('Request body must be a JSON object');
    }

    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const BadRequestException("'name' must be a non-empty string");
    }
    if (name.trim().length > maxNameLength) {
      throw const BadRequestException(
        "'name' must be at most $maxNameLength characters",
      );
    }

    return CategoryInput(
      name: name.trim(),
      type: TransactionType.parse(json['type']),
    );
  }
}

class Category {
  Category.fromInput(this.id, CategoryInput input)
    : name = input.name,
      type = input.type;

  final String id;
  final String name;
  final TransactionType type;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'type': type.name};
}
