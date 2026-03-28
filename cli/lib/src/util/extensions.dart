import 'dart:convert';

extension ObjectExt<T extends Object> on T {
  T2 let<T2>(T2 Function(T) f) => f(this);
}

extension IterableExt<T> on Iterable<T> {
  Iterable<T>? get nonEmptyOrNull => isEmpty ? null : this;
}

extension StringExt on String {
  /// Split into lines, trim each, and drop empty ones.
  List<String> get nonEmptyLines =>
      const LineSplitter().convert(this).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  String? get nonEmptyOrNull => isEmpty ? null : this;
}

extension FutureExt<T> on Future<T> {
  Future<T?> get orNull => onError((_, _) => Future.value());
}
