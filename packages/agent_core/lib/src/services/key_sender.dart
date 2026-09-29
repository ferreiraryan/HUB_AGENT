abstract interface class KeySender {
  Future<bool> send(String combo);

  Future<void> dispose();
}

class UnsupportedKeySender implements KeySender {
  @override
  Future<bool> send(String combo) async => false;

  @override
  Future<void> dispose() async {}
}
