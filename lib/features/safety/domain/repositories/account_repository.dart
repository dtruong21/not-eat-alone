/// Abstract boundary for the account-deletion cascade (a callable Cloud
/// Function — see `firebase/functions/` — that deletes the signed-in user's
/// Firestore data, Storage objects, and Auth record).
abstract class AccountRepository {
  Future<void> deleteAccount();
}
