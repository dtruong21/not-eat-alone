/// A resolved navigation target from a tapped push payload.
class PushRoute {
  /// Creates a PushRoute with the given go_router location.
  const PushRoute(this.location);

  /// A go_router location, e.g. '/chats/m1'.
  final String location;
}
