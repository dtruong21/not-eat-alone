/// Abstract boundary for the `blocks/{blockerUid}_{blockedUid}` collection.
abstract class BlockRepository {
  Future<void> block(String blockerUid, String blockedUid);
  Future<void> unblock(String blockerUid, String blockedUid);

  /// Every uid I should hide — the "other" side of any block whose pair
  /// contains me.
  Stream<Set<String>> watchBlockedUserIds(String uid);
}
