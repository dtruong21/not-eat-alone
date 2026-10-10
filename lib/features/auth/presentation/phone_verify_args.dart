/// What the phone-code screen (`/auth/phone`) needs from the sign-in screen,
/// passed as the route's `extra`.
class PhoneVerifyArgs {
  /// Creates the route arguments.
  const PhoneVerifyArgs({
    required this.verificationId,
    required this.phoneE164,
  });

  /// The `verificationId` from `AuthRepository.verifyPhone`'s `codeSent`.
  final String verificationId;

  /// The already-normalised E.164 number the code was sent to (re-used by
  /// "Resend code" and shown formatted in the header).
  final String phoneE164;
}
