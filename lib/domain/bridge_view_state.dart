enum BridgeViewState {
  stopped,
  starting,
  listening,
  connected,
  stopping,

  /// The session ended without a fault, for example when the client left.
  interrupted,
  error,
}
