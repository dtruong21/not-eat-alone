/// Abstract boundary for the write-only `reports` collection.
///
/// Reports are never read back by the client — rules deny `read`/`update`/
/// `delete`. A moderator reviews them out-of-band (Cloud Console / Functions).
abstract class ReportRepository {
  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    String? reason,
  });
}
