/// Host decision type for a pending join request.
library;

/// The host's choice for one pending request.
enum InboxAction {
  /// The host accepts the request.
  approve,

  /// The host declines the request.
  deny,
}
