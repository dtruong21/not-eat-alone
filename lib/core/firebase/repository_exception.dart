/// Typed errors thrown by repositories.
///
/// Repositories never return `null` to signal failure — they throw one of
/// these. Providers let them propagate into `AsyncValue.error`. UI renders
/// the error state. No silent swallowing.
library;

/// Thrown when a Firestore document fails to deserialize into its model.
/// Almost always indicates schema drift between code and the database.
class RepositoryParseException implements Exception {
  RepositoryParseException(this.collection, this.docId, this.cause, this.stack);

  final String collection;
  final String docId;
  final Object cause;
  final StackTrace stack;

  @override
  String toString() =>
      'RepositoryParseException($collection/$docId): $cause';
}

/// Thrown when a Firestore write fails (network, rules, quota, etc.).
class RepositoryWriteException implements Exception {
  RepositoryWriteException(this.collection, this.cause, this.stack);

  final String collection;
  final Object cause;
  final StackTrace stack;

  @override
  String toString() => 'RepositoryWriteException($collection): $cause';
}
